// Additive light shapes: neon script (texture), soft glow on the floor (fades along u).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0);
uniform float intensity = 1.0;
uniform bool use_tex = false;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform bool fade = false;

void fragment() {
	vec3 c = color * intensity;
	if (use_tex) {
		vec4 t = texture(tex, UV);
		c *= t.rgb * t.a;
	}
	if (fade) {
		float k = 1.0 - smoothstep(0.0, 1.0, UV.x);
		c *= k * k;
	}
	ALBEDO = c;
}
