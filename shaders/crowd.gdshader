// The crowd: hundreds of overlapping capsules. Light is computed per vertex (hemisphere light
// like VD-Link's 3D view + the beam light that falls on the floor where a person stands) – the
// pixels only output that colour, so overlapping people cost almost nothing.
// INSTANCE_CUSTOM = (phase, height): people bob to 128 BPM like on the desktop.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec3 albedo : source_color = vec3(0.33, 0.33, 0.37);
uniform float receive = 0.45;

global uniform sampler2D spot_map : filter_linear;
global uniform vec4 spot_area;
global uniform float spot_gain;
global uniform int spot_count;
global uniform float ambient_gain;

varying vec3 v_col;

void vertex() {
	float bob = max(0.0, sin(TIME * 6.2831853 * (128.0 / 60.0) + INSTANCE_CUSTOM.x)) * 0.06;
	VERTEX.y += bob / max(INSTANCE_CUSTOM.y, 0.5);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 muv = clamp((wp.xz - spot_area.xy) / spot_area.zw, vec2(0.0), vec2(1.0));
	vec3 light = spot_count > 0 ? textureLod(spot_map, muv, 0.0).rgb : vec3(0.0);
	v_col = albedo * mix(vec3(0.0052, 0.0052, 0.0070), vec3(0.216, 0.279, 0.434), n.y * 0.5 + 0.5) * ambient_gain
		+ light * spot_gain * receive * mix(vec3(1.0), albedo, 0.5) * (0.35 + 0.65 * max(n.y, 0.0));
}

void fragment() {
	ALBEDO = v_col;
}
