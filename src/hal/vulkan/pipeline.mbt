// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The description of a graphics pipeline as the seam reads it.
///
/// One stream of integers instead of twenty arguments: the seam walks it in
/// the order written here, and `render_pipeline_stream` is the only place that
/// writes it. Keeping the two sides in one shape is what makes a mistyped
/// field a test failure rather than a pipeline that draws nothing.
///
/// ```
/// topology, front face, cull, strip index format, unclipped
/// vertex buffer count
///   per buffer: stride, step mode, attribute count
///     per attribute: location, format, offset
/// colour target count
///   per target: format, blend enabled, source colour, destination colour,
///               colour operation, source alpha, destination alpha,
///               alpha operation, write mask
/// has depth, depth format, depth write, depth compare
/// front: compare, fail, depth fail, pass
/// back: compare, fail, depth fail, pass
/// stencil read mask, stencil write mask
/// samples, sample mask, alpha to coverage
/// ```
fn render_pipeline_stream(
  descriptor : @types.RenderPipelineDescriptor,
) -> Array[Int32] raise @hal.HalError {
  let stream : Array[Int32] = []
  stream.push(topology_code(descriptor.primitive.topology))
  // Vulkan's clip space points down and the specification's points up, so the
  // viewport is flipped; that reverses the winding of every triangle, and the
  // front face is flipped with it.
  stream.push(
    match descriptor.primitive.front_face {
      @types.FrontFace::Ccw => 1
      @types.FrontFace::Cw => 0
    },
  )
  stream.push(
    match descriptor.primitive.cull_mode {
      @types.CullMode::None => 0
      @types.CullMode::Front => 1
      @types.CullMode::Back => 2
    },
  )
  stream.push(
    match descriptor.primitive.strip_index_format {
      Some(@types.IndexFormat::Uint16) => 1
      Some(@types.IndexFormat::Uint32) => 2
      None => 0
    },
  )
  stream.push(if descriptor.primitive.unclipped_depth { 1 } else { 0 })
  stream.push(descriptor.vertex.buffers.length())
  for buffer in descriptor.vertex.buffers {
    stream.push(buffer.array_stride)
    stream.push(step_mode_code(buffer.step_mode))
    stream.push(buffer.attributes.length())
    for attribute in buffer.attributes {
      stream.push(attribute.shader_location)
      stream.push(vertex_code(attribute.format).to_int())
      stream.push(attribute.offset)
    }
  }
  let targets = match descriptor.fragment {
    Some(fragment) => fragment.targets
    None => []
  }
  stream.push(targets.length())
  for target in targets {
    stream.push(format_code(target.format).to_int())
    match target.blend {
      Some(blend) => {
        stream.push(1)
        stream.push(blend_factor_code(blend.color.src_factor))
        stream.push(blend_factor_code(blend.color.dst_factor))
        stream.push(blend_op_code(blend.color.operation))
        stream.push(blend_factor_code(blend.alpha.src_factor))
        stream.push(blend_factor_code(blend.alpha.dst_factor))
        stream.push(blend_op_code(blend.alpha.operation))
      }
      None => {
        stream.push(0)
        stream.push(1)
        stream.push(0)
        stream.push(0)
        stream.push(1)
        stream.push(0)
        stream.push(0)
      }
    }
    stream.push(target.write_mask.bits().reinterpret_as_int())
  }
  match descriptor.depth_stencil {
    Some(state) => {
      stream.push(1)
      stream.push(format_code(state.format).to_int())
      stream.push(if state.depth_write_enabled { 1 } else { 0 })
      stream.push(compare_code(state.depth_compare))
      stream.push(compare_code(state.stencil.front.compare))
      stream.push(stencil_op_code(state.stencil.front.fail_op))
      stream.push(stencil_op_code(state.stencil.front.depth_fail_op))
      stream.push(stencil_op_code(state.stencil.front.pass_op))
      stream.push(compare_code(state.stencil.back.compare))
      stream.push(stencil_op_code(state.stencil.back.fail_op))
      stream.push(stencil_op_code(state.stencil.back.depth_fail_op))
      stream.push(stencil_op_code(state.stencil.back.pass_op))
      stream.push(state.stencil.read_mask)
      stream.push(state.stencil.write_mask)
    }
    None => {
      stream.push(0)
      stream.push(0)
      stream.push(0)
      stream.push(7)
      stream.push(7)
      stream.push(0)
      stream.push(0)
      stream.push(0)
      stream.push(7)
      stream.push(0)
      stream.push(0)
      stream.push(0)
      stream.push(0xff)
      stream.push(0xff)
    }
  }
  stream.push(descriptor.multisample.count)
  stream.push(descriptor.multisample.mask.reinterpret_as_int())
  stream.push(
    if descriptor.multisample.alpha_to_coverage_enabled {
      1
    } else {
      0
    },
  )
  stream
}
