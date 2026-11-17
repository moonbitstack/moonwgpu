// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// `mapAsync`: the range, the alignment, and the two directions.

///|
fn map_error(run : () -> Unit raise @core.Refused) -> @types.ErrorKind? {
  try {
    run()
    None
  } catch {
    @core.Refused::Validation(kind~, ..) => Some(kind)
    _ => None
  }
}

///|
test "mapAsync checks alignment, size, mode and range" {
  let device = device()
  let buffer = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=64,
      usage=@types.BufferUsages::map_read() | @types.BufferUsages::copy_dst(),
    ),
  )
  assert_eq(
    map_error(fn() raise @core.Refused {
      buffer.map_async(mode=@types.MapMode::read(), offset=4)
    }),
    Some(@types.InvalidAlignment),
  )
  assert_eq(
    map_error(fn() raise @core.Refused {
      buffer.map_async(mode=@types.MapMode::read(), offset=0, size=6)
    }),
    Some(@types.InvalidBufferSize),
  )
  assert_eq(
    map_error(fn() raise @core.Refused {
      buffer.map_async(mode=@types.MapMode::read(), offset=0, size=128)
    }),
    Some(@types.InvalidBufferSize),
  )
  assert_eq(
    map_error(fn() raise @core.Refused {
      buffer.map_async(mode=@types.MapMode::none())
    }),
    Some(@types.InvalidBufferUsage),
  )
  assert_eq(
    map_error(fn() raise @core.Refused {
      buffer.map_async(mode=@types.MapMode::write())
    }),
    Some(@types.InvalidBufferUsage),
  )
}

///|
test "mapAsync maps the range it was given" {
  let device = device()
  let buffer = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=16,
      usage=@types.BufferUsages::map_read() | @types.BufferUsages::copy_dst(),
    ),
  )
  device
  .queue()
  .write_buffer(
    buffer~,
    offset=0,
    data=b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10",
  )
  buffer.map_async(mode=@types.MapMode::read(), offset=8, size=4)
  let mapped = buffer.get_mapped_range()
  assert_eq(mapped.length(), 4)
  assert_eq(mapped[0], b'\x09')
  assert_eq(mapped[3], b'\x0c')
  buffer.unmap()
  assert_false(buffer.is_mapped())
}

///|
test "a write mapping reaches the device when it is dropped" {
  let device = device()
  let staging = device.create_buffer(
    descriptor=@types.BufferDescriptor::new(
      size=8,
      usage=@types.BufferUsages::map_write() | @types.BufferUsages::copy_src(),
    ),
  )
  let readback = readback_buffer(device, 8)
  staging.map_async(mode=@types.MapMode::write())
  staging.map_write(data=b"\xaa\xbb\xcc\xdd\x11\x22\x33\x44")
  staging.unmap()
  let encoder = device.create_command_encoder()
  encoder.copy_buffer_to_buffer(
    source=staging,
    source_offset=0,
    destination=readback,
    destination_offset=0,
    size=8,
  )
  device.queue().submit(command_buffers=[encoder.finish()])
  readback.map_read()
  let bytes = readback.get_mapped_range()
  assert_eq(bytes[0], b'\xaa')
  assert_eq(bytes[7], b'\x44')
}
