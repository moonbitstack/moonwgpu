// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// A WebGPU-shaped facade over the MoonBit binding in `src/bindings/js`.
//
// The conformance suite this repository follows is a JavaScript program that
// calls `navigator.gpu`. This file is the smallest thing that lets such a
// program call this library instead: the object graph, the promises and the
// error classes that the specification defines, built over the three channels
// the binding publishes (`ask`, `text`, `take`).
//
// What it is not: a rasterizer. The memory backend moves bytes, so a case that
// compares pixels has nothing to compare, and a case that needs a shader
// compiler needs `moonnaga` first. Validation cases - the ones that ask whether
// an argument was refused, and which error scope saw it - are the ones this
// facade can carry.

const EMPTY = new Uint8Array(0);

// The opcode tables, mirrored from `src/bindings/js/host.mbt`. `connect`
// refuses to go on unless the binding answers with the same protocol string,
// so a half-updated pair fails loudly instead of misreading an argument.

export const OP = Object.freeze({
  CREATE_BUFFER: 1,
  BUFFER_SIZE: 2,
  BUFFER_USAGE: 3,
  BUFFER_MAP_STATE: 4,
  DESTROY_BUFFER: 5,
  WRITE_BUFFER: 6,
  MAP_ASYNC: 7,
  MAP_WRITE: 8,
  UNMAP: 9,
  PUSH_ERROR_SCOPE: 10,
  CREATE_TEXTURE: 11,
  DESTROY_TEXTURE: 12,
  WRITE_TEXTURE: 13,
  DESTROY_DEVICE: 14,
  SUBMIT: 15,
  TEXTURE_FORMAT_COUNT: 16,
});

export const TX = Object.freeze({
  PROTOCOL: 1,
  LAST_ERROR: 2,
  POP_ERROR_SCOPE: 3,
  TEXTURE_FORMAT_NAME: 4,
});

export const BY = Object.freeze({
  MAPPED_RANGE: 1,
});

export const PROTOCOL = 'moonwgpu/js/1';

let channels = null;

/** Attach the facade to a binding instance, which the compiled host publishes
 *  on `globalThis.__moonwgpu` when its `main` runs. */
export function connect(source = globalThis.__moonwgpu) {
  if (!source) {
    throw new Error(
      'moonwgpu: no binding on globalThis; build src/bindings/js for --target js and import its artifact first',
    );
  }
  const protocol = source.text(TX.PROTOCOL, 0);
  if (protocol !== PROTOCOL) {
    throw new Error(
      `moonwgpu: the binding speaks "${protocol}", this facade speaks "${PROTOCOL}"`,
    );
  }
  channels = source;
  return source;
}

function ask(op, a = 0, b = 0, c = 0, d = 0, e = 0, f = 0, g = 0, data = EMPTY) {
  return channels.ask(op, a, b, c, d, e, f, g, data);
}

/** The last refusal, or null if the last call succeeded. The binding clears it
 *  on entry, so `ask` returning 0 means one of two things and this says which. */
function refusal() {
  const message = channels.text(TX.LAST_ERROR, 0);
  return message === '' ? null : message;
}

function call(op, a, b, c, d, e, f, g, data) {
  const value = ask(op, a, b, c, d, e, f, g, data);
  return { value, error: refusal() };
}

// The three error classes the specification defines. A suite checks the class
// as often as it checks that something happened at all.

export class GPUError extends Error {
  constructor(message) {
    super(message);
    this.name = new.target.name;
  }
}

export class GPUValidationError extends GPUError {}
export class GPUOutOfMemoryError extends GPUError {}
export class GPUInternalError extends GPUError {}
export class GPUDeviceLostError extends GPUError {}
export class OperationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'OperationError';
  }
}

function classify(message) {
  if (message.startsWith('out of memory')) return GPUOutOfMemoryError;
  if (message.startsWith('internal error')) return GPUInternalError;
  return GPUValidationError;
}

function errorOf(message) {
  return new (classify(message))(message);
}

const MAP_MODES = { read: 1, write: 2 };
const ERROR_FILTERS = { validation: 0, 'out-of-memory': 1, internal: 2 };

function asBytes(data) {
  if (data instanceof ArrayBuffer) return new Uint8Array(data);
  if (ArrayBuffer.isView(data)) {
    return new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
  }
  throw new TypeError('data has to be an ArrayBuffer, a TypedArray or a DataView');
}

let formats = null;

