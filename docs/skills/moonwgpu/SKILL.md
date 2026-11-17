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

## An external frame

Where a browser imports a video element, a native host hands over the pixels it
decoded: the size, the format and the bytes, packed row by row. Importing copies
them, so the host may reuse its buffer immediately, and the texture lasts until
the host says the frame is gone.

```moonbit check
test {
  let backend = @memory.Backend::new()
  let device = @moonwgpu.Instance::new(backend~).request_adapter().request_device()
  let image = @types.ExternalImage::new(
    size=@types.Extent3d::new(width=1, height=1),
    format=@types.TextureFormat::Rgba8unorm,
    data=b"\xff\x00\x00\xff",
  )
  let frame = device.import_external_texture(
    descriptor=@types.ExternalTextureDescriptor::new(image~),
  )
  let target = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=1, height=1),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::copy_dst(),
    ),
  )
  device.queue().copy_external_image_to_texture(
    source=@types.CopyExternalImageSourceInfo::new(image~, flip_y=true),
    destination=@types.CopyExternalImageDestInfo::new(
      texture=target.id(),
      premultiplied_alpha=true,
    ),
    copy_size=@types.Extent3d::new(width=1, height=1),
  )
  frame.expire()
  assert_true(frame.is_expired())
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
- **`mapAsync` maps a range.** The offset is a multiple of 8 and the size a
  non-zero multiple of 4; `map_read` and `map_write` are the whole-buffer
  shorthands. A write mapping is filled by `map_write` and reaches the device
  when `unmap` runs.
- **A shader may arrive already compiled.** `ShaderModuleDescriptor::spirv`
  takes words from a front end; the magic number and the word alignment are
  checked, and nothing is parsed.
- **A canvas is a surface plus a context.** `CanvasContext::new(surface~)` takes
  a `@hal.Surface` a host implements over its window; `configure` binds a device
  and a format, `get_current_texture` returns an ordinary `Texture`.
- **A backend that is not bound refuses once.** `hal/vulkan`, `hal/metal`,
  `hal/dx12`, `hal/gles` and `web` are packages with a name and a reason; their
  `open()` hands back a backend whose every call raises `Internal` with that
  reason, so code written for them compiles and fails where the driver would
  have answered.
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
- **Immediates are recorded, not bound.** `set_immediates` loads a word-aligned
  run of bytes for the pipeline that was set before it; the range and the run
  are both counted in four-byte words.
- **Compilation info comes from the backend.** `get_compilation_info` reports
  what the host's shader compiler said, and the memory backend has none, so it
  reports no message — a module there is only as checked as its caller.
- **An external frame has a lifetime.** `import_external_texture` copies the
  pixels at import; `expire` is how a host says the frame has been replaced.
- **Errors no scope collects are kept.** A device hands them to
  `set_uncapturederror_handler`, or keeps them for `uncaptured_errors` when no
  handler is set.
- **The rules come from a document in the tree.** `spec/` is the editor's
  draft, pinned to one revision; the W3C text at
  <https://www.w3.org/TR/webgpu/> is what a rule is implemented against, and the
  draft only adds to it.
- **One library, four backends.** The suite passes on `wasm`, `wasm-gc`, `js`
  and `native`; `conformance/targets.json` records the count for each, and
  `scripts/targets.py --check` fails when a backend loses one.
- **The `js` backend can be driven from JavaScript.** `src/bindings/js` is built
  for `--target js` and publishes `ask`/`text`/`take` on `globalThis`;
  `conformance/js/webgpu.mjs` wraps them in `navigator.gpu`, promises and
  `GPUValidationError`. What a refusal looks like there is
  `Device::report_error`: the raise a MoonBit caller sees becomes the error a
  `popErrorScope` returns.
