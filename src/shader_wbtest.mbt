// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// Two ways to hand a device a module: WGSL text, and SPIR-V a front end has
// already produced.

///|
fn word_bytes(value : Int32) -> Array[Byte] {
  [
    (value & 0xFF).to_byte(),
    ((value >> 8) & 0xFF).to_byte(),
    ((value >> 16) & 0xFF).to_byte(),
    ((value >> 24) & 0xFF).to_byte(),
  ]
}

///|
fn bytes_of(values : Array[Int32]) -> Bytes {
  let out : Array[Byte] = []
  for value in values {
    for part in word_bytes(value) {
      out.push(part)
    }
  }
  Bytes::from_array(out)
}

///|
fn module_error(run : () -> Unit raise @core.Refused) -> @types.ErrorKind? {
  try {
    run()
    None
  } catch {
    @core.Refused::Validation(kind~, ..) => Some(kind)
    _ => None
  }
}

///|
test "a WGSL module is text" {
  let descriptor = @types.ShaderModuleDescriptor::wgsl(
    source="fn main() { }",
    label="hello",
  )
  assert_eq(descriptor.kind(), @types.ShaderSourceKind::Wgsl)
  assert_eq(descriptor.code.text(), Some("fn main() { }"))
  assert_eq(descriptor.code.words(), None)
  assert_false(descriptor.code.is_empty())
}

///|
test "a device takes SPIR-V words without a front end" {
  let device = device()
  let words = bytes_of([0x07230203, 0x00010000, 0x00000000, 0x00000001, 0])
  let descriptor = @types.ShaderModuleDescriptor::spirv(words~)
  assert_eq(descriptor.kind(), @types.ShaderSourceKind::SpirV)
  let shader = device.create_shader_module(descriptor~)
  assert_eq(shader.get_compilation_info().messages.length(), 0)
}

///|
test "SPIR-V that does not start with the magic number is refused" {
  let device = device()
  assert_eq(
    module_error(fn() raise @core.Refused {
      device.create_shader_module(
        descriptor=@types.ShaderModuleDescriptor::spirv(
          words=bytes_of([0x07230204, 0x00010000, 0]),
        ),
      )
      |> ignore
    }),
    Some(@types.InvalidShaderModule),
  )
}

///|
test "SPIR-V that is not a whole number of words is refused" {
  let device = device()
  let whole = bytes_of([0x07230203, 0x0001])
  let six = whole[0:6].to_owned()
  assert_eq(
    module_error(fn() raise @core.Refused {
      device.create_shader_module(
        descriptor=@types.ShaderModuleDescriptor::spirv(words=six),
      )
      |> ignore
    }),
    Some(@types.InvalidShaderModule),
  )
}

///|
test "an empty module is refused whichever form it takes" {
  let device = device()
  assert_eq(
    module_error(fn() raise @core.Refused {
      device.create_shader_module(
        descriptor=@types.ShaderModuleDescriptor::wgsl(source=""),
      )
      |> ignore
    }),
    Some(@types.InvalidShaderModule),
  )
  assert_eq(
    module_error(fn() raise @core.Refused {
      device.create_shader_module(
        descriptor=@types.ShaderModuleDescriptor::spirv(words=bytes_of([])),
      )
      |> ignore
    }),
    Some(@types.InvalidShaderModule),
  )
}
