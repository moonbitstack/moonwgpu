// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Every object a caller holds is identified by a value of one of these types.
// The backend allocates them; nothing else does, and nothing else needs to know
// how they are made. They are distinct types rather than one integer so that a
// buffer cannot be passed where a texture belongs.

///|
/// The identity of a buffer inside one adapter.
#derive(Eq, Debug)
pub struct BufferId(UInt64)

///|
pub fn BufferId::raw(self : BufferId) -> UInt64 {
  self.0
}

///|
/// An identity from the integer the backend allocated.
pub fn BufferId::from_raw(raw : UInt64) -> BufferId {
  BufferId(raw)
}

///|
/// The identity of a texture inside one adapter.
#derive(Eq, Debug)
pub struct TextureId(UInt64)

///|
pub fn TextureId::raw(self : TextureId) -> UInt64 {
  self.0
}

///|
/// An identity from the integer the backend allocated.
pub fn TextureId::from_raw(raw : UInt64) -> TextureId {
  TextureId(raw)
}

///|
/// The identity of a view on a texture.
#derive(Eq, Debug)
pub struct TextureViewId(UInt64)

///|
pub fn TextureViewId::raw(self : TextureViewId) -> UInt64 {
  self.0
}

///|
/// An identity from the integer the backend allocated.
pub fn TextureViewId::from_raw(raw : UInt64) -> TextureViewId {
  TextureViewId(raw)
}

///|
/// The identity of a sampler.
#derive(Eq, Debug)
pub struct SamplerId(UInt64)

///|
pub fn SamplerId::raw(self : SamplerId) -> UInt64 {
  self.0
}

///|
/// An identity from the integer the backend allocated.
pub fn SamplerId::from_raw(raw : UInt64) -> SamplerId {
  SamplerId(raw)
}

///|
/// The identity of a shader module.
#derive(Eq, Debug)
pub struct ShaderModuleId(UInt64)

///|
pub fn ShaderModuleId::raw(self : ShaderModuleId) -> UInt64 {
  self.0
}

///|
/// An identity from the integer the backend allocated.
pub fn ShaderModuleId::from_raw(raw : UInt64) -> ShaderModuleId {
  ShaderModuleId(raw)
}

///|
/// The identity of a bind group layout.
#derive(Eq, Debug)
pub struct BindGroupLayoutId(UInt64)

///|
pub fn BindGroupLayoutId::raw(self : BindGroupLayoutId) -> UInt64 {
  self.0
}

///|
/// An identity from the integer the backend allocated.
pub fn BindGroupLayoutId::from_raw(raw : UInt64) -> BindGroupLayoutId {
  BindGroupLayoutId(raw)
}

///|
/// The identity of a bind group.
#derive(Eq, Debug)
pub struct BindGroupId(UInt64)

///|
pub fn BindGroupId::raw(self : BindGroupId) -> UInt64 {
  self.0
}

///|
/// An identity from the integer the backend allocated.
pub fn BindGroupId::from_raw(raw : UInt64) -> BindGroupId {
  BindGroupId(raw)
}

///|
/// The identity of a pipeline layout.
#derive(Eq, Debug)
pub struct PipelineLayoutId(UInt64)

///|
pub fn PipelineLayoutId::raw(self : PipelineLayoutId) -> UInt64 {
  self.0
}

///|
/// An identity from the integer the backend allocated.
pub fn PipelineLayoutId::from_raw(raw : UInt64) -> PipelineLayoutId {
  PipelineLayoutId(raw)
}

///|
/// The identity of a render pipeline.
#derive(Eq, Debug)
pub struct RenderPipelineId(UInt64)

///|
pub fn RenderPipelineId::raw(self : RenderPipelineId) -> UInt64 {
  self.0
}

///|
/// An identity from the integer the backend allocated.
pub fn RenderPipelineId::from_raw(raw : UInt64) -> RenderPipelineId {
  RenderPipelineId(raw)
}

///|
/// The identity of a compute pipeline.
#derive(Eq, Debug)
pub struct ComputePipelineId(UInt64)

///|
pub fn ComputePipelineId::raw(self : ComputePipelineId) -> UInt64 {
  self.0
}

///|
/// An identity from the integer the backend allocated.
pub fn ComputePipelineId::from_raw(raw : UInt64) -> ComputePipelineId {
  ComputePipelineId(raw)
}

///|
/// The identity of a query set.
#derive(Eq, Debug)
pub struct QuerySetId(UInt64)

