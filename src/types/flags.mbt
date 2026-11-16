// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The set of `GPUBufferUsage` bits of one buffer.
///
/// A flag set is not an enumeration: the specification lets any combination
/// that is not empty, except that `map_read` and `map_write` exclude each
/// other on the same buffer. The bits are private so that a caller cannot
/// invent a value the specification does not define.
#derive(Eq, Debug)
pub struct BufferUsages(UInt32)

///|
pub fn BufferUsages::none() -> BufferUsages {
  BufferUsages(0U)
}

///|
/// The buffer can be mapped for reading: `map_read` and `get_mapped_range`.
pub fn BufferUsages::map_read() -> BufferUsages {
  BufferUsages(0x0001U)
}

///|
/// The buffer can be mapped for writing with `map_write`.
pub fn BufferUsages::map_write() -> BufferUsages {
  BufferUsages(0x0002U)
}

///|
/// The buffer is a copy source.
pub fn BufferUsages::copy_src() -> BufferUsages {
  BufferUsages(0x0004U)
}

///|
/// The buffer is a copy destination, including `queue.write_buffer`.
pub fn BufferUsages::copy_dst() -> BufferUsages {
  BufferUsages(0x0008U)
}

///|
/// The buffer holds index data.
pub fn BufferUsages::index() -> BufferUsages {
  BufferUsages(0x0010U)
}

///|
/// The buffer holds vertex data.
pub fn BufferUsages::vertex() -> BufferUsages {
  BufferUsages(0x0020U)
}

///|
/// The buffer is bound as a uniform buffer.
pub fn BufferUsages::uniform() -> BufferUsages {
  BufferUsages(0x0040U)
}

///|
/// The buffer is bound as a storage buffer.
pub fn BufferUsages::storage() -> BufferUsages {
  BufferUsages(0x0080U)
}

///|
/// The buffer holds arguments of an indirect draw or dispatch.
pub fn BufferUsages::indirect() -> BufferUsages {
  BufferUsages(0x0100U)
}

///|
/// The buffer receives the results of `resolve_query_set`.
pub fn BufferUsages::query_resolve() -> BufferUsages {
  BufferUsages(0x0200U)
}

///|
/// Every bit the specification defines.
pub fn BufferUsages::all() -> BufferUsages {
  BufferUsages(0x03FFU)
}

///|
/// The raw bits, for serialisation and for comparisons the type system cannot
/// express.
pub fn BufferUsages::bits(self : BufferUsages) -> UInt32 {
  self.0
}

