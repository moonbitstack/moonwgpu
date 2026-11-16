// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// What happens when a command buffer reaches the queue: everything it names is
// looked up, every rule of the specification that applies to the command is
// checked, and only then does the backend see the batch.

///|
/// The rules one attachment of a render pass must satisfy.
fn Hub::validate_colour_attachment(
  self : Hub,
  attachment : @types.ColorAttachment,
  sample_count : Int32,
  at : String,
) -> Int32 raise Refused {
  let view = match self.views.get(attachment.view.raw()) {
    Some(view) => view
    None =>
      raise invalid(
        @types.InvalidResource,
        "\{at}.view",
        "a texture view of this device",
        attachment.view.raw().to_string(),
      )
  }
  let texture = self.texture(view.texture)
  let info = view.format.info()
  require(
    info.render_attachment,
    @types.InvalidPassDescriptor,
    "\{at}.view",
    "a renderable format",
    view.format.name(),
  )
  require(
    texture.descriptor.usage.contains(@types.TextureUsages::render_attachment()),
    @types.InvalidTextureUsage,
    "\{at}.view",
    "a texture with RENDER_ATTACHMENT",
    describe_usages(texture.descriptor.usage.bits(), texture_usage_names()),
  )
  require_same(
    sample_count,
    texture.descriptor.sample_count,
    @types.InvalidPassDescriptor,
    "\{at}.view",
  )
  match attachment.resolve_target {
    Some(target) => {
      let resolve = match self.views.get(target.raw()) {
        Some(view) => view
        None =>
          raise invalid(
            @types.InvalidResource,
            "\{at}.resolveTarget",
            "a texture view of this device",
            target.raw().to_string(),
          )
      }
      let resolved = self.texture(resolve.texture)
      require_same(
        1,
        resolved.descriptor.sample_count,
        @types.InvalidPassDescriptor,
        "\{at}.resolveTarget",
      )
      require(
        resolve.format == view.format,
        @types.InvalidPassDescriptor,
        "\{at}.resolveTarget",
        view.format.name(),
        resolve.format.name(),
      )
      require(
        resolved.descriptor.usage.contains(
          @types.TextureUsages::render_attachment(),
        ),
        @types.InvalidTextureUsage,
        "\{at}.resolveTarget",
        "a texture with RENDER_ATTACHMENT",
        describe_usages(resolved.descriptor.usage.bits(), texture_usage_names()),
      )
    }
    None => ()
  }
  info.bytes_per_sample
}

///|
/// The rules a depth-stencil attachment must satisfy.
fn Hub::validate_depth_stencil_attachment(
  self : Hub,
  attachment : @types.DepthStencilAttachment,
  sample_count : Int32,
) -> Unit raise Refused {
  let view = match self.views.get(attachment.view.raw()) {
    Some(view) => view
    None =>
      raise invalid(
        @types.InvalidResource,
        "depthStencilAttachment.view",
        "a texture view of this device",
        attachment.view.raw().to_string(),
      )
  }
  let texture = self.texture(view.texture)
  let info = view.format.info()
  let has_depth = info.aspect == @types.FormatAspect::DepthOnly ||
    info.aspect == @types.FormatAspect::DepthStencil
  let has_stencil = info.aspect == @types.FormatAspect::StencilOnly ||
    info.aspect == @types.FormatAspect::DepthStencil
  require(
    has_depth || has_stencil,
    @types.InvalidPassDescriptor,
    "depthStencilAttachment.view",
    "a depth or stencil format",
    view.format.name(),
  )
  require_same(
    sample_count,
    texture.descriptor.sample_count,
    @types.InvalidPassDescriptor,
    "depthStencilAttachment.view",
  )
  if attachment.depth_read_only {
    require(
      attachment.depth_load_op == @types.LoadOp::Load,
      @types.InvalidPassDescriptor,
      "depthStencilAttachment.depthLoadOp",
      "load on a read-only attachment",
      "clear",
    )
    require(
      attachment.depth_store == @types.StoreOp::Store,
      @types.InvalidPassDescriptor,
      "depthStencilAttachment.depthStoreOp",
      "store on a read-only attachment",
      "discard",
    )
  } else {
    require(
      has_depth,
      @types.InvalidPassDescriptor,
      "depthStencilAttachment.depthReadOnly",
      "a writable depth aspect",
      view.format.name(),
    )
  }
  if attachment.stencil_read_only {
    require(
      attachment.stencil_load_op == @types.LoadOp::Load,
      @types.InvalidPassDescriptor,
      "depthStencilAttachment.stencilLoadOp",
      "load on a read-only attachment",
      "clear",
    )
    require(
      attachment.stencil_store == @types.StoreOp::Store,
      @types.InvalidPassDescriptor,
      "depthStencilAttachment.stencilStoreOp",
      "store on a read-only attachment",
      "discard",
    )
  }
}

