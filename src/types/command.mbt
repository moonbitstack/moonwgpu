// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Where the bytes of one row start and how far apart rows are:
/// `GPUTexelCopyBufferLayout`.
///
/// `bytes_per_row` and `rows_per_image` are `None` for a copy that is one row
/// or one layer deep, and must be given for anything larger.
#derive(Debug)
pub(all) struct TexelCopyBufferLayout {
  offset : Int32
  bytes_per_row : Int32?
  rows_per_image : Int32?
}

///|
pub fn TexelCopyBufferLayout::new(
  offset~ : Int32 = 0,
  bytes_per_row? : Int32,
  rows_per_image? : Int32,
) -> TexelCopyBufferLayout {
  { offset, bytes_per_row, rows_per_image, }
}

///|
/// A `GPUTexelCopyBufferInfo`: a buffer plus the layout of the texels in it.
#derive(Debug)
pub(all) struct TexelCopyBufferInfo {
  buffer : BufferId
  layout : TexelCopyBufferLayout
}

///|
pub fn TexelCopyBufferInfo::new(
  buffer~ : BufferId,
  layout~ : TexelCopyBufferLayout,
) -> TexelCopyBufferInfo {
  { buffer, layout, }
}

///|
/// A `GPUTexelCopyTextureInfo`: a subresource of a texture.
#derive(Debug)
pub(all) struct TexelCopyTextureInfo {
  texture : TextureId
  mip_level : Int32
  origin : Origin3d
  aspect : TextureAspect
}

///|
pub fn TexelCopyTextureInfo::new(
  texture~ : TextureId,
  mip_level~ : Int32 = 0,
  origin~ : Origin3d = Origin3d::new(),
  aspect~ : TextureAspect = TextureAspect::All,
) -> TexelCopyTextureInfo {
  { texture, mip_level, origin, aspect, }
}

///|
/// One colour attachment of a render pass.
#derive(Debug)
pub(all) struct ColorAttachment {
  view : TextureViewId
  resolve_target : TextureViewId?
  load_op : LoadOp
  clear_value : Color
  store : StoreOp
}

///|
pub fn ColorAttachment::new(
  view~ : TextureViewId,
  resolve_target? : TextureViewId,
  load_op~ : LoadOp = LoadOp::Load,
  clear_value~ : Color = Color::black(),
  store~ : StoreOp = StoreOp::Store,
) -> ColorAttachment {
  { view, resolve_target, load_op, clear_value, store, }
}

///|
/// The depth-stencil attachment of a render pass. A read-only attachment may
/// not be written: it has no store operation and its load operation must
/// preserve the contents.
#derive(Debug)
pub(all) struct DepthStencilAttachment {
  view : TextureViewId
  depth_load_op : LoadOp
  depth_clear_value : Double
  depth_store : StoreOp
  depth_read_only : Bool
  stencil_load_op : LoadOp
  stencil_clear_value : Int32
  stencil_store : StoreOp
  stencil_read_only : Bool
}

///|
pub fn DepthStencilAttachment::new(
  view~ : TextureViewId,
  depth_load_op~ : LoadOp = LoadOp::Load,
  depth_clear_value~ : Double = 1.0,
  depth_store~ : StoreOp = StoreOp::Store,
  depth_read_only~ : Bool = false,
  stencil_load_op~ : LoadOp = LoadOp::Load,
  stencil_clear_value~ : Int32 = 0,
  stencil_store~ : StoreOp = StoreOp::Store,
  stencil_read_only~ : Bool = false,
) -> DepthStencilAttachment {
  {
    view,
    depth_load_op,
    depth_clear_value,
    depth_store,
    depth_read_only,
    stencil_load_op,
    stencil_clear_value,
    stencil_store,
    stencil_read_only,
  }
}

///|
/// Which timestamps a pass writes: `GPURenderPassTimestampWrites`.
#derive(Debug)
pub(all) struct PassTimestampWrites {
  query_set : QuerySetId
  beginning_of_pass_write_index : Int32?
  end_of_pass_write_index : Int32?
}

