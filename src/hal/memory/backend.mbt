// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A buffer as this backend keeps it: its descriptor, its bytes, and whether
/// it has been destroyed.
pub struct BufferRecord {
  descriptor : @types.BufferDescriptor
  data : Array[Byte]
  mut destroyed : Bool
}

///|
/// A texture as this backend keeps it: its descriptor and one tightly packed
/// array of bytes per mip level, all array layers one after another.
pub struct TextureRecord {
  descriptor : @types.TextureDescriptor
  levels : Array[Array[Byte]]
  mut destroyed : Bool
}

///|
/// The texture formats and limits a `Backend` was built with.
pub(all) struct Capabilities {
  limits : @types.Limits
  features : @types.Features
}

///|
/// A backend that holds everything in memory.
///
/// Pipelines, layouts and shader modules are stored as they were described;
/// nothing is compiled, because this backend has no shader compiler. What it
/// does execute is every command that moves bytes: clears and the four copies,
/// which is what makes the read-back path testable without a GPU.
pub struct Backend {
  limits : @types.Limits
  features : @types.Features
  buffers : Map[UInt64, BufferRecord]
  textures : Map[UInt64, TextureRecord]
  views : Map[UInt64, @types.TextureViewId]
  samplers : Map[UInt64, @types.SamplerDescriptor]
  shader_modules : Map[UInt64, @types.ShaderModuleDescriptor]
  bind_group_layouts : Map[UInt64, @types.BindGroupLayoutDescriptor]
  bind_groups : Map[UInt64, @types.BindGroupDescriptor]
  pipeline_layouts : Map[UInt64, @types.PipelineLayoutDescriptor]
  render_pipelines : Map[UInt64, @types.RenderPipelineDescriptor]
  compute_pipelines : Map[UInt64, @types.ComputePipelineDescriptor]
  query_sets : Map[UInt64, @types.QuerySetDescriptor]
  external_textures : Map[UInt64, @types.ExternalTextureDescriptor]
  submitted : Array[Array[@types.Command]]
  mut next_id : UInt64
}

///|
/// A backend offering the limits and features every WebGPU implementation must
/// offer, and nothing optional.
pub fn Backend::new() -> Backend {
  Backend::with_capabilities({
    limits: @types.Limits::webgpu(),
    features: @types.Features::none(),
  })
}

///|
/// A backend that advertises the given limits and features, so that a test can
/// exercise the paths an adapter with those capabilities would take.
pub fn Backend::with_capabilities(capabilities : Capabilities) -> Backend {
  {
    limits: capabilities.limits,
    features: capabilities.features,
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
    submitted: [],
    next_id: 1UL,
  }
}

///|
/// Hand out the next identity. One counter serves every kind of object; the
/// types keep them apart at the call site.
fn Backend::allocate(self : Backend) -> UInt64 {
  let id = self.next_id
  self.next_id = self.next_id + 1UL
  id
}

///|
/// The command batches this backend has executed, oldest first.
pub fn Backend::submitted(self : Backend) -> Array[Array[@types.Command]] {
  self.submitted
}

///|
/// The bytes of one buffer, for a test that wants to look at them without
/// going through a mapping.
pub fn Backend::buffer_bytes(
  self : Backend,
  id : @types.BufferId,
) -> Array[Byte] raise @hal.HalError {
  match self.buffers.get(id.raw()) {
    Some(record) => record.data
    None => raise @hal.HalError::missing("buffer \{id.raw()}")
  }
}

///|
/// The bytes of one mip level of one texture, packed row by row.
pub fn Backend::texture_bytes(
  self : Backend,
  id : @types.TextureId,
  mip_level~ : Int32 = 0,
) -> Array[Byte] raise @hal.HalError {
  match self.textures.get(id.raw()) {
    Some(record) =>
      if mip_level < 0 || mip_level >= record.levels.length() {
        raise @hal.HalError::missing("mip \{mip_level} of texture \{id.raw()}")
      } else {
        record.levels[mip_level]
      }
    None => raise @hal.HalError::missing("texture \{id.raw()}")
  }
}

///|
/// How many bytes one row of `width` texels occupies, with no padding.
fn row_bytes(format : @types.TextureFormat, width : Int32) -> Int32 {
  let info = format.info()
  let blocks = (width + info.block_width - 1) / info.block_width
  blocks * info.bytes_per_block
}

///|
/// How many bytes one mip level of a texture occupies, all layers included.
fn level_bytes(
  format : @types.TextureFormat,
  width : Int32,
  height : Int32,
  layers : Int32,
) -> Int32 {
  let info = format.info()
  let rows = (height + info.block_height - 1) / info.block_height
  row_bytes(format, width) * rows * layers
}

///|
/// A fresh buffer of `size` zero bytes.
fn make_buffer(descriptor : @types.BufferDescriptor) -> BufferRecord {
  { descriptor, data: Array::make(descriptor.size, b'\x00'), destroyed: false, }
}

///|
/// A fresh texture: every mip level allocated and zeroed.
fn make_texture(descriptor : @types.TextureDescriptor) -> TextureRecord {
  let levels = []
  for mip in 0..<descriptor.mip_level_count {
    let size = descriptor.size.physical_size(
      mip_level=mip,
      format=descriptor.format,
    )
    levels.push(
      Array::make(
        level_bytes(
          descriptor.format,
          size.width,
          size.height,
          size.depth_or_array_layers,
        ),
        b'\x00',
      ),
    )
  }
  { descriptor, levels, destroyed: false, }
}

