// Glass railings and see-through panels: barely visible like in VD-Link (opacity ~0.15),
// a faint edge at grazing angles. Unshaded – cheap even when it covers much of the view.
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.6, 0.67, 0.73);
uniform float opacity = 0.15;
global uniform float ambient_gain;

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	ALBEDO = color * (0.06 + 0.05 * ambient_gain);
	ALPHA = clamp(opacity * 0.5 + fres * 0.08, 0.0, 0.4);
}
