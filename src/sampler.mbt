// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A sampler: how a shader reads a texture, and how it reads between texels.
pub struct Sampler {
  device : Device
  id : @types.SamplerId
  descriptor : @types.SamplerDescriptor
}

///|
/// The sampler's identity inside its device.
pub fn Sampler::id(self : Sampler) -> @types.SamplerId {
  self.id
}

///|
/// The descriptor the sampler was created from.
pub fn Sampler::descriptor(self : Sampler) -> @types.SamplerDescriptor {
  self.descriptor
}

///|
/// Whether any of the filters interpolates, which decides whether the sampler
/// may fill a `filtering` slot of a bind group layout.
pub fn Sampler::is_filtering(self : Sampler) -> Bool {
  self.descriptor.mag_filter == @types.FilterMode::Linear ||
  self.descriptor.min_filter == @types.FilterMode::Linear ||
  self.descriptor.mipmap_filter == @types.FilterMode::Linear
}

///|
/// Whether the sampler compares against a reference value instead of returning
/// texels.
pub fn Sampler::is_comparison(self : Sampler) -> Bool {
  match self.descriptor.compare {
    Some(_) => true
    None => false
  }
}
