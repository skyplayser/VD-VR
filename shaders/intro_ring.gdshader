// Start animation: light line on the floor around you, drawn from the front to the back on both
// sides (UV.x: 0 = in front, 1 = behind; UV.y across the line). Colour from the vertices.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float draw = 1.0;
uniform float intensity = 1.0;
uniform float soft = 1.5;

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float a = pow(max(across, 0.0), soft);
	float shown = smoothstep(draw + 0.01, draw - 0.01, UV.x);
	float head = exp(-max(draw - UV.x, 0.0) * 25.0) * step(draw, 0.999);
	ALBEDO = COLOR.rgb * COLOR.a * a * shown * intensity * (1.0 + 2.5 * head);
}
