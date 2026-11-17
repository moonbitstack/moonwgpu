// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The browser backend, as a name.
///
/// In a browser the object graph already exists: `navigator.gpu` hands out an
/// adapter, the adapter a device, and every call is a promise. This package is
/// where that bridge goes, and it is the one backend whose `Instance` is not
/// the first object in the chain. Until the bridge is written, `open` returns
/// a backend that refuses every call with the reason below.
pub fn open() -> @hal.Unbound {
  @hal.Unbound::new(
    name="web",
    reason="web: the navigator.gpu bridge is not written yet; the seam is web",
  )
}
