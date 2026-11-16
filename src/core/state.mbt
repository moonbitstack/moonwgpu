// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The state of one buffer as the device tracks it.
pub struct BufferState {
  descriptor : @types.BufferDescriptor
  mut destroyed : Bool
  mapped : Bool
}

///|
/// The state of one texture.
pub struct TextureState {
  descriptor : @types.TextureDescriptor
  mut destroyed : Bool
}

///|
/// The state of one texture view: what it resolves to, so that a bind group
/// can be checked against a layout without asking the backend.
pub struct ViewState {
  texture : @types.TextureId
  format : @types.TextureFormat
  dimension : @types.TextureViewDimension
  aspect : @types.TextureAspect
  mip_level_count : Int32
  array_layer_count : Int32
  destroyed : Bool
}

///|
/// The state of one sampler.
pub struct SamplerState {
  descriptor : @types.SamplerDescriptor
  filtering : Bool
  comparison : Bool
}

///|
/// The state of one shader module.
pub struct ShaderModuleState {
  descriptor : @types.ShaderModuleDescriptor
}

///|
/// The state of one bind group layout.
pub struct BindGroupLayoutState {
  descriptor : @types.BindGroupLayoutDescriptor
}

///|
/// The state of one pipeline layout.
pub struct PipelineLayoutState {
  descriptor : @types.PipelineLayoutDescriptor
}

///|
/// The state of one bind group.
pub struct BindGroupState {
  layout : @types.BindGroupLayoutId
  descriptor : @types.BindGroupDescriptor
}

///|
/// Turn a backend's complaint into the error the caller sees.
pub fn Refused::from_hal(error : @hal.HalError) -> Refused {
  match error {
    Exhausted(want~, limit~) =>
      OutOfMemory(at="device allocation", limit~, want~)
    Missing(what~) => Internal(message="backend lost \{what}")
    Unsupported(what~) => Internal(message="backend cannot \{what}")
    Failed(what~) => Internal(message="backend failed: \{what}")
  }
}
