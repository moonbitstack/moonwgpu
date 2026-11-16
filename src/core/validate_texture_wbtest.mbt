// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The texture, view and sampler rules. The section names in these test names
// are the ones in "validating GPUTextureDescriptor", "device timeline
// initialization steps" of createView, and createSampler.

///|
test "a plain two dimensional texture is accepted" {
  assert_true(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        texture_descriptor(
          16,
          16,
          @types.TextureFormat::Rgba8unorm,
          @types.TextureUsages::texture_binding(),
        ),
        webgpu_limits,
        no_features(),
      )
    })
    is None,
  )
}

///|
test "an empty usage set is refused" {
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        texture_descriptor(
          1,
          1,
          @types.TextureFormat::Rgba8unorm,
          @types.TextureUsages::none(),
        ),
        webgpu_limits,
        no_features(),
      )
    }),
    Some(@types.InvalidTextureUsage),
  )
}

///|
test "a zero dimension is refused" {
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        texture_descriptor(
          0,
          4,
          @types.TextureFormat::Rgba8unorm,
          @types.TextureUsages::texture_binding(),
        ),
        webgpu_limits,
        no_features(),
      )
    }),
    Some(@types.InvalidTextureDimension),
  )
}

///|
test "a sample count other than one or four is refused" {
  let descriptor = {
    ..texture_descriptor(
      4,
      4,
      @types.TextureFormat::Rgba8unorm,
      @types.TextureUsages::render_attachment(),
    ),
    sample_count: 2,
  }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        descriptor,
        webgpu_limits,
        @types.Features::none(),
      )
    }),
    Some(@types.InvalidTextureSampleCount),
  )
}

///|
test "a mip count above what the size allows is refused" {
  let descriptor = {
    ..texture_descriptor(
      4,
      4,
      @types.TextureFormat::Rgba8unorm,
      @types.TextureUsages::texture_binding(),
    ),
    mip_level_count: 4,
  }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        descriptor,
        webgpu_limits,
        @types.Features::none(),
      )
    }),
    Some(@types.InvalidTextureDescriptor),
  )
  let accepted = { ..descriptor, mip_level_count: 3, }
  assert_true(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        accepted,
        webgpu_limits,
        @types.Features::none(),
      )
    })
    is None,
  )
}

///|
test "a one dimensional texture has one row and one layer" {
  let descriptor = {
    ..texture_descriptor(
      4,
      4,
      @types.TextureFormat::Rgba8unorm,
      @types.TextureUsages::texture_binding(),
    ),
    dimension: @types.TextureDimension::D1,
  }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        descriptor,
        webgpu_limits,
        @types.Features::none(),
      )
    }),
    Some(@types.InvalidTextureDimension),
  )
}

///|
test "a one dimensional texture cannot be a depth format" {
  let descriptor = @types.TextureDescriptor::new(
    size=@types.Extent3d::new(width=4),
    format=@types.TextureFormat::Depth32float,
    usage=@types.TextureUsages::texture_binding(),
    dimension=@types.TextureDimension::D1,
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        descriptor,
        webgpu_limits,
        @types.Features::none(),
      )
    }),
    Some(@types.InvalidTextureFormat),
  )
}

///|
test "a multisampled texture must be a render attachment of one mip" {
  let base = texture_descriptor(
    4,
    4,
    @types.TextureFormat::Rgba8unorm,
    @types.TextureUsages::render_attachment(),
  )
  let multisampled = { ..base, sample_count: 4, }
  assert_true(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        multisampled,
        webgpu_limits,
        @types.Features::none(),
      )
    })
    is None,
  )
  let with_storage = {
    ..multisampled,
    usage: @types.TextureUsages::render_attachment() |
    @types.TextureUsages::storage_binding(),
  }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        with_storage,
        webgpu_limits,
        @types.Features::none(),
      )
    }),
    Some(@types.InvalidTextureUsage),
  )
  let two_mips = { ..multisampled, mip_level_count: 2, }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        two_mips,
        webgpu_limits,
        @types.Features::none(),
      )
    }),
    Some(@types.InvalidTextureDescriptor),
  )
}

///|
test "a multisampled texture of a format without multisampling is refused" {
  let descriptor = {
    ..texture_descriptor(
      4,
      4,
      @types.TextureFormat::Rgba32float,
      @types.TextureUsages::render_attachment(),
    ),
    sample_count: 4,
  }
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        descriptor,
        webgpu_limits,
        @types.Features::none(),
      )
    }),
    Some(@types.InvalidTextureSampleCount),
  )
}

///|
test "a render attachment has to be a renderable format" {
  let descriptor = texture_descriptor(
    4,
    4,
    @types.TextureFormat::Rgba8snorm,
    @types.TextureUsages::render_attachment(),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        descriptor,
        webgpu_limits,
        @types.Features::none(),
      )
    }),
    Some(@types.InvalidTextureUsage),
  )
}

///|
test "a storage binding has to be a storage format" {
  let descriptor = texture_descriptor(
    4,
    4,
    @types.TextureFormat::Rgba8unormSrgb,
    @types.TextureUsages::storage_binding(),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        descriptor,
        webgpu_limits,
        @types.Features::none(),
      )
    }),
    Some(@types.InvalidTextureUsage),
  )
}

///|
test "a compressed format needs its feature" {
  let descriptor = texture_descriptor(
    4,
    4,
    @types.TextureFormat::Bc1RgbaUnorm,
    @types.TextureUsages::texture_binding(),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(
        descriptor,
        webgpu_limits,
        @types.Features::none(),
      )
    }),
    Some(@types.MissingFeature),
  )
  let enabled = @types.Features::of(@types.TextureCompressionBc)
  assert_true(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(descriptor, webgpu_limits, enabled)
    })
    is None,
  )
}

