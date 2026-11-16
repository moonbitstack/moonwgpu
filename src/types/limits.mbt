// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The `GPUSupportedLimits` of an adapter, and the set a device is created
/// with.
///
/// The defaults are the "Default" column of the specification's limits table;
/// `compatibility()` is the "Compatibility Mode Default" column, which lowers
/// the limits a compatibility-mode adapter has to reach.
/// https://www.w3.org/TR/webgpu/#limits
///
/// Sizes are `Int`, which is 64 bits on the native targets and 32 bits on the
/// wasm targets. A size above 2 GiB therefore cannot be expressed on wasm; the
/// specification's own default is 256 MiB.
#derive(Eq, Debug)
pub(all) struct Limits {
  max_texture_dimension_1d : Int32
  max_texture_dimension_2d : Int32
  max_texture_dimension_3d : Int32
  max_texture_array_layers : Int32
  max_bind_groups : Int32
  max_bind_groups_plus_vertex_buffers : Int32
  max_immediate_size : Int32
  max_bindings_per_bind_group : Int32
  max_dynamic_uniform_buffers_per_pipeline_layout : Int32
  max_dynamic_storage_buffers_per_pipeline_layout : Int32
  max_sampled_textures_per_shader_stage : Int32
  max_samplers_per_shader_stage : Int32
  max_storage_buffers_per_shader_stage : Int32
  max_storage_buffers_in_vertex_stage : Int32
  max_storage_buffers_in_fragment_stage : Int32
  max_storage_textures_per_shader_stage : Int32
  max_storage_textures_in_vertex_stage : Int32
  max_storage_textures_in_fragment_stage : Int32
  max_uniform_buffers_per_shader_stage : Int32
  max_uniform_buffer_binding_size : Int32
  max_storage_buffer_binding_size : Int32
  min_uniform_buffer_offset_alignment : Int32
  min_storage_buffer_offset_alignment : Int32
  max_vertex_buffers : Int32
  max_buffer_size : Int32
  max_vertex_attributes : Int32
  max_vertex_buffer_array_stride : Int32
  max_inter_stage_shader_variables : Int32
  max_color_attachments : Int32
  max_color_attachment_bytes_per_sample : Int32
  max_compute_workgroup_storage_size : Int32
  max_compute_invocations_per_workgroup : Int32
  max_compute_workgroup_size_x : Int32
  max_compute_workgroup_size_y : Int32
  max_compute_workgroup_size_z : Int32
  max_compute_workgroups_per_dimension : Int32
}

///|
/// The limits every WebGPU implementation must offer.
pub fn Limits::webgpu() -> Limits {
  {
    max_texture_dimension_1d: 8192,
    max_texture_dimension_2d: 8192,
    max_texture_dimension_3d: 2048,
    max_texture_array_layers: 256,
    max_bind_groups: 4,
    max_bind_groups_plus_vertex_buffers: 24,
    max_immediate_size: 64,
    max_bindings_per_bind_group: 1000,
    max_dynamic_uniform_buffers_per_pipeline_layout: 8,
    max_dynamic_storage_buffers_per_pipeline_layout: 4,
    max_sampled_textures_per_shader_stage: 16,
    max_samplers_per_shader_stage: 16,
    max_storage_buffers_per_shader_stage: 8,
    max_storage_buffers_in_vertex_stage: 8,
    max_storage_buffers_in_fragment_stage: 8,
    max_storage_textures_per_shader_stage: 4,
    max_storage_textures_in_vertex_stage: 4,
    max_storage_textures_in_fragment_stage: 4,
    max_uniform_buffers_per_shader_stage: 12,
    max_uniform_buffer_binding_size: 65536,
    max_storage_buffer_binding_size: 134217728,
    min_uniform_buffer_offset_alignment: 256,
    min_storage_buffer_offset_alignment: 256,
    max_vertex_buffers: 8,
    max_buffer_size: 268435456,
    max_vertex_attributes: 16,
    max_vertex_buffer_array_stride: 2048,
    max_inter_stage_shader_variables: 16,
    max_color_attachments: 8,
    max_color_attachment_bytes_per_sample: 32,
    max_compute_workgroup_storage_size: 16384,
    max_compute_invocations_per_workgroup: 256,
    max_compute_workgroup_size_x: 256,
    max_compute_workgroup_size_y: 256,
    max_compute_workgroup_size_z: 64,
    max_compute_workgroups_per_dimension: 65535,
  }
}