///|
/// Mark the resources one bind group touches in the pass's usage scope.
fn Hub::touch_bind_group(
  self : Hub,
  scope : UsageScope,
  id : @types.BindGroupId,
) -> Unit raise Refused {
  let group = match self.bind_groups.get(id.raw()) {
    Some(group) => group
    None =>
      raise invalid(
        @types.InvalidResource,
        "setBindGroup",
        "a bind group of this device",
        id.raw().to_string(),
      )
  }
  let layouts = match self.bind_group_layouts.get(group.layout.raw()) {
    Some(layout) => layout
    None =>
      raise invalid(
        @types.InvalidResource,
        "setBindGroup",
        "a bind group layout of this device",
        group.layout.raw().to_string(),
      )
  }
  let kinds = Map([])
  for entry in layouts.descriptor.entries {
    kinds[entry.binding] = entry.kind
  }
  for entry in group.descriptor.entries {
    let kind = match kinds.get(entry.binding) {
      Some(kind) => kind
      None => continue
    }
    match (kind, entry.resource) {
      (Buffer(layout), Buffer(binding)) => {
        let usage = match layout.kind {
          Uniform => @types.BufferUsages::uniform()
          Storage => @types.BufferUsages::storage()
          ReadOnlyStorage => @types.BufferUsages::storage()
        }
        scope.use_buffer(binding.buffer, usage)
      }
      (Texture(_), TextureView(view_id)) =>
        match self.views.get(view_id.raw()) {
          Some(view) =>
            scope.use_texture(
              view.texture,
              @types.TextureUsages::texture_binding(),
            )
          None => ()
        }
      (StorageTexture(_), TextureView(view_id)) =>
        match self.views.get(view_id.raw()) {
          Some(view) =>
            scope.use_texture(
              view.texture,
              @types.TextureUsages::storage_binding(),
            )
          None => ()
        }
      _ => ()
    }
  }
}

