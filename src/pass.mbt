// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The two pass encoders. A pass records into its own list and hands it to the
// frame when it ends; using a pass after `end` is refused, as the specification
// requires.

///|
/// Records the commands of one render pass.
pub struct RenderPassEncoder {
  frame : @core.Frame
  descriptor : @types.RenderPassDescriptor
  commands : Array[@types.RenderCommand]
  mut ended : Bool
  label : String
}

///|
/// The pass's label.
pub fn RenderPassEncoder::label(self : RenderPassEncoder) -> String {
  self.label
}

///|
/// Refuse anything recorded after `end`.
fn RenderPassEncoder::check_open(
  self : RenderPassEncoder,
) -> Unit raise @core.Refused {
  @core.require(
    !self.ended,
    @types.InvalidPassState,
    "renderPass",
    "a pass that has not ended",
    "an ended pass",
  )
}

///|
/// `setPipeline`.
/// https://www.w3.org/TR/webgpu/#dom-gpurenderpassencoder-setpipeline
pub fn RenderPassEncoder::set_pipeline(
  self : RenderPassEncoder,
  pipeline~ : RenderPipeline,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::SetPipeline(pipeline.id))
}

///|
/// `setBindGroup`.
pub fn RenderPassEncoder::set_bind_group(
  self : RenderPassEncoder,
  index~ : Int32,
  bind_group~ : BindGroup,
  dynamic_offsets~ : Array[Int32] = [],
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::SetBindGroup({
      index,
      group: bind_group.id,
      dynamic_offsets,
    }),
  )
}

///|
/// `setVertexBuffer`.
pub fn RenderPassEncoder::set_vertex_buffer(
  self : RenderPassEncoder,
  slot~ : Int32,
  buffer~ : Buffer,
  offset~ : Int32 = 0,
  size? : Int32,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::SetVertexBuffer({
      slot,
      buffer: buffer.id,
      offset,
      size,
    }),
  )
}

///|
/// `setIndexBuffer`.
pub fn RenderPassEncoder::set_index_buffer(
  self : RenderPassEncoder,
  buffer~ : Buffer,
  format~ : @types.IndexFormat,
  offset~ : Int32 = 0,
  size? : Int32,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::SetIndexBuffer({
      buffer: buffer.id,
      format,
      offset,
      size,
    }),
  )
}

///|
/// `draw`.
pub fn RenderPassEncoder::draw(
  self : RenderPassEncoder,
  arguments~ : @types.DrawArguments,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::Draw(arguments))
}

///|
/// `drawIndexed`.
pub fn RenderPassEncoder::draw_indexed(
  self : RenderPassEncoder,
  arguments~ : @types.DrawIndexedArguments,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::DrawIndexed(arguments))
}

///|
/// `drawIndirect`: the four arguments come from a buffer.
/// https://www.w3.org/TR/webgpu/#dom-gpurenderpassencoder-drawindirect
pub fn RenderPassEncoder::draw_indirect(
  self : RenderPassEncoder,
  buffer~ : Buffer,
  offset~ : Int32 = 0,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::DrawIndirect({ buffer: buffer.id, offset, }),
  )
}

///|
/// `drawIndexedIndirect`.
pub fn RenderPassEncoder::draw_indexed_indirect(
  self : RenderPassEncoder,
  buffer~ : Buffer,
  offset~ : Int32 = 0,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::DrawIndexedIndirect({ buffer: buffer.id, offset, }),
  )
}

///|
/// `executeBundles`: run the recorded bundles in this pass, in order.
/// https://www.w3.org/TR/webgpu/#dom-gpurenderpassencoder-executebundles
pub fn RenderPassEncoder::execute_bundles(
  self : RenderPassEncoder,
  bundles~ : Array[@types.RenderBundle],
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::ExecuteBundles(bundles))
}

///|
/// `insertDebugMarker`.
pub fn RenderPassEncoder::insert_debug_marker(
  self : RenderPassEncoder,
  marker~ : String,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::InsertDebugMarker(marker))
}

///|
/// `pushDebugGroup`.
pub fn RenderPassEncoder::push_debug_group(
  self : RenderPassEncoder,
  group_label~ : String,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::PushDebugGroup(group_label))
}

///|
/// `popDebugGroup`.
pub fn RenderPassEncoder::pop_debug_group(
  self : RenderPassEncoder,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::PopDebugGroup)
}

///|
/// `setViewport`.
pub fn RenderPassEncoder::set_viewport(
  self : RenderPassEncoder,
  x~ : Double,
  y~ : Double,
  width~ : Double,
  height~ : Double,
  min_depth~ : Double = 0.0,
  max_depth~ : Double = 1.0,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::SetViewport({
      x,
      y,
      width,
      height,
      min_depth,
      max_depth,
    }),
  )
}

///|
/// `setScissorRect`.
pub fn RenderPassEncoder::set_scissor_rect(
  self : RenderPassEncoder,
  x~ : Int32,
  y~ : Int32,
  width~ : Int32,
  height~ : Int32,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::SetScissorRect({ x, y, width, height, }),
  )
}

///|
/// `setBlendConstant`.
pub fn RenderPassEncoder::set_blend_constant(
  self : RenderPassEncoder,
  color~ : @types.Color,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::SetBlendConstant(color))
}

