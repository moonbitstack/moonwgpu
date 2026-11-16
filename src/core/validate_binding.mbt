// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The rules one `GPUBindGroupLayoutEntry` must satisfy.
/// https://www.w3.org/TR/webgpu/#bind-group-layout-creation
fn validate_bind_group_layout_entry(
  entry : @types.BindGroupLayoutEntry,
  limits : @types.Limits,
) -> Unit raise Refused {
  require_int(
    entry.binding >= 0 && entry.binding < limits.max_bindings_per_bind_group,
    @types.InvalidBindGroupLayout,
    "descriptor.entries.binding",
    limits.max_bindings_per_bind_group - 1,
    entry.binding,
  )
  require(
    !entry.visibility.is_empty(),
    @types.InvalidBindGroupLayout,
    "descriptor.entries.visibility",
    "at least one stage",
    "none",
  )
  match entry.kind {
    Buffer(layout) => {
      let maximum = match layout.kind {
        Uniform => limits.max_uniform_buffer_binding_size
        Storage | ReadOnlyStorage => limits.max_storage_buffer_binding_size
      }
      match layout.min_binding_size {
        Some(size) => {
          require_int(
            size > 0,
            @types.InvalidBindGroupLayout,
            "descriptor.entries.buffer.minBindingSize",
            1,
            size,
          )
          require_int(
            size <= maximum,
            @types.LimitExceeded,
            "descriptor.entries.buffer.minBindingSize",
            maximum,
            size,
          )
        }
        None => ()
      }
    }
    Sampler(_) => ()
    Texture(layout) => {
      if layout.sample_type == @types.SampleType::Depth {
        require(
          layout.view_dimension == @types.TextureViewDimension::D2 ||
          layout.view_dimension == @types.TextureViewDimension::D2Array ||
          layout.view_dimension == @types.TextureViewDimension::Cube ||
          layout.view_dimension == @types.TextureViewDimension::CubeArray,
          @types.InvalidBindGroupLayout,
          "descriptor.entries.texture.viewDimension",
          "2d, 2d-array, cube or cube-array for a depth sample type",
          "another dimension",
        )
      }
      if layout.multisampled {
        require(
          layout.view_dimension == @types.TextureViewDimension::D2,
          @types.InvalidBindGroupLayout,
          "descriptor.entries.texture.viewDimension",
          "2d for a multisampled binding",
          "another dimension",
        )
      }
    }
    StorageTexture(layout) => {
      let info = layout.format.info()
      let supported = match layout.access {
        WriteOnly =>
          info.storage == @types.StorageAccess::WriteOnly ||
          info.storage == @types.StorageAccess::Both
        ReadOnly =>
          info.storage == @types.StorageAccess::ReadOnly ||
          info.storage == @types.StorageAccess::Both
        ReadWrite => info.storage == @types.StorageAccess::Both
      }
      require(
        supported,
        @types.InvalidBindGroupLayout,
        "descriptor.entries.storageTexture.format",
        "a format with that storage access",
        layout.format.name(),
      )
    }
  }
  match entry.count {
    Some(count) =>
      require_int(
        count >= 1,
        @types.InvalidBindGroupLayout,
        "descriptor.entries.count",
        1,
        count,
      )
    None => ()
  }
}

///|
/// The rules a whole bind group layout must satisfy.
pub fn validate_bind_group_layout_descriptor(
  descriptor : @types.BindGroupLayoutDescriptor,
  limits : @types.Limits,
) -> Unit raise Refused {
  let seen = Map([])
  for entry in descriptor.entries {
    validate_bind_group_layout_entry(entry, limits)
    require(
      seen.get(entry.binding) is None,
      @types.InvalidBindGroupLayout,
      "descriptor.entries.binding",
      "a binding index used once",
      entry.binding.to_string(),
    )
    seen[entry.binding] = true
  }
}

///|
/// The rules a pipeline layout must satisfy.
pub fn validate_pipeline_layout_descriptor(
  descriptor : @types.PipelineLayoutDescriptor,
  limits : @types.Limits,
) -> Unit raise Refused {
  require_int(
    descriptor.bind_group_layouts.length() <= limits.max_bind_groups,
    @types.LimitExceeded,
    "descriptor.bindGroupLayouts",
    limits.max_bind_groups,
    descriptor.bind_group_layouts.length(),
  )
}

