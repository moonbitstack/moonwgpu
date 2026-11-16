// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What a shader may sample a texture of this format as, `GPUTextureSampleType`.
#derive(Eq, Debug)
pub(all) enum SampleType {
  Float
  UnfilterableFloat
  Uint
  Sint
  Depth
}

///|
/// Which `GPUStorageTextureAccess` values the format offers. `None` means the
/// format cannot be a storage texture at all.
#derive(Eq, Debug)
pub(all) enum StorageAccess {
  None
  WriteOnly
  ReadOnly
  Both
}

///|
/// The aspects a format has. A depth-stencil format is one texture with two
/// aspects; a view selects one of them.
#derive(Eq, Debug)
pub(all) enum FormatAspect {
  Color
  DepthOnly
  StencilOnly
  DepthStencil
}

///|
/// Everything the specification says about one `GPUTextureFormat`.
///
/// The values come from the tables "Texture format capabilities" and "Depth
/// and stencil format capabilities" of the specification; the features named
/// here are the ones that must be enabled before a texture of the format can
/// be created at all. The storage column records what the format offers under
/// `core-features-and-limits`; the tiered storage extensions are not modelled
/// yet.
#derive(Debug)
pub(all) struct FormatInfo {
  block_width : Int32
  block_height : Int32
  bytes_per_block : Int32
  bytes_per_sample : Int32
  sample_type : SampleType
  aspect : FormatAspect
  render_attachment : Bool
  blendable : Bool
  multisample : Bool
  resolve : Bool
  storage : StorageAccess
  copy_src : Bool
  copy_dst : Bool
  feature : FeatureName?
}

