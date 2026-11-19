// Room surfaces that show the light spots of the beams ("fake spot lights", like
// src/render/lighting.ts on the desktop). The brightest spots of the frame are in a small
// float texture (4 texels per spot): apex.xyz cosOuter | dir.xyz cosInner | rgb gobo | right.xyz.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec3 albedo : source_color = vec3(0.2);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.8;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
/** How strongly the surface shows spots (black matt paint still shows them). */
uniform float receive : hint_range(0.0, 2.0) = 1.0;
uniform vec3 emission_color : source_color = vec3(0.0);
/** Looks of VD-Link's materials: 1 quilted wall, 2 black marble, 3 ribbed duct, 4 velvet sheen. */
uniform int pattern = 0;
uniform float sheen_k = 0.0;
/** Vertex colours hold the room's point lights (baked by VD-Link). */
uniform bool baked = false;
uniform float baked_gain = 1.0;
/** Crowd (MultiMesh): bob to 128 BPM, INSTANCE_CUSTOM = (phase, height). */
uniform bool crowd = false;

global uniform int spot_count;
global uniform sampler2D spot_tex : filter_nearest;
global uniform float spot_gain;
/** Light map from above (spotmap.gdshader) and its area in the room, its height map. */
global uniform sampler2D spot_map : filter_linear;
global uniform sampler2D spot_height : filter_nearest;
global uniform vec4 spot_area;
/** Spots looped per pixel on walls and other surfaces the map does not cover (brightest first). */
global uniform int spot_wall_count;

/** Room light like VD-Link's hemisphere light (sky above, dark floor below); menu „Grundlicht“. */
global uniform float ambient_gain;
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

varying vec3 v_world;

void vertex() {
	if (crowd) {
		float bob = max(0.0, sin(TIME * 6.2831853 * (128.0 / 60.0) + INSTANCE_CUSTOM.x)) * 0.06;
		VERTEX.y += bob / max(INSTANCE_CUSTOM.y, 0.5);
	}
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Small value noise for the marble veins (signed, about -1..1).
float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z) * 2.0 - 1.0;
}

float fbm(vec3 p) {
	return vnoise(p) * 0.66 + vnoise(p * 2.0) * 0.34;
}

// Base colour with the pattern (linear colours, like the TSL nodes in VD-Link).
vec3 base_color(vec3 a, vec2 uv) {
	if (pattern == 1) {
		float u = v_world.x + v_world.z;
		float s1 = fract((u + v_world.y) * 1.6);
		float s2 = fract((u - v_world.y) * 1.6);
		float line = 1.0 - smoothstep(0.0, 0.05, min(min(s1, 1.0 - s1), min(s2, 1.0 - s2)));
		return a * (1.0 - line * 0.5);
	}
	if (pattern == 2) {
		vec3 p = v_world * vec3(0.55, 1.1, 0.55);
		float v1 = 1.0 - smoothstep(0.0, 0.03, abs(fbm(p)));
		return mix(vec3(0.018, 0.018, 0.02), vec3(0.62, 0.62, 0.64), v1 * 0.85);
	}
	if (pattern == 3) {
		return vec3(0.16, 0.165, 0.18) * (0.7 + smoothstep(0.75, 0.85, fract(uv.y * 4.0)) * 0.6);
	}
	return a;
}

void fragment() {
	vec3 col = base_color(albedo, UV);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 sum = vec3(0.0);
	vec2 muv = (v_world.xz - spot_area.xy) / spot_area.zw;
	bool on_map = n.y > 0.7 && all(greaterThanEqual(muv, vec2(0.0))) && all(lessThanEqual(muv, vec2(1.0)))
		&& abs(texture(spot_height, muv).r - v_world.y) < 0.12;
	if (on_map) {
		// Floor, stage, podiums: one texel of the light map.
		sum = texture(spot_map, muv).rgb;
	} else if (crowd) {
		// People: the light that falls on the floor where they stand (many overlapping capsules –
		// the per-spot loop would cost the headset far too much).
		sum = texture(spot_map, clamp(muv, vec2(0.0), vec2(1.0))).rgb * (0.35 + 0.65 * max(n.y, 0.0));
	} else {
		int count = min(spot_count, spot_wall_count);
		for (int i = 0; i < count; i++) {
			vec4 t0 = texelFetch(spot_tex, ivec2(0, i), 0);
			vec4 t1 = texelFetch(spot_tex, ivec2(1, i), 0);
			vec3 to_p = v_world - t0.xyz;
			float dist = max(length(to_p), 0.001);
			vec3 l = to_p / dist;
			float cos_t = dot(l, t1.xyz);
			if (cos_t > t0.w) {
				vec4 t2 = texelFetch(spot_tex, ivec2(2, i), 0);
				vec4 t3 = texelFetch(spot_tex, ivec2(3, i), 0);
				float cone = smoothstep(t0.w, t1.w, cos_t);
				float lambert = max(dot(n, -l), 0.0);
				float atten = 1.0 / (1.0 + dist * dist * 0.012);
				sum += t2.rgb * cone * lambert * atten * gobo_mask(t0, t1, t2, t3, l, cos_t);
			}
		}
	}
	vec3 em = emission_color + sum * spot_gain * receive * mix(vec3(1.0), albedo, 0.5);
	// Hemisphere light of VD-Link's 3D view (0x8090b0 above, 0x101014 below), linear colours.
	em += col * mix(vec3(0.0052, 0.0052, 0.0070), vec3(0.216, 0.279, 0.434), n.y * 0.5 + 0.5) * ambient_gain;
	if (baked) em += col * COLOR.rgb * baked_gain;
	if (pattern == 4) em += albedo * pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0) * sheen_k;
	EMISSION = em;
}
