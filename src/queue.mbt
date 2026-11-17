// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The queue work is submitted to.
///
/// Writes through the queue happen before the next submission, which is why
/// `write_buffer` and `write_texture` take effect without a command buffer.
/// https://www.w3.org/TR/webgpu/#gpiqueue
pub struct Queue {
  device : Device
  label : String
}

///|
/// The queue's label.
pub fn Queue::label(self : Queue) -> String {
  self.label
}

///|
/// Write bytes into a buffer before the next submission.
/// https://www.w3.org/TR/webgpu/#dom-gpuqueue-writebuffer
pub fn Queue::write_buffer(
  self : Queue,
  buffer~ : Buffer,
  offset~ : Int32,
  data~ : Bytes,
) -> Unit raise @core.Refused {
  self.device.hub.write_buffer(buffer.id, offset, data)
}

///|
/// Write texels into a texture before the next submission. Unlike a copy
/// through a buffer, these rows need no 256-byte stride.
/// https://www.w3.org/TR/webgpu/#dom-gpuqueue-writetexture
pub fn Queue::write_texture(
  self : Queue,
  destination~ : @types.TexelCopyTextureInfo,
  data~ : Bytes,
  layout~ : @types.TexelCopyBufferLayout = @types.TexelCopyBufferLayout::new(),
) -> Unit raise @core.Refused {
  self.device.hub.write_texture(destination, data, layout)
}

///|
/// `copyExternalImageToTexture`: move the pixels of a decoded frame into a
/// texture, before the next submission.
///
/// The rows need no alignment of their own: the frame is copied texel by texel,
/// which is why the specification allows it on a queue rather than through a
/// buffer.
/// https://www.w3.org/TR/webgpu/#dom-gpuqueue-copyexternalimagetotexture
pub fn Queue::copy_external_image_to_texture(
  self : Queue,
  source~ : @types.CopyExternalImageSourceInfo,
  destination~ : @types.CopyExternalImageDestInfo,
  copy_size~ : @types.Extent3d,
) -> Unit raise @core.Refused {
  self.device.hub.copy_external_image_to_texture(source, destination, copy_size)
}

///|
/// Wait until everything submitted so far has finished.
///
/// The specification returns a promise here because a real device works later.
/// The device timeline of this library runs in the caller's thread, so every
/// submission is already complete when `submit` returns, and this call only
/// reports that.
/// https://www.w3.org/TR/webgpu/#dom-gpuqueue-onsubmittedworkdone
pub fn Queue::on_submitted_work_done(self : Queue) -> Unit {
  ignore(self)
}

///|
/// Submit command buffers in order. Nothing reaches the host until every
/// command of every buffer has passed validation.
/// https://www.w3.org/TR/webgpu/#dom-gpuqueue-submit
pub fn Queue::submit(
  self : Queue,
  command_buffers~ : Array[CommandBuffer],
) -> Unit raise @core.Refused {
  let commands = []
  for buffer in command_buffers {
    for command in buffer.commands {
      commands.push(command)
    }
  }
  self.device.hub.submit(commands)
}
