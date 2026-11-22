// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The seam to `stub.c`.
///
/// One declaration per entry point, and on the targets without a C compiler a
/// stand-in that reports nothing: a shader the backend cannot reach refuses
/// with `Unsupported` instead of pretending a handle exists. Handles are
/// `Int64` the whole way through, so no foreign type crosses the boundary.
#cfg(target="native")
extern "C" fn vk_available() -> Int64 = "mwg_vk_available"

///|
#cfg(not(target="native"))
fn vk_available() -> Int64 {
  0
}

///|
/// Copy the last error message into `dst` and return its length.
#cfg(target="native")
#borrow(dst)
extern "C" fn vk_error_copy(dst : FixedArray[Byte], capacity : Int32) -> Int64 = "mwg_vk_error_copy"

///|
#cfg(not(target="native"))
fn vk_error_copy(_dst : FixedArray[Byte], _capacity : Int32) -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_instance_create() -> Int64 = "mwg_vk_instance_create"

///|
#cfg(not(target="native"))
fn vk_instance_create() -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_instance_destroy(instance : Int64) = "mwg_vk_instance_destroy"

///|
#cfg(not(target="native"))
fn vk_instance_destroy(_instance : Int64) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_device_count(instance : Int64) -> Int32 = "mwg_vk_device_count"

///|
#cfg(not(target="native"))
fn vk_device_count(_instance : Int64) -> Int32 {
  0
}

///|
/// Fill 512 bytes: the device name, then four 64-bit numbers.
#cfg(target="native")
#borrow(dst)
extern "C" fn vk_physical_info(
  instance : Int64,
  index : Int32,
  dst : FixedArray[Byte],
) -> Int64 = "mwg_vk_physical_info"

///|
#cfg(not(target="native"))
fn vk_physical_info(
  _instance : Int64,
  _index : Int32,
  _dst : FixedArray[Byte],
) -> Int64 {
  0
}

///|
#cfg(target="native")
#borrow(report)
extern "C" fn vk_device_create(
  instance : Int64,
  index : Int32,
  report : FixedArray[Int64],
) -> Int64 = "mwg_vk_device_create"

///|
#cfg(not(target="native"))
fn vk_device_create(
  _instance : Int64,
  _index : Int32,
  _report : FixedArray[Int64],
) -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_device_destroy(device : Int64) = "mwg_vk_device_destroy"

///|
#cfg(not(target="native"))
fn vk_device_destroy(_device : Int64) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_device_wait(device : Int64) -> Int64 = "mwg_vk_device_wait"

///|
#cfg(not(target="native"))
fn vk_device_wait(_device : Int64) -> Int64 {
  0
}

///|
/// A Vulkan `VkFormat` from a name, or zero when the name is unknown.
#cfg(target="native")
#borrow(name)
extern "C" fn vk_format(name : Bytes, length : Int32) -> Int64 = "mwg_vk_format"

///|
#cfg(not(target="native"))
fn vk_format(_name : Bytes, _length : Int32) -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_buffer_create(
  device : Int64,
  size : Int32,
  usage : Int32,
  zero : Int32,
) -> Int64 = "mwg_vk_buffer_create"

///|
#cfg(not(target="native"))
fn vk_buffer_create(
  _device : Int64,
  _size : Int32,
  _usage : Int32,
  _zero : Int32,
) -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_buffer_destroy(buffer : Int64) = "mwg_vk_buffer_destroy"

///|
#cfg(not(target="native"))
fn vk_buffer_destroy(_buffer : Int64) -> Unit {

}

///|
#cfg(target="native")
#borrow(source)
extern "C" fn vk_buffer_write(
  buffer : Int64,
  offset : Int32,
  source : Bytes,
  length : Int32,
) -> Int32 = "mwg_vk_buffer_write"

///|
#cfg(not(target="native"))
fn vk_buffer_write(
  _buffer : Int64,
  _offset : Int32,
  _source : Bytes,
  _length : Int32,
) -> Int32 {
  0
}

