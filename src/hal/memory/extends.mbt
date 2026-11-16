// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The backend's trait methods are also reachable as methods of `Backend`;
/// declaring them keeps the toolchain from reporting the promotion.
#doc(hidden)
pub extend Backend with @hal.Hal::{
  name,
  limits,
  features,
  create_buffer,
  destroy_buffer,
  write_buffer,
  read_buffer,
  create_texture,
  destroy_texture,
  create_texture_view,
  create_sampler,
  create_shader_module,
  create_bind_group_layout,
  create_bind_group,
  create_pipeline_layout,
  create_render_pipeline,
  create_compute_pipeline,
  create_query_set,
  submit,
  read_texture,
  write_texture,
}
