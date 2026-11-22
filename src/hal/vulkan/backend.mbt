// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A buffer as this backend holds it.
pub struct BufferRecord {
  handle : Int64
  descriptor : @types.BufferDescriptor
  mut destroyed : Bool
}

///|
/// A texture as this backend holds it, with the layout of each mip level.
///
/// The layout is the one piece of state Vulkan requires a caller to keep: a
/// barrier may only name the layout the subresource is already in, and a wrong
/// answer is undefined behaviour rather than an error the driver reports. So it
/// is kept here, next to the descriptor, and every transition goes through
/// `transition`.
pub struct TextureRecord {
  handle : Int64
  descriptor : @types.TextureDescriptor
  format : Int64
  layouts : Array[Int32]
  mut destroyed : Bool
}

///|
pub struct ViewRecord {
  handle : Int64
  texture : UInt64
  format : Int64
  descriptor : @types.TextureViewDescriptor
}

///|
pub struct SetLayoutRecord {
  handle : Int64
  descriptor : @types.BindGroupLayoutDescriptor
}

///|
pub struct SetRecord {
  handle : Int64
  layout : UInt64
  descriptor : @types.BindGroupDescriptor
}

///|
pub struct PipelineLayoutRecord {
  handle : Int64
  descriptor : @types.PipelineLayoutDescriptor
}

///|
pub struct PipelineRecord {
  handle : Int64
  label : String
  compute : Bool
}

///|
/// A shader module. A module written in WGSL arrives here without a Vulkan
/// module, because compiling WGSL is the shader compiler's job and this
/// backend has none; the messages say so, and a pipeline built on it refuses.
pub struct ShaderRecord {
  handle : Int64
  descriptor : @types.ShaderModuleDescriptor
  messages : Array[@types.CompilationMessage]
}

///|
pub struct QueryRecord {
  handle : Int64
  descriptor : @types.QuerySetDescriptor
}

///|
/// The Vulkan backend.
///
/// One `VkInstance` and one `VkDevice` per `Backend`, created on the first
/// adapter the loader reports. Every object the layer above makes has a record
/// here: the Vulkan handle, the descriptor it came from, and — for a texture —
/// the layout of each subresource.
pub struct Backend {
  mut instance : Int64
  mut device : Int64
  device_name : String
  driver_version : Int64
  api_version : Int64
  dynamic_rendering : Bool
  samplers_anisotropic : Bool
  reason : String
  buffers : Map[UInt64, BufferRecord]
  textures : Map[UInt64, TextureRecord]
  views : Map[UInt64, ViewRecord]
  samplers : Map[UInt64, Int64]
  shaders : Map[UInt64, ShaderRecord]
  set_layouts : Map[UInt64, SetLayoutRecord]
  sets : Map[UInt64, SetRecord]
  pipeline_layouts : Map[UInt64, PipelineLayoutRecord]
  pipelines : Map[UInt64, PipelineRecord]
  queries : Map[UInt64, QueryRecord]
  submissions : Array[Int32]
  mut next_id : UInt64
}

///|
/// Open the backend: the loader, the first device it reports, and the command
/// pool every submission goes through.
///
/// A machine without a Vulkan loader, without a device, or without dynamic
/// rendering gets a backend that says so and refuses every call, rather than a
/// panic at the first draw.
pub fn open() -> Backend {
  let backend = {
    instance: 0L,
    device: 0L,
    device_name: "",
    driver_version: 0L,
    api_version: 0L,
    dynamic_rendering: false,
    samplers_anisotropic: false,
    reason: "",
    buffers: Map([]),
    textures: Map([]),
    views: Map([]),
    samplers: Map([]),
    shaders: Map([]),
    set_layouts: Map([]),
    sets: Map([]),
    pipeline_layouts: Map([]),
    pipelines: Map([]),
    queries: Map([]),
    submissions: [],
    next_id: 1UL,
  }
  if vk_available() == 0 {
    return { ..backend, reason: "vulkan: \{last_error()}", }
  }
  let instance = vk_instance_create()
  if instance == 0L {
    return { ..backend, reason: "vulkan: \{last_error()}", }
  }
  if vk_device_count(instance) == 0 {
    vk_instance_destroy(instance)
    return {
      ..backend,
      reason: "vulkan: the loader reports no physical device",
    }
  }
  let info = FixedArray::make(512, b'\x00')
  let length = vk_physical_info(instance, 0, info).to_int()
  let name = if length > 0 {
    let bytes = FixedArray::make(length, b'\x00')
    for i in 0..<length {
      bytes[i] = info[i]
    }
    @utf8.decode_lossy(Bytes::from_array(bytes)[:])
  } else {
    ""
  }
  let numbers = FixedArray::make(4, 0L)
  for i in 0..<4 {
    let mut value = 0L
    for byte in 0..<8 {
      let shift = (byte * 8).to_int()
      value = value | (info[256 + i * 8 + byte].to_int64() << shift)
    }
    numbers[i] = value
  }
  let report = FixedArray::make(32, 0L)
  let device = vk_device_create(instance, 0, report)
  if device == 0L {
    let reason = last_error()
    vk_instance_destroy(instance)
    return { ..backend, reason: "vulkan: \{reason}", }
  }
  {
    ..backend,
    instance,
    device,
    device_name: name,
    driver_version: numbers[1],
    api_version: numbers[0],
    dynamic_rendering: report[0] != 0L,
    samplers_anisotropic: report[1] != 0L,
  }
}