///|
/// The limits a compatibility-mode adapter has to reach.
pub fn Limits::compatibility() -> Limits {
  {
    ..Limits::webgpu(),
    max_texture_dimension_1d: 4096,
    max_texture_dimension_2d: 4096,
    max_storage_buffers_in_vertex_stage: 0,
    max_storage_buffers_in_fragment_stage: 4,
    max_storage_textures_in_vertex_stage: 0,
    max_uniform_buffer_binding_size: 16384,
    max_inter_stage_shader_variables: 15,
    max_color_attachments: 4,
    max_compute_invocations_per_workgroup: 128,
    max_compute_workgroup_size_x: 128,
    max_compute_workgroup_size_y: 128,
  }
}

///|
/// The names and values of every limit, in specification order. Used by
/// `check` and by the diagnostics a failed `request_device` prints.
pub fn Limits::entries(self : Limits) -> Array[(String, Int32)] {
  [
    ("maxTextureDimension1D", self.max_texture_dimension_1d),
    ("maxTextureDimension2D", self.max_texture_dimension_2d),
    ("maxTextureDimension3D", self.max_texture_dimension_3d),
    ("maxTextureArrayLayers", self.max_texture_array_layers),
    ("maxBindGroups", self.max_bind_groups),
    ("maxBindGroupsPlusVertexBuffers", self.max_bind_groups_plus_vertex_buffers),
    ("maxImmediateSize", self.max_immediate_size),
    ("maxBindingsPerBindGroup", self.max_bindings_per_bind_group),
    (
      "maxDynamicUniformBuffersPerPipelineLayout",
      self.max_dynamic_uniform_buffers_per_pipeline_layout,
    ),
    (
      "maxDynamicStorageBuffersPerPipelineLayout",
      self.max_dynamic_storage_buffers_per_pipeline_layout,
    ),
    (
      "maxSampledTexturesPerShaderStage",
      self.max_sampled_textures_per_shader_stage,
    ),
    ("maxSamplersPerShaderStage", self.max_samplers_per_shader_stage),
    (
      "maxStorageBuffersPerShaderStage",
      self.max_storage_buffers_per_shader_stage,
    ),
    ("maxStorageBuffersInVertexStage", self.max_storage_buffers_in_vertex_stage),
    (
      "maxStorageBuffersInFragmentStage",
      self.max_storage_buffers_in_fragment_stage,
    ),
    (
      "maxStorageTexturesPerShaderStage",
      self.max_storage_textures_per_shader_stage,
    ),
    (
      "maxStorageTexturesInVertexStage",
      self.max_storage_textures_in_vertex_stage,
    ),
    (
      "maxStorageTexturesInFragmentStage",
      self.max_storage_textures_in_fragment_stage,
    ),
    (
      "maxUniformBuffersPerShaderStage",
      self.max_uniform_buffers_per_shader_stage,
    ),
    ("maxUniformBufferBindingSize", self.max_uniform_buffer_binding_size),
    ("maxStorageBufferBindingSize", self.max_storage_buffer_binding_size),
    (
      "minUniformBufferOffsetAlignment",
      self.min_uniform_buffer_offset_alignment,
    ),
    (
      "minStorageBufferOffsetAlignment",
      self.min_storage_buffer_offset_alignment,
    ),
    ("maxVertexBuffers", self.max_vertex_buffers),
    ("maxBufferSize", self.max_buffer_size),
    ("maxVertexAttributes", self.max_vertex_attributes),
    ("maxVertexBufferArrayStride", self.max_vertex_buffer_array_stride),
    ("maxInterStageShaderVariables", self.max_inter_stage_shader_variables),
    ("maxColorAttachments", self.max_color_attachments),
    (
      "maxColorAttachmentBytesPerSample",
      self.max_color_attachment_bytes_per_sample,
    ),
    ("maxComputeWorkgroupStorageSize", self.max_compute_workgroup_storage_size),
    (
      "maxComputeInvocationsPerWorkgroup",
      self.max_compute_invocations_per_workgroup,
    ),
    ("maxComputeWorkgroupSizeX", self.max_compute_workgroup_size_x),
    ("maxComputeWorkgroupSizeY", self.max_compute_workgroup_size_y),
    ("maxComputeWorkgroupSizeZ", self.max_compute_workgroup_size_z),
    (
      "maxComputeWorkgroupsPerDimension",
      self.max_compute_workgroups_per_dimension,
    ),
  ]
}

///|
/// The first limit of `requested` that is above `supported`, as its name and
/// the two values; `None` when the request fits.
pub fn Limits::exceeds(
  self : Limits,
  requested : Limits,
) -> (String, Int32, Int32)? {
  let supported = self.entries()
  let wanted = requested.entries()
  for i in 0..<supported.length() {
    let (name, have) = supported[i]
    let (_, want) = wanted[i]
    if want > have {
      return Some((name, have, want))
    }
    if want < 0 {
      return Some((name, have, want))
    }
  }
  None
}