///|
/// `setStencilReference`.
pub fn RenderPassEncoder::set_stencil_reference(
  self : RenderPassEncoder,
  reference~ : Int32,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::SetStencilReference(reference))
}

///|
/// `beginOcclusionQuery`.
pub fn RenderPassEncoder::begin_occlusion_query(
  self : RenderPassEncoder,
  query_index~ : Int32,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::BeginOcclusionQuery(query_index))
}

///|
/// `endOcclusionQuery`.
pub fn RenderPassEncoder::end_occlusion_query(
  self : RenderPassEncoder,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::EndOcclusionQuery)
}

///|
/// `writeTimestamp`.
pub fn RenderPassEncoder::write_timestamp(
  self : RenderPassEncoder,
  query_set~ : QuerySet,
  query_index~ : Int32,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::WriteTimestamp({
      query_set: query_set.id,
      query_index,
    }),
  )
}

///|
/// End the pass and keep what it recorded.
/// https://www.w3.org/TR/webgpu/#dom-gpurenderpassencoder-end
pub fn RenderPassEncoder::end(
  self : RenderPassEncoder,
) -> Unit raise @core.Refused {
  self.check_open()
  self.ended = true
  self.frame.close_pass(
    @types.Command::RenderPass({
      label: self.descriptor.label,
      color_attachments: self.descriptor.color_attachments,
      depth_stencil_attachment: self.descriptor.depth_stencil_attachment,
      timestamp_writes: self.descriptor.timestamp_writes,
      occlusion_query_set: self.descriptor.occlusion_query_set,
      commands: self.commands.copy(),
    }),
  )
}

///|
/// Records the commands of one compute pass.
pub struct ComputePassEncoder {
  frame : @core.Frame
  descriptor : @types.ComputePassDescriptor
  commands : Array[@types.ComputeCommand]
  mut ended : Bool
  label : String
}

///|
/// The pass's label.
pub fn ComputePassEncoder::label(self : ComputePassEncoder) -> String {
  self.label
}

///|
/// Refuse anything recorded after `end`.
fn ComputePassEncoder::check_open(
  self : ComputePassEncoder,
) -> Unit raise @core.Refused {
  @core.require(
    !self.ended,
    @types.InvalidPassState,
    "computePass",
    "a pass that has not ended",
    "an ended pass",
  )
}

///|
/// `setPipeline`.
pub fn ComputePassEncoder::set_pipeline(
  self : ComputePassEncoder,
  pipeline~ : ComputePipeline,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.ComputeCommand::SetPipeline(pipeline.id))
}

///|
/// `setBindGroup`.
pub fn ComputePassEncoder::set_bind_group(
  self : ComputePassEncoder,
  index~ : Int32,
  bind_group~ : BindGroup,
  dynamic_offsets~ : Array[Int32] = [],
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.ComputeCommand::SetBindGroup({
      index,
      group: bind_group.id,
      dynamic_offsets,
    }),
  )
}

///|
/// `dispatchWorkgroups`.
pub fn ComputePassEncoder::dispatch_workgroups(
  self : ComputePassEncoder,
  arguments~ : @types.DispatchArguments,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.ComputeCommand::DispatchWorkgroups(arguments))
}

///|
/// `dispatchWorkgroupsIndirect`: the workgroup counts come from a buffer.
/// https://www.w3.org/TR/webgpu/#dom-gpucomputepassencoder-dispatchworkgroupsindirect
pub fn ComputePassEncoder::dispatch_workgroups_indirect(
  self : ComputePassEncoder,
  buffer~ : Buffer,
  offset~ : Int32 = 0,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.ComputeCommand::DispatchWorkgroupsIndirect({
      buffer: buffer.id,
      offset,
    }),
  )
}

///|
/// `insertDebugMarker`.
pub fn ComputePassEncoder::insert_debug_marker(
  self : ComputePassEncoder,
  marker~ : String,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.ComputeCommand::InsertDebugMarker(marker))
}

///|
/// `pushDebugGroup`.
pub fn ComputePassEncoder::push_debug_group(
  self : ComputePassEncoder,
  group_label~ : String,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.ComputeCommand::PushDebugGroup(group_label))
}

///|
/// `popDebugGroup`.
pub fn ComputePassEncoder::pop_debug_group(
  self : ComputePassEncoder,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.ComputeCommand::PopDebugGroup)
}

///|
/// `writeTimestamp`.
pub fn ComputePassEncoder::write_timestamp(
  self : ComputePassEncoder,
  query_set~ : QuerySet,
  query_index~ : Int32,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.ComputeCommand::WriteTimestamp({
      query_set: query_set.id,
      query_index,
    }),
  )
}

///|
/// End the pass and keep what it recorded.
pub fn ComputePassEncoder::end(
  self : ComputePassEncoder,
) -> Unit raise @core.Refused {
  self.check_open()
  self.ended = true
  self.frame.close_pass(
    @types.Command::ComputePass({
      label: self.descriptor.label,
      timestamp_writes: self.descriptor.timestamp_writes,
      commands: self.commands.copy(),
    }),
  )
}
