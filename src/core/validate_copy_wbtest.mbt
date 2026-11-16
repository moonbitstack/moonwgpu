// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The copy rules: alignment, ranges, usages, and the 256-byte row stride a
// buffer-to-texture copy needs.

///|
test "a buffer to buffer copy needs four byte alignment on both sides" {
  let source = buffer_state(64, @types.BufferUsages::copy_src())
  let destination = buffer_state(64, @types.BufferUsages::copy_dst())
  assert_true(
    kind_of(fn() raise Refused {
      validate_copy_buffer_to_buffer(source, 0, destination, 0, 64)
    })
    is None,
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_copy_buffer_to_buffer(source, 2, destination, 0, 4)
    }),
    Some(@types.InvalidAlignment),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_copy_buffer_to_buffer(source, 0, destination, 0, 6)
    }),
    Some(@types.InvalidAlignment),
  )
}

///|
test "a buffer to buffer copy stays inside both buffers" {
  let source = buffer_state(64, @types.BufferUsages::copy_src())
  let destination = buffer_state(32, @types.BufferUsages::copy_dst())
  assert_eq(
    kind_of(fn() raise Refused {
      validate_copy_buffer_to_buffer(source, 0, destination, 0, 36)
    }),
    Some(@types.InvalidCopyRange),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_copy_buffer_to_buffer(source, 32, destination, 0, 36)
    }),
    Some(@types.InvalidCopyRange),
  )
}

///|
test "a copy needs the usage that names its direction" {
  let source = buffer_state(64, @types.BufferUsages::vertex())
  let destination = buffer_state(64, @types.BufferUsages::copy_dst())
  assert_eq(
    kind_of(fn() raise Refused {
      validate_copy_buffer_to_buffer(source, 0, destination, 0, 4)
    }),
    Some(@types.InvalidBufferUsage),
  )
  let writable = buffer_state(64, @types.BufferUsages::copy_src())
  assert_eq(
    kind_of(fn() raise Refused {
      validate_copy_buffer_to_buffer(writable, 0, writable, 0, 4)
    }),
    Some(@types.InvalidBufferUsage),
  )
}

///|
test "a buffer to texture copy needs a 256 byte row stride" {
  let buffer = buffer_state(4096, @types.BufferUsages::copy_src())
  let texture = texture_state(
    4,
    4,
    @types.TextureFormat::Rgba8unorm,
    @types.TextureUsages::copy_dst(),
  )
  let destination = @types.TexelCopyTextureInfo::new(
    texture=@types.TextureId::from_raw(1UL),
  )
  let size = @types.Extent3d::new(width=4, height=4)
  let fine = @types.TexelCopyBufferLayout::new(
    offset=0,
    bytes_per_row=256,
    rows_per_image=4,
  )
  assert_true(
    kind_of(fn() raise Refused {
      validate_buffer_to_texture_copy(
        buffer, fine, texture, destination, size, 256, "copy",
      )
    })
    is None,
  )
  let unaligned = @types.TexelCopyBufferLayout::new(
    offset=0,
    bytes_per_row=64,
    rows_per_image=4,
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_buffer_to_texture_copy(
        buffer, unaligned, texture, destination, size, 256, "copy",
      )
    }),
    Some(@types.InvalidBytesPerRow),
  )
}

///|
test "a row stride narrower than a row of texels is refused" {
  let buffer = buffer_state(4096, @types.BufferUsages::copy_src())
  let texture = texture_state(
    8,
    1,
    @types.TextureFormat::Rgba8unorm,
    @types.TextureUsages::copy_dst(),
  )
  let destination = @types.TexelCopyTextureInfo::new(
    texture=@types.TextureId::from_raw(1UL),
  )
  let layout = @types.TexelCopyBufferLayout::new(offset=0, bytes_per_row=16)
  assert_eq(
    kind_of(fn() raise Refused {
      validate_buffer_to_texture_copy(
        buffer,
        layout,
        texture,
        destination,
        @types.Extent3d::new(width=8, height=1),
        1,
        "write",
      )
    }),
    Some(@types.InvalidBytesPerRow),
  )
}

