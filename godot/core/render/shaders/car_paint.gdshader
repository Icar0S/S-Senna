// S-Senna — car paint (Forward+ and Compatibility).
// One material instance per car per paint zone; the game only changes uniforms.
// `finish` follows the order of `paint_finishes` in core/content/conventions.json:
// 0 solid, 1 metallic, 2 pearl, 3 matte, 4 satin, 5 chrome, 6 candy, 7 chameleon.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform int finish = 0;
uniform vec3 color : source_color = vec3(0.8, 0.12, 0.1);
uniform vec3 color2 : source_color = vec3(0.1, 0.2, 0.9);
// Metallic flakes amount (0..1).
uniform float flake : hint_range(0.0, 1.0) = 0.0;
// Clear coat shine (0 = no varnish).
uniform float gloss : hint_range(0.0, 1.0) = 0.9;
// Flakes per meter (object space, so no UVs are needed).
uniform float flake_scale = 260.0;

// Vinyls (Etapa 08): one texture per side, box-projected in car space.
uniform bool vinyl_enabled = false;
uniform sampler2D vinyl_tex_left : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D vinyl_tex_right : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D vinyl_tex_top : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D vinyl_tex_front : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D vinyl_tex_rear : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 vinyl_box_min = vec3(-1.0, 0.0, -2.5);
uniform vec3 vinyl_box_max = vec3(1.0, 1.5, 2.5);

varying vec3 object_pos;
varying vec3 object_normal;

void vertex() {
	object_pos = VERTEX;
	object_normal = NORMAL;
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Car space: +X left, +Y up, +Z front. Each side only paints surfaces facing it.
vec4 vinyl_color() {
	vec3 box = (object_pos - vinyl_box_min) / max(vinyl_box_max - vinyl_box_min, vec3(0.001));
	vec3 n = normalize(object_normal);
	vec4 result = vec4(0.0);
	float w_left = smoothstep(0.35, 0.6, n.x);
	float w_right = smoothstep(0.35, 0.6, -n.x);
	float w_top = smoothstep(0.35, 0.6, n.y);
	float w_front = smoothstep(0.35, 0.6, n.z);
	float w_rear = smoothstep(0.35, 0.6, -n.z);
	result += texture(vinyl_tex_left, vec2(1.0 - box.z, 1.0 - box.y)) * w_left;
	result += texture(vinyl_tex_right, vec2(box.z, 1.0 - box.y)) * w_right;
	result += texture(vinyl_tex_top, vec2(box.x, 1.0 - box.z)) * w_top;
	result += texture(vinyl_tex_front, vec2(1.0 - box.x, 1.0 - box.y)) * w_front;
	result += texture(vinyl_tex_rear, vec2(box.x, 1.0 - box.y)) * w_rear;
	return clamp(result, vec4(0.0), vec4(1.0));
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = 1.0 - facing;
	vec3 base = color;
	float metallic = 0.0;
	float roughness = 0.32;
	float coat = gloss;
	float flake_amount = 0.0;

	if (finish == 1) { // metallic
		metallic = 0.55;
		roughness = 0.36;
		flake_amount = flake;
	} else if (finish == 2) { // pearl: color -> color2 toward the edges
		base = mix(color, color2, smoothstep(0.2, 0.95, edge) * 0.85);
		metallic = 0.3;
		roughness = 0.3;
		flake_amount = flake * 0.6;
	} else if (finish == 3) { // matte
		roughness = 0.82;
		coat = 0.0;
	} else if (finish == 4) { // satin
		roughness = 0.55;
		coat = gloss * 0.25;
	} else if (finish == 5) { // chrome
		// A bit of silver diffuse: pure mirrors look black in dark places.
		base = mix(color, vec3(1.0), 0.25);
		metallic = 0.82;
		roughness = 0.06;
		coat = 0.0;
	} else if (finish == 6) { // candy: deep color over a bright base (color2)
		base = mix(color2, color * 0.75, smoothstep(0.0, 0.7, facing));
		metallic = 0.45;
		roughness = 0.22;
		flake_amount = flake * 0.5;
	} else if (finish == 7) { // chameleon: strong shift with the viewing angle
		base = mix(color, color2, smoothstep(0.1, 0.8, edge));
		metallic = 0.6;
		roughness = 0.26;
		flake_amount = flake * 0.4;
	}

	if (flake_amount > 0.0) {
		vec3 flake_pos = object_pos * flake_scale;
		// Fade the flakes out when a flake is smaller than a pixel (far away), so the
		// paint reads as a smooth metallic instead of noise.
		float pixel_cells = length(fwidth(flake_pos));
		float near = clamp(1.6 - pixel_cells, 0.0, 1.0);
		vec3 cell = floor(flake_pos);
		vec3 rnd = hash33(cell) * 2.0 - 1.0;
		vec3 tilt = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(rnd, 0.0)).xyz);
		NORMAL = normalize(NORMAL + tilt * 0.07 * flake_amount * near);
		float sparkle = step(0.965, hash33(cell + 17.0).x) * flake_amount * near;
		base = mix(base, vec3(1.0), sparkle * 0.18);
		// What the flakes add at a distance: a slightly brighter, more metallic look.
		metallic = mix(metallic, metallic + 0.15, flake_amount * (1.0 - near));
	}

	if (vinyl_enabled) {
		vec4 vinyl = vinyl_color();
		base = mix(base, vinyl.rgb, vinyl.a);
		metallic = mix(metallic, 0.0, vinyl.a);
		roughness = mix(roughness, 0.35, vinyl.a);
	}

	ALBEDO = base;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = mix(0.4, 0.03, gloss);
}
