# moonwgpu

The WebGPU API, as the specification writes it.

> **Status: planned.** The repository is set up; nothing is
> implemented yet.

One surface, two hosts: in a browser it is the platform's own WebGPU, and on
native it is a backend underneath the same names. Code written against it does
not ask which one it got.

| Package | What it covers |
|:--|:--|
| `adapter` | Requesting an adapter and a device, and what each says it can do |
| `buffer` | Buffers and textures: allocation, mapping, and moving bytes across |
| `shader` | Shader modules and the pipelines built from them |
| `pass` | Command encoders, render passes and compute passes |

The reference is [the WebGPU specification](https://www.w3.org/TR/webgpu/) and
[WGSL](https://www.w3.org/TR/WGSL/) — not any one implementation of it. Where a
host cannot do what the specification asks, that is reported, not papered over.

## What is deliberately elsewhere

Tensors and computation graphs are [`moonggml`](https://github.com/moonbitstack/moonggml)'s.
This library hands out a device and takes commands; what to compute is not its
question.

## Install

```bash
moon add moonbitstack/moonwgpu
```

## Licence

Apache-2.0. See [LICENSE](LICENSE).