///|
#cfg(target="native")
#borrow(dst)
extern "C" fn vk_buffer_read(
  buffer : Int64,
  offset : Int32,
  dst : FixedArray[Byte],
  length : Int32,
) -> Int32 = "mwg_vk_buffer_read"

///|
#cfg(not(target="native"))
fn vk_buffer_read(
  _buffer : Int64,
  _offset : Int32,
  _dst : FixedArray[Byte],
  _length : Int32,
) -> Int32 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_texture_create(
  device : Int64,
  width : Int32,
  height : Int32,
  depth : Int32,
  layers : Int32,
  mips : Int32,
  samples : Int32,
  dimension : Int32,
  format : Int64,
  usage : Int32,
) -> Int64 = "mwg_vk_texture_create"

///|
#cfg(not(target="native"))
fn vk_texture_create(
  _device : Int64,
  _width : Int32,
  _height : Int32,
  _depth : Int32,
  _layers : Int32,
  _mips : Int32,
  _samples : Int32,
  _dimension : Int32,
  _format : Int64,
  _usage : Int32,
) -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_texture_destroy(texture : Int64) = "mwg_vk_texture_destroy"

///|
#cfg(not(target="native"))
fn vk_texture_destroy(_texture : Int64) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_view_create(
  device : Int64,
  texture : Int64,
  format : Int64,
  dimension : Int32,
  aspect : Int32,
  base_mip : Int32,
  mip_count : Int32,
  base_layer : Int32,
  layer_count : Int32,
) -> Int64 = "mwg_vk_view_create"

///|
#cfg(not(target="native"))
fn vk_view_create(
  _device : Int64,
  _texture : Int64,
  _format : Int64,
  _dimension : Int32,
  _aspect : Int32,
  _base_mip : Int32,
  _mip_count : Int32,
  _base_layer : Int32,
  _layer_count : Int32,
) -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_view_destroy(view : Int64) = "mwg_vk_view_destroy"

///|
#cfg(not(target="native"))
fn vk_view_destroy(_view : Int64) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_sampler_create(
  device : Int64,
  mag : Int32,
  min : Int32,
  mip : Int32,
  address_u : Int32,
  address_v : Int32,
  address_w : Int32,
  lod_min : Double,
  lod_max : Double,
  compare_enabled : Int32,
  compare : Int32,
  anisotropy : Double,
) -> Int64 = "mwg_vk_sampler_create"

///|
#cfg(not(target="native"))
fn vk_sampler_create(
  _device : Int64,
  _mag : Int32,
  _min : Int32,
  _mip : Int32,
  _address_u : Int32,
  _address_v : Int32,
  _address_w : Int32,
  _lod_min : Double,
  _lod_max : Double,
  _compare_enabled : Int32,
  _compare : Int32,
  _anisotropy : Double,
) -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_sampler_destroy(sampler : Int64) = "mwg_vk_sampler_destroy"

///|
#cfg(not(target="native"))
fn vk_sampler_destroy(_sampler : Int64) -> Unit {

}

///|
#cfg(target="native")
#borrow(words)
extern "C" fn vk_shader_create(
  device : Int64,
  words : Bytes,
  length : Int32,
) -> Int64 = "mwg_vk_shader_create"

///|
#cfg(not(target="native"))
fn vk_shader_create(_device : Int64, _words : Bytes, _length : Int32) -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_shader_destroy(shader : Int64) = "mwg_vk_shader_destroy"

///|
#cfg(not(target="native"))
fn vk_shader_destroy(_shader : Int64) -> Unit {

}

///|
#cfg(target="native")
#borrow(entries)
extern "C" fn vk_set_layout_create(
  device : Int64,
  entries : FixedArray[Int32],
  count : Int32,
) -> Int64 = "mwg_vk_set_layout_create"

///|
#cfg(not(target="native"))
fn vk_set_layout_create(
  _device : Int64,
  _entries : FixedArray[Int32],
  _count : Int32,
) -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_set_layout_destroy(layout : Int64) = "mwg_vk_set_layout_destroy"

