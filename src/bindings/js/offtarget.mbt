// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The other backends have no way to call into a JavaScript host, so building
// this package for them produces a program that says exactly that instead of
// one that fails to link.

///|
#coverage.skip
fn main {
  println(
    "moonwgpu: the js binding is built for --target js; nothing to do here",
  )
}
