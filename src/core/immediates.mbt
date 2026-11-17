// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The arguments of `setImmediates`, checked and taken as one run of bytes.
///
/// The specification loads the bytes into a range of the immediate constants of
/// the bind group that was bound before the draw or dispatch; both the range and
/// the bytes are counted in four-byte words, which is the alignment hardware
/// keeps them in.
/// https://www.w3.org/TR/webgpu/#dom-gpubindingcommandsmixin-setimmediates
pub fn immediates(
  range_offset : Int32,
  data : Bytes,
  data_offset : Int32,
  data_size : Int32?,
) -> @types.SetImmediates raise Refused {
  require_same(0, range_offset % 4, @types.InvalidAlignment, "rangeOffset")
  require_int(
    data_offset >= 0 && data_offset <= data.length(),
    @types.InvalidCopyRange,
    "dataOffset",
    data.length(),
    data_offset,
  )
  require_same(0, data_offset % 4, @types.InvalidAlignment, "dataOffset")
  let size = match data_size {
    Some(size) => size
    None => data.length() - data_offset
  }
  require_same(0, size % 4, @types.InvalidAlignment, "dataSize")
  require_int(
    size > 0 && data_offset + size <= data.length(),
    @types.InvalidCopyRange,
    "dataOffset + dataSize",
    data.length(),
    data_offset + size,
  )
  { range_offset, data: data[data_offset:data_offset + size].to_owned(), }
}