///|
test "a multi row copy needs a row stride at all" {
  let buffer = buffer_state(4096, @types.BufferUsages::copy_src())
  let texture = texture_state(
    4,
    4,
    @types.TextureFormat::Rgba8unorm,
    @types.TextureUsages::copy_dst(),
  )
  let destination = @types.TexelCopyTextureInfo::new(
    texture=@types.TextureId::from_raw(1UL),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_buffer_to_texture_copy(
        buffer,
        @types.TexelCopyBufferLayout::new(),
        texture,
        destination,
        @types.Extent3d::new(width=4, height=4),
        256,
        "copy",
      )
    }),
    Some(@types.InvalidBytesPerRow),
  )
}

///|
test "a copy region stays inside the mip level" {
  let buffer = buffer_state(4096, @types.BufferUsages::copy_src())
  let texture = texture_state(
    4,
    4,
    @types.TextureFormat::Rgba8unorm,
    @types.TextureUsages::copy_dst(),
  )
  let destination = @types.TexelCopyTextureInfo::new(
    texture=@types.TextureId::from_raw(1UL),
    origin=@types.Origin3d::new(x=0, y=2),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_buffer_to_texture_copy(
        buffer,
        @types.TexelCopyBufferLayout::new(offset=0, bytes_per_row=256),
        texture,
        destination,
        @types.Extent3d::new(width=4, height=4),
        256,
        "copy",
      )
    }),
    Some(@types.InvalidCopyRange),
  )
}

///|
test "a copy into a texture without copy destination is refused" {
  let buffer = buffer_state(4096, @types.BufferUsages::copy_src())
  let texture = texture_state(
    4,
    4,
    @types.TextureFormat::Rgba8unorm,
    @types.TextureUsages::texture_binding(),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_buffer_to_texture_copy(
        buffer,
        @types.TexelCopyBufferLayout::new(offset=0, bytes_per_row=256),
        texture,
        @types.TexelCopyTextureInfo::new(
          texture=@types.TextureId::from_raw(1UL),
        ),
        @types.Extent3d::new(width=4, height=4),
        256,
        "copy",
      )
    }),
    Some(@types.InvalidTextureUsage),
  )
}

///|
test "a buffer read back needs copy destination and a mapped range" {
  let texture = texture_state(
    4,
    4,
    @types.TextureFormat::Rgba8unorm,
    @types.TextureUsages::copy_src(),
  )
  let buffer = buffer_state(4096, @types.BufferUsages::map_read())
  let layout = @types.TexelCopyBufferLayout::new(
    offset=0,
    bytes_per_row=256,
    rows_per_image=4,
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_to_buffer_copy(
        texture,
        @types.TexelCopyTextureInfo::new(
          texture=@types.TextureId::from_raw(1UL),
        ),
        buffer,
        layout,
        @types.Extent3d::new(width=4, height=4),
      )
    }),
    Some(@types.InvalidBufferUsage),
  )
}

///|
test "a texture to texture copy needs both directions and one format" {
  let source = texture_state(
    4,
    4,
    @types.TextureFormat::Rgba8unorm,
    @types.TextureUsages::copy_src(),
  )
  let destination = texture_state(
    4,
    4,
    @types.TextureFormat::Rgba8unorm,
    @types.TextureUsages::copy_dst(),
  )
  let from = @types.TexelCopyTextureInfo::new(
    texture=@types.TextureId::from_raw(1UL),
  )
  let to = @types.TexelCopyTextureInfo::new(
    texture=@types.TextureId::from_raw(2UL),
  )
  assert_true(
    kind_of(fn() raise Refused {
      validate_texture_to_texture_copy(
        source,
        from,
        destination,
        to,
        @types.Extent3d::new(width=4, height=4),
      )
    })
    is None,
  )
  let other_format = texture_state(
    4,
    4,
    @types.TextureFormat::Bgra8unorm,
    @types.TextureUsages::copy_dst(),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_to_texture_copy(
        source,
        from,
        other_format,
        to,
        @types.Extent3d::new(width=4, height=4),
      )
    }),
    Some(@types.InvalidTextureFormat),
  )
}
