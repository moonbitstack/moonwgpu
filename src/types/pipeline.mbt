// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// `GPUVertexStepMode`: whether a vertex buffer advances per vertex or per
/// instance.
#derive(Eq, Debug)
pub(all) enum VertexStepMode {
  Vertex
  Instance
}

///|
/// A `GPUVertexAttribute`.
#derive(Debug)
pub(all) struct VertexAttribute {
  format : VertexFormat
  offset : Int32
  shader_location : Int32
}

///|
pub fn VertexAttribute::new(
  format~ : VertexFormat,
  offset~ : Int32,
  shader_location~ : Int32,
) -> VertexAttribute {
  { format, offset, shader_location, }
}

///|
/// A `GPUVertexBufferLayout`.
#derive(Debug)
pub(all) struct VertexBufferLayout {
  array_stride : Int32
  step_mode : VertexStepMode
  attributes : Array[VertexAttribute]
}

///|
pub fn VertexBufferLayout::new(
  array_stride~ : Int32,
  step_mode~ : VertexStepMode,
  attributes~ : Array[VertexAttribute],
) -> VertexBufferLayout {
  { array_stride, step_mode, attributes, }
}

///|
/// The vertex stage of a pipeline: which shader, which entry point, and how
/// the vertex buffers are laid out.
#derive(Debug)
pub(all) struct VertexState {
  shader : ShaderModuleId
  entry_point : String
  buffers : Array[VertexBufferLayout]
}

///|
pub fn VertexState::new(
  shader~ : ShaderModuleId,
  entry_point~ : String,
  buffers~ : Array[VertexBufferLayout] = [],
) -> VertexState {
  { shader, entry_point, buffers, }
}

///|
/// One component of a blend equation: what multiplies the source, what
/// multiplies the destination, and how the two are combined.
#derive(Debug)
pub(all) struct BlendComponent {
  src_factor : BlendFactor
  dst_factor : BlendFactor
  operation : BlendOperation
}

///|
/// `src * src_factor + dst * dst_factor`.
pub fn BlendComponent::new(
  src_factor~ : BlendFactor = BlendFactor::One,
  dst_factor~ : BlendFactor = BlendFactor::Zero,
  operation~ : BlendOperation = BlendOperation::Add,
) -> BlendComponent {
  { src_factor, dst_factor, operation, }
}

///|
/// A `GPUBlendState`: one equation for colour, one for alpha.
#derive(Debug)
pub(all) struct BlendState {
  color : BlendComponent
  alpha : BlendComponent
}

///|
pub fn BlendState::new(
  color~ : BlendComponent,
  alpha~ : BlendComponent,
) -> BlendState {
  { color, alpha, }
}

///|
/// A `GPUColorTargetState`.
#derive(Debug)
pub(all) struct ColorTargetState {
  format : TextureFormat
  blend : BlendState?
  write_mask : ColorWrites
}

///|
pub fn ColorTargetState::new(
  format~ : TextureFormat,
  blend? : BlendState,
  write_mask~ : ColorWrites = ColorWrites::all(),
) -> ColorTargetState {
  { format, blend, write_mask, }
}

///|
/// The fragment stage of a pipeline.
#derive(Debug)
pub(all) struct FragmentState {
  shader : ShaderModuleId
  entry_point : String
  targets : Array[ColorTargetState]
}

///|
pub fn FragmentState::new(
  shader~ : ShaderModuleId,
  entry_point~ : String,
  targets~ : Array[ColorTargetState],
) -> FragmentState {
  { shader, entry_point, targets, }
}

///|
/// A `GPUPrimitiveState`.
#derive(Debug)
pub(all) struct PrimitiveState {
  topology : PrimitiveTopology
  strip_index_format : IndexFormat?
  front_face : FrontFace
  cull_mode : CullMode
  unclipped_depth : Bool
}

///|
pub fn PrimitiveState::new(
  topology~ : PrimitiveTopology = PrimitiveTopology::TriangleList,
  strip_index_format? : IndexFormat,
  front_face~ : FrontFace = FrontFace::Ccw,
  cull_mode~ : CullMode = CullMode::None,
  unclipped_depth~ : Bool = false,
) -> PrimitiveState {
  { topology, strip_index_format, front_face, cull_mode, unclipped_depth, }
}

