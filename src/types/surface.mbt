// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// `GPUCanvasAlphaMode`: how the canvas's alpha is treated when the page
/// composites it.
#derive(Eq, Debug)
pub(all) enum CanvasAlphaMode {
  Opaque
  Premultiplied
}

///|
/// `CanvasToneMappingMode`: how values outside the displayable range are
/// mapped before they reach the canvas.
#derive(Eq, Debug)
pub(all) enum ToneMappingMode {
  Standard
  Extended
}

///|
/// `CanvasToneMapping`.
#derive(Eq, Debug)
pub(all) struct CanvasToneMapping {
  mode : ToneMappingMode
}

///|
pub fn CanvasToneMapping::new(
  mode~ : ToneMappingMode = ToneMappingMode::Standard,
) -> CanvasToneMapping {
  { mode, }
}

///|
/// `GPUCanvasConfiguration`, minus the device it names.
///
/// The device is a property of the `CanvasContext` here rather than a field of
/// the configuration: a configuration is handed to a host surface, which has no
/// way to name a device, and the context is where the two are known to be the
/// same one.
///
/// https://www.w3.org/TR/webgpu/#dictdef-gpucanvasconfiguration
#derive(Debug)
pub(all) struct SurfaceConfiguration {
  format : TextureFormat
  usage : TextureUsages
  view_formats : Array[TextureFormat]
  color_space : PredefinedColorSpace
  tone_mapping : CanvasToneMapping
  alpha_mode : CanvasAlphaMode
}

///|
/// The configuration a canvas starts from: renderable, sRGB, opaque, and the
/// standard tone mapping.
pub fn SurfaceConfiguration::new(
  format~ : TextureFormat,
  usage~ : TextureUsages = TextureUsages::render_attachment(),
  view_formats~ : Array[TextureFormat] = [],
  color_space~ : PredefinedColorSpace = PredefinedColorSpace::Srgb,
  tone_mapping~ : CanvasToneMapping = CanvasToneMapping::new(),
  alpha_mode~ : CanvasAlphaMode = CanvasAlphaMode::Opaque,
) -> SurfaceConfiguration {
  { format, usage, view_formats, color_space, tone_mapping, alpha_mode, }
}

///|
/// What a surface can be configured with, as `GPUCanvasContext` reports it
/// through the adapter.
#derive(Debug)
pub(all) struct SurfaceCapabilities {
  formats : Array[TextureFormat]
  alpha_modes : Array[CanvasAlphaMode]
  usages : TextureUsages
}

///|
pub fn SurfaceCapabilities::new(
  formats~ : Array[TextureFormat],
  alpha_modes~ : Array[CanvasAlphaMode] = [
    CanvasAlphaMode::Opaque,
    CanvasAlphaMode::Premultiplied,
  ],
  usages~ : TextureUsages = TextureUsages::render_attachment(),
) -> SurfaceCapabilities {
  { formats, alpha_modes, usages, }
}

///|
/// One acquired frame: the texture to render into, and whether the surface
/// considers it a poor match for what it can present.
#derive(Debug)
pub(all) struct SurfaceFrame {
  texture : TextureId
  suboptimal : Bool
}

///|
pub fn SurfaceFrame::new(
  texture~ : TextureId,
  suboptimal~ : Bool = false,
) -> SurfaceFrame {
  { texture, suboptimal, }
}
