// Start animation: a beam of light (cylinder, narrow end at UV.y = 0), fading along its length
// and towards its edges. Additive.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float intensity = 1.0;
uniform float fade = 1.4;

void fragment() {
	float f = pow(clamp(1.0 - UV.y, 0.0, 1.0), fade);
	float e = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.8);
	ALBEDO = color.rgb * intensity * f * e;
}