///|
/// The rules one recorded render pass must satisfy.
fn Hub::validate_render_pass(
  self : Hub,
  pass : @types.RenderPassCommand,
) -> Unit raise Refused {
  let colour_count = pass.color_attachments.length()
  require_int(
    colour_count <= self.limits.max_color_attachments,
    @types.LimitExceeded,
    "colorAttachments",
    self.limits.max_color_attachments,
    colour_count,
  )
  if colour_count == 0 && pass.depth_stencil_attachment is None {
    raise invalid(
      @types.InvalidPassDescriptor,
      "colorAttachments",
      "a colour or depth-stencil attachment",
      "none",
    )
  }
  let sample_count = if colour_count > 0 {
    match self.views.get(pass.color_attachments[0].view.raw()) {
      Some(view) =>
        match self.textures.get(view.texture.raw()) {
          Some(texture) => texture.descriptor.sample_count
          None => 1
        }
      None => 1
    }
  } else {
    match pass.depth_stencil_attachment {
      Some(attachment) =>
        match self.views.get(attachment.view.raw()) {
          Some(view) =>
            match self.textures.get(view.texture.raw()) {
              Some(texture) => texture.descriptor.sample_count
              None => 1
            }
          None => 1
        }
      None => 1
    }
  }
  let scope = UsageScope::new()
  let mut bytes_per_sample = 0
  for i, attachment in pass.color_attachments {
    bytes_per_sample = bytes_per_sample +
      self.validate_colour_attachment(
        attachment,
        sample_count,
        "colorAttachments[\{i}]",
      )
    let view = self.views.get(attachment.view.raw()).unwrap()
    scope.use_texture(view.texture, @types.TextureUsages::render_attachment())
    match attachment.resolve_target {
      Some(target) =>
        match self.views.get(target.raw()) {
          Some(resolve) =>
            scope.use_texture(
              resolve.texture,
              @types.TextureUsages::render_attachment(),
            )
          None => ()
        }
      None => ()
    }
  }
  require_int(
    bytes_per_sample <= self.limits.max_color_attachment_bytes_per_sample,
    @types.LimitExceeded,
    "colorAttachments",
    self.limits.max_color_attachment_bytes_per_sample,
    bytes_per_sample,
  )
  match pass.depth_stencil_attachment {
    Some(attachment) => {
      self.validate_depth_stencil_attachment(attachment, sample_count)
      let view = self.views.get(attachment.view.raw()).unwrap()
      scope.use_texture(view.texture, @types.TextureUsages::render_attachment())
    }
    None => ()
  }
  let mut pipeline_set = false
  for command in pass.commands {
    match command {
      SetPipeline(id) => {
        require(
          self.render_pipelines.get(id.raw()) is Some(_),
          @types.InvalidResource,
          "setPipeline",
          "a render pipeline of this device",
          id.raw().to_string(),
        )
        pipeline_set = true
      }
      SetBindGroup(binding) => {
        require_int(
          binding.index >= 0 && binding.index < self.limits.max_bind_groups,
          @types.LimitExceeded,
          "setBindGroup.index",
          self.limits.max_bind_groups - 1,
          binding.index,
        )
        self.touch_bind_group(scope, binding.group)
      }
      SetVertexBuffer(buffer) => {
        let state = self.buffer(buffer.buffer)
        require(
          state.descriptor.usage.contains(@types.BufferUsages::vertex()),
          @types.InvalidBufferUsage,
          "setVertexBuffer.buffer",
          "VERTEX",
          describe_usages(state.descriptor.usage.bits(), buffer_usage_names()),
        )
        require_same(
          0,
          buffer.offset % 4,
          @types.InvalidAlignment,
          "setVertexBuffer.offset",
        )
        match buffer.size {
          Some(size) =>
            require_int(
              buffer.offset + size <= state.descriptor.size,
              @types.InvalidCopyRange,
              "setVertexBuffer.offset + size",
              state.descriptor.size,
              buffer.offset + size,
            )
          None => ()
        }
        scope.use_buffer(buffer.buffer, @types.BufferUsages::vertex())
      }
      SetIndexBuffer(buffer) => {
        let state = self.buffer(buffer.buffer)
        require(
          state.descriptor.usage.contains(@types.BufferUsages::index()),
          @types.InvalidBufferUsage,
          "setIndexBuffer.buffer",
          "INDEX",
          describe_usages(state.descriptor.usage.bits(), buffer_usage_names()),
        )
        require_same(
          0,
          buffer.offset % 4,
          @types.InvalidAlignment,
          "setIndexBuffer.offset",
        )
        scope.use_buffer(buffer.buffer, @types.BufferUsages::index())
      }
      Draw(arguments) => {
        require(
          pipeline_set,
          @types.InvalidPassState,
          "draw",
          "a pipeline set before drawing",
          "no pipeline",
        )
        require_int(
          arguments.vertex_count >= 0,
          @types.InvalidDraw,
          "draw.vertexCount",
          0,
          arguments.vertex_count,
        )
        require_int(
          arguments.instance_count > 0,
          @types.InvalidDraw,
          "draw.instanceCount",
          1,
          arguments.instance_count,
        )
      }
      DrawIndexed(arguments) => {
        require(
          pipeline_set,
          @types.InvalidPassState,
          "drawIndexed",
          "a pipeline set before drawing",
          "no pipeline",
        )
        require_int(
          arguments.index_count >= 0,
          @types.InvalidDraw,
          "drawIndexed.indexCount",
          0,
          arguments.index_count,
        )
        require_int(
          arguments.instance_count > 0,
          @types.InvalidDraw,
          "drawIndexed.instanceCount",
          1,
          arguments.instance_count,
        )
      }
      SetViewport(viewport) => {
        require_int(
          viewport.width >= 0,
          @types.InvalidPassState,
          "setViewport.width",
          0,
          viewport.width.to_int(),
        )
        require_int(
          viewport.height >= 0,
          @types.InvalidPassState,
          "setViewport.height",
          0,
          viewport.height.to_int(),
        )
      }
      SetScissorRect(rect) =>
        require_int(
          rect.width >= 0 && rect.height >= 0,
          @types.InvalidPassState,
          "setScissorRect",
          0,
          rect.width,
        )
      DrawIndirect(indirect) => {
        require(
          pipeline_set,
          @types.InvalidPassState,
          "drawIndirect",
          "a pipeline set before drawing",
          "no pipeline",
        )
        self.validate_indirect(
          indirect.buffer,
          indirect.offset,
          16,
          "drawIndirect",
        )
        scope.use_buffer(indirect.buffer, @types.BufferUsages::indirect())
      }
      DrawIndexedIndirect(indirect) => {
        require(
          pipeline_set,
          @types.InvalidPassState,
          "drawIndexedIndirect",
          "a pipeline set before drawing",
          "no pipeline",
        )
        self.validate_indirect(
          indirect.buffer,
          indirect.offset,
          20,
          "drawIndexedIndirect",
        )
        scope.use_buffer(indirect.buffer, @types.BufferUsages::indirect())
      }
      ExecuteBundles(bundles) =>
        for bundle in bundles {
          for recorded in bundle.commands {
            ignore(recorded)
          }
        }
      InsertDebugMarker(_) | PushDebugGroup(_) | PopDebugGroup => ()
      SetBlendConstant(_) | SetStencilReference(_) => ()
      BeginOcclusionQuery(_) | EndOcclusionQuery => ()
      WriteTimestamp(write) =>
        require(
          self.query_sets.get(write.query_set.raw()) is Some(_),
          @types.InvalidResource,
          "writeTimestamp",
          "a query set of this device",
          write.query_set.raw().to_string(),
        )
    }
  }
}