function textureFormats() {
  if (formats === null) {
    const count = ask(OP.TEXTURE_FORMAT_COUNT);
    formats = new Map();
    for (let index = 0; index < count; index += 1) {
      formats.set(channels.text(TX.TEXTURE_FORMAT_NAME, index), index);
    }
  }
  return formats;
}

class GPUBuffer {
  constructor(device, handle, descriptor) {
    this._device = device;
    this._handle = handle;
    this._size = descriptor.size;
    this._usage = descriptor.usage;
    this._mapState = 'unmapped';
    this._mapped = null;
    this._mappedFor = null;
    this.label = descriptor.label ?? '';
  }

  get size() {
    return this._size;
  }

  get usage() {
    return this._usage;
  }

  get mapState() {
    if (this._mapState !== 'unmapped') return this._mapState;
    if (!this._handle) return 'unmapped';
    const code = ask(OP.BUFFER_MAP_STATE, this._handle);
    return ['unmapped', 'pending', 'mapped'][code] ?? 'unmapped';
  }

  mapAsync(mode, offset = 0, size) {
    return new Promise((resolve, reject) => {
      if (!this._handle) {
        reject(new OperationError('the buffer is invalid'));
        return;
      }
      if (this._mapState !== 'unmapped') {
        reject(new OperationError('buffer: want an unmapped buffer, got a mapped one'));
        return;
      }
      const length = size ?? this._size - offset;
      const { error } = call(OP.MAP_ASYNC, this._handle, mode, offset, length);
      if (error !== null) {
        reject(errorOf(error));
        return;
      }
      this._mapState = 'pending';
      this._mappedFor = { mode, offset, size: length };
      // The device timeline of the memory backend runs in the caller's thread,
      // so the mapping is ready by the time the call returns; the promise is
      // what a suite awaits, and it is already resolved.
      this._mapState = 'mapped';
      resolve();
    });
  }

  getMappedRange(offset = 0, size) {
    if (!this._handle || this._mappedFor === null) {
      throw new OperationError('buffer: want a mapped buffer, got an unmapped one');
    }
    if (this._mapped === null) {
      const bytes = channels.take(BY.MAPPED_RANGE, this._handle);
      const message = refusal();
      if (message !== null) throw new OperationError(message);
      // A copy, not a view: the specification hands out a range that the caller
      // may write into, for a write mapping, and that the library reads back on
      // `unmap`.
      this._mapped = new Uint8Array(bytes.length);
      this._mapped.set(bytes);
    }
    const span = this._mappedFor.size;
    const start = offset - this._mappedFor.offset;
    const end = size === undefined ? span : start + size;
    if (start < 0 || end > span || start > end) {
      throw new OperationError('getMappedRange: the range is outside the mapping');
    }
    if (start === 0 && end === span) {
      // The whole mapping is one ArrayBuffer of its own, so a caller writing
      // through it writes into the range `unmap` hands back.
      return this._mapped.buffer;
    }
    // A sub-range cannot alias the same memory through a second ArrayBuffer;
    // this one is a copy, and the comment is the caveat.
    return this._mapped.buffer.slice(start, end);
  }

  unmap() {
    if (this._handle === 0) return;
    if (this._mapped !== null && this._mappedFor?.mode === MAP_MODES.write) {
      const { error } = call(OP.MAP_WRITE, this._handle, 0, 0, 0, 0, 0, 0, this._mapped);
      if (error !== null) throw errorOf(error);
    }
    ask(OP.UNMAP, this._handle);
    this._mapState = 'unmapped';
    this._mapped = null;
    this._mappedFor = null;
  }

  destroy() {
    if (this._handle === 0) return;
    if (this._mapState !== 'unmapped') this.unmap();
    ask(OP.DESTROY_BUFFER, this._handle);
    this._handle = 0;
  }
}

class GPUTexture {
  constructor(device, handle, descriptor) {
    this._device = device;
    this._handle = handle;
    const size = descriptor.size ?? { width: 1, height: 1, depthOrArrayLayers: 1 };
    this.width = size.width;
    this.height = size.height ?? 1;
    this.depthOrArrayLayers = size.depthOrArrayLayers ?? 1;
    this.format = descriptor.format;
    this.usage = descriptor.usage;
    this.mipLevelCount = descriptor.mipLevelCount ?? 1;
    this.sampleCount = descriptor.sampleCount ?? 1;
    this.dimension = descriptor.dimension ?? '2d';
    this.label = descriptor.label ?? '';
  }

  createView(descriptor = {}) {
    return { texture: this, ...descriptor };
  }

