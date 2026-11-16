// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A texture: texels in a format, with mip levels and array layers.
pub struct Texture {
  device : Device
  id : @types.TextureId
  descriptor : @types.TextureDescriptor
  mut destroyed : Bool
}

///|
/// The texture's identity inside its device.
pub fn Texture::id(self : Texture) -> @types.TextureId {
  self.id
}

///|
/// The size the texture was created with, in texels.
pub fn Texture::size(self : Texture) -> @types.Extent3d {
  self.descriptor.size
}

///|
/// The texel format.
pub fn Texture::format(self : Texture) -> @types.TextureFormat {
  self.descriptor.format
}

///|
/// The usages the texture was created with.
pub fn Texture::usage(self : Texture) -> @types.TextureUsages {
  self.descriptor.usage
}

///|
/// How many mip levels the texture has.
pub fn Texture::mip_level_count(self : Texture) -> Int32 {
  self.descriptor.mip_level_count
}

///|
/// How many samples each texel has.
pub fn Texture::sample_count(self : Texture) -> Int32 {
  self.descriptor.sample_count
}

///|
/// The texture's dimension.
pub fn Texture::dimension(self : Texture) -> @types.TextureDimension {
  self.descriptor.dimension
}

///|
/// A view of the texture.
/// https://www.w3.org/TR/webgpu/#dom-gputexture-createview
pub fn Texture::create_view(
  self : Texture,
  descriptor~ : @types.TextureViewDescriptor = @types.TextureViewDescriptor::new(),
) -> TextureView raise @core.Refused {
  @core.require(
    !self.destroyed,
    @types.InvalidResource,
    "texture",
    "a live texture",
    "a destroyed texture",
  )
  let id = self.device.hub.create_texture_view(self.id, descriptor)
  let format = match descriptor.format {
    Some(format) => format
    None =>
      @core.resolve_aspect_format(self.descriptor.format, descriptor.aspect)
  }
  let dimension = match descriptor.dimension {
    Some(dimension) => dimension
    None =>
      match self.descriptor.dimension {
        @types.TextureDimension::D1 => @types.TextureViewDimension::D1
        @types.TextureDimension::D3 => @types.TextureViewDimension::D3
        @types.TextureDimension::D2 =>
          if self.descriptor.size.depth_or_array_layers == 1 {
            @types.TextureViewDimension::D2
          } else {
            @types.TextureViewDimension::D2Array
          }
      }
  }
  { device: self.device, id, texture: self.id, format, dimension, }
}

///|
/// Destroy the texture. Later uses are refused.
pub fn Texture::destroy(self : Texture) -> Unit {
  if !self.destroyed {
    self.destroyed = true
    self.device.hub.destroy_texture(self.id)
  }
}

///|
/// A view of a texture: what a bind group entry or an attachment names.
pub struct TextureView {
  device : Device
  id : @types.TextureViewId
  texture : @types.TextureId
  format : @types.TextureFormat
  dimension : @types.TextureViewDimension
}

///|
/// The view's identity inside its device.
pub fn TextureView::id(self : TextureView) -> @types.TextureViewId {
  self.id
}

///|
/// The format the view reads the texture as.
pub fn TextureView::format(self : TextureView) -> @types.TextureFormat {
  self.format
}

///|
/// The dimension the view reads the texture as.
pub fn TextureView::dimension(
  self : TextureView,
) -> @types.TextureViewDimension {
  self.dimension
}

///|
/// The texture the view stands on.
pub fn TextureView::texture(self : TextureView) -> @types.TextureId {
  self.texture
}
