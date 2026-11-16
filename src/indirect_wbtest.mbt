// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The commands that read their arguments from a buffer, the bundles that replay
// a recorded run, query resolution, and the corners of the device that are not
// about resources.

///|
fn triangle_pipeline(
  device : Device,
) -> (RenderPipeline, TextureView) raise @core.Refused {
  let shader = device.create_shader_module(
    descriptor=@types.ShaderModuleDescriptor::wgsl(source="// vertex stage\n"),
  )
  let group_layout = device.create_bind_group_layout(
    descriptor=@types.BindGroupLayoutDescriptor::new(entries=[]),
  )
  let layout = device.create_pipeline_layout(
    descriptor=@types.PipelineLayoutDescriptor::new(bind_group_layouts=[
      group_layout.id(),
    ]),
  )
  let pipeline = device.create_render_pipeline(
    descriptor=@types.RenderPipelineDescriptor::new(
      layout=layout.id(),
      vertex=@types.VertexState::new(
        shader=shader.id(),
        entry_point="vs_main",
        buffers=[
          @types.VertexBufferLayout::new(
            array_stride=12,
            step_mode=@types.VertexStepMode::Vertex,
            attributes=[
              @types.VertexAttribute::new(
                format=@types.VertexFormat::Float32x3,
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
    ),
  )
  let target = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=8, height=8),
      format=@types.TextureFormat::Bgra8unorm,
      usage=@types.TextureUsages::render_attachment(),
    ),
  )
  (pipeline, target.create_view())
}

///|
test "a draw from an indirect buffer is accepted when the buffer allows it" {
  let device = device()
  let (pipeline, view) = triangle_pipeline(device)
  let arguments = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::indirect() | @types.BufferUsages::copy_dst(),
    ),
  )
  device
  .queue()
  .write_buffer(
    buffer=arguments,
    offset=0,
    data=b"\x03\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  )
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(color_attachments=[
      @types.ColorAttachment::new(view=view.id()),
    ]),
  )
  pass.set_pipeline(pipeline~)
  pass.draw_indirect(buffer=arguments)
  pass.end()
  device.queue().submit(command_buffers=[encoder.finish()])
  assert_eq(device.queue().label(), "")
}

///|
test "an indirect buffer without INDIRECT is refused" {
  let device = device()
  let (pipeline, view) = triangle_pipeline(device)
  let arguments = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::copy_dst(),
    ),
  )
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(color_attachments=[
      @types.ColorAttachment::new(view=view.id()),
    ]),
  )
  pass.set_pipeline(pipeline~)
  pass.draw_indirect(buffer=arguments)
  pass.end()
  try {
    device.queue().submit(command_buffers=[encoder.finish()])
    fail("the buffer is not an indirect buffer")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidBufferUsage)
    _ => fail("wrong refusal")
  }
}

///|
test "a bundle replays the draw it recorded" {
  let device = device()
  let (pipeline, view) = triangle_pipeline(device)
  let vertices = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=36,
      usage=@types.BufferUsages::vertex() | @types.BufferUsages::copy_dst(),
    ),
  )
  let bundle_encoder = device.create_render_bundle_encoder(
    descriptor=RenderBundleEncoderDescriptor::new(
      color_formats=[@types.TextureFormat::Bgra8unorm],
      label="one triangle",
    ),
  )
  bundle_encoder.set_pipeline(pipeline~)
  bundle_encoder.set_vertex_buffer(slot=0, buffer=vertices)
  bundle_encoder.draw(arguments=@types.DrawArguments::new(vertex_count=3))
  let bundle = bundle_encoder.finish()
  assert_eq(bundle.commands.length(), 3)
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(color_attachments=[
      @types.ColorAttachment::new(view=view.id()),
    ]),
  )
  pass.execute_bundles(bundles=[bundle])
  pass.end()
  let commands = encoder.finish().commands
  assert_eq(commands.length(), 1)
}

