class_name MaterialLibrary
extends RefCounted
## The game's materials, picked by the NAME of the material in the model (doc 03 §4.2).
##
## - Shared materials (chrome, rubber, trim, carbon...): ONE instance for every car.
## - Per-car materials (paint zones, glass, lights): see [CarMaterialSet]; their
##   uniforms change, the instances are reused (no new material per color change).
## - `tex_*` materials are kept as they come in the model.

const PAINT_SHADER: String = "res://core/render/shaders/car_paint.gdshader"
const CARBON_SHADER: String = "res://core/render/shaders/carbon.gdshader"
const GLASS_SHADER: String = "res://core/render/shaders/glass.gdshader"
const LIGHT_SHADER: String = "res://core/render/shaders/car_light.gdshader"

## Material names that become a per-car paint (must exist in conventions.json).
const PAINT_ZONES: PackedStringArray = [
	"paint_body", "paint_secondary", "rim", "rim_accent", "caliper"
]
const LIGHT_HEAD: String = "light_head"
const LIGHT_TAIL: String = "light_tail"
const LIGHT_SIGNAL: String = "light_signal"
const LIGHTS: PackedStringArray = [LIGHT_HEAD, LIGHT_TAIL, LIGHT_SIGNAL]
const GLASS: String = "glass"
const BODY_PAINT: String = "paint_body"
const TRIM: String = "trim_black"
const CARBON: String = "carbon"
const RUBBER: String = "rubber"
const METAL_DARK: String = "metal_dark"
## Part finishes (conventions `part_finishes`) -> material used on its painted surfaces.
const FINISH_MATERIALS: Dictionary = {"carbon": CARBON, "black": TRIM}
## Order of `finish` in car_paint.gdshader; a test checks it against conventions.json.
const SHADER_FINISH_ORDER: PackedStringArray = [
	"solid", "metallic", "pearl", "matte", "satin", "chrome", "candy", "chameleon"
]

static var _shared: Dictionary = {}
static var _shaders: Dictionary = {}


## The shared instance for [param material_name], or null when that name is not
## a shared material (paint zones, glass, lights and `tex_*` are not).
static func shared(material_name: String) -> Material:
	if _shared.has(material_name):
		return _shared[material_name]
	var material: Material = _create_shared(material_name)
	if material != null:
		material.resource_name = material_name
		_shared[material_name] = material
	return material


static func is_paint_zone(material_name: String) -> bool:
	return PAINT_ZONES.has(material_name)


static func is_light(material_name: String) -> bool:
	return LIGHTS.has(material_name)


## True for `tex_*` names: the model's own material is kept.
static func keeps_original(material_name: String) -> bool:
	var prefix: String = str(Conventions.data().get("material_prefix_keep", "tex_"))
	return material_name.begins_with(prefix)


## A new paint material (one per car per zone).
static func new_paint_material(spec: PaintSpec) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _shader(PAINT_SHADER)
	set_paint(material, spec)
	return material


## Updates the uniforms of a paint material (never creates a new one).
static func set_paint(material: ShaderMaterial, spec: PaintSpec) -> void:
	material.set_shader_parameter("finish", maxi(0, SHADER_FINISH_ORDER.find(spec.finish)))
	material.set_shader_parameter("color", spec.get_color())
	material.set_shader_parameter("color2", spec.get_color2())
	material.set_shader_parameter("flake", spec.flake)
	material.set_shader_parameter("gloss", spec.gloss)


static func new_glass_material(tint: Color, darkness: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _shader(GLASS_SHADER)
	material.resource_name = GLASS
	set_glass(material, tint, darkness)
	return material


static func set_glass(material: ShaderMaterial, tint: Color, darkness: float) -> void:
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("darkness", darkness)


static func new_light_material(light_name: String) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _shader(LIGHT_SHADER)
	material.resource_name = light_name
	var colors: Dictionary = {
		LIGHT_HEAD: Color("#F4F7FF"), LIGHT_TAIL: Color("#E0141C"), LIGHT_SIGNAL: Color("#FF9A1F")
	}
	material.set_shader_parameter("light_color", colors.get(light_name, Color.WHITE))
	return material


static func _create_shared(material_name: String) -> Material:
	match material_name:
		CARBON:
			var carbon: ShaderMaterial = ShaderMaterial.new()
			carbon.shader = _shader(CARBON_SHADER)
			return carbon
		TRIM:
			return _standard(Color("#141518"), 0.0, 0.7)
		"chrome":
			return _standard(Color("#E9ECEF"), 1.0, 0.05)
		METAL_DARK:
			return _standard(Color("#34373C"), 0.85, 0.38)
		RUBBER:
			return _standard(Color("#0E0E0F"), 0.0, 0.92)
		"interior":
			return _standard(Color("#1C1D20"), 0.0, 0.85)
		"plate":
			return _standard(Color("#E8E8E2"), 0.0, 0.45)
		"glass_light":
			var lens: StandardMaterial3D = _standard(Color(0.95, 0.97, 1.0, 0.18), 0.0, 0.02)
			lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			return lens
	return null


static func _standard(albedo: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _shader(path: String) -> Shader:
	if not _shaders.has(path):
		_shaders[path] = load(path)
	return _shaders[path]
