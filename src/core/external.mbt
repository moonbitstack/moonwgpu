// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// External textures: a frame a host decoded, held as something a bind group
// can name. The specification's source is a video element; a native host hands
// over the pixels instead, which is the same thing one step later.

///|
/// An external texture as the device keeps it.
pub struct ExternalTextureState {
  descriptor : @types.ExternalTextureDescriptor
  mut destroyed : Bool
}

///|
/// `importExternalTexture`: take a decoded frame and hold it as a texture.
///
/// The bytes must be there in full: the frame is copied when it is imported,
/// so that a host may reuse its buffer as soon as this call returns.
/// https://www.w3.org/TR/webgpu/#dom-gpudevice-importexternaltexture
pub fn Hub::import_external_texture(
  self : Hub,
  descriptor : @types.ExternalTextureDescriptor,
) -> @types.ExternalTextureId raise Refused {
  self.ensure_alive()
  let image = descriptor.image
  require_int(
    image.size.width > 0,
    @types.InvalidResource,
    "descriptor.source.width",
    1,
    image.size.width,
  )
  require_int(
    image.size.height > 0,
    @types.InvalidResource,
    "descriptor.source.height",
    1,
    image.size.height,
  )
  let needed = image.row_bytes() *
    image.size.height *
    image.size.depth_or_array_layers
  require_int(
    image.data.length() >= needed,
    @types.InvalidCopyRange,
    "descriptor.source",
    needed,
    image.data.length(),
  )
  let id = self.backend.create_external_texture(descriptor) catch {
    error => raise self.report(Refused::from_hal(error))
  }
  self.external_textures[id.raw()] = { descriptor, destroyed: false, }
  id
}

///|
/// An external texture this device imported and the caller has not released.
pub fn Hub::external_texture(
  self : Hub,
  id : @types.ExternalTextureId,
) -> ExternalTextureState raise Refused {
  match self.external_textures.get(id.raw()) {
    Some(state) =>
      if state.destroyed {
        raise invalid(
          @types.InvalidResource,
          "externalTexture",
          "a live external texture",
          "a released external texture",
        )
      } else {
        state
      }
    None =>
      raise invalid(
        @types.InvalidResource,
        "externalTexture",
        "an external texture of this device",
        id.raw().to_string(),
      )
  }
}

///|
/// Release an external texture. A frame a host has moved on from is released
/// the same way.
pub fn Hub::destroy_external_texture(
  self : Hub,
  id : @types.ExternalTextureId,
) -> Unit {
  match self.external_textures.get(id.raw()) {
    Some(state) => {
      state.destroyed = true
      self.backend.destroy_external_texture(id)
    }
    None => ()
  }
}

///|
/// Whether a texture format can be the destination of an external image copy.
/// The specification lists exactly these five.
fn is_external_copy_format(format : @types.TextureFormat) -> Bool {
  match format {
    @types.TextureFormat::Rgba8unorm
    | @types.TextureFormat::Rgba8unormSrgb
    | @types.TextureFormat::Bgra8unorm
    | @types.TextureFormat::Bgra8unormSrgb
    | @types.TextureFormat::Rgba16float => true
    _ => false
  }
}

///|
/// Whether a format holds colour in eight-bit channels, which is the only case
/// in which this library premultiplies alpha itself.
fn is_eight_bit_colour(format : @types.TextureFormat) -> Bool {
  match format {
    @types.TextureFormat::Rgba8unorm
    | @types.TextureFormat::Rgba8unormSrgb
    | @types.TextureFormat::Bgra8unorm
    | @types.TextureFormat::Bgra8unormSrgb => true
    _ => false
  }
}

///|
/// Multiply the colour channels of one eight-bit row by its alpha channel.
///
/// `alpha_at` is the index of the alpha byte in one texel, which is the fourth
/// in both `rgba8` and `bgra8`; the three colour bytes are the first three.
fn premultiply_row(row : Array[Byte]) -> Unit {
  let mut at = 0
  while at + 4 <= row.length() {
    let alpha = row[at + 3].to_int()
    if alpha < 255 {
      for channel in 0..<3 {
        let value = row[at + channel].to_int()
        row[at + channel] = ((value * alpha + 127) / 255).to_byte()
      }
    }
    at = at + 4
  }
}