///|
test "a bundle encoder refuses to record after finishing" {
  let device = device()
  let (pipeline, _) = triangle_pipeline(device)
  let bundle_encoder = device.create_render_bundle_encoder(
    descriptor=RenderBundleEncoderDescriptor::new(color_formats=[
      @types.TextureFormat::Bgra8unorm,
    ]),
  )
  bundle_encoder.finish() |> ignore
  try {
    bundle_encoder.set_pipeline(pipeline~)
    fail("the bundle has finished")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidPassState)
    _ => fail("wrong refusal")
  }
}

///|
test "an occlusion query set resolves into a query resolve buffer" {
  let device = device()
  let query_set = device.create_query_set(
    descriptor=@types.QuerySetDescriptor::new(
      kind=@types.QueryType::Occlusion,
      count=2,
    ),
  )
  let destination = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::query_resolve(),
    ),
  )
  let encoder = device.create_command_encoder()
  encoder.resolve_query_set(
    query_set~,
    first_query=0,
    query_count=2,
    destination~,
  )
  device.queue().submit(command_buffers=[encoder.finish()])
  assert_eq(query_set.count(), 2)
}

///|
test "resolving past the last query is refused" {
  let device = device()
  let query_set = device.create_query_set(
    descriptor=@types.QuerySetDescriptor::new(
      kind=@types.QueryType::Occlusion,
      count=2,
    ),
  )
  let destination = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=64,
      usage=@types.BufferUsages::query_resolve(),
    ),
  )
  let encoder = device.create_command_encoder()
  encoder.resolve_query_set(
    query_set~,
    first_query=0,
    query_count=3,
    destination~,
  )
  try {
    device.queue().submit(command_buffers=[encoder.finish()])
    fail("there are only two queries")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidCopyRange)
    _ => fail("wrong refusal")
  }
}

///|
test "a timestamp query set needs its feature" {
  let device = device()
  try {
    device.create_query_set(
      descriptor=@types.QuerySetDescriptor::new(
        kind=@types.QueryType::Timestamp,
        count=1,
      ),
    )
    |> ignore
    fail("timestamp-query is off")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.MissingFeature)
    _ => fail("wrong refusal")
  }
}

///|
test "an error scope collects nothing when nothing went wrong" {
  let device = device()
  assert_eq(device.lost(), false)
  device.push_error_scope(filter=@types.ErrorFilter::Validation)
  let errors = device.pop_error_scope()
  assert_eq(errors.length(), 0)
}

///|
test "popping an error scope that was never pushed is refused" {
  let device = device()
  try {
    device.pop_error_scope() |> ignore
    fail("the stack is empty")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidPassState)
    _ => fail("wrong refusal")
  }
}

///|
test "a pipeline built with an explicit layout hands it back" {
  let device = device()
  let (pipeline, _) = triangle_pipeline(device)
  let layout = pipeline.get_bind_group_layout(index=0)
  assert_eq(layout.descriptor().entries.length(), 0)
}

///|
test "a pipeline asks for a layout index it has no entry for" {
  let device = device()
  let (pipeline, _) = triangle_pipeline(device)
  try {
    pipeline.get_bind_group_layout(index=3) |> ignore
    fail("the pipeline has one layout")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidPipelineLayout)
    _ => fail("wrong refusal")
  }
}

///|
test "a buffer reports whether it is mapped" {
  let device = device()
  let buffer = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=8,
      usage=@types.BufferUsages::map_read() | @types.BufferUsages::copy_dst(),
    ),
  )
  assert_eq(buffer.map_state(), @types.MapState::Unmapped)
  buffer.map_read()
  assert_eq(buffer.map_state(), @types.MapState::Mapped)
  buffer.unmap()
  assert_eq(buffer.map_state(), @types.MapState::Unmapped)
}

///|
test "the memory backend says it is a fallback adapter" {
  let backend = @memory.Backend::new()
  let adapter = Instance::new(backend~).request_adapter()
  assert_eq(adapter.is_fallback_adapter(), true)
}

///|
test "waiting on submitted work returns at once" {
  let device = device()
  device.queue().on_submitted_work_done()
  assert_eq(device.queue().label(), "")
}