///|
pub fn PassTimestampWrites::new(
  query_set~ : QuerySetId,
  beginning_of_pass_write_index? : Int32,
  end_of_pass_write_index? : Int32,
) -> PassTimestampWrites {
  { query_set, beginning_of_pass_write_index, end_of_pass_write_index, }
}

///|
/// A `GPURenderPassDescriptor`.
#derive(Debug)
pub(all) struct RenderPassDescriptor {
  label : String
  color_attachments : Array[ColorAttachment]
  depth_stencil_attachment : DepthStencilAttachment?
  timestamp_writes : PassTimestampWrites?
  occlusion_query_set : QuerySetId?
}

///|
pub fn RenderPassDescriptor::new(
  color_attachments~ : Array[ColorAttachment] = [],
  depth_stencil_attachment? : DepthStencilAttachment,
  timestamp_writes? : PassTimestampWrites,
  occlusion_query_set? : QuerySetId,
  label~ : String = "",
) -> RenderPassDescriptor {
  {
    label,
    color_attachments,
    depth_stencil_attachment,
    timestamp_writes,
    occlusion_query_set,
  }
}

///|
/// A `GPUComputePassDescriptor`.
#derive(Debug)
pub(all) struct ComputePassDescriptor {
  label : String
  timestamp_writes : PassTimestampWrites?
}

///|
pub fn ComputePassDescriptor::new(
  label~ : String = "",
  timestamp_writes? : PassTimestampWrites,
) -> ComputePassDescriptor {
  { label, timestamp_writes, }
}

///|
/// The arguments of `draw`.
#derive(Eq, Debug)
pub(all) struct DrawArguments {
  vertex_count : Int32
  instance_count : Int32
  first_vertex : Int32
  first_instance : Int32
}

///|
pub fn DrawArguments::new(
  vertex_count~ : Int32,
  instance_count~ : Int32 = 1,
  first_vertex~ : Int32 = 0,
  first_instance~ : Int32 = 0,
) -> DrawArguments {
  { vertex_count, instance_count, first_vertex, first_instance, }
}

///|
/// The arguments of `draw_indexed`.
#derive(Eq, Debug)
pub(all) struct DrawIndexedArguments {
  index_count : Int32
  instance_count : Int32
  first_index : Int32
  base_vertex : Int32
  first_instance : Int32
}

///|
pub fn DrawIndexedArguments::new(
  index_count~ : Int32,
  instance_count~ : Int32 = 1,
  first_index~ : Int32 = 0,
  base_vertex~ : Int32 = 0,
  first_instance~ : Int32 = 0,
) -> DrawIndexedArguments {
  { index_count, instance_count, first_index, base_vertex, first_instance, }
}

///|
/// The arguments of `dispatch_workgroups`.
#derive(Eq, Debug)
pub(all) struct DispatchArguments {
  x : Int32
  y : Int32
  z : Int32
}

///|
pub fn DispatchArguments::new(
  x~ : Int32,
  y~ : Int32 = 1,
  z~ : Int32 = 1,
) -> DispatchArguments {
  { x, y, z, }
}

///|
/// One `copy_buffer_to_buffer`.
#derive(Debug)
pub(all) struct CopyBufferToBuffer {
  source : BufferId
  source_offset : Int32
  destination : BufferId
  destination_offset : Int32
  size : Int32
}

///|
/// One `copy_buffer_to_texture`.
#derive(Debug)
pub(all) struct CopyBufferToTexture {
  source : TexelCopyBufferInfo
  destination : TexelCopyTextureInfo
  copy_size : Extent3d
}

///|
/// One `copy_texture_to_buffer`.
#derive(Debug)
pub(all) struct CopyTextureToBuffer {
  source : TexelCopyTextureInfo
  destination : TexelCopyBufferInfo
  copy_size : Extent3d
}

