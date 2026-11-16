// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A `GPUTextureFormat`: the texel layout of a texture.
///
/// The list follows the enumeration the specification prints, in the same
/// order, so that a reader can compare the two side by side.
/// https://www.w3.org/TR/webgpu/#enumdef-gputextureformat
#derive(Eq, Debug)
pub(all) enum TextureFormat {
  R8unorm
  R8snorm
  R8uint
  R8sint
  R16unorm
  R16snorm
  R16uint
  R16sint
  R16float
  Rg8unorm
  Rg8snorm
  Rg8uint
  Rg8sint
  R32uint
  R32sint
  R32float
  Rg16unorm
  Rg16snorm
  Rg16uint
  Rg16sint
  Rg16float
  Rgba8unorm
  Rgba8unormSrgb
  Rgba8snorm
  Rgba8uint
  Rgba8sint
  Bgra8unorm
  Bgra8unormSrgb
  Rgb9e5ufloat
  Rgb10a2uint
  Rgb10a2unorm
  Rg11b10ufloat
  Rg32uint
  Rg32sint
  Rg32float
  Rgba16unorm
  Rgba16snorm
  Rgba16uint
  Rgba16sint
  Rgba16float
  Rgba32uint
  Rgba32sint
  Rgba32float
  Stencil8
  Depth16unorm
  Depth24plus
  Depth24plusStencil8
  Depth32float
  Depth32floatStencil8
  Bc1RgbaUnorm
  Bc1RgbaUnormSrgb
  Bc2RgbaUnorm
  Bc2RgbaUnormSrgb
  Bc3RgbaUnorm
  Bc3RgbaUnormSrgb
  Bc4RUnorm
  Bc4RSnorm
  Bc5RgUnorm
  Bc5RgSnorm
  Bc6hRgbUfloat
  Bc6hRgbFloat
  Bc7RgbaUnorm
  Bc7RgbaUnormSrgb
  Etc2Rgb8unorm
  Etc2Rgb8unormSrgb
  Etc2Rgb8a1unorm
  Etc2Rgb8a1unormSrgb
  Etc2Rgba8unorm
  Etc2Rgba8unormSrgb
  EacR11unorm
  EacR11snorm
  EacRg11unorm
  EacRg11snorm
  Astc4x4Unorm
  Astc4x4UnormSrgb
  Astc5x4Unorm
  Astc5x4UnormSrgb
  Astc5x5Unorm
  Astc5x5UnormSrgb
  Astc6x5Unorm
  Astc6x5UnormSrgb
  Astc6x6Unorm
  Astc6x6UnormSrgb
  Astc8x5Unorm
  Astc8x5UnormSrgb
  Astc8x6Unorm
  Astc8x6UnormSrgb
  Astc8x8Unorm
  Astc8x8UnormSrgb
  Astc10x5Unorm
  Astc10x5UnormSrgb
  Astc10x6Unorm
  Astc10x6UnormSrgb
  Astc10x8Unorm
  Astc10x8UnormSrgb
  Astc10x10Unorm
  Astc10x10UnormSrgb
  Astc12x10Unorm
  Astc12x10UnormSrgb
  Astc12x12Unorm
  Astc12x12UnormSrgb
}

