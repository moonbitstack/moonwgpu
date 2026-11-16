// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A bind group layout: the shape of a set of resources a shader sees.
pub struct BindGroupLayout {
  device : Device
  id : @types.BindGroupLayoutId
  descriptor : @types.BindGroupLayoutDescriptor
}

///|
/// The layout's identity inside its device.
pub fn BindGroupLayout::id(self : BindGroupLayout) -> @types.BindGroupLayoutId {
  self.id
}

///|
/// The descriptor the layout was created from.
pub fn BindGroupLayout::descriptor(
  self : BindGroupLayout,
) -> @types.BindGroupLayoutDescriptor {
  self.descriptor
}

///|
/// A pipeline layout: the bind group layouts a pipeline draws on.
pub struct PipelineLayout {
  device : Device
  id : @types.PipelineLayoutId
  descriptor : @types.PipelineLayoutDescriptor
}

///|
/// The layout's identity inside its device.
pub fn PipelineLayout::id(self : PipelineLayout) -> @types.PipelineLayoutId {
  self.id
}

///|
/// The descriptor the layout was created from.
pub fn PipelineLayout::descriptor(
  self : PipelineLayout,
) -> @types.PipelineLayoutDescriptor {
  self.descriptor
}

///|
/// A bind group: resources bound together, ready to be set on a pass.
pub struct BindGroup {
  device : Device
  id : @types.BindGroupId
  layout : @types.BindGroupLayoutId
}

///|
/// The group's identity inside its device.
pub fn BindGroup::id(self : BindGroup) -> @types.BindGroupId {
  self.id
}

///|
/// The layout the group was made against.
pub fn BindGroup::layout(self : BindGroup) -> @types.BindGroupLayoutId {
  self.layout
}

///|
/// A render pipeline: the whole fixed function state of a draw.
pub struct RenderPipeline {
  device : Device
  id : @types.RenderPipelineId
  label : String
}

///|
/// The pipeline's identity inside its device.
pub fn RenderPipeline::id(self : RenderPipeline) -> @types.RenderPipelineId {
  self.id
}

///|
/// The pipeline's label.
pub fn RenderPipeline::label(self : RenderPipeline) -> String {
  self.label
}

///|
/// One of the bind group layouts a pipeline was built with.
///
/// A pipeline created without an explicit layout has an automatic one, which
/// this layer does not model: reflection needs the shader's own declarations.
/// https://www.w3.org/TR/webgpu/#dom-gpupipelinebase-getbindgrouplayout
pub fn RenderPipeline::get_bind_group_layout(
  self : RenderPipeline,
  index~ : Int32,
) -> BindGroupLayout raise @core.Refused {
  let layout = match self.device.hub.render_pipeline_layout(self.id) {
    Some(layout) => layout
    None =>
      raise @core.invalid(
        @types.InvalidPipelineLayout,
        "pipeline.layout",
        "a pipeline built with an explicit layout",
        "an automatic layout",
      )
  }
  let pipeline_layout = self.device.hub.pipeline_layout(layout)
  @core.require_int(
    index >= 0 && index < pipeline_layout.descriptor.bind_group_layouts.length(),
    @types.InvalidPipelineLayout,
    "index",
    pipeline_layout.descriptor.bind_group_layouts.length() - 1,
    index,
  )
  let id = pipeline_layout.descriptor.bind_group_layouts[index]
  let state = self.device.hub.bind_group_layout(id)
  { device: self.device, id, descriptor: state.descriptor, }
}

///|
/// A compute pipeline: one compute entry point and its layout.
pub struct ComputePipeline {
  device : Device
  id : @types.ComputePipelineId
  label : String
}

///|
/// The pipeline's identity inside its device.
pub fn ComputePipeline::id(self : ComputePipeline) -> @types.ComputePipelineId {
  self.id
}

///|
/// The pipeline's label.
pub fn ComputePipeline::label(self : ComputePipeline) -> String {
  self.label
}

///|
/// One of the bind group layouts a pipeline was built with.
pub fn ComputePipeline::get_bind_group_layout(
  self : ComputePipeline,
  index~ : Int32,
) -> BindGroupLayout raise @core.Refused {
  let layout = match self.device.hub.compute_pipeline_layout(self.id) {
    Some(layout) => layout
    None =>
      raise @core.invalid(
        @types.InvalidPipelineLayout,
        "pipeline.layout",
        "a pipeline built with an explicit layout",
        "an automatic layout",
      )
  }
  let pipeline_layout = self.device.hub.pipeline_layout(layout)
  @core.require_int(
    index >= 0 && index < pipeline_layout.descriptor.bind_group_layouts.length(),
    @types.InvalidPipelineLayout,
    "index",
    pipeline_layout.descriptor.bind_group_layouts.length() - 1,
    index,
  )
  let id = pipeline_layout.descriptor.bind_group_layouts[index]
  let state = self.device.hub.bind_group_layout(id)
  { device: self.device, id, descriptor: state.descriptor, }
}

///|
/// A query set: the timestamps or occlusion results a pass writes.
pub struct QuerySet {
  device : Device
  id : @types.QuerySetId
  descriptor : @types.QuerySetDescriptor
}

///|
/// The set's identity inside its device.
pub fn QuerySet::id(self : QuerySet) -> @types.QuerySetId {
  self.id
}

///|
/// How many queries the set holds.
pub fn QuerySet::count(self : QuerySet) -> Int32 {
  self.descriptor.count
}

///|
/// What the set records.
pub fn QuerySet::kind(self : QuerySet) -> @types.QueryType {
  self.descriptor.kind
}

///|
/// Destroy the set. Later uses are refused.
/// https://www.w3.org/TR/webgpu/#dom-gpuqueryset-destroy
pub fn QuerySet::destroy(self : QuerySet) -> Unit {
  self.device.hub.destroy_query_set(self.id)
}
