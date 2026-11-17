// S-Senna — carbon fiber: procedural 2x2 twill, triplanar in object space (no UVs).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.07, 0.075, 0.08);
// Weave cells per meter.
uniform float weave_scale = 60.0;
uniform float gloss : hint_range(0.0, 1.0) = 0.9;

varying vec3 object_pos;
varying vec3 object_normal;

void vertex() {
	object_pos = VERTEX;
	object_normal = NORMAL;
}

// 0..1 brightness of the twill at a 2D point.
float twill(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	// Twill: the over/under pattern shifts one cell per row.
	float horizontal = mod(cell.x + cell.y, 4.0) < 2.0 ? 1.0 : 0.0;
	float along = mix(f.y, f.x, horizontal);
	float across = mix(f.x, f.y, horizontal);
	float fiber = 0.75 + 0.25 * sin(across * 3.14159 * 6.0);
	float bundle = sin(along * 3.14159);
	return clamp(bundle * fiber, 0.0, 1.0) * mix(0.75, 1.0, horizontal);
}

void fragment() {
	vec3 w = pow(abs(normalize(object_normal)), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = object_pos * weave_scale;
	float pattern = twill(p.zy) * w.x + twill(p.xz) * w.y + twill(p.xy) * w.z;
	ALBEDO = tint * (0.55 + 0.9 * pattern);
	METALLIC = 0.25;
	ROUGHNESS = mix(0.5, 0.28, pattern);
	CLEARCOAT = gloss;
	CLEARCOAT_ROUGHNESS = mix(0.35, 0.03, gloss);
}
