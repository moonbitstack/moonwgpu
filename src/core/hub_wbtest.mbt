// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The hub against the memory backend: creation, mapping, submission, and the
// bookkeeping that refuses a resource that has been destroyed.

///|
fn memory_hub() -> (Hub, @memory.Backend) {
  let backend = @memory.Backend::new()
  let hub = Hub::new(backend, @types.Limits::webgpu(), @types.Features::none())
  (hub, backend)
}

///|
test "a buffer round trips through the queue" {
  let (hub, _) = memory_hub()
  let buffer = hub.create_buffer(
    @types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::copy_dst() | @types.BufferUsages::map_read(),
    ),
  )
  hub.write_buffer(buffer, 0, b"\x01\x02\x03\x04")
  let bytes = hub.read_buffer(buffer, 0, 16)
  assert_eq(bytes.length(), 16)
  assert_eq(bytes[0], b'\x01')
  assert_eq(bytes[3], b'\x04')
  assert_eq(bytes[4], b'\x00')
}

///|
test "a write outside a buffer is refused" {
  let (hub, _) = memory_hub()
  let buffer = hub.create_buffer(
    @types.BufferDescriptor::new(size=16, usage=@types.BufferUsages::copy_dst()),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      hub.write_buffer(buffer, 12, b"\x01\x02\x03\x04\x05\x06\x07\x08")
    }),
    Some(@types.InvalidCopyRange),
  )
}

///|
test "a write into a buffer without copy destination is refused" {
  let (hub, _) = memory_hub()
  let buffer = hub.create_buffer(
    @types.BufferDescriptor::new(size=16, usage=@types.BufferUsages::vertex()),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      hub.write_buffer(buffer, 0, b"\x00\x00\x00\x00")
    }),
    Some(@types.InvalidBufferUsage),
  )
}

///|
test "a destroyed buffer cannot be used again" {
  let (hub, _) = memory_hub()
  let buffer = hub.create_buffer(
    @types.BufferDescriptor::new(size=16, usage=@types.BufferUsages::copy_dst()),
  )
  hub.destroy_buffer(buffer)
  assert_eq(
    kind_of(fn() raise Refused {
      hub.write_buffer(buffer, 0, b"\x00\x00\x00\x00")
    }),
    Some(@types.InvalidResource),
  )
}

///|
test "a texture write lands on the texels the copy names" {
  let (hub, backend) = memory_hub()
  let texture = hub.create_texture(
    @types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=2, height=2),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::copy_dst(),
    ),
  )
  hub.write_texture(
    @types.TexelCopyTextureInfo::new(texture~),
    b"\xff\x00\x00\xff\x00\xff\x00\xff\x00\x00\xff\xff\xff\xff\xff\xff",
    @types.TexelCopyBufferLayout::new(
      offset=0,
      bytes_per_row=8,
      rows_per_image=2,
    ),
  )
  let texels = backend.texture_bytes(texture)
  assert_eq(texels[0], b'\xff')
  assert_eq(texels[1], b'\x00')
  assert_eq(texels[4], b'\x00')
  assert_eq(texels[5], b'\xff')
  assert_eq(texels[13], b'\xff')
}

///|
test "a texture write needs enough bytes for its rows" {
  let (hub, _) = memory_hub()
  let texture = hub.create_texture(
    @types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=2, height=2),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::copy_dst(),
    ),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      hub.write_texture(
        @types.TexelCopyTextureInfo::new(texture~),
        b"\xff\x00\x00\xff",
        @types.TexelCopyBufferLayout::new(offset=0, bytes_per_row=8),
      )
    }),
    Some(@types.InvalidCopyRange),
  )
}

///|
test "a command buffer that copies through the queue moves the bytes" {
  let (hub, _) = memory_hub()
  let source = hub.create_buffer(
    @types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::copy_src() | @types.BufferUsages::copy_dst(),
    ),
  )
  let destination = hub.create_buffer(
    @types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::copy_dst() | @types.BufferUsages::map_read(),
    ),
  )
  hub.write_buffer(
    source, 0, b"\x0a\x0b\x0c\x0d\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  )
  hub.submit([
    @types.Command::CopyBufferToBuffer({
      source,
      source_offset: 0,
      destination,
      destination_offset: 4,
      size: 4,
    }),
  ])
  let bytes = hub.read_buffer(destination, 0, 16)
  assert_eq(bytes[3], b'\x00')
  assert_eq(bytes[4], b'\x0a')
  assert_eq(bytes[7], b'\x0d')
}

///|
test "a submit that breaks a rule moves nothing" {
  let (hub, _) = memory_hub()
  let source = hub.create_buffer(
    @types.BufferDescriptor::new(size=16, usage=@types.BufferUsages::vertex()),
  )
  let destination = hub.create_buffer(
    @types.BufferDescriptor::new(size=16, usage=@types.BufferUsages::copy_dst()),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      hub.submit([
        @types.Command::CopyBufferToBuffer({
          source,
          source_offset: 0,
          destination,
          destination_offset: 0,
          size: 16,
        }),
      ])
    }),
    Some(@types.InvalidBufferUsage),
  )
}

///|
test "the device reports the limits and features it was built with" {
  let (hub, _) = memory_hub()
  assert_eq(hub.limits().max_bind_groups, 4)
  assert_true(hub.features().is_empty())
  assert_eq(hub.backend_name(), "memory")
}

///|
test "losing the device refuses everything afterwards" {
  let (hub, _) = memory_hub()
  hub.lose()
  try {
    hub.ensure_alive()
    fail("a lost device must refuse")
  } catch {
    DeviceLost(_) => ()
    _ => fail("the refusal has to be a device loss")
  }
}
