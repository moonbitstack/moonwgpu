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

## The specification

Three documents describe what this library is supposed to be, and this
repository names all three rather than paraphrasing them:

| Document | What it is | What it decides here |
|:--|:--|:--|
| [WebGPU](https://www.w3.org/TR/webgpu/) | the W3C text, on the Recommendation track | the normative one: every validation rule in `core` follows a step in it, and a rule that exists here and there is implemented as written there |
| [WebGPU draft](https://gpuweb.github.io/gpuweb/) | the editor's copy, the text the TR is built from | the source the rules were read out of, and the place a change appears before it is published; where the two differ, the TR is what is implemented |
| [WGSL](https://www.w3.org/TR/WGSL/) | the shading language | not here: parsing and executing WGSL belong to [moonnaga](https://github.com/moonbitstack/moonnaga), and this library keeps only the seam a compiled module arrives through |

The draft is checked out as a submodule at `spec/`, pinned to
`gpuweb/gpuweb@d178d91` — the revision whose paragraphs the rules were
transcribed from — so a comment like "the row pitch is a multiple of 256" can be
traced to the sentence that says so. The draft and the TR carry the same text;
what the pin adds is a date, so a reader a year from now reads the paragraph the
code was written against rather than whatever the editor has added since:

```bash
git submodule update --init --depth 1 spec     # about 4 MB, working tree only
```

The source is Bikeshed, and it is one file per document: `spec/spec/index.bs`
holds the whole WebGPU text — eighteen thousand lines, the IDL inline with the
prose around it — and `spec/wgsl/index.bs` the WGSL one. Update the pin
deliberately: a new revision may add a rule that the validators have not learned
yet.

The reference implementations are read, not vendored: [wgpu](https://github.com/gfx-rs/wgpu)
for the layering this library follows (`types` below the API, `hal` below that)
and [Dawn](https://dawn.googlesource.com/dawn) for what a conformance run
actually asserts. Local checkouts of either belong in `.ref/`, which git
ignores.

The conformance suite is imported the same way. It is TypeScript driving
`navigator.gpu`, so the part of it that can run against this library is the part
that asks questions rather than draws pictures: `conformance/` holds a generated
index of every case the suite declares and a ledger of the rules this library
mirrors, file by file, with the tests that assert them. Both directions are
checked, so a case renamed upstream and a claim whose test disappeared are both
build failures. The `js` backend can be driven from JavaScript as well, through
a small WebGPU-shaped facade — see [Backends](#backends). Details in
[conformance/README.md](conformance/README.md).

Both pins move on the first and the fifteenth of the month:
`.github/workflows/refresh.yml` walks `spec` and `cts` to upstream head,
regenerates the index, and opens a pull request with whatever moved.

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
| The same suite on `wasm`, `wasm-gc`, `js` and `native` | 187 tests on each, recorded in `conformance/targets.json` |
| Driving the `js` backend from JavaScript | `src/bindings/js` plus a WebGPU-shaped facade in `conformance/js` |
| Executing a shader | needs a WGSL front end, which is its own library (`moonnaga`); a module that arrives as SPIR-V runs today |
| Vulkan | real: instance, device, buffers, textures, pipelines, descriptor sets, dynamic render passes, compute, read-back |
| Metal, D3D12 and GLES | packaged and named; each refuses with its reason until its stub exists |
## Vulkan

`hal/vulkan` is the first backend that runs on a device. It is a MoonBit
implementation of the same contract the memory backend implements, with one C
file underneath it: `src/hal/vulkan/stub.c` is the only place a Vulkan call is
made, it opens the loader at run time, and it links against nothing. Where the
Vulkan headers are absent the file still compiles, and the backend reports that
the loader cannot be reached instead of failing to build.

```bash
moon run src/examples/05-device --target native
```

```
device:  llvmpipe (LLVM 21.1.8, 256 bits)
clear:   4x4 read back as 51,102,153,255
triangle: 512 of 4096 pixels in the triangle's colour
compute: 1024 of 1024 words read back as 2n+1
```

To build it you need the Vulkan development headers and a driver: on Debian and
Ubuntu, `libvulkan-dev` and `mesa-vulkan-drivers`. The loader is opened with
`dlopen`/`LoadLibrary`, so nothing is linked at build time and no SDK is needed
to check the package.

| Piece | How it is here |
|:--|:--|
| Instance, device, queue | one `VkInstance` and one `VkDevice` per backend, the first device the loader reports |
| Buffers | host-visible and coherent, mapped once at creation |
| Textures, views, samplers | `VK_IMAGE_TILING_OPTIMAL`, with the usage bits the descriptor asks for |
| Pipelines | built for dynamic rendering (`VkPipelineRenderingCreateInfo`), so a pass is a `vkCmdBeginRendering` and the pipeline needs no render pass object |
| Bind groups | one descriptor set per group, at the set index the bind names |
| Subresource layouts | tracked by the backend, one per mip level, and every use is a barrier from what it was to what it now is |
| Read-back | a staging buffer and a copy on the same queue, for `read_texture`, `write_texture` and the examples |
| Immediates | Vulkan push constants, in one 128-byte range on every pipeline layout |
| Shaders | SPIR-V, which is what `ShaderModuleDescriptor::spirv` takes; a WGSL module is created with an error a caller can read, and a pipeline built on it refuses |

The shaders the examples and the tests use are compiled from the GLSL in
`scripts/shaders` by `scripts/build_shaders.py`, which writes the words into
`src/shaders/modules.mbt`. That is where the wrapper's shader compiler will plug
in: the same words, from WGSL instead of GLSL.

Two things this backend does not do yet. A draw that samples a texture reads
zero on the software driver it was developed against, although the image holds
its texels and the descriptor is bound; the four ways bytes move — clear,
vertex, compute, transfer — are exact, and the sampling path is the open one. A
surface needs a window system, so `Surface` is still the windowing layer's job
and a native canvas arrives with it.

## Backends

One source tree, four backends, one suite. `conformance/targets.json` is the
record of what each backend actually ran, and `scripts/targets.py --check`
keeps it honest in CI:

```bash
python3 scripts/targets.py           # run the suite on all four, write the file
python3 scripts/targets.py --check   # fail if a backend lost a test
```

| Backend | How the suite runs there | What can call into it |
|:--|:--|:--|
| `native` | `moon test --target native`, in the caller's thread over the memory backend | MoonBit |
| `wasm` | `moon test --target wasm`, under a wasm runtime | MoonBit |
| `wasm-gc` | `moon test --target wasm-gc`, likewise | MoonBit |
| `js` | `moon test --target js`, and from JavaScript: `src/bindings/js` | JavaScript |

The last row is the one a conformance suite needs. `src/bindings/js` is built
for `--target js` only and publishes three functions on `globalThis` —
`ask(op, …) -> Int`, `text(op, …) -> String`, `take(op, …) -> Bytes` — and
`conformance/js/webgpu.mjs` wraps them in the objects, promises and error
classes the specification defines:

```bash
moon build --target js
node conformance/js/run.mjs    # a dozen cases, in the shape the suite writes them
```

What that buys is the error model a suite is written against: a call that the
library refuses returns an invalid object, and the error arrives later from
`popErrorScope`. The bridge is `Device::report_error`, which records a raised
refusal in the innermost scope that accepts its filter.

What it does not buy, and no facade could: a case that compares pixels needs a
rasterizer, and a case that runs a shader needs a WGSL compiler. The memory
backend moves bytes and keeps no framebuffer; `moonnaga` is the shader
question. Encoding also stays on the MoonBit side for now — the facade creates,
writes, maps and destroys, and hands `submit` only the empty array it can prove.

The other two backends cannot be called from JavaScript at all, and that is a
property of the toolchain rather than of this library: a `wasm` or `wasm-gc`
artifact exports `_start` and nothing else — no functions, no memory — and
neither backend accepts `extern "js"`, so a host has no way in. What they can be
driven by is the suite itself running inside them, which is what the ledger
above asserts; `native` is in the same position from JavaScript's side, since it
has no stable ABI to reach through.


## Licence

Apache-2.0. See [LICENSE](LICENSE).
