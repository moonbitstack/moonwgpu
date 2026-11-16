// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The 256-byte line a buffer-to-texture copy pads every row to. The copy APIs
/// require it so that a backend can hand the buffer to the hardware row by row.
pub const COPY_BYTES_PER_ROW_ALIGNMENT : Int32 = 256

///|
/// `copyBufferToBuffer`: both offsets and the size are multiples of four and
/// the two ranges are inside their buffers.
/// https://www.w3.org/TR/webgpu/#dom-gpucommandencoder-copybuffertobuffer
pub fn validate_copy_buffer_to_buffer(
  source : BufferState,
  source_offset : Int32,
  destination : BufferState,
  destination_offset : Int32,
  size : Int32,
) -> Unit raise Refused {
  require(
    source.descriptor.usage.contains(@types.BufferUsages::copy_src()),
    @types.InvalidBufferUsage,
    "source.usage",
    "COPY_SRC",
    describe_usages(source.descriptor.usage.bits(), buffer_usage_names()),
  )
  require(
    destination.descriptor.usage.contains(@types.BufferUsages::copy_dst()),
    @types.InvalidBufferUsage,
    "destination.usage",
    "COPY_DST",
    describe_usages(destination.descriptor.usage.bits(), buffer_usage_names()),
  )
  require_same(0, source_offset % 4, @types.InvalidAlignment, "sourceOffset")
  require_same(
    0,
    destination_offset % 4,
    @types.InvalidAlignment,
    "destinationOffset",
  )
  require_same(0, size % 4, @types.InvalidAlignment, "size")
  require_int(size >= 0, @types.InvalidCopySize, "size", 0, size)
  require_int(
    source_offset + size <= source.descriptor.size,
    @types.InvalidCopyRange,
    "sourceOffset + size",
    source.descriptor.size,
    source_offset + size,
  )
  require_int(
    destination_offset + size <= destination.descriptor.size,
    @types.InvalidCopyRange,
    "destinationOffset + size",
    destination.descriptor.size,
    destination_offset + size,
  )
}

///|
/// The subresource a copy addresses: the aspect exists, the mip level exists,
/// and the region is inside that level.
fn validate_copy_region(
  texture : TextureState,
  copy : @types.TexelCopyTextureInfo,
  size : @types.Extent3d,
  at : String,
) -> Unit raise Refused {
  let info = texture.descriptor.format.info()
  match copy.aspect {
    @types.TextureAspect::All => ()
    @types.TextureAspect::DepthOnly =>
      require(
        info.aspect == @types.FormatAspect::DepthOnly ||
        info.aspect == @types.FormatAspect::DepthStencil,
        @types.InvalidSubresource,
        "\{at}.aspect",
        "a texture with a depth aspect",
        texture.descriptor.format.name(),
      )
    @types.TextureAspect::StencilOnly =>
      require(
        info.aspect == @types.FormatAspect::StencilOnly ||
        info.aspect == @types.FormatAspect::DepthStencil,
        @types.InvalidSubresource,
        "\{at}.aspect",
        "a texture with a stencil aspect",
        texture.descriptor.format.name(),
      )
  }
  require_int(
    copy.mip_level >= 0 && copy.mip_level < texture.descriptor.mip_level_count,
    @types.InvalidSubresource,
    "\{at}.mipLevel",
    texture.descriptor.mip_level_count - 1,
    copy.mip_level,
  )
  let level = texture.descriptor.size.physical_size(
    mip_level=copy.mip_level,
    format=texture.descriptor.format,
  )
  require_same(
    0,
    copy.origin.x % info.block_width,
    @types.InvalidAlignment,
    "\{at}.origin.x",
  )
  require_same(
    0,
    copy.origin.y % info.block_height,
    @types.InvalidAlignment,
    "\{at}.origin.y",
  )
  require_int(
    copy.origin.x + size.width <= level.width,
    @types.InvalidCopyRange,
    "\{at}.origin.x + copySize.width",
    level.width,
    copy.origin.x + size.width,
  )
  require_int(
    copy.origin.y + size.height <= level.height,
    @types.InvalidCopyRange,
    "\{at}.origin.y + copySize.height",
    level.height,
    copy.origin.y + size.height,
  )
  require_int(
    copy.origin.z + size.depth_or_array_layers <= level.depth_or_array_layers,
    @types.InvalidCopyRange,
    "\{at}.origin.z + copySize.depthOrArrayLayers",
    level.depth_or_array_layers,
    copy.origin.z + size.depth_or_array_layers,
  )
  require_int(
    size.width > 0,
    @types.InvalidCopySize,
    "\{at}.copySize.width",
    1,
    size.width,
  )
}

