// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Derived implementations are also reachable as methods; declaring them keeps
// the toolchain from reporting the promotion, and keeps them out of the API
// reference, where `==` and `Debug` are the ways in.

///|
#doc(hidden)
pub extend AdapterInfo with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend AdapterInfo with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend RequestAdapterOptions with Eq::{equal, not_equal}

///|
#doc(hidden)
pub extend RequestAdapterOptions with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend DeviceDescriptor with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend CommandBuffer with @debug.Debug::{to_repr}

///|
#doc(hidden)
pub extend RenderBundleEncoderDescriptor with @debug.Debug::{to_repr}