///|
/// An indirect argument buffer: it exists, it carries INDIRECT, and the
/// arguments fit inside it, aligned to four bytes.
fn Hub::validate_indirect(
  self : Hub,
  buffer : @types.BufferId,
  offset : Int32,
  size : Int32,
  at : String,
) -> Unit raise Refused {
  let state = self.buffer(buffer)
  require(
    state.descriptor.usage.contains(@types.BufferUsages::indirect()),
    @types.InvalidBufferUsage,
    at,
    "INDIRECT",
    describe_usages(state.descriptor.usage.bits(), buffer_usage_names()),
  )
  require_same(0, offset % 4, @types.InvalidAlignment, at)
  require_int(
    offset + size <= state.descriptor.size,
    @types.InvalidCopyRange,
    at,
    state.descriptor.size,
    offset + size,
  )
}

///|
/// The rules one recorded compute pass must satisfy.
fn Hub::validate_compute_pass(
  self : Hub,
  pass : @types.ComputePassCommand,
) -> Unit raise Refused {
  let scope = UsageScope::new()
  let mut pipeline_set = false
  for command in pass.commands {
    match command {
      SetPipeline(id) => {
        require(
          self.compute_pipelines.get(id.raw()) is Some(_),
          @types.InvalidResource,
          "setPipeline",
          "a compute pipeline of this device",
          id.raw().to_string(),
        )
        pipeline_set = true
      }
      SetBindGroup(binding) => {
        require_int(
          binding.index >= 0 && binding.index < self.limits.max_bind_groups,
          @types.LimitExceeded,
          "setBindGroup.index",
          self.limits.max_bind_groups - 1,
          binding.index,
        )
        self.touch_bind_group(scope, binding.group)
      }
      DispatchWorkgroups(arguments) => {
        require(
          pipeline_set,
          @types.InvalidPassState,
          "dispatchWorkgroups",
          "a pipeline set before dispatching",
          "no pipeline",
        )
        for count in [arguments.x, arguments.y, arguments.z] {
          require_int(
            count >= 0 &&
            count <= self.limits.max_compute_workgroups_per_dimension,
            @types.InvalidDispatch,
            "dispatchWorkgroups",
            self.limits.max_compute_workgroups_per_dimension,
            count,
          )
        }
      }
      DispatchWorkgroupsIndirect(indirect) => {
        require(
          pipeline_set,
          @types.InvalidPassState,
          "dispatchWorkgroupsIndirect",
          "a pipeline set before dispatching",
          "no pipeline",
        )
        self.validate_indirect(
          indirect.buffer,
          indirect.offset,
          12,
          "dispatchWorkgroupsIndirect",
        )
        scope.use_buffer(indirect.buffer, @types.BufferUsages::indirect())
      }
      WriteTimestamp(write) =>
        require(
          self.query_sets.get(write.query_set.raw()) is Some(_),
          @types.InvalidResource,
          "writeTimestamp",
          "a query set of this device",
          write.query_set.raw().to_string(),
        )
      InsertDebugMarker(_) | PushDebugGroup(_) | PopDebugGroup => ()
    }
  }
}

