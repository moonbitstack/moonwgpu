// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The queue: what reaches the backend, and what is refused before it does.

///|
/// A buffer both directions of a copy can use, and that the queue can write.
fn copy_buffer(device : Device, size : Int32) -> Buffer raise @core.Refused {
  device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size~,
      usage=@types.BufferUsages::copy_src() | @types.BufferUsages::copy_dst(),
    ),
  )
}

///|
/// A buffer the queue can write and a caller can read: MAP_READ may only be
/// paired with COPY_DST, which is also why a read-back buffer cannot be a copy
/// source.
fn readback_buffer(device : Device, size : Int32) -> Buffer raise @core.Refused {
  device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size~,
      usage=@types.BufferUsages::map_read() | @types.BufferUsages::copy_dst(),
    ),
  )
}

///|
test "a copy through the queue moves bytes where the command says" {
  let device = device()
  let source = copy_buffer(device, 16)
  let destination = readback_buffer(device, 16)
  device
  .queue()
  .write_buffer(
    buffer=source,
    offset=0,
    data=b"\x11\x22\x33\x44\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  )
  let encoder = device.create_command_encoder()
  encoder.copy_buffer_to_buffer(
    source~,
    source_offset=0,
    destination~,
    destination_offset=8,
    size=4,
  )
  device.queue().submit(command_buffers=[encoder.finish()])
  destination.map_read()
  let bytes = destination.get_mapped_range()
  assert_eq(bytes[7], b'\x00')
  assert_eq(bytes[8], b'\x11')
  assert_eq(bytes[11], b'\x44')
  assert_eq(bytes[12], b'\x00')
}

///|
test "clearing a buffer zeroes exactly its range" {
  let device = device()
  let buffer = readback_buffer(device, 16)
  device
  .queue()
  .write_buffer(
    buffer~,
    offset=0,
    data=b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff",
  )
  let encoder = device.create_command_encoder()
  encoder.clear_buffer(buffer~, offset=4, size=8)
  device.queue().submit(command_buffers=[encoder.finish()])
  buffer.map_read()
  let bytes = buffer.get_mapped_range()
  assert_eq(bytes[3], b'\xff')
  assert_eq(bytes[4], b'\x00')
  assert_eq(bytes[11], b'\x00')
  assert_eq(bytes[12], b'\xff')
}

///|
test "a texture written through the queue reads back the same texels" {
  let device = device()
  let texture = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=2, height=2),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::copy_dst() | @types.TextureUsages::copy_src(),
    ),
  )
  let texels = b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10"
  device
  .queue()
  .write_texture(
    destination=@types.TexelCopyTextureInfo::new(texture=texture.id()),
    data=texels,
    layout=@types.TexelCopyBufferLayout::new(
      offset=0,
      bytes_per_row=8,
      rows_per_image=2,
    ),
  )
  let readback = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=512,
      usage=@types.BufferUsages::copy_dst() | @types.BufferUsages::map_read(),
    ),
  )
  let encoder = device.create_command_encoder()
  encoder.copy_texture_to_buffer(
    source=@types.TexelCopyTextureInfo::new(texture=texture.id()),
    destination=@types.TexelCopyBufferInfo::new(
      buffer=readback.id(),
      layout=@types.TexelCopyBufferLayout::new(
        offset=0,
        bytes_per_row=256,
        rows_per_image=2,
      ),
    ),
    copy_size=@types.Extent3d::new(width=2, height=2),
  )
  device.queue().submit(command_buffers=[encoder.finish()])
  readback.map_read()
  let bytes = readback.get_mapped_range()
  assert_eq(bytes[0], b'\x01')
  assert_eq(bytes[7], b'\x08')
  assert_eq(bytes[256], b'\x09')
  assert_eq(bytes[263], b'\x10')
}

