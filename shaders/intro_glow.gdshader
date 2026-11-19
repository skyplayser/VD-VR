// Start animation: soft round light (stars, halos behind signs and icons). Additive.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float intensity = 1.0;
uniform float sharp = 2.0;
uniform bool stars = false;
varying float phase;

void vertex() {
	phase = INSTANCE_CUSTOM.x;
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(max(0.0, 1.0 - d), sharp);
	vec3 c = color.rgb;
	float k = intensity;
	if (stars) {
		c *= COLOR.rgb;
		k *= 0.55 + 0.45 * sin(TIME * (1.2 + phase * 2.5) + phase * 40.0);
	}
	ALBEDO = c * a * k;
}