///|
/// Whether this backend can do anything at all.
pub fn Backend::available(self : Backend) -> Bool {
  self.device != 0L
}

///|
/// Why it cannot, in the words of whoever opened it.
pub fn Backend::reason(self : Backend) -> String {
  if self.reason.is_empty() && !self.available() {
    "vulkan: the backend was never opened"
  } else {
    self.reason
  }
}

///|
/// The name the driver gave the device, as in `"llvmpipe (LLVM 21.1.8, 256
/// bits)"`.
pub fn Backend::device_name(self : Backend) -> String {
  self.device_name
}

///|
/// The API version the driver reports, as `major << 22 | minor << 12 | patch`.
pub fn Backend::api_version(self : Backend) -> Int64 {
  self.api_version
}

///|
/// The driver version, whose meaning the vendor decides.
pub fn Backend::driver_version(self : Backend) -> Int64 {
  self.driver_version
}

///|
/// Release everything this backend made, then the device and the instance.
///
/// A WebGPU object has no destructor of its own beyond `destroy`, so this is
/// where a test's resources go when it is finished with them.
pub fn Backend::close(self : Backend) -> Unit {
  if self.device != 0L {
    ignore(vk_device_wait(self.device))
    for _, record in self.pipelines {
      vk_pipeline_destroy(record.handle)
    }
    for _, record in self.sets {
      vk_set_destroy(record.handle)
    }
    for _, record in self.pipeline_layouts {
      vk_pipeline_layout_destroy(record.handle)
    }
    for _, record in self.set_layouts {
      vk_set_layout_destroy(record.handle)
    }
    for _, record in self.shaders {
      if record.handle != 0L {
        vk_shader_destroy(record.handle)
      }
    }
    for _, handle in self.samplers {
      vk_sampler_destroy(handle)
    }
    for _, record in self.views {
      vk_view_destroy(record.handle)
    }
    for _, record in self.textures {
      if !record.destroyed {
        vk_texture_destroy(record.handle)
      }
    }
    for _, record in self.buffers {
      if !record.destroyed {
        vk_buffer_destroy(record.handle)
      }
    }
    for _, record in self.queries {
      vk_queries_destroy(record.handle)
    }
    vk_device_destroy(self.device)
    self.device = 0L
  }
  if self.instance != 0L {
    vk_instance_destroy(self.instance)
    self.instance = 0L
  }
}

///|
/// How many submissions this backend has completed. A test that asks whether a
/// command buffer reached the device asks this.
pub fn Backend::submissions(self : Backend) -> Int32 {
  self.submissions.length()
}

///|
fn Backend::allocate(self : Backend) -> UInt64 {
  let id = self.next_id
  self.next_id = self.next_id + 1UL
  id
}

///|
/// The record of a texture, or a refusal naming the identity.
fn Backend::texture(
  self : Backend,
  id : @types.TextureId,
) -> TextureRecord raise @hal.HalError {
  match self.textures.get(id.raw()) {
    Some(record) => record
    None => raise @hal.HalError::missing("texture \{id.raw()}")
  }
}