///|
/// The rules a bind group must satisfy against its layout.
/// https://www.w3.org/TR/webgpu/#bind-group-creation
pub fn validate_bind_group_descriptor(
  descriptor : @types.BindGroupDescriptor,
  layout : BindGroupLayoutState,
  buffers : Map[UInt64, BufferState],
  views : Map[UInt64, ViewState],
  textures : Map[UInt64, TextureState],
  samplers : Map[UInt64, SamplerState],
  limits : @types.Limits,
) -> Unit raise Refused {
  let declared = Map([])
  for entry in layout.descriptor.entries {
    declared[entry.binding] = entry
  }
  let supplied = Map([])
  for entry in descriptor.entries {
    require(
      supplied.get(entry.binding) is None,
      @types.InvalidBindGroup,
      "descriptor.entries.binding",
      "a binding index used once",
      entry.binding.to_string(),
    )
    supplied[entry.binding] = true
    let wanted = match declared.get(entry.binding) {
      Some(wanted) => wanted
      None =>
        raise invalid(
          @types.InvalidBindGroup,
          "descriptor.entries.binding",
          "a binding the layout declares",
          entry.binding.to_string(),
        )
    }
    match (wanted.kind, entry.resource) {
      (Buffer(layout), Buffer(binding)) =>
        validate_buffer_binding(binding, layout, buffers, limits)
      (Sampler(layout), Sampler(id)) =>
        validate_sampler_binding(id, layout, samplers)
      (Texture(layout), TextureView(id)) =>
        validate_texture_binding(id, layout, views, textures)
      (StorageTexture(layout), TextureView(id)) =>
        validate_storage_texture_binding(id, layout, views, textures)
      _ =>
        raise invalid(
          @types.InvalidBindGroup,
          "descriptor.entries.resource",
          "the resource kind the layout declares",
          "another kind",
        )
    }
  }
  // Every binding the layout declares has to be supplied.
  for entry in layout.descriptor.entries {
    require(
      supplied.get(entry.binding) is Some(_),
      @types.InvalidBindGroup,
      "descriptor.entries.binding",
      "an entry for every binding of the layout",
      entry.binding.to_string(),
    )
  }
}

///|
/// One buffer binding against one layout entry.
fn validate_buffer_binding(
  binding : @types.BufferBinding,
  layout : @types.BufferBindingLayout,
  buffers : Map[UInt64, BufferState],
  limits : @types.Limits,
) -> Unit raise Refused {
  let state = match buffers.get(binding.buffer.raw()) {
    Some(state) => state
    None =>
      raise invalid(
        @types.InvalidResource,
        "descriptor.entries.resource.buffer",
        "a live buffer",
        binding.buffer.raw().to_string(),
      )
  }
  require(
    !state.destroyed,
    @types.InvalidResource,
    "descriptor.entries.resource.buffer",
    "a live buffer",
    "a destroyed buffer",
  )
  let (alignment, usage, maximum) = match layout.kind {
    Uniform =>
      (
        limits.min_uniform_buffer_offset_alignment,
        @types.BufferUsages::uniform(),
        limits.max_uniform_buffer_binding_size,
      )
    Storage =>
      (
        limits.min_storage_buffer_offset_alignment,
        @types.BufferUsages::storage(),
        limits.max_storage_buffer_binding_size,
      )
    ReadOnlyStorage =>
      (
        limits.min_storage_buffer_offset_alignment,
        @types.BufferUsages::storage(),
        limits.max_storage_buffer_binding_size,
      )
  }
  require_same(
    0,
    binding.offset % alignment,
    @types.InvalidAlignment,
    "descriptor.entries.resource.offset",
  )
  require(
    state.descriptor.usage.contains(usage),
    @types.InvalidBufferUsage,
    "descriptor.entries.resource.buffer",
    "a buffer with the layout's usage",
    describe_usages(state.descriptor.usage.bits(), buffer_usage_names()),
  )
  let size = match binding.size {
    Some(size) => size
    None => state.descriptor.size - binding.offset
  }
  require_int(
    size >= 0,
    @types.InvalidCopyRange,
    "descriptor.entries.resource.size",
    0,
    size,
  )
  require_int(
    binding.offset + size <= state.descriptor.size,
    @types.InvalidCopyRange,
    "descriptor.entries.resource.offset + size",
    state.descriptor.size,
    binding.offset + size,
  )
  require_int(
    size <= maximum,
    @types.LimitExceeded,
    "descriptor.entries.resource.size",
    maximum,
    size,
  )
  match layout.min_binding_size {
    Some(minimum) =>
      require_int(
        size >= minimum,
        @types.InvalidBindGroup,
        "descriptor.entries.resource.size",
        minimum,
        size,
      )
    None => ()
  }
}

///|
/// One sampler binding against one layout entry.
fn validate_sampler_binding(
  id : @types.SamplerId,
  layout : @types.SamplerBindingLayout,
  samplers : Map[UInt64, SamplerState],
) -> Unit raise Refused {
  let state = match samplers.get(id.raw()) {
    Some(state) => state
    None =>
      raise invalid(
        @types.InvalidResource,
        "descriptor.entries.resource",
        "a live sampler",
        id.raw().to_string(),
      )
  }
  match layout.kind {
    @types.SamplerBindingType::Filtering =>
      require(
        state.filtering,
        @types.InvalidBindGroup,
        "descriptor.entries.resource",
        "a filtering sampler",
        "a non-filtering sampler",
      )
    @types.SamplerBindingType::NonFiltering =>
      require(
        !state.filtering,
        @types.InvalidBindGroup,
        "descriptor.entries.resource",
        "a non-filtering sampler",
        "a filtering sampler",
      )
    @types.SamplerBindingType::Comparison =>
      require(
        state.comparison,
        @types.InvalidBindGroup,
        "descriptor.entries.resource",
        "a comparison sampler",
        "a sampler without a compare function",
      )
  }
}

