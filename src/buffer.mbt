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
/// Map the whole buffer for reading, so that `get_mapped_range` returns its
/// bytes.
///
/// The specification's `mapAsync` is asynchronous because a real device may
/// still be writing. On a device whose timeline this library runs in the
/// caller's thread, the wait is the call itself: this is the native form of
/// that promise.
/// https://www.w3.org/TR/webgpu/#dom-gpubuffer-mapasync
pub fn Buffer::map_read(self : Buffer) -> Unit raise @core.Refused {
  @core.require(
    !self.destroyed,
    @types.InvalidResource,
    "buffer",
    "a live buffer",
    "a destroyed buffer",
  )
  @core.require(
    self.usage.contains(@types.BufferUsages::map_read()),
    @types.InvalidBufferUsage,
    "buffer.usage",
    "MAP_READ",
    "no MAP_READ",
  )
  @core.require(
    self.mapped is None,
    @types.InvalidBufferState,
    "buffer",
    "an unmapped buffer",
    "an already mapped buffer",
  )
  self.mapped = Some(self.device.hub.read_buffer(self.id, 0, self.size))
}

///|
/// Write into a buffer that was mapped for writing. The bytes go to the device
/// on the next submit, as in the specification.
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
  @core.require(
    data.length() == self.size,
    @types.InvalidBufferSize,
    "data.size",
    self.size.to_string(),
    data.length().to_string(),
  )
  self.device.hub.write_buffer(self.id, 0, data)
}

///|
/// The bytes of the mapped range.
/// https://www.w3.org/TR/webgpu/#dom-gpubuffer-getmappedrange
pub fn Buffer::get_mapped_range(self : Buffer) -> Bytes raise @core.Refused {
  match self.mapped {
    Some(bytes) => bytes
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
/// Drop the mapping.
pub fn Buffer::unmap(self : Buffer) -> Unit {
  self.mapped = None
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