///|
fn Backend::buffer(
  self : Backend,
  id : @types.BufferId,
) -> BufferRecord raise @hal.HalError {
  match self.buffers.get(id.raw()) {
    Some(record) => record
    None => raise @hal.HalError::missing("buffer \{id.raw()}")
  }
}

///|
fn Backend::view(
  self : Backend,
  id : @types.TextureViewId,
) -> ViewRecord raise @hal.HalError {
  match self.views.get(id.raw()) {
    Some(record) => record
    None => raise @hal.HalError::missing("texture view \{id.raw()}")
  }
}

///|
/// Move one subresource to `wanted`, if it is not already there.
///
/// The barrier names both layouts and both uses; `use_of_layout` says what the
/// old one was last read by, which is what the source stage has to wait for.
fn Backend::transition(
  self : Backend,
  record : TextureRecord,
  mip : Int32,
  wanted : Int32,
) -> Unit {
  if mip < 0 || mip >= record.layouts.length() {
    return
  }
  let current = record.layouts[mip]
  if current == wanted {
    return
  }
  let layers = record.descriptor.size.depth_or_array_layers
  vk_barrier(
    self.device,
    record.handle,
    mip,
    0,
    layers,
    current,
    wanted,
    use_of_layout(current),
    use_of_layout(wanted),
  )
  record.layouts[mip] = wanted
}

///|
pub impl @hal.Hal for Backend with fn name(self) {
  ignore(self)
  "vulkan"
}

///|
pub impl @hal.Hal for Backend with fn limits(self) {
  ignore(self)
  @types.Limits::webgpu()
}

///|
pub impl @hal.Hal for Backend with fn features(self) {
  ignore(self)
  @types.Features::none()
}

