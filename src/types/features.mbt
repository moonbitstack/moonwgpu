// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A `GPUFeatureName`: an optional capability a device must be asked for
/// explicitly.
///
/// The list is the one the specification prints, in the same order.
/// https://www.w3.org/TR/webgpu/#enumdef-gpufeaturename
#derive(Eq, Debug)
pub(all) enum FeatureName {
  CoreFeaturesAndLimits
  DepthClipControl
  Depth32floatStencil8
  TextureCompressionBc
  TextureCompressionBcSliced3d
  TextureCompressionEtc2
  TextureCompressionAstc
  TextureCompressionAstcSliced3d
  TimestampQuery
  IndirectFirstInstance
  ShaderF16
  Rg11b10ufloatRenderable
  Bgra8unormStorage
  Float32Filterable
  Float32Blendable
  ClipDistances
  DualSourceBlending
  Subgroups
  TextureFormatsTier1
  TextureFormatsTier2
  PrimitiveIndex
  TextureComponentSwizzle
  SubgroupSizeControl
  TextureCompressionUnaligned
  AtomicVec2uMinMax
}

///|
/// The name the specification uses, as in `"shader-f16"`.
pub fn FeatureName::name(self : FeatureName) -> String {
  match self {
    CoreFeaturesAndLimits => "core-features-and-limits"
    DepthClipControl => "depth-clip-control"
    Depth32floatStencil8 => "depth32float-stencil8"
    TextureCompressionBc => "texture-compression-bc"
    TextureCompressionBcSliced3d => "texture-compression-bc-sliced-3d"
    TextureCompressionEtc2 => "texture-compression-etc2"
    TextureCompressionAstc => "texture-compression-astc"
    TextureCompressionAstcSliced3d => "texture-compression-astc-sliced-3d"
    TimestampQuery => "timestamp-query"
    IndirectFirstInstance => "indirect-first-instance"
    ShaderF16 => "shader-f16"
    Rg11b10ufloatRenderable => "rg11b10ufloat-renderable"
    Bgra8unormStorage => "bgra8unorm-storage"
    Float32Filterable => "float32-filterable"
    Float32Blendable => "float32-blendable"
    ClipDistances => "clip-distances"
    DualSourceBlending => "dual-source-blending"
    Subgroups => "subgroups"
    TextureFormatsTier1 => "texture-formats-tier1"
    TextureFormatsTier2 => "texture-formats-tier2"
    PrimitiveIndex => "primitive-index"
    TextureComponentSwizzle => "texture-component-swizzle"
    SubgroupSizeControl => "subgroup-size-control"
    TextureCompressionUnaligned => "texture-compression-unaligned"
    AtomicVec2uMinMax => "atomic-vec2u-min-max"
  }
}

///|
/// Every feature, in specification order.
pub fn FeatureName::all() -> Array[FeatureName] {
  [
    CoreFeaturesAndLimits,
    DepthClipControl,
    Depth32floatStencil8,
    TextureCompressionBc,
    TextureCompressionBcSliced3d,
    TextureCompressionEtc2,
    TextureCompressionAstc,
    TextureCompressionAstcSliced3d,
    TimestampQuery,
    IndirectFirstInstance,
    ShaderF16,
    Rg11b10ufloatRenderable,
    Bgra8unormStorage,
    Float32Filterable,
    Float32Blendable,
    ClipDistances,
    DualSourceBlending,
    Subgroups,
    TextureFormatsTier1,
    TextureFormatsTier2,
    PrimitiveIndex,
    TextureComponentSwizzle,
    SubgroupSizeControl,
    TextureCompressionUnaligned,
    AtomicVec2uMinMax,
  ]
}

///|
/// The position of the feature in the bit set, which is also its index in the
/// enumeration above.
fn FeatureName::index(self : FeatureName) -> Int32 {
  match self {
    CoreFeaturesAndLimits => 0
    DepthClipControl => 1
    Depth32floatStencil8 => 2
    TextureCompressionBc => 3
    TextureCompressionBcSliced3d => 4
    TextureCompressionEtc2 => 5
    TextureCompressionAstc => 6
    TextureCompressionAstcSliced3d => 7
    TimestampQuery => 8
    IndirectFirstInstance => 9
    ShaderF16 => 10
    Rg11b10ufloatRenderable => 11
    Bgra8unormStorage => 12
    Float32Filterable => 13
    Float32Blendable => 14
    ClipDistances => 15
    DualSourceBlending => 16
    Subgroups => 17
    TextureFormatsTier1 => 18
    TextureFormatsTier2 => 19
    PrimitiveIndex => 20
    TextureComponentSwizzle => 21
    SubgroupSizeControl => 22
    TextureCompressionUnaligned => 23
    AtomicVec2uMinMax => 24
  }
}

///|
/// The features that must be enabled together with this one. The
/// specification's "Feature Dependencies" table lists them; `core-features-and-limits`
/// is implied by every feature that is defined on top of it.
pub fn FeatureName::dependencies(self : FeatureName) -> Array[FeatureName] {
  match self {
    TextureFormatsTier2 => [TextureFormatsTier1]
    TextureFormatsTier1 => [Rg11b10ufloatRenderable]
    TextureCompressionBcSliced3d => [TextureCompressionBc]
    TextureCompressionAstcSliced3d => [TextureCompressionAstc]
    _ => []
  }
}

///|
/// A set of `GPUFeatureName`s.
#derive(Eq, Debug)
pub struct Features(UInt32)

///|
/// No optional feature at all: the device still offers the core of the
/// specification.
pub fn Features::none() -> Features {
  Features(0U)
}

///|
/// Every feature the specification defines.
pub fn Features::all() -> Features {
  Features(0x01FF_FFFFU)
}

///|
/// A set holding exactly `feature`.
pub fn Features::of(feature : FeatureName) -> Features {
  Features(1U << feature.index())
}

///|
pub fn Features::contains(self : Features, feature : FeatureName) -> Bool {
  (self.0 & (1U << feature.index())) != 0U
}

///|
/// The raw bits.
pub fn Features::bits(self : Features) -> UInt32 {
  self.0
}

///|
pub fn Features::is_empty(self : Features) -> Bool {
  self.0 == 0U
}

///|
/// Whether everything in `other` is also here.
pub fn Features::contains_all(self : Features, other : Features) -> Bool {
  (self.0 & other.0) == other.0
}

///|
/// The features in this set, in specification order.
pub fn Features::names(self : Features) -> Array[FeatureName] {
  let out = []
  for feature in FeatureName::all() {
    if self.contains(feature) {
      out.push(feature)
    }
  }
  out
}

///|
pub impl BitOr for Features with fn lor(self, other) {
  Features(self.0 | other.0)
}

///|
pub impl BitAnd for Features with fn land(self, other) {
  Features(self.0 & other.0)
}
