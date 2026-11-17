// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Every error the specification names. The specification raises these on the
/// device timeline and reports them through an error scope; a library that
/// runs the device timeline in the caller's thread raises them instead, and
/// keeps this enumeration so that a caller can branch on the same classes the
/// specification defines.
#derive(Eq, Debug)
pub(all) enum ErrorKind {
  InvalidBufferSize
  InvalidBufferUsage
  InvalidBufferState
  InvalidTextureDescriptor
  InvalidTextureDimension
  InvalidTextureFormat
  InvalidTextureUsage
  InvalidTextureSampleCount
  InvalidTextureViewDescriptor
  InvalidSamplerDescriptor
  InvalidBindGroupLayout
  InvalidBindGroup
  InvalidPipelineLayout
  InvalidShaderModule
  InvalidRenderPipeline
  InvalidComputePipeline
  InvalidVertexState
  InvalidFragmentState
  InvalidPrimitiveState
  InvalidDepthStencilState
  InvalidMultisampleState
  InvalidCopyRange
  InvalidCopySize
  InvalidAlignment
  InvalidBytesPerRow
  InvalidSubresource
  InvalidPassDescriptor
  InvalidPassState
  InvalidDraw
  InvalidDispatch
  PassNotEnded
  EncoderFinished
  InvalidResource
  InvalidCanvasConfiguration
  MissingFeature
  LimitExceeded
  DeviceLost
  OutOfMemory
  Internal
}

///|
pub fn ErrorKind::name(self : ErrorKind) -> String {
  match self {
    InvalidBufferSize => "invalid buffer size"
    InvalidBufferUsage => "invalid buffer usage"
    InvalidBufferState => "invalid buffer state"
    InvalidTextureDescriptor => "invalid texture descriptor"
    InvalidTextureDimension => "invalid texture dimension"
    InvalidTextureFormat => "invalid texture format"
    InvalidTextureUsage => "invalid texture usage"
    InvalidTextureSampleCount => "invalid texture sample count"
    InvalidTextureViewDescriptor => "invalid texture view descriptor"
    InvalidSamplerDescriptor => "invalid sampler descriptor"
    InvalidBindGroupLayout => "invalid bind group layout"
    InvalidBindGroup => "invalid bind group"
    InvalidPipelineLayout => "invalid pipeline layout"
    InvalidShaderModule => "invalid shader module"
    InvalidRenderPipeline => "invalid render pipeline"
    InvalidComputePipeline => "invalid compute pipeline"
    InvalidVertexState => "invalid vertex state"
    InvalidFragmentState => "invalid fragment state"
    InvalidPrimitiveState => "invalid primitive state"
    InvalidDepthStencilState => "invalid depth-stencil state"
    InvalidMultisampleState => "invalid multisample state"
    InvalidCopyRange => "invalid copy range"
    InvalidCopySize => "invalid copy size"
    InvalidAlignment => "invalid alignment"
    InvalidBytesPerRow => "invalid bytes per row"
    InvalidSubresource => "invalid subresource"
    InvalidPassDescriptor => "invalid pass descriptor"
    InvalidPassState => "invalid pass state"
    InvalidDraw => "invalid draw"
    InvalidDispatch => "invalid dispatch"
    PassNotEnded => "pass not ended"
    EncoderFinished => "encoder already finished"
    InvalidResource => "invalid resource"
    InvalidCanvasConfiguration => "invalid canvas configuration"
    MissingFeature => "missing feature"
    LimitExceeded => "limit exceeded"
    DeviceLost => "device lost"
    OutOfMemory => "out of memory"
    Internal => "internal error"
  }
}
