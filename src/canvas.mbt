// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A canvas: the surface a device renders into and something else presents.
///
/// `GPUCanvasContext`, with the window system factored out. The context owns
/// no pixels and no swap chain; it holds a `@hal.Surface`, which a windowing
/// layer implements, and turns the frames that surface hands out into ordinary
/// `Texture` objects, so that recording into a canvas is recording into a
/// texture and nothing more.
///
/// https://www.w3.org/TR/webgpu/#canvas-context
pub struct CanvasContext {
  surface : &@hal.Surface
  mut device : Device?
  mut configuration : @types.SurfaceConfiguration?
}

///|
/// A context over a host surface, unconfigured.
pub fn CanvasContext::new(surface~ : &@hal.Surface) -> CanvasContext {
  { surface, device: None, configuration: None, }
}

///|
/// The host's own name for the surface, which is what `canvas` names in the
/// specification: the element belongs to the host.
pub fn CanvasContext::canvas(self : CanvasContext) -> String {
  self.surface.name()
}

///|
/// Whether a configuration is in force.
pub fn CanvasContext::is_configured(self : CanvasContext) -> Bool {
  self.configuration is Some(_)
}

///|
/// What this surface accepts, before anything is configured.
pub fn CanvasContext::capabilities(
  self : CanvasContext,
) -> @types.SurfaceCapabilities {
  self.surface.capabilities()
}

///|
/// `configure`: bind the canvas to a device and a format.
pub fn CanvasContext::configure(
  self : CanvasContext,
  device~ : Device,
  configuration~ : @types.SurfaceConfiguration,
) -> Unit raise @core.Refused {
  @core.require(
    !device.destroyed(),
    @types.InvalidResource,
    "canvas.device",
    "a live device",
    "a destroyed device",
  )
  let capabilities = self.surface.capabilities()
  @core.require(
    capabilities.formats.contains(configuration.format),
    @types.InvalidCanvasConfiguration,
    "configuration.format",
    "a format the surface can present",
    configuration.format.name(),
  )
  @core.require(
    !configuration.usage.is_empty(),
    @types.InvalidCanvasConfiguration,
    "configuration.usage",
    "at least one usage",
    "none",
  )
  self.surface.configure(configuration) catch {
    error => raise @core.Refused::from_hal(error)
  }
  self.device = Some(device)
  self.configuration = Some(configuration)
}

///|
/// `unconfigure`: drop the configuration and the frames held for it.
pub fn CanvasContext::unconfigure(self : CanvasContext) -> Unit {
  self.surface.unconfigure()
  self.device = None
  self.configuration = None
}

///|
/// `getCurrentTexture`: the frame to render into.
///
/// The texture carries the configuration's format and usage and the surface's
/// current size, so a render pass opens on it exactly as on a texture the
/// device created. The frame is recycled when it is presented.
pub fn CanvasContext::get_current_texture(
  self : CanvasContext,
) -> Texture raise @core.Refused {
  let (device, configuration) = match (self.device, self.configuration) {
    (Some(device), Some(configuration)) => (device, configuration)
    _ =>
      raise @core.invalid(
        @types.InvalidCanvasConfiguration,
        "canvas",
        "a configured context",
        "an unconfigured one",
      )
  }
  @core.require(
    !device.destroyed(),
    @types.InvalidResource,
    "canvas.device",
    "a live device",
    "a destroyed device",
  )
  let frame = self.surface.acquire() catch {
    error => raise @core.Refused::from_hal(error)
  }
  let descriptor = @types.TextureDescriptor::new(
    size=self.surface.size(),
    format=configuration.format,
    usage=configuration.usage,
    view_formats=configuration.view_formats,
    label=self.surface.name(),
  )
  { device, id: frame.texture, descriptor, destroyed: false, }
}

///|
/// Hand a frame back for display.
pub fn CanvasContext::present(
  self : CanvasContext,
  texture~ : Texture,
) -> Unit raise @core.Refused {
  self.surface.present(texture.id()) catch {
    error => raise @core.Refused::from_hal(error)
  }
}
