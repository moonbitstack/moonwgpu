// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The rules a `GPUTextureDescriptor` must satisfy.
/// https://www.w3.org/TR/webgpu/#dom-gpudevice-createtexture "validating
/// GPUTextureDescriptor".
pub fn validate_texture_descriptor(
  descriptor : @types.TextureDescriptor,
  limits : @types.Limits,
  features : @types.Features,
) -> Unit raise Refused {
  let bits = descriptor.usage.bits()
  require(
    bits != 0U,
    @types.InvalidTextureUsage,
    "descriptor.usage",
    "at least one flag",
    "none",
  )
  require(
    (bits & (0xFFFF_FFFFU ^ @types.TextureUsages::all().bits())) == 0U,
    @types.InvalidTextureUsage,
    "descriptor.usage",
    "only the flags GPUTextureUsage defines",
    describe_usages(bits, texture_usage_names()),
  )
  let size = descriptor.size
  require_int(
    size.width > 0,
    @types.InvalidTextureDimension,
    "descriptor.size.width",
    1,
    size.width,
  )
  require_int(
    size.height > 0,
    @types.InvalidTextureDimension,
    "descriptor.size.height",
    1,
    size.height,
  )
  require_int(
    size.depth_or_array_layers > 0,
    @types.InvalidTextureDimension,
    "descriptor.size.depthOrArrayLayers",
    1,
    size.depth_or_array_layers,
  )
  require_int(
    descriptor.mip_level_count > 0,
    @types.InvalidTextureDescriptor,
    "descriptor.mipLevelCount",
    1,
    descriptor.mip_level_count,
  )
  require(
    descriptor.sample_count == 1 || descriptor.sample_count == 4,
    @types.InvalidTextureSampleCount,
    "descriptor.sampleCount",
    "1 or 4",
    descriptor.sample_count.to_string(),
  )
  let info = descriptor.format.info()
  // A format that needs a feature cannot be used until that feature is on.
  match info.feature {
    Some(feature) =>
      require(
        features.contains(feature),
        @types.MissingFeature,
        "descriptor.format",
        feature.name(),
        "feature disabled",
      )
    None => ()
  }
  for view_format in descriptor.view_formats {
    match view_format.info().feature {
      Some(feature) =>
        require(
          features.contains(feature),
          @types.MissingFeature,
          "descriptor.viewFormats",
          feature.name(),
          "feature disabled",
        )
      None => ()
    }
  }
  let uncompressed_colour = info.block_width == 1 &&
    info.block_height == 1 &&
    info.aspect == @types.FormatAspect::Color
  match descriptor.dimension {
    @types.TextureDimension::D1 => {
      require_int(
        size.width <= limits.max_texture_dimension_1d,
        @types.LimitExceeded,
        "descriptor.size.width",
        limits.max_texture_dimension_1d,
        size.width,
      )
      require_int(
        size.height == 1,
        @types.InvalidTextureDimension,
        "descriptor.size.height",
        1,
        size.height,
      )
      require_int(
        size.depth_or_array_layers == 1,
        @types.InvalidTextureDimension,
        "descriptor.size.depthOrArrayLayers",
        1,
        size.depth_or_array_layers,
      )
      require_int(
        descriptor.sample_count == 1,
        @types.InvalidTextureSampleCount,
        "descriptor.sampleCount",
        1,
        descriptor.sample_count,
      )
      require(
        uncompressed_colour,
        @types.InvalidTextureFormat,
        "descriptor.format",
        "an uncompressed colour format",
        descriptor.format.name(),
      )
    }
    @types.TextureDimension::D2 => {
      require_int(
        size.width <= limits.max_texture_dimension_2d,
        @types.LimitExceeded,
        "descriptor.size.width",
        limits.max_texture_dimension_2d,
        size.width,
      )
      require_int(
        size.height <= limits.max_texture_dimension_2d,
        @types.LimitExceeded,
        "descriptor.size.height",
        limits.max_texture_dimension_2d,
        size.height,
      )
      require_int(
        size.depth_or_array_layers <= limits.max_texture_array_layers,
        @types.LimitExceeded,
        "descriptor.size.depthOrArrayLayers",
        limits.max_texture_array_layers,
        size.depth_or_array_layers,
      )
    }
    @types.TextureDimension::D3 => {
      require_int(
        size.width <= limits.max_texture_dimension_3d,
        @types.LimitExceeded,
        "descriptor.size.width",
        limits.max_texture_dimension_3d,
        size.width,
      )
      require_int(
        size.height <= limits.max_texture_dimension_3d,
        @types.LimitExceeded,
        "descriptor.size.height",
        limits.max_texture_dimension_3d,
        size.height,
      )
      require_int(
        size.depth_or_array_layers <= limits.max_texture_dimension_3d,
        @types.LimitExceeded,
        "descriptor.size.depthOrArrayLayers",
        limits.max_texture_dimension_3d,
        size.depth_or_array_layers,
      )
      require_int(
        descriptor.sample_count == 1,
        @types.InvalidTextureSampleCount,
        "descriptor.sampleCount",
        1,
        descriptor.sample_count,
      )
      require(
        uncompressed_colour,
        @types.InvalidTextureDimension,
        "descriptor.format",
        "a format that can be three-dimensional",
        descriptor.format.name(),
      )
    }
  }
  // A block-compressed size has to be a whole number of blocks unless the
  // feature that allows partial blocks is on.
  if !features.contains(@types.TextureCompressionUnaligned) {
    require_same(
      0,
      size.width % info.block_width,
      @types.InvalidTextureDimension,
      "descriptor.size.width",
    )
    require_same(
      0,
      size.height % info.block_height,
      @types.InvalidTextureDimension,
      "descriptor.size.height",
    )
  }
  if descriptor.sample_count > 1 {
    require_int(
      descriptor.mip_level_count == 1,
      @types.InvalidTextureDescriptor,
      "descriptor.mipLevelCount",
      1,
      descriptor.mip_level_count,
    )
    require_int(
      size.depth_or_array_layers == 1,
      @types.InvalidTextureDimension,
      "descriptor.size.depthOrArrayLayers",
      1,
      size.depth_or_array_layers,
    )
    require(
      (bits & @types.TextureUsages::storage_binding().bits()) == 0U,
      @types.InvalidTextureUsage,
      "descriptor.usage",
      "no STORAGE_BINDING on a multisampled texture",
      describe_usages(bits, texture_usage_names()),
    )
    require(
      (bits & @types.TextureUsages::render_attachment().bits()) != 0U,
      @types.InvalidTextureUsage,
      "descriptor.usage",
      "RENDER_ATTACHMENT on a multisampled texture",
      describe_usages(bits, texture_usage_names()),
    )
    require(
      info.multisample,
      @types.InvalidTextureSampleCount,
      "descriptor.format",
      "a format that supports multisampling",
      descriptor.format.name(),
    )
  }
  let maximum_mips = size.max_mip_level_count()
  require_int(
    descriptor.mip_level_count <= maximum_mips,
    @types.InvalidTextureDescriptor,
    "descriptor.mipLevelCount",
    maximum_mips,
    descriptor.mip_level_count,
  )
  if (bits & @types.TextureUsages::render_attachment().bits()) != 0U {
    // A depth or stencil format is renderable as a depth-stencil attachment
    // even though it is never a colour target.
    let renderable = info.render_attachment ||
      info.aspect != @types.FormatAspect::Color
    require(
      renderable,
      @types.InvalidTextureUsage,
      "descriptor.format",
      "a renderable format",
      descriptor.format.name(),
    )
    require(
      descriptor.dimension != @types.TextureDimension::D1,
      @types.InvalidTextureDimension,
      "descriptor.dimension",
      "2d or 3d with RENDER_ATTACHMENT",
      "1d",
    )
  }
  if (bits & @types.TextureUsages::storage_binding().bits()) != 0U {
    require(
      info.storage != @types.StorageAccess::None,
      @types.InvalidTextureUsage,
      "descriptor.format",
      "a format with a storage capability",
      descriptor.format.name(),
    )
  }
}