///|
#cfg(not(target="native"))
fn vk_set_layout_destroy(_layout : Int64) -> Unit {

}

///|
#cfg(target="native")
#borrow(layouts)
extern "C" fn vk_pipeline_layout_create(
  device : Int64,
  layouts : FixedArray[Int64],
  count : Int32,
) -> Int64 = "mwg_vk_pipeline_layout_create"

///|
#cfg(not(target="native"))
fn vk_pipeline_layout_create(
  _device : Int64,
  _layouts : FixedArray[Int64],
  _count : Int32,
) -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_pipeline_layout_destroy(layout : Int64) = "mwg_vk_pipeline_layout_destroy"

///|
#cfg(not(target="native"))
fn vk_pipeline_layout_destroy(_layout : Int64) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_set_create(device : Int64, layout : Int64) -> Int64 = "mwg_vk_set_create"

///|
#cfg(not(target="native"))
fn vk_set_create(_device : Int64, _layout : Int64) -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_set_destroy(set : Int64) = "mwg_vk_set_destroy"

///|
#cfg(not(target="native"))
fn vk_set_destroy(_set : Int64) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_set_buffer(
  set : Int64,
  binding : Int32,
  buffer : Int64,
  offset : Int32,
  size : Int32,
  kind : Int32,
) -> Int32 = "mwg_vk_set_buffer"

///|
#cfg(not(target="native"))
fn vk_set_buffer(
  _set : Int64,
  _binding : Int32,
  _buffer : Int64,
  _offset : Int32,
  _size : Int32,
  _kind : Int32,
) -> Int32 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_set_sampler(
  set : Int64,
  binding : Int32,
  sampler : Int64,
) -> Int32 = "mwg_vk_set_sampler"

///|
#cfg(not(target="native"))
fn vk_set_sampler(_set : Int64, _binding : Int32, _sampler : Int64) -> Int32 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_set_texture(
  set : Int64,
  binding : Int32,
  view : Int64,
  kind : Int32,
) -> Int32 = "mwg_vk_set_texture"

///|
#cfg(not(target="native"))
fn vk_set_texture(
  _set : Int64,
  _binding : Int32,
  _view : Int64,
  _kind : Int32,
) -> Int32 {
  0
}

///|
#cfg(target="native")
#borrow(vertex_entry, fragment_entry, stream)
extern "C" fn vk_render_pipeline_create(
  device : Int64,
  layout : Int64,
  vertex : Int64,
  vertex_entry : Bytes,
  vertex_length : Int32,
  fragment : Int64,
  fragment_entry : Bytes,
  fragment_length : Int32,
  stream : FixedArray[Int32],
  count : Int32,
  bias_constant : Int32,
  bias_slope : Double,
  bias_clamp : Double,
) -> Int64 = "mwg_vk_render_pipeline_create"

///|
#cfg(not(target="native"))
fn vk_render_pipeline_create(
  _device : Int64,
  _layout : Int64,
  _vertex : Int64,
  _vertex_entry : Bytes,
  _vertex_length : Int32,
  _fragment : Int64,
  _fragment_entry : Bytes,
  _fragment_length : Int32,
  _stream : FixedArray[Int32],
  _count : Int32,
  _bias_constant : Int32,
  _bias_slope : Double,
  _bias_clamp : Double,
) -> Int64 {
  0
}

///|
#cfg(target="native")
#borrow(entry)
extern "C" fn vk_compute_pipeline_create(
  device : Int64,
  layout : Int64,
  compute : Int64,
  entry : Bytes,
  length : Int32,
) -> Int64 = "mwg_vk_compute_pipeline_create"

///|
#cfg(not(target="native"))
fn vk_compute_pipeline_create(
  _device : Int64,
  _layout : Int64,
  _compute : Int64,
  _entry : Bytes,
  _length : Int32,
) -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_pipeline_destroy(pipeline : Int64) = "mwg_vk_pipeline_destroy"

