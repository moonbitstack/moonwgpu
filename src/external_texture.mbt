// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A frame a host decoded, held as a texture a bind group can name.
///
/// The specification calls the same object a `GPUExternalTexture`, and gives it
/// a lifetime as short as the frame it came from: after the frame is gone the
/// texture is *expired*, and using it is refused. A host that knows its frame
/// has moved on says so with `expire`.
/// https://www.w3.org/TR/webgpu/#gpuexternaltexture
pub struct ExternalTexture {
  device : Device
  id : @types.ExternalTextureId
  label : String
  descriptor : @types.ExternalTextureDescriptor
  mut expired : Bool
}

///|
/// The texture's identity inside its device.
pub fn ExternalTexture::id(self : ExternalTexture) -> @types.ExternalTextureId {
  self.id
}

///|
/// The texture's label.
pub fn ExternalTexture::label(self : ExternalTexture) -> String {
  self.label
}

///|
/// The frame and colour space the texture was imported with.
pub fn ExternalTexture::descriptor(
  self : ExternalTexture,
) -> @types.ExternalTextureDescriptor {
  self.descriptor
}

///|
/// The colour space the pixels are in, as recorded at import.
pub fn ExternalTexture::color_space(
  self : ExternalTexture,
) -> @types.PredefinedColorSpace {
  self.descriptor.color_space
}

///|
/// Whether the frame behind this texture has moved on.
pub fn ExternalTexture::is_expired(self : ExternalTexture) -> Bool {
  self.expired
}

///|
/// Mark the texture expired, as the specification's automatic expiry does when
/// the frame it came from is replaced.
pub fn ExternalTexture::expire(self : ExternalTexture) -> Unit {
  if !self.expired {
    self.expired = true
    self.device.hub.destroy_external_texture(self.id)
  }
}
