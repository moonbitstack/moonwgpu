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
| `moonbitstack/moonwgpu` | The objects: instance, adapter, device, queue, buffers, textures, samplers, shader modules, layouts, pipelines, encoders, passes, bundles, query sets |
| `moonbitstack/moonwgpu/types` | The vocabulary: descriptors, enumerations, flag sets, the texture and vertex format tables, limits and features |
| `moonbitstack/moonwgpu/core` | The rules: descriptor validation, usage tracking, command recording, error scopes |
| `moonbitstack/moonwgpu/hal` | The contract a host implements: create, write, read, submit |
| `moonbitstack/moonwgpu/hal/memory` | A host that keeps everything in memory and executes every copy and clear for real |

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
| Mapping a buffer for read-back | done |
| Query sets, timestamps, occlusion queries | recorded and validated |
| Limits, features and their dependencies | the specification's full tables |
| Texture and vertex format tables | every format the specification defines |
| Executing a shader | needs a WGSL front end, which is its own library |
| Surfaces and canvases | a host's question; the contract is `hal` |

## Install and targets

All four targets build and test: `wasm`, `wasm-gc`, `js`, `native`. Nothing is
native-only, and nothing is a stub: a backend that cannot do something says so
through `HalError` instead of returning a value that looks like success.

## Licence

Apache-2.0. See [LICENSE](LICENSE).
