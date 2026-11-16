// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Texel addressing for the memory backend. A mip level is one flat array with
// the rows packed tightly; the padded layout only exists while bytes travel
// through a buffer, which `execute.mbt` deals with.

///|
/// The row stride of one mip level, in bytes.
fn level_row_stride(format : @types.TextureFormat, width : Int32) -> Int32 {
  row_bytes(format, width)
}

///|
/// Write `data`, whose rows are packed, into the region of `record`.
fn write_texels(
  record : TextureRecord,
  origin : @types.Origin3d,
  extent : @types.Extent3d,
  mip_level : Int32,
  data : Bytes,
) -> Unit raise @hal.HalError {
  let format = record.descriptor.format
  if mip_level < 0 || mip_level >= record.levels.length() {
    raise @hal.HalError::missing("mip \{mip_level}")
  }
  let level = record.levels[mip_level]
  let size = record.descriptor.size.physical_size(mip_level~, format~)
  let stride = level_row_stride(format, size.width)
  let src_row = row_bytes(format, extent.width)
  let x_offset = row_bytes(format, origin.x)
  let mut at = 0
  for z in 0..<extent.depth_or_array_layers {
    for y in 0..<extent.height {
      let row = (origin.z + z) * size.height + origin.y + y
      let target = row * stride + x_offset
      if target + src_row > level.length() || at + src_row > data.length() {
        raise @hal.HalError::failed("write outside the texture")
      }
      for i in 0..<src_row {
        level[target + i] = data[at + i]
      }
      at = at + src_row
    }
  }
}

///|
/// Read the region of `record` into packed rows.
fn read_texels(
  record : TextureRecord,
  origin : @types.Origin3d,
  extent : @types.Extent3d,
  mip_level : Int32,
) -> Array[Byte] raise @hal.HalError {
  let format = record.descriptor.format
  if mip_level < 0 || mip_level >= record.levels.length() {
    raise @hal.HalError::missing("mip \{mip_level}")
  }
  let level = record.levels[mip_level]
  let size = record.descriptor.size.physical_size(mip_level~, format~)
  let stride = level_row_stride(format, size.width)
  let row = row_bytes(format, extent.width)
  let x_offset = row_bytes(format, origin.x)
  let out = Array::make(
    row * extent.height * extent.depth_or_array_layers,
    b'\x00',
  )
  let mut at = 0
  for z in 0..<extent.depth_or_array_layers {
    for y in 0..<extent.height {
      let line = (origin.z + z) * size.height + origin.y + y
      let source = line * stride + x_offset
      if source + row > level.length() {
        raise @hal.HalError::failed("read outside the texture")
      }
      for i in 0..<row {
        out[at + i] = level[source + i]
      }
      at = at + row
    }
  }
  out
}
