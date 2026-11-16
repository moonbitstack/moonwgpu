// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// `queue.writeTexture`: the same region rules as a buffer-to-texture copy,
/// without the 256-byte row alignment a copy buffer needs.
/// https://www.w3.org/TR/webgpu/#dom-gpuqueue-writetexture
pub fn Hub::write_texture(
  self : Hub,
  destination : @types.TexelCopyTextureInfo,
  data : Bytes,
  layout : @types.TexelCopyBufferLayout,
) -> Unit raise Refused {
  self.ensure_alive()
  let texture = self.texture(destination.texture)
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
  let info = texture.descriptor.format.info()
  let region = texture.descriptor.size.physical_size(
    mip_level=destination.mip_level,
    format=texture.descriptor.format,
  )
  let origin = destination.origin
  require_int(
    origin.x + region.width <= region.width,
    @types.InvalidCopyRange,
    "destination.origin.x",
    region.width,
    origin.x + region.width,
  )
  require_int(
    origin.y + region.height <= region.height,
    @types.InvalidCopyRange,
    "destination.origin.y",
    region.height,
    origin.y + region.height,
  )
  require_int(
    origin.z + region.depth_or_array_layers <= region.depth_or_array_layers,
    @types.InvalidCopyRange,
    "destination.origin.z",
    region.depth_or_array_layers,
    origin.z + region.depth_or_array_layers,
  )
  require_same(
    0,
    destination.origin.x % info.block_width,
    @types.InvalidAlignment,
    "destination.origin.x",
  )
  require_same(
    0,
    destination.origin.y % info.block_height,
    @types.InvalidAlignment,
    "destination.origin.y",
  )
  let row = texture.descriptor.format.bytes_per_row(width=region.width)
  let bytes_per_row = match layout.bytes_per_row {
    Some(value) => value
    None => row
  }
  require_int(
    bytes_per_row >= row,
    @types.InvalidBytesPerRow,
    "dataLayout.bytesPerRow",
    row,
    bytes_per_row,
  )
  require_same(
    0,
    bytes_per_row % info.bytes_per_block,
    @types.InvalidBytesPerRow,
    "dataLayout.bytesPerRow",
  )
  let rows = (region.height + info.block_height - 1) / info.block_height
  let rows_per_image = match layout.rows_per_image {
    Some(value) => value
    None => rows
  }
  require_int(
    rows_per_image >= rows,
    @types.InvalidBytesPerRow,
    "dataLayout.rowsPerImage",
    rows,
    rows_per_image,
  )
  let needed = bytes_per_row *
    rows_per_image *
    (region.depth_or_array_layers - 1) +
    bytes_per_row * (rows - 1) +
    row
  require_int(
    layout.offset >= 0 && layout.offset + needed <= data.length(),
    @types.InvalidCopyRange,
    "dataLayout.offset",
    data.length(),
    layout.offset + needed,
  )
  // One row at a time: the backend takes a rect, and a row is the rect that
  // shares the padding rules of the array.
  for z in 0..<region.depth_or_array_layers {
    for y in 0..<rows {
      let at = layout.offset +
        z * bytes_per_row * rows_per_image +
        y * bytes_per_row
      let slice = data[at:at + row].to_owned()
      let origin = @types.Origin3d::new(
        x=destination.origin.x,
        y=destination.origin.y + y * info.block_height,
        z=destination.origin.z + z,
      )
      self.backend.write_texture(
        destination.texture,
        origin,
        @types.Extent3d::new(
          width=region.width,
          height=info.block_height,
          depth_or_array_layers=1,
        ),
        destination.mip_level,
        slice,
      ) catch {
        error => raise self.report(Refused::from_hal(error))
      }
    }
  }
}
