// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The rest of the specification's surface: the canvas format, the asynchronous
// pipeline forms, compilation info, immediates, and external textures.

///|
fn refusal_kind(run : () -> Unit raise @core.Refused) -> @types.ErrorKind? {
  try {
    run()
    None
  } catch {
    @core.Refused::Validation(kind~, ..) => Some(kind)
    _ => None
  }
}

///|
fn compute_module(device : Device) -> ShaderModule raise @core.Refused {
  device.create_shader_module(
    descriptor=@types.ShaderModuleDescriptor::wgsl(
      source="@compute @workgroup_size(1) fn main() {}",
    ),
  )
}

///|
test "the preferred canvas format is the one a surface takes" {
  let backend = @memory.Backend::new()
  let instance = Instance::new(backend~)
  assert_eq(
    instance.get_preferred_canvas_format(),
    @types.TextureFormat::Bgra8unorm,
  )
  assert_eq(instance.get_preferred_canvas_format().name(), "bgra8unorm")
}

///|
test "a destroyed device says so and refuses work" {
  let device = device()
  assert_false(device.destroyed())
  device.destroy()
  assert_true(device.destroyed())
  try {
    device.create_buffer(
      descriptor=@types.BufferDescriptor::new(
        size=16,
        usage=@types.BufferUsages::copy_dst(),
      ),
    )
    |> ignore
    fail("a destroyed device still made a buffer")
  } catch {
    @core.Refused::DeviceLost(_) => ()
    _ => fail("wrong refusal")
  }
}

///|
test "the asynchronous pipeline form builds the same pipeline" {
  let device = device()
  let shader = compute_module(device)
  let descriptor = @types.ComputePipelineDescriptor::new(
    shader=shader.id(),
    entry_point="main",
    label="sum",
  )
  let pipeline = device.create_compute_pipeline_async(descriptor~)
  assert_eq(pipeline.label(), "sum")
  assert_true(pipeline.id().raw() > 0UL)
}

///|
test "a module without a compiler reports no message" {
  let device = device()
  let shader = compute_module(device)
  let info = shader.get_compilation_info()
  assert_eq(info.messages.length(), 0)
  assert_false(info.has_errors())
}

///|
test "immediates are recorded where the caller put them" {
  let device = device()
  let shader = compute_module(device)
  let pipeline = device.create_compute_pipeline(
    descriptor=@types.ComputePipelineDescriptor::new(
      shader=shader.id(),
      entry_point="main",
    ),
  )
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_compute_pass()
  pass.set_pipeline(pipeline~)
  pass.set_immediates(range_offset=0, data=b"\x01\x00\x00\x00\x02\x00\x00\x00")
  pass.end()
  let buffer = encoder.finish()
  device.queue().submit(command_buffers=[buffer])
  assert_eq(buffer.commands.length(), 1)
}

///|
test "immediates must start on a word boundary" {
  let device = device()
  let shader = compute_module(device)
  let pipeline = device.create_compute_pipeline(
    descriptor=@types.ComputePipelineDescriptor::new(
      shader=shader.id(),
      entry_point="main",
    ),
  )
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_compute_pass()
  pass.set_pipeline(pipeline~)
  assert_eq(
    refusal_kind(fn() raise @core.Refused {
      pass.set_immediates(range_offset=2, data=b"\x01\x00\x00\x00")
    }),
    Some(@types.InvalidAlignment),
  )
}

///|
test "an imported frame is held until it expires" {
  let backend = @memory.Backend::new()
  let device = Instance::new(backend~).request_adapter().request_device()
  let image = @types.ExternalImage::new(
    size=@types.Extent3d::new(width=2, height=1),
    format=@types.TextureFormat::Rgba8unorm,
    data=b"\xff\x00\x00\xff\x00\xff\x00\xff",
  )
  let texture = device.import_external_texture(
    descriptor=@types.ExternalTextureDescriptor::new(image~, label="frame"),
  )
  assert_eq(texture.label(), "frame")
  assert_false(texture.is_expired())
  assert_eq(texture.color_space(), @types.PredefinedColorSpace::Srgb)
  texture.expire()
  assert_true(texture.is_expired())
}

