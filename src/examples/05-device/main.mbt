// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The four places a device is used, on a real one.
///
/// This is the example the other four cannot be: it opens the Vulkan backend,
/// renders, reads the pixels back and prints what it found. Where there is no
/// device it says so and stops, which is what a machine without a Vulkan
/// driver sees.
///
///     moon run src/examples/05-device

///|
fn main raise {
  let backend = @vulkan.open()
  if !backend.available() {
    println("device:  none — \{backend.reason()}")
    return
  }
  println("device:  \{backend.device_name()}")
  let device = @moonwgpu.Instance::new(backend~)
    .request_adapter()
    .request_device()
  clear(device, backend)
  triangle(device, backend)
  fill(device, backend)
  backend.close()
}

///|
/// Four bytes of little-endian IEEE 754 per value.
fn floats(values : Array[Float]) -> Bytes {
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
fn buffer_of(
  device : @moonwgpu.Device,
  data : Bytes,
  usage : @types.BufferUsages,
) -> @moonwgpu.Buffer raise {
  let buffer = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(size=data.length(), usage~),
  )
  device.queue().write_buffer(buffer~, offset=0, data~)
  buffer
}

///|
fn target_of(
  device : @moonwgpu.Device,
  size : Int32,
) -> @moonwgpu.Texture raise {
  device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=size, height=size),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::render_attachment() |
        @types.TextureUsages::copy_src(),
    ),
  )
}

///|
fn clear(device : @moonwgpu.Device, backend : @vulkan.Backend) -> Unit raise {
  let target = target_of(device, 4)
  let view = target.create_view()
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
  let texels = backend.texture_bytes(target.id())
  println(
    "clear:   4x4 read back as \{texels[0].to_int()},\{texels[1].to_int()},\{texels[2].to_int()},\{texels[3].to_int()}",
  )
}

///|
fn triangle(device : @moonwgpu.Device, backend : @vulkan.Backend) -> Unit raise {
  let vertices = buffer_of(
    device,
    floats([-0.5, -0.5, 0.5, -0.5, 0.0, 0.5]),
    @types.BufferUsages::vertex() | @types.BufferUsages::copy_dst(),
  )
  let vertex_shader = device.create_shader_module(
    descriptor=@types.ShaderModuleDescriptor::spirv(
      words=@shaders.triangle_vertex,
    ),
  )
  let fragment_shader = device.create_shader_module(
    descriptor=@types.ShaderModuleDescriptor::spirv(
      words=@shaders.triangle_fragment,
    ),
  )
  let layout = device.create_pipeline_layout(
    descriptor=@types.PipelineLayoutDescriptor::new(bind_group_layouts=[]),
  )
  let pipeline = device.create_render_pipeline(
    descriptor=@types.RenderPipelineDescriptor::new(
      layout=layout.id(),
      vertex=@types.VertexState::new(
        shader=vertex_shader.id(),
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
          @types.ColorTargetState::new(format=@types.TextureFormat::Rgba8unorm),
        ],
      ),
    ),
  )
  let target = target_of(device, 64)
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
  let mut covered = 0
  for index in 0..<(64 * 64) {
    if texels[index * 4].to_int() == 255 {
      covered = covered + 1
    }
  }
  println("triangle: \{covered} of 4096 pixels in the triangle's colour")
}

///|
fn fill(device : @moonwgpu.Device, backend : @vulkan.Backend) -> Unit raise {
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
      usage=@types.BufferUsages::copy_dst() | @types.BufferUsages::map_read(),
    ),
  )
  let shader = device.create_shader_module(
    descriptor=@types.ShaderModuleDescriptor::spirv(words=@shaders.fill_compute),
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
  let mut correct = 0
  for index in 0..<1024 {
    let at = index * 4
    let value = bytes[at].to_int() |
      (bytes[at + 1].to_int() << 8) |
      (bytes[at + 2].to_int() << 16) |
      (bytes[at + 3].to_int() << 24)
    if value == index * 2 + 1 {
      correct = correct + 1
    }
  }
  println("compute: \{correct} of 1024 words read back as 2n+1")
}
