// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A compute pass: a storage buffer, a bind group and a dispatch, recorded and
/// submitted.
///
/// The dispatch itself is recorded rather than executed: running a compute
/// shader needs a WGSL front end, which is its own library. What the example
/// proves is that the storage binding, the pipeline layout and the dispatch
/// survive validation.
///
///     moon run src/examples/04-compute
#coverage.skip
fn main raise {
  let backend = @memory.Backend::new()
  let device = @moonwgpu.Instance::new(backend~)
    .request_adapter()
    .request_device()
  let shader = device.create_shader_module(
    descriptor=@types.ShaderModuleDescriptor::wgsl(
      label="fill",
      source="// a compute stage writing to a storage buffer\n",
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
            min_binding_size=256,
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
      entry_point="cs_main",
      layout=pipeline_layout.id(),
      label="fill pipeline",
    ),
  )
  let storage = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=256,
      usage=@types.BufferUsages::storage() | @types.BufferUsages::copy_src(),
      label="storage buffer",
    ),
  )
  let bind_group = device.create_bind_group(
    descriptor=@types.BindGroupDescriptor::new(layout=layout.id(), entries=[
      @types.BindGroupEntry::new(
        binding=0,
        resource=@types.BindingResource::Buffer(
          @types.BufferBinding::new(buffer=storage.id(), size=256),
        ),
      ),
    ]),
  )
  let encoder = device.create_command_encoder(label="compute")
  let pass = encoder.begin_compute_pass(
    descriptor=@types.ComputePassDescriptor::new(label="fill pass"),
  )
  pass.set_pipeline(pipeline~)
  pass.set_bind_group(index=0, bind_group~)
  pass.dispatch_workgroups(
    arguments=@types.DispatchArguments::new(x=16, y=1, z=1),
  )
  pass.end()
  let command_buffer = encoder.finish()
  device.queue().submit(command_buffers=[command_buffer])
  println("pipeline:       \{pipeline.label()}")
  println("bindings:       \{layout.descriptor().entries.length()}")
  println("commands:       \{command_buffer.commands.length()}")
  println("submissions:    \{backend.submitted().length()}")
}
