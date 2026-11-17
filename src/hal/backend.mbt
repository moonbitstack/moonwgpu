// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Why a backend could not do what it was asked.
///
/// A backend reports only what it knows: a resource it does not have, an
/// operation it does not implement, or a host that ran out of memory. Whether
/// a request is *valid* is decided before the backend is called, by `core`.
pub suberror HalError {
  Missing(what~ : String)
  Unsupported(what~ : String)
  Exhausted(want~ : Int32, limit~ : Int32)
  Failed(what~ : String)
}

///|
pub fn HalError::missing(what : String) -> HalError {
  Missing(what~)
}

///|
pub fn HalError::unsupported(what : String) -> HalError {
  Unsupported(what~)
}

///|
pub fn HalError::exhausted(want : Int32, limit : Int32) -> HalError {
  Exhausted(want~, limit~)
}

///|
pub fn HalError::failed(what : String) -> HalError {
  Failed(what~)
}

///|
/// What a backend has to provide.
///
/// The methods mirror the specification's device-timeline steps one for one:
/// a resource is created here only after the layer above has validated the
/// descriptor, so an implementation may assume its arguments are legal. The
/// two exceptions are the byte-level operations, which receive whatever the
/// caller asked for and report what they cannot do.
///
/// Nothing here knows about pipelines beyond storing them: compiling WGSL is
/// the job of the shader compiler a backend is handed, and a backend without
/// one still records the pipeline so that command buffers replay exactly.
pub(open) trait Hal {
  ///|
  /// Which backend this is, for diagnostics, as in `"memory"`.
  fn name(Self) -> String
  ///|
  /// The limits this host offers.
  fn limits(Self) -> @types.Limits
  ///|
  /// The optional features this host offers.
  fn features(Self) -> @types.Features
  fn create_buffer(Self, @types.BufferDescriptor) -> @types.BufferId raise HalError
  fn destroy_buffer(Self, @types.BufferId) -> Unit
  ///|
  /// Write `data` at `offset`. The caller has checked the range and that the
  /// buffer carries `copy_dst`.
  fn write_buffer(Self, @types.BufferId, Int32, Bytes) -> Unit raise HalError
  ///|
  /// Read `size` bytes at `offset`; the caller has checked the range and that
  /// the buffer is mapped for reading.
  fn read_buffer(Self, @types.BufferId, Int32, Int32) -> Bytes raise HalError
  fn create_texture(Self, @types.TextureDescriptor) -> @types.TextureId raise HalError
  fn destroy_texture(Self, @types.TextureId) -> Unit
  fn create_texture_view(Self, @types.TextureId, @types.TextureViewDescriptor) -> @types.TextureViewId raise HalError
  fn create_sampler(Self, @types.SamplerDescriptor) -> @types.SamplerId raise HalError
  fn create_shader_module(Self, @types.ShaderModuleDescriptor) -> @types.ShaderModuleId raise HalError
  ///|
  /// What the backend's shader compiler said about a module. A backend without
  /// a compiler reports nothing, which is not the same as reporting success:
  /// the module is then only as good as the caller's own checking.
  fn compilation_info(Self, @types.ShaderModuleId) -> Array[
    @types.CompilationMessage,
  ]
  fn create_bind_group_layout(Self, @types.BindGroupLayoutDescriptor) -> @types.BindGroupLayoutId raise HalError
  fn create_bind_group(Self, @types.BindGroupDescriptor) -> @types.BindGroupId raise HalError
  fn create_pipeline_layout(Self, @types.PipelineLayoutDescriptor) -> @types.PipelineLayoutId raise HalError
  fn create_render_pipeline(Self, @types.RenderPipelineDescriptor) -> @types.RenderPipelineId raise HalError
  fn create_compute_pipeline(Self, @types.ComputePipelineDescriptor) -> @types.ComputePipelineId raise HalError
  fn create_query_set(Self, @types.QuerySetDescriptor) -> @types.QuerySetId raise HalError
  ///|
  /// Take a frame a host decoded and hold it as a texture the caller can bind.
  fn create_external_texture(Self, @types.ExternalTextureDescriptor) -> @types.ExternalTextureId raise HalError
  fn destroy_external_texture(Self, @types.ExternalTextureId) -> Unit
  ///|
  /// Run the commands in order. Every resource the commands name exists: the
  /// layer above has already refused a command buffer that outlives one.
  fn submit(Self, Array[@types.Command]) -> Unit raise HalError
  ///|
  /// Copy the texels of one subresource into `data`, row by row, with no
  /// padding between rows. Used by the read-back path.
  fn read_texture(
    Self,
    @types.TextureId,
    @types.Origin3d,
    @types.Extent3d,
    Int32,
  ) -> Bytes raise HalError
  ///|
  /// Write texels from `data`, which is packed row by row. The caller has
  /// validated the region and the format.
  fn write_texture(
    Self,
    @types.TextureId,
    @types.Origin3d,
    @types.Extent3d,
    Int32,
    Bytes,
  ) -> Unit raise HalError
}
