// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Drive the library through the `js` backend, from JavaScript.
//
// This is the shape a conformance case has: ask `navigator.gpu` for a device,
// do something, and find out through an error scope whether the library said
// no. The cases below are written the way the suite writes them, on purpose -
// if these pass, the seam a suite needs is there, and what is missing for a
// case is what the case itself needs (a shader compiler, a rasterizer) rather
// than the binding.
//
//     moon build --target js
//     node conformance/js/run.mjs
//
// The artifact is the built host; importing it runs its `main`, which publishes
// the channels the facade wraps.

import { existsSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const here = import.meta.dirname;
const root = path.resolve(here, '../..');
const artifact = path.join(root, '_build/js/debug/build/bindings/js/js.js');

if (!existsSync(artifact)) {
  console.error(`missing ${path.relative(root, artifact)}; run: moon build --target js`);
  process.exit(2);
}

await import(pathToFileURL(artifact).href);

const facade = await import(pathToFileURL(path.join(here, 'webgpu.mjs')).href);
const { connect, install, GPUValidationError } = facade;

connect();
install();

const results = [];

async function check(name, body) {
  try {
    await body();
    results.push({ name, error: null });
  } catch (error) {
    results.push({ name, error });
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const MAP_READ = 0x0001;
const MAP_WRITE = 0x0002;
const COPY_SRC = 0x0004;
const COPY_DST = 0x0008;
const TEXTURE_BINDING = 0x0010;
const RENDER_ATTACHMENT = 0x0020;
const COPY_DST_TEXTURE = 0x0002;

const { gpu } = globalThis.navigator;
const adapter = await gpu.requestAdapter();
const device = await adapter.requestDevice();

await check('an adapter and a device come back', async () => {
  assert(adapter !== null, 'no adapter');
  assert(device.queue !== undefined, 'no queue');
  assert(gpu.getPreferredCanvasFormat() === 'bgra8unorm', 'wrong canvas format');
});

await check('bytes written through the queue read back through a mapping', async () => {
  const buffer = device.createBuffer({ size: 16, usage: MAP_READ | COPY_DST });
  const bytes = new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
  device.queue.writeBuffer(buffer, 0, bytes);
  await buffer.mapAsync(MAP_READ);
  const mapped = new Uint8Array(buffer.getMappedRange());
  assert(mapped.length === 16, `mapped ${mapped.length} bytes`);
  for (let i = 0; i < 16; i += 1) assert(mapped[i] === i + 1, `byte ${i} is ${mapped[i]}`);
  buffer.unmap();
  assert(buffer.mapState === 'unmapped', 'still mapped after unmap');
  buffer.destroy();
});

await check('a usage the specification forbids is refused, and the scope sees it', async () => {
  device.pushErrorScope('validation');
  // MAP_READ allows at most COPY_DST beside it, so a copy source cannot be
  // read back: the case is the specification's, not this facade's.
  const buffer = device.createBuffer({ size: 16, usage: MAP_READ | COPY_SRC });
  const error = await device.popErrorScope();
  assert(buffer !== null, 'no buffer object');
  assert(buffer.size === 16, 'the descriptor is not reflected');
  assert(error instanceof GPUValidationError, `the scope saw ${error}`);
  buffer.destroy();
});

await check('a size that is not a multiple of four is legal unless it is mapped at creation', async () => {
  device.pushErrorScope('validation');
  const buffer = device.createBuffer({ size: 6, usage: COPY_DST });
  const error = await device.popErrorScope();
  assert(error === null, `the scope saw ${error}`);
  buffer.destroy();
});

await check('an unaligned mapping offset rejects and is scoped', async () => {
  const buffer = device.createBuffer({ size: 16, usage: MAP_READ | COPY_DST });
  device.queue.writeBuffer(buffer, 0, new Uint8Array(16));
  device.pushErrorScope('validation');
  let rejected = false;
  try {
    await buffer.mapAsync(MAP_READ, 4);
  } catch {
    rejected = true;
  }
  const error = await device.popErrorScope();
  assert(rejected, 'the promise resolved');
  assert(error !== null, 'the scope saw nothing');
  buffer.destroy();
});

await check('a mapping for writing carries what the caller wrote on unmap', async () => {
  const buffer = device.createBuffer({ size: 8, usage: MAP_WRITE | COPY_SRC });
  await buffer.mapAsync(MAP_WRITE);
  new Uint8Array(buffer.getMappedRange()).set([9, 9, 9, 9, 9, 9, 9, 9]);
  buffer.unmap();
  await buffer.mapAsync(MAP_WRITE);
  const seen = new Uint8Array(buffer.getMappedRange());
  assert(seen[0] === 9 && seen[7] === 9, `read back ${seen[0]}`);
  buffer.unmap();
  buffer.destroy();
});

await check('a destroyed buffer cannot be mapped', async () => {
  const buffer = device.createBuffer({ size: 8, usage: MAP_READ | COPY_DST });
  buffer.destroy();
  let rejected = false;
  try {
    await buffer.mapAsync(MAP_READ);
  } catch {
    rejected = true;
  }
  assert(rejected, 'the promise resolved');
});

await check('a sample count of three is refused', async () => {
  device.pushErrorScope('validation');
  const texture = device.createTexture({
    size: { width: 4, height: 4 },
    format: 'rgba8unorm',
    usage: RENDER_ATTACHMENT,
    sampleCount: 3,
  });
  const error = await device.popErrorScope();
  assert(error instanceof GPUValidationError, `the scope saw ${error}`);
  texture.destroy();
});

await check('a texture with a legal descriptor is created and keeps it', async () => {
  device.pushErrorScope('validation');
  const texture = device.createTexture({
    size: { width: 4, height: 4 },
    format: 'rgba8unorm',
    usage: TEXTURE_BINDING | COPY_DST_TEXTURE,
  });
  const error = await device.popErrorScope();
  assert(error === null, `the scope saw ${error}`);
  assert(texture.width === 4 && texture.height === 4, 'the size is not reflected');
  assert(texture.format === 'rgba8unorm', 'the format is not reflected');
  texture.destroy();
});

await check('writeTexture fills a texture without a refusal', async () => {
  const texture = device.createTexture({
    size: { width: 4, height: 4 },
    format: 'rgba8unorm',
    usage: TEXTURE_BINDING | COPY_DST_TEXTURE,
  });
  device.pushErrorScope('validation');
  device.queue.writeTexture(
    { texture },
    new Uint8Array(4 * 4 * 4),
    { bytesPerRow: 16 },
    { width: 4, height: 4 },
  );
  const error = await device.popErrorScope();
  assert(error === null, `the scope saw ${error}`);
  texture.destroy();
});

await check('writing past the end of a texture is refused', async () => {
  const texture = device.createTexture({
    size: { width: 4, height: 4 },
    format: 'rgba8unorm',
    usage: TEXTURE_BINDING | COPY_DST_TEXTURE,
  });
  device.pushErrorScope('validation');
  device.queue.writeTexture(
    { texture },
    new Uint8Array(4 * 4 * 4),
    { bytesPerRow: 16 },
    { width: 8, height: 8 },
  );
  const error = await device.popErrorScope();
  assert(error !== null, 'the scope saw nothing');
  texture.destroy();
});

await check('an empty submission is accepted and a made-up one is not', async () => {
  device.queue.submit([]);
  let refused = false;
  try {
    device.queue.submit([{}]);
  } catch {
    refused = true;
  }
  assert(refused, 'a submission with no command buffer was accepted');
});

const failed = results.filter((result) => result.error !== null);
for (const result of results) {
  console.log(`${result.error === null ? 'ok  ' : 'FAIL'} ${result.name}`);
  if (result.error !== null) console.log(`     ${result.error.message}`);
}
console.log(`\n${results.length - failed.length}/${results.length} on the js backend`);

// An error left in the device's uncaptured list is a case written wrong, not a
// case that passed: the specification would have delivered it to
// onuncapturederror, and nothing here listens.
process.exit(failed.length === 0 ? 0 : 1);
