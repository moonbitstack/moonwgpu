// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The translation from the specification's words to the seam's numbers.
///
/// Two things live here: the name a format goes by, which the seam looks up in
/// its table, and the small enumerations that the C side switches on. Nothing
/// in this file touches a device, so all of it is checked without one.

///|
/// The image layouts this backend tracks, one per subresource. The numbers are
/// the seam's, not Vulkan's: `stub.c` owns the mapping.
let layout_undefined : Int32 = 0

///|
let layout_color_attachment : Int32 = 1

///|
let layout_shader_read : Int32 = 2

///|
let layout_transfer_source : Int32 = 3

///|
let layout_transfer_destination : Int32 = 4

///|
let layout_general : Int32 = 5

///|
let layout_depth_attachment : Int32 = 6

///|
/// The layout a texture must be in before a step reads it that way.
///
/// This is the whole of the transition policy: a sampled texture is read in
/// `shader read`, a storage texture is read and written in `general`, a copy
/// source in `transfer source`, and so on. Every barrier in `record.mbt` is
/// derived from this function and the layout the subresource is already in.
fn wanted_layout(kind : @types.BindingLayout) -> Int32 {
  match kind {
    @types.BindingLayout::Texture(_) => layout_shader_read
    @types.BindingLayout::StorageTexture(descriptor) =>
      match descriptor.access {
        @types.StorageTextureAccess::WriteOnly => layout_general
        @types.StorageTextureAccess::ReadOnly => layout_general
        @types.StorageTextureAccess::ReadWrite => layout_general
      }
    _ => layout_shader_read
  }
}

///|
/// The stage and access a subresource was last used with, which is what the
/// barrier that leaves that layout has to wait for.
fn use_of_layout(layout : Int32) -> Int32 {
  if layout == layout_color_attachment {
    2
  } else if layout == layout_depth_attachment {
    5
  } else if layout == layout_shader_read {
    3
  } else if layout == layout_transfer_source {
    1
  } else if layout == layout_transfer_destination {
    1
  } else if layout == layout_general {
    4
  } else {
    0
  }
}

///|
/// The layout a copy writes into, and the one it reads from.
fn is_depth_only(format : @types.TextureFormat) -> Bool {
  match format {
    @types.TextureFormat::Depth16unorm
    | @types.TextureFormat::Depth24plus
    | @types.TextureFormat::Depth32float => true
    _ => false
  }
}

///|
fn attachment_layout(format : @types.TextureFormat) -> Int32 {
  let info = format.info()
  match info.aspect {
    @types.FormatAspect::Color => layout_color_attachment
    _ => layout_depth_attachment
  }
}

///|
/// A `VkFormat` for a texture format, as the seam's table names it.
fn format_code(format : @types.TextureFormat) -> Int64 raise @hal.HalError {
  let name = format.name()
  let bytes = @utf8.encode(name)
  let code = vk_format(bytes, bytes.length())
  if code == 0 {
    raise @hal.HalError::unsupported(
      "vulkan: the format \{name} has no Vulkan equivalent in this backend",
    )
  }
  code
}

///|
/// A `VkFormat` for a vertex format, from the same table.
fn vertex_code(format : @types.VertexFormat) -> Int64 raise @hal.HalError {
  let name = format.name()
  let bytes = @utf8.encode(name)
  let code = vk_format(bytes, bytes.length())
  if code == 0 {
    raise @hal.HalError::unsupported(
      "vulkan: the vertex format \{name} has no Vulkan equivalent",
    )
  }
  code
}

///|
/// The image usage a texture descriptor asks for, in the seam's bits: 1
/// sampled, 2 storage, 4 colour attachment, 8 depth attachment.
fn texture_usage(usage : @types.TextureUsages) -> Int32 {
  let mut bits = 0
  if usage.contains(@types.TextureUsages::texture_binding()) {
    bits = bits | 1
  }
  if usage.contains(@types.TextureUsages::storage_binding()) {
    bits = bits | 2
  }
  if usage.contains(@types.TextureUsages::render_attachment()) {
    bits = bits | 4
  }
  bits
}

///|
/// The image usage bits, with a depth format's render attachment counted as a
/// depth attachment rather than a colour one.
fn image_usage(
  usage : @types.TextureUsages,
  format : @types.TextureFormat,
) -> Int32 {
  let mut bits = texture_usage(usage)
  if (bits & 4) != 0 && !is_depth_only(format) {
    let info = format.info()
    let is_depth = match info.aspect {
      @types.FormatAspect::Color => false
      _ => true
    }
    if is_depth {
      bits = (bits ^ 4) | 8
    }
  }
  bits
}