///|
/// One `copy_texture_to_texture`.
#derive(Debug)
pub(all) struct CopyTextureToTexture {
  source : TexelCopyTextureInfo
  destination : TexelCopyTextureInfo
  copy_size : Extent3d
}

///|
/// `GPUCopyExternalImageSourceInfo`: the pixels to copy and where in them to
/// start, with `flip_y` for a frame whose rows are bottom-first.
#derive(Debug)
pub(all) struct CopyExternalImageSourceInfo {
  image : ExternalImage
  origin : Origin3d
  flip_y : Bool
}

///|
pub fn CopyExternalImageSourceInfo::new(
  image~ : ExternalImage,
  origin~ : Origin3d = Origin3d::new(),
  flip_y~ : Bool = false,
) -> CopyExternalImageSourceInfo {
  { image, origin, flip_y, }
}

///|
/// `GPUCopyExternalImageDestInfo`: where the pixels land, whether their alpha
/// is premultiplied on the way, and in which colour space.
#derive(Debug)
pub(all) struct CopyExternalImageDestInfo {
  texture : TextureId
  mip_level : Int32
  origin : Origin3d
  aspect : TextureAspect
  premultiplied_alpha : Bool
  color_space : PredefinedColorSpace
}

///|
pub fn CopyExternalImageDestInfo::new(
  texture~ : TextureId,
  mip_level~ : Int32 = 0,
  origin~ : Origin3d = Origin3d::new(),
  aspect~ : TextureAspect = TextureAspect::All,
  premultiplied_alpha~ : Bool = false,
  color_space~ : PredefinedColorSpace = PredefinedColorSpace::Srgb,
) -> CopyExternalImageDestInfo {
  { texture, mip_level, origin, aspect, premultiplied_alpha, color_space, }
}

///|
/// One `clear_buffer`.
#derive(Debug)
pub(all) struct ClearBuffer {
  buffer : BufferId
  offset : Int32
  size : Int32
}

///|
/// `resolveQuerySet`: the results of a query set into a buffer.
#derive(Debug)
pub(all) struct ResolveQuerySet {
  query_set : QuerySetId
  first_query : Int32
  query_count : Int32
  destination : BufferId
  destination_offset : Int32
}

///|
/// `drawIndirect`: the arguments come from a buffer.
#derive(Debug)
pub(all) struct DrawIndirect {
  buffer : BufferId
  offset : Int32
}

///|
/// `drawIndexedIndirect`: the arguments come from a buffer.
#derive(Debug)
pub(all) struct DrawIndexedIndirect {
  buffer : BufferId
  offset : Int32
}

///|
/// `dispatchWorkgroupsIndirect`: the arguments come from a buffer.
#derive(Debug)
pub(all) struct DispatchIndirect {
  buffer : BufferId
  offset : Int32
}

///|
/// One `clear_texture`.
#derive(Debug)
pub(all) struct ClearTexture {
  texture : TextureId
  mip_level : Int32
  origin : Origin3d
  size : Extent3d
  aspect : TextureAspect
}

///|
/// A recorded command. A command buffer is a list of these; the backend
/// executes them in order.
#derive(Debug)
pub(all) enum Command {
  CopyBufferToBuffer(CopyBufferToBuffer)
  CopyBufferToTexture(CopyBufferToTexture)
  CopyTextureToBuffer(CopyTextureToBuffer)
  CopyTextureToTexture(CopyTextureToTexture)
  ClearBuffer(ClearBuffer)
  ClearTexture(ClearTexture)
  ResolveQuerySet(ResolveQuerySet)
  RenderPass(RenderPassCommand)
  ComputePass(ComputePassCommand)
}

///|
/// A render pass that has been recorded and ended.
#derive(Debug)
pub(all) struct RenderPassCommand {
  label : String
  color_attachments : Array[ColorAttachment]
  depth_stencil_attachment : DepthStencilAttachment?
  timestamp_writes : PassTimestampWrites?
  occlusion_query_set : QuerySetId?
  commands : Array[RenderCommand]
}

