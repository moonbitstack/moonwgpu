// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The JavaScript side of this library.
//
// A conformance suite for WebGPU is a JavaScript program calling
// `navigator.gpu`. This package is what lets such a program call this library
// instead, on the one backend a JavaScript host can reach.
//
// The seam is deliberately narrow: one object with three functions, and an
// opcode table shared with the facade.
//
//     ask(op, a, b, c, d, e, f, g, data) -> Int   an answer, or 0 on refusal
//     text(op, a) -> String                      text about a call
//     take(op, a) -> Bytes                       bytes about a call
//
// Everything a suite expects to be asynchronous - the promises, the error
// classes, the prototype chain - is the facade's work, on the JavaScript side.
// Nothing above this file knows that JavaScript exists, and nothing here knows
// what a promise is.

///|
/// Buffers: create, inspect, fill, map, unmap, destroy.
const OP_CREATE_BUFFER : Int32 = 1

///|
const OP_BUFFER_SIZE : Int32 = 2

///|
const OP_BUFFER_USAGE : Int32 = 3

///|
const OP_BUFFER_MAP_STATE : Int32 = 4

///|
const OP_DESTROY_BUFFER : Int32 = 5

///|
const OP_WRITE_BUFFER : Int32 = 6

///|
const OP_MAP_ASYNC : Int32 = 7

///|
const OP_MAP_WRITE : Int32 = 8

///|
const OP_UNMAP : Int32 = 9

///|
/// Error scopes: the device's own error channel, which is how a suite asks
/// whether an operation was refused.
const OP_PUSH_ERROR_SCOPE : Int32 = 10

///|
/// Textures: create, fill, destroy.
const OP_CREATE_TEXTURE : Int32 = 11

///|
const OP_DESTROY_TEXTURE : Int32 = 12

///|
const OP_WRITE_TEXTURE : Int32 = 13

///|
/// The device and its queue.
const OP_DESTROY_DEVICE : Int32 = 14

///|
const OP_SUBMIT : Int32 = 15

///|
const OP_TEXTURE_FORMAT_COUNT : Int32 = 16

///|
/// The text channel.
const TX_PROTOCOL : Int32 = 1

///|
const TX_LAST_ERROR : Int32 = 2

///|
const TX_POP_ERROR_SCOPE : Int32 = 3

///|
const TX_TEXTURE_FORMAT_NAME : Int32 = 4

///|
/// The bytes channel.
const BY_MAPPED_RANGE : Int32 = 1

///|
/// The protocol the facade on the other side has to speak. A facade that
/// disagrees with this number would be reading the wrong table, so it says so
/// instead of returning nonsense.
const PROTOCOL : String = "moonwgpu/js/1"

///|
/// What the binding remembers between calls: the device, and the objects a
/// handle names.
///
/// A handle is an index into one of these lists plus one, so that `0` can stand
/// for "no object" - the JavaScript side treats a zero as the refusal that
/// `last_error` explains. A destroyed object leaves its slot empty, and a
/// handle to it is refused like any other stale handle.
struct Host {
  device : @moonwgpu.Device
  buffers : Array[@moonwgpu.Buffer?]
  textures : Array[@moonwgpu.Texture?]
  mut last_error : String
}

///|
fn Host::new() -> Host raise @core.Refused {
  let backend = @memory.Backend::new()
  let instance = @moonwgpu.Instance::new(backend~, label="js")
  let adapter = instance.request_adapter()
  let device = adapter.request_device()
  { device, buffers: [], textures: [], last_error: "", }
}

///|
fn Host::buffer(
  self : Host,
  handle : Int32,
) -> @moonwgpu.Buffer raise @core.Refused {
  let index = handle - 1
  let found = if index >= 0 && index < self.buffers.length() {
    self.buffers[index]
  } else {
    None
  }
  match found {
    Some(buffer) => buffer
    None =>
      raise @core.invalid(
        @types.InvalidResource,
        "buffer",
        "a live buffer handle",
        handle.to_string(),
      )
  }
}