///|
/// 0 one dimension, 1 two, 2 three, as the seam reads them.
fn texture_dimension(dimension : @types.TextureDimension) -> Int32 {
  match dimension {
    @types.TextureDimension::D1 => 0
    @types.TextureDimension::D2 => 1
    @types.TextureDimension::D3 => 2
  }
}

///|
/// 0 one dimension, 1 two, 2 two-dimensional array, 3 cube, 4 cube array, 5
/// three-dimensional.
fn view_dimension(dimension : @types.TextureViewDimension) -> Int32 {
  match dimension {
    @types.TextureViewDimension::D1 => 0
    @types.TextureViewDimension::D2 => 1
    @types.TextureViewDimension::D2Array => 2
    @types.TextureViewDimension::Cube => 3
    @types.TextureViewDimension::CubeArray => 4
    @types.TextureViewDimension::D3 => 5
  }
}

///|
/// 0 colour, 1 depth, 2 stencil, 3 both.
fn aspect_code(aspect : @types.TextureAspect) -> Int32 {
  match aspect {
    @types.TextureAspect::All => 3
    @types.TextureAspect::DepthOnly => 1
    @types.TextureAspect::StencilOnly => 2
  }
}

///|
/// 0 clamp to edge, 1 repeat, 2 mirror repeat.
fn address_code(mode : @types.AddressMode) -> Int32 {
  match mode {
    @types.AddressMode::ClampToEdge => 0
    @types.AddressMode::Repeat => 1
    @types.AddressMode::MirrorRepeat => 2
  }
}

///|
/// 0 nearest, 1 linear.
fn filter_code(mode : @types.FilterMode) -> Int32 {
  match mode {
    @types.FilterMode::Nearest => 0
    @types.FilterMode::Linear => 1
  }
}

///|
/// The comparison the seam's switch reads: 0 never … 7 always.
fn compare_code(compare : @types.CompareFunction) -> Int32 {
  match compare {
    @types.CompareFunction::Never => 0
    @types.CompareFunction::Less => 1
    @types.CompareFunction::Equal => 2
    @types.CompareFunction::LessEqual => 3
    @types.CompareFunction::Greater => 4
    @types.CompareFunction::NotEqual => 5
    @types.CompareFunction::GreaterEqual => 6
    @types.CompareFunction::Always => 7
  }
}

///|
fn blend_factor_code(factor : @types.BlendFactor) -> Int32 {
  match factor {
    @types.BlendFactor::Zero => 0
    @types.BlendFactor::One => 1
    @types.BlendFactor::Src => 2
    @types.BlendFactor::OneMinusSrc => 3
    @types.BlendFactor::SrcAlpha => 4
    @types.BlendFactor::OneMinusSrcAlpha => 5
    @types.BlendFactor::Dst => 6
    @types.BlendFactor::OneMinusDst => 7
    @types.BlendFactor::DstAlpha => 8
    @types.BlendFactor::OneMinusDstAlpha => 9
    @types.BlendFactor::SrcAlphaSaturated => 10
    @types.BlendFactor::Constant => 11
    @types.BlendFactor::OneMinusConstant => 12
    @types.BlendFactor::Src1 => 13
    @types.BlendFactor::OneMinusSrc1 => 14
    @types.BlendFactor::Src1Alpha => 15
    @types.BlendFactor::OneMinusSrc1Alpha => 16
  }
}

///|
fn blend_op_code(operation : @types.BlendOperation) -> Int32 {
  match operation {
    @types.BlendOperation::Add => 0
    @types.BlendOperation::Subtract => 1
    @types.BlendOperation::ReverseSubtract => 2
    @types.BlendOperation::Min => 3
    @types.BlendOperation::Max => 4
  }
}

///|
fn stencil_op_code(operation : @types.StencilOperation) -> Int32 {
  match operation {
    @types.StencilOperation::Keep => 0
    @types.StencilOperation::Zero => 1
    @types.StencilOperation::Replace => 2
    @types.StencilOperation::Invert => 3
    @types.StencilOperation::IncrementClamp => 4
    @types.StencilOperation::DecrementClamp => 5
    @types.StencilOperation::IncrementWrap => 6
    @types.StencilOperation::DecrementWrap => 7
  }
}

///|
fn topology_code(topology : @types.PrimitiveTopology) -> Int32 {
  match topology {
    @types.PrimitiveTopology::PointList => 0
    @types.PrimitiveTopology::LineList => 1
    @types.PrimitiveTopology::LineStrip => 2
    @types.PrimitiveTopology::TriangleList => 3
    @types.PrimitiveTopology::TriangleStrip => 4
  }
}

