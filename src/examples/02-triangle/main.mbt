// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A triangle: vertex buffers, a pipeline and a draw, recorded exactly as the
/// specification describes.
///
/// The memory backend records the pass and does not shade it, so what this
/// example shows is the whole API path - shader module, bind group layout,
/// pipeline layout, render pipeline, vertex data, draw - and the command
/// stream it produces.
///
///     moon run src/examples/02-triangle
#coverage.skip
fn main raise {
  let backend = @memory.Backend::new()
  let device = @moonwgpu.Instance::new(backend~)
    .request_adapter()
    .request_device()
  // Three vertices, two floats each: a triangle in clip space.
  let positions : Array[Byte] = [
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x80', b'\x3f', // ( 0.0,  0.0)
     b'\x00', b'\x00', b'\x80', b'\x3f', b'\x00', b'\x00', b'\x00', b'\x00', // ( 1.0,  0.0)
     b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x80', b'\x3f', // ( 0.0,  1.0)
  ]
  let vertices = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=positions.length(),
      usage=@types.BufferUsages::vertex() | @types.BufferUsages::copy_dst(),
      label="triangle vertices",
    ),
  )
  device
  .queue()
  .write_buffer(buffer=vertices, offset=0, data=Bytes::from_array(positions))
  let shader = device.create_shader_module(
    descriptor=@types.ShaderModuleDescriptor::wgsl(
      label="triangle",
      source="// a vertex stage returning the position it was given\n",
    ),
  )
  let layout = device.create_pipeline_layout(
    descriptor=@types.PipelineLayoutDescriptor::new(bind_group_layouts=[]),
  )
  let pipeline = device.create_render_pipeline(
    descriptor=@types.RenderPipelineDescriptor::new(
      layout=layout.id(),
      vertex=@types.VertexState::new(
        shader=shader.id(),
        entry_point="vs_main",
        buffers=[
          @types.VertexBufferLayout::new(
            array_stride=8,
            step_mode=@types.VertexStepMode::Vertex,
            attributes=[
              @types.VertexAttribute::new(
                format=@types.VertexFormat::Float32x2,
                offset=0,
                shader_location=0,
              ),
            ],
          ),
        ],
      ),
      fragment=@types.FragmentState::new(
        shader=shader.id(),
        entry_point="fs_main",
        targets=[
          @types.ColorTargetState::new(format=@types.TextureFormat::Bgra8unorm),
        ],
      ),
      label="triangle pipeline",
    ),
  )
  let target = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=256, height=256),
      format=@types.TextureFormat::Bgra8unorm,
      usage=@types.TextureUsages::render_attachment(),
    ),
  )
  let view = target.create_view()
  let encoder = device.create_command_encoder(label="triangle")
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(
      color_attachments=[
        @types.ColorAttachment::new(
          view=view.id(),
          load_op=@types.LoadOp::Clear,
          clear_value=@types.Color::new(r=0.05, g=0.05, b=0.08, a=1.0),
        ),
      ],
      label="triangle pass",
    ),
  )
  pass.set_pipeline(pipeline~)
  pass.set_vertex_buffer(slot=0, buffer=vertices)
  pass.draw(
    arguments=@types.DrawArguments::new(
      vertex_count=3,
      instance_count=1,
      first_vertex=0,
      first_instance=0,
    ),
  )
  pass.end()
  let command_buffer = encoder.finish()
  device.queue().submit(command_buffers=[command_buffer])
  println("pipeline:       \{pipeline.label()}")
  println("vertices:       \{vertices.size()} bytes")
  println("commands:       \{command_buffer.commands.length()}")
  println("submissions:    \{backend.submitted().length()}")
}