///|
fn Host::texture(
  self : Host,
  handle : Int32,
) -> @moonwgpu.Texture raise @core.Refused {
  let index = handle - 1
  let found = if index >= 0 && index < self.textures.length() {
    self.textures[index]
  } else {
    None
  }
  match found {
    Some(texture) => texture
    None =>
      raise @core.invalid(
        @types.InvalidResource,
        "texture",
        "a live texture handle",
        handle.to_string(),
      )
  }
}

///|
/// Run one operation and turn a refusal into a zero plus a message, because a
/// JavaScript call that crosses this seam cannot raise.
///
/// The refusal is also handed to the device's scopes, which is what the
/// specification does with an error a call generated: a suite reads it back
/// from `popErrorScope` rather than from the call. `last_error` is cleared
/// first, so that a zero answer with no message is a success - the numeric
/// channel has no other way to say both.
fn Host::ask(
  self : Host,
  op : Int32,
  a : Int32,
  b : Int32,
  c : Int32,
  d : Int32,
  e : Int32,
  f : Int32,
  g : Int32,
  data : Bytes,
) -> Int32 {
  self.last_error = ""
  self.dispatch(op, a, b, c, d, e, f, g, data) catch {
    error => {
      self.last_error = error.message()
      ignore(self.device.report_error(error))
      0
    }
  }
}

///|
fn Host::dispatch(
  self : Host,
  op : Int32,
  a : Int32,
  b : Int32,
  c : Int32,
  d : Int32,
  e : Int32,
  f : Int32,
  g : Int32,
  data : Bytes,
) -> Int32 raise @core.Refused {
  match op {
    OP_CREATE_BUFFER => {
      let buffer = self.device.create_buffer(
        descriptor=@types.BufferDescriptor::new(
          size=a,
          usage=@types.BufferUsages::from_bits(b.reinterpret_as_uint()),
        ),
      )
      self.buffers.push(Some(buffer))
      self.buffers.length()
    }
    OP_BUFFER_SIZE => self.buffer(a).size()
    OP_BUFFER_USAGE => self.buffer(a).usage().bits().reinterpret_as_int()
    OP_BUFFER_MAP_STATE =>
      match self.buffer(a).map_state() {
        @types.MapState::Unmapped => 0
        @types.MapState::Pending => 1
        @types.MapState::Mapped => 2
      }
    OP_DESTROY_BUFFER => {
      let buffer = self.buffer(a)
      buffer.destroy()
      self.buffers[a - 1] = None
      0
    }
    OP_WRITE_BUFFER => {
      self.device.queue().write_buffer(buffer=self.buffer(a), offset=b, data~)
      0
    }
    OP_MAP_ASYNC => {
      let buffer = self.buffer(a)
      let mode = @types.MapMode::from_bits(b.reinterpret_as_uint())
      if d > 0 {
        buffer.map_async(mode~, offset=c, size=d)
      } else {
        buffer.map_async(mode~, offset=c)
      }
      0
    }
    OP_MAP_WRITE => {
      self.buffer(a).map_write(data~)
      0
    }
    OP_UNMAP => {
      self.buffer(a).unmap()
      0
    }
    OP_PUSH_ERROR_SCOPE => {
      let filter = match a {
        1 => @types.ErrorFilter::OutOfMemory
        2 => @types.ErrorFilter::Internal
        _ => @types.ErrorFilter::Validation
      }
      self.device.push_error_scope(filter~)
      0
    }
    OP_CREATE_TEXTURE => {
      let formats = @types.TextureFormat::all()
      @core.require(
        f >= 0 && f < formats.length(),
        @types.InvalidTextureFormat,
        "descriptor.format",
        "a texture format",
        f.to_string(),
      )
      let texture = self.device.create_texture(
        descriptor=@types.TextureDescriptor::new(
          size=@types.Extent3d::new(width=a, height=b, depth_or_array_layers=c),
          format=formats[f],
          usage=@types.TextureUsages::from_bits(g.reinterpret_as_uint()),
          mip_level_count=d,
          sample_count=e,
        ),
      )
      self.textures.push(Some(texture))
      self.textures.length()
    }
    OP_DESTROY_TEXTURE => {
      let texture = self.texture(a)
      texture.destroy()
      self.textures[a - 1] = None
      0
    }
    OP_WRITE_TEXTURE => {
      let texture = self.texture(a)
      let info = texture.format().info()
      let bytes_per_row = b * info.bytes_per_block / info.block_width
      self.device
      .queue()
      .write_texture(
        destination=@types.TexelCopyTextureInfo::new(
          texture=texture.id(),
          origin=@types.Origin3d::new(x=c, y=d),
        ),
        data~,
        layout=@types.TexelCopyBufferLayout::new(bytes_per_row~),
      )
      0
    }
    OP_DESTROY_DEVICE => {
      self.device.destroy()
      0
    }
    OP_SUBMIT => {
      // A command buffer reaches this seam only if a facade built one, and the
      // facade cannot: encoding is where a suite and this library meet in
      // MoonBit, not in JavaScript. An empty submit is the one that is honest.
      @core.require(
        a == 0,
        @types.InvalidPassState,
        "commandBuffers",
        "an empty submission",
        a.to_string(),
      )
      self.device.queue().submit(command_buffers=[])
      0
    }
    OP_TEXTURE_FORMAT_COUNT => @types.TextureFormat::all().length()
    _ =>
      raise @core.invalid(
        @types.InvalidResource,
        "op",
        "a known operation",
        op.to_string(),
      )
  }
}

