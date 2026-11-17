// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A buffer: a block of bytes the device can read from and write into.
pub struct Buffer {
  device : Device
  id : @types.BufferId
  size : Int32
  usage : @types.BufferUsages
  mut mapped : Bytes?
  mut mapped_offset : Int32
  mut mapped_size : Int32
  mut mapped_for_write : Bool
  mut destroyed : Bool
}

///|
/// The buffer's identity inside its device, for a bind group entry.
pub fn Buffer::id(self : Buffer) -> @types.BufferId {
  self.id
}

///|
/// The size in bytes this buffer was created with.
pub fn Buffer::size(self : Buffer) -> Int32 {
  self.size
}

///|
/// The usages this buffer was created with.
pub fn Buffer::usage(self : Buffer) -> @types.BufferUsages {
  self.usage
}

///|
/// Whether the buffer is currently mapped.
pub fn Buffer::is_mapped(self : Buffer) -> Bool {
  self.mapped is Some(_)
}

///|
/// Whether the buffer is unmapped, waiting to be mapped, or mapped.
/// https://www.w3.org/TR/webgpu/#dom-gpubuffer-mapstate
pub fn Buffer::map_state(self : Buffer) -> @types.MapState {
  if self.mapped is Some(_) {
    @types.MapState::Mapped
  } else {
    @types.MapState::Unmapped
  }
}

///|
/// `mapAsync`: map a range of the buffer, for reading or for writing.
///
/// The specification's form is a promise because a real device may still be
/// writing the range. On a device whose timeline this library runs in the
/// caller's thread the wait is the call itself, so this returns when the range
/// is ready; `map_read` and `map_write` are the whole-buffer shorthands.
///
/// The alignment rules are the specification's: `offset` is a multiple of 8,
/// the range is a non-zero multiple of 4, and it lies inside the buffer.
/// https://www.w3.org/TR/webgpu/#dom-gpubuffer-mapasync
pub fn Buffer::map_async(
  self : Buffer,
  mode~ : @types.MapMode,
  offset~ : Int32 = 0,
  size? : Int32,
) -> Unit raise @core.Refused {
  @core.require(
    !self.destroyed,
    @types.InvalidResource,
    "buffer",
    "a live buffer",
    "a destroyed buffer",
  )
  let only_read = mode == @types.MapMode::read()
  let only_write = mode == @types.MapMode::write()
  @core.require(
    only_read || only_write,
    @types.InvalidBufferUsage,
    "mode",
    "MAP_READ or MAP_WRITE",
    if mode.is_empty() {
      "no mode"
    } else {
      "both modes"
    },
  )
  @core.require(
    offset % 8 == 0,
    @types.InvalidAlignment,
    "offset",
    "a multiple of 8",
    offset.to_string(),
  )
  let length = match size {
    Some(size) => size
    None => self.size - offset
  }
  @core.require(
    length > 0 && length % 4 == 0,
    @types.InvalidBufferSize,
    "size",
    "a non-zero multiple of 4",
    length.to_string(),
  )
  @core.require(
    offset >= 0 && offset + length <= self.size,
    @types.InvalidBufferSize,
    "offset + size",
    self.size.to_string(),
    (offset + length).to_string(),
  )
  let required = if only_read {
    @types.BufferUsages::map_read()
  } else {
    @types.BufferUsages::map_write()
  }
  let required_name = if only_read { "MAP_READ" } else { "MAP_WRITE" }
  @core.require(
    self.usage.contains(required),
    @types.InvalidBufferUsage,
    "buffer.usage",
    required_name,
    "the other mapping usage",
  )
  @core.require(
    self.mapped is None,
    @types.InvalidBufferState,
    "buffer",
    "an unmapped buffer",
    "an already mapped buffer",
  )
  self.mapped = Some(self.device.hub.read_buffer(self.id, offset, length))
  self.mapped_offset = offset
  self.mapped_size = length
  self.mapped_for_write = only_write
}