///|
/// Check every command of a finished command buffer, then hand the batch to the
/// backend. Nothing has touched the host until the whole batch is legal.
pub fn Hub::submit(
  self : Hub,
  commands : Array[@types.Command],
) -> Unit raise Refused {
  self.ensure_alive()
  for command in commands {
    match command {
      CopyBufferToBuffer(copy) =>
        validate_copy_buffer_to_buffer(
          self.buffer(copy.source),
          copy.source_offset,
          self.buffer(copy.destination),
          copy.destination_offset,
          copy.size,
        )
      ClearBuffer(clear) => {
        let state = self.buffer(clear.buffer)
        require(
          state.descriptor.usage.contains(@types.BufferUsages::copy_dst()),
          @types.InvalidBufferUsage,
          "clearBuffer.buffer",
          "COPY_DST",
          describe_usages(state.descriptor.usage.bits(), buffer_usage_names()),
        )
        require_same(
          0,
          clear.offset % 4,
          @types.InvalidAlignment,
          "clearBuffer.offset",
        )
        require_same(
          0,
          clear.size % 4,
          @types.InvalidAlignment,
          "clearBuffer.size",
        )
        require_int(
          clear.offset + clear.size <= state.descriptor.size,
          @types.InvalidCopyRange,
          "clearBuffer.offset + size",
          state.descriptor.size,
          clear.offset + clear.size,
        )
      }
      ClearTexture(clear) => {
        let state = self.texture(clear.texture)
        require(
          state.descriptor.usage.contains(@types.TextureUsages::copy_dst()),
          @types.InvalidTextureUsage,
          "clearTexture.texture",
          "COPY_DST",
          describe_usages(state.descriptor.usage.bits(), texture_usage_names()),
        )
        validate_copy_region(
          state,
          {
            texture: clear.texture,
            mip_level: clear.mip_level,
            origin: clear.origin,
            aspect: clear.aspect,
          },
          clear.size,
          "clearTexture",
        )
      }
      CopyBufferToTexture(copy) =>
        validate_buffer_to_texture_copy(
          self.buffer(copy.source.buffer),
          copy.source.layout,
          self.texture(copy.destination.texture),
          copy.destination,
          copy.copy_size,
          COPY_BYTES_PER_ROW_ALIGNMENT,
          "copyBufferToTexture",
        )
      CopyTextureToBuffer(copy) =>
        validate_texture_to_buffer_copy(
          self.texture(copy.source.texture),
          copy.source,
          self.buffer(copy.destination.buffer),
          copy.destination.layout,
          copy.copy_size,
        )
      CopyTextureToTexture(copy) =>
        validate_texture_to_texture_copy(
          self.texture(copy.source.texture),
          copy.source,
          self.texture(copy.destination.texture),
          copy.destination,
          copy.copy_size,
        )
      ResolveQuerySet(resolve) => {
        let set = match self.query_sets.get(resolve.query_set.raw()) {
          Some(set) => set
          None =>
            raise invalid(
              @types.InvalidResource,
              "resolveQuerySet.querySet",
              "a query set of this device",
              resolve.query_set.raw().to_string(),
            )
        }
        require_int(
          resolve.first_query >= 0 &&
          resolve.first_query + resolve.query_count <= set.count,
          @types.InvalidCopyRange,
          "resolveQuerySet.firstQuery + queryCount",
          set.count,
          resolve.first_query + resolve.query_count,
        )
        let state = self.buffer(resolve.destination)
        require(
          state.descriptor.usage.contains(@types.BufferUsages::query_resolve()),
          @types.InvalidBufferUsage,
          "resolveQuerySet.destination",
          "QUERY_RESOLVE",
          describe_usages(state.descriptor.usage.bits(), buffer_usage_names()),
        )
        require_same(
          0,
          resolve.destination_offset % 8,
          @types.InvalidAlignment,
          "resolveQuerySet.destinationOffset",
        )
        require_int(
          resolve.destination_offset + resolve.query_count * 8 <=
          state.descriptor.size,
          @types.InvalidCopyRange,
          "resolveQuerySet.destinationOffset + queryCount * 8",
          state.descriptor.size,
          resolve.destination_offset + resolve.query_count * 8,
        )
      }
      RenderPass(pass) => self.validate_render_pass(pass)
      ComputePass(pass) => self.validate_compute_pass(pass)
    }
  }
  self.backend.submit(commands) catch {
    error => raise self.report(Refused::from_hal(error))
  }
}
