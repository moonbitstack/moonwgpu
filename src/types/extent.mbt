// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A size in texels: `GPUExtent3D`.
#derive(Eq, Debug)
pub(all) struct Extent3d {
  width : Int32
  height : Int32
  depth_or_array_layers : Int32
}

///|
pub fn Extent3d::new(
  width~ : Int32,
  height~ : Int32 = 1,
  depth_or_array_layers~ : Int32 = 1,
) -> Extent3d {
  { width, height, depth_or_array_layers, }
}

///|
/// A texel position inside a texture: `GPUOrigin3D`.
#derive(Eq, Debug)
pub(all) struct Origin3d {
  x : Int32
  y : Int32
  z : Int32
}

///|
pub fn Origin3d::new(
  x~ : Int32 = 0,
  y~ : Int32 = 0,
  z~ : Int32 = 0,
) -> Origin3d {
  { x, y, z, }
}

///|
/// A colour, `GPUColor`.
#derive(Eq, Debug)
pub(all) struct Color {
  r : Double
  g : Double
  b : Double
  a : Double
}

///|
pub fn Color::new(
  r~ : Double = 0.0,
  g~ : Double = 0.0,
  b~ : Double = 0.0,
  a~ : Double = 1.0,
) -> Color {
  { r, g, b, a, }
}

///|
/// Opaque black, the value a colour attachment clears to when the descriptor
/// does not say.
pub fn Color::black() -> Color {
  Color::new()
}

///|
/// Whether any dimension is zero. A zero-sized texture or copy is valid and
/// does nothing.
pub fn Extent3d::is_empty(self : Extent3d) -> Bool {
  self.width == 0 || self.height == 0 || self.depth_or_array_layers == 0
}

///|
/// The number of mip levels a texture of this size can have: one more than the
/// base-2 logarithm of its largest dimension.
pub fn Extent3d::max_mip_level_count(self : Extent3d) -> Int32 {
  let largest = if self.width > self.height { self.width } else { self.height }
  let largest = if largest > self.depth_or_array_layers {
    largest
  } else {
    self.depth_or_array_layers
  }
  if largest <= 0 {
    return 1
  }
  let mut levels = 1
  let mut size = largest
  while size > 1 {
    size = size / 2
    levels = levels + 1
  }
  levels
}

///|
/// The size of one mip level in texels, rounded up to whole texel blocks of
/// `format`. This is the "physical size" the specification's copy validation
/// works in.
pub fn Extent3d::physical_size(
  self : Extent3d,
  mip_level~ : Int32,
  format~ : TextureFormat,
) -> Extent3d {
  let info = format.info()
  let shift = mip_level
  let width = if self.width >> shift > 0 { self.width >> shift } else { 1 }
  let height = if self.height >> shift > 0 { self.height >> shift } else { 1 }
  let depth = if self.depth_or_array_layers >> shift > 0 {
    self.depth_or_array_layers >> shift
  } else {
    1
  }
  let rounded = fn(size : Int32, block : Int32) {
    if size == 0 {
      0
    } else {
      (size + block - 1) / block * block
    }
  }
  {
    width: rounded(width, info.block_width),
    height: rounded(height, info.block_height),
    depth_or_array_layers: depth,
  }
}

///|
/// The bytes one row of `width` texels of `format` occupies before padding,
/// not counting the 256-byte alignment a copy imposes.
pub fn TextureFormat::bytes_per_row(
  self : TextureFormat,
  width~ : Int32,
) -> Int32 {
  let info = self.info()
  let blocks = (width + info.block_width - 1) / info.block_width
  blocks * info.bytes_per_block
}
