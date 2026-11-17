// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The Direct3D 12 backend, as a name.
///
/// The package exists so that the backend has its own place in the tree and
/// its own dependency edge: nothing above `hal` may name it, and it may not
/// name anything above `hal`. What it does not have yet is a surface: until
/// the C stub exists, `open` returns a backend that refuses every call with
/// the reason below.
pub fn open() -> @hal.Unbound {
  @hal.Unbound::new(
    name="dx12",
    reason="dx12: the D3D12 stub is not bound yet; the seam is hal/dx12",
  )
}
