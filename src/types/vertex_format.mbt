// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// How the bytes of one vertex attribute are read, `GPUVertexFormat`.
#derive(Eq, Debug)
pub(all) enum VertexFormat {
  Uint8
  Uint8x2
  Uint8x4
  Sint8
  Sint8x2
  Sint8x4
  Unorm8
  Unorm8x2
  Unorm8x4
  Snorm8
  Snorm8x2
  Snorm8x4
  Uint16
  Uint16x2
  Uint16x4
  Sint16
  Sint16x2
  Sint16x4
  Unorm16
  Unorm16x2
  Unorm16x4
  Snorm16
  Snorm16x2
  Snorm16x4
  Float16
  Float16x2
  Float16x4
  Float32
  Float32x2
  Float32x3
  Float32x4
  Uint32
  Uint32x2
  Uint32x3
  Uint32x4
  Sint32
  Sint32x2
  Sint32x3
  Sint32x4
  Unorm1010102
  Unorm8x4Bgra
  Snorm1010102
}

///|
/// The scalar type the bytes decode to, which decides what WGSL type the
/// attribute may be declared as.
#derive(Eq, Debug)
pub(all) enum VertexDataType {
  Uint
  Sint
  Unorm
  Snorm
  Float
}

///|
/// What a `VertexFormat` occupies in a vertex buffer.
#derive(Eq, Debug)
pub(all) struct VertexFormatInfo {
  size : Int32
  components : Int32
  data_type : VertexDataType
}

///|
/// The layout of one attribute. Sizes are the `byteSize` column of the
/// specification's vertex format table; the three packed formats hold four
/// components in four bytes.
/// https://www.w3.org/TR/webgpu/#vertex-formats
pub fn VertexFormat::info(self : VertexFormat) -> VertexFormatInfo {
  match self {
    Uint8 => { size: 1, components: 1, data_type: VertexDataType::Uint, }
    Uint8x2 => { size: 2, components: 1, data_type: VertexDataType::Uint, }
    Uint8x4 => { size: 4, components: 1, data_type: VertexDataType::Uint, }
    Sint8 => { size: 1, components: 1, data_type: VertexDataType::Sint, }
    Sint8x2 => { size: 2, components: 1, data_type: VertexDataType::Sint, }
    Sint8x4 => { size: 4, components: 1, data_type: VertexDataType::Sint, }
    Unorm8 => { size: 1, components: 1, data_type: VertexDataType::Unorm, }
    Unorm8x2 => { size: 2, components: 1, data_type: VertexDataType::Unorm, }
    Unorm8x4 => { size: 4, components: 1, data_type: VertexDataType::Unorm, }
    Snorm8 => { size: 1, components: 1, data_type: VertexDataType::Snorm, }
    Snorm8x2 => { size: 2, components: 1, data_type: VertexDataType::Snorm, }
    Snorm8x4 => { size: 4, components: 1, data_type: VertexDataType::Snorm, }
    Uint16 => { size: 2, components: 1, data_type: VertexDataType::Uint, }
    Uint16x2 => { size: 4, components: 2, data_type: VertexDataType::Uint, }
    Uint16x4 => { size: 8, components: 4, data_type: VertexDataType::Uint, }
    Sint16 => { size: 2, components: 1, data_type: VertexDataType::Sint, }
    Sint16x2 => { size: 4, components: 2, data_type: VertexDataType::Sint, }
    Sint16x4 => { size: 8, components: 4, data_type: VertexDataType::Sint, }
    Unorm16 => { size: 2, components: 1, data_type: VertexDataType::Unorm, }
    Unorm16x2 => { size: 4, components: 2, data_type: VertexDataType::Unorm, }
    Unorm16x4 => { size: 8, components: 4, data_type: VertexDataType::Unorm, }
    Snorm16 => { size: 2, components: 1, data_type: VertexDataType::Snorm, }
    Snorm16x2 => { size: 4, components: 2, data_type: VertexDataType::Snorm, }
    Snorm16x4 => { size: 8, components: 4, data_type: VertexDataType::Snorm, }
    Float16 => { size: 2, components: 1, data_type: VertexDataType::Float, }
    Float16x2 => { size: 4, components: 2, data_type: VertexDataType::Float, }
    Float16x4 => { size: 8, components: 4, data_type: VertexDataType::Float, }
    Float32 => { size: 4, components: 1, data_type: VertexDataType::Float, }
    Float32x2 => { size: 8, components: 2, data_type: VertexDataType::Float, }
    Float32x3 => { size: 12, components: 3, data_type: VertexDataType::Float, }
    Float32x4 => { size: 16, components: 4, data_type: VertexDataType::Float, }
    Uint32 => { size: 4, components: 1, data_type: VertexDataType::Uint, }
    Uint32x2 => { size: 8, components: 2, data_type: VertexDataType::Uint, }
    Uint32x3 => { size: 12, components: 3, data_type: VertexDataType::Uint, }
    Uint32x4 => { size: 16, components: 4, data_type: VertexDataType::Uint, }
    Sint32 => { size: 4, components: 1, data_type: VertexDataType::Sint, }
    Sint32x2 => { size: 8, components: 2, data_type: VertexDataType::Sint, }
    Sint32x3 => { size: 12, components: 3, data_type: VertexDataType::Sint, }
    Sint32x4 => { size: 16, components: 4, data_type: VertexDataType::Sint, }
    Unorm1010102 =>
      { size: 4, components: 4, data_type: VertexDataType::Unorm, }
    Unorm8x4Bgra =>
      { size: 4, components: 4, data_type: VertexDataType::Unorm, }
    Snorm1010102 =>
      { size: 4, components: 4, data_type: VertexDataType::Snorm, }
  }
}

