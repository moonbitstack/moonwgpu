// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The bridge between the two error models: a caller in MoonBit has its
/// refusals raised, a caller speaking the specification reads them back from
/// `popErrorScope`, and `report_error` is how the second one sees the first.

///|
test "report_error hands a refusal to the innermost matching scope" {
  let device = device()
  device.push_error_scope(filter=@types.ErrorFilter::Validation)
  let refused = @core.invalid(
    @types.InvalidBufferUsage,
    "descriptor.usage",
    "MAP_READ with at most COPY_DST",
    "MAP_READ | COPY_SRC",
  )
  let returned = device.report_error(refused)
  assert_eq(returned.message(), refused.message())
  let errors = device.pop_error_scope()
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].message(), refused.message())
}

///|
test "a scope with another filter does not see it, and the device keeps it" {
  let device = device()
  device.clear_uncaptured_errors()
  device.push_error_scope(filter=@types.ErrorFilter::OutOfMemory)
  let refused = @core.invalid(
    @types.InvalidBufferUsage,
    "descriptor.usage",
    "at least one flag",
    "none",
  )
  device.report_error(refused) |> ignore
  let errors = device.pop_error_scope()
  assert_eq(errors.length(), 0)
  let uncaptured = device.uncaptured_errors()
  assert_eq(uncaptured.length(), 1)
  assert_eq(uncaptured[0].message(), refused.message())
}

///|
test "with no scope open the refusal is uncaptured" {
  let device = device()
  device.clear_uncaptured_errors()
  let refused = @core.invalid(
    @types.InvalidTextureSampleCount,
    "descriptor.sampleCount",
    "1 or 4",
    "3",
  )
  device.report_error(refused) |> ignore
  let uncaptured = device.uncaptured_errors()
  assert_eq(uncaptured.length(), 1)
  assert_eq(uncaptured[0].message(), refused.message())
}

///|
test "an inner scope keeps its own errors out of the outer one" {
  let device = device()
  device.push_error_scope(filter=@types.ErrorFilter::Validation)
  device.push_error_scope(filter=@types.ErrorFilter::Validation)
  device.report_error(
    @core.invalid(@types.InvalidBufferSize, "descriptor.size", "0", "-1"),
  )
  |> ignore
  let inner = device.pop_error_scope()
  assert_eq(inner.length(), 1)
  let outer = device.pop_error_scope()
  assert_eq(outer.length(), 0)
}
