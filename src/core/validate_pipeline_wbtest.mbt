// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The pipeline rules that the descriptor alone decides: vertex layout
// arithmetic, strip topologies, colour target formats, and the byte cost of a
// sample across all targets.

///|
fn shader_id() -> @types.ShaderModuleId {
  @types.ShaderModuleId::from_raw(1UL)
}

///|
fn pipeline(
  buffers : Array[@types.VertexBufferLayout],
) -> @types.RenderPipelineDescriptor {
  @types.RenderPipelineDescriptor::new(
    vertex=@types.VertexState::new(
      shader=shader_id(),
      entry_point="vs_main",
      buffers~,
    ),
    fragment=@types.FragmentState::new(
      shader=shader_id(),
      entry_point="fs_main",
      targets=[
        @types.ColorTargetState::new(format=@types.TextureFormat::Rgba8unorm),
      ],
    ),
  )
}

///|
fn vertex_layout(stride : Int32, offset : Int32) -> @types.VertexBufferLayout {
  @types.VertexBufferLayout::new(
    array_stride=stride,
    step_mode=@types.VertexStepMode::Vertex,
    attributes=[
      @types.VertexAttribute::new(
        format=@types.VertexFormat::Float32x3,
        offset~,
        shader_location=0,
      ),
    ],
  )
}

///|
test "a well formed vertex layout is accepted" {
  assert_true(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(
        pipeline([vertex_layout(12, 0)]),
        webgpu_limits,
      )
    })
    is None,
  )
}

///|
test "an array stride has to be a multiple of four" {
  assert_eq(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(
        pipeline([vertex_layout(10, 0)]),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidVertexState),
  )
}

///|
test "an attribute has to fit inside the stride" {
  assert_eq(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(
        pipeline([vertex_layout(12, 4)]),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidVertexState),
  )
}

///|
test "an attribute offset aligns to its own size, up to four" {
  // Float32x3 is twelve bytes, so four byte alignment applies: offset 2 is out.
  assert_eq(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(
        pipeline([vertex_layout(16, 2)]),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidAlignment),
  )
  assert_true(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(
        pipeline([vertex_layout(16, 4)]),
        webgpu_limits,
      )
    })
    is None,
  )
}

///|
test "two attributes cannot claim the same shader location" {
  let layout = @types.VertexBufferLayout::new(
    array_stride=24,
    step_mode=@types.VertexStepMode::Vertex,
    attributes=[
      @types.VertexAttribute::new(
        format=@types.VertexFormat::Float32x3,
        offset=0,
        shader_location=0,
      ),
      @types.VertexAttribute::new(
        format=@types.VertexFormat::Float32x3,
        offset=12,
        shader_location=0,
      ),
    ],
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(pipeline([layout]), webgpu_limits)
    }),
    Some(@types.InvalidVertexState),
  )
}

///|
test "more vertex buffers than the limit is refused" {
  let layouts = []
  for _ in 0..<9 {
    layouts.push(vertex_layout(12, 0))
  }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(pipeline(layouts), webgpu_limits)
    }),
    Some(@types.LimitExceeded),
  )
}

///|
test "a strip topology needs a strip index format and a list must not have one" {
  let strip = {
    ..pipeline([vertex_layout(12, 0)]),
    primitive: @types.PrimitiveState::new(
      topology=@types.PrimitiveTopology::TriangleStrip,
    ),
  }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(strip, webgpu_limits)
    }),
    Some(@types.InvalidPrimitiveState),
  )
  let indexed = {
    ..strip,
    primitive: @types.PrimitiveState::new(
      topology=@types.PrimitiveTopology::TriangleStrip,
      strip_index_format=@types.IndexFormat::Uint16,
    ),
  }
  assert_true(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(indexed, webgpu_limits)
    })
    is None,
  )
  let list_with_format = {
    ..pipeline([vertex_layout(12, 0)]),
    primitive: @types.PrimitiveState::new(
      strip_index_format=@types.IndexFormat::Uint16,
    ),
  }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(list_with_format, webgpu_limits)
    }),
    Some(@types.InvalidPrimitiveState),
  )
}

///|
test "a pipeline without a fragment stage or depth attachment writes nothing" {
  let descriptor = { ..pipeline([]), fragment: None, }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(descriptor, webgpu_limits)
    }),
    Some(@types.InvalidRenderPipeline),
  )
}

///|
test "a colour target has to be a renderable format" {
  let fragment = @types.FragmentState::new(
    shader=shader_id(),
    entry_point="fs_main",
    targets=[
      @types.ColorTargetState::new(format=@types.TextureFormat::Rgba8snorm),
    ],
  )
  let descriptor = {
    ..pipeline([vertex_layout(12, 0)]),
    fragment: Some(fragment),
  }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(descriptor, webgpu_limits)
    }),
    Some(@types.InvalidFragmentState),
  )
}

///|
test "blending needs a blendable format" {
  let fragment = @types.FragmentState::new(
    shader=shader_id(),
    entry_point="fs_main",
    targets=[
      @types.ColorTargetState::new(
        format=@types.TextureFormat::Rgba32uint,
        blend=@types.BlendState::new(
          color=@types.BlendComponent::new(),
          alpha=@types.BlendComponent::new(),
        ),
      ),
    ],
  )
  let descriptor = {
    ..pipeline([vertex_layout(12, 0)]),
    fragment: Some(fragment),
  }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(descriptor, webgpu_limits)
    }),
    Some(@types.InvalidFragmentState),
  )
}

///|
test "the colour attachments of one sample stay within their byte budget" {
  // Eight rgba32float targets are 128 bytes per sample, four times the default
  // budget of 32.
  let targets = []
  for _ in 0..<8 {
    targets.push(
      @types.ColorTargetState::new(format=@types.TextureFormat::Rgba32float),
    )
  }
  let fragment = @types.FragmentState::new(
    shader=shader_id(),
    entry_point="fs_main",
    targets~,
  )
  let descriptor = {
    ..pipeline([vertex_layout(12, 0)]),
    fragment: Some(fragment),
  }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(descriptor, webgpu_limits)
    }),
    Some(@types.LimitExceeded),
  )
}

///|
test "an empty entry point is refused" {
  let descriptor = {
    ..pipeline([vertex_layout(12, 0)]),
    vertex: @types.VertexState::new(shader=shader_id(), entry_point=""),
  }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_render_pipeline_descriptor(descriptor, webgpu_limits)
    }),
    Some(@types.InvalidShaderModule),
  )
}
