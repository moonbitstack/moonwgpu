#version 450
// A quad that covers the target, carrying the texel coordinates through.
layout(location = 0) in vec2 position;
layout(location = 1) in vec2 texel;

layout(location = 0) out vec2 coordinate;

void main() {
  gl_Position = vec4(position, 0.0, 1.0);
  coordinate = texel;
}
