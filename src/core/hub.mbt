// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The device state: every resource it has made, the limits it was created
/// with, and the one place that talks to the backend.
///
/// The specification keeps this in the device object; a MoonBit struct with a
/// trait object in it does the same job, and lets `Instance` and `Device` be
/// thin handles a caller can copy freely.
pub struct Hub {
  backend : &@hal.Hal
  limits : @types.Limits
  features : @types.Features
  buffers : Map[UInt64, BufferState]
  textures : Map[UInt64, TextureState]
  views : Map[UInt64, ViewState]
  samplers : Map[UInt64, SamplerState]
  shader_modules : Map[UInt64, ShaderModuleState]
  bind_group_layouts : Map[UInt64, BindGroupLayoutState]
  bind_groups : Map[UInt64, BindGroupState]
  pipeline_layouts : Map[UInt64, PipelineLayoutState]
  render_pipelines : Map[UInt64, @types.RenderPipelineDescriptor]
  compute_pipelines : Map[UInt64, @types.ComputePipelineDescriptor]
  query_sets : Map[UInt64, @types.QuerySetDescriptor]
  external_textures : Map[UInt64, ExternalTextureState]
  mut lost : Bool
  scopes : Array[ErrorScope]
  uncaptured : Array[Refused]
  mut handler : ((Refused) -> Unit)?
}

///|
/// One `pushErrorScope`: the filter it was pushed with and what it collected.
pub struct ErrorScope {
  filter : @types.ErrorFilter
  errors : Array[Refused]
}

///|
/// Push an error scope. Errors the device generates itself - an allocation the
/// host could not make, or a backend that fails - are collected here; errors
/// about the caller's descriptors are raised instead, because this library runs
/// the device timeline in the caller's thread and a raised error carries the
/// same information at the same point.
/// https://www.w3.org/TR/webgpu/#dom-gpudevice-pusherrorscope
pub fn Hub::push_error_scope(self : Hub, filter : @types.ErrorFilter) -> Unit {
  self.scopes.push({ filter, errors: [], })
}

///|
/// Pop the innermost scope, handing back what it collected.
/// https://www.w3.org/TR/webgpu/#dom-gpudevice-poperrorscope
pub fn Hub::pop_error_scope(self : Hub) -> Array[Refused] raise Refused {
  if self.scopes.is_empty() {
    raise invalid(
      @types.InvalidPassState,
      "popErrorScope",
      "a scope that was pushed",
      "an empty stack",
    )
  }
  let scope = self.scopes.pop().unwrap()
  // An inner scope's errors are not seen by an outer one, as in the
  // specification: a scope only sees the errors raised while it was on top.
  scope.errors.copy()
}

///|
/// Record an error in the innermost scope that accepts its filter; an error no
/// scope asked for is the device's own and is kept for `uncapturederror`.
fn Hub::report(self : Hub, error : Refused) -> Refused {
  let mut captured = false
  if !self.scopes.is_empty() {
    let scope = self.scopes[self.scopes.length() - 1]
    let matches = match (scope.filter, error) {
      (@types.ErrorFilter::Validation, Validation(..)) => true
      (@types.ErrorFilter::OutOfMemory, OutOfMemory(..)) => true
      (@types.ErrorFilter::Internal, Internal(..)) => true
      _ => false
    }
    if matches {
      scope.errors.push(error)
      captured = true
    }
  }
  if !captured {
    self.uncaptured.push(error)
    match self.handler {
      Some(handler) => handler(error)
      None => ()
    }
  }
  error
}

///|
/// The errors no error scope collected, oldest first.
pub fn Hub::uncaptured_errors(self : Hub) -> Array[Refused] {
  self.uncaptured.copy()
}

///|
/// The handler an uncaptured error is handed to, if one is set.
pub fn Hub::handler(self : Hub) -> ((Refused) -> Unit)? {
  self.handler
}

///|
/// Set, or with `None` clear, the handler an uncaptured error is handed to.
pub fn Hub::set_handler(self : Hub, handler : ((Refused) -> Unit)?) -> Unit {
  self.handler = handler
}

///|
/// Forget the errors kept so far.
pub fn Hub::clear_uncaptured_errors(self : Hub) -> Unit {
  self.uncaptured.clear()
}

