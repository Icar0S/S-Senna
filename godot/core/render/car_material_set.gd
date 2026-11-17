class_name CarMaterialSet
extends RefCounted
## The per-car materials: one paint material per zone, the glass and the lights.
## Created once per car; changing a color only changes uniforms.

const DEFAULT_PAINTS: Dictionary = {
	"paint_body": "#B8BCC2",
	"paint_secondary": "#141518",
	"rim": "#B8BCC2",
	"rim_accent": "#E8E8E8",
	"caliper": "#B01010",
}
const HEADLIGHT_ENERGY: float = 3.0
## Tail lights glow a little when the headlights are on.
const TAIL_RUNNING: float = 0.35

## Zone -> ShaderMaterial.
var paints: Dictionary = {}
## Light name -> ShaderMaterial.
var lights: Dictionary = {}
var glass: ShaderMaterial = null


func _init() -> void:
	for zone: String in MaterialLibrary.PAINT_ZONES:
		var spec: PaintSpec = PaintSpec.new()
		spec.finish = "metallic" if zone.begins_with("rim") else "solid"
		spec.color = DEFAULT_PAINTS.get(zone, "#FFFFFF")
		paints[zone] = MaterialLibrary.new_paint_material(spec)
	for light: String in MaterialLibrary.LIGHTS:
		lights[light] = MaterialLibrary.new_light_material(light)
	glass = MaterialLibrary.new_glass_material(Color("#101418"), 0.3)


## Material for a surface named [param material_name]. [param finish] is the part
## finish of the surface's part (`paint`, `carbon`, `black`); [param trim_as_body]
## paints `trim_black` with the body color. Null means "keep the model's material".
func material_for(
	material_name: String, finish: String = "", trim_as_body: bool = false
) -> Material:
	var own: Material = _own_material(material_name, finish, trim_as_body)
	if own != null:
		return own
	if MaterialLibrary.keeps_original(material_name):
		return null
	return MaterialLibrary.shared(material_name)


func set_paint(zone: String, spec: PaintSpec) -> void:
	if paints.has(zone):
		MaterialLibrary.set_paint(paints[zone], spec)


func set_glass(tint: Color, darkness: float) -> void:
	MaterialLibrary.set_glass(glass, tint, darkness)


## [param headlights]: on/off; [param brake]: 0..1.
func set_lights(headlights: bool, brake: float) -> void:
	var head: ShaderMaterial = lights[MaterialLibrary.LIGHT_HEAD]
	head.set_shader_parameter("on", 1.0 if headlights else 0.0)
	var tail: ShaderMaterial = lights[MaterialLibrary.LIGHT_TAIL]
	tail.set_shader_parameter("on", TAIL_RUNNING if headlights else 0.0)
	tail.set_shader_parameter("boost", clampf(brake, 0.0, 1.0))


## Materials that depend on this car (paint, finishes, glass, lights); null otherwise.
func _own_material(material_name: String, finish: String, trim_as_body: bool) -> Material:
	if material_name == MaterialLibrary.BODY_PAINT and MaterialLibrary.FINISH_MATERIALS.has(finish):
		return MaterialLibrary.shared(MaterialLibrary.FINISH_MATERIALS[finish])
	if material_name == MaterialLibrary.TRIM and trim_as_body:
		return paints[MaterialLibrary.BODY_PAINT]
	if material_name == MaterialLibrary.GLASS:
		return glass
	if paints.has(material_name):
		return paints[material_name]
	return lights.get(material_name)
