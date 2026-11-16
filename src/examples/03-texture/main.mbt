// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A texture round trip: upload two texels, copy the texture into a read-back
/// buffer, map it, and look at the bytes.
///
/// Every byte printed here was moved by the library, not by the example.
///
///     moon run src/examples/03-texture

///|
/// Two lowercase hex digits of one byte.
fn hex(byte : Byte) -> String {
  let digits = "0123456789abcdef"
  let value = byte.to_int()
  let high = (value >> 4) & 0xF
  let low = value & 0xF
  digits[high:high + 1].to_owned() + digits[low:low + 1].to_owned()
}

///|
#coverage.skip
fn main raise {
  let backend = @memory.Backend::new()
  let device = @moonwgpu.Instance::new(backend~)
    .request_adapter()
    .request_device()
  let texture = device.create_texture(
    descriptor=@types.TextureDescriptor::new(
      size=@types.Extent3d::new(width=2, height=2),
      format=@types.TextureFormat::Rgba8unorm,
      usage=@types.TextureUsages::copy_dst() | @types.TextureUsages::copy_src(),
    ),
  )
  // Two rows of two texels: red, green, blue, white.
  let texels : Array[Byte] = [
    b'\xff', b'\x00', b'\x00', b'\xff', b'\x00', b'\xff', b'\x00', b'\xff', b'\x00',
    b'\x00', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff', b'\xff',
  ]
  device
  .queue()
  .write_texture(
    destination=@types.TexelCopyTextureInfo::new(texture=texture.id()),
    data=Bytes::from_array(texels),
    layout=@types.TexelCopyBufferLayout::new(
      offset=0,
      bytes_per_row=8,
      rows_per_image=2,
    ),
  )
  // A copy back needs a buffer whose rows are 256-byte aligned.
  let readback = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=512,
      usage=@types.BufferUsages::copy_dst() | @types.BufferUsages::map_read(),
    ),
  )
  let encoder = device.create_command_encoder(label="readback")
  encoder.copy_texture_to_buffer(
    source=@types.TexelCopyTextureInfo::new(texture=texture.id()),
    destination=@types.TexelCopyBufferInfo::new(
      buffer=readback.id(),
      layout=@types.TexelCopyBufferLayout::new(
        offset=0,
        bytes_per_row=256,
        rows_per_image=2,
      ),
    ),
    copy_size=@types.Extent3d::new(width=2, height=2),
  )
  device.queue().submit(command_buffers=[encoder.finish()])
  readback.map_read()
  let bytes = readback.get_mapped_range()
  readback.unmap()
  println("format:         \{texture.format().name()}")
  println("texels written: \{texels.length()} bytes")
  // Rows in a copy buffer are 256 bytes apart, so row one starts at byte 256.
  let mut out = ""
  for row in 0..<2 {
    if row > 0 {
      out = out + " | "
    }
    for i in 0..<8 {
      if i > 0 && i % 4 == 0 {
        out = out + " "
      }
      out = out + hex(bytes[row * 256 + i])
    }
  }
  println("read back:      \{out}")
}