///|
/// The capabilities of `self`.
pub fn TextureFormat::info(self : TextureFormat) -> FormatInfo {
  match self {
    R8unorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 1,
        bytes_per_sample: 1,
        sample_type: SampleType::Float,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: true,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    R8snorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 1,
        bytes_per_sample: 1,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    R8uint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 1,
        bytes_per_sample: 1,
        sample_type: SampleType::Uint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    R8sint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 1,
        bytes_per_sample: 1,
        sample_type: SampleType::Sint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    R16unorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 2,
        bytes_per_sample: 2,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureFormatsTier1),
      }
    R16snorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 2,
        bytes_per_sample: 2,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureFormatsTier1),
      }
    R16uint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 2,
        bytes_per_sample: 2,
        sample_type: SampleType::Uint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    R16sint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 2,
        bytes_per_sample: 2,
        sample_type: SampleType::Sint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    R16float =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 2,
        bytes_per_sample: 2,
        sample_type: SampleType::Float,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: true,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rg8unorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 2,
        bytes_per_sample: 2,
        sample_type: SampleType::Float,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: true,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rg8snorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 2,
        bytes_per_sample: 2,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rg8uint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 2,
        bytes_per_sample: 2,
        sample_type: SampleType::Uint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rg8sint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 2,
        bytes_per_sample: 2,
        sample_type: SampleType::Sint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    R32uint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 4,
        sample_type: SampleType::Uint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    R32sint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 4,
        sample_type: SampleType::Sint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    R32float =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 4,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rg16unorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 4,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureFormatsTier1),
      }
    Rg16snorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 4,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureFormatsTier1),
      }
    Rg16uint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 4,
        sample_type: SampleType::Uint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rg16sint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 4,
        sample_type: SampleType::Sint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rg16float =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 4,
        sample_type: SampleType::Float,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: true,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgba8unorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 8,
        sample_type: SampleType::Float,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: true,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgba8unormSrgb =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 8,
        sample_type: SampleType::Float,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: true,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgba8snorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 8,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: true,
        multisample: true,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgba8uint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 4,
        sample_type: SampleType::Uint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgba8sint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 4,
        sample_type: SampleType::Sint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Bgra8unorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 8,
        sample_type: SampleType::Float,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: true,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Bgra8unormSrgb =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 8,
        sample_type: SampleType::Float,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: true,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgb9e5ufloat =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgb10a2uint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 8,
        sample_type: SampleType::Uint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgb10a2unorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 8,
        sample_type: SampleType::Float,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: true,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rg11b10ufloat =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 8,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::Rg11b10ufloatRenderable),
      }
    Rg32uint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 8,
        bytes_per_sample: 8,
        sample_type: SampleType::Uint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rg32sint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 8,
        bytes_per_sample: 8,
        sample_type: SampleType::Sint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rg32float =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 8,
        bytes_per_sample: 8,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgba16unorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 8,
        bytes_per_sample: 8,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureFormatsTier1),
      }
    Rgba16snorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 8,
        bytes_per_sample: 8,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureFormatsTier1),
      }
    Rgba16uint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 8,
        bytes_per_sample: 8,
        sample_type: SampleType::Uint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgba16sint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 8,
        bytes_per_sample: 8,
        sample_type: SampleType::Sint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgba16float =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 8,
        bytes_per_sample: 8,
        sample_type: SampleType::Float,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: true,
        multisample: true,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgba32uint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 16,
        bytes_per_sample: 16,
        sample_type: SampleType::Uint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgba32sint =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 16,
        bytes_per_sample: 16,
        sample_type: SampleType::Sint,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Rgba32float =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 16,
        bytes_per_sample: 16,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: true,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::Both,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Stencil8 =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 1,
        bytes_per_sample: 0,
        sample_type: SampleType::Uint,
        aspect: FormatAspect::StencilOnly,
        render_attachment: false,
        blendable: false,
        multisample: true,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Depth16unorm =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 2,
        bytes_per_sample: 0,
        sample_type: SampleType::Depth,
        aspect: FormatAspect::DepthOnly,
        render_attachment: false,
        blendable: false,
        multisample: true,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Depth24plus =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 0,
        sample_type: SampleType::Depth,
        aspect: FormatAspect::DepthOnly,
        render_attachment: false,
        blendable: false,
        multisample: true,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: false,
        copy_dst: false,
        feature: None,
      }
    Depth24plusStencil8 =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 0,
        sample_type: SampleType::Depth,
        aspect: FormatAspect::DepthStencil,
        render_attachment: false,
        blendable: false,
        multisample: true,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: None,
      }
    Depth32float =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 0,
        sample_type: SampleType::Depth,
        aspect: FormatAspect::DepthOnly,
        render_attachment: false,
        blendable: false,
        multisample: true,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: false,
        feature: None,
      }
    Depth32floatStencil8 =>
      {
        block_width: 1,
        block_height: 1,
        bytes_per_block: 4,
        bytes_per_sample: 0,
        sample_type: SampleType::Depth,
        aspect: FormatAspect::DepthStencil,
        render_attachment: false,
        blendable: false,
        multisample: true,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: false,
        feature: Some(FeatureName::Depth32floatStencil8),
      }
    Bc1RgbaUnorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 8,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Bc1RgbaUnormSrgb =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 8,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Bc2RgbaUnorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Bc2RgbaUnormSrgb =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Bc3RgbaUnorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Bc3RgbaUnormSrgb =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Bc4RUnorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 8,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Bc4RSnorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 8,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Bc5RgUnorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Bc5RgSnorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Bc6hRgbUfloat =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Bc6hRgbFloat =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Bc7RgbaUnorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Bc7RgbaUnormSrgb =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionBc),
      }
    Etc2Rgb8unorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 8,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionEtc2),
      }
    Etc2Rgb8unormSrgb =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 8,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionEtc2),
      }
    Etc2Rgb8a1unorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 8,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionEtc2),
      }
    Etc2Rgb8a1unormSrgb =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 8,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionEtc2),
      }
    Etc2Rgba8unorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionEtc2),
      }
    Etc2Rgba8unormSrgb =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionEtc2),
      }
    EacR11unorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 8,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionEtc2),
      }
    EacR11snorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 8,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionEtc2),
      }
    EacRg11unorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionEtc2),
      }
    EacRg11snorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionEtc2),
      }
    Astc4x4Unorm =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc4x4UnormSrgb =>
      {
        block_width: 4,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc5x4Unorm =>
      {
        block_width: 5,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc5x4UnormSrgb =>
      {
        block_width: 5,
        block_height: 4,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc5x5Unorm =>
      {
        block_width: 5,
        block_height: 5,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc5x5UnormSrgb =>
      {
        block_width: 5,
        block_height: 5,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc6x5Unorm =>
      {
        block_width: 6,
        block_height: 5,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc6x5UnormSrgb =>
      {
        block_width: 6,
        block_height: 5,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc6x6Unorm =>
      {
        block_width: 6,
        block_height: 6,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc6x6UnormSrgb =>
      {
        block_width: 6,
        block_height: 6,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc8x5Unorm =>
      {
        block_width: 8,
        block_height: 5,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc8x5UnormSrgb =>
      {
        block_width: 8,
        block_height: 5,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc8x6Unorm =>
      {
        block_width: 8,
        block_height: 6,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc8x6UnormSrgb =>
      {
        block_width: 8,
        block_height: 6,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc8x8Unorm =>
      {
        block_width: 8,
        block_height: 8,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc8x8UnormSrgb =>
      {
        block_width: 8,
        block_height: 8,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc10x5Unorm =>
      {
        block_width: 10,
        block_height: 5,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc10x5UnormSrgb =>
      {
        block_width: 10,
        block_height: 5,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc10x6Unorm =>
      {
        block_width: 10,
        block_height: 6,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc10x6UnormSrgb =>
      {
        block_width: 10,
        block_height: 6,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc10x8Unorm =>
      {
        block_width: 10,
        block_height: 8,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc10x8UnormSrgb =>
      {
        block_width: 10,
        block_height: 8,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc10x10Unorm =>
      {
        block_width: 10,
        block_height: 10,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc10x10UnormSrgb =>
      {
        block_width: 10,
        block_height: 10,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc12x10Unorm =>
      {
        block_width: 12,
        block_height: 10,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc12x10UnormSrgb =>
      {
        block_width: 12,
        block_height: 10,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc12x12Unorm =>
      {
        block_width: 12,
        block_height: 12,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
    Astc12x12UnormSrgb =>
      {
        block_width: 12,
        block_height: 12,
        bytes_per_block: 16,
        bytes_per_sample: 0,
        sample_type: SampleType::UnfilterableFloat,
        aspect: FormatAspect::Color,
        render_attachment: false,
        blendable: false,
        multisample: false,
        resolve: false,
        storage: StorageAccess::None,
        copy_src: true,
        copy_dst: true,
        feature: Some(FeatureName::TextureCompressionAstc),
      }
  }
}
