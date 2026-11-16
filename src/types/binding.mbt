// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A `GPUBufferBindingLayout`.
#derive(Debug)
pub(all) struct BufferBindingLayout {
  kind : BufferBindingType
  has_dynamic_offset : Bool
  min_binding_size : Int32?
}

///|
pub fn BufferBindingLayout::new(
  kind~ : BufferBindingType,
  has_dynamic_offset~ : Bool = false,
  min_binding_size? : Int32,
) -> BufferBindingLayout {
  { kind, has_dynamic_offset, min_binding_size, }
}

///|
/// A `GPUSamplerBindingLayout`.
#derive(Debug)
pub(all) struct SamplerBindingLayout {
  kind : SamplerBindingType
}

///|
pub fn SamplerBindingLayout::new(
  kind~ : SamplerBindingType = SamplerBindingType::Filtering,
) -> SamplerBindingLayout {
  { kind, }
}

///|
/// A `GPUTextureBindingLayout`.
#derive(Debug)
pub(all) struct TextureBindingLayout {
  sample_type : SampleType
  view_dimension : TextureViewDimension
  multisampled : Bool
}

///|
pub fn TextureBindingLayout::new(
  sample_type~ : SampleType = SampleType::Float,
  view_dimension~ : TextureViewDimension = TextureViewDimension::D2,
  multisampled~ : Bool = false,
) -> TextureBindingLayout {
  { sample_type, view_dimension, multisampled, }
}

///|
/// A `GPUStorageTextureBindingLayout`.
#derive(Debug)
pub(all) struct StorageTextureBindingLayout {
  access : StorageTextureAccess
  format : TextureFormat
  view_dimension : TextureViewDimension
}

///|
pub fn StorageTextureBindingLayout::new(
  format~ : TextureFormat,
  access~ : StorageTextureAccess = StorageTextureAccess::WriteOnly,
  view_dimension~ : TextureViewDimension = TextureViewDimension::D2,
) -> StorageTextureBindingLayout {
  { access, format, view_dimension, }
}

///|
/// The kind of resource one binding of a bind group layout declares. Exactly
/// one of the four shapes the specification defines.
#derive(Debug)
pub(all) enum BindingLayout {
  Buffer(BufferBindingLayout)
  Sampler(SamplerBindingLayout)
  Texture(TextureBindingLayout)
  StorageTexture(StorageTextureBindingLayout)
}

///|
/// A `GPUBindGroupLayoutEntry`.
#derive(Debug)
pub(all) struct BindGroupLayoutEntry {
  binding : Int32
  visibility : ShaderStages
  kind : BindingLayout
  count : Int32?
}

///|
pub fn BindGroupLayoutEntry::new(
  binding~ : Int32,
  visibility~ : ShaderStages,
  kind~ : BindingLayout,
  count? : Int32,
) -> BindGroupLayoutEntry {
  { binding, visibility, kind, count, }
}

///|
/// A `GPUBindGroupLayoutDescriptor`.
#derive(Debug)
pub(all) struct BindGroupLayoutDescriptor {
  label : String
  entries : Array[BindGroupLayoutEntry]
}

///|
pub fn BindGroupLayoutDescriptor::new(
  entries~ : Array[BindGroupLayoutEntry],
  label~ : String = "",
) -> BindGroupLayoutDescriptor {
  { label, entries, }
}

///|
/// A `GPUPipelineLayoutDescriptor`. An empty list of bind group layouts is the
/// explicit form of the "auto" layout.
#derive(Debug)
pub(all) struct PipelineLayoutDescriptor {
  label : String
  bind_group_layouts : Array[BindGroupLayoutId]
}

///|
pub fn PipelineLayoutDescriptor::new(
  bind_group_layouts~ : Array[BindGroupLayoutId],
  label~ : String = "",
) -> PipelineLayoutDescriptor {
  { label, bind_group_layouts, }
}

///|
/// A `GPUBufferBinding`: a buffer, where the binding starts, and how long it
/// is. `None` means "to the end of the buffer".
#derive(Debug)
pub(all) struct BufferBinding {
  buffer : BufferId
  offset : Int32
  size : Int32?
}

///|
pub fn BufferBinding::new(
  buffer~ : BufferId,
  offset~ : Int32 = 0,
  size? : Int32,
) -> BufferBinding {
  { buffer, offset, size, }
}

///|
/// What a `GPUBindGroupEntry` binds.
#derive(Debug)
pub(all) enum BindingResource {
  Buffer(BufferBinding)
  Sampler(SamplerId)
  TextureView(TextureViewId)
}

///|
/// A `GPUBindGroupEntry`.
#derive(Debug)
pub(all) struct BindGroupEntry {
  binding : Int32
  resource : BindingResource
}

///|
pub fn BindGroupEntry::new(
  binding~ : Int32,
  resource~ : BindingResource,
) -> BindGroupEntry {
  { binding, resource, }
}

///|
/// A `GPUBindGroupDescriptor`.
#derive(Debug)
pub(all) struct BindGroupDescriptor {
  label : String
  layout : BindGroupLayoutId
  entries : Array[BindGroupEntry]
}

///|
pub fn BindGroupDescriptor::new(
  layout~ : BindGroupLayoutId,
  entries~ : Array[BindGroupEntry],
  label~ : String = "",
) -> BindGroupDescriptor {
  { label, layout, entries, }
}