///|
pub fn QuerySetId::raw(self : QuerySetId) -> UInt64 {
  self.0
}

///|
/// An identity from the integer the backend allocated.
pub fn QuerySetId::from_raw(raw : UInt64) -> QuerySetId {
  QuerySetId(raw)
}

///|
/// The identity of an external texture.
#derive(Eq, Debug)
pub struct ExternalTextureId(UInt64)

///|
pub fn ExternalTextureId::raw(self : ExternalTextureId) -> UInt64 {
  self.0
}

///|
/// An identity from the integer the backend allocated.
pub fn ExternalTextureId::from_raw(raw : UInt64) -> ExternalTextureId {
  ExternalTextureId(raw)
}

///|
/// A `GPUBufferDescriptor`.
#derive(Debug)
pub(all) struct BufferDescriptor {
  label : String
  size : Int32
  usage : BufferUsages
  mapped_at_creation : Bool
}

///|
/// A buffer of `size` bytes with the usages given; nothing mapped.
pub fn BufferDescriptor::new(
  size~ : Int32,
  usage~ : BufferUsages,
  mapped_at_creation~ : Bool = false,
  label~ : String = "",
) -> BufferDescriptor {
  { label, size, usage, mapped_at_creation, }
}

///|
/// A `GPUTextureDescriptor`.
#derive(Debug)
pub(all) struct TextureDescriptor {
  label : String
  size : Extent3d
  mip_level_count : Int32
  sample_count : Int32
  dimension : TextureDimension
  format : TextureFormat
  usage : TextureUsages
  view_formats : Array[TextureFormat]
  texture_binding_view_dimension : TextureViewDimension?
}

///|
/// A texture of one mip level and one sample, the default every other option
/// starts from.
pub fn TextureDescriptor::new(
  size~ : Extent3d,
  format~ : TextureFormat,
  usage~ : TextureUsages,
  mip_level_count~ : Int32 = 1,
  sample_count~ : Int32 = 1,
  dimension~ : TextureDimension = TextureDimension::D2,
  view_formats~ : Array[TextureFormat] = [],
  texture_binding_view_dimension? : TextureViewDimension,
  label~ : String = "",
) -> TextureDescriptor {
  {
    label,
    size,
    mip_level_count,
    sample_count,
    dimension,
    format,
    usage,
    view_formats,
    texture_binding_view_dimension,
  }
}

///|
/// A `GPUTextureViewDescriptor`.
#derive(Debug)
pub(all) struct TextureViewDescriptor {
  label : String
  format : TextureFormat?
  dimension : TextureViewDimension?
  aspect : TextureAspect
  base_mip_level : Int32
  mip_level_count : Int32?
  base_array_layer : Int32
  array_layer_count : Int32?
  usage : TextureUsages?
  swizzle : String?
}

///|
/// A view of the whole texture in its own format and dimension.
pub fn TextureViewDescriptor::new(
  label~ : String = "",
  format? : TextureFormat,
  dimension? : TextureViewDimension,
  aspect~ : TextureAspect = TextureAspect::All,
  base_mip_level~ : Int32 = 0,
  mip_level_count? : Int32,
  base_array_layer~ : Int32 = 0,
  array_layer_count? : Int32,
  usage? : TextureUsages,
  swizzle? : String,
) -> TextureViewDescriptor {
  {
    label,
    format,
    dimension,
    aspect,
    base_mip_level,
    mip_level_count,
    base_array_layer,
    array_layer_count,
    usage,
    swizzle,
  }
}

///|
/// A `GPUSamplerDescriptor`.
#derive(Debug)
pub(all) struct SamplerDescriptor {
  label : String
  address_mode_u : AddressMode
  address_mode_v : AddressMode
  address_mode_w : AddressMode
  mag_filter : FilterMode
  min_filter : FilterMode
  mipmap_filter : FilterMode
  lod_min_clamp : Double
  lod_max_clamp : Double
  compare : CompareFunction?
  max_anisotropy : Int32
}

