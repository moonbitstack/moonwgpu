// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A `GPURenderBundleEncoderDescriptor`: the attachment formats a bundle is
/// recorded against, so that its commands can be validated without a pass.
#derive(Debug)
pub(all) struct RenderBundleEncoderDescriptor {
  label : String
  color_formats : Array[@types.TextureFormat]
  depth_stencil_format : @types.TextureFormat?
  sample_count : Int32
  depth_read_only : Bool
  stencil_read_only : Bool
}

///|
pub fn RenderBundleEncoderDescriptor::new(
  color_formats~ : Array[@types.TextureFormat],
  label~ : String = "",
  depth_stencil_format? : @types.TextureFormat,
  sample_count~ : Int32 = 1,
  depth_read_only~ : Bool = false,
  stencil_read_only~ : Bool = false,
) -> RenderBundleEncoderDescriptor {
  {
    label,
    color_formats,
    depth_stencil_format,
    sample_count,
    depth_read_only,
    stencil_read_only,
  }
}

///|
/// Records a render bundle: a run of draw commands that any number of passes
/// can execute again.
///
/// A bundle records the same commands a render pass does, minus the ones that
/// depend on the pass's own attachment views. It is validated when it is
/// executed, in the pass it lands in, which is where the specification puts
/// that check.
/// https://www.w3.org/TR/webgpu/#render-bundles
pub struct RenderBundleEncoder {
  device : Device
  descriptor : RenderBundleEncoderDescriptor
  commands : Array[@types.RenderCommand]
  mut ended : Bool
}

///|
/// The bundle encoder's label.
pub fn RenderBundleEncoder::label(self : RenderBundleEncoder) -> String {
  self.descriptor.label
}

///|
/// Refuse anything recorded after `finish`.
fn RenderBundleEncoder::check_open(
  self : RenderBundleEncoder,
) -> Unit raise @core.Refused {
  @core.require(
    !self.ended,
    @types.InvalidPassState,
    "renderBundleEncoder",
    "an encoder that has not finished",
    "a finished encoder",
  )
}

///|
/// `setPipeline`.
pub fn RenderBundleEncoder::set_pipeline(
  self : RenderBundleEncoder,
  pipeline~ : RenderPipeline,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::SetPipeline(pipeline.id))
}

///|
/// `setBindGroup`.
pub fn RenderBundleEncoder::set_bind_group(
  self : RenderBundleEncoder,
  index~ : Int32,
  bind_group~ : BindGroup,
  dynamic_offsets~ : Array[Int32] = [],
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::SetBindGroup({
      index,
      group: bind_group.id,
      dynamic_offsets,
    }),
  )
}

///|
/// `setImmediates`, recorded into the bundle.
pub fn RenderBundleEncoder::set_immediates(
  self : RenderBundleEncoder,
  range_offset~ : Int32,
  data~ : Bytes,
  data_offset~ : Int32 = 0,
  data_size? : Int32,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::SetImmediates(
      @core.immediates(range_offset, data, data_offset, data_size),
    ),
  )
}

///|
/// `setVertexBuffer`.
pub fn RenderBundleEncoder::set_vertex_buffer(
  self : RenderBundleEncoder,
  slot~ : Int32,
  buffer~ : Buffer,
  offset~ : Int32 = 0,
  size? : Int32,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::SetVertexBuffer({
      slot,
      buffer: buffer.id,
      offset,
      size,
    }),
  )
}

///|
/// `setIndexBuffer`.
pub fn RenderBundleEncoder::set_index_buffer(
  self : RenderBundleEncoder,
  buffer~ : Buffer,
  format~ : @types.IndexFormat,
  offset~ : Int32 = 0,
  size? : Int32,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::SetIndexBuffer({
      buffer: buffer.id,
      format,
      offset,
      size,
    }),
  )
}

///|
/// `draw`.
pub fn RenderBundleEncoder::draw(
  self : RenderBundleEncoder,
  arguments~ : @types.DrawArguments,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::Draw(arguments))
}

///|
/// `drawIndexed`.
pub fn RenderBundleEncoder::draw_indexed(
  self : RenderBundleEncoder,
  arguments~ : @types.DrawIndexedArguments,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::DrawIndexed(arguments))
}

///|
/// `drawIndirect`.
pub fn RenderBundleEncoder::draw_indirect(
  self : RenderBundleEncoder,
  buffer~ : Buffer,
  offset~ : Int32 = 0,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::DrawIndirect({ buffer: buffer.id, offset, }),
  )
}

///|
/// `drawIndexedIndirect`.
pub fn RenderBundleEncoder::draw_indexed_indirect(
  self : RenderBundleEncoder,
  buffer~ : Buffer,
  offset~ : Int32 = 0,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(
    @types.RenderCommand::DrawIndexedIndirect({ buffer: buffer.id, offset, }),
  )
}

///|
/// `insertDebugMarker`.
pub fn RenderBundleEncoder::insert_debug_marker(
  self : RenderBundleEncoder,
  marker~ : String,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::InsertDebugMarker(marker))
}

///|
/// `pushDebugGroup`.
pub fn RenderBundleEncoder::push_debug_group(
  self : RenderBundleEncoder,
  group_label~ : String,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::PushDebugGroup(group_label))
}

///|
/// `popDebugGroup`.
pub fn RenderBundleEncoder::pop_debug_group(
  self : RenderBundleEncoder,
) -> Unit raise @core.Refused {
  self.check_open()
  self.commands.push(@types.RenderCommand::PopDebugGroup)
}

///|
/// Finish the bundle.
/// https://www.w3.org/TR/webgpu/#dom-gpurenderbundleencoder-finish
pub fn RenderBundleEncoder::finish(
  self : RenderBundleEncoder,
) -> @types.RenderBundle raise @core.Refused {
  self.check_open()
  self.ended = true
  @types.RenderBundle::{
    label: self.descriptor.label,
    commands: self.commands.copy(),
  }
}

///|
/// An encoder for a render bundle over the given attachment formats.
pub fn Device::create_render_bundle_encoder(
  self : Device,
  descriptor~ : RenderBundleEncoderDescriptor,
) -> RenderBundleEncoder raise @core.Refused {
  @core.require(
    descriptor.sample_count == 1 || descriptor.sample_count == 4,
    @types.InvalidMultisampleState,
    "descriptor.sampleCount",
    "1 or 4",
    descriptor.sample_count.to_string(),
  )
  { device: self, descriptor, commands: [], ended: false, }
}
