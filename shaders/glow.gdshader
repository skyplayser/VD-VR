// LED strips, bulbs, downlights, glowing panels of VD-Link's rooms (MeshBasic × intensity).
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 color : source_color = vec3(1.0);
uniform float intensity = 1.0;

void fragment() {
	ALBEDO = color * intensity;
}