///|
/// A hub over one backend, holding the limits and features a device was
/// created with.
pub fn Hub::new(
  backend : &@hal.Hal,
  limits : @types.Limits,
  features : @types.Features,
) -> Hub {
  {
    backend,
    limits,
    features,
    buffers: Map([]),
    textures: Map([]),
    views: Map([]),
    samplers: Map([]),
    shader_modules: Map([]),
    bind_group_layouts: Map([]),
    bind_groups: Map([]),
    pipeline_layouts: Map([]),
    render_pipelines: Map([]),
    compute_pipelines: Map([]),
    query_sets: Map([]),
    external_textures: Map([]),
    lost: false,
    scopes: [],
    uncaptured: [],
    handler: None,
  }
}

///|

///|
/// Refuse everything once the device is gone, the way a lost device does.
pub fn Hub::ensure_alive(self : Hub) -> Unit raise Refused {
  if self.lost {
    raise DeviceLost(reason=@types.DeviceLostReason::Destroyed)
  }
}

///|
/// Mark the device as gone: every later call is refused.
pub fn Hub::lose(self : Hub) -> Unit {
  self.lost = true
}

///|
pub fn Hub::limits(self : Hub) -> @types.Limits {
  self.limits
}

///|
pub fn Hub::features(self : Hub) -> @types.Features {
  self.features
}

///|
/// The backend this hub drives, for the odd caller that needs to name it.
pub fn Hub::backend_name(self : Hub) -> String {
  self.backend.name()
}

///|
/// Look up a buffer the caller still holds.
pub fn Hub::buffer(
  self : Hub,
  id : @types.BufferId,
) -> BufferState raise Refused {
  match self.buffers.get(id.raw()) {
    Some(state) =>
      if state.destroyed {
        raise invalid(
          @types.InvalidResource,
          "buffer",
          "a live buffer",
          "a destroyed buffer",
        )
      } else {
        state
      }
    None =>
      raise invalid(
        @types.InvalidResource,
        "buffer",
        "a buffer of this device",
        id.raw().to_string(),
      )
  }
}

///|
/// Look up a texture the caller still holds.
pub fn Hub::texture(
  self : Hub,
  id : @types.TextureId,
) -> TextureState raise Refused {
  match self.textures.get(id.raw()) {
    Some(state) =>
      if state.destroyed {
        raise invalid(
          @types.InvalidResource,
          "texture",
          "a live texture",
          "a destroyed texture",
        )
      } else {
        state
      }
    None =>
      raise invalid(
        @types.InvalidResource,
        "texture",
        "a texture of this device",
        id.raw().to_string(),
      )
  }
}

///|
pub fn Hub::create_buffer(
  self : Hub,
  descriptor : @types.BufferDescriptor,
) -> @types.BufferId raise Refused {
  self.ensure_alive()
  validate_buffer_descriptor(descriptor, self.limits)
  let id = self.backend.create_buffer(descriptor) catch {
    error => raise self.report(Refused::from_hal(error))
  }
  self.buffers[id.raw()] = { descriptor, destroyed: false, mapped: false, }
  id
}

///|
/// Write into a buffer, checking that it has `copy_dst` and that the range
/// fits. This is `queue.writeBuffer`: the write happens before the next submit.
pub fn Hub::write_buffer(
  self : Hub,
  id : @types.BufferId,
  offset : Int32,
  data : Bytes,
) -> Unit raise Refused {
  self.ensure_alive()
  let state = self.buffer(id)
  require(
    state.descriptor.usage.contains(@types.BufferUsages::copy_dst()),
    @types.InvalidBufferUsage,
    "buffer.usage",
    "COPY_DST",
    describe_usages(state.descriptor.usage.bits(), buffer_usage_names()),
  )
  require_same(0, offset % 4, @types.InvalidAlignment, "bufferOffset")
  require_same(0, data.length() % 4, @types.InvalidAlignment, "data.size")
  require_int(
    offset + data.length() <= state.descriptor.size,
    @types.InvalidCopyRange,
    "bufferOffset + data.size",
    state.descriptor.size,
    offset + data.length(),
  )
  self.backend.write_buffer(id, offset, data) catch {
    error => raise self.report(Refused::from_hal(error))
  }
}

///|
/// Write back what a write mapping was given, when the mapping is dropped.
///
/// This is not `write_buffer`: a buffer mapped for writing carries `MAP_WRITE`
/// and may carry nothing else, so asking for `COPY_DST` here would refuse the
/// only write the buffer was ever meant to take. The range was checked when
/// the mapping was taken; this checks it again against the same buffer, since
/// the mapping outlives any amount of caller code.
pub fn Hub::unmap_write(
  self : Hub,
  id : @types.BufferId,
  offset : Int32,
  data : Bytes,
) -> Unit raise Refused {
  self.ensure_alive()
  let state = self.buffer(id)
  require_int(
    offset >= 0 && offset + data.length() <= state.descriptor.size,
    @types.InvalidCopyRange,
    "mapped offset + size",
    state.descriptor.size,
    offset + data.length(),
  )
  self.backend.write_buffer(id, offset, data) catch {
    error => raise self.report(Refused::from_hal(error))
  }
}