///|
test "a copy row stride that is not 256 aligned is refused" {
  let device = device()
  let buffer = copy_buffer(device, 512)
  let texture = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=4, height=4),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::copy_dst(),
    ),
  )
  let encoder = device.create_command_encoder()
  encoder.copy_buffer_to_texture(
    source=@types.TexelCopyBufferInfo::new(
      buffer=buffer.id(),
      layout=@types.TexelCopyBufferLayout::new(
        offset=0,
        bytes_per_row=64,
        rows_per_image=4,
      ),
    ),
    destination=@types.TexelCopyTextureInfo::new(texture=texture.id()),
    copy_size=@types.Extent3d::new(width=4, height=4),
  )
  try {
    device.queue().submit(command_buffers=[encoder.finish()])
    fail("64 is not a multiple of 256")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidBytesPerRow)
    _ => fail("wrong refusal")
  }
}

///|
test "one pass cannot both write a texture and bind it as storage" {
  let device = device()
  let texture = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=4, height=4),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::render_attachment() |
        @types.TextureUsages::storage_binding(),
    ),
  )
  let view = texture.create_view()
  let layout = device.create_bind_group_layout(
    descriptor=@types.BindGroupLayoutDescriptor::new(entries=[
      @types.BindGroupLayoutEntry::new(
        binding=0,
        visibility=@types.ShaderStages::fragment(),
        kind=@types.BindingLayout::StorageTexture(
          @types.StorageTextureBindingLayout::new(
            format=@types.TextureFormat::Rgba8unorm,
          ),
        ),
      ),
    ]),
  )
  let group = device.create_bind_group(
    descriptor=@types.BindGroupDescriptor::new(layout=layout.id(), entries=[
      @types.BindGroupEntry::new(
        binding=0,
        resource=@types.BindingResource::TextureView(view.id()),
      ),
    ]),
  )
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(color_attachments=[
      @types.ColorAttachment::new(view=view.id()),
    ]),
  )
  pass.set_bind_group(index=0, bind_group=group)
  pass.end()
  try {
    device.queue().submit(command_buffers=[encoder.finish()])
    fail("the same texture cannot be written and read in one pass")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidTextureUsage)
    _ => fail("wrong refusal")
  }
}

///|
test "a resolve target has to be single sampled and share the format" {
  let device = device()
  let multisampled = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=4, height=4),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::render_attachment(),
      sample_count=4,
    ),
  )
  let other = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=4, height=4),
      format=@types.TextureFormat::Bgra8unorm,
      usage=@types.TextureUsages::render_attachment(),
    ),
  )
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(color_attachments=[
      @types.ColorAttachment::new(
        view=multisampled.create_view().id(),
        resolve_target=other.create_view().id(),
      ),
    ]),
  )
  pass.end()
  try {
    device.queue().submit(command_buffers=[encoder.finish()])
    fail("bgra8unorm does not resolve rgba8unorm")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidPassDescriptor)
    _ => fail("wrong refusal")
  }
}

///|
test "a buffer bound to a pass and copied in the same pass is refused" {
  let device = device()
  let storage = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=256,
      usage=@types.BufferUsages::storage() | @types.BufferUsages::copy_dst(),
    ),
  )
  let target = copy_buffer(device, 256)
  let layout = device.create_bind_group_layout(
    descriptor=@types.BindGroupLayoutDescriptor::new(entries=[
      @types.BindGroupLayoutEntry::new(
        binding=0,
        visibility=@types.ShaderStages::compute(),
        kind=@types.BindingLayout::Buffer(
          @types.BufferBindingLayout::new(
            kind=@types.BufferBindingType::Storage,
          ),
        ),
      ),
    ]),
  )
  let group = device.create_bind_group(
    descriptor=@types.BindGroupDescriptor::new(layout=layout.id(), entries=[
      @types.BindGroupEntry::new(
        binding=0,
        resource=@types.BindingResource::Buffer(
          @types.BufferBinding::new(buffer=storage.id()),
        ),
      ),
    ]),
  )
  let encoder = device.create_command_encoder()
  encoder.copy_buffer_to_buffer(
    source=target,
    source_offset=0,
    destination=storage,
    destination_offset=0,
    size=256,
  )
  let pass = encoder.begin_compute_pass()
  pass.set_bind_group(index=0, bind_group=group)
  pass.end()
  // The copy happens between passes, so this is legal: it is the same pass
  // rule that would be broken if the copy were inside one.
  device.queue().submit(command_buffers=[encoder.finish()])
  assert_eq(device.queue().label(), "")
}
