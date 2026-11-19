// Start animation: a picture (suite logo, program icons), with a wipe from the left
// (clip_lo … clip_hi) and a light line at the wipe's edge. Drawn over everything else.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha = 1.0;
uniform float clip_lo = 0.0;
uniform float clip_hi = 1.0;
uniform float edge = 0.0;

void fragment() {
	vec4 c = texture(tex, UV);
	float m = step(clip_lo, UV.x) * smoothstep(clip_hi + 0.003, clip_hi - 0.003, UV.x);
	float line = edge * exp(-abs(UV.x - clip_hi) * 120.0) * step(clip_lo, UV.x);
	ALBEDO = c.rgb + vec3(line);
	ALPHA = clamp(c.a * m + line * 0.6, 0.0, 1.0) * alpha;
}