///|
/// Read back `size` bytes at `offset`. The caller has checked that the buffer
/// is mapped for reading; this is the native form of `getMappedRange`.
pub fn Hub::read_buffer(
  self : Hub,
  id : @types.BufferId,
  offset : Int32,
  size : Int32,
) -> Bytes raise Refused {
  self.ensure_alive()
  let state = self.buffer(id)
  require_int(
    offset >= 0 && offset + size <= state.descriptor.size,
    @types.InvalidCopyRange,
    "mapOffset + mapSize",
    state.descriptor.size,
    offset + size,
  )
  self.backend.read_buffer(id, offset, size) catch {
    error => raise self.report(Refused::from_hal(error))
  }
}

///|
pub fn Hub::create_texture(
  self : Hub,
  descriptor : @types.TextureDescriptor,
) -> @types.TextureId raise Refused {
  self.ensure_alive()
  validate_texture_descriptor(descriptor, self.limits, self.features)
  let id = self.backend.create_texture(descriptor) catch {
    error => raise self.report(Refused::from_hal(error))
  }
  self.textures[id.raw()] = { descriptor, destroyed: false, }
  id
}

///|
pub fn Hub::create_texture_view(
  self : Hub,
  texture : @types.TextureId,
  descriptor : @types.TextureViewDescriptor,
) -> @types.TextureViewId raise Refused {
  self.ensure_alive()
  let state = self.texture(texture)
  validate_texture_view_descriptor(state.descriptor, descriptor, self.features)
  let id = self.backend.create_texture_view(texture, descriptor) catch {
    error => raise self.report(Refused::from_hal(error))
  }
  let format = match descriptor.format {
    Some(format) => format
    None => resolve_aspect_format(state.descriptor.format, descriptor.aspect)
  }
  let dimension = match descriptor.dimension {
    Some(dimension) => dimension
    None =>
      match state.descriptor.dimension {
        @types.TextureDimension::D1 => @types.TextureViewDimension::D1
        @types.TextureDimension::D3 => @types.TextureViewDimension::D3
        @types.TextureDimension::D2 =>
          if state.descriptor.size.depth_or_array_layers == 1 {
            @types.TextureViewDimension::D2
          } else {
            @types.TextureViewDimension::D2Array
          }
      }
  }
  let mip_level_count = match descriptor.mip_level_count {
    Some(count) => count
    None => state.descriptor.mip_level_count - descriptor.base_mip_level
  }
  let array_layer_count = match descriptor.array_layer_count {
    Some(count) => count
    None =>
      array_layer_count_of_texture(state.descriptor) -
      descriptor.base_array_layer
  }
  self.views[id.raw()] = {
    texture,
    format,
    dimension,
    aspect: descriptor.aspect,
    mip_level_count,
    array_layer_count,
    destroyed: false,
  }
  id
}

///|
pub fn Hub::create_sampler(
  self : Hub,
  descriptor : @types.SamplerDescriptor,
) -> @types.SamplerId raise Refused {
  self.ensure_alive()
  validate_sampler_descriptor(descriptor)
  let id = self.backend.create_sampler(descriptor) catch {
    error => raise self.report(Refused::from_hal(error))
  }
  let filtering = descriptor.mag_filter == @types.FilterMode::Linear ||
    descriptor.min_filter == @types.FilterMode::Linear ||
    descriptor.mipmap_filter == @types.FilterMode::Linear
  let comparison = match descriptor.compare {
    Some(_) => true
    None => false
  }
  self.samplers[id.raw()] = { descriptor, filtering, comparison, }
  id
}