///|
/// Whether every bit of `other` is set here.
pub fn BufferUsages::contains(
  self : BufferUsages,
  other : BufferUsages,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
/// Whether at least one bit of `other` is set here.
pub fn BufferUsages::intersects(
  self : BufferUsages,
  other : BufferUsages,
) -> Bool {
  (self.0 & other.0) != 0U
}

///|
pub fn BufferUsages::is_empty(self : BufferUsages) -> Bool {
  self.0 == 0U
}

///|
pub impl BitOr for BufferUsages with fn lor(self, other) {
  BufferUsages(self.0 | other.0)
}

///|
pub impl BitAnd for BufferUsages with fn land(self, other) {
  BufferUsages(self.0 & other.0)
}

///|
pub impl Sub for BufferUsages with fn sub(self, other) {
  BufferUsages(self.0 & (other.0 ^ 0xFFFF_FFFFU))
}

///|
/// The set of `GPUTextureUsage` bits of one texture.
#derive(Eq, Debug)
pub struct TextureUsages(UInt32)

///|
pub fn TextureUsages::none() -> TextureUsages {
  TextureUsages(0U)
}

///|
pub fn TextureUsages::copy_src() -> TextureUsages {
  TextureUsages(0x0001U)
}

///|
pub fn TextureUsages::copy_dst() -> TextureUsages {
  TextureUsages(0x0002U)
}

///|
pub fn TextureUsages::texture_binding() -> TextureUsages {
  TextureUsages(0x0004U)
}

///|
pub fn TextureUsages::storage_binding() -> TextureUsages {
  TextureUsages(0x0008U)
}

///|
pub fn TextureUsages::render_attachment() -> TextureUsages {
  TextureUsages(0x0010U)
}

///|
pub fn TextureUsages::all() -> TextureUsages {
  TextureUsages(0x001FU)
}

///|
pub fn TextureUsages::bits(self : TextureUsages) -> UInt32 {
  self.0
}

///|
pub fn TextureUsages::contains(
  self : TextureUsages,
  other : TextureUsages,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub fn TextureUsages::intersects(
  self : TextureUsages,
  other : TextureUsages,
) -> Bool {
  (self.0 & other.0) != 0U
}

///|
pub fn TextureUsages::is_empty(self : TextureUsages) -> Bool {
  self.0 == 0U
}

///|
pub impl BitOr for TextureUsages with fn lor(self, other) {
  TextureUsages(self.0 | other.0)
}

///|
pub impl BitAnd for TextureUsages with fn land(self, other) {
  TextureUsages(self.0 & other.0)
}

///|
pub impl Sub for TextureUsages with fn sub(self, other) {
  TextureUsages(self.0 & (other.0 ^ 0xFFFF_FFFFU))
}

///|
/// The set of `GPUShaderStage` bits an entry of a bind group layout is visible
/// to.
#derive(Eq, Debug)
pub struct ShaderStages(UInt32)

///|
pub fn ShaderStages::none() -> ShaderStages {
  ShaderStages(0U)
}

///|
pub fn ShaderStages::vertex() -> ShaderStages {
  ShaderStages(0x0001U)
}

///|
pub fn ShaderStages::fragment() -> ShaderStages {
  ShaderStages(0x0002U)
}

///|
pub fn ShaderStages::compute() -> ShaderStages {
  ShaderStages(0x0004U)
}

///|
pub fn ShaderStages::all() -> ShaderStages {
  ShaderStages(0x0007U)
}

///|
pub fn ShaderStages::bits(self : ShaderStages) -> UInt32 {
  self.0
}

///|
pub fn ShaderStages::contains(
  self : ShaderStages,
  other : ShaderStages,
) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub fn ShaderStages::intersects(
  self : ShaderStages,
  other : ShaderStages,
) -> Bool {
  (self.0 & other.0) != 0U
}

///|
pub fn ShaderStages::is_empty(self : ShaderStages) -> Bool {
  self.0 == 0U
}

///|
pub impl BitOr for ShaderStages with fn lor(self, other) {
  ShaderStages(self.0 | other.0)
}

///|
pub impl BitAnd for ShaderStages with fn land(self, other) {
  ShaderStages(self.0 & other.0)
}

///|
/// The set of `GPUColorWrite` bits a color target writes.
#derive(Eq, Debug)
pub struct ColorWrites(UInt32)

///|
pub fn ColorWrites::none() -> ColorWrites {
  ColorWrites(0U)
}

///|
pub fn ColorWrites::red() -> ColorWrites {
  ColorWrites(0x0001U)
}

///|
pub fn ColorWrites::green() -> ColorWrites {
  ColorWrites(0x0002U)
}

///|
pub fn ColorWrites::blue() -> ColorWrites {
  ColorWrites(0x0004U)
}

///|
pub fn ColorWrites::alpha() -> ColorWrites {
  ColorWrites(0x0008U)
}

///|
/// Every channel: the value a target uses when it does not say otherwise.
pub fn ColorWrites::all() -> ColorWrites {
  ColorWrites(0x000FU)
}

///|
pub fn ColorWrites::bits(self : ColorWrites) -> UInt32 {
  self.0
}

///|
pub fn ColorWrites::contains(self : ColorWrites, other : ColorWrites) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub fn ColorWrites::is_empty(self : ColorWrites) -> Bool {
  self.0 == 0U
}

///|
pub impl BitOr for ColorWrites with fn lor(self, other) {
  ColorWrites(self.0 | other.0)
}

///|
pub impl BitAnd for ColorWrites with fn land(self, other) {
  ColorWrites(self.0 & other.0)
}

///|
/// The two `GPUMapMode` bits.
#derive(Eq, Debug)
pub struct MapMode(UInt32)

///|
pub fn MapMode::none() -> MapMode {
  MapMode(0U)
}

///|
/// The mapped range may be read: `map_read`.
pub fn MapMode::read() -> MapMode {
  MapMode(0x0001U)
}

///|
/// The mapped range may be written: `map_write`.
pub fn MapMode::write() -> MapMode {
  MapMode(0x0002U)
}

///|
pub fn MapMode::bits(self : MapMode) -> UInt32 {
  self.0
}

///|
pub fn MapMode::contains(self : MapMode, other : MapMode) -> Bool {
  (self.0 & other.0) == other.0
}

///|
pub fn MapMode::is_empty(self : MapMode) -> Bool {
  self.0 == 0U
}

///|
pub impl BitOr for MapMode with fn lor(self, other) {
  MapMode(self.0 | other.0)
}

///|
pub impl BitAnd for MapMode with fn land(self, other) {
  MapMode(self.0 & other.0)
}
