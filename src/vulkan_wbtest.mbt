// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The four examples, with a device behind them and the pixels read back.
//
// `MOONWGPU_VULKAN_LIVE=1` turns "this machine has no Vulkan device" from a
// skip into a failure, which is how CI on Linux keeps the tests honest: a run
// there has to render, not quietly return.

///|
/// Whether a device is required on this run. Only a native build can have one,
/// so only there does the variable mean anything.
#cfg(target="native")
fn live_required() -> Bool {
  @env.get_env_var("MOONWGPU_VULKAN_LIVE") is Some(_)
}

///|
#cfg(not(target="native"))
fn live_required() -> Bool {
  false
}

///|
fn device_for_test() -> (@vulkan.Backend, Device)? raise {
  let backend = @vulkan.open()
  if !backend.available() {
    if live_required() {
      fail(
        "MOONWGPU_VULKAN_LIVE is set but there is no device: \{backend.reason()}",
      )
    }
    return None
  }
  let device = Instance::new(backend~).request_adapter().request_device()
  Some((backend, device))
}

///|
/// Four bytes of little-endian IEEE 754 per value.
fn float_bytes(values : Array[Float]) -> Bytes {
  let out : Array[Byte] = []
  for value in values {
    let bits = value.reinterpret_as_uint()
    for i in 0..<4 {
      out.push(((bits >> (i * 8)).reinterpret_as_int() & 0xff).to_byte())
    }
  }
  Bytes::from_array(out)
}

///|
/// One texel of `rgba8unorm`, as four bytes.
fn texel(
  red : Int32,
  green : Int32,
  blue : Int32,
  alpha : Int32,
) -> Array[Byte] {
  [red.to_byte(), green.to_byte(), blue.to_byte(), alpha.to_byte()]
}

///|
fn texel_at(bytes : Array[Byte], index : Int32) -> Array[Byte] {
  [
    bytes[index * 4],
    bytes[index * 4 + 1],
    bytes[index * 4 + 2],
    bytes[index * 4 + 3],
  ]
}

///|
test "a clear pass writes the colour it was handed" {
  match device_for_test() {
    None => return
    Some((backend, device)) => {
      let texture = device.create_texture(
        descriptor=@types.TextureDescriptor::new(
          size=@types.Extent3d::new(width=4, height=4),
          format=@types.TextureFormat::Rgba8unorm,
          usage=@types.TextureUsages::render_attachment() |
            @types.TextureUsages::copy_src(),
        ),
      )
      let view = texture.create_view()
      let encoder = device.create_command_encoder(label="clear")
      let pass = encoder.begin_render_pass(
        descriptor=@types.RenderPassDescriptor::new(color_attachments=[
          @types.ColorAttachment::new(
            view=view.id(),
            load_op=@types.LoadOp::Clear,
            clear_value=@types.Color::new(r=0.2, g=0.4, b=0.6, a=1.0),
          ),
        ]),
      )
      pass.end()
      device.queue().submit(command_buffers=[encoder.finish()])
      let texels = backend.texture_bytes(texture.id())
      assert_eq(texels.length(), 64)
      for index in 0..<16 {
        assert_eq(texel_at(texels, index), texel(51, 102, 153, 255))
      }
      backend.close()
    }
  }
}

///|
/// Whether a pixel centre lies inside the triangle the test draws, by the sign
/// of the three edge functions. The vertices are placed so that no centre is
/// within a hundredth of an edge, which is what makes software and hardware
/// rasterisers agree here.
fn in_triangle(x : Double, y : Double) -> Bool {
  let ax = 16.0
  let ay = 48.0
  let bx = 48.0
  let by = 48.0
  let cx = 32.0
  let cy = 16.0
  let e0 = (bx - ax) * (y - ay) - (by - ay) * (x - ax)
  let e1 = (cx - bx) * (y - by) - (cy - by) * (x - bx)
  let e2 = (ax - cx) * (y - cy) - (ay - cy) * (x - cx)
  (e0 >= 0.0 && e1 >= 0.0 && e2 >= 0.0) || (e0 <= 0.0 && e1 <= 0.0 && e2 <= 0.0)
}

///|
test "a triangle covers the pixels its geometry covers" {
  match device_for_test() {
    None => return
    Some((backend, device)) => {
      let positions = float_bytes([-0.5, -0.5, 0.5, -0.5, 0.0, 0.5])
      let vertices = device.create_buffer(
        descriptor=@types.BufferDescriptor::new(
          size=positions.length(),
          usage=@types.BufferUsages::vertex() | @types.BufferUsages::copy_dst(),
        ),
      )
      device.queue().write_buffer(buffer=vertices, offset=0, data=positions)
      let shader = device.create_shader_module(
        descriptor=@types.ShaderModuleDescriptor::spirv(
          words=@shaders.triangle_vertex,
          label="triangle vertex",
        ),
      )
      let fragment_shader = device.create_shader_module(
        descriptor=@types.ShaderModuleDescriptor::spirv(
          words=@shaders.triangle_fragment,
          label="triangle fragment",
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
            entry_point="main",
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
            shader=fragment_shader.id(),
            entry_point="main",
            targets=[
              @types.ColorTargetState::new(
                format=@types.TextureFormat::Rgba8unorm,
              ),
            ],
          ),
        ),
      )
      let target = device.create_texture(
        descriptor=@types.TextureDescriptor::new(
          size=@types.Extent3d::new(width=64, height=64),
          format=@types.TextureFormat::Rgba8unorm,
          usage=@types.TextureUsages::render_attachment() |
            @types.TextureUsages::copy_src(),
        ),
      )
      let view = target.create_view()
      let encoder = device.create_command_encoder(label="triangle")
      let pass = encoder.begin_render_pass(
        descriptor=@types.RenderPassDescriptor::new(color_attachments=[
          @types.ColorAttachment::new(
            view=view.id(),
            load_op=@types.LoadOp::Clear,
            clear_value=@types.Color::black(),
          ),
        ]),
      )
      pass.set_pipeline(pipeline~)
      pass.set_vertex_buffer(slot=0, buffer=vertices)
      pass.draw(arguments=@types.DrawArguments::new(vertex_count=3))
      pass.end()
      device.queue().submit(command_buffers=[encoder.finish()])
      let texels = backend.texture_bytes(target.id())
      let mut inside = 0
      let mut wrong = 0
      for y in 0..<64 {
        for x in 0..<64 {
          let index = y * 64 + x
          let covered = in_triangle(x.to_double() + 0.5, y.to_double() + 0.5)
          let expected = if covered {
            texel(255, 128, 64, 255)
          } else {
            texel(0, 0, 0, 255)
          }
          if texel_at(texels, index) != expected {
            wrong = wrong + 1
          }
          if covered {
            inside = inside + 1
          }
        }
      }
      assert_eq(wrong, 0)
      assert_eq(inside, 512)
      backend.close()
    }
  }
}

