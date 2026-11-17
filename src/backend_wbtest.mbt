// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// A backend that is named but not bound: the call compiles, and the refusal
// arrives where the driver would have answered.

///|
test "an unbound backend refuses at the call, not at construction" {
  let backend = @vulkan.open()
  assert_eq(backend.name(), "vulkan")
  assert_true(backend.reason().contains("vulkan"))
  let instance = Instance::new(backend~)
  assert_eq(instance.backend_name(), "vulkan")
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
    @core.Refused::Internal(message~) => assert_true(message.contains("vulkan"))
    _ => fail("the refusal did not carry the backend's reason")
  }
}

///|
test "the browser backend names its own gap" {
  let backend = @web.open()
  assert_eq(backend.name(), "web")
  assert_true(backend.reason().contains("navigator.gpu"))
}