///|
/// One command inside a render pass.
#derive(Debug)
pub(all) enum RenderCommand {
  SetPipeline(RenderPipelineId)
  SetBindGroup(SetBindGroup)
  SetImmediates(SetImmediates)
  SetVertexBuffer(SetVertexBuffer)
  SetIndexBuffer(SetIndexBuffer)
  Draw(DrawArguments)
  DrawIndexed(DrawIndexedArguments)
  DrawIndirect(DrawIndirect)
  DrawIndexedIndirect(DrawIndexedIndirect)
  SetViewport(SetViewport)
  SetScissorRect(SetScissorRect)
  SetBlendConstant(Color)
  SetStencilReference(Int32)
  BeginOcclusionQuery(Int32)
  EndOcclusionQuery
  WriteTimestamp(WriteTimestamp)
  ExecuteBundles(Array[RenderBundle])
  InsertDebugMarker(String)
  PushDebugGroup(String)
  PopDebugGroup
}

///|
/// One `set_bind_group`, with the offsets of its dynamic bindings.
#derive(Debug)
pub(all) struct SetBindGroup {
  index : Int32
  group : BindGroupId
  dynamic_offsets : Array[Int32]
}

///|
/// One `set_immediates`: bytes loaded into the immediate constants of one bind
/// group slot, for the draw or dispatch that follows.
///
/// The bytes are already the run the caller named: `data_offset` and
/// `data_size`, when given, have been applied.
#derive(Debug)
pub(all) struct SetImmediates {
  range_offset : Int32
  data : Bytes
}

///|
pub fn SetImmediates::new(
  range_offset~ : Int32,
  data~ : Bytes,
) -> SetImmediates {
  { range_offset, data, }
}

///|
/// One `set_vertex_buffer`.
#derive(Debug)
pub(all) struct SetVertexBuffer {
  slot : Int32
  buffer : BufferId
  offset : Int32
  size : Int32?
}

///|
/// One `set_index_buffer`.
#derive(Debug)
pub(all) struct SetIndexBuffer {
  buffer : BufferId
  format : IndexFormat
  offset : Int32
  size : Int32?
}

///|
/// A viewport: `set_viewport`.
#derive(Debug)
pub(all) struct SetViewport {
  x : Double
  y : Double
  width : Double
  height : Double
  min_depth : Double
  max_depth : Double
}

///|
/// A scissor rectangle: `set_scissor_rect`.
#derive(Debug)
pub(all) struct SetScissorRect {
  x : Int32
  y : Int32
  width : Int32
  height : Int32
}

///|
/// `write_timestamp`, inside a pass or on a compute pass.
#derive(Debug)
pub(all) struct WriteTimestamp {
  query_set : QuerySetId
  query_index : Int32
}

///|
/// A compute pass that has been recorded and ended.
#derive(Debug)
pub(all) struct ComputePassCommand {
  label : String
  timestamp_writes : PassTimestampWrites?
  commands : Array[ComputeCommand]
}

///|
/// One command inside a compute pass.
#derive(Debug)
pub(all) enum ComputeCommand {
  SetPipeline(ComputePipelineId)
  SetBindGroup(SetBindGroup)
  SetImmediates(SetImmediates)
  DispatchWorkgroups(DispatchArguments)
  DispatchWorkgroupsIndirect(DispatchIndirect)
  WriteTimestamp(WriteTimestamp)
  InsertDebugMarker(String)
  PushDebugGroup(String)
  PopDebugGroup
}

///|
/// A recorded, finished command buffer.
#derive(Debug)
pub(all) struct CommandBuffer {
  label : String
  commands : Array[Command]
}

///|
/// A recorded render bundle: a run of draw commands that can be executed in any
/// number of passes. https://www.w3.org/TR/webgpu/#render-bundles
#derive(Debug)
pub(all) struct RenderBundle {
  label : String
  commands : Array[RenderCommand]
}
