// LED surface of a video wall, like src/render/videowall.ts: the surface shows its rectangle of
// the output (rect), the output shows the source picture according to the fit mode (map).
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D tex : source_color, filter_linear;
/** Part of the output on this surface: x, y, w, h (0…1, top-left origin). */
uniform vec4 rect = vec4(0.0, 0.0, 1.0, 1.0);
/** Output → source: scale x, y, offset x, y. */
uniform vec4 map = vec4(1.0, 1.0, 0.0, 0.0);
uniform float brightness = 1.0;
/** 0 black, 1 live picture, 2 test image, 3 demo visuals (standalone without computer). */
uniform int mode = 2;

vec3 test_image(vec2 o) {
	// Colour bars with a grid – shows how the output is split across the surfaces.
	const vec3 bars[8] = vec3[8](vec3(0.75), vec3(0.75, 0.75, 0.0), vec3(0.0, 0.75, 0.75), vec3(0.0, 0.75, 0.0),
		vec3(0.75, 0.0, 0.75), vec3(0.75, 0.0, 0.0), vec3(0.0, 0.0, 0.75), vec3(0.08));
	vec3 c = bars[clamp(int(o.x * 8.0), 0, 7)];
	if (o.y > 0.72) c = vec3(o.x);
	vec2 g = abs(fract(o * vec2(16.0, 9.0) + 0.5) - 0.5);
	if (min(g.x, g.y) < 0.02) c = vec3(0.9);
	return c;
}

// Demo visuals: moving colour bands and rings over the whole output (own, procedural).
vec3 demo_image(vec2 o) {
	float t = TIME * 0.6;
	vec2 p = (o - 0.5) * vec2(3.0, 1.0);
	float r = length(p);
	float bands = smoothstep(0.35, 0.65, sin(o.x * 9.0 - t * 2.2) * 0.5 + 0.5);
	float rings = pow(sin(r * 18.0 - t * 4.0) * 0.5 + 0.5, 3.0);
	float beat = pow(0.5 + 0.5 * sin(t * 3.14159), 8.0);
	vec3 a = vec3(1.0, 0.12, 0.45);
	vec3 b = vec3(0.05, 0.75, 1.0);
	vec3 c = mix(a, b, bands) * (0.08 + 1.1 * rings);
	c += vec3(1.0, 0.85, 0.7) * beat * smoothstep(0.3, 0.0, r);
	return c;
}

void fragment() {
	vec2 o = rect.xy + UV * rect.zw;
	vec3 c = vec3(0.0);
	if (mode == 2) {
		c = test_image(o);
	} else if (mode == 3) {
		c = demo_image(o);
	} else if (mode == 1) {
		vec2 s = o * map.xy + map.zw;
		if (all(greaterThanEqual(s, vec2(0.0))) && all(lessThanEqual(s, vec2(1.0)))) c = texture(tex, s).rgb;
	}
	ALBEDO = c * brightness;
}
