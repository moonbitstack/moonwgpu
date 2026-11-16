// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The buffer rules, one condition per test. Each name says which condition of
// "device timeline initialization steps" of createBuffer it checks.
// https://www.w3.org/TR/webgpu/#dom-gpudevice-createbuffer

///|
test "a buffer with one usage bit is accepted" {
  assert_true(
    kind_of(fn() raise Refused {
      validate_buffer_descriptor(
        buffer_descriptor(16, @types.BufferUsages::vertex()),
        webgpu_limits,
      )
    })
    is None,
  )
}

///|
test "an empty usage set is refused" {
  assert_eq(
    kind_of(fn() raise Refused {
      validate_buffer_descriptor(
        buffer_descriptor(16, @types.BufferUsages::none()),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidBufferUsage),
  )
}

///|
test "map read may only be combined with copy destination" {
  let allowed = @types.BufferUsages::map_read() |
    @types.BufferUsages::copy_dst()
  assert_true(
    kind_of(fn() raise Refused {
      validate_buffer_descriptor(buffer_descriptor(16, allowed), webgpu_limits)
    })
    is None,
  )
  let refused = @types.BufferUsages::map_read() | @types.BufferUsages::vertex()
  assert_eq(
    kind_of(fn() raise Refused {
      validate_buffer_descriptor(buffer_descriptor(16, refused), webgpu_limits)
    }),
    Some(@types.InvalidBufferUsage),
  )
}

///|
test "map write may only be combined with copy source" {
  let allowed = @types.BufferUsages::map_write() |
    @types.BufferUsages::copy_src()
  assert_true(
    kind_of(fn() raise Refused {
      validate_buffer_descriptor(buffer_descriptor(16, allowed), webgpu_limits)
    })
    is None,
  )
  let refused = @types.BufferUsages::map_write() |
    @types.BufferUsages::storage()
  assert_eq(
    kind_of(fn() raise Refused {
      validate_buffer_descriptor(buffer_descriptor(16, refused), webgpu_limits)
    }),
    Some(@types.InvalidBufferUsage),
  )
}

///|
test "a size above maxBufferSize is refused" {
  assert_eq(
    kind_of(fn() raise Refused {
      validate_buffer_descriptor(
        buffer_descriptor(
          webgpu_limits.max_buffer_size + 4,
          @types.BufferUsages::storage(),
        ),
        webgpu_limits,
      )
    }),
    Some(@types.LimitExceeded),
  )
}

///|
test "a negative size is refused" {
  assert_eq(
    kind_of(fn() raise Refused {
      validate_buffer_descriptor(
        buffer_descriptor(-4, @types.BufferUsages::storage()),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidBufferSize),
  )
}

///|
test "a mapped buffer has to be a whole number of four byte words" {
  assert_true(
    kind_of(fn() raise Refused {
      validate_buffer_descriptor(
        @types.BufferDescriptor::new(
          size=16,
          usage=@types.BufferUsages::map_write(),
          mapped_at_creation=true,
        ),
        webgpu_limits,
      )
    })
    is None,
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_buffer_descriptor(
        @types.BufferDescriptor::new(
          size=18,
          usage=@types.BufferUsages::map_write(),
          mapped_at_creation=true,
        ),
        webgpu_limits,
      )
    }),
    Some(@types.InvalidBufferSize),
  )
}

///|
test "a buffer range has to stay inside the buffer" {
  assert_true(
    kind_of(fn() raise Refused { validate_buffer_range(64, 32, 32, "source") })
    is None,
  )
  assert_eq(
    kind_of(fn() raise Refused { validate_buffer_range(64, 32, 36, "source") }),
    Some(@types.InvalidCopyRange),
  )
  assert_eq(
    kind_of(fn() raise Refused { validate_buffer_range(64, -4, 4, "source") }),
    Some(@types.InvalidCopyRange),
  )
}
