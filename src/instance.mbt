// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// An `GPUAdapterInfo`: what an adapter says about itself.
#derive(Eq, Debug)
pub(all) struct AdapterInfo {
  vendor : String
  architecture : String
  device : String
  description : String
  is_fallback_adapter : Bool
  subgroup_min_size : Int32
  subgroup_max_size : Int32
}

///|
pub fn AdapterInfo::new(
  vendor~ : String = "",
  architecture~ : String = "",
  device~ : String = "",
  description~ : String = "",
  is_fallback_adapter~ : Bool = false,
  subgroup_min_size~ : Int32 = 0,
  subgroup_max_size~ : Int32 = 0,
) -> AdapterInfo {
  {
    vendor,
    architecture,
    device,
    description,
    is_fallback_adapter,
    subgroup_min_size,
    subgroup_max_size,
  }
}

///|
/// A `GPURequestAdapterOptions`.
#derive(Eq, Debug)
pub(all) struct RequestAdapterOptions {
  power_preference : @types.PowerPreference
  force_fallback_adapter : Bool
}

///|
pub fn RequestAdapterOptions::new(
  power_preference~ : @types.PowerPreference = @types.PowerPreference::None,
  force_fallback_adapter~ : Bool = false,
) -> RequestAdapterOptions {
  { power_preference, force_fallback_adapter, }
}

///|
/// A `GPUDeviceDescriptor`.
#derive(Debug)
pub(all) struct DeviceDescriptor {
  label : String
  required_features : @types.Features
  required_limits : @types.Limits?
  default_queue_label : String
}

///|
/// A device with no optional feature and the adapter's own limits.
pub fn DeviceDescriptor::new(
  label~ : String = "",
  required_features~ : @types.Features = @types.Features::none(),
  required_limits? : @types.Limits,
  default_queue_label~ : String = "",
) -> DeviceDescriptor {
  { label, required_features, required_limits, default_queue_label, }
}

///|
/// The entry point: what a caller has to build before anything else.
///
/// A `Instance` owns a backend, a handle to one way of talking to a device:
/// the memory backend of this repository, a native graphics API, or the
/// browser's own WebGPU. The handle is injected rather than chosen here, so
/// that this package never depends on a particular one.
pub struct Instance {
  backend : &@hal.Hal
  label : String
}

///|
/// An instance over `backend`.
pub fn Instance::new(backend~ : &@hal.Hal, label~ : String = "") -> Instance {
  { backend, label, }
}

///|
/// The name of the backend behind this instance, as in `"memory"`.
pub fn Instance::backend_name(self : Instance) -> String {
  self.backend.name()
}

///|
/// Ask for an adapter. A backend that offers exactly one adapter hands it over
/// whatever the options say; the options exist so that a host with several can
/// pick.
/// https://www.w3.org/TR/webgpu/#dom-gpu-requestadapter
pub fn Instance::request_adapter(
  self : Instance,
  options~ : RequestAdapterOptions = RequestAdapterOptions::new(),
) -> Adapter {
  ignore(options)
  {
    backend: self.backend,
    limits: self.backend.limits(),
    features: self.backend.features(),
    info: AdapterInfo::new(
      description=self.backend.name(),
      is_fallback_adapter=true,
    ),
  }
}

///|
/// What a caller holds between asking for an adapter and asking for a device.
pub struct Adapter {
  backend : &@hal.Hal
  limits : @types.Limits
  features : @types.Features
  info : AdapterInfo
}

///|
/// The limits this adapter offers.
pub fn Adapter::limits(self : Adapter) -> @types.Limits {
  self.limits
}

///|
/// The optional features this adapter offers.
pub fn Adapter::features(self : Adapter) -> @types.Features {
  self.features
}

///|
/// What the adapter says about itself.
pub fn Adapter::info(self : Adapter) -> AdapterInfo {
  self.info
}

///|
/// Whether this is a fallback adapter, one that prefers to be correct over
/// being fast.
/// https://www.w3.org/TR/webgpu/#dom-gpuadapter-isfallbackadapter
pub fn Adapter::is_fallback_adapter(self : Adapter) -> Bool {
  self.info.is_fallback_adapter
}

///|
/// Create a device, checking that everything asked for is offered.
/// https://www.w3.org/TR/webgpu/#dom-gpuadapter-requestdevice
pub fn Adapter::request_device(
  self : Adapter,
  descriptor~ : DeviceDescriptor = DeviceDescriptor::new(),
) -> Device raise @core.Refused {
  // Every requested feature has to be offered, and so does everything it
  // depends on.
  for feature in descriptor.required_features.names() {
    @core.require(
      self.features.contains(feature),
      @types.MissingFeature,
      "descriptor.requiredFeatures",
      feature.name(),
      "not offered",
    )
    for dependency in feature.dependencies() {
      @core.require(
        descriptor.required_features.contains(dependency),
        @types.MissingFeature,
        "descriptor.requiredFeatures",
        dependency.name(),
        "the dependency of \{feature.name()} is missing",
      )
    }
  }
  let limits = match descriptor.required_limits {
    Some(required) =>
      match self.limits.exceeds(required) {
        Some((name, have, want)) =>
          raise @core.invalid(
            @types.LimitExceeded,
            "descriptor.requiredLimits.\{name}",
            have.to_string(),
            want.to_string(),
          )
        None => required
      }
    None => self.limits
  }
  {
    hub: @core.Hub::new(self.backend, limits, descriptor.required_features),
    label: descriptor.label,
    default_queue_label: descriptor.default_queue_label,
  }
}
