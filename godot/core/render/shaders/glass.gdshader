// S-Senna — car glass: tinted, more opaque and reflective at grazing angles.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.06, 0.08, 0.1);
// Window film: 0 = clear, 1 = almost black.
uniform float darkness : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	ALBEDO = tint;
	METALLIC = 0.0;
	ROUGHNESS = 0.03;
	SPECULAR = 0.75;
	ALPHA = clamp(mix(0.35, 0.96, darkness) + fresnel * 0.45, 0.0, 1.0);
}