///|
/// Map the whole buffer for reading, so that `get_mapped_range` returns its
/// bytes.
///
/// The specification's `mapAsync` is asynchronous because a real device may
/// still be writing. On a device whose timeline this library runs in the
/// caller's thread, the wait is the call itself: this is the native form of
/// that promise.
/// https://www.w3.org/TR/webgpu/#dom-gpubuffer-mapasync
pub fn Buffer::map_read(self : Buffer) -> Unit raise @core.Refused {
  self.map_async(mode=@types.MapMode::read())
}

///|
/// Fill the range a write mapping holds. Outside a mapping this is the
/// whole-buffer shorthand: the bytes reach the device at once.
///
/// A write mapping is filled by this call rather than by mutating the bytes
/// `get_mapped_range` returned, because those bytes are a read-only view in
/// this library. The range is the one `map_async` took, and `unmap` hands it
/// back to the device.
/// https://www.w3.org/TR/webgpu/#dom-gpubuffer-getmappedrange
pub fn Buffer::map_write(
  self : Buffer,
  data~ : Bytes,
) -> Unit raise @core.Refused {
  @core.require(
    !self.destroyed,
    @types.InvalidResource,
    "buffer",
    "a live buffer",
    "a destroyed buffer",
  )
  @core.require(
    self.usage.contains(@types.BufferUsages::map_write()),
    @types.InvalidBufferUsage,
    "buffer.usage",
    "MAP_WRITE",
    "no MAP_WRITE",
  )
  if self.mapped_for_write {
    @core.require(
      data.length() == self.mapped_size,
      @types.InvalidBufferSize,
      "data.size",
      self.mapped_size.to_string(),
      data.length().to_string(),
    )
    self.mapped = Some(data)
  } else {
    @core.require(
      data.length() == self.size,
      @types.InvalidBufferSize,
      "data.size",
      self.size.to_string(),
      data.length().to_string(),
    )
    self.device.hub.unmap_write(self.id, 0, data)
  }
}

///|
/// The bytes of the mapped range, or of a range inside it.
///
/// `offset` is relative to the mapping and a multiple of 8, as in the
/// specification; both bounds default to the whole mapped range.
/// https://www.w3.org/TR/webgpu/#dom-gpubuffer-getmappedrange
pub fn Buffer::get_mapped_range(
  self : Buffer,
  offset~ : Int32 = 0,
  size? : Int32,
) -> Bytes raise @core.Refused {
  match self.mapped {
    Some(bytes) => {
      let length = match size {
        Some(size) => size
        None => self.mapped_size - offset
      }
      @core.require(
        offset % 8 == 0,
        @types.InvalidAlignment,
        "offset",
        "a multiple of 8",
        offset.to_string(),
      )
      @core.require(
        offset >= 0 && length >= 0 && offset + length <= bytes.length(),
        @types.InvalidBufferSize,
        "offset + size",
        bytes.length().to_string(),
        (offset + length).to_string(),
      )
      bytes[offset:offset + length].to_owned()
    }
    None =>
      raise @core.invalid(
        @types.InvalidBufferState,
        "buffer",
        "a mapped buffer",
        "an unmapped buffer",
      )
  }
}

///|
/// Drop the mapping, writing back what a write mapping was given.
///
/// A write-back the device refuses is dropped: the only ways it can fail are a
/// destroyed or lost device, and in both cases the bytes have no destination
/// left to reach.
pub fn Buffer::unmap(self : Buffer) -> Unit {
  if self.mapped_for_write {
    match self.mapped {
      Some(bytes) =>
        self.device.hub.unmap_write(self.id, self.mapped_offset, bytes) catch {
          _ => ()
        }
      None => ()
    }
  }
  self.mapped = None
  self.mapped_for_write = false
}

///|
/// Destroy the buffer. Later uses are refused; the bytes are kept by the
/// backend until the device itself goes away, which is what a driver does.
/// https://www.w3.org/TR/webgpu/#dom-gpubuffer-destroy
pub fn Buffer::destroy(self : Buffer) -> Unit {
  if !self.destroyed {
    self.destroyed = true
    self.mapped = None
    self.device.hub.destroy_buffer(self.id)
  }
}
