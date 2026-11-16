// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Usage scopes: what a pass may do with a subresource, and what it may not do
// a second time. https://www.w3.org/TR/webgpu/#programming-model

///|
test "reading a buffer twice in one pass is fine" {
  let scope = UsageScope::new()
  let buffer = @types.BufferId::from_raw(1UL)
  scope.use_buffer(buffer, @types.BufferUsages::uniform())
  scope.use_buffer(buffer, @types.BufferUsages::uniform())
  assert_true(
    kind_of(fn() raise Refused {
      scope.use_buffer(buffer, @types.BufferUsages::index())
    })
    is None,
  )
}

///|
test "writing a buffer then reading it in one pass is refused" {
  let scope = UsageScope::new()
  let buffer = @types.BufferId::from_raw(1UL)
  scope.use_buffer(buffer, @types.BufferUsages::storage())
  assert_eq(
    kind_of(fn() raise Refused {
      scope.use_buffer(buffer, @types.BufferUsages::uniform())
    }),
    Some(@types.InvalidBufferUsage),
  )
}

///|
test "reading a buffer then writing it in one pass is refused" {
  let scope = UsageScope::new()
  let buffer = @types.BufferId::from_raw(1UL)
  scope.use_buffer(buffer, @types.BufferUsages::uniform())
  assert_eq(
    kind_of(fn() raise Refused {
      scope.use_buffer(buffer, @types.BufferUsages::copy_dst())
    }),
    Some(@types.InvalidBufferUsage),
  )
}

///|
test "two different buffers do not interact" {
  let scope = UsageScope::new()
  scope.use_buffer(
    @types.BufferId::from_raw(1UL),
    @types.BufferUsages::storage(),
  )
  assert_true(
    kind_of(fn() raise Refused {
      scope.use_buffer(
        @types.BufferId::from_raw(2UL),
        @types.BufferUsages::storage(),
      )
    })
    is None,
  )
}

///|
test "a storage texture cannot be read in the same pass" {
  let scope = UsageScope::new()
  let texture = @types.TextureId::from_raw(7UL)
  scope.use_texture(texture, @types.TextureUsages::storage_binding())
  assert_eq(
    kind_of(fn() raise Refused {
      scope.use_texture(texture, @types.TextureUsages::texture_binding())
    }),
    Some(@types.InvalidTextureUsage),
  )
}

///|
test "a render attachment cannot be sampled in the same pass" {
  let scope = UsageScope::new()
  let texture = @types.TextureId::from_raw(7UL)
  scope.use_texture(texture, @types.TextureUsages::render_attachment())
  assert_eq(
    kind_of(fn() raise Refused {
      scope.use_texture(texture, @types.TextureUsages::texture_binding())
    }),
    Some(@types.InvalidTextureUsage),
  )
}

///|
test "sampling a texture twice in one pass is fine" {
  let scope = UsageScope::new()
  let texture = @types.TextureId::from_raw(7UL)
  scope.use_texture(texture, @types.TextureUsages::texture_binding())
  assert_true(
    kind_of(fn() raise Refused {
      scope.use_texture(texture, @types.TextureUsages::texture_binding())
    })
    is None,
  )
}