///|
/// The bytes one vertex of this attribute occupies.
pub fn VertexFormat::size(self : VertexFormat) -> Int32 {
  self.info().size
}

///|
/// How many components the attribute has.
pub fn VertexFormat::components(self : VertexFormat) -> Int32 {
  self.info().components
}

///|
/// The alignment an attribute offset must be a multiple of: the smaller of
/// four bytes and the size of the whole attribute.
pub fn VertexFormat::alignment(self : VertexFormat) -> Int32 {
  let size = self.size()
  if size < 4 {
    size
  } else {
    4
  }
}

///|
/// The format string the specification uses, as in `"unorm10-10-10-2"`.
pub fn VertexFormat::name(self : VertexFormat) -> String {
  match self {
    Uint8 => "uint8"
    Uint8x2 => "uint8x2"
    Uint8x4 => "uint8x4"
    Sint8 => "sint8"
    Sint8x2 => "sint8x2"
    Sint8x4 => "sint8x4"
    Unorm8 => "unorm8"
    Unorm8x2 => "unorm8x2"
    Unorm8x4 => "unorm8x4"
    Snorm8 => "snorm8"
    Snorm8x2 => "snorm8x2"
    Snorm8x4 => "snorm8x4"
    Uint16 => "uint16"
    Uint16x2 => "uint16x2"
    Uint16x4 => "uint16x4"
    Sint16 => "sint16"
    Sint16x2 => "sint16x2"
    Sint16x4 => "sint16x4"
    Unorm16 => "unorm16"
    Unorm16x2 => "unorm16x2"
    Unorm16x4 => "unorm16x4"
    Snorm16 => "snorm16"
    Snorm16x2 => "snorm16x2"
    Snorm16x4 => "snorm16x4"
    Float16 => "float16"
    Float16x2 => "float16x2"
    Float16x4 => "float16x4"
    Float32 => "float32"
    Float32x2 => "float32x2"
    Float32x3 => "float32x3"
    Float32x4 => "float32x4"
    Uint32 => "uint32"
    Uint32x2 => "uint32x2"
    Uint32x3 => "uint32x3"
    Uint32x4 => "uint32x4"
    Sint32 => "sint32"
    Sint32x2 => "sint32x2"
    Sint32x3 => "sint32x3"
    Sint32x4 => "sint32x4"
    Unorm1010102 => "unorm10-10-10-2"
    Unorm8x4Bgra => "unorm8x4-bgra"
    Snorm1010102 => "snorm10-10-10-2"
  }
}

///|
/// Every vertex format, in specification order.
pub fn VertexFormat::all() -> Array[VertexFormat] {
  [
    Uint8,
    Uint8x2,
    Uint8x4,
    Sint8,
    Sint8x2,
    Sint8x4,
    Unorm8,
    Unorm8x2,
    Unorm8x4,
    Snorm8,
    Snorm8x2,
    Snorm8x4,
    Uint16,
    Uint16x2,
    Uint16x4,
    Sint16,
    Sint16x2,
    Sint16x4,
    Unorm16,
    Unorm16x2,
    Unorm16x4,
    Snorm16,
    Snorm16x2,
    Snorm16x4,
    Float16,
    Float16x2,
    Float16x4,
    Float32,
    Float32x2,
    Float32x3,
    Float32x4,
    Uint32,
    Uint32x2,
    Uint32x3,
    Uint32x4,
    Sint32,
    Sint32x2,
    Sint32x3,
    Sint32x4,
    Unorm1010102,
    Unorm8x4Bgra,
    Snorm1010102,
  ]
}

///|
pub impl Show for VertexFormat with fn to_string(self) {
  self.name()
}
