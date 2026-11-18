// S-Senna — test field floor: asphalt-gray with a 1 m grid and a stronger 10 m grid,
// in world space (no UVs). Works in Forward+ and Compatibility.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 base_color : source_color = vec3(0.24, 0.25, 0.27);
uniform vec3 line_color : source_color = vec3(0.55, 0.57, 0.6);
uniform vec3 major_color : source_color = vec3(0.9, 0.75, 0.25);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 1 on the grid lines, 0 elsewhere; [width_px] wide, antialiased with derivatives.
float grid(vec2 p, float spacing, float width_px) {
	vec2 coord = p / spacing;
	vec2 distance_px = abs(fract(coord - 0.5) - 0.5) / max(fwidth(coord), vec2(0.0001));
	return 1.0 - clamp(min(distance_px.x, distance_px.y) / width_px, 0.0, 1.0);
}

void fragment() {
	float minor = grid(world_pos.xz, 1.0, 1.0);
	float major = grid(world_pos.xz, 10.0, 2.0);
	vec3 color = mix(base_color, line_color, minor * 0.5);
	color = mix(color, major_color, major * 0.6);
	ALBEDO = color;
	ROUGHNESS = 0.85;
}