///|
/// The texture path that does work end to end: rows go in through the queue and
/// come back out through the transfer path unchanged.
///
/// A draw that samples this texture reads zero on the software driver this was
/// developed against, which is written down in the delivery note rather than
/// asserted here.
test "a texture written through the queue keeps its texels" {
  match device_for_test() {
    None => return
    Some((backend, device)) => {
      let image = device.create_texture(
        descriptor=@types.TextureDescriptor::new(
          size=@types.Extent3d::new(width=3, height=2),
          format=@types.TextureFormat::Rgba8unorm,
          usage=@types.TextureUsages::texture_binding() |
            @types.TextureUsages::copy_dst(),
        ),
      )
      let pixels = Bytes::from_array([
        b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08', b'\x09',
        b'\x0a', b'\x0b', b'\x0c', b'\x0d', b'\x0e', b'\x0f', b'\x10', b'\x11', b'\x12',
        b'\x13', b'\x14', b'\x15', b'\x16', b'\x17', b'\x18',
      ])
      device
      .queue()
      .write_texture(
        destination=@types.TexelCopyTextureInfo::new(texture=image.id()),
        data=pixels,
      )
      let texels = backend.texture_bytes(image.id())
      assert_eq(texels.length(), 24)
      for index in 0..<24 {
        assert_eq(texels[index].to_int(), index + 1)
      }
      backend.close()
    }
  }
}

///|
test "a compute pass fills the buffer the shader describes" {
  match device_for_test() {
    None => return
    Some((backend, device)) => {
      let size = 4096
      let storage = device.create_buffer(
        descriptor=@types.BufferDescriptor::new(
          size~,
          usage=@types.BufferUsages::storage() | @types.BufferUsages::copy_src(),
        ),
      )
      let result = device.create_buffer(
        descriptor=@types.BufferDescriptor::new(
          size~,
          usage=@types.BufferUsages::copy_dst() |
            @types.BufferUsages::map_read(),
        ),
      )
      let shader = device.create_shader_module(
        descriptor=@types.ShaderModuleDescriptor::spirv(
          words=@shaders.fill_compute,
        ),
      )
      let layout = device.create_bind_group_layout(
        descriptor=@types.BindGroupLayoutDescriptor::new(entries=[
          @types.BindGroupLayoutEntry::new(
            binding=0,
            visibility=@types.ShaderStages::compute(),
            kind=@types.BindingLayout::Buffer(
              @types.BufferBindingLayout::new(
                kind=@types.BufferBindingType::Storage,
                min_binding_size=size,
              ),
            ),
          ),
        ]),
      )
      let pipeline_layout = device.create_pipeline_layout(
        descriptor=@types.PipelineLayoutDescriptor::new(bind_group_layouts=[
          layout.id(),
        ]),
      )
      let pipeline = device.create_compute_pipeline(
        descriptor=@types.ComputePipelineDescriptor::new(
          shader=shader.id(),
          entry_point="main",
          layout=pipeline_layout.id(),
        ),
      )
      let bind_group = device.create_bind_group(
        descriptor=@types.BindGroupDescriptor::new(layout=layout.id(), entries=[
          @types.BindGroupEntry::new(
            binding=0,
            resource=@types.BindingResource::Buffer(
              @types.BufferBinding::new(buffer=storage.id(), size~),
            ),
          ),
        ]),
      )
      let encoder = device.create_command_encoder(label="fill")
      let pass = encoder.begin_compute_pass()
      pass.set_pipeline(pipeline~)
      pass.set_bind_group(index=0, bind_group~)
      pass.dispatch_workgroups(arguments=@types.DispatchArguments::new(x=16))
      pass.end()
      encoder.copy_buffer_to_buffer(
        source=storage,
        source_offset=0,
        destination=result,
        destination_offset=0,
        size~,
      )
      device.queue().submit(command_buffers=[encoder.finish()])
      let bytes = backend.buffer_bytes(result.id())
      assert_eq(bytes.length(), 1024 * 4)
      let mut wrong = 0
      for index in 0..<1024 {
        let at = index * 4
        let value = bytes[at].to_int() |
          (bytes[at + 1].to_int() << 8) |
          (bytes[at + 2].to_int() << 16) |
          (bytes[at + 3].to_int() << 24)
        if value != index * 2 + 1 {
          wrong = wrong + 1
        }
      }
      assert_eq(wrong, 0)
      backend.close()
    }
  }
}
