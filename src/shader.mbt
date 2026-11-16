// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A shader module: source code the device can build entry points from.
pub struct ShaderModule {
  device : Device
  id : @types.ShaderModuleId
  label : String
}

///|
/// The module's identity inside its device.
pub fn ShaderModule::id(self : ShaderModule) -> @types.ShaderModuleId {
  self.id
}

///|
/// The module's label.
pub fn ShaderModule::label(self : ShaderModule) -> String {
  self.label
}