///|
/// The sampler the specification describes when a descriptor says nothing:
/// clamp to edge, linear magnification, nearest minification, one mip level.
pub fn SamplerDescriptor::new(
  label~ : String = "",
  address_mode_u~ : AddressMode = AddressMode::ClampToEdge,
  address_mode_v~ : AddressMode = AddressMode::ClampToEdge,
  address_mode_w~ : AddressMode = AddressMode::ClampToEdge,
  mag_filter~ : FilterMode = FilterMode::Nearest,
  min_filter~ : FilterMode = FilterMode::Nearest,
  mipmap_filter~ : FilterMode = FilterMode::Nearest,
  lod_min_clamp~ : Double = 0.0,
  lod_max_clamp~ : Double = 32.0,
  compare? : CompareFunction,
  max_anisotropy~ : Int32 = 1,
) -> SamplerDescriptor {
  {
    label,
    address_mode_u,
    address_mode_v,
    address_mode_w,
    mag_filter,
    min_filter,
    mipmap_filter,
    lod_min_clamp,
    lod_max_clamp,
    compare,
    max_anisotropy,
  }
}

///|
/// A `GPUShaderModuleDescriptor`.
#derive(Debug)
pub(all) struct ShaderModuleDescriptor {
  label : String
  source : String
  kind : ShaderSourceKind
}

///|
/// A shader module written in WGSL.
pub fn ShaderModuleDescriptor::wgsl(
  source~ : String,
  label~ : String = "",
) -> ShaderModuleDescriptor {
  { label, source, kind: ShaderSourceKind::Wgsl, }
}

///|
/// A `GPUQuerySetDescriptor`.
#derive(Debug)
pub(all) struct QuerySetDescriptor {
  label : String
  kind : QueryType
  count : Int32
}

///|
pub fn QuerySetDescriptor::new(
  kind~ : QueryType,
  count~ : Int32,
  label~ : String = "",
) -> QuerySetDescriptor {
  { label, kind, count, }
}

///|
/// One `GPUCompilationMessage`: what a shader compiler said about one place in
/// a module.
///
/// `line_num` and `line_pos` are one-based, as in the specification; an offset
/// without a line has `line_num` zero.
#derive(Eq, Debug)
pub(all) struct CompilationMessage {
  message : String
  kind : CompilationMessageType
  line_num : Int32
  line_pos : Int32
  offset : Int32
  length : Int32
}

///|
pub fn CompilationMessage::new(
  message~ : String,
  kind~ : CompilationMessageType,
  line_num~ : Int32 = 1,
  line_pos~ : Int32 = 1,
  offset~ : Int32 = 0,
  length~ : Int32 = 0,
) -> CompilationMessage {
  { message, kind, line_num, line_pos, offset, length, }
}

///|
/// Whether this message stops the module from being built.
pub fn CompilationMessage::is_error(self : CompilationMessage) -> Bool {
  self.kind == CompilationMessageType::Error
}

///|
/// `GPUCompilationInfo`: everything the compiler said about one module, in the
/// order it said it.
#derive(Debug)
pub(all) struct CompilationInfo {
  messages : Array[CompilationMessage]
}

///|
pub fn CompilationInfo::new(
  messages~ : Array[CompilationMessage] = [],
) -> CompilationInfo {
  { messages, }
}

///|
/// Whether any message is an error, in which case the module cannot be used.
pub fn CompilationInfo::has_errors(self : CompilationInfo) -> Bool {
  for message in self.messages {
    if message.is_error() {
      return true
    }
  }
  false
}

///|
/// The pixels a host hands over for an external image.
///
/// The specification's source is an `HTMLVideoElement` or a `VideoFrame`; a
/// native host has neither, so it hands over the frame it decoded instead: the
/// size of the frame, the format its pixels are in, and the bytes themselves,
/// packed row by row with no padding.
#derive(Debug)
pub(all) struct ExternalImage {
  label : String
  size : Extent3d
  format : TextureFormat
  data : Bytes
}

///|
pub fn ExternalImage::new(
  size~ : Extent3d,
  format~ : TextureFormat,
  data~ : Bytes,
  label~ : String = "",
) -> ExternalImage {
  { label, size, format, data, }
}

///|
/// The bytes one row of this image occupies, with no padding.
pub fn ExternalImage::row_bytes(self : ExternalImage) -> Int32 {
  let info = self.format.info()
  let blocks = (self.size.width + info.block_width - 1) / info.block_width
  blocks * info.bytes_per_block
}

///|
/// A `GPUExternalTextureDescriptor`.
#derive(Debug)
pub(all) struct ExternalTextureDescriptor {
  label : String
  image : ExternalImage
  color_space : PredefinedColorSpace
}

///|
pub fn ExternalTextureDescriptor::new(
  image~ : ExternalImage,
  color_space~ : PredefinedColorSpace = PredefinedColorSpace::Srgb,
  label~ : String = "",
) -> ExternalTextureDescriptor {
  { label, image, color_space, }
}
