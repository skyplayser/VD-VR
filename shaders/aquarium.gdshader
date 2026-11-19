// Glowing aquarium wall of VD-Link's club: turquoise caustics, light rays and drifting
// jellyfish (cheaper noise than on the desktop, same look).
shader_type spatial;
render_mode unshaded, cull_back;

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 st = vec2(UV.x, 1.0 - UV.y);
	float t = TIME;
	vec2 q = st * vec2(7.0, 3.0);
	float caust = n2(q + vec2(t * 0.25, 0.0)) * 0.6 + n2(q * 2.0 - vec2(0.0, t * 0.3)) * 0.4;
	caust = caust * 2.0 - 1.0;
	float rays = pow(sin(st.x * 40.0 + caust * 6.0) * 0.5 + 0.5, 6.0) * st.y * 0.35;
	vec3 col = vec3(0.0, 0.42, 0.55) * (0.75 + caust * 0.5) + vec3(0.3, 0.9, 1.0) * rays;
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		float sx = mod(fi * 0.37 + 0.11, 1.0);
		float sp = 0.012 + mod(fi, 3.0) * 0.006;
		float y = fract(t * sp + fi * 0.23);
		float x = sx + sin(t * 0.3 + fi) * 0.03;
		float d = length((st - vec2(x, y)) * vec2(3.2, 1.2));
		col += vec3(0.85, 0.3, 1.0) * smoothstep(0.05, 0.0, d) * 1.4;
	}
	ALBEDO = col * (0.45 + st.y * 0.7) * 1.05;
}