///|
/// The bytes one copy region needs in its buffer, with rows padded to the
/// alignment the API demands.
fn buffer_extent(
  format : @types.TextureFormat,
  size : @types.Extent3d,
  layout : @types.TexelCopyBufferLayout,
  bytes_per_row_alignment : Int32,
) -> Int32 raise Refused {
  let info = format.info()
  let row = format.bytes_per_row(width=size.width)
  let bytes_per_row = match layout.bytes_per_row {
    Some(value) => value
    None =>
      if size.height > 1 {
        raise invalid(
          @types.InvalidBytesPerRow,
          "layout.bytesPerRow",
          "a row stride when the copy is more than one row",
          "none",
        )
      } else {
        row
      }
  }
  require_int(
    bytes_per_row >= row,
    @types.InvalidBytesPerRow,
    "layout.bytesPerRow",
    row,
    bytes_per_row,
  )
  if bytes_per_row_alignment > 1 {
    require_same(
      0,
      bytes_per_row % bytes_per_row_alignment,
      @types.InvalidBytesPerRow,
      "layout.bytesPerRow",
    )
  } else {
    require_same(
      0,
      bytes_per_row % info.bytes_per_block,
      @types.InvalidBytesPerRow,
      "layout.bytesPerRow",
    )
  }
  let rows = (size.height + info.block_height - 1) / info.block_height
  let rows_per_image = match layout.rows_per_image {
    Some(value) => value
    None =>
      if size.depth_or_array_layers > 1 {
        raise invalid(
          @types.InvalidBytesPerRow,
          "layout.rowsPerImage",
          "a row count per image when the copy is more than one layer",
          "none",
        )
      } else {
        rows
      }
  }
  require_int(
    rows_per_image >= rows,
    @types.InvalidBytesPerRow,
    "layout.rowsPerImage",
    rows,
    rows_per_image,
  )
  bytes_per_row * rows_per_image * (size.depth_or_array_layers - 1) +
  bytes_per_row * (rows - 1) +
  row
}

///|
/// `copyBufferToTexture` and `writeTexture` share these rules; only the row
/// alignment differs, which the caller passes in.
pub fn validate_buffer_to_texture_copy(
  buffer : BufferState,
  layout : @types.TexelCopyBufferLayout,
  texture : TextureState,
  destination : @types.TexelCopyTextureInfo,
  size : @types.Extent3d,
  bytes_per_row_alignment : Int32,
  at : String,
) -> Unit raise Refused {
  require(
    buffer.descriptor.usage.contains(@types.BufferUsages::copy_src()),
    @types.InvalidBufferUsage,
    "\{at}.buffer.usage",
    "COPY_SRC",
    describe_usages(buffer.descriptor.usage.bits(), buffer_usage_names()),
  )
  require(
    texture.descriptor.usage.contains(@types.TextureUsages::copy_dst()),
    @types.InvalidTextureUsage,
    "destination.texture.usage",
    "COPY_DST",
    describe_usages(texture.descriptor.usage.bits(), texture_usage_names()),
  )
  require(
    texture.descriptor.format.info().copy_dst,
    @types.InvalidTextureFormat,
    "destination.texture.format",
    "a format that can be a copy destination",
    texture.descriptor.format.name(),
  )
  require_int(
    texture.descriptor.sample_count == 1,
    @types.InvalidTextureSampleCount,
    "destination.texture.sampleCount",
    1,
    texture.descriptor.sample_count,
  )
  validate_copy_region(texture, destination, size, "destination")
  let needed = buffer_extent(
    texture.descriptor.format,
    size,
    layout,
    bytes_per_row_alignment,
  )
  require_int(
    layout.offset >= 0 && layout.offset + needed <= buffer.descriptor.size,
    @types.InvalidCopyRange,
    "\{at}.layout.offset",
    buffer.descriptor.size,
    layout.offset + needed,
  )
}