///|
/// The format string the specification uses, as in `"rgba8unorm"`.
pub fn TextureFormat::name(self : TextureFormat) -> String {
  match self {
    R8unorm => "r8unorm"
    R8snorm => "r8snorm"
    R8uint => "r8uint"
    R8sint => "r8sint"
    R16unorm => "r16unorm"
    R16snorm => "r16snorm"
    R16uint => "r16uint"
    R16sint => "r16sint"
    R16float => "r16float"
    Rg8unorm => "rg8unorm"
    Rg8snorm => "rg8snorm"
    Rg8uint => "rg8uint"
    Rg8sint => "rg8sint"
    R32uint => "r32uint"
    R32sint => "r32sint"
    R32float => "r32float"
    Rg16unorm => "rg16unorm"
    Rg16snorm => "rg16snorm"
    Rg16uint => "rg16uint"
    Rg16sint => "rg16sint"
    Rg16float => "rg16float"
    Rgba8unorm => "rgba8unorm"
    Rgba8unormSrgb => "rgba8unorm-srgb"
    Rgba8snorm => "rgba8snorm"
    Rgba8uint => "rgba8uint"
    Rgba8sint => "rgba8sint"
    Bgra8unorm => "bgra8unorm"
    Bgra8unormSrgb => "bgra8unorm-srgb"
    Rgb9e5ufloat => "rgb9e5ufloat"
    Rgb10a2uint => "rgb10a2uint"
    Rgb10a2unorm => "rgb10a2unorm"
    Rg11b10ufloat => "rg11b10ufloat"
    Rg32uint => "rg32uint"
    Rg32sint => "rg32sint"
    Rg32float => "rg32float"
    Rgba16unorm => "rgba16unorm"
    Rgba16snorm => "rgba16snorm"
    Rgba16uint => "rgba16uint"
    Rgba16sint => "rgba16sint"
    Rgba16float => "rgba16float"
    Rgba32uint => "rgba32uint"
    Rgba32sint => "rgba32sint"
    Rgba32float => "rgba32float"
    Stencil8 => "stencil8"
    Depth16unorm => "depth16unorm"
    Depth24plus => "depth24plus"
    Depth24plusStencil8 => "depth24plus-stencil8"
    Depth32float => "depth32float"
    Depth32floatStencil8 => "depth32float-stencil8"
    Bc1RgbaUnorm => "bc1-rgba-unorm"
    Bc1RgbaUnormSrgb => "bc1-rgba-unorm-srgb"
    Bc2RgbaUnorm => "bc2-rgba-unorm"
    Bc2RgbaUnormSrgb => "bc2-rgba-unorm-srgb"
    Bc3RgbaUnorm => "bc3-rgba-unorm"
    Bc3RgbaUnormSrgb => "bc3-rgba-unorm-srgb"
    Bc4RUnorm => "bc4-r-unorm"
    Bc4RSnorm => "bc4-r-snorm"
    Bc5RgUnorm => "bc5-rg-unorm"
    Bc5RgSnorm => "bc5-rg-snorm"
    Bc6hRgbUfloat => "bc6h-rgb-ufloat"
    Bc6hRgbFloat => "bc6h-rgb-float"
    Bc7RgbaUnorm => "bc7-rgba-unorm"
    Bc7RgbaUnormSrgb => "bc7-rgba-unorm-srgb"
    Etc2Rgb8unorm => "etc2-rgb8unorm"
    Etc2Rgb8unormSrgb => "etc2-rgb8unorm-srgb"
    Etc2Rgb8a1unorm => "etc2-rgb8a1unorm"
    Etc2Rgb8a1unormSrgb => "etc2-rgb8a1unorm-srgb"
    Etc2Rgba8unorm => "etc2-rgba8unorm"
    Etc2Rgba8unormSrgb => "etc2-rgba8unorm-srgb"
    EacR11unorm => "eac-r11unorm"
    EacR11snorm => "eac-r11snorm"
    EacRg11unorm => "eac-rg11unorm"
    EacRg11snorm => "eac-rg11snorm"
    Astc4x4Unorm => "astc-4x4-unorm"
    Astc4x4UnormSrgb => "astc-4x4-unorm-srgb"
    Astc5x4Unorm => "astc-5x4-unorm"
    Astc5x4UnormSrgb => "astc-5x4-unorm-srgb"
    Astc5x5Unorm => "astc-5x5-unorm"
    Astc5x5UnormSrgb => "astc-5x5-unorm-srgb"
    Astc6x5Unorm => "astc-6x5-unorm"
    Astc6x5UnormSrgb => "astc-6x5-unorm-srgb"
    Astc6x6Unorm => "astc-6x6-unorm"
    Astc6x6UnormSrgb => "astc-6x6-unorm-srgb"
    Astc8x5Unorm => "astc-8x5-unorm"
    Astc8x5UnormSrgb => "astc-8x5-unorm-srgb"
    Astc8x6Unorm => "astc-8x6-unorm"
    Astc8x6UnormSrgb => "astc-8x6-unorm-srgb"
    Astc8x8Unorm => "astc-8x8-unorm"
    Astc8x8UnormSrgb => "astc-8x8-unorm-srgb"
    Astc10x5Unorm => "astc-10x5-unorm"
    Astc10x5UnormSrgb => "astc-10x5-unorm-srgb"
    Astc10x6Unorm => "astc-10x6-unorm"
    Astc10x6UnormSrgb => "astc-10x6-unorm-srgb"
    Astc10x8Unorm => "astc-10x8-unorm"
    Astc10x8UnormSrgb => "astc-10x8-unorm-srgb"
    Astc10x10Unorm => "astc-10x10-unorm"
    Astc10x10UnormSrgb => "astc-10x10-unorm-srgb"
    Astc12x10Unorm => "astc-12x10-unorm"
    Astc12x10UnormSrgb => "astc-12x10-unorm-srgb"
    Astc12x12Unorm => "astc-12x12-unorm"
    Astc12x12UnormSrgb => "astc-12x12-unorm-srgb"
  }
}

