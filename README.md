# moonwgpu

The WebGPU API for MoonBit: one surface, any host.

Every object the [WebGPU specification](https://www.w3.org/TR/webgpu/) defines is
here under its own name — `Instance`, `Adapter`, `Device`, `Queue`, the
resources, the encoders, the passes, the bundles — together with the validation
the specification puts in front of each of them. A caller writes one program; a
backend decides whether it runs on a graphics API or in memory.

```moonbit nocheck
let backend = @memory.Backend::new()
let device = @moonwgpu.Instance::new(backend~).request_adapter().request_device()
```

The library is layered so that each question has one home:

| Package | What it holds |
|:--|:--|
| `moonbitstack/moonwgpu` | The objects: instance, adapter, device, queue, buffers, textures, samplers, shader modules, layouts, pipelines, encoders, passes, bundles, query sets, canvas contexts |
| `moonbitstack/moonwgpu/types` | The vocabulary: descriptors, enumerations, flag sets, the texture and vertex format tables, limits and features, surface configurations |
| `moonbitstack/moonwgpu/core` | The rules: descriptor validation, usage tracking, command recording, error scopes |
| `moonbitstack/moonwgpu/hal` | The contract a host implements: create, write, read, submit, and the `Surface` a window system fills |
| `moonbitstack/moonwgpu/hal/memory` | A host that keeps everything in memory and executes every copy and clear for real |
| `moonbitstack/moonwgpu/hal/vulkan`, `hal/metal`, `hal/dx12`, `hal/gles`, `web` | One package per graphics API: the name of the backend, the seam it will sit on, and a refusal until its C stub or host bridge exists |

## Install

```bash
moon add moonbitstack/moonwgpu
```

## The first device

An instance takes a backend; everything above it is the same whatever the
backend is.

```moonbit check
test {
  let backend = @memory.Backend::new()
  let instance = @moonwgpu.Instance::new(backend~)
  let adapter = instance.request_adapter()
  let device = adapter.request_device()
  assert_eq(instance.backend_name(), "memory")
  assert_eq(device.limits().max_bind_groups, 4)
}
```

## Bytes in, bytes out

A buffer that can be written and mapped is the shortest way to see the library
work: the queue writes, the command buffer copies, the mapping reads.

```moonbit check
test {
  let backend = @memory.Backend::new()
  let device = @moonwgpu.Instance::new(backend~).request_adapter().request_device()
  let source = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::copy_src() | @types.BufferUsages::copy_dst(),
    ),
  )
  let destination = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::copy_dst() | @types.BufferUsages::map_read(),
    ),
  )
  device.queue().write_buffer(buffer=source, offset=0, data=b"\x01\x02\x03\x04")
  let encoder = device.create_command_encoder()
  encoder.copy_buffer_to_buffer(
    source=source,
    source_offset=0,
    destination=destination,
    destination_offset=4,
    size=4,
  )
  device.queue().submit(command_buffers=[encoder.finish()])
  destination.map_read()
  let bytes = destination.get_mapped_range()
  assert_eq(bytes[4], b'\x01')
  assert_eq(bytes[7], b'\x04')
}
```

## A frame from the host

Where a browser imports a video element, a native host hands over the frame it
already decoded. The frame is copied when it is imported, so the host may reuse
its buffer as soon as the call returns, and the texture lives until the host
says the frame has moved on.

```moonbit check
test {
  let backend = @memory.Backend::new()
  let device = @moonwgpu.Instance::new(backend~).request_adapter().request_device()
  let image = @types.ExternalImage::new(
    size=@types.Extent3d::new(width=2, height=1),
    format=@types.TextureFormat::Rgba8unorm,
    data=b"\xff\x00\x00\xff\x00\xff\x00\xff",
  )
  let frame = device.import_external_texture(
    descriptor=@types.ExternalTextureDescriptor::new(image~),
  )
  let target = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=2, height=1),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::copy_dst(),
    ),
  )
  device.queue().copy_external_image_to_texture(
    source=@types.CopyExternalImageSourceInfo::new(image~),
    destination=@types.CopyExternalImageDestInfo::new(texture=target.id()),
    copy_size=@types.Extent3d::new(width=2, height=1),
  )
  assert_false(frame.is_expired())
  frame.expire()
  assert_true(frame.is_expired())
}
```

## A shader you compiled yourself

The device takes WGSL, and it also takes SPIR-V that a front end already
produced, which is what a native backend wants and what a caller with a build
step already has. The second form is checked for the magic number and for whole
words, and nothing else: parsing SPIR-V is not this library's question.

```moonbit check
test {
  let backend = @memory.Backend::new()
  let device = @moonwgpu.Instance::new(backend~).request_adapter().request_device()
  let words = b"\x03\x02\x23\x07\x00\x00\x01\x00"
  let shader = device.create_shader_module(
    descriptor=@types.ShaderModuleDescriptor::spirv(words~),
  )
  assert_eq(shader.get_compilation_info().messages.length(), 0)
}
```

## A canvas

A canvas is the one object that cannot exist without a window system, so it is
split in two: `CanvasContext` holds a `@hal.Surface`, which a host implements
over its own window or view, and turns the frames that surface hands out into
ordinary `Texture` objects. Configure it with a device and a format, take a
frame with `get_current_texture`, render into it like any other texture, and
give it back with `present`.

```moonbit nocheck
let canvas = @moonwgpu.CanvasContext::new(surface~=window)
canvas.configure(
  device~,
  configuration=@types.SurfaceConfiguration::new(
    format=instance.get_preferred_canvas_format(),
  ),
)
let frame = canvas.get_current_texture()
// ... record a pass into `frame` ...
device.queue().submit(command_buffers=[encoder.finish()])
canvas.present(texture=frame)
```

## What the device refuses

Validation is not a mode: every call that the specification validates raises a
`Refused` carrying the class of the error, the place in the descriptor, the
value the rule wanted and the value it got.

```moonbit check
test {
  let backend = @memory.Backend::new()
  let device = @moonwgpu.Instance::new(backend~).request_adapter().request_device()
  try {
    device.create_buffer(
      descriptor=@types.BufferDescriptor::new(
        size=16,
        usage=@types.BufferUsages::map_read() | @types.BufferUsages::vertex(),
      ),
    ) |> ignore
    fail("MAP_READ may only be combined with COPY_DST")
  } catch {
    @core.Refused::Validation(kind~, at~, ..) => {
      assert_eq(kind, @types.InvalidBufferUsage)
      assert_eq(at, "descriptor.usage")
    }
    _ => fail("the refusal should be a validation error")
  }
}
```

## Objects

| Object | What it is for |
|:--|:--|
| `Instance` | The entry point, over one backend |
| `Adapter` | What a host offers: limits, features, and a device |
| `Device` | Makes resources, encoders, pipelines and query sets; error scopes |
| `Queue` | Writes bytes, submits command buffers, waits for work |
| `Buffer` | Bytes the device reads and writes; mapping for read-back |
| `Texture`, `TextureView` | Texels, mip levels, array layers, and the views over them |
| `Sampler` | How a shader reads a texture |
| `ShaderModule` | WGSL source, kept for the pipelines that name its entry points |
| `BindGroupLayout`, `BindGroup` | What a shader sees, and the resources bound to it |
| `PipelineLayout`, `RenderPipeline`, `ComputePipeline` | The whole fixed-function state of a draw or a dispatch |
| `CommandEncoder`, `CommandBuffer` | Recording, then submitting |
| `RenderPassEncoder`, `ComputePassEncoder` | One pass: pipeline, bindings, draws, dispatches |
| `RenderBundleEncoder`, `RenderBundle` | A recorded run of draws any pass can execute |
| `QuerySet` | Timestamps and occlusion results |
| `ExternalTexture` | A decoded frame a host handed over, bindable until it expires |
| `CanvasContext` | A surface a host provides, configured with a device and a format |

## What runs today

The memory backend executes every command that moves bytes — the four copies,
buffer and texture clears, and queue writes — byte for byte. Passes, draws and
dispatches are validated and recorded in full, and executed by a host that has a
shader compiler; running WGSL is a separate library's question, and this one
keeps the seam (`hal`'s contract) rather than pretending.

| Capability | State |
|:--|:--|
| Creating every resource, with the specification's validation | done |
| Bind groups, pipeline layouts, render and compute pipelines | done |
| Command recording: passes, bundles, indirect draws and dispatches | done |
| Copies and clears, executed byte exactly on the memory backend | done |
| Mapping a buffer, whole or by range (`mapAsync`), for reading and for writing | done |
| Query sets, timestamps, occlusion queries | recorded and validated |
| Shader compilation info (`getCompilationInfo`) | reported by a backend that compiles; empty without one |
| Shader modules from WGSL or from SPIR-V a front end produced | accepted, with the magic number and word alignment checked |
| Immediate constants (`setImmediates`) | recorded and validated in passes and bundles |
| External frames (`importExternalTexture`, `copyExternalImageToTexture`) | copied texel by texel, with row flipping and alpha premultiplication |
| Limits, features and their dependencies | the specification's full tables |
| Texture and vertex format tables | every format the specification defines |
| Canvases (`CanvasContext`, `configure`, `getCurrentTexture`) | a frame is an ordinary texture over the host's `Surface` |
| Executing a shader | needs a WGSL front end, which is its own library (`moonnaga`) |
| Vulkan, Metal, D3D12, GLES and browser backends | packaged and named; each refuses with its reason until its stub exists, and `hal` is where that stub lands |

## Install and targets

All four targets build and test: `wasm`, `wasm-gc`, `js`, `native`. Nothing is
native-only, and nothing is a stub: a backend that cannot do something says so
through `HalError` instead of returning a value that looks like success.

## Licence

Apache-2.0. See [LICENSE](LICENSE).
