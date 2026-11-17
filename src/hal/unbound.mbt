// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A backend that is named but not bound.
///
/// Every graphics API needs a stub of C functions before MoonBit can call it,
/// and a platform needs a window before it can present. Until that stub exists,
/// a backend still has to be a name: this is it. It carries the name of the API
/// it stands for and the reason it cannot work, and refuses every call with
/// that reason, so that code written against a real backend compiles and fails
/// where it should instead of at the wrong layer.
///
/// It is also the honest way to test error routing: a refusal from here passes
/// through the same path a driver failure does.
pub struct Unbound {
  ///
  /// What this backend is called, as in `"vulkan"`.
  name_ : String
  ///
  /// What is missing, in the words of whoever bound the name.
  reason_ : String
}

///|
/// A backend name without a binding.
pub fn Unbound::new(name~ : String, reason~ : String = "") -> Unbound {
  { name_: name, reason_: reason, }
}

///|
/// What is missing.
pub fn Unbound::reason(self : Unbound) -> String {
  if self.reason_.is_empty() {
    "\{self.name_}: this backend is not bound"
  } else {
    self.reason_
  }
}

///|
pub impl Hal for Unbound with fn name(self) {
  self.name_
}

///|
pub impl Hal for Unbound with fn limits(_self) {
  @types.Limits::webgpu()
}

///|
pub impl Hal for Unbound with fn features(_self) {
  @types.Features::none()
}

///|
pub impl Hal for Unbound with fn create_buffer(self, _descriptor) -> @types.BufferId raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn destroy_buffer(_self, _id) {
  ()
}

///|
pub impl Hal for Unbound with fn write_buffer(self, _id, _offset, _data) -> Unit raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn read_buffer(self, _id, _offset, _size) -> Bytes raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn create_texture(self, _descriptor) -> @types.TextureId raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn destroy_texture(_self, _id) {
  ()
}

///|
pub impl Hal for Unbound with fn create_texture_view(
  self,
  _texture,
  _descriptor,
) -> @types.TextureViewId raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn create_sampler(self, _descriptor) -> @types.SamplerId raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn create_shader_module(self, _descriptor) -> @types.ShaderModuleId raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn compilation_info(_self, _id) {
  []
}

///|
pub impl Hal for Unbound with fn create_bind_group_layout(self, _descriptor) -> @types.BindGroupLayoutId raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn create_bind_group(self, _descriptor) -> @types.BindGroupId raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn create_pipeline_layout(self, _descriptor) -> @types.PipelineLayoutId raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn create_render_pipeline(self, _descriptor) -> @types.RenderPipelineId raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn create_compute_pipeline(self, _descriptor) -> @types.ComputePipelineId raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn create_query_set(self, _descriptor) -> @types.QuerySetId raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn create_external_texture(self, _descriptor) -> @types.ExternalTextureId raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn destroy_external_texture(_self, _id) {
  ()
}

///|
pub impl Hal for Unbound with fn submit(self, _commands) -> Unit raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn read_texture(
  self,
  _id,
  _origin,
  _size,
  _mip_level,
) -> Bytes raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
pub impl Hal for Unbound with fn write_texture(
  self,
  _id,
  _origin,
  _size,
  _mip_level,
  _data,
) -> Unit raise HalError {
  raise HalError::unsupported(self.reason())
}

///|
#doc(hidden)
pub extend Unbound with Hal::{
  name,
  limits,
  features,
  create_buffer,
  destroy_buffer,
  write_buffer,
  read_buffer,
  create_texture,
  destroy_texture,
  create_texture_view,
  create_sampler,
  create_shader_module,
  compilation_info,
  create_bind_group_layout,
  create_bind_group,
  create_pipeline_layout,
  create_render_pipeline,
  create_compute_pipeline,
  create_query_set,
  create_external_texture,
  destroy_external_texture,
  submit,
  read_texture,
  write_texture,
}
