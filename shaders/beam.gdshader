// Volumetric light beam (additive cone), the same look as the VD-Link desktop beams
// (src/render/beam.ts). One MultiMesh instance per beam:
//   transform: origin = lens centre, basis x = right, y = beam direction, z = up
//   COLOR.rgb = beam colour, INSTANCE_CUSTOM = (tanHalf, lens radius, softness, length)
// Mobile: everything is computed per vertex (the cone has 24 sides – smooth enough), the
// pixel only multiplies colour and brightness. The cone ends where it meets the floor.
shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled, fog_disabled;

global uniform float haze;
const float BEAM_LENGTH = 32.0;

varying vec3 v_rgb;

void vertex() {
	float tan_half = INSTANCE_CUSTOM.x;
	float lens = INSTANCE_CUSTOM.y;
	float soft_w = INSTANCE_CUSTOM.z;
	float len = INSTANCE_CUSTOM.w > 0.0 ? INSTANCE_CUSTOM.w : BEAM_LENGTH;
	float along = VERTEX.y;
	float dist = along * len;
	float radius = lens + dist * tan_half;
	vec3 local = vec3(VERTEX.x * radius, dist, VERTEX.z * radius);
	vec3 world = (MODEL_MATRIX * vec4(local, 1.0)).xyz;
	vec3 view_pos = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	vec3 n_world = normalize((MODEL_MATRIX * vec4(VERTEX.x, 0.0, VERTEX.z, 0.0)).xyz);
	vec3 n_view = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	// Brighter where you look along the beam surface, softer for washes.
	float facing = abs(dot(n_view, normalize(-view_pos)));
	float edge = pow(facing, mix(1.1, 3.4, soft_w)) * mix(1.35, 0.28, soft_w);
	float frac = dist / BEAM_LENGTH;
	float falloff = 1.0 / (1.0 + dist * 0.09) * pow(max(1.0 - frac, 0.0), 0.6);
	float narrow = pow(clamp(0.08 / max(tan_half, 0.004), 0.6, 3.5), 0.65);
	// Fade the last 60 cm above the floor (no depth-buffer copy needed).
	float soft = smoothstep(0.02, 0.6, world.y);
	v_rgb = COLOR.rgb * edge * falloff * narrow * soft * haze * 0.9;
	VERTEX = local;
}

void fragment() {
	ALBEDO = v_rgb;
}