///|
/// `copyTextureToBuffer`.
pub fn validate_texture_to_buffer_copy(
  texture : TextureState,
  source : @types.TexelCopyTextureInfo,
  buffer : BufferState,
  layout : @types.TexelCopyBufferLayout,
  size : @types.Extent3d,
) -> Unit raise Refused {
  require(
    texture.descriptor.usage.contains(@types.TextureUsages::copy_src()),
    @types.InvalidTextureUsage,
    "source.texture.usage",
    "COPY_SRC",
    describe_usages(texture.descriptor.usage.bits(), texture_usage_names()),
  )
  require(
    buffer.descriptor.usage.contains(@types.BufferUsages::copy_dst()),
    @types.InvalidBufferUsage,
    "destination.buffer.usage",
    "COPY_DST",
    describe_usages(buffer.descriptor.usage.bits(), buffer_usage_names()),
  )
  require(
    texture.descriptor.format.info().copy_src,
    @types.InvalidTextureFormat,
    "source.texture.format",
    "a format that can be a copy source",
    texture.descriptor.format.name(),
  )
  require_int(
    texture.descriptor.sample_count == 1,
    @types.InvalidTextureSampleCount,
    "source.texture.sampleCount",
    1,
    texture.descriptor.sample_count,
  )
  validate_copy_region(texture, source, size, "source")
  let needed = buffer_extent(
    texture.descriptor.format,
    size,
    layout,
    COPY_BYTES_PER_ROW_ALIGNMENT,
  )
  require_int(
    layout.offset >= 0 && layout.offset + needed <= buffer.descriptor.size,
    @types.InvalidCopyRange,
    "destination.layout.offset",
    buffer.descriptor.size,
    layout.offset + needed,
  )
}

///|
/// `copyTextureToTexture`: both sides have to agree on the texel size and the
/// aspect, and both have to carry the usage the direction needs.
pub fn validate_texture_to_texture_copy(
  source : TextureState,
  source_info : @types.TexelCopyTextureInfo,
  destination : TextureState,
  destination_info : @types.TexelCopyTextureInfo,
  size : @types.Extent3d,
) -> Unit raise Refused {
  require(
    source.descriptor.usage.contains(@types.TextureUsages::copy_src()),
    @types.InvalidTextureUsage,
    "source.texture.usage",
    "COPY_SRC",
    describe_usages(source.descriptor.usage.bits(), texture_usage_names()),
  )
  require(
    destination.descriptor.usage.contains(@types.TextureUsages::copy_dst()),
    @types.InvalidTextureUsage,
    "destination.texture.usage",
    "COPY_DST",
    describe_usages(destination.descriptor.usage.bits(), texture_usage_names()),
  )
  require(
    source.descriptor.format == destination.descriptor.format,
    @types.InvalidTextureFormat,
    "destination.texture.format",
    source.descriptor.format.name(),
    destination.descriptor.format.name(),
  )
  require_int(
    source.descriptor.sample_count == destination.descriptor.sample_count,
    @types.InvalidTextureSampleCount,
    "destination.texture.sampleCount",
    source.descriptor.sample_count,
    destination.descriptor.sample_count,
  )
  require(
    source_info.aspect == destination_info.aspect,
    @types.InvalidSubresource,
    "destination.aspect",
    "the source's aspect",
    "another aspect",
  )
  validate_copy_region(source, source_info, size, "source")
  validate_copy_region(destination, destination_info, size, "destination")
}