///|
/// `copyExternalImageToTexture`: put the pixels of a frame into a texture,
/// turning them over when the host's rows are bottom-first, and premultiplying
/// alpha when the caller asks for it.
///
/// Colour space conversion is the host's: the bytes are copied as they are, and
/// the colour space is recorded with them.
/// https://www.w3.org/TR/webgpu/#dom-gpuqueue-copyexternalimagetotexture
pub fn Hub::copy_external_image_to_texture(
  self : Hub,
  source : @types.CopyExternalImageSourceInfo,
  destination : @types.CopyExternalImageDestInfo,
  copy_size : @types.Extent3d,
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
    is_external_copy_format(texture.descriptor.format),
    @types.InvalidTextureFormat,
    "destination.texture.format",
    "rgba8unorm, rgba8unorm-srgb, bgra8unorm, bgra8unorm-srgb or rgba16float",
    texture.descriptor.format.name(),
  )
  require_int(
    texture.descriptor.sample_count == 1,
    @types.InvalidTextureSampleCount,
    "destination.texture.sampleCount",
    1,
    texture.descriptor.sample_count,
  )
  require(
    !destination.premultiplied_alpha ||
    is_eight_bit_colour(texture.descriptor.format),
    @types.InvalidTextureFormat,
    "destination.premultipliedAlpha",
    "a format whose colour is eight bits wide",
    texture.descriptor.format.name(),
  )
  let image = source.image
  let region = texture.descriptor.size.physical_size(
    mip_level=destination.mip_level,
    format=texture.descriptor.format,
  )
  require_int(
    copy_size.width > 0 &&
    copy_size.height > 0 &&
    copy_size.depth_or_array_layers > 0,
    @types.InvalidCopyRange,
    "copySize",
    1,
    if copy_size.width < copy_size.height {
      copy_size.width
    } else {
      copy_size.height
    },
  )
  require_int(
    destination.origin.x + copy_size.width <= region.width,
    @types.InvalidCopyRange,
    "destination.origin.x + copySize.width",
    region.width,
    destination.origin.x + copy_size.width,
  )
  require_int(
    destination.origin.y + copy_size.height <= region.height,
    @types.InvalidCopyRange,
    "destination.origin.y + copySize.height",
    region.height,
    destination.origin.y + copy_size.height,
  )
  require_int(
    destination.origin.z + copy_size.depth_or_array_layers <=
    region.depth_or_array_layers,
    @types.InvalidCopyRange,
    "destination.origin.z + copySize.depthOrArrayLayers",
    region.depth_or_array_layers,
    destination.origin.z + copy_size.depth_or_array_layers,
  )
  require_int(
    source.origin.x + copy_size.width <= image.size.width,
    @types.InvalidCopyRange,
    "source.origin.x + copySize.width",
    image.size.width,
    source.origin.x + copy_size.width,
  )
  require_int(
    source.origin.y + copy_size.height <= image.size.height,
    @types.InvalidCopyRange,
    "source.origin.y + copySize.height",
    image.size.height,
    source.origin.y + copy_size.height,
  )
  let destination_row = texture.descriptor.format.bytes_per_row(
    width=copy_size.width,
  )
  let source_row = image.format.bytes_per_row(width=copy_size.width)
  require_same(
    destination_row,
    source_row,
    @types.InvalidTextureFormat,
    "descriptor.source.format",
  )
  let image_stride = image.row_bytes()
  for z in 0..<copy_size.depth_or_array_layers {
    for y in 0..<copy_size.height {
      let source_line = if source.flip_y {
        source.origin.y + copy_size.height - 1 - y
      } else {
        source.origin.y + y
      }
      let at = source_line * image_stride +
        image.format.bytes_per_row(width=source.origin.x)
      let row = []
      for i in 0..<source_row {
        row.push(image.data[at + i])
      }
      if destination.premultiplied_alpha {
        premultiply_row(row)
      }
      self.backend.write_texture(
        destination.texture,
        @types.Origin3d::new(
          x=destination.origin.x,
          y=destination.origin.y + y,
          z=destination.origin.z + z,
        ),
        @types.Extent3d::new(width=copy_size.width, height=1),
        destination.mip_level,
        Bytes::from_array(row),
      ) catch {
        error => raise self.report(Refused::from_hal(error))
      }
    }
  }
}
