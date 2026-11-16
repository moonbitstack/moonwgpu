// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "the whole feature list is the one the specification prints" {
  let names = []
  for feature in FeatureName::all() {
    names.push(feature.name())
  }
  assert_eq(names.length(), 25)
  assert_eq(names[0], "core-features-and-limits")
  assert_eq(names[2], "depth32float-stencil8")
  assert_eq(names[24], "atomic-vec2u-min-max")
}

///|
test "a feature set holds exactly what was put in it" {
  let features = Features::of(ShaderF16) | Features::of(TimestampQuery)
  assert_true(features.contains(ShaderF16))
  assert_true(features.contains(TimestampQuery))
  assert_false(features.contains(ClipDistances))
  assert_eq(features.names().length(), 2)
  assert_true(Features::none().is_empty())
  assert_eq(Features::all().names().length(), 25)
}

///|
test "features with dependencies name them" {
  let tier2 = TextureFormatsTier2.dependencies()
  assert_eq(tier2.length(), 1)
  assert_eq(tier2[0], TextureFormatsTier1)
  let tier1 = TextureFormatsTier1.dependencies()
  assert_eq(tier1[0], Rg11b10ufloatRenderable)
  assert_eq(
    TextureCompressionBcSliced3d.dependencies()[0],
    TextureCompressionBc,
  )
  assert_eq(
    TextureCompressionAstcSliced3d.dependencies()[0],
    TextureCompressionAstc,
  )
  assert_eq(ShaderF16.dependencies().length(), 0)
}

///|
test "contains_all is a subset test" {
  let a = Features::of(ShaderF16) | Features::of(Subgroups)
  let b = Features::of(ShaderF16)
  assert_true(a.contains_all(b))
  assert_false(b.contains_all(a))
  let empty = Features::none()
  assert_true(a.contains_all(empty))
}

///|
test "flag sets combine and subtract" {
  let usage = BufferUsages::vertex() |
    BufferUsages::index() |
    BufferUsages::copy_dst()
  assert_true(usage.contains(BufferUsages::vertex()))
  assert_true(usage.intersects(BufferUsages::index()))
  assert_false(usage.intersects(BufferUsages::storage()))
  let without_index = usage - BufferUsages::index()
  assert_false(without_index.contains(BufferUsages::index()))
  assert_true(without_index.contains(BufferUsages::vertex()))
  assert_true(BufferUsages::all().contains(usage))
}

///|
test "the usage bits are the constants the specification defines" {
  assert_eq(BufferUsages::map_read().bits(), 0x0001U)
  assert_eq(BufferUsages::map_write().bits(), 0x0002U)
  assert_eq(BufferUsages::copy_src().bits(), 0x0004U)
  assert_eq(BufferUsages::copy_dst().bits(), 0x0008U)
  assert_eq(BufferUsages::index().bits(), 0x0010U)
  assert_eq(BufferUsages::vertex().bits(), 0x0020U)
  assert_eq(BufferUsages::uniform().bits(), 0x0040U)
  assert_eq(BufferUsages::storage().bits(), 0x0080U)
  assert_eq(BufferUsages::indirect().bits(), 0x0100U)
  assert_eq(BufferUsages::query_resolve().bits(), 0x0200U)
  assert_eq(TextureUsages::render_attachment().bits(), 0x0010U)
  assert_eq(ShaderStages::compute().bits(), 0x0004U)
  assert_eq(ColorWrites::all().bits(), 0x000FU)
}