///|
fn Host::text(self : Host, op : Int32, a : Int32) -> String {
  match op {
    TX_PROTOCOL => PROTOCOL
    TX_LAST_ERROR => self.last_error
    TX_POP_ERROR_SCOPE =>
      try {
        let errors = self.device.pop_error_scope()
        if errors.is_empty() {
          ""
        } else {
          errors[0].message()
        }
      } catch {
        error => error.message()
      }
    TX_TEXTURE_FORMAT_NAME => {
      let formats = @types.TextureFormat::all()
      if a >= 0 && a < formats.length() {
        formats[a].name()
      } else {
        ""
      }
    }
    _ => ""
  }
}

///|
fn Host::take(self : Host, op : Int32, a : Int32) -> Bytes {
  self.last_error = ""
  match op {
    BY_MAPPED_RANGE =>
      self.buffer(a).get_mapped_range() catch {
        error => {
          self.last_error = error.message()
          b""
        }
      }
    _ => b""
  }
}

///|
extern "js" fn install_channels(
  ask : (Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Bytes) -> Int32,
  text : (Int32, Int32) -> String,
  take : (Int32, Int32) -> Bytes,
) =
  #| (ask, text, take) => {
  #|   Object.defineProperty(globalThis, "__moonwgpu", {
  #|     value: { ask, text, take },
  #|     configurable: true,
  #|     writable: true,
  #|   });
  #| }

///|
/// Publish the channels a JavaScript facade calls. Called once, from `main`.
pub fn install() -> Unit raise @core.Refused {
  let host = Host::new()
  install_channels(
    fn(op, a, b, c, d, e, f, g, data) {
      host.ask(op, a, b, c, d, e, f, g, data)
    },
    fn(op, a) { host.text(op, a) },
    fn(op, a) { host.take(op, a) },
  )
}

///|
/// Build for the `js` backend and this happens: the channels appear on
/// `globalThis`, and a JavaScript facade can drive the library.
#coverage.skip
fn main {
  install() catch {
    error =>
      println("moonwgpu: the js host could not start: \{error.message()}")
  }
}
