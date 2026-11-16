// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A device: the object that makes resources and records work.
///
/// The state lives in a `@core.Hub`, so copying a `Device` copies a handle and
/// not a device. That is the same arrangement the specification has, where
/// every object carries a reference to its device.
pub struct Device {
  hub : @core.Hub
  label : String
  default_queue_label : String
}

///|
/// The device's label.
pub fn Device::label(self : Device) -> String {
  self.label
}

///|
/// The limits the device was created with.
pub fn Device::limits(self : Device) -> @types.Limits {
  self.hub.limits()
}

///|
/// The features the device was created with.
pub fn Device::features(self : Device) -> @types.Features {
  self.hub.features()
}

///|
/// The queue work is submitted to. One device has one queue.
pub fn Device::queue(self : Device) -> Queue {
  { device: self, label: self.default_queue_label, }
}

///|
/// The backend's name, for diagnostics.
pub fn Device::backend_name(self : Device) -> String {
  self.hub.backend_name()
}

///|
/// Lose the device: every later call is refused, as after a real device loss.
pub fn Device::destroy(self : Device) -> Unit {
  self.hub.lose()
}

///|
/// Whether the device has been lost.
pub fn Device::lost(self : Device) -> Bool {
  self.hub.lost
}

///|
/// Push an error scope: the errors the device itself generates while it is on
/// top are collected for `pop_error_scope` instead of being lost.
/// https://www.w3.org/TR/webgpu/#dom-gpudevice-pusherrorscope
pub fn Device::push_error_scope(
  self : Device,
  filter~ : @types.ErrorFilter = @types.ErrorFilter::Validation,
) -> Unit {
  self.hub.push_error_scope(filter)
}

///|
/// Pop the innermost error scope and hand back what it collected.
/// https://www.w3.org/TR/webgpu/#dom-gpudevice-poperrorscope
pub fn Device::pop_error_scope(
  self : Device,
) -> Array[@core.Refused] raise @core.Refused {
  self.hub.pop_error_scope()
}

///|
/// A `GPUBufferDescriptor` to a buffer.
/// https://www.w3.org/TR/webgpu/#dom-gpudevice-createbuffer
pub fn Device::create_buffer(
  self : Device,
  descriptor~ : @types.BufferDescriptor,
) -> Buffer raise @core.Refused {
  let id = self.hub.create_buffer(descriptor)
  {
    device: self,
    id,
    size: descriptor.size,
    usage: descriptor.usage,
    mapped: None,
    destroyed: false,
  }
}

///|
/// A `GPUTextureDescriptor` to a texture.
pub fn Device::create_texture(
  self : Device,
  descriptor~ : @types.TextureDescriptor,
) -> Texture raise @core.Refused {
  let id = self.hub.create_texture(descriptor)
  { device: self, id, descriptor, destroyed: false, }
}

///|
/// A `GPUSamplerDescriptor` to a sampler.
pub fn Device::create_sampler(
  self : Device,
  descriptor~ : @types.SamplerDescriptor = @types.SamplerDescriptor::new(),
) -> Sampler raise @core.Refused {
  let id = self.hub.create_sampler(descriptor)
  { device: self, id, descriptor, }
}

///|
/// A `GPUShaderModuleDescriptor` to a shader module.
pub fn Device::create_shader_module(
  self : Device,
  descriptor~ : @types.ShaderModuleDescriptor,
) -> ShaderModule raise @core.Refused {
  let id = self.hub.create_shader_module(descriptor)
  { device: self, id, label: descriptor.label, }
}

///|
/// A `GPUBindGroupLayoutDescriptor` to a bind group layout.
pub fn Device::create_bind_group_layout(
  self : Device,
  descriptor~ : @types.BindGroupLayoutDescriptor,
) -> BindGroupLayout raise @core.Refused {
  let id = self.hub.create_bind_group_layout(descriptor)
  { device: self, id, descriptor, }
}

///|
/// A `GPUPipelineLayoutDescriptor` to a pipeline layout.
pub fn Device::create_pipeline_layout(
  self : Device,
  descriptor~ : @types.PipelineLayoutDescriptor,
) -> PipelineLayout raise @core.Refused {
  let id = self.hub.create_pipeline_layout(descriptor)
  { device: self, id, descriptor, }
}

///|
/// A `GPUBindGroupDescriptor` to a bind group.
pub fn Device::create_bind_group(
  self : Device,
  descriptor~ : @types.BindGroupDescriptor,
) -> BindGroup raise @core.Refused {
  let id = self.hub.create_bind_group(descriptor)
  { device: self, id, layout: descriptor.layout, }
}

///|
/// A `GPURenderPipelineDescriptor` to a render pipeline.
pub fn Device::create_render_pipeline(
  self : Device,
  descriptor~ : @types.RenderPipelineDescriptor,
) -> RenderPipeline raise @core.Refused {
  let id = self.hub.create_render_pipeline(descriptor)
  { device: self, id, label: descriptor.label, }
}

///|
/// A `GPUComputePipelineDescriptor` to a compute pipeline.
pub fn Device::create_compute_pipeline(
  self : Device,
  descriptor~ : @types.ComputePipelineDescriptor,
) -> ComputePipeline raise @core.Refused {
  let id = self.hub.create_compute_pipeline(descriptor)
  { device: self, id, label: descriptor.label, }
}

///|
/// A `GPUQuerySetDescriptor` to a query set.
pub fn Device::create_query_set(
  self : Device,
  descriptor~ : @types.QuerySetDescriptor,
) -> QuerySet raise @core.Refused {
  let id = self.hub.create_query_set(descriptor)
  { device: self, id, descriptor, }
}

///|
/// An encoder with nothing recorded.
pub fn Device::create_command_encoder(
  self : Device,
  label~ : String = "",
) -> CommandEncoder {
  { device: self, frame: @core.Frame::new(), label, }
}
