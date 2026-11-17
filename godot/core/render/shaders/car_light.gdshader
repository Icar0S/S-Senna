// S-Senna — car lights (head, tail, turn signal): emissive, with the bloom of the
// environment doing the glow. One instance per car per light kind.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec3 light_color : source_color = vec3(1.0);
// Glow of the lens when the light is off (so it still reads as a lamp).
uniform float off_energy = 0.15;
uniform float on_energy = 3.0;
// 0..1: light switched on.
uniform float on = 0.0;
// 0..1: extra intensity (brake pedal for tail lights).
uniform float boost = 0.0;
uniform float boost_energy = 6.0;

void fragment() {
	ALBEDO = light_color * 0.35;
	METALLIC = 0.0;
	ROUGHNESS = 0.15;
	EMISSION = light_color * (off_energy + on * on_energy + boost * boost_energy);
}
