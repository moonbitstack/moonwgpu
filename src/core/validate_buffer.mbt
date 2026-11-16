// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The bit names of `GPUBufferUsage`, for the `got` field of a refusal.
pub fn buffer_usage_names() -> Array[(String, UInt32)] {
  [
    ("MAP_READ", 0x0001U),
    ("MAP_WRITE", 0x0002U),
    ("COPY_SRC", 0x0004U),
    ("COPY_DST", 0x0008U),
    ("INDEX", 0x0010U),
    ("VERTEX", 0x0020U),
    ("UNIFORM", 0x0040U),
    ("STORAGE", 0x0080U),
    ("INDIRECT", 0x0100U),
    ("QUERY_RESOLVE", 0x0200U),
  ]
}

///|
/// The bit names of `GPUTextureUsage`, for the `got` field of a refusal.
pub fn texture_usage_names() -> Array[(String, UInt32)] {
  [
    ("COPY_SRC", 0x0001U),
    ("COPY_DST", 0x0002U),
    ("TEXTURE_BINDING", 0x0004U),
    ("STORAGE_BINDING", 0x0008U),
    ("RENDER_ATTACHMENT", 0x0010U),
  ]
}

///|
/// The rules a `GPUBufferDescriptor` must satisfy before a buffer exists.
/// https://www.w3.org/TR/webgpu/#dom-gpudevice-createbuffer "device timeline
/// initialization steps".
pub fn validate_buffer_descriptor(
  descriptor : @types.BufferDescriptor,
  limits : @types.Limits,
) -> Unit raise Refused {
  let bits = descriptor.usage.bits()
  require(
    bits != 0U,
    @types.InvalidBufferUsage,
    "descriptor.usage",
    "at least one flag",
    "none",
  )
  require(
    (bits & (0xFFFF_FFFFU ^ @types.BufferUsages::all().bits())) == 0U,
    @types.InvalidBufferUsage,
    "descriptor.usage",
    "only the flags GPUBufferUsage defines",
    describe_usages(bits, buffer_usage_names()),
  )
  let read = @types.BufferUsages::map_read().bits()
  let write = @types.BufferUsages::map_write().bits()
  let copy_dst = @types.BufferUsages::copy_dst().bits()
  let copy_src = @types.BufferUsages::copy_src().bits()
  if (bits & read) != 0U {
    require(
      (bits & (0xFFFF_FFFFU ^ (read | copy_dst))) == 0U,
      @types.InvalidBufferUsage,
      "descriptor.usage",
      "MAP_READ with at most COPY_DST",
      describe_usages(bits, buffer_usage_names()),
    )
  }
  if (bits & write) != 0U {
    require(
      (bits & (0xFFFF_FFFFU ^ (write | copy_src))) == 0U,
      @types.InvalidBufferUsage,
      "descriptor.usage",
      "MAP_WRITE with at most COPY_SRC",
      describe_usages(bits, buffer_usage_names()),
    )
  }
  require_int(
    descriptor.size >= 0,
    @types.InvalidBufferSize,
    "descriptor.size",
    0,
    descriptor.size,
  )
  require_int(
    descriptor.size <= limits.max_buffer_size,
    @types.LimitExceeded,
    "descriptor.size",
    limits.max_buffer_size,
    descriptor.size,
  )
  if descriptor.mapped_at_creation {
    require_int(
      descriptor.size % 4 == 0,
      @types.InvalidBufferSize,
      "descriptor.size",
      0,
      descriptor.size % 4,
    )
  }
}

///|
/// The range a copy or write addresses has to be inside the buffer, and its
/// offset aligned to four bytes.
/// https://www.w3.org/TR/webgpu/#buffer-copies
pub fn validate_buffer_range(
  size : Int32,
  offset : Int32,
  length : Int32,
  at : String,
) -> Unit raise Refused {
  require_int(
    offset >= 0 && length >= 0 && offset + length <= size,
    @types.InvalidCopyRange,
    at,
    size,
    offset + length,
  )
}
