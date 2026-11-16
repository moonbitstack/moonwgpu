// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Helpers shared by the validation tests: the default limits, an empty feature
// set, two descriptor builders, and one way to ask which error a rule raised.

///|
let webgpu_limits : @types.Limits = @types.Limits::webgpu()

///|
fn no_features() -> @types.Features {
  @types.Features::none()
}

///|
fn kind_of(run : () -> Unit raise Refused) -> @types.ErrorKind? {
  try {
    run()
    None
  } catch {
    Validation(kind~, ..) => Some(kind)
    _ => None
  }
}

///|
fn buffer_descriptor(
  size : Int32,
  usage : @types.BufferUsages,
) -> @types.BufferDescriptor {
  @types.BufferDescriptor::new(size~, usage~)
}

///|
fn texture_descriptor(
  width : Int32,
  height : Int32,
  format : @types.TextureFormat,
  usage : @types.TextureUsages,
) -> @types.TextureDescriptor {
  @types.TextureDescriptor::new(
    size=@types.Extent3d::new(width~, height~),
    format~,
    usage~,
  )
}

///|
fn buffer_state(size : Int32, usage : @types.BufferUsages) -> BufferState {
  {
    descriptor: @types.BufferDescriptor::new(size~, usage~),
    destroyed: false,
    mapped: false,
  }
}

///|
fn texture_state(
  width : Int32,
  height : Int32,
  format : @types.TextureFormat,
  usage : @types.TextureUsages,
) -> TextureState {
  {
    descriptor: @types.TextureDescriptor::new(
      size=@types.Extent3d::new(width~, height~),
      format~,
      usage~,
    ),
    destroyed: false,
  }
}