///|
#cfg(not(target="native"))
fn vk_pipeline_destroy(_pipeline : Int64) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_queries_create(
  device : Int64,
  kind : Int32,
  count : Int32,
) -> Int64 = "mwg_vk_queries_create"

///|
#cfg(not(target="native"))
fn vk_queries_create(_device : Int64, _kind : Int32, _count : Int32) -> Int64 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_queries_destroy(queries : Int64) = "mwg_vk_queries_destroy"

///|
#cfg(not(target="native"))
fn vk_queries_destroy(_queries : Int64) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_record_begin(device : Int64) -> Int32 = "mwg_vk_record_begin"

///|
#cfg(not(target="native"))
fn vk_record_begin(_device : Int64) -> Int32 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_record_submit(device : Int64) -> Int32 = "mwg_vk_record_submit"

///|
#cfg(not(target="native"))
fn vk_record_submit(_device : Int64) -> Int32 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_record_abandon(device : Int64) = "mwg_vk_record_abandon"

///|
#cfg(not(target="native"))
fn vk_record_abandon(_device : Int64) -> Unit {

}

///|
#cfg(target="native")
#borrow(views, formats, loads, stores, clears)
extern "C" fn vk_begin_render(
  device : Int64,
  width : Int32,
  height : Int32,
  colors : Int32,
  views : FixedArray[Int64],
  formats : FixedArray[Int64],
  loads : FixedArray[Int32],
  stores : FixedArray[Int32],
  clears : FixedArray[Double],
  depth_view : Int64,
  depth_format : Int64,
  depth_load : Int32,
  depth_store : Int32,
  depth_clear : Double,
  stencil_clear : Int32,
  depth_read_only : Int32,
) -> Int32 = "mwg_vk_begin_render"

///|
#cfg(not(target="native"))
fn vk_begin_render(
  _device : Int64,
  _width : Int32,
  _height : Int32,
  _colors : Int32,
  _views : FixedArray[Int64],
  _formats : FixedArray[Int64],
  _loads : FixedArray[Int32],
  _stores : FixedArray[Int32],
  _clears : FixedArray[Double],
  _depth_view : Int64,
  _depth_format : Int64,
  _depth_load : Int32,
  _depth_store : Int32,
  _depth_clear : Double,
  _stencil_clear : Int32,
  _depth_read_only : Int32,
) -> Int32 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_end_render(device : Int64) = "mwg_vk_end_render"

///|
#cfg(not(target="native"))
fn vk_end_render(_device : Int64) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_begin_compute(device : Int64) = "mwg_vk_begin_compute"

///|
#cfg(not(target="native"))
fn vk_begin_compute(_device : Int64) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_end_compute(device : Int64) = "mwg_vk_end_compute"

///|
#cfg(not(target="native"))
fn vk_end_compute(_device : Int64) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_bind_pipeline(device : Int64, pipeline : Int64) = "mwg_vk_bind_pipeline"

///|
#cfg(not(target="native"))
fn vk_bind_pipeline(_device : Int64, _pipeline : Int64) -> Unit {

}

///|
#cfg(target="native")
#borrow(offsets)
extern "C" fn vk_bind_set(
  device : Int64,
  index : Int32,
  set : Int64,
  offsets : FixedArray[Int32],
  count : Int32,
  compute : Int32,
) = "mwg_vk_bind_set"

///|
#cfg(not(target="native"))
fn vk_bind_set(
  _device : Int64,
  _index : Int32,
  _set : Int64,
  _offsets : FixedArray[Int32],
  _count : Int32,
  _compute : Int32,
) -> Unit {

}

///|
#cfg(target="native")
#borrow(data)
extern "C" fn vk_push_constants(
  device : Int64,
  offset : Int32,
  data : Bytes,
  length : Int32,
  compute : Int32,
) = "mwg_vk_push_constants"