///|
/// The rules a `GPUTextureViewDescriptor` must satisfy against the texture it
/// views. https://www.w3.org/TR/webgpu/#dom-gputexture-createview "device
/// timeline initialization steps".
pub fn validate_texture_view_descriptor(
  texture : @types.TextureDescriptor,
  view : @types.TextureViewDescriptor,
  features : @types.Features,
) -> Unit raise Refused {
  let info = texture.format.info()
  match view.aspect {
    @types.TextureAspect::DepthOnly =>
      require(
        info.aspect == @types.FormatAspect::DepthOnly ||
        info.aspect == @types.FormatAspect::DepthStencil,
        @types.InvalidSubresource,
        "descriptor.aspect",
        "a format with a depth aspect",
        texture.format.name(),
      )
    @types.TextureAspect::StencilOnly =>
      require(
        info.aspect == @types.FormatAspect::StencilOnly ||
        info.aspect == @types.FormatAspect::DepthStencil,
        @types.InvalidSubresource,
        "descriptor.aspect",
        "a format with a stencil aspect",
        texture.format.name(),
      )
    @types.TextureAspect::All => ()
  }
  let aspect_format = resolve_aspect_format(texture.format, view.aspect)
  let format = match view.format {
    Some(format) => format
    None => aspect_format
  }
  match view.aspect {
    @types.TextureAspect::All => {
      let compatible = format == texture.format ||
        texture.view_formats.contains(format)
      require(
        compatible,
        @types.InvalidTextureViewDescriptor,
        "descriptor.format",
        "the texture format or one of its view formats",
        format.name(),
      )
    }
    _ =>
      require(
        format == aspect_format,
        @types.InvalidTextureViewDescriptor,
        "descriptor.format",
        aspect_format.name(),
        format.name(),
      )
  }
  let dimension = match view.dimension {
    Some(dimension) => dimension
    None =>
      match texture.dimension {
        @types.TextureDimension::D1 => @types.TextureViewDimension::D1
        @types.TextureDimension::D3 => @types.TextureViewDimension::D3
        @types.TextureDimension::D2 =>
          if texture.size.depth_or_array_layers == 1 {
            @types.TextureViewDimension::D2
          } else {
            @types.TextureViewDimension::D2Array
          }
      }
  }
  let layers_of_texture = array_layer_count_of_texture(texture)
  let layer_count = match view.array_layer_count {
    Some(count) => count
    None =>
      match dimension {
        @types.TextureViewDimension::D1
        | @types.TextureViewDimension::D2
        | @types.TextureViewDimension::D3 => 1
        @types.TextureViewDimension::Cube => 6
        @types.TextureViewDimension::D2Array
        | @types.TextureViewDimension::CubeArray =>
          layers_of_texture - view.base_array_layer
      }
  }
  // The base of the range has to exist before the range can be measured.
  require_int(
    view.base_mip_level >= 0 && view.base_mip_level < texture.mip_level_count,
    @types.InvalidSubresource,
    "descriptor.baseMipLevel",
    texture.mip_level_count - 1,
    view.base_mip_level,
  )
  require_int(
    view.base_array_layer >= 0 && view.base_array_layer < layers_of_texture,
    @types.InvalidSubresource,
    "descriptor.baseArrayLayer",
    layers_of_texture - 1,
    view.base_array_layer,
  )
  let mip_count = match view.mip_level_count {
    Some(count) => count
    None => texture.mip_level_count - view.base_mip_level
  }
  require_int(
    mip_count > 0,
    @types.InvalidTextureViewDescriptor,
    "descriptor.mipLevelCount",
    1,
    mip_count,
  )
  require_int(
    view.base_mip_level + mip_count <= texture.mip_level_count,
    @types.InvalidSubresource,
    "descriptor.baseMipLevel + descriptor.mipLevelCount",
    texture.mip_level_count,
    view.base_mip_level + mip_count,
  )
  require_int(
    layer_count > 0,
    @types.InvalidTextureViewDescriptor,
    "descriptor.arrayLayerCount",
    1,
    layer_count,
  )
  require_int(
    view.base_array_layer + layer_count <= layers_of_texture,
    @types.InvalidSubresource,
    "descriptor.baseArrayLayer + descriptor.arrayLayerCount",
    layers_of_texture,
    view.base_array_layer + layer_count,
  )
  if texture.sample_count > 1 {
    require(
      dimension == @types.TextureViewDimension::D2,
      @types.InvalidTextureViewDescriptor,
      "descriptor.dimension",
      "2d for a multisampled texture",
      "another dimension",
    )
  }
  match dimension {
    @types.TextureViewDimension::D1 => {
      require(
        texture.dimension == @types.TextureDimension::D1,
        @types.InvalidTextureViewDescriptor,
        "descriptor.dimension",
        "1d over a 1d texture",
        "over another texture",
      )
      require_same(
        1,
        layer_count,
        @types.InvalidTextureViewDescriptor,
        "descriptor.arrayLayerCount",
      )
    }
    @types.TextureViewDimension::D2 => {
      require(
        texture.dimension == @types.TextureDimension::D2,
        @types.InvalidTextureViewDescriptor,
        "descriptor.dimension",
        "2d over a 2d texture",
        "over another texture",
      )
      require_same(
        1,
        layer_count,
        @types.InvalidTextureViewDescriptor,
        "descriptor.arrayLayerCount",
      )
    }
    @types.TextureViewDimension::D2Array =>
      require(
        texture.dimension == @types.TextureDimension::D2,
        @types.InvalidTextureViewDescriptor,
        "descriptor.dimension",
        "2d-array over a 2d texture",
        "over another texture",
      )
    @types.TextureViewDimension::Cube => {
      require(
        texture.dimension == @types.TextureDimension::D2,
        @types.InvalidTextureViewDescriptor,
        "descriptor.dimension",
        "cube over a 2d texture",
        "over another texture",
      )
      require_same(
        6,
        layer_count,
        @types.InvalidTextureViewDescriptor,
        "descriptor.arrayLayerCount",
      )
      require_same(
        texture.size.height,
        texture.size.width,
        @types.InvalidTextureViewDescriptor,
        "descriptor.dimension",
      )
    }
    @types.TextureViewDimension::CubeArray => {
      require(
        texture.dimension == @types.TextureDimension::D2,
        @types.InvalidTextureViewDescriptor,
        "descriptor.dimension",
        "cube-array over a 2d texture",
        "over another texture",
      )
      require(
        features.contains(@types.CoreFeaturesAndLimits),
        @types.MissingFeature,
        "descriptor.dimension",
        "core-features-and-limits",
        "feature disabled",
      )
      require_same(
        0,
        layer_count % 6,
        @types.InvalidSubresource,
        "descriptor.arrayLayerCount",
      )
      require_same(
        texture.size.height,
        texture.size.width,
        @types.InvalidTextureViewDescriptor,
        "descriptor.dimension",
      )
    }
    @types.TextureViewDimension::D3 => {
      require(
        texture.dimension == @types.TextureDimension::D3,
        @types.InvalidTextureViewDescriptor,
        "descriptor.dimension",
        "3d over a 3d texture",
        "over another texture",
      )
      require_same(
        1,
        layer_count,
        @types.InvalidTextureViewDescriptor,
        "descriptor.arrayLayerCount",
      )
    }
  }
  match view.usage {
    Some(usage) =>
      require(
        texture.usage.contains(usage),
        @types.InvalidTextureViewDescriptor,
        "descriptor.usage",
        "a subset of the texture's usages",
        "a wider set",
      )
    None => ()
  }
}

