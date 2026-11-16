// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The command executor of the memory backend. Copies and clears move real
// bytes; passes are recorded but not shaded, because this backend has no
// shader compiler.

///|
/// Copy `length` bytes between two byte arrays.
fn copy_bytes(
  destination : Array[Byte],
  destination_offset : Int32,
  source : Array[Byte],
  source_offset : Int32,
  length : Int32,
) -> Unit raise @hal.HalError {
  if source_offset < 0 ||
    destination_offset < 0 ||
    source_offset + length > source.length() ||
    destination_offset + length > destination.length() {
    raise @hal.HalError::failed("copy outside its resource")
  }
  for i in 0..<length {
    destination[destination_offset + i] = source[source_offset + i]
  }
}

///|
pub impl @hal.Hal for Backend with fn submit(self, commands) -> Unit raise @hal.HalError {
  for command in commands {
    match command {
      CopyBufferToBuffer(copy) => {
        let source = match self.buffers.get(copy.source.raw()) {
          Some(record) => record
          None => raise @hal.HalError::missing("buffer \{copy.source.raw()}")
        }
        let destination = match self.buffers.get(copy.destination.raw()) {
          Some(record) => record
          None =>
            raise @hal.HalError::missing("buffer \{copy.destination.raw()}")
        }
        copy_bytes(
          destination.data,
          copy.destination_offset,
          source.data,
          copy.source_offset,
          copy.size,
        )
      }
      ClearBuffer(clear) => {
        let record = match self.buffers.get(clear.buffer.raw()) {
          Some(record) => record
          None => raise @hal.HalError::missing("buffer \{clear.buffer.raw()}")
        }
        for i in 0..<clear.size {
          record.data[clear.offset + i] = b'\x00'
        }
      }
      ClearTexture(clear) => {
        let record = match self.textures.get(clear.texture.raw()) {
          Some(record) => record
          None => raise @hal.HalError::missing("texture \{clear.texture.raw()}")
        }
        let size = record.descriptor.size.physical_size(
          mip_level=clear.mip_level,
          format=record.descriptor.format,
        )
        let stride = level_row_stride(record.descriptor.format, size.width)
        let level = record.levels[clear.mip_level]
        let row = row_bytes(record.descriptor.format, clear.size.width)
        let x_offset = row_bytes(record.descriptor.format, clear.origin.x)
        for z in 0..<clear.size.depth_or_array_layers {
          for y in 0..<clear.size.height {
            let line = (clear.origin.z + z) * size.height + clear.origin.y + y
            for i in 0..<row {
              level[line * stride + x_offset + i] = b'\x00'
            }
          }
        }
      }
      CopyBufferToTexture(copy) => {
        let source = match self.buffers.get(copy.source.buffer.raw()) {
          Some(record) => record
          None =>
            raise @hal.HalError::missing("buffer \{copy.source.buffer.raw()}")
        }
        let destination = match
          self.textures.get(copy.destination.texture.raw()) {
          Some(record) => record
          None =>
            raise @hal.HalError::missing(
              "texture \{copy.destination.texture.raw()}",
            )
        }
        let format = destination.descriptor.format
        let size = destination.descriptor.size.physical_size(
          mip_level=copy.destination.mip_level,
          format~,
        )
        let stride = level_row_stride(format, size.width)
        let level = destination.levels[copy.destination.mip_level]
        let row = row_bytes(format, copy.copy_size.width)
        let x_offset = row_bytes(format, copy.destination.origin.x)
        let bytes_per_row = match copy.source.layout.bytes_per_row {
          Some(value) => value
          None => row
        }
        let rows_per_image = match copy.source.layout.rows_per_image {
          Some(value) => value
          None => copy.copy_size.height
        }
        for z in 0..<copy.copy_size.depth_or_array_layers {
          for y in 0..<copy.copy_size.height {
            let source_at = copy.source.layout.offset +
              z * bytes_per_row * rows_per_image +
              y * bytes_per_row
            let line = (copy.destination.origin.z + z) * size.height +
              copy.destination.origin.y +
              y
            let target = line * stride + x_offset
            if target + row > level.length() ||
              source_at + row > source.data.length() {
              raise @hal.HalError::failed("texel write outside its resource")
            }
            for i in 0..<row {
              level[target + i] = source.data[source_at + i]
            }
          }
        }
      }
      CopyTextureToBuffer(copy) => {
        let source = match self.textures.get(copy.source.texture.raw()) {
          Some(record) => record
          None =>
            raise @hal.HalError::missing("texture \{copy.source.texture.raw()}")
        }
        let destination = match
          self.buffers.get(copy.destination.buffer.raw()) {
          Some(record) => record
          None =>
            raise @hal.HalError::missing(
              "buffer \{copy.destination.buffer.raw()}",
            )
        }
        let format = source.descriptor.format
        let size = source.descriptor.size.physical_size(
          mip_level=copy.source.mip_level,
          format~,
        )
        let stride = level_row_stride(format, size.width)
        let level = source.levels[copy.source.mip_level]
        let row = row_bytes(format, copy.copy_size.width)
        let x_offset = row_bytes(format, copy.source.origin.x)
        let bytes_per_row = match copy.destination.layout.bytes_per_row {
          Some(value) => value
          None => row
        }
        let rows_per_image = match copy.destination.layout.rows_per_image {
          Some(value) => value
          None => copy.copy_size.height
        }
        for z in 0..<copy.copy_size.depth_or_array_layers {
          for y in 0..<copy.copy_size.height {
            let target_at = copy.destination.layout.offset +
              z * bytes_per_row * rows_per_image +
              y * bytes_per_row
            let line = (copy.source.origin.z + z) * size.height +
              copy.source.origin.y +
              y
            let source_at = line * stride + x_offset
            if source_at + row > level.length() ||
              target_at + row > destination.data.length() {
              raise @hal.HalError::failed("texel read outside its resource")
            }
            for i in 0..<row {
              destination.data[target_at + i] = level[source_at + i]
            }
          }
        }
      }
      CopyTextureToTexture(copy) => {
        let source = match self.textures.get(copy.source.texture.raw()) {
          Some(record) => record
          None =>
            raise @hal.HalError::missing("texture \{copy.source.texture.raw()}")
        }
        let destination = match
          self.textures.get(copy.destination.texture.raw()) {
          Some(record) => record
          None =>
            raise @hal.HalError::missing(
              "texture \{copy.destination.texture.raw()}",
            )
        }
        let format = source.descriptor.format
        let source_size = source.descriptor.size.physical_size(
          mip_level=copy.source.mip_level,
          format~,
        )
        let destination_size = destination.descriptor.size.physical_size(
          mip_level=copy.destination.mip_level,
          format~,
        )
        let source_stride = level_row_stride(format, source_size.width)
        let destination_stride = level_row_stride(
          format,
          destination_size.width,
        )
        let source_level = source.levels[copy.source.mip_level]
        let destination_level = destination.levels[copy.destination.mip_level]
        let row = row_bytes(format, copy.copy_size.width)
        for z in 0..<copy.copy_size.depth_or_array_layers {
          for y in 0..<copy.copy_size.height {
            let source_line = (copy.source.origin.z + z) * source_size.height +
              copy.source.origin.y +
              y
            let destination_line = (copy.destination.origin.z + z) *
              destination_size.height +
              copy.destination.origin.y +
              y
            let from = source_line * source_stride +
              row_bytes(format, copy.source.origin.x)
            let to = destination_line * destination_stride +
              row_bytes(format, copy.destination.origin.x)
            if from + row > source_level.length() ||
              to + row > destination_level.length() {
              raise @hal.HalError::failed("texel copy outside its resource")
            }
            for i in 0..<row {
              destination_level[to + i] = source_level[from + i]
            }
          }
        }
      }
      // Query results are written by a real device; this backend has none, so
      // the destination keeps whatever it held.
      ResolveQuerySet(_) => ()
      RenderPass(_) | ComputePass(_) => ()
    }
  }
  self.submitted.push(commands.copy())
}
