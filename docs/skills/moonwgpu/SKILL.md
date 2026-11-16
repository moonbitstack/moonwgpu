---
name: moonwgpu
description: Use the WebGPU API from MoonBit — devices, buffers, textures, pipelines, command buffers and passes, with the specification's validation. Read this when drawing, computing on a device, or moving bytes to and from one.
---

# moonwgpu

The WebGPU API, in MoonBit. One surface over any host: the objects are the ones
the specification defines, the validation is the specification's, and a backend
decides whether the work runs on a graphics API, in a browser, or in memory.

```bash
moon add moonbitstack/moonwgpu
```

## A device over the memory backend

The memory backend is the one that needs nothing: it holds resources in memory
and executes every copy and clear for real, which makes it the way to test a
program that does not need pixels.

```moonbit check
test {
  let backend = @memory.Backend::new()
  let device = @moonwgpu.Instance::new(backend~).request_adapter().request_device()
  let texture = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=4, height=4),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::copy_dst() | @types.TextureUsages::copy_src(),
    ),
  )
  assert_eq(texture.mip_level_count(), 1)
  assert_eq(device.backend_name(), "memory")
}
```

## Moving bytes

Writes go through the queue; reads come back through a mapped buffer. A buffer
that is mapped for reading may only carry `copy_dst` as well, which is why a
read-back buffer is not also a copy source.

```moonbit check
test {
  let backend = @memory.Backend::new()
  let device = @moonwgpu.Instance::new(backend~).request_adapter().request_device()
  let buffer = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::map_read() | @types.BufferUsages::copy_dst(),
    ),
  )
  device.queue().write_buffer(buffer=buffer, offset=0, data=b"\x2a\x00\x00\x00")
  buffer.map_read()
  assert_eq(buffer.get_mapped_range()[0], b'\x2a')
  buffer.unmap()
  assert_eq(buffer.map_state(), @types.MapState::Unmapped)
}
```

## Recording a pass

A pass records; the queue validates and submits. A draw needs a pipeline set
first, and a pass needs at least one attachment — both are refused when the
command buffer reaches the queue, with the class of the specification's error.

```moonbit check
test {
  let backend = @memory.Backend::new()
  let device = @moonwgpu.Instance::new(backend~).request_adapter().request_device()
  let shader = device.create_shader_module(
    descriptor=@types.ShaderModuleDescriptor::wgsl(source="// vertex stage\n"),
  )
  let layout = device.create_pipeline_layout(
    descriptor=@types.PipelineLayoutDescriptor::new(bind_group_layouts=[]),
  )
  let pipeline = device.create_render_pipeline(
    descriptor=@types.RenderPipelineDescriptor::new(
      layout=layout.id(),
      vertex=@types.VertexState::new(shader=shader.id(), entry_point="vs_main"),
      fragment=@types.FragmentState::new(
        shader=shader.id(),
        entry_point="fs_main",
        targets=[@types.ColorTargetState::new(format=@types.TextureFormat::Bgra8unorm)],
      ),
    ),
  )
  let target = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=64, height=64),
      format=@types.TextureFormat::Bgra8unorm,
      usage=@types.TextureUsages::render_attachment(),
    ),
  )
  let encoder = device.create_command_encoder()
  let pass = encoder.begin_render_pass(
    descriptor=@types.RenderPassDescriptor::new(
      color_attachments=[@types.ColorAttachment::new(view=target.create_view().id())],
    ),
  )
  pass.set_pipeline(pipeline=pipeline)
  pass.draw(arguments=@types.DrawArguments::new(vertex_count=3))
  pass.end()
  device.queue().submit(command_buffers=[encoder.finish()])
  assert_eq(pipeline.label(), "")
}
```

## Things to know

- **Errors are raised, not delivered later.** Every refusal is a
  `@core.Refused`: `Validation(kind, at, want, got)`, `OutOfMemory`,
  `DeviceLost` or `Internal`. `kind` is the class the specification names, and
  `at` is the place in the descriptor, as in `"descriptor.usage"`.
- **Validation happens at the queue for commands.** A draw that names no
  pipeline is legal to record and refused at `submit`; keep the whole batch in
  mind.
- **One pass at a time.** A command that stands on its own cannot be recorded
  while a pass is open, and a pass that has ended records nothing.
- **`map_read` is the promise.** The specification's `mapAsync` waits because a
  device works later; here the device timeline runs in the caller's thread, so
  the call is the wait.
- **A shader is not compiled.** Pipelines keep the module and entry point by
  name; executing them needs a WGSL front end, which is a separate library.
- **Features gate formats and queries.** `rg11b10ufloat`, the compressed
  formats and timestamp queries need their feature enabled on the device, and
  the errors say which one is missing.
