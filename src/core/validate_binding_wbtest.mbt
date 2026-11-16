// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The binding rules: what one layout entry declares, and whether a group's
// resources match it.

///|
test "a layout entry's binding index is below maxBindingsPerBindGroup" {
  let entry = @types.BindGroupLayoutEntry::new(
    binding=1000,
    visibility=@types.ShaderStages::fragment(),
    kind=@types.BindingLayout::Sampler(@types.SamplerBindingLayout::new()),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_bind_group_layout_descriptor(
        @types.BindGroupLayoutDescriptor::new(entries=[entry]),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidBindGroupLayout),
  )
}

///|
test "two entries cannot share a binding index" {
  let entry = @types.BindGroupLayoutEntry::new(
    binding=0,
    visibility=@types.ShaderStages::fragment(),
    kind=@types.BindingLayout::Sampler(@types.SamplerBindingLayout::new()),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_bind_group_layout_descriptor(
        @types.BindGroupLayoutDescriptor::new(entries=[entry, entry]),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidBindGroupLayout),
  )
}

///|
test "an entry needs at least one visible stage" {
  let entry = @types.BindGroupLayoutEntry::new(
    binding=0,
    visibility=@types.ShaderStages::none(),
    kind=@types.BindingLayout::Sampler(@types.SamplerBindingLayout::new()),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_bind_group_layout_descriptor(
        @types.BindGroupLayoutDescriptor::new(entries=[entry]),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidBindGroupLayout),
  )
}

///|
test "a depth sample type is not available to a one dimensional view" {
  let entry = @types.BindGroupLayoutEntry::new(
    binding=0,
    visibility=@types.ShaderStages::fragment(),
    kind=@types.BindingLayout::Texture(
      @types.TextureBindingLayout::new(
        sample_type=@types.SampleType::Depth,
        view_dimension=@types.TextureViewDimension::D1,
      ),
    ),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_bind_group_layout_descriptor(
        @types.BindGroupLayoutDescriptor::new(entries=[entry]),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidBindGroupLayout),
  )
}

///|
test "a multisampled binding is two dimensional" {
  let entry = @types.BindGroupLayoutEntry::new(
    binding=0,
    visibility=@types.ShaderStages::fragment(),
    kind=@types.BindingLayout::Texture(
      @types.TextureBindingLayout::new(
        view_dimension=@types.TextureViewDimension::Cube,
        multisampled=true,
      ),
    ),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_bind_group_layout_descriptor(
        @types.BindGroupLayoutDescriptor::new(entries=[entry]),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidBindGroupLayout),
  )
}

///|
test "a storage texture needs a format with that access" {
  let entry = @types.BindGroupLayoutEntry::new(
    binding=0,
    visibility=@types.ShaderStages::compute(),
    kind=@types.BindingLayout::StorageTexture(
      @types.StorageTextureBindingLayout::new(
        format=@types.TextureFormat::Rgba8unormSrgb,
      ),
    ),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_bind_group_layout_descriptor(
        @types.BindGroupLayoutDescriptor::new(entries=[entry]),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidBindGroupLayout),
  )
}

///|
test "a bind group would need every binding the layout declares" {
  let layout : BindGroupLayoutState = {
    descriptor: @types.BindGroupLayoutDescriptor::new(entries=[
      @types.BindGroupLayoutEntry::new(
        binding=0,
        visibility=@types.ShaderStages::compute(),
        kind=@types.BindingLayout::Buffer(
          @types.BufferBindingLayout::new(
            kind=@types.BufferBindingType::Storage,
          ),
        ),
      ),
    ]),
  }
  let group = @types.BindGroupDescriptor::new(
    layout=@types.BindGroupLayoutId::from_raw(1UL),
    entries=[],
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_bind_group_descriptor(
        group,
        layout,
        Map([]),
        Map([]),
        Map([]),
        Map([]),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidBindGroup),
  )
}

///|
test "a buffer binding has to be aligned to the offset alignment" {
  let layout : BindGroupLayoutState = {
    descriptor: @types.BindGroupLayoutDescriptor::new(entries=[
      @types.BindGroupLayoutEntry::new(
        binding=0,
        visibility=@types.ShaderStages::compute(),
        kind=@types.BindingLayout::Buffer(
          @types.BufferBindingLayout::new(
            kind=@types.BufferBindingType::Uniform,
          ),
        ),
      ),
    ]),
  }
  let buffers = Map([])
  buffers[1UL] = buffer_state(1024, @types.BufferUsages::uniform())
  let group = @types.BindGroupDescriptor::new(
    layout=@types.BindGroupLayoutId::from_raw(1UL),
    entries=[
      @types.BindGroupEntry::new(
        binding=0,
        resource=@types.BindingResource::Buffer(
          @types.BufferBinding::new(
            buffer=@types.BufferId::from_raw(1UL),
            offset=8,
          ),
        ),
      ),
    ],
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_bind_group_descriptor(
        group,
        layout,
        buffers,
        Map([]),
        Map([]),
        Map([]),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidAlignment),
  )
  // The same binding at 256 is fine.
  let aligned = @types.BindGroupDescriptor::new(
    layout=@types.BindGroupLayoutId::from_raw(1UL),
    entries=[
      @types.BindGroupEntry::new(
        binding=0,
        resource=@types.BindingResource::Buffer(
          @types.BufferBinding::new(
            buffer=@types.BufferId::from_raw(1UL),
            offset=256,
          ),
        ),
      ),
    ],
  )
  assert_true(
    kind_of(fn() raise Refused {
      validate_bind_group_descriptor(
        aligned,
        layout,
        buffers,
        Map([]),
        Map([]),
        Map([]),
        webgpu_limits,
      )
    })
    is None,
  )
}

///|
test "a bind group binding is refused when the buffer lacks the usage" {
  let layout : BindGroupLayoutState = {
    descriptor: @types.BindGroupLayoutDescriptor::new(entries=[
      @types.BindGroupLayoutEntry::new(
        binding=0,
        visibility=@types.ShaderStages::compute(),
        kind=@types.BindingLayout::Buffer(
          @types.BufferBindingLayout::new(
            kind=@types.BufferBindingType::Storage,
          ),
        ),
      ),
    ]),
  }
  let buffers = Map([])
  buffers[1UL] = buffer_state(256, @types.BufferUsages::uniform())
  let group = @types.BindGroupDescriptor::new(
    layout=@types.BindGroupLayoutId::from_raw(1UL),
    entries=[
      @types.BindGroupEntry::new(
        binding=0,
        resource=@types.BindingResource::Buffer(
          @types.BufferBinding::new(buffer=@types.BufferId::from_raw(1UL)),
        ),
      ),
    ],
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_bind_group_descriptor(
        group,
        layout,
        buffers,
        Map([]),
        Map([]),
        Map([]),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidBufferUsage),
  )
}