///|
test "a compressed size has to be whole blocks" {
  let descriptor = texture_descriptor(
    5,
    4,
    @types.TextureFormat::Bc1RgbaUnorm,
    @types.TextureUsages::texture_binding(),
  )
  let enabled = @types.Features::of(@types.TextureCompressionBc)
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(descriptor, webgpu_limits, enabled)
    }),
    Some(@types.InvalidTextureDimension),
  )
  let unaligned = enabled |
    @types.Features::of(@types.TextureCompressionUnaligned)
  assert_true(
    kind_of(fn() raise Refused {
      validate_texture_descriptor(descriptor, webgpu_limits, unaligned)
    })
    is None,
  )
}

///|
test "a view of one aspect takes that aspect's format" {
  let source = @types.TextureDescriptor::new(
    size=@types.Extent3d::new(width=4, height=4),
    format=@types.TextureFormat::Depth24plusStencil8,
    usage=@types.TextureUsages::texture_binding(),
  )
  let stencil = @types.TextureViewDescriptor::new(
    aspect=@types.TextureAspect::StencilOnly,
  )
  assert_true(
    kind_of(fn() raise Refused {
      validate_texture_view_descriptor(source, stencil, @types.Features::none())
    })
    is None,
  )
  let wrong = @types.TextureViewDescriptor::new(
    aspect=@types.TextureAspect::StencilOnly,
    format=@types.TextureFormat::Depth24plus,
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_view_descriptor(source, wrong, @types.Features::none())
    }),
    Some(@types.InvalidTextureViewDescriptor),
  )
}

///|
test "a view cannot reach past the last mip level" {
  let source = texture_descriptor(
    4,
    4,
    @types.TextureFormat::Rgba8unorm,
    @types.TextureUsages::texture_binding(),
  )
  let view = @types.TextureViewDescriptor::new(base_mip_level=1)
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_view_descriptor(source, view, @types.Features::none())
    }),
    Some(@types.InvalidSubresource),
  )
}

///|
test "a view cannot reach past the last array layer" {
  let source = @types.TextureDescriptor::new(
    size=@types.Extent3d::new(width=4, height=4, depth_or_array_layers=2),
    format=@types.TextureFormat::Rgba8unorm,
    usage=@types.TextureUsages::texture_binding(),
  )
  let view = @types.TextureViewDescriptor::new(
    base_array_layer=1,
    array_layer_count=2,
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_view_descriptor(source, view, @types.Features::none())
    }),
    Some(@types.InvalidSubresource),
  )
}

///|
test "a cube view covers six square layers" {
  let source = @types.TextureDescriptor::new(
    size=@types.Extent3d::new(width=4, height=4, depth_or_array_layers=6),
    format=@types.TextureFormat::Rgba8unorm,
    usage=@types.TextureUsages::texture_binding(),
  )
  let cube = @types.TextureViewDescriptor::new(
    dimension=@types.TextureViewDimension::Cube,
  )
  assert_true(
    kind_of(fn() raise Refused {
      validate_texture_view_descriptor(source, cube, @types.Features::none())
    })
    is None,
  )
  let not_square = @types.TextureDescriptor::new(
    size=@types.Extent3d::new(width=4, height=2, depth_or_array_layers=6),
    format=@types.TextureFormat::Rgba8unorm,
    usage=@types.TextureUsages::texture_binding(),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_view_descriptor(
        not_square,
        cube,
        @types.Features::none(),
      )
    }),
    Some(@types.InvalidTextureViewDescriptor),
  )
}

///|
test "a two dimensional view of a multisampled texture is the only one allowed" {
  let source = @types.TextureDescriptor::new(
    size=@types.Extent3d::new(width=4, height=4, depth_or_array_layers=2),
    format=@types.TextureFormat::Rgba8unorm,
    usage=@types.TextureUsages::render_attachment(),
    sample_count=4,
  )
  let array = @types.TextureViewDescriptor::new(
    dimension=@types.TextureViewDimension::D2Array,
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_texture_view_descriptor(source, array, @types.Features::none())
    }),
    Some(@types.InvalidTextureViewDescriptor),
  )
}

///|
test "the sampler rules" {
  assert_true(
    kind_of(fn() raise Refused {
      validate_sampler_descriptor(@types.SamplerDescriptor::new())
    })
    is None,
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_sampler_descriptor(
        @types.SamplerDescriptor::new(lod_min_clamp=-1.0),
      )
    }),
    Some(@types.InvalidSamplerDescriptor),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_sampler_descriptor(
        @types.SamplerDescriptor::new(lod_min_clamp=4.0, lod_max_clamp=2.0),
      )
    }),
    Some(@types.InvalidSamplerDescriptor),
  )
  assert_eq(
    kind_of(fn() raise Refused {
      validate_sampler_descriptor(
        @types.SamplerDescriptor::new(max_anisotropy=0),
      )
    }),
    Some(@types.InvalidSamplerDescriptor),
  )
  // Anisotropy above one is only defined for linear filters.
  assert_eq(
    kind_of(fn() raise Refused {
      validate_sampler_descriptor(
        @types.SamplerDescriptor::new(max_anisotropy=4),
      )
    }),
    Some(@types.InvalidSamplerDescriptor),
  )
  assert_true(
    kind_of(fn() raise Refused {
      validate_sampler_descriptor(
        @types.SamplerDescriptor::new(
          max_anisotropy=4,
          mag_filter=@types.FilterMode::Linear,
          min_filter=@types.FilterMode::Linear,
          mipmap_filter=@types.FilterMode::Linear,
        ),
      )
    })
    is None,
  )
}