///|
/// One sampled texture binding against one layout entry.
fn validate_texture_binding(
  id : @types.TextureViewId,
  layout : @types.TextureBindingLayout,
  views : Map[UInt64, ViewState],
  textures : Map[UInt64, TextureState],
) -> Unit raise Refused {
  let view = match views.get(id.raw()) {
    Some(view) => view
    None =>
      raise invalid(
        @types.InvalidResource,
        "descriptor.entries.resource",
        "a live texture view",
        id.raw().to_string(),
      )
  }
  let texture = match textures.get(view.texture.raw()) {
    Some(texture) => texture
    None =>
      raise invalid(
        @types.InvalidResource,
        "descriptor.entries.resource",
        "a view of a live texture",
        view.texture.raw().to_string(),
      )
  }
  require(
    texture.descriptor.usage.contains(@types.TextureUsages::texture_binding()),
    @types.InvalidTextureUsage,
    "descriptor.entries.resource",
    "a texture with TEXTURE_BINDING",
    describe_usages(texture.descriptor.usage.bits(), texture_usage_names()),
  )
  let sample_type = view.format.info().sample_type
  let compatible = match layout.sample_type {
    @types.SampleType::Float => sample_type == @types.SampleType::Float
    @types.SampleType::UnfilterableFloat =>
      sample_type == @types.SampleType::Float ||
      sample_type == @types.SampleType::UnfilterableFloat
    @types.SampleType::Uint => sample_type == @types.SampleType::Uint
    @types.SampleType::Sint => sample_type == @types.SampleType::Sint
    @types.SampleType::Depth => sample_type == @types.SampleType::Depth
  }
  require(
    compatible,
    @types.InvalidBindGroup,
    "descriptor.entries.resource",
    "a view whose sample type the layout declares",
    view.format.name(),
  )
  require(
    view.dimension == layout.view_dimension,
    @types.InvalidBindGroup,
    "descriptor.entries.resource",
    "the layout's view dimension",
    "another dimension",
  )
  require(
    (texture.descriptor.sample_count > 1) == layout.multisampled,
    @types.InvalidBindGroup,
    "descriptor.entries.resource",
    "a texture whose sample count matches multisampled",
    texture.descriptor.sample_count.to_string(),
  )
}

///|
/// One storage texture binding against one layout entry.
fn validate_storage_texture_binding(
  id : @types.TextureViewId,
  layout : @types.StorageTextureBindingLayout,
  views : Map[UInt64, ViewState],
  textures : Map[UInt64, TextureState],
) -> Unit raise Refused {
  let view = match views.get(id.raw()) {
    Some(view) => view
    None =>
      raise invalid(
        @types.InvalidResource,
        "descriptor.entries.resource",
        "a live texture view",
        id.raw().to_string(),
      )
  }
  let texture = match textures.get(view.texture.raw()) {
    Some(texture) => texture
    None =>
      raise invalid(
        @types.InvalidResource,
        "descriptor.entries.resource",
        "a view of a live texture",
        view.texture.raw().to_string(),
      )
  }
  require(
    texture.descriptor.usage.contains(@types.TextureUsages::storage_binding()),
    @types.InvalidTextureUsage,
    "descriptor.entries.resource",
    "a texture with STORAGE_BINDING",
    describe_usages(texture.descriptor.usage.bits(), texture_usage_names()),
  )
  require(
    view.format == layout.format,
    @types.InvalidBindGroup,
    "descriptor.entries.resource",
    layout.format.name(),
    view.format.name(),
  )
  require(
    view.dimension == layout.view_dimension,
    @types.InvalidBindGroup,
    "descriptor.entries.resource",
    "the layout's view dimension",
    "another dimension",
  )
  let info = view.format.info()
  let supported = match layout.access {
    @types.StorageTextureAccess::WriteOnly =>
      info.storage == @types.StorageAccess::WriteOnly ||
      info.storage == @types.StorageAccess::Both
    @types.StorageTextureAccess::ReadOnly =>
      info.storage == @types.StorageAccess::ReadOnly ||
      info.storage == @types.StorageAccess::Both
    @types.StorageTextureAccess::ReadWrite =>
      info.storage == @types.StorageAccess::Both
  }
  require(
    supported,
    @types.InvalidBindGroup,
    "descriptor.entries.resource",
    "a format with that storage access",
    view.format.name(),
  )
}