///|
fn step_mode_code(mode : @types.VertexStepMode) -> Int32 {
  match mode {
    @types.VertexStepMode::Vertex => 0
    @types.VertexStepMode::Instance => 1
  }
}

///|
/// The stages a binding is visible to: 1 vertex, 2 fragment, 4 compute.
fn stage_code(stages : @types.ShaderStages) -> Int32 {
  let mut bits = 0
  if stages.contains(@types.ShaderStages::vertex()) {
    bits = bits | 1
  }
  if stages.contains(@types.ShaderStages::fragment()) {
    bits = bits | 2
  }
  if stages.contains(@types.ShaderStages::compute()) {
    bits = bits | 4
  }
  bits
}

///|
/// The kind of a descriptor binding, as the seam's switch reads it: 0 uniform
/// buffer, 1 storage buffer, 2 read-only storage buffer, 3 filtering sampler,
/// 4 non-filtering sampler, 5 comparison sampler, 6 sampled texture, 8 storage
/// texture.
fn binding_kind(kind : @types.BindingLayout) -> Int32 {
  match kind {
    @types.BindingLayout::Buffer(buffer) =>
      match buffer.kind {
        @types.BufferBindingType::Uniform => 0
        @types.BufferBindingType::Storage => 1
        @types.BufferBindingType::ReadOnlyStorage => 2
      }
    @types.BindingLayout::Sampler(sampler) =>
      match sampler.kind {
        @types.SamplerBindingType::Filtering => 3
        @types.SamplerBindingType::NonFiltering => 4
        @types.SamplerBindingType::Comparison => 5
      }
    @types.BindingLayout::Texture(_) => 6
    @types.BindingLayout::StorageTexture(_) => 8
  }
}

///|
/// Whether a binding takes a dynamic offset, which changes how a descriptor
/// set is written and bound.
fn is_dynamic(kind : @types.BindingLayout) -> Bool {
  match kind {
    @types.BindingLayout::Buffer(buffer) => buffer.has_dynamic_offset
    _ => false
  }
}

///|
/// The sample type of a texture binding: 0 float, 1 unfilterable float, 2
/// uint, 3 sint, 4 depth.
fn sample_type_code(kind : @types.BindingLayout) -> Int32 {
  match kind {
    @types.BindingLayout::Texture(texture) =>
      match texture.sample_type {
        @types.SampleType::Float => 0
        @types.SampleType::UnfilterableFloat => 1
        @types.SampleType::Uint => 2
        @types.SampleType::Sint => 3
        @types.SampleType::Depth => 4
      }
    _ => 0
  }
}

///|
fn text_dimension_code(kind : @types.BindingLayout) -> Int32 {
  match kind {
    @types.BindingLayout::Texture(texture) =>
      view_dimension(texture.view_dimension)
    @types.BindingLayout::StorageTexture(texture) =>
      view_dimension(texture.view_dimension)
    _ => 1
  }
}

///|
fn multisampled_code(kind : @types.BindingLayout) -> Int32 {
  match kind {
    @types.BindingLayout::Texture(texture) =>
      if texture.multisampled {
        1
      } else {
        0
      }
    _ => 0
  }
}

///|
fn storage_access_code(kind : @types.BindingLayout) -> Int32 {
  match kind {
    @types.BindingLayout::StorageTexture(texture) =>
      match texture.access {
        @types.StorageTextureAccess::WriteOnly => 0
        @types.StorageTextureAccess::ReadOnly => 1
        @types.StorageTextureAccess::ReadWrite => 2
      }
    _ => 0
  }
}

///|
/// The index format: 0 sixteen bits, 1 thirty-two.
fn index_format_code(format : @types.IndexFormat) -> Int32 {
  match format {
    @types.IndexFormat::Uint16 => 0
    @types.IndexFormat::Uint32 => 1
  }
}

///|
/// How many bytes one row of `width` texels takes, with no padding.
fn row_bytes(format : @types.TextureFormat, width : Int32) -> Int32 {
  let info = format.info()
  let blocks = (width + info.block_width - 1) / info.block_width
  blocks * info.bytes_per_block
}

///|
/// How many bytes one whole subresource of a texture takes.
fn subresource_bytes(
  format : @types.TextureFormat,
  size : @types.Extent3d,
) -> Int32 {
  let info = format.info()
  let rows = (size.height + info.block_height - 1) / info.block_height
  row_bytes(format, size.width) * rows * size.depth_or_array_layers
}
