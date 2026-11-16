// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Pass recording: the two rules an encoder enforces itself, and the ones the
// queue enforces when the commands it recorded arrive.

///|
fn colour_view(
  device : Device,
  samples~ : Int32 = 1,
) -> TextureView raise @core.Refused {
  let texture = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=4, height=4),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::render_attachment(),
      sample_count=samples,
    ),
  )
  texture.create_view()
}

///|
test "a top level command cannot be recorded while a pass is open" {
  let device = device()
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(color_attachments=[
      @types.ColorAttachment::new(view=colour_view(device).id()),
    ]),
  )
  let source = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::copy_src() | @types.BufferUsages::copy_dst(),
    ),
  )
  try {
    encoder.copy_buffer_to_buffer(
      source~,
      source_offset=0,
      destination=source,
      destination_offset=0,
      size=16,
    )
    fail("the pass is still open")
  } catch {
    @core.Refused::Validation(kind~, ..) => assert_eq(kind, @types.PassNotEnded)
    _ => fail("wrong refusal")
  }
  pass.end()
}

///|
test "a pass ends once" {
  let device = device()
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(color_attachments=[
      @types.ColorAttachment::new(view=colour_view(device).id()),
    ]),
  )
  pass.end()
  try {
    pass.end()
    fail("the pass has already ended")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidPassState)
    _ => fail("wrong refusal")
  }
}

///|
test "nothing records into a pass after it ends" {
  let device = device()
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(color_attachments=[
      @types.ColorAttachment::new(view=colour_view(device).id()),
    ]),
  )
  pass.end()
  try {
    pass.set_scissor_rect(x=0, y=0, width=4, height=4)
    fail("the pass has ended")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidPassState)
    _ => fail("wrong refusal")
  }
}

///|
test "an encoder with an open pass cannot finish" {
  let device = device()
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(color_attachments=[
      @types.ColorAttachment::new(view=colour_view(device).id()),
    ]),
  )
  try {
    encoder.finish() |> ignore
    fail("the pass is still open")
  } catch {
    @core.Refused::Validation(kind~, ..) => assert_eq(kind, @types.PassNotEnded)
    _ => fail("wrong refusal")
  }
  pass.end()
}

///|
test "a finished encoder records nothing more" {
  let device = device()
  let encoder = device.create_command_encoder()
  encoder.finish() |> ignore
  let buffer = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::copy_src() | @types.BufferUsages::copy_dst(),
    ),
  )
  try {
    encoder.copy_buffer_to_buffer(
      source=buffer,
      source_offset=0,
      destination=buffer,
      destination_offset=0,
      size=16,
    )
    fail("the encoder has finished")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.EncoderFinished)
    _ => fail("wrong refusal")
  }
}

///|
test "a render pass with no attachment is refused" {
  let device = device()
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(),
  )
  pass.end()
  try {
    device.queue().submit(command_buffers=[encoder.finish()])
    fail("a pass needs something to write")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidPassDescriptor)
    _ => fail("wrong refusal")
  }
}

///|
test "a draw without a pipeline is refused at submit" {
  let device = device()
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(color_attachments=[
      @types.ColorAttachment::new(view=colour_view(device).id()),
    ]),
  )
  pass.draw(arguments=@types.DrawArguments::new(vertex_count=3))
  pass.end()
  try {
    device.queue().submit(command_buffers=[encoder.finish()])
    fail("a draw needs a pipeline")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidPassState)
    _ => fail("wrong refusal")
  }
}

///|
test "a dispatch without a pipeline is refused at submit" {
  let device = device()
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_compute_pass()
  pass.dispatch_workgroups(arguments=@types.DispatchArguments::new(x=1))
  pass.end()
  try {
    device.queue().submit(command_buffers=[encoder.finish()])
    fail("a dispatch needs a pipeline")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidPassState)
    _ => fail("wrong refusal")
  }
}

///|
test "an attachment sample count must match the one the others use" {
  let device = device()
  let encoder = device.create_command_encoder()
  let single = colour_view(device)
  let four = colour_view(device, samples=4)
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(color_attachments=[
      @types.ColorAttachment::new(view=single.id()),
      @types.ColorAttachment::new(view=four.id()),
    ]),
  )
  pass.end()
  try {
    device.queue().submit(command_buffers=[encoder.finish()])
    fail("the two attachments disagree about samples")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidPassDescriptor)
    _ => fail("wrong refusal")
  }
}

///|
test "a read only depth attachment cannot clear" {
  let device = device()
  let depth = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=4, height=4),
      format=@types.TextureFormat::Depth32float,
      usage=@types.TextureUsages::render_attachment(),
    ),
  )
  let view = depth.create_view()
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(
      color_attachments=[
        @types.ColorAttachment::new(view=colour_view(device).id()),
      ],
      depth_stencil_attachment=@types.DepthStencilAttachment::new(
        view=view.id(),
        depth_load_op=@types.LoadOp::Clear,
        depth_read_only=true,
      ),
    ),
  )
  pass.end()
  try {
    device.queue().submit(command_buffers=[encoder.finish()])
    fail("a read only attachment keeps what it holds")
  } catch {
    @core.Refused::Validation(kind~, ..) =>
      assert_eq(kind, @types.InvalidPassDescriptor)
    _ => fail("wrong refusal")
  }
}

///|
test "two passes in one encoder are both recorded in order" {
  let device = device()
  let encoder = device.create_command_encoder()
  let first = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(
      color_attachments=[
        @types.ColorAttachment::new(view=colour_view(device).id()),
      ],
      label="first",
    ),
  )
  first.end()
  let second = encoder.begin_compute_pass()
  second.end()
  let commands = encoder.finish().commands
  assert_eq(commands.length(), 2)
}
