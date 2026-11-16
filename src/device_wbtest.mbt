// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The public objects: what a caller holds, and what each call refuses.

///|
fn device() -> Device raise @core.Refused {
  let backend = @memory.Backend::new()
  Instance::new(backend~).request_adapter().request_device()
}

///|
test "an adapter offers what its backend offers" {
  let backend = @memory.Backend::with_capabilities({
    limits: @types.Limits::compatibility(),
    features: @types.Features::of(@types.TimestampQuery),
  })
  let adapter = Instance::new(backend~).request_adapter()
  assert_eq(adapter.limits().max_texture_dimension_2d, 4096)
  assert_true(adapter.features().contains(@types.TimestampQuery))
  assert_eq(adapter.info().description, "memory")
}

///|
test "asking for a feature the adapter does not offer is refused" {
  let backend = @memory.Backend::new()
  let adapter = Instance::new(backend~).request_adapter()
  try {
    adapter.request_device(
      descriptor=DeviceDescriptor::new(
        required_features=@types.Features::of(@types.ShaderF16),
      ),
    )
    |> ignore
    fail("shader-f16 is not offered by the memory backend")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.MissingFeature)
    _ => fail("wrong refusal")
  }
}

///|
test "asking for a feature without its dependency is refused" {
  let backend = @memory.Backend::with_capabilities({
    limits: @types.Limits::webgpu(),
    features: @types.Features::all(),
  })
  let adapter = Instance::new(backend~).request_adapter()
  try {
    adapter.request_device(
      descriptor=DeviceDescriptor::new(
        required_features=@types.Features::of(@types.TextureFormatsTier2),
      ),
    )
    |> ignore
    fail("texture-formats-tier2 depends on texture-formats-tier1")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.MissingFeature)
    _ => fail("wrong refusal")
  }
}

///|
test "asking for a feature with its dependency is accepted" {
  let backend = @memory.Backend::with_capabilities({
    limits: @types.Limits::webgpu(),
    features: @types.Features::all(),
  })
  let adapter = Instance::new(backend~).request_adapter()
  let features = @types.Features::of(@types.TextureFormatsTier2) |
    @types.Features::of(@types.TextureFormatsTier1) |
    @types.Features::of(@types.Rg11b10ufloatRenderable)
  let device = adapter.request_device(
    descriptor=DeviceDescriptor::new(required_features=features),
  )
  assert_true(device.features().contains(@types.TextureFormatsTier2))
}

///|
test "asking for a limit above the adapter's is refused" {
  let backend = @memory.Backend::new()
  let adapter = Instance::new(backend~).request_adapter()
  let wanted = { ..@types.Limits::webgpu(), max_texture_dimension_2d: 16384, }
  try {
    adapter.request_device(
      descriptor=DeviceDescriptor::new(required_limits=wanted),
    )
    |> ignore
    fail("16384 is above the default of 8192")
  } catch {
    @core.Refused::Validation(kind~, at~, want~, got~) => {
      assert_eq(kind, @types.LimitExceeded)
      assert_eq(at, "descriptor.requiredLimits.maxTextureDimension2D")
      assert_eq(want, "8192")
      assert_eq(got, "16384")
    }
    _ => fail("wrong refusal")
  }
}

///|
test "a device holds the limits it was created with" {
  let backend = @memory.Backend::new()
  let adapter = Instance::new(backend~).request_adapter()
  let device = adapter.request_device(
    descriptor=DeviceDescriptor::new(required_limits={
      ..@types.Limits::webgpu(),
      max_bind_groups: 2,
    }),
  )
  assert_eq(device.limits().max_bind_groups, 2)
  assert_eq(device.backend_name(), "memory")
}

///|
test "a buffer carries its size and usage" {
  let device = device()
  let buffer = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=64,
      usage=@types.BufferUsages::storage() | @types.BufferUsages::copy_dst(),
    ),
  )
  assert_eq(buffer.size(), 64)
  assert_true(buffer.usage().contains(@types.BufferUsages::storage()))
  assert_eq(buffer.is_mapped(), false)
}

///|
test "mapping reads the bytes a queue write put there" {
  let device = device()
  let buffer = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::copy_dst() | @types.BufferUsages::map_read(),
    ),
  )
  device.queue().write_buffer(buffer~, offset=0, data=b"\x01\x02\x03\x04")
  buffer.map_read()
  assert_eq(buffer.is_mapped(), true)
  let bytes = buffer.get_mapped_range()
  assert_eq(bytes[0], b'\x01')
  assert_eq(bytes[3], b'\x04')
  buffer.unmap()
  assert_eq(buffer.is_mapped(), false)
}

///|
test "a range that is not mapped cannot be read" {
  let device = device()
  let buffer = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::map_read(),
    ),
  )
  try {
    buffer.get_mapped_range() |> ignore
    fail("nothing is mapped yet")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidBufferState)
    _ => fail("wrong refusal")
  }
}

///|
test "mapping a buffer that lacks MAP_READ is refused" {
  let device = device()
  let buffer = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::vertex(),
    ),
  )
  try {
    buffer.map_read()
    fail("a vertex buffer is not readable")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidBufferUsage)
    _ => fail("wrong refusal")
  }
}

///|
test "a destroyed buffer refuses a second write" {
  let device = device()
  let buffer = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::copy_dst(),
    ),
  )
  buffer.destroy()
  try {
    device.queue().write_buffer(buffer~, offset=0, data=b"\x00\x00\x00\x00")
    fail("the buffer is gone")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidResource)
    _ => fail("wrong refusal")
  }
}

///|
test "a texture reports what it was made with" {
  let device = device()
  let texture = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=8, height=4),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::texture_binding(),
      mip_level_count=4,
    ),
  )
  assert_eq(texture.size().width, 8)
  assert_eq(texture.format(), @types.TextureFormat::Rgba8unorm)
  assert_eq(texture.mip_level_count(), 4)
  let view = texture.create_view()
  assert_eq(view.format(), @types.TextureFormat::Rgba8unorm)
  assert_eq(view.dimension(), @types.TextureViewDimension::D2)
}

///|
test "a view of a mip level reports the level's format" {
  let device = device()
  let texture = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=8, height=8),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::texture_binding(),
      mip_level_count=2,
    ),
  )
  let view = texture.create_view(
    descriptor=@types.TextureViewDescriptor::new(base_mip_level=1),
  )
  assert_eq(view.format(), @types.TextureFormat::Rgba8unorm)
}

///|
test "a sampler says whether it filters and compares" {
  let device = device()
  let nearest = device.create_sampler()
  assert_eq(nearest.is_filtering(), false)
  assert_eq(nearest.is_comparison(), false)
  let linear = device.create_sampler(
    descriptor=@types.SamplerDescriptor::new(
      mag_filter=@types.FilterMode::Linear,
    ),
  )
  assert_eq(linear.is_filtering(), true)
  let shadow = device.create_sampler(
    descriptor=@types.SamplerDescriptor::new(
      compare=@types.CompareFunction::Less,
    ),
  )
  assert_eq(shadow.is_comparison(), true)
}

///|
test "losing a device refuses the next creation" {
  let device = device()
  device.destroy()
  try {
    device.create_buffer(
      descriptor=@types.BufferDescriptor::new(
        size=16,
        usage=@types.BufferUsages::vertex(),
      ),
    )
    |> ignore
    fail("a lost device makes nothing")
  } catch {
    @core.Refused::DeviceLost(_) => ()
    _ => fail("wrong refusal")
  }
}