///|
pub impl @hal.Hal for Backend with fn name(_self) {
  "memory"
}

///|
pub impl @hal.Hal for Backend with fn limits(self) {
  self.limits
}

///|
pub impl @hal.Hal for Backend with fn features(self) {
  self.features
}

///|
pub impl @hal.Hal for Backend with fn create_buffer(self, descriptor) -> @types.BufferId raise @hal.HalError {
  let id = self.allocate()
  self.buffers[id] = make_buffer(descriptor)
  @types.BufferId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn destroy_buffer(self, id) {
  match self.buffers.get(id.raw()) {
    Some(record) => record.destroyed = true
    None => ()
  }
}

///|
pub impl @hal.Hal for Backend with fn write_buffer(self, id, offset, data) -> Unit raise @hal.HalError {
  match self.buffers.get(id.raw()) {
    None => raise @hal.HalError::missing("buffer \{id.raw()}")
    Some(record) => {
      let end = offset + data.length()
      if offset < 0 || end > record.data.length() {
        raise @hal.HalError::failed(
          "write of \{data.length()} bytes at \{offset}",
        )
      }
      for i in 0..<data.length() {
        record.data[offset + i] = data[i]
      }
    }
  }
}

///|
pub impl @hal.Hal for Backend with fn read_buffer(self, id, offset, size) -> Bytes raise @hal.HalError {
  match self.buffers.get(id.raw()) {
    None => raise @hal.HalError::missing("buffer \{id.raw()}")
    Some(record) => {
      if offset < 0 || offset + size > record.data.length() {
        raise @hal.HalError::failed("read of \{size} bytes at \{offset}")
      }
      Bytes::from_array(record.data[offset:offset + size])
    }
  }
}

///|
pub impl @hal.Hal for Backend with fn create_texture(self, descriptor) -> @types.TextureId raise @hal.HalError {
  let id = self.allocate()
  self.textures[id] = make_texture(descriptor)
  @types.TextureId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn destroy_texture(self, id) {
  match self.textures.get(id.raw()) {
    Some(record) => record.destroyed = true
    None => ()
  }
}

///|
pub impl @hal.Hal for Backend with fn create_texture_view(
  self,
  texture,
  descriptor,
) -> @types.TextureViewId raise @hal.HalError {
  if self.textures.get(texture.raw()) is None {
    raise @hal.HalError::missing("texture \{texture.raw()}")
  }
  let id = self.allocate()
  self.views[id] = @types.TextureViewId::from_raw(id)
  ignore(descriptor)
  @types.TextureViewId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_sampler(self, descriptor) -> @types.SamplerId raise @hal.HalError {
  let id = self.allocate()
  self.samplers[id] = descriptor
  @types.SamplerId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_shader_module(self, descriptor) -> @types.ShaderModuleId raise @hal.HalError {
  let id = self.allocate()
  self.shader_modules[id] = descriptor
  @types.ShaderModuleId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_bind_group_layout(self, descriptor) -> @types.BindGroupLayoutId raise @hal.HalError {
  let id = self.allocate()
  self.bind_group_layouts[id] = descriptor
  @types.BindGroupLayoutId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_bind_group(self, descriptor) -> @types.BindGroupId raise @hal.HalError {
  let id = self.allocate()
  self.bind_groups[id] = descriptor
  @types.BindGroupId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_pipeline_layout(self, descriptor) -> @types.PipelineLayoutId raise @hal.HalError {
  let id = self.allocate()
  self.pipeline_layouts[id] = descriptor
  @types.PipelineLayoutId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_render_pipeline(self, descriptor) -> @types.RenderPipelineId raise @hal.HalError {
  let id = self.allocate()
  self.render_pipelines[id] = descriptor
  @types.RenderPipelineId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_compute_pipeline(self, descriptor) -> @types.ComputePipelineId raise @hal.HalError {
  let id = self.allocate()
  self.compute_pipelines[id] = descriptor
  @types.ComputePipelineId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn create_query_set(self, descriptor) -> @types.QuerySetId raise @hal.HalError {
  let id = self.allocate()
  self.query_sets[id] = descriptor
  @types.QuerySetId::from_raw(id)
}

///|
/// This backend has no shader compiler, so it has nothing to say about a
/// module. A backend that compiles WGSL reports its diagnostics here.
pub impl @hal.Hal for Backend with fn compilation_info(self, id) -> Array[
  @types.CompilationMessage,
] {
  ignore(self)
  ignore(id)
  []
}

///|
pub impl @hal.Hal for Backend with fn create_external_texture(self, descriptor) -> @types.ExternalTextureId raise @hal.HalError {
  let id = self.allocate()
  self.external_textures[id] = descriptor
  @types.ExternalTextureId::from_raw(id)
}

///|
pub impl @hal.Hal for Backend with fn destroy_external_texture(self, id) {
  self.external_textures.remove(id.raw()) |> ignore
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
  match self.textures.get(id.raw()) {
    None => raise @hal.HalError::missing("texture \{id.raw()}")
    Some(record) => write_texels(record, origin, extent, mip_level, data)
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
  match self.textures.get(id.raw()) {
    None => raise @hal.HalError::missing("texture \{id.raw()}")
    Some(record) =>
      Bytes::from_array(read_texels(record, origin, extent, mip_level))
  }
}
