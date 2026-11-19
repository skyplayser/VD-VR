// Light map of the beam spots seen from above (floor, stage, podiums), computed once per
// frame at a fixed resolution instead of per pixel and eye in the headset. The room
// surfaces facing up only read one texel from it.
shader_type canvas_item;
render_mode blend_disabled;

/** Height of the walkable surface per texel (metres, R channel). */
uniform sampler2D height_tex : filter_linear;

global uniform vec4 spot_area;   // x0, z0, width, depth of the map in the room
global uniform int spot_count;
global uniform sampler2D spot_tex : filter_nearest;

global uniform sampler2D gobo_tex : filter_linear;
global uniform vec2 gobo_grid;

// Gobo of spot i at direction L from its apex (as src/render/lighting.ts): position on the
// beam's cross-section, -1..1 at the cone edge, then the tile of the atlas.
float gobo_mask(vec4 t0, vec4 t1, vec4 t2, vec4 t3, vec3 L, float cos_t) {
	if (t2.w < 0.5 || gobo_grid.x < 0.5) return 1.0;
	float tan_half = sqrt(max(1.0 - t0.w * t0.w, 0.0)) / max(t0.w, 0.01);
	float denom = max(cos_t, 0.01) * tan_half;
	vec3 up = cross(t1.xyz, t3.xyz);
	float gx = clamp(dot(L, t3.xyz) / denom, -0.98, 0.98);
	float gy = clamp(dot(L, up) / denom, -0.98, 0.98);
	float tile = max(t2.w - 1.0, 0.0);
	float row = floor((tile + 0.5) / gobo_grid.x);
	float col = tile - row * gobo_grid.x;
	vec2 uv = vec2((col + gx * 0.5 + 0.5) / gobo_grid.x, (row - gy * 0.5 + 0.5) / gobo_grid.y);
	return textureLod(gobo_tex, uv, 0.0).r;
}

void fragment() {
	vec2 uv = UV;
	float y = texture(height_tex, uv).r;
	vec3 p = vec3(spot_area.x + uv.x * spot_area.z, y, spot_area.y + uv.y * spot_area.w);
	vec3 sum = vec3(0.0);
	for (int i = 0; i < spot_count; i++) {
		vec4 t0 = texelFetch(spot_tex, ivec2(0, i), 0);
		vec4 t1 = texelFetch(spot_tex, ivec2(1, i), 0);
		vec3 to_p = p - t0.xyz;
		float dist = max(length(to_p), 0.001);
		vec3 l = to_p / dist;
		float cos_t = dot(l, t1.xyz);
		if (cos_t > t0.w) {
			vec4 t2 = texelFetch(spot_tex, ivec2(2, i), 0);
			vec4 t3 = texelFetch(spot_tex, ivec2(3, i), 0);
			float cone = smoothstep(t0.w, t1.w, cos_t);
			float lambert = max(-l.y, 0.0);
			float atten = 1.0 / (1.0 + dist * dist * 0.012);
			sum += t2.rgb * cone * lambert * atten * gobo_mask(t0, t1, t2, t3, l, cos_t);
		}
	}
	COLOR = vec4(sum, 1.0);
}