///|
pub fn Hub::create_shader_module(
  self : Hub,
  descriptor : @types.ShaderModuleDescriptor,
) -> @types.ShaderModuleId raise Refused {
  self.ensure_alive()
  match descriptor.code {
    @types.Wgsl(text) =>
      require(
        !text.is_empty(),
        @types.InvalidShaderModule,
        "descriptor.code",
        "a non-empty module",
        "an empty string",
      )
    @types.SpirV(words) => {
      require(
        words.length() >= 4,
        @types.InvalidShaderModule,
        "descriptor.code",
        "at least one SPIR-V word",
        "fewer than four bytes",
      )
      require_int(
        words.length() % 4 == 0,
        @types.InvalidShaderModule,
        "descriptor.code",
        0,
        words.length() % 4,
      )
      let magic = words[0].to_int() |
        (words[1].to_int() << 8) |
        (words[2].to_int() << 16) |
        (words[3].to_int() << 24)
      require_int(
        magic == 0x07230203,
        @types.InvalidShaderModule,
        "descriptor.code, first word",
        0x07230203,
        magic,
      )
    }
  }
  let id = self.backend.create_shader_module(descriptor) catch {
    error => raise self.report(Refused::from_hal(error))
  }
  self.shader_modules[id.raw()] = { descriptor, }
  id
}

///|
/// `getCompilationInfo`: what the backend's compiler said about a module.
///
/// A backend without a compiler reports no message, which the trait documents;
/// the module is then only as good as the caller's own checking.
/// https://www.w3.org/TR/webgpu/#dom-gpushadermodule-getcompilationinfo
pub fn Hub::compilation_info(
  self : Hub,
  id : @types.ShaderModuleId,
) -> @types.CompilationInfo raise Refused {
  self.ensure_alive()
  self.require_shader(id)
  { messages: self.backend.compilation_info(id), }
}

///|
pub fn Hub::create_bind_group_layout(
  self : Hub,
  descriptor : @types.BindGroupLayoutDescriptor,
) -> @types.BindGroupLayoutId raise Refused {
  self.ensure_alive()
  validate_bind_group_layout_descriptor(descriptor, self.limits)
  let id = self.backend.create_bind_group_layout(descriptor) catch {
    error => raise self.report(Refused::from_hal(error))
  }
  self.bind_group_layouts[id.raw()] = { descriptor, }
  id
}

///|
pub fn Hub::create_pipeline_layout(
  self : Hub,
  descriptor : @types.PipelineLayoutDescriptor,
) -> @types.PipelineLayoutId raise Refused {
  self.ensure_alive()
  validate_pipeline_layout_descriptor(descriptor, self.limits)
  for layout in descriptor.bind_group_layouts {
    require(
      self.bind_group_layouts.get(layout.raw()) is Some(_),
      @types.InvalidPipelineLayout,
      "descriptor.bindGroupLayouts",
      "layouts of this device",
      layout.raw().to_string(),
    )
  }
  let id = self.backend.create_pipeline_layout(descriptor) catch {
    error => raise self.report(Refused::from_hal(error))
  }
  self.pipeline_layouts[id.raw()] = { descriptor, }
  id
}

///|
pub fn Hub::create_bind_group(
  self : Hub,
  descriptor : @types.BindGroupDescriptor,
) -> @types.BindGroupId raise Refused {
  self.ensure_alive()
  let layout = match self.bind_group_layouts.get(descriptor.layout.raw()) {
    Some(layout) => layout
    None =>
      raise invalid(
        @types.InvalidResource,
        "descriptor.layout",
        "a layout of this device",
        descriptor.layout.raw().to_string(),
      )
  }
  validate_bind_group_descriptor(
    descriptor,
    layout,
    self.buffers,
    self.views,
    self.textures,
    self.samplers,
    self.limits,
  )
  let id = self.backend.create_bind_group(descriptor) catch {
    error => raise self.report(Refused::from_hal(error))
  }
  self.bind_groups[id.raw()] = { layout: descriptor.layout, descriptor, }
  id
}

///|
pub fn Hub::create_render_pipeline(
  self : Hub,
  descriptor : @types.RenderPipelineDescriptor,
) -> @types.RenderPipelineId raise Refused {
  self.ensure_alive()
  validate_render_pipeline_descriptor(descriptor, self.limits)
  self.require_shader(descriptor.vertex.shader)
  match descriptor.fragment {
    Some(fragment) => self.require_shader(fragment.shader)
    None => ()
  }
  match descriptor.layout {
    Some(layout) => self.require_pipeline_layout(layout)
    None => ()
  }
  let id = self.backend.create_render_pipeline(descriptor) catch {
    error => raise self.report(Refused::from_hal(error))
  }
  self.render_pipelines[id.raw()] = descriptor
  id
}