///|
/// The format of one aspect of a texture format: a single-aspect view of a
/// depth-stencil format has the aspect's own format.
pub fn resolve_aspect_format(
  format : @types.TextureFormat,
  aspect : @types.TextureAspect,
) -> @types.TextureFormat {
  match aspect {
    @types.TextureAspect::All => format
    @types.TextureAspect::StencilOnly => @types.TextureFormat::Stencil8
    @types.TextureAspect::DepthOnly =>
      match format {
        @types.TextureFormat::Depth32floatStencil8 =>
          @types.TextureFormat::Depth32float
        _ => format
      }
  }
}

///|
/// A 1d or 3d texture has one array layer; a 2d texture has one per element of
/// `depthOrArrayLayers`.
pub fn array_layer_count_of_texture(
  texture : @types.TextureDescriptor,
) -> Int32 {
  match texture.dimension {
    @types.TextureDimension::D1 | @types.TextureDimension::D3 => 1
    @types.TextureDimension::D2 => texture.size.depth_or_array_layers
  }
}

///|
/// The rules a `GPUSamplerDescriptor` must satisfy.
/// https://www.w3.org/TR/webgpu/#dom-gpudevice-createsampler
pub fn validate_sampler_descriptor(
  descriptor : @types.SamplerDescriptor,
) -> Unit raise Refused {
  require(
    descriptor.lod_min_clamp >= 0.0,
    @types.InvalidSamplerDescriptor,
    "descriptor.lodMinClamp",
    "at least 0",
    descriptor.lod_min_clamp.to_string(),
  )
  require(
    descriptor.lod_max_clamp >= descriptor.lod_min_clamp,
    @types.InvalidSamplerDescriptor,
    "descriptor.lodMaxClamp",
    "at least descriptor.lodMinClamp",
    descriptor.lod_max_clamp.to_string(),
  )
  require_int(
    descriptor.max_anisotropy >= 1,
    @types.InvalidSamplerDescriptor,
    "descriptor.maxAnisotropy",
    1,
    descriptor.max_anisotropy,
  )
  if descriptor.max_anisotropy > 1 {
    require(
      descriptor.mag_filter == @types.FilterMode::Linear &&
      descriptor.min_filter == @types.FilterMode::Linear &&
      descriptor.mipmap_filter == @types.FilterMode::Linear,
      @types.InvalidSamplerDescriptor,
      "descriptor.maxAnisotropy",
      "linear filters when above 1",
      "a nearest filter",
    )
  }
}
