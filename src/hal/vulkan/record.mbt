// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Replaying a recorded command buffer on the device.
///
/// The layer above has already decided that every command is legal and that
/// every resource it names is alive; what is left is the Vulkan spelling of
/// each command, and the one piece of state Vulkan does not keep for us — the
/// layout of each subresource.

///|
pub impl @hal.Hal for Backend with fn submit(self, commands) -> Unit raise @hal.HalError {
  if !self.available() {
    raise @hal.HalError::unsupported(self.reason())
  }
  if vk_record_begin(self.device) == 0 {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  errdefer vk_record_abandon(self.device)
  for command in commands {
    self.apply(command)
  }
  if vk_record_submit(self.device) == 0 {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  self.submissions.push(commands.length())
}

///|
fn Backend::apply(
  self : Backend,
  command : @types.Command,
) -> Unit raise @hal.HalError {
  match command {
    @types.Command::CopyBufferToBuffer(copy) => {
      let source = self.buffer(copy.source)
      let destination = self.buffer(copy.destination)
      vk_barrier_memory(self.device)
      vk_copy_buffer(
        self.device,
        source.handle,
        copy.source_offset,
        destination.handle,
        copy.destination_offset,
        copy.size,
      )
    }
    @types.Command::CopyBufferToTexture(copy) => {
      let texture = self.texture(copy.destination.texture)
      self.transition(
        texture,
        copy.destination.mip_level,
        layout_transfer_destination,
      )
      let buffer = self.buffer(copy.source.buffer)
      vk_barrier_memory(self.device)
      vk_copy_buffer_to_texture(
        self.device,
        buffer.handle,
        copy.source.layout.offset,
        row_length(copy.source.layout, texture.descriptor.format),
        copy.source.layout.rows_per_image.unwrap_or(0),
        texture.handle,
        copy.destination.mip_level,
        copy.destination.origin.x,
        copy.destination.origin.y,
        copy.destination.origin.z,
        copy.copy_size.width,
        copy.copy_size.height,
        copy.copy_size.depth_or_array_layers,
      )
    }
    @types.Command::CopyTextureToBuffer(copy) => {
      let texture = self.texture(copy.source.texture)
      self.transition(texture, copy.source.mip_level, layout_transfer_source)
      let buffer = self.buffer(copy.destination.buffer)
      vk_barrier_memory(self.device)
      vk_copy_texture_to_buffer(
        self.device,
        texture.handle,
        copy.source.mip_level,
        copy.source.origin.x,
        copy.source.origin.y,
        copy.source.origin.z,
        copy.copy_size.width,
        copy.copy_size.height,
        copy.copy_size.depth_or_array_layers,
        buffer.handle,
        copy.destination.layout.offset,
        row_length(copy.destination.layout, texture.descriptor.format),
        copy.destination.layout.rows_per_image.unwrap_or(0),
      )
    }
    @types.Command::CopyTextureToTexture(copy) => {
      let source = self.texture(copy.source.texture)
      let destination = self.texture(copy.destination.texture)
      self.transition(source, copy.source.mip_level, layout_transfer_source)
      self.transition(
        destination,
        copy.destination.mip_level,
        layout_transfer_destination,
      )
      vk_barrier_memory(self.device)
      vk_copy_texture(
        self.device,
        source.handle,
        copy.source.mip_level,
        copy.source.origin.x,
        copy.source.origin.y,
        copy.source.origin.z,
        destination.handle,
        copy.destination.mip_level,
        copy.destination.origin.x,
        copy.destination.origin.y,
        copy.destination.origin.z,
        copy.copy_size.width,
        copy.copy_size.height,
        copy.copy_size.depth_or_array_layers,
      )
    }
    @types.Command::ClearBuffer(clear) => {
      let buffer = self.buffer(clear.buffer)
      vk_barrier_memory(self.device)
      vk_fill_buffer(self.device, buffer.handle, clear.offset, clear.size, 0)
    }
    @types.Command::ClearTexture(clear) => {
      let texture = self.texture(clear.texture)
      let format = texture.descriptor.format
      self.transition(texture, clear.mip_level, attachment_layout(format))
      vk_barrier_memory(self.device)
      let color = FixedArray::make(4, 0.0)
      let integers = FixedArray::make(4, 0)
      let is_float = match format.info().sample_type {
        @types.SampleType::Uint | @types.SampleType::Sint => false
        _ => true
      }
      if is_float {
        color[0] = 0.0
        color[1] = 0.0
        color[2] = 0.0
        color[3] = 0.0
      }
      vk_clear_texture(
        self.device,
        texture.handle,
        clear.mip_level,
        clear.origin.x,
        clear.origin.y,
        clear.origin.z,
        clear.size.width,
        clear.size.height,
        clear.size.depth_or_array_layers,
        if is_float {
          1
        } else {
          0
        },
        color,
        integers,
        1.0,
        0,
        0,
      )
    }
    @types.Command::ResolveQuerySet(resolve) => {
      let queries = match self.queries.get(resolve.query_set.raw()) {
        Some(record) => record
        None =>
          raise @hal.HalError::missing("query set \{resolve.query_set.raw()}")
      }
      let buffer = self.buffer(resolve.destination)
      vk_barrier_memory(self.device)
      vk_resolve_queries(
        self.device,
        queries.handle,
        resolve.first_query,
        resolve.query_count,
        buffer.handle,
        resolve.destination_offset,
      )
    }
    @types.Command::RenderPass(pass) => self.render_pass(pass)
    @types.Command::ComputePass(pass) => self.compute_pass(pass)
  }
}

///|
/// `GPUTexelCopyBufferLayout::bytesPerRow` is a byte count, while Vulkan wants
/// a row length in texels or blocks. A layout that gives no row length means
/// the rows are packed against the image extent, which Vulkan spells as zero.
fn row_length(
  layout : @types.TexelCopyBufferLayout,
  format : @types.TextureFormat,
) -> Int32 {
  match layout.bytes_per_row {
    Some(bytes) => {
      let info = format.info()
      bytes * info.block_width / info.bytes_per_block
    }
    None => 0
  }
}

///|
/// What a pass has to do before it begins: every texture its bind groups name
/// has to be in the layout that use requires.
///
/// The pass is recorded whole before it is submitted, so the textures are
/// known up front and the barriers go outside the pass, which is where Vulkan
/// wants them.
fn Backend::plan_bindings(
  self : Backend,
  groups : Array[@types.SetBindGroup],
) -> Unit raise @hal.HalError {
  for group in groups {
    let set = match self.sets.get(group.group.raw()) {
      Some(record) => record
      None => raise @hal.HalError::missing("bind group \{group.group.raw()}")
    }
    let layout = match self.set_layouts.get(set.layout) {
      Some(record) => record
      None => raise @hal.HalError::missing("bind group layout \{set.layout}")
    }
    for entry in set.descriptor.entries {
      if entry.resource is @types.BindingResource::TextureView(view) {
        let record = self.view(view)
        let texture = self.texture(@types.TextureId::from_raw(record.texture))
        let mut wanted = layout_shader_read
        for declared in layout.descriptor.entries {
          if declared.binding == entry.binding {
            wanted = wanted_layout(declared.kind)
          }
        }
        self.transition(texture, 0, wanted)
      }
    }
  }
}

///|
fn Backend::render_pass(
  self : Backend,
  pass : @types.RenderPassCommand,
) -> Unit raise @hal.HalError {
  let count = pass.color_attachments.length()
  let slots = if count > 0 { count } else { 1 }
  let views = FixedArray::make(slots, 0L)
  let formats = FixedArray::make(slots, 0L)
  let loads = FixedArray::make(slots, 0)
  let stores = FixedArray::make(slots, 0)
  let clears = FixedArray::make(slots * 4, 0.0)
  let mut width = 0
  let mut height = 0
  for i, attachment in pass.color_attachments {
    let view = self.view(attachment.view)
    let texture = self.texture(@types.TextureId::from_raw(view.texture))
    self.transition(texture, 0, layout_color_attachment)
    if i == 0 {
      width = texture.descriptor.size.width
      height = texture.descriptor.size.height
    }
    views[i] = view.handle
    formats[i] = view.format
    loads[i] = match attachment.load_op {
      @types.LoadOp::Clear => 1
      @types.LoadOp::Load => 0
    }
    stores[i] = match attachment.store {
      @types.StoreOp::Store => 0
      @types.StoreOp::Discard => 1
    }
    clears[i * 4] = attachment.clear_value.r
    clears[i * 4 + 1] = attachment.clear_value.g
    clears[i * 4 + 2] = attachment.clear_value.b
    clears[i * 4 + 3] = attachment.clear_value.a
  }
  let mut depth_view = 0L
  let mut depth_format = 0L
  let mut depth_load = 0
  let mut depth_store = 0
  let mut depth_clear = 1.0
  let mut stencil_clear = 0
  let mut depth_read_only = 0
  match pass.depth_stencil_attachment {
    Some(attachment) => {
      let view = self.view(attachment.view)
      let texture = self.texture(@types.TextureId::from_raw(view.texture))
      self.transition(texture, 0, layout_depth_attachment)
      if count == 0 {
        width = texture.descriptor.size.width
        height = texture.descriptor.size.height
      }
      depth_view = view.handle
      depth_format = view.format
      depth_load = match attachment.depth_load_op {
        @types.LoadOp::Clear => 1
        @types.LoadOp::Load => 0
      }
      depth_store = match attachment.depth_store {
        @types.StoreOp::Store => 0
        @types.StoreOp::Discard => 1
      }
      depth_clear = attachment.depth_clear_value
      stencil_clear = attachment.stencil_clear_value
      depth_read_only = if attachment.depth_read_only { 1 } else { 0 }
    }
    None => ()
  }
  self.plan_bindings(render_groups(pass.commands))
  let occlusion = match pass.occlusion_query_set {
    Some(id) => self.query(id).handle
    None => 0L
  }
  if vk_begin_render(
      self.device,
      width,
      height,
      count,
      views,
      formats,
      loads,
      stores,
      clears,
      depth_view,
      depth_format,
      depth_load,
      depth_store,
      depth_clear,
      stencil_clear,
      depth_read_only,
    ) ==
    0 {
    raise @hal.HalError::failed("vulkan: \{last_error()}")
  }
  // The whole attachment, and the y axis flipped: the specification's clip
  // space points up, Vulkan's points down.
  vk_viewport(
    self.device,
    0.0,
    height.to_double(),
    width.to_double(),
    -height.to_double(),
    0.0,
    1.0,
  )
  vk_scissor(self.device, 0, 0, width, height)
  for command in pass.commands {
    self.render_command(command, occlusion)
  }
  vk_end_render(self.device)
  vk_barrier_memory(self.device)
}

///|
fn Backend::compute_pass(
  self : Backend,
  pass : @types.ComputePassCommand,
) -> Unit raise @hal.HalError {
  self.plan_bindings(compute_groups(pass.commands))
  vk_begin_compute(self.device)
  for command in pass.commands {
    self.compute_command(command)
  }
  vk_end_compute(self.device)
  vk_barrier_memory(self.device)
}

///|
fn Backend::render_command(
  self : Backend,
  command : @types.RenderCommand,
  occlusion : Int64,
) -> Unit raise @hal.HalError {
  match command {
    @types.RenderCommand::SetPipeline(id) => {
      let record = self.pipeline(id.raw())
      vk_bind_pipeline(self.device, record.handle)
    }
    @types.RenderCommand::SetBindGroup(group) => self.bind_group(group, false)
    @types.RenderCommand::SetImmediates(immediates) =>
      vk_push_constants(
        self.device,
        immediates.range_offset,
        immediates.data,
        immediates.data.length(),
        0,
      )
    @types.RenderCommand::SetVertexBuffer(buffer) => {
      let record = self.buffer(buffer.buffer)
      vk_vertex_buffer(self.device, buffer.slot, record.handle, buffer.offset)
    }
    @types.RenderCommand::SetIndexBuffer(buffer) => {
      let record = self.buffer(buffer.buffer)
      vk_index_buffer(
        self.device,
        record.handle,
        buffer.offset,
        index_format_code(buffer.format),
      )
    }
    @types.RenderCommand::Draw(arguments) =>
      vk_draw(
        self.device,
        arguments.vertex_count,
        arguments.instance_count,
        arguments.first_vertex,
        arguments.first_instance,
      )
    @types.RenderCommand::DrawIndexed(arguments) =>
      vk_draw_indexed(
        self.device,
        arguments.index_count,
        arguments.instance_count,
        arguments.first_index,
        arguments.base_vertex,
        arguments.first_instance,
      )
    @types.RenderCommand::DrawIndirect(indirect) => {
      let record = self.buffer(indirect.buffer)
      vk_draw_indirect(self.device, record.handle, indirect.offset, 0)
    }
    @types.RenderCommand::DrawIndexedIndirect(indirect) => {
      let record = self.buffer(indirect.buffer)
      vk_draw_indirect(self.device, record.handle, indirect.offset, 1)
    }
    @types.RenderCommand::SetViewport(viewport) =>
      // A viewport given from the top edge, flipped the same way the default
      // one is.
      vk_viewport(
        self.device,
        viewport.x,
        viewport.y + viewport.height,
        viewport.width,
        -viewport.height,
        viewport.min_depth,
        viewport.max_depth,
      )
    @types.RenderCommand::SetScissorRect(rect) =>
      vk_scissor(self.device, rect.x, rect.y, rect.width, rect.height)
    @types.RenderCommand::SetBlendConstant(color) =>
      vk_blend_constants(self.device, color.r, color.g, color.b, color.a)
    @types.RenderCommand::SetStencilReference(reference) =>
      vk_stencil_reference(self.device, reference)
    @types.RenderCommand::BeginOcclusionQuery(index) =>
      if occlusion != 0L {
        vk_begin_query(self.device, occlusion, index)
      }
    @types.RenderCommand::EndOcclusionQuery =>
      if occlusion != 0L {
        vk_end_query(self.device, occlusion, 0)
      }
    @types.RenderCommand::WriteTimestamp(write) => {
      let queries = self.query(write.query_set)
      vk_write_timestamp(self.device, queries.handle, write.query_index)
    }
    @types.RenderCommand::ExecuteBundles(bundles) =>
      for bundle in bundles {
        for inner in bundle.commands {
          self.render_command(inner, occlusion)
        }
      }
    @types.RenderCommand::InsertDebugMarker(label) => ignore(label)
    @types.RenderCommand::PushDebugGroup(label) => ignore(label)
    @types.RenderCommand::PopDebugGroup => ()
  }
}

///|
fn Backend::compute_command(
  self : Backend,
  command : @types.ComputeCommand,
) -> Unit raise @hal.HalError {
  match command {
    @types.ComputeCommand::SetPipeline(id) => {
      let record = self.pipeline(id.raw())
      vk_bind_pipeline(self.device, record.handle)
    }
    @types.ComputeCommand::SetBindGroup(group) => self.bind_group(group, true)
    @types.ComputeCommand::SetImmediates(immediates) =>
      vk_push_constants(
        self.device,
        immediates.range_offset,
        immediates.data,
        immediates.data.length(),
        1,
      )
    @types.ComputeCommand::DispatchWorkgroups(arguments) =>
      vk_dispatch(self.device, arguments.x, arguments.y, arguments.z)
    @types.ComputeCommand::DispatchWorkgroupsIndirect(indirect) => {
      let record = self.buffer(indirect.buffer)
      vk_dispatch_indirect(self.device, record.handle, indirect.offset)
    }
    @types.ComputeCommand::WriteTimestamp(write) => {
      let queries = self.query(write.query_set)
      vk_write_timestamp(self.device, queries.handle, write.query_index)
    }
    @types.ComputeCommand::InsertDebugMarker(label) => ignore(label)
    @types.ComputeCommand::PushDebugGroup(label) => ignore(label)
    @types.ComputeCommand::PopDebugGroup => ()
  }
}

///|
/// A bind group goes to the set index the specification names.
///
/// The index is the binding point a pipeline layout was built for, and it is
/// the whole of the mapping between a `@group(n)` in a shader and a Vulkan
/// descriptor set: change it and a shader reads the wrong group's bindings.
fn Backend::bind_group(
  self : Backend,
  group : @types.SetBindGroup,
  compute : Bool,
) -> Unit raise @hal.HalError {
  let set = match self.sets.get(group.group.raw()) {
    Some(record) => record
    None => raise @hal.HalError::missing("bind group \{group.group.raw()}")
  }
  let offsets = FixedArray::make(
    if group.dynamic_offsets.length() > 0 {
      group.dynamic_offsets.length()
    } else {
      1
    },
    0,
  )
  for i, offset in group.dynamic_offsets {
    offsets[i] = offset
  }
  vk_bind_set(
    self.device,
    group.index,
    set.handle,
    offsets,
    group.dynamic_offsets.length(),
    if compute {
      1
    } else {
      0
    },
  )
}

///|
fn Backend::pipeline(
  self : Backend,
  id : UInt64,
) -> PipelineRecord raise @hal.HalError {
  match self.pipelines.get(id) {
    Some(record) => record
    None => raise @hal.HalError::missing("pipeline \{id}")
  }
}

///|
fn Backend::query(
  self : Backend,
  id : @types.QuerySetId,
) -> QueryRecord raise @hal.HalError {
  match self.queries.get(id.raw()) {
    Some(record) => record
    None => raise @hal.HalError::missing("query set \{id.raw()}")
  }
}

///|
/// Every bind group a render pass names, in the order it names them.
fn render_groups(
  commands : Array[@types.RenderCommand],
) -> Array[@types.SetBindGroup] {
  let groups : Array[@types.SetBindGroup] = []
  for command in commands {
    match command {
      @types.RenderCommand::SetBindGroup(group) => groups.push(group)
      @types.RenderCommand::ExecuteBundles(bundles) =>
        for bundle in bundles {
          for inner in bundle.commands {
            if inner is @types.RenderCommand::SetBindGroup(group) {
              groups.push(group)
            }
          }
        }
      _ => ()
    }
  }
  groups
}

///|
fn compute_groups(
  commands : Array[@types.ComputeCommand],
) -> Array[@types.SetBindGroup] {
  let groups : Array[@types.SetBindGroup] = []
  for command in commands {
    if command is @types.ComputeCommand::SetBindGroup(group) {
      groups.push(group)
    }
  }
  groups
}