///|
pub fn Hub::create_compute_pipeline(
  self : Hub,
  descriptor : @types.ComputePipelineDescriptor,
) -> @types.ComputePipelineId raise Refused {
  self.ensure_alive()
  validate_compute_pipeline_descriptor(descriptor, self.limits)
  self.require_shader(descriptor.shader)
  match descriptor.layout {
    Some(layout) => self.require_pipeline_layout(layout)
    None => ()
  }
  let id = self.backend.create_compute_pipeline(descriptor) catch {
    error => raise self.report(Refused::from_hal(error))
  }
  self.compute_pipelines[id.raw()] = descriptor
  id
}

///|
pub fn Hub::create_query_set(
  self : Hub,
  descriptor : @types.QuerySetDescriptor,
) -> @types.QuerySetId raise Refused {
  self.ensure_alive()
  require_int(
    descriptor.count > 0,
    @types.InvalidResource,
    "descriptor.count",
    1,
    descriptor.count,
  )
  if descriptor.kind == @types.QueryType::Timestamp {
    require(
      self.features.contains(@types.TimestampQuery),
      @types.MissingFeature,
      "descriptor.type",
      "timestamp-query",
      "feature disabled",
    )
  }
  let id = self.backend.create_query_set(descriptor) catch {
    error => raise self.report(Refused::from_hal(error))
  }
  self.query_sets[id.raw()] = descriptor
  id
}

///|
fn Hub::require_shader(
  self : Hub,
  id : @types.ShaderModuleId,
) -> Unit raise Refused {
  require(
    self.shader_modules.get(id.raw()) is Some(_),
    @types.InvalidResource,
    "shader",
    "a shader module of this device",
    id.raw().to_string(),
  )
}

///|
fn Hub::require_pipeline_layout(
  self : Hub,
  id : @types.PipelineLayoutId,
) -> Unit raise Refused {
  require(
    self.pipeline_layouts.get(id.raw()) is Some(_),
    @types.InvalidResource,
    "layout",
    "a pipeline layout of this device",
    id.raw().to_string(),
  )
}

///|
pub fn Hub::destroy_buffer(self : Hub, id : @types.BufferId) -> Unit {
  match self.buffers.get(id.raw()) {
    Some(state) => {
      state.destroyed = true
      self.backend.destroy_buffer(id)
    }
    None => ()
  }
}

///|
pub fn Hub::destroy_texture(self : Hub, id : @types.TextureId) -> Unit {
  match self.textures.get(id.raw()) {
    Some(state) => {
      state.destroyed = true
      self.backend.destroy_texture(id)
    }
    None => ()
  }
}

///|
/// A bind group layout this device made.
pub fn Hub::bind_group_layout(
  self : Hub,
  id : @types.BindGroupLayoutId,
) -> BindGroupLayoutState raise Refused {
  match self.bind_group_layouts.get(id.raw()) {
    Some(state) => state
    None =>
      raise invalid(
        @types.InvalidResource,
        "layout",
        "a bind group layout of this device",
        id.raw().to_string(),
      )
  }
}

///|
/// A pipeline layout this device made.
pub fn Hub::pipeline_layout(
  self : Hub,
  id : @types.PipelineLayoutId,
) -> PipelineLayoutState raise Refused {
  match self.pipeline_layouts.get(id.raw()) {
    Some(state) => state
    None =>
      raise invalid(
        @types.InvalidResource,
        "layout",
        "a pipeline layout of this device",
        id.raw().to_string(),
      )
  }
}

///|
/// The explicit layout a render pipeline was built with, if it had one.
pub fn Hub::render_pipeline_layout(
  self : Hub,
  id : @types.RenderPipelineId,
) -> @types.PipelineLayoutId? raise Refused {
  match self.render_pipelines.get(id.raw()) {
    Some(descriptor) => descriptor.layout
    None =>
      raise invalid(
        @types.InvalidResource,
        "pipeline",
        "a render pipeline of this device",
        id.raw().to_string(),
      )
  }
}

///|
/// The explicit layout a compute pipeline was built with, if it had one.
pub fn Hub::compute_pipeline_layout(
  self : Hub,
  id : @types.ComputePipelineId,
) -> @types.PipelineLayoutId? raise Refused {
  match self.compute_pipelines.get(id.raw()) {
    Some(descriptor) => descriptor.layout
    None =>
      raise invalid(
        @types.InvalidResource,
        "pipeline",
        "a compute pipeline of this device",
        id.raw().to_string(),
      )
  }
}

///|
/// Forget a query set.
pub fn Hub::destroy_query_set(self : Hub, id : @types.QuerySetId) -> Unit {
  self.query_sets.remove(id.raw()) |> ignore
}