///|
test "an imported frame with too few bytes is refused" {
  let backend = @memory.Backend::new()
  let device = Instance::new(backend~).request_adapter().request_device()
  assert_eq(
    refusal_kind(fn() raise @core.Refused {
      device.import_external_texture(
        descriptor=@types.ExternalTextureDescriptor::new(
          image=@types.ExternalImage::new(
            size=@types.Extent3d::new(width=2, height=2),
            format=@types.TextureFormat::Rgba8unorm,
            data=b"\xff\x00\x00\xff",
          ),
        ),
      )
      |> ignore
    }),
    Some(@types.InvalidCopyRange),
  )
}

///|
test "an external image lands in the texture it names" {
  let backend = @memory.Backend::new()
  let device = Instance::new(backend~).request_adapter().request_device()
  let texture = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=2, height=2),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::copy_dst() | @types.TextureUsages::copy_src(),
    ),
  )
  let image = @types.ExternalImage::new(
    size=@types.Extent3d::new(width=2, height=2),
    format=@types.TextureFormat::Rgba8unorm,
    data=b"\x01\x02\x03\xff\x04\x05\x06\xff\x07\x08\x09\xff\x0a\x0b\x0c\xff",
  )
  device
  .queue()
  .copy_external_image_to_texture(
    source=@types.CopyExternalImageSourceInfo::new(image~),
    destination=@types.CopyExternalImageDestInfo::new(texture=texture.id()),
    copy_size=@types.Extent3d::new(width=2, height=2),
  )
  let texels = backend.texture_bytes(texture.id())
  assert_eq(texels[0], b'\x01')
  assert_eq(texels[3], b'\xff')
  assert_eq(texels[8], b'\x07')
  assert_eq(texels[12], b'\x0a')
}

///|
test "flipping an external image turns its rows over" {
  let backend = @memory.Backend::new()
  let device = Instance::new(backend~).request_adapter().request_device()
  let texture = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=1, height=2),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::copy_dst(),
    ),
  )
  let image = @types.ExternalImage::new(
    size=@types.Extent3d::new(width=1, height=2),
    format=@types.TextureFormat::Rgba8unorm,
    data=b"\x01\x01\x01\xff\x02\x02\x02\xff",
  )
  device
  .queue()
  .copy_external_image_to_texture(
    source=@types.CopyExternalImageSourceInfo::new(image~, flip_y=true),
    destination=@types.CopyExternalImageDestInfo::new(texture=texture.id()),
    copy_size=@types.Extent3d::new(width=1, height=2),
  )
  let texels = backend.texture_bytes(texture.id())
  assert_eq(texels[0], b'\x02')
  assert_eq(texels[4], b'\x01')
}

///|
test "premultiplying an external image scales its colour by its alpha" {
  let backend = @memory.Backend::new()
  let device = Instance::new(backend~).request_adapter().request_device()
  let texture = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=1, height=1),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::copy_dst(),
    ),
  )
  let image = @types.ExternalImage::new(
    size=@types.Extent3d::new(width=1, height=1),
    format=@types.TextureFormat::Rgba8unorm,
    data=b"\xff\x80\x40\x80",
  )
  device
  .queue()
  .copy_external_image_to_texture(
    source=@types.CopyExternalImageSourceInfo::new(image~),
    destination=@types.CopyExternalImageDestInfo::new(
      texture=texture.id(),
      premultiplied_alpha=true,
    ),
    copy_size=@types.Extent3d::new(width=1, height=1),
  )
  let texels = backend.texture_bytes(texture.id())
  assert_eq(texels[0], b'\x80')
  assert_eq(texels[1], b'\x40')
  assert_eq(texels[2], b'\x20')
  assert_eq(texels[3], b'\x80')
}
