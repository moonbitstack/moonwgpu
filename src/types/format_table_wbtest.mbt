// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The format table is checked against the invariants the specification's own
// table has: every format names a texel block, a copy footprint and a sample
// type, and the features it needs are the ones the capability tables print.

///|
test "every format has a texel block and a copy footprint" {
  for format in TextureFormat::all() {
    let info = format.info()
    assert_true(info.block_width >= 1)
    assert_true(info.block_height >= 1)
    assert_true(info.bytes_per_block > 0)
  }
}

///|
test "every format reports the name it is printed with" {
  for format in TextureFormat::all() {
    let name = format.name()
    assert_true(!name.is_empty())
  }
}

///|
test "block compressed formats are four texels wide and carry a feature" {
  for format in TextureFormat::all() {
    let info = format.info()
    if info.block_width > 1 || info.block_height > 1 {
      assert_true(info.block_width >= 4)
      assert_true(info.feature is Some(_))
      assert_eq(info.render_attachment, false)
      assert_eq(info.multisample, false)
      assert_eq(info.storage, StorageAccess::None)
    }
  }
}

///|
test "uncompressed colour formats are one texel per block" {
  for format in TextureFormat::all() {
    let info = format.info()
    let is_compressed = info.feature is Some(_) &&
      (info.block_width > 1 || info.block_height > 1)
    if !is_compressed && info.aspect == FormatAspect::Color {
      assert_eq(info.block_width, 1)
      assert_eq(info.block_height, 1)
    }
  }
}

///|
test "depth and stencil formats are never render targets of a colour pass" {
  for format in TextureFormat::all() {
    let info = format.info()
    if info.aspect != FormatAspect::Color {
      assert_eq(info.render_attachment, false)
    }
  }
}

///|
test "multisampled formats are the ones the table marks" {
  assert_true(TextureFormat::Rgba8unorm.info().multisample)
  assert_true(TextureFormat::Depth32float.info().multisample)
  assert_false(TextureFormat::Rgba32float.info().multisample)
  assert_false(TextureFormat::Bc1RgbaUnorm.info().multisample)
}

///|
test "storage capability follows the plain colour formats table" {
  assert_eq(TextureFormat::Rgba8unorm.info().storage, StorageAccess::Both)
  assert_eq(TextureFormat::Rgba8unormSrgb.info().storage, StorageAccess::None)
  assert_eq(TextureFormat::Bgra8unorm.info().storage, StorageAccess::None)
  assert_eq(TextureFormat::R32float.info().storage, StorageAccess::Both)
}

///|
test "bytes per row rounds up to whole texel blocks" {
  assert_eq(TextureFormat::Rgba8unorm.bytes_per_row(width=4), 16)
  assert_eq(TextureFormat::Rgba8unorm.bytes_per_row(width=1), 4)
  assert_eq(TextureFormat::R8unorm.bytes_per_row(width=7), 7)
  // One block of BC1 holds four by four texels in eight bytes.
  assert_eq(TextureFormat::Bc1RgbaUnorm.bytes_per_row(width=4), 8)
  assert_eq(TextureFormat::Bc1RgbaUnorm.bytes_per_row(width=5), 16)
}

///|
test "depth24plus cannot be copied at all" {
  let info = TextureFormat::Depth24plus.info()
  assert_eq(info.copy_src, false)
  assert_eq(info.copy_dst, false)
}

///|
test "depth32float is a copy source but not a destination" {
  let info = TextureFormat::Depth32float.info()
  assert_eq(info.copy_src, true)
  assert_eq(info.copy_dst, false)
}

///|
test "the three feature gated formats name their feature" {
  match TextureFormat::Depth32floatStencil8.info().feature {
    Some(feature) => assert_eq(feature, Depth32floatStencil8)
    None => fail("depth32float-stencil8 needs its feature")
  }
  match TextureFormat::Rg11b10ufloat.info().feature {
    Some(feature) => assert_eq(feature, Rg11b10ufloatRenderable)
    None => fail("rg11b10ufloat needs its feature")
  }
  assert_true(TextureFormat::Rgba8unorm.info().feature is None)
}
