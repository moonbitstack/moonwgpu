///|
#doc(hidden)
pub extend MapState with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend MapState with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ResolveQuerySet with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend DrawIndirect with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend DrawIndexedIndirect with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend DispatchIndirect with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderBundle with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BufferUsages with BitOr::{lor}

///|
#doc(hidden)
pub extend BufferUsages with BitAnd::{land}

///|
#doc(hidden)
pub extend BufferUsages with Sub::{sub}

///|
#doc(hidden)
pub extend TextureUsages with BitOr::{lor}

///|
#doc(hidden)
pub extend TextureUsages with BitAnd::{land}

///|
#doc(hidden)
pub extend TextureUsages with Sub::{sub}

///|
#doc(hidden)
pub extend ShaderStages with BitOr::{lor}

///|
#doc(hidden)
pub extend ShaderStages with BitAnd::{land}

///|
#doc(hidden)
pub extend ColorWrites with BitOr::{lor}

///|
#doc(hidden)
pub extend ColorWrites with BitAnd::{land}

///|
#doc(hidden)
pub extend MapMode with BitOr::{lor}

///|
#doc(hidden)
pub extend MapMode with BitAnd::{land}

///|
#doc(hidden)
pub extend Features with BitOr::{lor}

///|
#doc(hidden)
pub extend Features with BitAnd::{land}

///|
#doc(hidden)
pub extend Extent3d with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend Extent3d with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend Origin3d with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend Origin3d with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend Color with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend Color with @debug.Debug::{to_repr}

// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// A derived implementation of `Eq`, `Debug` or `Show` is also reachable as a
// method of the type, which the toolchain reports as a deprecated form of
// promotion unless it is declared here. The declarations stay out of the API
// reference: `==`, `Debug` and interpolation are the ways in.

///|
#doc(hidden)
pub extend BufferUsages with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend TextureUsages with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend ShaderStages with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend ColorWrites with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend MapMode with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend TextureFormat with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend SampleType with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend StorageAccess with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend FormatAspect with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend FeatureName with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend Features with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend Limits with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend VertexFormat with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend VertexDataType with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend VertexFormatInfo with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend TextureDimension with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend TextureViewDimension with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend TextureAspect with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend PrimitiveTopology with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend FrontFace with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend CullMode with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend IndexFormat with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend CompareFunction with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend StencilOperation with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend BlendFactor with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend BlendOperation with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend AddressMode with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend FilterMode with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend SamplerBindingType with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend BufferBindingType with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend StorageTextureAccess with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend StoreOp with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend LoadOp with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend QueryType with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend CompilationMessageType with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend DeviceLostReason with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend ErrorFilter with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend PowerPreference with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend BackendKind with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend PipelineErrorReason with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend ShaderSourceKind with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend VertexStepMode with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend DrawArguments with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend DrawIndexedArguments with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend DispatchArguments with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend ErrorKind with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend BufferId with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend TextureId with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend TextureViewId with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend SamplerId with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend ShaderModuleId with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend BindGroupLayoutId with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend BindGroupId with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend PipelineLayoutId with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend RenderPipelineId with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend ComputePipelineId with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend QuerySetId with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend BufferUsages with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TextureUsages with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ShaderStages with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ColorWrites with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend MapMode with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TextureFormat with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SampleType with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend StorageAccess with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend FormatAspect with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend FeatureName with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend Features with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend Limits with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend VertexFormat with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend VertexDataType with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend VertexFormatInfo with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TextureDimension with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TextureViewDimension with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TextureAspect with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend PrimitiveTopology with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend FrontFace with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CullMode with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend IndexFormat with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CompareFunction with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend StencilOperation with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BlendFactor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BlendOperation with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend AddressMode with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend FilterMode with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SamplerBindingType with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BufferBindingType with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend StorageTextureAccess with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend StoreOp with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend LoadOp with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend QueryType with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CompilationMessageType with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend DeviceLostReason with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ErrorFilter with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend PowerPreference with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BackendKind with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend PipelineErrorReason with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ShaderSourceKind with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend VertexStepMode with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend DrawArguments with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend DrawIndexedArguments with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend DispatchArguments with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ErrorKind with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BufferId with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TextureId with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TextureViewId with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SamplerId with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ShaderModuleId with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BindGroupLayoutId with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BindGroupId with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend PipelineLayoutId with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineId with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ComputePipelineId with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend QuerySetId with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend FormatInfo with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BufferDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TextureDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TextureViewDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SamplerDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ShaderModuleDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend QuerySetDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BufferBindingLayout with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SamplerBindingLayout with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TextureBindingLayout with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend StorageTextureBindingLayout with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BindingLayout with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BindGroupLayoutEntry with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BindGroupLayoutDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend PipelineLayoutDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BufferBinding with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BindingResource with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BindGroupEntry with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BindGroupDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend VertexAttribute with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend VertexBufferLayout with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend VertexState with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BlendComponent with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend BlendState with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ColorTargetState with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend FragmentState with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend PrimitiveState with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend DepthBiasState with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend StencilFaceState with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend StencilState with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend DepthStencilState with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend MultisampleState with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPipelineDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ComputePipelineDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TexelCopyBufferLayout with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TexelCopyBufferInfo with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TexelCopyTextureInfo with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ColorAttachment with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend DepthStencilAttachment with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend PassTimestampWrites with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPassDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ComputePassDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CopyBufferToBuffer with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CopyBufferToTexture with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CopyTextureToBuffer with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CopyTextureToTexture with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ClearBuffer with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ClearTexture with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend Command with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderPassCommand with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderCommand with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SetBindGroup with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SetVertexBuffer with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SetIndexBuffer with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SetViewport with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SetScissorRect with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend WriteTimestamp with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ComputePassCommand with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ComputeCommand with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CommandBuffer with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend TextureFormat with Show::{to_string, output}

///|
#doc(hidden)
pub extend VertexFormat with Show::{to_string, output}

///|
#doc(hidden)
pub extend PredefinedColorSpace with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend PredefinedColorSpace with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ExternalTextureId with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend ExternalTextureId with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CompilationMessage with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend CompilationMessage with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CompilationInfo with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ExternalImage with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ExternalTextureDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SetImmediates with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CopyExternalImageSourceInfo with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CopyExternalImageDestInfo with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ShaderSource with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CanvasAlphaMode with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend CanvasAlphaMode with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend ToneMappingMode with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend ToneMappingMode with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CanvasToneMapping with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend CanvasToneMapping with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceConfiguration with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceCapabilities with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceFrame with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend DeviceLostInfo with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend DeviceLostInfo with @debug.Debug::{to_repr}
