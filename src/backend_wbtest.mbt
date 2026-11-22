// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// A backend that is named but not bound: the call compiles, and the refusal
// arrives where the driver would have answered.
//
// `metal` stands where `vulkan` used to: the Vulkan backend now has a device
// behind it wherever the loader and a driver are present, so the unbound case
// is shown by a backend that has no binding on any of the four targets.

///|
test "an unbound backend refuses at the call, not at construction" {
  let backend = @metal.open()
  assert_eq(backend.name(), "metal")
  assert_true(backend.reason().contains("metal"))
  let instance = Instance::new(backend~)
  assert_eq(instance.backend_name(), "metal")
  let device = instance.request_adapter().request_device()
  try {
    device.create_buffer(
      descriptor=@types.BufferDescriptor::new(
        size=16,
        usage=@types.BufferUsages::copy_dst(),
      ),
    )
    |> ignore
    fail("a backend with no binding created a buffer")
  } catch {
    @core.Refused::Internal(message~) => assert_true(message.contains("metal"))
    _ => fail("the refusal did not carry the backend's reason")
  }
}

///|
test "the browser backend names its own gap" {
  let backend = @web.open()
  assert_eq(backend.name(), "web")
  assert_true(backend.reason().contains("navigator.gpu"))
}

///|
/// Whichever way the machine answers, the backend answers: a device where the
/// loader and a driver are present, and a reason everywhere else.
test "the vulkan backend reports a device or the reason there is none" {
  let backend = @vulkan.open()
  assert_eq(backend.name(), "vulkan")
  if backend.available() {
    assert_true(backend.device_name().length() > 0)
    backend.close()
  } else {
    assert_true(backend.reason().contains("vulkan"))
  }
}