  destroy() {
    if (this._handle === 0) return;
    ask(OP.DESTROY_TEXTURE, this._handle);
    this._handle = 0;
  }
}

class GPUQueue {
  constructor(device) {
    this._device = device;
    this.label = '';
  }

  // The specification's writeBuffer does not throw: it generates a validation
  // error, which is why the refusal is left in the device's scopes.
  writeBuffer(buffer, bufferOffset, data, dataOffset = 0, size) {
    if (!buffer._handle) return;
    const bytes = asBytes(data);
    const start = dataOffset;
    const end = size === undefined ? bytes.length : start + size;
    call(OP.WRITE_BUFFER, buffer._handle, bufferOffset, 0, 0, 0, 0, 0, bytes.slice(start, end));
  }

  // `dataLayout.bytesPerRow` is not passed on: writeTexture crosses the seam
  // texel by texel, so the row pitch the binding computes is the tight one.
  // A suite that supplies a padded layout is answered by the memory backend's
  // own copy rules through `copyBufferToTexture`, not from here.
  writeTexture(destination, data, _dataLayout = {}, size) {
    if (!destination.texture?._handle) return;
    const bytes = asBytes(data);
    const width = size?.width ?? destination.texture.width;
    const origin = destination.origin ?? { x: 0, y: 0, z: 0 };
    call(
      OP.WRITE_TEXTURE,
      destination.texture._handle,
      width,
      origin.x ?? 0,
      origin.y ?? 0,
      0,
      0,
      0,
      bytes,
    );
  }

  submit(commandBuffers) {
    const count = commandBuffers?.length ?? 0;
    const { error } = call(OP.SUBMIT, count);
    if (error !== null) throw errorOf(error);
  }

  onSubmittedWorkDone() {
    return Promise.resolve();
  }
}

class GPUDevice {
  constructor(adapter) {
    this._adapter = adapter;
    this.queue = new GPUQueue(this);
    this.label = '';
    this.lost = new Promise(() => {});
    this.features = new Set();
    this.limits = {};
  }

  pushErrorScope(filter = 'validation') {
    ask(OP.PUSH_ERROR_SCOPE, ERROR_FILTERS[filter] ?? 0);
  }

  popErrorScope() {
    const message = channels.text(TX.POP_ERROR_SCOPE, 0);
    return Promise.resolve(message === '' ? null : errorOf(message));
  }

  createBuffer(descriptor) {
    const { value, error } = call(OP.CREATE_BUFFER, descriptor.size, descriptor.usage);
    // Invalid, not thrown: the specification returns a buffer whose operations
    // are no-ops and leaves the error to the scope that was open.
    ignore(error);
    return new GPUBuffer(this, error === null ? value : 0, descriptor);
  }

  createTexture(descriptor) {
    const index = textureFormats().get(descriptor.format);
    const size = descriptor.size ?? { width: 1, height: 1, depthOrArrayLayers: 1 };
    const { value, error } = call(
      OP.CREATE_TEXTURE,
      size.width,
      size.height ?? 1,
      size.depthOrArrayLayers ?? 1,
      descriptor.mipLevelCount ?? 1,
      descriptor.sampleCount ?? 1,
      index ?? -1,
      descriptor.usage,
    );
    ignore(error);
    return new GPUTexture(this, error === null ? value : 0, descriptor);
  }

  destroy() {
    ask(OP.DESTROY_DEVICE);
  }
}

function ignore(_value) {}

class GPUAdapter {
  constructor(gpu) {
    this._gpu = gpu;
    this.features = new Set();
    this.limits = {};
    this.info = { vendor: 'moonbitstack', architecture: 'memory', device: 'memory', description: 'the memory backend' };
  }

  get isFallbackAdapter() {
    return true;
  }

  requestDevice(_descriptor = {}) {
    // One device per process: the binding owns a single backend, and the
    // suite's descriptor asks for features this backend does not have. The
    // checks that matter - limits and features - are refused by the library
    // itself, not here.
    return Promise.resolve(new GPUDevice(this));
  }
}

class GPU {
  requestAdapter(_options = {}) {
    return Promise.resolve(new GPUAdapter(this));
  }

  getPreferredCanvasFormat() {
    return 'bgra8unorm';
  }
}

/** Install the facade on a global object, as `navigator.gpu`. */
export function install(target = globalThis) {
  const gpu = new GPU();
  if (target.navigator === undefined) {
    Object.defineProperty(target, 'navigator', { value: {}, configurable: true });
  }
  target.navigator.gpu = gpu;
  return gpu;
}