///|
/// A `GPUDepthBiasState`.
#derive(Debug)
pub(all) struct DepthBiasState {
  constant : Int32
  slope_scale : Double
  clamp : Double
}

///|
pub fn DepthBiasState::new(
  constant~ : Int32 = 0,
  slope_scale~ : Double = 0.0,
  clamp~ : Double = 0.0,
) -> DepthBiasState {
  { constant, slope_scale, clamp, }
}

///|
/// A `GPUStencilFaceState`.
#derive(Debug)
pub(all) struct StencilFaceState {
  compare : CompareFunction
  fail_op : StencilOperation
  depth_fail_op : StencilOperation
  pass_op : StencilOperation
}

///|
pub fn StencilFaceState::new(
  compare~ : CompareFunction = CompareFunction::Always,
  fail_op~ : StencilOperation = StencilOperation::Keep,
  depth_fail_op~ : StencilOperation = StencilOperation::Keep,
  pass_op~ : StencilOperation = StencilOperation::Keep,
) -> StencilFaceState {
  { compare, fail_op, depth_fail_op, pass_op, }
}

///|
/// A `GPUStencilState`: the same four operations for the two faces.
#derive(Debug)
pub(all) struct StencilState {
  front : StencilFaceState
  back : StencilFaceState
  read_mask : Int32
  write_mask : Int32
}

///|
pub fn StencilState::new(
  front~ : StencilFaceState = StencilFaceState::new(),
  back~ : StencilFaceState = StencilFaceState::new(),
  read_mask~ : Int32 = 0xFF,
  write_mask~ : Int32 = 0xFF,
) -> StencilState {
  { front, back, read_mask, write_mask, }
}

///|
/// A `GPUDepthStencilState`.
#derive(Debug)
pub(all) struct DepthStencilState {
  format : TextureFormat
  depth_write_enabled : Bool
  depth_compare : CompareFunction
  stencil : StencilState
  bias : DepthBiasState
}

///|
pub fn DepthStencilState::new(
  format~ : TextureFormat,
  depth_write_enabled~ : Bool = false,
  depth_compare~ : CompareFunction = CompareFunction::Always,
  stencil~ : StencilState = StencilState::new(),
  bias~ : DepthBiasState = DepthBiasState::new(),
) -> DepthStencilState {
  { format, depth_write_enabled, depth_compare, stencil, bias, }
}

///|
/// A `GPUMultisampleState`.
#derive(Debug)
pub(all) struct MultisampleState {
  count : Int32
  mask : UInt32
  alpha_to_coverage_enabled : Bool
}

///|
pub fn MultisampleState::new(
  count~ : Int32 = 1,
  mask~ : UInt32 = 0xFFFF_FFFFU,
  alpha_to_coverage_enabled~ : Bool = false,
) -> MultisampleState {
  { count, mask, alpha_to_coverage_enabled, }
}

///|
/// A `GPURenderPipelineDescriptor`.
#derive(Debug)
pub(all) struct RenderPipelineDescriptor {
  label : String
  layout : PipelineLayoutId?
  vertex : VertexState
  primitive : PrimitiveState
  depth_stencil : DepthStencilState?
  multisample : MultisampleState
  fragment : FragmentState?
}

///|
pub fn RenderPipelineDescriptor::new(
  vertex~ : VertexState,
  layout? : PipelineLayoutId,
  primitive~ : PrimitiveState = PrimitiveState::new(),
  depth_stencil? : DepthStencilState,
  multisample~ : MultisampleState = MultisampleState::new(),
  fragment? : FragmentState,
  label~ : String = "",
) -> RenderPipelineDescriptor {
  { label, layout, vertex, primitive, depth_stencil, multisample, fragment, }
}

///|
/// A `GPUComputePipelineDescriptor`.
#derive(Debug)
pub(all) struct ComputePipelineDescriptor {
  label : String
  layout : PipelineLayoutId?
  shader : ShaderModuleId
  entry_point : String
  constants : Array[(String, Double)]
}

///|
pub fn ComputePipelineDescriptor::new(
  shader~ : ShaderModuleId,
  entry_point~ : String,
  layout? : PipelineLayoutId,
  constants~ : Array[(String, Double)] = [],
  label~ : String = "",
) -> ComputePipelineDescriptor {
  { label, layout, shader, entry_point, constants, }
}