///|
#cfg(not(target="native"))
fn vk_push_constants(
  _device : Int64,
  _offset : Int32,
  _data : Bytes,
  _length : Int32,
  _compute : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_vertex_buffer(
  device : Int64,
  slot : Int32,
  buffer : Int64,
  offset : Int32,
) = "mwg_vk_vertex_buffer"

///|
#cfg(not(target="native"))
fn vk_vertex_buffer(
  _device : Int64,
  _slot : Int32,
  _buffer : Int64,
  _offset : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_index_buffer(
  device : Int64,
  buffer : Int64,
  offset : Int32,
  format : Int32,
) = "mwg_vk_index_buffer"

///|
#cfg(not(target="native"))
fn vk_index_buffer(
  _device : Int64,
  _buffer : Int64,
  _offset : Int32,
  _format : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_draw(
  device : Int64,
  vertices : Int32,
  instances : Int32,
  first_vertex : Int32,
  first_instance : Int32,
) = "mwg_vk_draw"

///|
#cfg(not(target="native"))
fn vk_draw(
  _device : Int64,
  _vertices : Int32,
  _instances : Int32,
  _first_vertex : Int32,
  _first_instance : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_draw_indexed(
  device : Int64,
  indices : Int32,
  instances : Int32,
  first_index : Int32,
  base_vertex : Int32,
  first_instance : Int32,
) = "mwg_vk_draw_indexed"

///|
#cfg(not(target="native"))
fn vk_draw_indexed(
  _device : Int64,
  _indices : Int32,
  _instances : Int32,
  _first_index : Int32,
  _base_vertex : Int32,
  _first_instance : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_draw_indirect(
  device : Int64,
  buffer : Int64,
  offset : Int32,
  indexed : Int32,
) = "mwg_vk_draw_indirect"

///|
#cfg(not(target="native"))
fn vk_draw_indirect(
  _device : Int64,
  _buffer : Int64,
  _offset : Int32,
  _indexed : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_dispatch(device : Int64, x : Int32, y : Int32, z : Int32) = "mwg_vk_dispatch"

///|
#cfg(not(target="native"))
fn vk_dispatch(_device : Int64, _x : Int32, _y : Int32, _z : Int32) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_dispatch_indirect(
  device : Int64,
  buffer : Int64,
  offset : Int32,
) = "mwg_vk_dispatch_indirect"

///|
#cfg(not(target="native"))
fn vk_dispatch_indirect(
  _device : Int64,
  _buffer : Int64,
  _offset : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_viewport(
  device : Int64,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  min_depth : Double,
  max_depth : Double,
) = "mwg_vk_viewport"

///|
#cfg(not(target="native"))
fn vk_viewport(
  _device : Int64,
  _x : Double,
  _y : Double,
  _width : Double,
  _height : Double,
  _min_depth : Double,
  _max_depth : Double,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_scissor(
  device : Int64,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
) = "mwg_vk_scissor"

///|
#cfg(not(target="native"))
fn vk_scissor(
  _device : Int64,
  _x : Int32,
  _y : Int32,
  _width : Int32,
  _height : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_blend_constants(
  device : Int64,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
) = "mwg_vk_blend_constants"

///|
#cfg(not(target="native"))
fn vk_blend_constants(
  _device : Int64,
  _r : Double,
  _g : Double,
  _b : Double,
  _a : Double,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_stencil_reference(device : Int64, reference : Int32) = "mwg_vk_stencil_reference"

///|
#cfg(not(target="native"))
fn vk_stencil_reference(_device : Int64, _reference : Int32) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_begin_query(device : Int64, queries : Int64, index : Int32) = "mwg_vk_begin_query"

///|
#cfg(not(target="native"))
fn vk_begin_query(_device : Int64, _queries : Int64, _index : Int32) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_end_query(device : Int64, queries : Int64, index : Int32) = "mwg_vk_end_query"

///|
#cfg(not(target="native"))
fn vk_end_query(_device : Int64, _queries : Int64, _index : Int32) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_write_timestamp(
  device : Int64,
  queries : Int64,
  index : Int32,
) = "mwg_vk_write_timestamp"

///|
#cfg(not(target="native"))
fn vk_write_timestamp(
  _device : Int64,
  _queries : Int64,
  _index : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_resolve_queries(
  device : Int64,
  queries : Int64,
  first : Int32,
  count : Int32,
  buffer : Int64,
  offset : Int32,
) = "mwg_vk_resolve_queries"

///|
#cfg(not(target="native"))
fn vk_resolve_queries(
  _device : Int64,
  _queries : Int64,
  _first : Int32,
  _count : Int32,
  _buffer : Int64,
  _offset : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_barrier(
  device : Int64,
  texture : Int64,
  mip : Int32,
  base_layer : Int32,
  layer_count : Int32,
  old_layout : Int32,
  new_layout : Int32,
  from_use : Int32,
  to_use : Int32,
) = "mwg_vk_barrier"

///|
#cfg(not(target="native"))
fn vk_barrier(
  _device : Int64,
  _texture : Int64,
  _mip : Int32,
  _base_layer : Int32,
  _layer_count : Int32,
  _old_layout : Int32,
  _new_layout : Int32,
  _from_use : Int32,
  _to_use : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_copy_buffer(
  device : Int64,
  source : Int64,
  source_offset : Int32,
  destination : Int64,
  destination_offset : Int32,
  size : Int32,
) = "mwg_vk_copy_buffer"

///|
#cfg(not(target="native"))
fn vk_copy_buffer(
  _device : Int64,
  _source : Int64,
  _source_offset : Int32,
  _destination : Int64,
  _destination_offset : Int32,
  _size : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_fill_buffer(
  device : Int64,
  buffer : Int64,
  offset : Int32,
  size : Int32,
  value : Int32,
) = "mwg_vk_fill_buffer"

///|
#cfg(not(target="native"))
fn vk_fill_buffer(
  _device : Int64,
  _buffer : Int64,
  _offset : Int32,
  _size : Int32,
  _value : Int32,
) -> Unit {

}

///|
#cfg(target="native")
#borrow(color, uint_color)
extern "C" fn vk_clear_texture(
  device : Int64,
  texture : Int64,
  mip : Int32,
  x : Int32,
  y : Int32,
  z : Int32,
  width : Int32,
  height : Int32,
  depth : Int32,
  is_float : Int32,
  color : FixedArray[Double],
  uint_color : FixedArray[Int32],
  depth_value : Double,
  stencil_value : Int32,
  stencil_only : Int32,
) = "mwg_vk_clear_texture"

///|
#cfg(not(target="native"))
fn vk_clear_texture(
  _device : Int64,
  _texture : Int64,
  _mip : Int32,
  _x : Int32,
  _y : Int32,
  _z : Int32,
  _width : Int32,
  _height : Int32,
  _depth : Int32,
  _is_float : Int32,
  _color : FixedArray[Double],
  _uint_color : FixedArray[Int32],
  _depth_value : Double,
  _stencil_value : Int32,
  _stencil_only : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_copy_buffer_to_texture(
  device : Int64,
  buffer : Int64,
  buffer_offset : Int32,
  bytes_per_row : Int32,
  rows_per_image : Int32,
  texture : Int64,
  mip : Int32,
  x : Int32,
  y : Int32,
  z : Int32,
  width : Int32,
  height : Int32,
  depth : Int32,
) = "mwg_vk_copy_buffer_to_texture"

///|
#cfg(not(target="native"))
fn vk_copy_buffer_to_texture(
  _device : Int64,
  _buffer : Int64,
  _buffer_offset : Int32,
  _bytes_per_row : Int32,
  _rows_per_image : Int32,
  _texture : Int64,
  _mip : Int32,
  _x : Int32,
  _y : Int32,
  _z : Int32,
  _width : Int32,
  _height : Int32,
  _depth : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_copy_texture_to_buffer(
  device : Int64,
  texture : Int64,
  mip : Int32,
  x : Int32,
  y : Int32,
  z : Int32,
  width : Int32,
  height : Int32,
  depth : Int32,
  buffer : Int64,
  buffer_offset : Int32,
  bytes_per_row : Int32,
  rows_per_image : Int32,
) = "mwg_vk_copy_texture_to_buffer"

///|
#cfg(not(target="native"))
fn vk_copy_texture_to_buffer(
  _device : Int64,
  _texture : Int64,
  _mip : Int32,
  _x : Int32,
  _y : Int32,
  _z : Int32,
  _width : Int32,
  _height : Int32,
  _depth : Int32,
  _buffer : Int64,
  _buffer_offset : Int32,
  _bytes_per_row : Int32,
  _rows_per_image : Int32,
) -> Unit {

}

///|
#cfg(target="native")
extern "C" fn vk_copy_texture(
  device : Int64,
  source : Int64,
  source_mip : Int32,
  x : Int32,
  y : Int32,
  z : Int32,
  destination : Int64,
  destination_mip : Int32,
  destination_x : Int32,
  destination_y : Int32,
  destination_z : Int32,
  width : Int32,
  height : Int32,
  depth : Int32,
) = "mwg_vk_copy_texture"

///|
#cfg(not(target="native"))
fn vk_copy_texture(
  _device : Int64,
  _source : Int64,
  _source_mip : Int32,
  _x : Int32,
  _y : Int32,
  _z : Int32,
  _destination : Int64,
  _destination_mip : Int32,
  _destination_x : Int32,
  _destination_y : Int32,
  _destination_z : Int32,
  _width : Int32,
  _height : Int32,
  _depth : Int32,
) -> Unit {

}

///|
#cfg(target="native")
#borrow(dst)
extern "C" fn vk_texture_read(
  device : Int64,
  texture : Int64,
  mip : Int32,
  x : Int32,
  y : Int32,
  z : Int32,
  width : Int32,
  height : Int32,
  depth : Int32,
  layout : Int32,
  total : Int32,
  dst : FixedArray[Byte],
) -> Int32 = "mwg_vk_texture_read"

///|
#cfg(not(target="native"))
fn vk_texture_read(
  _device : Int64,
  _texture : Int64,
  _mip : Int32,
  _x : Int32,
  _y : Int32,
  _z : Int32,
  _width : Int32,
  _height : Int32,
  _depth : Int32,
  _layout : Int32,
  _total : Int32,
  _dst : FixedArray[Byte],
) -> Int32 {
  0
}

///|
#cfg(target="native")
#borrow(source)
extern "C" fn vk_texture_write(
  device : Int64,
  texture : Int64,
  mip : Int32,
  x : Int32,
  y : Int32,
  z : Int32,
  width : Int32,
  height : Int32,
  depth : Int32,
  layout : Int32,
  total : Int32,
  source : Bytes,
) -> Int32 = "mwg_vk_texture_write"

///|
#cfg(not(target="native"))
fn vk_texture_write(
  _device : Int64,
  _texture : Int64,
  _mip : Int32,
  _x : Int32,
  _y : Int32,
  _z : Int32,
  _width : Int32,
  _height : Int32,
  _depth : Int32,
  _layout : Int32,
  _total : Int32,
  _source : Bytes,
) -> Int32 {
  0
}

///|
#cfg(target="native")
extern "C" fn vk_barrier_memory(device : Int64) = "mwg_vk_barrier_memory"

///|
#cfg(not(target="native"))
fn vk_barrier_memory(_device : Int64) -> Unit {

}

///|
/// The message the seam last recorded, or `""`.
fn last_error() -> String {
  let buffer = FixedArray::make(512, b'\x00')
  let length = vk_error_copy(buffer, 512).to_int()
  if length <= 0 {
    return ""
  }
  let bytes = FixedArray::make(length, b'\x00')
  for i in 0..<length {
    bytes[i] = buffer[i]
  }
  @utf8.decode_lossy(Bytes::from_array(bytes)[:])
}
