// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The canvas seam: a host surface that presents nothing, and the context that
// turns its frames into textures.

///|
struct FakeSurface {
  mut configured : Bool
  mut format : @types.TextureFormat
  mut frames : Int32
  mut presented : Bool
}

///|
fn fake_surface() -> FakeSurface {
  {
    configured: false,
    format: @types.TextureFormat::Bgra8unorm,
    frames: 0,
    presented: false,
  }
}

///|
pub impl @hal.Surface for FakeSurface with fn name(_self) {
  "window 1"
}

///|
pub impl @hal.Surface for FakeSurface with fn size(_self) {
  @types.Extent3d::new(width=64, height=32)
}

///|
pub impl @hal.Surface for FakeSurface with fn configure(self, configuration) {
  self.configured = true
  self.format = configuration.format
}

///|
pub impl @hal.Surface for FakeSurface with fn unconfigure(self) {
  self.configured = false
}

///|
pub impl @hal.Surface for FakeSurface with fn capabilities(_self) {
  @types.SurfaceCapabilities::new(formats=[
    @types.TextureFormat::Bgra8unorm,
    @types.TextureFormat::Rgba8unorm,
  ])
}

///|
pub impl @hal.Surface for FakeSurface with fn acquire(self) {
  self.frames = self.frames + 1
  @types.SurfaceFrame::new(texture=@types.TextureId::from_raw(100))
}

///|
pub impl @hal.Surface for FakeSurface with fn present(self, _id) {
  self.presented = true
}

///|
fn canvas_error(run : () -> Unit raise @core.Refused) -> @types.ErrorKind? {
  try {
    run()
    None
  } catch {
    @core.Refused::Validation(kind~, ..) => Some(kind)
    _ => None
  }
}

///|
test "a canvas before it is configured has no frame" {
  let surface = fake_surface()
  let canvas = CanvasContext::new(surface~)
  assert_false(canvas.is_configured())
  assert_eq(canvas.canvas(), "window 1")
  assert_eq(
    canvas_error(fn() raise @core.Refused {
      canvas.get_current_texture() |> ignore
    }),
    Some(@types.InvalidCanvasConfiguration),
  )
}

///|
test "configuring a canvas binds a device and a format" {
  let surface = fake_surface()
  let canvas = CanvasContext::new(surface~)
  let device = device()
  canvas.configure(
    device~,
    configuration=@types.SurfaceConfiguration::new(
      format=@types.TextureFormat::Bgra8unorm,
    ),
  )
  assert_true(canvas.is_configured())
  assert_true(surface.configured)
  assert_eq(surface.format, @types.TextureFormat::Bgra8unorm)
  let frame = canvas.get_current_texture()
  assert_eq(frame.width(), 64)
  assert_eq(frame.height(), 32)
  assert_eq(frame.format(), @types.TextureFormat::Bgra8unorm)
  assert_true(frame.usage().contains(@types.TextureUsages::render_attachment()))
  canvas.present(texture=frame)
  assert_true(surface.presented)
  canvas.unconfigure()
  assert_false(canvas.is_configured())
  assert_false(surface.configured)
}

///|
test "a format the surface cannot present is refused" {
  let surface = fake_surface()
  let canvas = CanvasContext::new(surface~)
  let device = device()
  assert_eq(
    canvas_error(fn() raise @core.Refused {
      canvas.configure(
        device~,
        configuration=@types.SurfaceConfiguration::new(
          format=@types.TextureFormat::Rgba16float,
        ),
      )
    }),
    Some(@types.InvalidCanvasConfiguration),
  )
  assert_false(surface.configured)
}

///|
test "a destroyed device cannot own a canvas" {
  let surface = fake_surface()
  let canvas = CanvasContext::new(surface~)
  let device = device()
  device.destroy()
  assert_eq(
    canvas_error(fn() raise @core.Refused {
      canvas.configure(
        device~,
        configuration=@types.SurfaceConfiguration::new(
          format=@types.TextureFormat::Bgra8unorm,
        ),
      )
    }),
    Some(@types.InvalidResource),
  )
}

///|
#doc(hidden)
pub extend FakeSurface with @hal.Surface::{
  name,
  size,
  configure,
  unconfigure,
  capabilities,
  acquire,
  present,
}