///|
pub impl @hal.Hal for Backend with fn create_buffer(self, descriptor) -> @types.BufferId raise @hal.HalError {
  if !self.available() {
    raise @hal.HalError::unsupported(self.reason())
  }
  let handle = vk_buffer_create(
    self.device,
    descriptor.size,
    descriptor.usage.bits().reinterpret_as_int(),
    1,
  )
  if handle == 0L {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  let id = self.allocate()
  self.buffers[id] = { handle, descriptor, destroyed: false, }
  @types.BufferId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn destroy_buffer(self, id) {
  match self.buffers.get(id.raw()) {
    Some(record) =>
      if !record.destroyed {
        vk_buffer_destroy(record.handle)
        record.destroyed = true
      }
    None => ()
  }
}

///|
pub impl @hal.Hal for Backend with fn write_buffer(self, id, offset, data) -> Unit raise @hal.HalError {
  let record = self.buffer(id)
  if vk_buffer_write(record.handle, offset, data, data.length()) == 0 {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
}

///|
pub impl @hal.Hal for Backend with fn read_buffer(self, id, offset, size) -> Bytes raise @hal.HalError {
  let record = self.buffer(id)
  let dst = FixedArray::make(size, b'\x00')
  if vk_buffer_read(record.handle, offset, dst, size) == 0 {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  Bytes::from_array(dst)
}

///|
pub impl @hal.Hal for Backend with fn create_texture(self, descriptor) -> @types.TextureId raise @hal.HalError {
  if !self.available() {
    raise @hal.HalError::unsupported(self.reason())
  }
  let code = format_code(descriptor.format)
  let size = descriptor.size
  let depth = if descriptor.dimension is @types.TextureDimension::D3 {
    size.depth_or_array_layers
  } else {
    1
  }
  let layers = if descriptor.dimension is @types.TextureDimension::D3 {
    1
  } else {
    size.depth_or_array_layers
  }
  let handle = vk_texture_create(
    self.device,
    size.width,
    size.height,
    depth,
    layers,
    descriptor.mip_level_count,
    descriptor.sample_count,
    texture_dimension(descriptor.dimension),
    code,
    image_usage(descriptor.usage, descriptor.format),
  )
  if handle == 0L {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  let layouts = Array::make(descriptor.mip_level_count, layout_undefined)
  let id = self.allocate()
  self.textures[id] = {
    handle,
    descriptor,
    format: code,
    layouts,
    destroyed: false,
  }
  @types.TextureId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn destroy_texture(self, id) {
  match self.textures.get(id.raw()) {
    Some(record) =>
      if !record.destroyed {
        vk_texture_destroy(record.handle)
        record.destroyed = true
      }
    None => ()
  }
}

///|
pub impl @hal.Hal for Backend with fn create_texture_view(
  self,
  texture,
  descriptor,
) -> @types.TextureViewId raise @hal.HalError {
  let record = self.texture(texture)
  let format = match descriptor.format {
    Some(format) => format_code(format)
    None => record.format
  }
  let dimension = match descriptor.dimension {
    Some(dimension) => view_dimension(dimension)
    None =>
      match record.descriptor.dimension {
        @types.TextureDimension::D1 => 0
        @types.TextureDimension::D3 => 5
        @types.TextureDimension::D2 =>
          if record.descriptor.size.depth_or_array_layers > 1 {
            2
          } else {
            1
          }
      }
  }
  let handle = vk_view_create(
    self.device,
    record.handle,
    format,
    dimension,
    aspect_code(descriptor.aspect),
    descriptor.base_mip_level,
    descriptor.mip_level_count.unwrap_or(0),
    descriptor.base_array_layer,
    descriptor.array_layer_count.unwrap_or(0),
  )
  if handle == 0L {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  let id = self.allocate()
  self.views[id] = { handle, texture: texture.raw(), format, descriptor, }
  @types.TextureViewId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_sampler(self, descriptor) -> @types.SamplerId raise @hal.HalError {
  if !self.available() {
    raise @hal.HalError::unsupported(self.reason())
  }
  let compare_enabled = match descriptor.compare {
    Some(_) => 1
    None => 0
  }
  let compare = match descriptor.compare {
    Some(compare) => compare_code(compare)
    None => 7
  }
  let anisotropy = if self.samplers_anisotropic {
    match descriptor.max_anisotropy {
      n => if n > 1 { n.to_double() } else { 1.0 }
    }
  } else {
    1.0
  }
  let handle = vk_sampler_create(
    self.device,
    filter_code(descriptor.mag_filter),
    filter_code(descriptor.min_filter),
    filter_code(descriptor.mipmap_filter),
    address_code(descriptor.address_mode_u),
    address_code(descriptor.address_mode_v),
    address_code(descriptor.address_mode_w),
    descriptor.lod_min_clamp,
    descriptor.lod_max_clamp,
    compare_enabled,
    compare,
    anisotropy,
  )
  if handle == 0L {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  let id = self.allocate()
  self.samplers[id] = handle
  @types.SamplerId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_shader_module(self, descriptor) -> @types.ShaderModuleId raise @hal.HalError {
  if !self.available() {
    raise @hal.HalError::unsupported(self.reason())
  }
  let id = self.allocate()
  match descriptor.code {
    @types.ShaderSource::SpirV(words) => {
      let handle = vk_shader_create(self.device, words, words.length())
      if handle == 0L {
        let message = last_error()
        self.shaders[id] = {
          handle: 0L,
          descriptor,
          messages: [
            @types.CompilationMessage::new(
              message="\{message}",
              kind=@types.CompilationMessageType::Error,
            ),
          ],
        }
      } else {
        self.shaders[id] = { handle, descriptor, messages: [], }
      }
    }
    @types.ShaderSource::Wgsl(_) =>
      // WGSL is compiled by the shader compiler, which is a library of its own;
      // until it is linked, the module is created the way the specification
      // says — with an error a caller can read — and pipelines refuse it.
      self.shaders[id] = {
        handle: 0L,
        descriptor,
        messages: [
          @types.CompilationMessage::new(
            message="vulkan: this backend takes SPIR-V; WGSL needs the shader compiler, which is not linked",
            kind=@types.CompilationMessageType::Error,
          ),
        ],
      }
  }
  @types.ShaderModuleId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn compilation_info(self, id) -> Array[
  @types.CompilationMessage,
] {
  match self.shaders.get(id.raw()) {
    Some(record) => record.messages
    None => []
  }
}

///|
pub impl @hal.Hal for Backend with fn create_bind_group_layout(self, descriptor) -> @types.BindGroupLayoutId raise @hal.HalError {
  if !self.available() {
    raise @hal.HalError::unsupported(self.reason())
  }
  let entries = FixedArray::make(descriptor.entries.length() * 12, 0)
  let mut at = 0
  for entry in descriptor.entries {
    entries[at] = entry.binding
    entries[at + 1] = stage_code(entry.visibility)
    entries[at + 2] = binding_kind(entry.kind)
    entries[at + 3] = entry.count.unwrap_or(0)
    entries[at + 4] = if is_dynamic(entry.kind) { 1 } else { 0 }
    entries[at + 5] = sample_type_code(entry.kind)
    entries[at + 6] = text_dimension_code(entry.kind)
    entries[at + 7] = multisampled_code(entry.kind)
    entries[at + 8] = storage_access_code(entry.kind)
    at = at + 12
  }
  let handle = vk_set_layout_create(
    self.device,
    entries,
    descriptor.entries.length(),
  )
  if handle == 0L {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  let id = self.allocate()
  self.set_layouts[id] = { handle, descriptor, }
  @types.BindGroupLayoutId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_bind_group(self, descriptor) -> @types.BindGroupId raise @hal.HalError {
  let layout = match self.set_layouts.get(descriptor.layout.raw()) {
    Some(record) => record
    None =>
      raise @hal.HalError::missing(
        "bind group layout \{descriptor.layout.raw()}",
      )
  }
  let handle = vk_set_create(self.device, layout.handle)
  if handle == 0L {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  for entry in descriptor.entries {
    match entry.resource {
      @types.BindingResource::Buffer(binding) => {
        let buffer = self.buffer(binding.buffer)
        let size = binding.size.unwrap_or(0)
        let kind = if self.buffer_binding_kind(layout, entry.binding) == 0 {
          0
        } else {
          1
        }
        if vk_set_buffer(
            handle,
            entry.binding,
            buffer.handle,
            binding.offset,
            size,
            kind,
          ) ==
          0 {
          raise @hal.HalError::failed("vulkan: \{last_error()}")
        }
      }
      @types.BindingResource::Sampler(sampler) => {
        let handle_of = match self.samplers.get(sampler.raw()) {
          Some(handle) => handle
          None => raise @hal.HalError::missing("sampler \{sampler.raw()}")
        }
        if vk_set_sampler(handle, entry.binding, handle_of) == 0 {
          raise @hal.HalError::failed("vulkan: \{last_error()}")
        }
      }
      @types.BindingResource::TextureView(view) => {
        let record = self.view(view)
        let storage = self.buffer_binding_kind(layout, entry.binding) == 8
        if vk_set_texture(
            handle,
            entry.binding,
            record.handle,
            if storage {
              1
            } else {
              0
            },
          ) ==
          0 {
          raise @hal.HalError::failed("vulkan: \{last_error()}")
        }
      }
    }
  }
  let id = self.allocate()
  self.sets[id] = { handle, layout: descriptor.layout.raw(), descriptor, }
  @types.BindGroupId::from_raw(id)
}

///|
/// The kind of one binding, looked up in the layout the group was made from.
fn Backend::buffer_binding_kind(
  self : Backend,
  layout : SetLayoutRecord,
  binding : Int32,
) -> Int32 {
  ignore(self)
  for entry in layout.descriptor.entries {
    if entry.binding == binding {
      return binding_kind(entry.kind)
    }
  }
  0
}

///|
pub impl @hal.Hal for Backend with fn create_pipeline_layout(self, descriptor) -> @types.PipelineLayoutId raise @hal.HalError {
  if !self.available() {
    raise @hal.HalError::unsupported(self.reason())
  }
  let layouts = FixedArray::make(descriptor.bind_group_layouts.length(), 0L)
  for i, id in descriptor.bind_group_layouts {
    let record = match self.set_layouts.get(id.raw()) {
      Some(record) => record
      None => raise @hal.HalError::missing("bind group layout \{id.raw()}")
    }
    layouts[i] = record.handle
  }
  let handle = vk_pipeline_layout_create(
    self.device,
    layouts,
    descriptor.bind_group_layouts.length(),
  )
  if handle == 0L {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  let id = self.allocate()
  self.pipeline_layouts[id] = { handle, descriptor, }
  @types.PipelineLayoutId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_render_pipeline(self, descriptor) -> @types.RenderPipelineId raise @hal.HalError {
  let vertex = self.shader_handle(descriptor.vertex.shader, "vertex")
  let fragment = match descriptor.fragment {
    Some(fragment) => Some(self.shader_handle(fragment.shader, "fragment"))
    None => None
  }
  let fragment = match fragment {
    Some(handle) => handle
    None =>
      raise @hal.HalError::unsupported(
        "vulkan: a render pipeline needs a fragment stage",
      )
  }
  let (layout, _) = self.pipeline_layout_of(descriptor.layout)
  let stream = render_pipeline_stream(descriptor)
  let handle = vk_render_pipeline_create(
    self.device,
    layout,
    vertex,
    @utf8.encode(descriptor.vertex.entry_point),
    descriptor.vertex.entry_point.length(),
    fragment,
    match descriptor.fragment {
      Some(fragment) => @utf8.encode(fragment.entry_point)
      None => b""
    },
    match descriptor.fragment {
      Some(fragment) => fragment.entry_point.length()
      None => 0
    },
    FixedArray::from_array(stream),
    stream.length(),
    match descriptor.depth_stencil {
      Some(state) => state.bias.constant
      None => 0
    },
    match descriptor.depth_stencil {
      Some(state) => state.bias.slope_scale
      None => 0.0
    },
    match descriptor.depth_stencil {
      Some(state) => state.bias.clamp
      None => 0.0
    },
  )
  if handle == 0L {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  let id = self.allocate()
  self.pipelines[id] = { handle, label: descriptor.label, compute: false, }
  @types.RenderPipelineId::from_raw(id)
}

///|
/// The Vulkan module behind a shader, or a refusal that repeats what the
/// compiler said.
fn Backend::shader_handle(
  self : Backend,
  id : @types.ShaderModuleId,
  stage : String,
) -> Int64 raise @hal.HalError {
  let record = match self.shaders.get(id.raw()) {
    Some(record) => record
    None => raise @hal.HalError::missing("shader module \{id.raw()}")
  }
  if record.handle == 0L {
    let message = if record.messages.length() > 0 {
      record.messages[0].message
    } else {
      "vulkan: the shader module has no compiled form"
    }
    raise @hal.HalError::unsupported(
      "vulkan: the \{stage} stage cannot be built: \{message}",
    )
  }
  record.handle
}

///|
/// A pipeline layout, or the one this backend makes for a pipeline that names
/// none: no bind groups, no immediates.
fn Backend::pipeline_layout_of(
  self : Backend,
  id : @types.PipelineLayoutId?,
) -> (Int64, Int32) raise @hal.HalError {
  match id {
    Some(id) =>
      match self.pipeline_layouts.get(id.raw()) {
        Some(record) => (record.handle, 1)
        None => raise @hal.HalError::missing("pipeline layout \{id.raw()}")
      }
    None => {
      let handle = vk_pipeline_layout_create(
        self.device,
        FixedArray::make(0, 0L),
        0,
      )
      if handle == 0L {
        raise @hal.HalError::failed("vulkan: \{last_error()}")
      }
      let id = self.allocate()
      self.pipeline_layouts[id] = {
        handle,
        descriptor: @types.PipelineLayoutDescriptor::new(bind_group_layouts=[]),
      }
      (handle, 0)
    }
  }
}

///|
pub impl @hal.Hal for Backend with fn create_compute_pipeline(self, descriptor) -> @types.ComputePipelineId raise @hal.HalError {
  let shader = self.shader_handle(descriptor.shader, "compute")
  let (layout, _) = self.pipeline_layout_of(descriptor.layout)
  let handle = vk_compute_pipeline_create(
    self.device,
    layout,
    shader,
    @utf8.encode(descriptor.entry_point),
    descriptor.entry_point.length(),
  )
  if handle == 0L {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  let id = self.allocate()
  self.pipelines[id] = { handle, label: descriptor.label, compute: true, }
  @types.ComputePipelineId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_query_set(self, descriptor) -> @types.QuerySetId raise @hal.HalError {
  if !self.available() {
    raise @hal.HalError::unsupported(self.reason())
  }
  let kind = match descriptor.kind {
    @types.QueryType::Occlusion => 0
    @types.QueryType::Timestamp => 1
  }
  let handle = vk_queries_create(self.device, kind, descriptor.count)
  if handle == 0L {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  let id = self.allocate()
  self.queries[id] = { handle, descriptor, }
  @types.QuerySetId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_external_texture(self, descriptor) -> @types.ExternalTextureId raise @hal.HalError {
  ignore(self.device)
  ignore(descriptor)
  raise @hal.HalError::unsupported(
    "vulkan: an external frame needs the platform's importer, which belongs to the windowing layer",
  )
}

///|
pub impl @hal.Hal for Backend with fn destroy_external_texture(self, id) {
  // This backend makes no external texture, so there is nothing to release.
  ignore(self.device)
  ignore(id)
}

///|
pub impl @hal.Hal for Backend with fn write_texture(
  self,
  id,
  origin,
  extent,
  mip_level,
  data,
) -> Unit raise @hal.HalError {
  let record = self.texture(id)
  let bytes = subresource_bytes(
    record.descriptor.format,
    @types.Extent3d::new(
      width=extent.width,
      height=extent.height,
      depth_or_array_layers=extent.depth_or_array_layers,
    ),
  )
  if data.length() < bytes {
    raise @hal.HalError::failed(
      "vulkan: \{data.length()} bytes for a subresource of \{bytes}",
    )
  }
  let current = if mip_level < record.layouts.length() {
    record.layouts[mip_level]
  } else {
    layout_undefined
  }
  if vk_texture_write(
      self.device,
      record.handle,
      mip_level,
      origin.x,
      origin.y,
      origin.z,
      extent.width,
      extent.height,
      extent.depth_or_array_layers,
      current,
      bytes,
      data,
    ) ==
    0 {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  if mip_level < record.layouts.length() {
    record.layouts[mip_level] = layout_transfer_destination
  }
}

///|
pub impl @hal.Hal for Backend with fn read_texture(
  self,
  id,
  origin,
  extent,
  mip_level,
) -> Bytes raise @hal.HalError {
  let record = self.texture(id)
  let size = @types.Extent3d::new(
    width=extent.width,
    height=extent.height,
    depth_or_array_layers=extent.depth_or_array_layers,
  )
  let bytes = subresource_bytes(record.descriptor.format, size)
  let dst = FixedArray::make(bytes, b'\x00')
  let current = if mip_level < record.layouts.length() {
    record.layouts[mip_level]
  } else {
    layout_undefined
  }
  if vk_texture_read(
      self.device,
      record.handle,
      mip_level,
      origin.x,
      origin.y,
      origin.z,
      extent.width,
      extent.height,
      extent.depth_or_array_layers,
      current,
      bytes,
      dst,
    ) ==
    0 {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  if mip_level < record.layouts.length() {
    record.layouts[mip_level] = layout_transfer_source
  }
  Bytes::from_array(dst)
}

///|
/// The contract's own names, lifted so that a caller can ask a `Backend`
/// directly without importing the trait.
#doc(hidden)
pub extend Backend with @hal.Hal::{
  name,
  limits,
  features,
  create_buffer,
  destroy_buffer,
  write_buffer,
  read_buffer,
  create_texture,
  destroy_texture,
  create_texture_view,
  create_sampler,
  create_shader_module,
  compilation_info,
  create_bind_group_layout,
  create_bind_group,
  create_pipeline_layout,
  create_render_pipeline,
  create_compute_pipeline,
  create_query_set,
  create_external_texture,
  destroy_external_texture,
  submit,
  read_texture,
  write_texture,
}

///|
/// Every texel of one mip level, packed row by row.
///
/// The read-back the specification spells as a copy into a mapped buffer; a
/// test or an example that only wants to look at the result asks for it here.
pub fn Backend::texture_bytes(
  self : Backend,
  id : @types.TextureId,
  mip_level~ : Int32 = 0,
) -> Array[Byte] raise @hal.HalError {
  let record = self.texture(id)
  let size = record.descriptor.size.physical_size(
    mip_level~,
    format=record.descriptor.format,
  )
  let extent = @types.Extent3d::new(
    width=size.width,
    height=size.height,
    depth_or_array_layers=size.depth_or_array_layers,
  )
  let bytes = self.read_texture(id, @types.Origin3d::new(), extent, mip_level)
  let out : Array[Byte] = []
  for i in 0..<bytes.length() {
    out.push(bytes[i])
  }
  out
}

///|
/// Every byte of a buffer.
pub fn Backend::buffer_bytes(
  self : Backend,
  id : @types.BufferId,
) -> Array[Byte] raise @hal.HalError {
  let record = self.buffer(id)
  let bytes = self.read_buffer(id, 0, record.descriptor.size)
  let out : Array[Byte] = []
  for i in 0..<bytes.length() {
    out.push(bytes[i])
  }
  out
}
