// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Clearing a texture, start to finish.
///
/// This is the shortest path through the whole library: an instance over the
/// memory backend, an adapter, a device, a texture, a command buffer that
/// clears it, and a read-back that proves the texels are zero.
///
///     moon run src/examples/01-clear
#coverage.skip
fn main raise {
  let backend = @memory.Backend::new()
  let instance = @moonwgpu.Instance::new(backend~)
  let adapter = instance.request_adapter()
  let device = adapter.request_device()
  let texture = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=4, height=4),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::copy_dst() |
        @types.TextureUsages::copy_src() |
        @types.TextureUsages::render_attachment(),
    ),
  )
  let view = texture.create_view()
  let encoder = device.create_command_encoder(label="clear")
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(
      color_attachments=[
        @types.ColorAttachment::new(
          view=view.id(),
          load_op=@types.LoadOp::Clear,
          clear_value=@types.Color::new(r=0.2, g=0.4, b=0.6, a=1.0),
        ),
      ],
      label="clear pass",
    ),
  )
  pass.end()
  encoder.clear_texture(texture~)
  device.queue().submit(command_buffers=[encoder.finish()])
  let texels = backend.texture_bytes(texture.id(), mip_level=0)
  println("backend:        \{instance.backend_name()}")
  println("texture:        4x4 \{texture.format().name()}")
  println("texels read:    \{texels.length()} bytes")
  let mut cleared = 0
  for texel in texels {
    if texel == b'\x00' {
      cleared = cleared + 1
    }
  }
  println("zero bytes:     \{cleared} of \{texels.length()}")
}
