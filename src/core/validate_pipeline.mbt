// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// One vertex buffer layout against the rules of `validating GPUVertexBufferLayout`.
fn validate_vertex_buffer_layout(
  layout : @types.VertexBufferLayout,
  limits : @types.Limits,
) -> Unit raise Refused {
  require_int(
    layout.array_stride <= limits.max_vertex_buffer_array_stride,
    @types.LimitExceeded,
    "descriptor.vertex.buffers.arrayStride",
    limits.max_vertex_buffer_array_stride,
    layout.array_stride,
  )
  require_same(
    0,
    layout.array_stride % 4,
    @types.InvalidVertexState,
    "descriptor.vertex.buffers.arrayStride",
  )
  for attribute in layout.attributes {
    let end = attribute.offset + attribute.format.size()
    let limit = if layout.array_stride == 0 {
      limits.max_vertex_buffer_array_stride
    } else {
      layout.array_stride
    }
    require_int(
      end <= limit,
      @types.InvalidVertexState,
      "descriptor.vertex.buffers.attributes.offset",
      limit,
      end,
    )
    require_same(
      0,
      attribute.offset % attribute.format.alignment(),
      @types.InvalidAlignment,
      "descriptor.vertex.buffers.attributes.offset",
    )
    require_int(
      attribute.shader_location < limits.max_vertex_attributes,
      @types.LimitExceeded,
      "descriptor.vertex.buffers.attributes.shaderLocation",
      limits.max_vertex_attributes - 1,
      attribute.shader_location,
    )
  }
}

///|
/// The rules a `GPURenderPipelineDescriptor` must satisfy.
///
/// A pipeline whose shaders were compiled would also be checked against what
/// the entry points declare. That needs a WGSL front end; this layer checks
/// everything the descriptor itself decides, which is where most of the
/// specification's rules live.
/// https://www.w3.org/TR/webgpu/#dom-gpudevice-createrenderpipeline
pub fn validate_render_pipeline_descriptor(
  descriptor : @types.RenderPipelineDescriptor,
  limits : @types.Limits,
) -> Unit raise Refused {
  let vertex = descriptor.vertex
  require(
    !vertex.entry_point.is_empty(),
    @types.InvalidShaderModule,
    "descriptor.vertex.entryPoint",
    "an entry point name",
    "an empty string",
  )
  require_int(
    vertex.buffers.length() <= limits.max_vertex_buffers,
    @types.LimitExceeded,
    "descriptor.vertex.buffers",
    limits.max_vertex_buffers,
    vertex.buffers.length(),
  )
  let locations = Map([])
  let mut attributes = 0
  for layout in vertex.buffers {
    validate_vertex_buffer_layout(layout, limits)
    for attribute in layout.attributes {
      attributes = attributes + 1
      require(
        locations.get(attribute.shader_location) is None,
        @types.InvalidVertexState,
        "descriptor.vertex.buffers.attributes.shaderLocation",
        "a location used once",
        attribute.shader_location.to_string(),
      )
      locations[attribute.shader_location] = true
    }
  }
  require_int(
    attributes <= limits.max_vertex_attributes,
    @types.LimitExceeded,
    "descriptor.vertex.buffers.attributes",
    limits.max_vertex_attributes,
    attributes,
  )
  // A strip topology consumes the index format and the others must not carry
  // one.
  let strip = descriptor.primitive.topology ==
    @types.PrimitiveTopology::LineStrip ||
    descriptor.primitive.topology == @types.PrimitiveTopology::TriangleStrip
  match (strip, descriptor.primitive.strip_index_format) {
    (true, None) =>
      raise invalid(
        @types.InvalidPrimitiveState,
        "descriptor.primitive.stripIndexFormat",
        "an index format for a strip topology",
        "none",
      )
    (false, Some(_)) =>
      raise invalid(
        @types.InvalidPrimitiveState,
        "descriptor.primitive.stripIndexFormat",
        "none for a list topology",
        "an index format",
      )
    _ => ()
  }
  let sample_count = descriptor.multisample.count
  require(
    sample_count == 1 || sample_count == 4,
    @types.InvalidMultisampleState,
    "descriptor.multisample.count",
    "1 or 4",
    sample_count.to_string(),
  )
  let has_depth = descriptor.depth_stencil is Some(_)
  let has_colour = match descriptor.fragment {
    Some(fragment) => fragment.targets.length() > 0
    None => false
  }
  require(
    has_depth || has_colour,
    @types.InvalidRenderPipeline,
    "descriptor",
    "a fragment stage or a depth-stencil attachment",
    "neither",
  )
  match descriptor.depth_stencil {
    Some(depth) => {
      let info = depth.format.info()
      let has_depth_aspect = info.aspect == @types.FormatAspect::DepthOnly ||
        info.aspect == @types.FormatAspect::DepthStencil
      require(
        has_depth_aspect,
        @types.InvalidDepthStencilState,
        "descriptor.depthStencil.format",
        "a format with a depth aspect",
        depth.format.name(),
      )
      if depth.depth_write_enabled {
        require(
          has_depth_aspect,
          @types.InvalidDepthStencilState,
          "descriptor.depthStencil.depthWriteEnabled",
          "a format with a depth aspect",
          depth.format.name(),
        )
      }
      if sample_count > 1 {
        require(
          info.multisample,
          @types.InvalidMultisampleState,
          "descriptor.depthStencil.format",
          "a format that supports multisampling",
          depth.format.name(),
        )
      }
    }
    None => ()
  }
  match descriptor.fragment {
    Some(fragment) => {
      require(
        !fragment.entry_point.is_empty(),
        @types.InvalidShaderModule,
        "descriptor.fragment.entryPoint",
        "an entry point name",
        "an empty string",
      )
      require_int(
        fragment.targets.length() <= limits.max_color_attachments,
        @types.LimitExceeded,
        "descriptor.fragment.targets",
        limits.max_color_attachments,
        fragment.targets.length(),
      )
      let mut bytes_per_sample = 0
      for target in fragment.targets {
        let info = target.format.info()
        require(
          info.render_attachment,
          @types.InvalidFragmentState,
          "descriptor.fragment.targets.format",
          "a renderable format",
          target.format.name(),
        )
        if sample_count > 1 {
          require(
            info.multisample,
            @types.InvalidMultisampleState,
            "descriptor.fragment.targets.format",
            "a format that supports multisampling",
            target.format.name(),
          )
        }
        if target.blend is Some(_) {
          require(
            info.blendable,
            @types.InvalidFragmentState,
            "descriptor.fragment.targets.blend",
            "a blendable format",
            target.format.name(),
          )
        }
        bytes_per_sample = bytes_per_sample + info.bytes_per_sample
      }
      require_int(
        bytes_per_sample <= limits.max_color_attachment_bytes_per_sample,
        @types.LimitExceeded,
        "descriptor.fragment.targets",
        limits.max_color_attachment_bytes_per_sample,
        bytes_per_sample,
      )
    }
    None => ()
  }
}

///|
/// The rules a `GPUComputePipelineDescriptor` must satisfy.
pub fn validate_compute_pipeline_descriptor(
  descriptor : @types.ComputePipelineDescriptor,
  limits : @types.Limits,
) -> Unit raise Refused {
  require(
    !descriptor.entry_point.is_empty(),
    @types.InvalidShaderModule,
    "descriptor.entryPoint",
    "an entry point name",
    "an empty string",
  )
  ignore(limits)
}
