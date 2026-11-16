// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A finished command buffer: the commands one encoder recorded, ready for
/// `queue.submit`.
#derive(Debug)
pub(all) struct CommandBuffer {
  label : String
  commands : Array[@types.Command]
}

///|
/// Records commands into a command buffer.
///
/// The encoder validates what it can while recording - that a pass has ended
/// before the next command, that the encoder is not finished - and leaves the
/// rules about resources to the queue, which sees the whole batch at once. The
/// specification makes the same split: encoding is per command, validation of
/// what a command names is per submit.
pub struct CommandEncoder {
  device : Device
  frame : @core.Frame
  label : String
}

///|
/// The encoder's label.
pub fn CommandEncoder::label(self : CommandEncoder) -> String {
  self.label
}

///|
/// `copyBufferToBuffer`.
/// https://www.w3.org/TR/webgpu/#dom-gpucommandencoder-copybuffertobuffer
pub fn CommandEncoder::copy_buffer_to_buffer(
  self : CommandEncoder,
  source~ : Buffer,
  source_offset~ : Int32,
  destination~ : Buffer,
  destination_offset~ : Int32,
  size~ : Int32,
) -> Unit raise @core.Refused {
  self.frame.record(
    @types.Command::CopyBufferToBuffer({
      source: source.id,
      source_offset,
      destination: destination.id,
      destination_offset,
      size,
    }),
  )
}

///|
/// `copyBufferToTexture`.
pub fn CommandEncoder::copy_buffer_to_texture(
  self : CommandEncoder,
  source~ : @types.TexelCopyBufferInfo,
  destination~ : @types.TexelCopyTextureInfo,
  copy_size~ : @types.Extent3d,
) -> Unit raise @core.Refused {
  self.frame.record(
    @types.Command::CopyBufferToTexture({ source, destination, copy_size, }),
  )
}

///|
/// `copyTextureToBuffer`.
pub fn CommandEncoder::copy_texture_to_buffer(
  self : CommandEncoder,
  source~ : @types.TexelCopyTextureInfo,
  destination~ : @types.TexelCopyBufferInfo,
  copy_size~ : @types.Extent3d,
) -> Unit raise @core.Refused {
  self.frame.record(
    @types.Command::CopyTextureToBuffer({ source, destination, copy_size, }),
  )
}

///|
/// `copyTextureToTexture`.
pub fn CommandEncoder::copy_texture_to_texture(
  self : CommandEncoder,
  source~ : @types.TexelCopyTextureInfo,
  destination~ : @types.TexelCopyTextureInfo,
  copy_size~ : @types.Extent3d,
) -> Unit raise @core.Refused {
  self.frame.record(
    @types.Command::CopyTextureToTexture({ source, destination, copy_size, }),
  )
}

///|
/// `clearBuffer`: every byte of the range becomes zero.
pub fn CommandEncoder::clear_buffer(
  self : CommandEncoder,
  buffer~ : Buffer,
  offset~ : Int32 = 0,
  size? : Int32,
) -> Unit raise @core.Refused {
  let size = match size {
    Some(size) => size
    None => buffer.size - offset
  }
  self.frame.record(
    @types.Command::ClearBuffer({ buffer: buffer.id, offset, size, }),
  )
}

///|
/// `clearTexture`: every texel of the region becomes zero.
pub fn CommandEncoder::clear_texture(
  self : CommandEncoder,
  texture~ : Texture,
  mip_level~ : Int32 = 0,
  origin~ : @types.Origin3d = @types.Origin3d::new(),
  size? : @types.Extent3d,
  aspect~ : @types.TextureAspect = @types.TextureAspect::All,
) -> Unit raise @core.Refused {
  let size = match size {
    Some(size) => size
    None =>
      texture.descriptor.size.physical_size(
        mip_level~,
        format=texture.descriptor.format,
      )
  }
  self.frame.record(
    @types.Command::ClearTexture({
      texture: texture.id,
      mip_level,
      origin,
      size,
      aspect,
    }),
  )
}

///|
/// `resolveQuerySet`: write the results of a query set into a buffer.
/// https://www.w3.org/TR/webgpu/#dom-gpucommandencoder-resolvequeryset
pub fn CommandEncoder::resolve_query_set(
  self : CommandEncoder,
  query_set~ : QuerySet,
  first_query~ : Int32,
  query_count~ : Int32,
  destination~ : Buffer,
  destination_offset~ : Int32 = 0,
) -> Unit raise @core.Refused {
  self.frame.record(
    @types.Command::ResolveQuerySet({
      query_set: query_set.id,
      first_query,
      query_count,
      destination: destination.id,
      destination_offset,
    }),
  )
}

///|
/// `insertDebugMarker`.
/// https://www.w3.org/TR/webgpu/#dom-gpucommandencoder-insertdebugmarker
pub fn CommandEncoder::insert_debug_marker(
  self : CommandEncoder,
  marker~ : String,
) -> Unit raise @core.Refused {
  ignore(marker)
  self.frame.check("insertDebugMarker")
}

///|
/// `pushDebugGroup`.
pub fn CommandEncoder::push_debug_group(
  self : CommandEncoder,
  group_label~ : String,
) -> Unit raise @core.Refused {
  ignore(group_label)
  self.frame.check("pushDebugGroup")
}

///|
/// `popDebugGroup`.
pub fn CommandEncoder::pop_debug_group(
  self : CommandEncoder,
) -> Unit raise @core.Refused {
  self.frame.check("popDebugGroup")
}

///|
/// Start a render pass. Only one pass may be open at a time.
/// https://www.w3.org/TR/webgpu/#dom-gpucommandencoder-beginrenderpass
pub fn CommandEncoder::begin_render_pass(
  self : CommandEncoder,
  descriptor~ : @types.RenderPassDescriptor,
) -> RenderPassEncoder raise @core.Refused {
  self.frame.open_pass()
  {
    frame: self.frame,
    descriptor,
    commands: [],
    ended: false,
    label: descriptor.label,
  }
}

///|
/// Start a compute pass.
pub fn CommandEncoder::begin_compute_pass(
  self : CommandEncoder,
  descriptor~ : @types.ComputePassDescriptor = @types.ComputePassDescriptor::new(),
) -> ComputePassEncoder raise @core.Refused {
  self.frame.open_pass()
  {
    frame: self.frame,
    descriptor,
    commands: [],
    ended: false,
    label: descriptor.label,
  }
}

///|
/// Finish the encoder and hand over the commands.
/// https://www.w3.org/TR/webgpu/#dom-gpucommandencoder-finish
pub fn CommandEncoder::finish(
  self : CommandEncoder,
) -> CommandBuffer raise @core.Refused {
  { label: self.label, commands: self.frame.finish(), }
}
