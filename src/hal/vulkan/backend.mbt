// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The Vulkan backend, as a name.
///
/// The package exists so that the backend has its own place in the tree and
/// its own dependency edge: nothing above `hal` may name it, and it may not
/// name anything above `hal`. What it does not have yet is a surface: until
/// the C stub exists, `open` returns a backend that refuses every call with
/// the reason below.
pub fn open() -> @hal.Unbound {
  @hal.Unbound::new(
    name="vulkan",
    reason="vulkan: the libvulkan C stub is not bound yet; the seam is hal/vulkan",
  )
}
