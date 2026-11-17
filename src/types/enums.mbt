// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// `GPUTextureDimension`: whether a texture is one-, two- or three-dimensional.
#derive(Eq, Debug)
pub(all) enum TextureDimension {
  D1
  D2
  D3
}

///|
/// `GPUTextureViewDimension`: how a view reads the texture it stands on.
#derive(Eq, Debug)
pub(all) enum TextureViewDimension {
  D1
  D2
  D2Array
  Cube
  CubeArray
  D3
}

///|
/// `GPUTextureAspect`: which aspect of a depth-stencil texture is addressed.
#derive(Eq, Debug)
pub(all) enum TextureAspect {
  All
  StencilOnly
  DepthOnly
}

///|
/// `GPUPrimitiveTopology`.
#derive(Eq, Debug)
pub(all) enum PrimitiveTopology {
  PointList
  LineList
  LineStrip
  TriangleList
  TriangleStrip
}

///|
/// `GPUFrontFace`.
#derive(Eq, Debug)
pub(all) enum FrontFace {
  Ccw
  Cw
}

///|
/// `GPUCullMode`.
#derive(Eq, Debug)
pub(all) enum CullMode {
  None
  Front
  Back
}

///|
/// `GPUIndexFormat`.
#derive(Eq, Debug)
pub(all) enum IndexFormat {
  Uint16
  Uint32
}

///|
/// The bytes one index occupies.
pub fn IndexFormat::size(self : IndexFormat) -> Int32 {
  match self {
    Uint16 => 2
    Uint32 => 4
  }
}

///|
/// `GPUCompareFunction`.
#derive(Eq, Debug)
pub(all) enum CompareFunction {
  Never
  Less
  Equal
  LessEqual
  Greater
  NotEqual
  GreaterEqual
  Always
}

///|
/// `GPUStencilOperation`.
#derive(Eq, Debug)
pub(all) enum StencilOperation {
  Keep
  Zero
  Replace
  Invert
  IncrementClamp
  DecrementClamp
  IncrementWrap
  DecrementWrap
}

///|
/// `GPUBlendFactor`.
#derive(Eq, Debug)
pub(all) enum BlendFactor {
  Zero
  One
  Src
  OneMinusSrc
  SrcAlpha
  OneMinusSrcAlpha
  Dst
  OneMinusDst
  DstAlpha
  OneMinusDstAlpha
  SrcAlphaSaturated
  Constant
  OneMinusConstant
  Src1
  OneMinusSrc1
  Src1Alpha
  OneMinusSrc1Alpha
}

///|
/// `GPUBlendOperation`.
#derive(Eq, Debug)
pub(all) enum BlendOperation {
  Add
  Subtract
  ReverseSubtract
  Min
  Max
}

///|
/// `GPUAddressMode`.
#derive(Eq, Debug)
pub(all) enum AddressMode {
  ClampToEdge
  Repeat
  MirrorRepeat
}

///|
/// `GPUFilterMode`, used both for magnification and for minification.
#derive(Eq, Debug)
pub(all) enum FilterMode {
  Nearest
  Linear
}

///|
/// `GPUCompareFunction` for a shadow sampler.
#derive(Eq, Debug)
pub(all) enum SamplerBindingType {
  Filtering
  NonFiltering
  Comparison
}

///|
/// `GPUBufferBindingType`.
#derive(Eq, Debug)
pub(all) enum BufferBindingType {
  Uniform
  Storage
  ReadOnlyStorage
}

///|
/// `GPUStorageTextureAccess`.
#derive(Eq, Debug)
pub(all) enum StorageTextureAccess {
  WriteOnly
  ReadOnly
  ReadWrite
}

///|
/// `GPUStoreOp`.
#derive(Eq, Debug)
pub(all) enum StoreOp {
  Store
  Discard
}

///|
/// `GPULoadOp`: whether an attachment keeps what it held or is cleared first.
/// The value it is cleared to is a separate field of the attachment, as in the
/// specification.
#derive(Eq, Debug)
pub(all) enum LoadOp {
  Load
  Clear
}

///|
/// `GPUQueryType`.
#derive(Eq, Debug)
pub(all) enum QueryType {
  Occlusion
  Timestamp
}

///|
/// `GPUCompilationMessageType`.
#derive(Eq, Debug)
pub(all) enum CompilationMessageType {
  Error
  Warning
  Info
}

///|
/// `GPUDeviceLostReason`.
#derive(Eq, Debug)
pub(all) enum DeviceLostReason {
  Unknown
  Destroyed
}

///|
/// `GPUErrorFilter`, the kinds of error a scope can collect.
#derive(Eq, Debug)
pub(all) enum ErrorFilter {
  Validation
  OutOfMemory
  Internal
}

///|
/// `GPUPowerPreference`.
#derive(Eq, Debug)
pub(all) enum PowerPreference {
  None
  LowPower
  HighPerformance
}

///|
/// Which kind of host an adapter came from. The specification only knows
/// "browser"; the native backends name themselves.
#derive(Eq, Debug)
pub(all) enum BackendKind {
  WebGpu
  Vulkan
  Metal
  Dx12
  Gles
  Memory
}

///|
/// `GPUPipelineErrorReason`.
#derive(Eq, Debug)
pub(all) enum PipelineErrorReason {
  Validation
  Internal
}

///|
/// What a `ShaderModule` is written in. WGSL is the only language the
/// specification defines; SPIR-V is accepted by some adapters and is kept here
/// so that a backend that wants it has a place to say so.
#derive(Eq, Debug)
pub(all) enum ShaderSourceKind {
  Wgsl
  SpirV
}

///|
/// `PredefinedColorSpace`: the colour space an external image is converted to
/// before it is sampled.
#derive(Eq, Debug)
pub(all) enum PredefinedColorSpace {
  Srgb
  DisplayP3
}

///|
/// The name the specification prints for a colour space, as in `"srgb"`.
pub fn PredefinedColorSpace::name(self : PredefinedColorSpace) -> String {
  match self {
    Srgb => "srgb"
    DisplayP3 => "display-p3"
  }
}

///|
/// `GPUBufferMapState`: whether a buffer is mapped, waiting to be, or not
/// mapped at all.
#derive(Eq, Debug)
pub(all) enum MapState {
  Unmapped
  Pending
  Mapped
}
