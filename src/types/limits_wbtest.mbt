// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
test "the webgpu limits are the ones the specification prints" {
  let limits = Limits::webgpu()
  assert_eq(limits.max_texture_dimension_1d, 8192)
  assert_eq(limits.max_texture_dimension_2d, 8192)
  assert_eq(limits.max_texture_dimension_3d, 2048)
  assert_eq(limits.max_texture_array_layers, 256)
  assert_eq(limits.max_bind_groups, 4)
  assert_eq(limits.max_bind_groups_plus_vertex_buffers, 24)
  assert_eq(limits.max_immediate_size, 64)
  assert_eq(limits.max_bindings_per_bind_group, 1000)
  assert_eq(limits.max_dynamic_uniform_buffers_per_pipeline_layout, 8)
  assert_eq(limits.max_dynamic_storage_buffers_per_pipeline_layout, 4)
  assert_eq(limits.max_sampled_textures_per_shader_stage, 16)
  assert_eq(limits.max_samplers_per_shader_stage, 16)
  assert_eq(limits.max_storage_buffers_per_shader_stage, 8)
  assert_eq(limits.max_storage_textures_per_shader_stage, 4)
  assert_eq(limits.max_uniform_buffers_per_shader_stage, 12)
  assert_eq(limits.max_uniform_buffer_binding_size, 65536)
  assert_eq(limits.max_storage_buffer_binding_size, 134217728)
  assert_eq(limits.min_uniform_buffer_offset_alignment, 256)
  assert_eq(limits.min_storage_buffer_offset_alignment, 256)
  assert_eq(limits.max_vertex_buffers, 8)
  assert_eq(limits.max_buffer_size, 268435456)
  assert_eq(limits.max_vertex_attributes, 16)
  assert_eq(limits.max_vertex_buffer_array_stride, 2048)
  assert_eq(limits.max_inter_stage_shader_variables, 16)
  assert_eq(limits.max_color_attachments, 8)
  assert_eq(limits.max_color_attachment_bytes_per_sample, 32)
  assert_eq(limits.max_compute_workgroup_storage_size, 16384)
  assert_eq(limits.max_compute_invocations_per_workgroup, 256)
  assert_eq(limits.max_compute_workgroup_size_x, 256)
  assert_eq(limits.max_compute_workgroup_size_y, 256)
  assert_eq(limits.max_compute_workgroup_size_z, 64)
  assert_eq(limits.max_compute_workgroups_per_dimension, 65535)
}

///|
test "compatibility mode lowers exactly the limits the table lowers" {
  let limits = Limits::compatibility()
  let full = Limits::webgpu()
  assert_eq(limits.max_texture_dimension_1d, 4096)
  assert_eq(limits.max_texture_dimension_2d, 4096)
  assert_eq(limits.max_storage_buffers_in_vertex_stage, 0)
  assert_eq(limits.max_storage_buffers_in_fragment_stage, 4)
  assert_eq(limits.max_storage_textures_in_vertex_stage, 0)
  assert_eq(limits.max_uniform_buffer_binding_size, 16384)
  assert_eq(limits.max_inter_stage_shader_variables, 15)
  assert_eq(limits.max_color_attachments, 4)
  assert_eq(limits.max_compute_invocations_per_workgroup, 128)
  assert_eq(limits.max_compute_workgroup_size_x, 128)
  assert_eq(limits.max_compute_workgroup_size_y, 128)
  // Everything else stays where the default table puts it.
  assert_eq(limits.max_texture_dimension_3d, full.max_texture_dimension_3d)
  assert_eq(limits.max_buffer_size, full.max_buffer_size)
  assert_eq(
    limits.max_compute_workgroup_size_z,
    full.max_compute_workgroup_size_z,
  )
}

///|
test "a request at or below the supported limits fits" {
  let supported = Limits::webgpu()
  let wanted = { ..supported, max_bind_groups: 2, }
  assert_true(supported.exceeds(wanted) is None)
  assert_true(supported.exceeds(supported) is None)
}

///|
test "a request above one limit is named with both numbers" {
  let supported = Limits::webgpu()
  let wanted = { ..supported, max_vertex_buffers: 16, }
  match supported.exceeds(wanted) {
    Some((name, have, want)) => {
      assert_eq(name, "maxVertexBuffers")
      assert_eq(have, 8)
      assert_eq(want, 16)
    }
    None => fail("16 vertex buffers exceed the default of 8")
  }
}

///|
test "the entries cover every limit once" {
  let entries = Limits::webgpu().entries()
  assert_eq(entries.length(), 36)
  let seen = Map([])
  for entry in entries {
    let (name, _) = entry
    assert_true(seen.get(name) is None)
    seen[name] = true
  }
}
