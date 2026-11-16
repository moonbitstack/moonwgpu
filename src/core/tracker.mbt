// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The usages of the subresources one pass touches.
///
/// The specification validates usage compatibility per pass: a subresource used
/// writably in a pass cannot be used at all anywhere else in that same pass,
/// and one used read-only can only be read again. Copies and clears between
/// passes are separate steps and are not compared with each other.
/// https://www.w3.org/TR/webgpu/#programming-model "Usage scopes"
pub struct UsageScope {
  buffers : Map[UInt64, UInt32]
  textures : Map[UInt64, UInt32]
}

///|
/// A scope that has touched nothing yet.
pub fn UsageScope::new() -> UsageScope {
  { buffers: Map([]), textures: Map([]), }
}

///|
/// The buffer flags that write the resource.
fn buffer_write_bits() -> UInt32 {
  @types.BufferUsages::copy_dst().bits() |
  @types.BufferUsages::storage().bits() |
  @types.BufferUsages::map_write().bits()
}

///|
/// The texture flags that write the resource.
fn texture_write_bits() -> UInt32 {
  @types.TextureUsages::copy_dst().bits() |
  @types.TextureUsages::storage_binding().bits() |
  @types.TextureUsages::render_attachment().bits()
}

///|
/// Record a use of one buffer in this scope, refusing a conflict.
pub fn UsageScope::use_buffer(
  self : UsageScope,
  id : @types.BufferId,
  usage : @types.BufferUsages,
) -> Unit raise Refused {
  let bits = usage.bits()
  let previous = match self.buffers.get(id.raw()) {
    Some(bits) => bits
    None => 0U
  }
  if previous != 0U {
    let writes = buffer_write_bits()
    let conflict = (previous & writes) != 0U || (bits & writes) != 0U
    require(
      !conflict,
      @types.InvalidBufferUsage,
      "buffer \{id.raw()} in this pass",
      "one compatible usage per subresource in a pass",
      describe_usages(previous | bits, buffer_usage_names()),
    )
  }
  self.buffers[id.raw()] = previous | bits
}

///|
/// Record a use of one texture in this scope, refusing a conflict.
pub fn UsageScope::use_texture(
  self : UsageScope,
  id : @types.TextureId,
  usage : @types.TextureUsages,
) -> Unit raise Refused {
  let bits = usage.bits()
  let previous = match self.textures.get(id.raw()) {
    Some(bits) => bits
    None => 0U
  }
  if previous != 0U {
    let writes = texture_write_bits()
    let conflict = (previous & writes) != 0U || (bits & writes) != 0U
    require(
      !conflict,
      @types.InvalidTextureUsage,
      "texture \{id.raw()} in this pass",
      "one compatible usage per subresource in a pass",
      describe_usages(previous | bits, texture_usage_names()),
    )
  }
  self.textures[id.raw()] = previous | bits
}