///|
/// Every format the specification defines, in specification order.
pub fn TextureFormat::all() -> Array[TextureFormat] {
  [
    R8unorm,
    R8snorm,
    R8uint,
    R8sint,
    R16unorm,
    R16snorm,
    R16uint,
    R16sint,
    R16float,
    Rg8unorm,
    Rg8snorm,
    Rg8uint,
    Rg8sint,
    R32uint,
    R32sint,
    R32float,
    Rg16unorm,
    Rg16snorm,
    Rg16uint,
    Rg16sint,
    Rg16float,
    Rgba8unorm,
    Rgba8unormSrgb,
    Rgba8snorm,
    Rgba8uint,
    Rgba8sint,
    Bgra8unorm,
    Bgra8unormSrgb,
    Rgb9e5ufloat,
    Rgb10a2uint,
    Rgb10a2unorm,
    Rg11b10ufloat,
    Rg32uint,
    Rg32sint,
    Rg32float,
    Rgba16unorm,
    Rgba16snorm,
    Rgba16uint,
    Rgba16sint,
    Rgba16float,
    Rgba32uint,
    Rgba32sint,
    Rgba32float,
    Stencil8,
    Depth16unorm,
    Depth24plus,
    Depth24plusStencil8,
    Depth32float,
    Depth32floatStencil8,
    Bc1RgbaUnorm,
    Bc1RgbaUnormSrgb,
    Bc2RgbaUnorm,
    Bc2RgbaUnormSrgb,
    Bc3RgbaUnorm,
    Bc3RgbaUnormSrgb,
    Bc4RUnorm,
    Bc4RSnorm,
    Bc5RgUnorm,
    Bc5RgSnorm,
    Bc6hRgbUfloat,
    Bc6hRgbFloat,
    Bc7RgbaUnorm,
    Bc7RgbaUnormSrgb,
    Etc2Rgb8unorm,
    Etc2Rgb8unormSrgb,
    Etc2Rgb8a1unorm,
    Etc2Rgb8a1unormSrgb,
    Etc2Rgba8unorm,
    Etc2Rgba8unormSrgb,
    EacR11unorm,
    EacR11snorm,
    EacRg11unorm,
    EacRg11snorm,
    Astc4x4Unorm,
    Astc4x4UnormSrgb,
    Astc5x4Unorm,
    Astc5x4UnormSrgb,
    Astc5x5Unorm,
    Astc5x5UnormSrgb,
    Astc6x5Unorm,
    Astc6x5UnormSrgb,
    Astc6x6Unorm,
    Astc6x6UnormSrgb,
    Astc8x5Unorm,
    Astc8x5UnormSrgb,
    Astc8x6Unorm,
    Astc8x6UnormSrgb,
    Astc8x8Unorm,
    Astc8x8UnormSrgb,
    Astc10x5Unorm,
    Astc10x5UnormSrgb,
    Astc10x6Unorm,
    Astc10x6UnormSrgb,
    Astc10x8Unorm,
    Astc10x8UnormSrgb,
    Astc10x10Unorm,
    Astc10x10UnormSrgb,
    Astc12x10Unorm,
    Astc12x10UnormSrgb,
    Astc12x12Unorm,
    Astc12x12UnormSrgb,
  ]
}

///|
pub impl Show for TextureFormat with fn to_string(self) {
  self.name()
}
