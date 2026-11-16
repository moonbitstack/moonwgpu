// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "vertex sizes are the byteSize column" {
  assert_eq(VertexFormat::Uint8.size(), 1)
  assert_eq(VertexFormat::Uint8x4.size(), 4)
  assert_eq(VertexFormat::Float16x2.size(), 4)
  assert_eq(VertexFormat::Float32x3.size(), 12)
  assert_eq(VertexFormat::Float32x4.size(), 16)
  assert_eq(VertexFormat::Unorm1010102.size(), 4)
  assert_eq(VertexFormat::Unorm8x4Bgra.size(), 4)
  assert_eq(VertexFormat::Snorm1010102.size(), 4)
}

///|
test "component counts and data types" {
  assert_eq(VertexFormat::Float32x3.components(), 3)
  assert_eq(VertexFormat::Float32x3.info().data_type, VertexDataType::Float)
  assert_eq(VertexFormat::Uint16x2.info().data_type, VertexDataType::Uint)
  assert_eq(VertexFormat::Sint8.info().data_type, VertexDataType::Sint)
  assert_eq(VertexFormat::Unorm8x4.info().data_type, VertexDataType::Unorm)
  assert_eq(VertexFormat::Snorm16.info().data_type, VertexDataType::Snorm)
}

///|
test "an attribute offset aligns to the smaller of four and the attribute" {
  assert_eq(VertexFormat::Uint8.alignment(), 1)
  assert_eq(VertexFormat::Uint8x2.alignment(), 2)
  assert_eq(VertexFormat::Uint8x4.alignment(), 4)
  assert_eq(VertexFormat::Float32x3.alignment(), 4)
  assert_eq(VertexFormat::Float16.alignment(), 2)
}

///|
test "every vertex format round trips through its name" {
  let formats = VertexFormat::all()
  assert_eq(formats.length(), 42)
  assert_eq(VertexFormat::Unorm1010102.name(), "unorm10-10-10-2")
  assert_eq(VertexFormat::Snorm1010102.name(), "snorm10-10-10-2")
  assert_eq(VertexFormat::Unorm8x4Bgra.name(), "unorm8x4-bgra")
  assert_eq(VertexFormat::Float32.name(), "float32")
  for format in formats {
    assert_true(!format.name().is_empty())
  }
}

///|
test "mip level counts follow the largest dimension" {
  let size = Extent3d::new(width=8, height=4)
  assert_eq(size.max_mip_level_count(), 4)
  assert_eq(Extent3d::new(width=1, height=1).max_mip_level_count(), 1)
  assert_eq(Extent3d::new(width=7, height=3).max_mip_level_count(), 3)
  assert_eq(
    Extent3d::new(width=4, height=4, depth_or_array_layers=16).max_mip_level_count(),
    5,
  )
}

///|
test "a mip level rounds its size up to whole texel blocks" {
  let size = Extent3d::new(width=9, height=9)
  let level0 = size.physical_size(mip_level=0, format=TextureFormat::Rgba8unorm)
  assert_eq(level0.width, 9)
  let level1 = size.physical_size(mip_level=1, format=TextureFormat::Rgba8unorm)
  assert_eq(level1.width, 4)
  let compressed = size.physical_size(
    mip_level=0,
    format=TextureFormat::Bc1RgbaUnorm,
  )
  // Three blocks of four texels to cover nine.
  assert_eq(compressed.width, 12)
  assert_eq(compressed.height, 12)
}

///|
test "zero sized extents are empty" {
  assert_true(Extent3d::new(width=0, height=1).is_empty())
  assert_false(Extent3d::new(width=1, height=1).is_empty())
}

///|
test "the default sampler descriptor is the one the specification describes" {
  let sampler = SamplerDescriptor::new()
  assert_eq(sampler.address_mode_u, AddressMode::ClampToEdge)
  assert_eq(sampler.mag_filter, FilterMode::Nearest)
  assert_eq(sampler.mipmap_filter, FilterMode::Nearest)
  assert_eq(sampler.lod_max_clamp, 32.0)
  assert_eq(sampler.max_anisotropy, 1)
  assert_true(sampler.compare is None)
}

///|
test "the default texture descriptor is one mip, one sample, two dimensional" {
  let descriptor = TextureDescriptor::new(
    size=Extent3d::new(width=4, height=4),
    format=TextureFormat::Rgba8unorm,
    usage=TextureUsages::texture_binding(),
  )
  assert_eq(descriptor.mip_level_count, 1)
  assert_eq(descriptor.sample_count, 1)
  assert_eq(descriptor.dimension, TextureDimension::D2)
  assert_eq(descriptor.view_formats.length(), 0)
}
