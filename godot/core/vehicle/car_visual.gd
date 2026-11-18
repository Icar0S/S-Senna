class_name CarVisual
extends Node3D
## A car on screen: the model with the chosen parts, materials, wheels and stance.
## Built by [CarAssembler]; the same code runs in the game, the garage, races and
## the Studio. Knows nothing about physics.
##
## Layout: CarVisual -> Body (moved by the ride height) -> model; CarVisual -> Wheels.

signal rebuilt

const MM: float = 0.001
const FINISH_PAINT: String = "paint"

var car: CarDef = null
## The configuration being shown (as stored in the save; may hold missing IDs).
var config: CarConfig = null
var library: ContentLibrary = null
## Problems found while building (unknown names/materials, missing nodes).
var issues: PackedStringArray = []
## IDs in the config that are not in the loaded content (shown as stock).
var missing: PackedStringArray = []
var materials: CarMaterialSet = CarMaterialSet.new()
## False when a [Vehicle] drives this car: the physics places the wheels and the
## ride height becomes a suspension setting instead of a visual offset.
var body_follows_ride_height: bool = true

var _body: Node3D = null
var _wheels_root: Node3D = null
var _model: Node3D = null
var _scan: ConventionScanner.ScanResult = null
## Slot -> universal part instance currently attached.
var _universal: Dictionary = {}
## Position -> WheelVisual.
var _wheels: Dictionary = {}
var _trim_as_body: bool = false
var _headlights: bool = false
var _brake: float = 0.0
var _reverse: bool = false


## Sets up the nodes for [param model] (called once by [CarAssembler]).
func setup(car_def: CarDef, model: Node3D, content: ContentLibrary) -> void:
	car = car_def
	library = content
	name = "Car_" + car_def.id.get_slice("/", car_def.id.get_slice_count("/") - 1)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_wheels_root = Node3D.new()
	_wheels_root.name = "Wheels"
	add_child(_wheels_root)
	_model = model
	_body.add_child(model)
	_scan = ConventionScanner.scan(model)
	issues.append_array(_scan.issues)
	_check_model_matches_car()
	if _scan.rim != null:
		_scan.rim.visible = false
	for collision: Node3D in _scan.collisions:
		collision.visible = false
	for position_name: String in Conventions.wheel_positions():
		var wheel: WheelVisual = WheelVisual.new(position_name, car.wheels.anchors[position_name])
		_wheels_root.add_child(wheel)
		_wheels[position_name] = wheel


## Applies the whole configuration (parts, finishes, paint, wheels, stance, glass).
func apply_config(new_config: CarConfig) -> void:
	config = new_config.copy()
	var resolution: CarConfig.Resolution = config.resolve(library)
	missing = resolution.missing
	var shown: CarConfig = resolution.config
	_apply_paints(shown)
	_trim_as_body = str(shown.paint.get(MaterialLibrary.TRIM, "")) == "body_color"
	_apply_materials(_model, "")
	for slot: String in _slots_in_use(shown):
		_show_slot(slot, str(shown.parts.get(slot, "")))
	_refresh_hidden_by_rules()
	for slot: String in shown.part_finish:
		_apply_slot_finish(slot)
	_apply_wheels(shown.wheel_front, shown.wheel_rear)
	set_ride_height(shown.ride_height_mm)
	materials.set_glass(Color.html(shown.glass_tint), shown.glass_darkness)
	materials.set_lights(_headlights, _brake)
	rebuilt.emit()


## Puts [param part_id] in [param slot] ("" = the car's stock part).
func set_part(slot: String, part_id: String) -> void:
	if part_id.is_empty():
		config.parts.erase(slot)
	else:
		config.parts[slot] = part_id
	var shown_id: String = part_id if library.get_part(part_id) != null else ""
	_show_slot(slot, shown_id)
	_refresh_hidden_by_rules()
	_apply_slot_finish(slot)


## `paint`, `carbon` or `black` for the painted surfaces of the part in [param slot].
func set_part_finish(slot: String, finish: String) -> void:
	if finish.is_empty() or finish == FINISH_PAINT:
		config.part_finish.erase(slot)
	else:
		config.part_finish[slot] = finish
	_apply_slot_finish(slot)


## Paint of a zone (`paint_body`, `paint_secondary`, `rim`, `rim_accent`, `caliper`).
func set_paint(zone: String, paint: PaintSpec) -> void:
	if zone.begins_with("rim") or zone == "caliper":
		config.wheel_paint[zone] = paint
	else:
		config.paint[zone] = paint
	materials.set_paint(zone, paint)


func set_wheels(front: CarConfig.WheelSetting, rear: CarConfig.WheelSetting) -> void:
	config = config.with_wheels(CarConfig.AXLE_FRONT, front).with_wheels(CarConfig.AXLE_REAR, rear)
	var shown: CarConfig = config.resolve(library).config
	_apply_wheels(shown.wheel_front, shown.wheel_rear)


## Lowers (negative) or raises the body relative to the wheels.
func set_ride_height(mm: float) -> void:
	if config != null:
		config.ride_height_mm = mm
	_body.position = Vector3(0.0, mm * MM if body_follows_ride_height else 0.0, 0.0)


## Ride height in meters (the physics of Etapa 04 reads this).
func get_ride_height_m() -> float:
	return _body.position.y


## [param brake] 0..1. Reverse lamps have no material yet (stored for later stages).
func set_lights(headlights: bool, brake: float, reverse: bool) -> void:
	_headlights = headlights
	_brake = brake
	_reverse = reverse
	materials.set_lights(headlights, brake)


func is_reverse_on() -> bool:
	return _reverse


## Wheel position (`FL`...) -> hub center in car space (used by the physics).
func get_wheel_anchors() -> Dictionary:
	var anchors: Dictionary = {}
	for position_name: String in _wheels:
		anchors[position_name] = Transform3D(Basis.IDENTITY, car.wheels.anchors[position_name])
	return anchors


func get_wheel(position_name: String) -> WheelVisual:
	return _wheels.get(position_name)


func get_socket(socket_name: String) -> Node3D:
	return _scan.sockets.get(socket_name)


## The node of a car-specific part (`bumper_front`, `kit01`), or null.
func get_part_node(slot: String, variant: String) -> Node3D:
	return _scan.get_part(slot, variant)


## The universal part attached to [param slot], or null.
func get_universal_part(slot: String) -> Node3D:
	return _universal.get(slot)


func get_scan() -> ConventionScanner.ScanResult:
	return _scan


## Bounding box of everything visible, in this node's space.
func get_aabb_car_space() -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for mesh: MeshInstance3D in _meshes_under(self):
		if mesh.mesh == null or not mesh.is_visible_in_tree() and mesh.is_inside_tree():
			continue
		if not _visible_up_to_self(mesh):
			continue
		var box: AABB = _transform_to_self(mesh) * mesh.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


# --- Parts -----------------------------------------------------------------------


## Slots to (re)build: every slot with car variants plus every slot in the config.
func _slots_in_use(shown: CarConfig) -> PackedStringArray:
	var slots: PackedStringArray = []
	for slot: String in _scan.parts:
		slots.append(slot)
	for slot: String in shown.parts:
		if not slots.has(slot):
			slots.append(slot)
	for slot: String in _universal:
		if not slots.has(slot):
			slots.append(slot)
	return slots


## Shows the right variant of [param slot] ([param part_id] "" = stock).
func _show_slot(slot: String, part_id: String) -> void:
	_remove_universal(slot)
	var part: PartDef = library.get_part(part_id) if not part_id.is_empty() else null
	var variant: String = CarDef.STOCK_VARIANT
	if part != null and not part.is_universal() and part.car_id == car.id:
		variant = part.variant
	elif part != null and part.is_universal():
		variant = ""
		_attach_universal(slot, part)
	var variants: Dictionary = _scan.parts.get(slot, {})
	for variant_name: String in variants:
		(variants[variant_name] as Node3D).visible = variant_name == variant


func _attach_universal(slot: String, part: PartDef) -> void:
	var socket: Node3D = get_socket(part.fit_socket) if not part.fit_socket.is_empty() else null
	var model: Node3D = ModelLoader.load_model(part.model_path)
	if model == null:
		issues.append("modelo da peça não encontrado: %s" % part.model_path)
		return
	model.name = "Universal_" + slot
	var parent: Node3D = socket if socket != null else _body
	parent.add_child(model)
	var socket_width: float = float(car.sockets.get(part.fit_socket, {}).get("width_m", 0.0))
	if socket_width > 0.0 and part.reference_width_m > 0.0:
		var stretch: float = clampf(
			socket_width / part.reference_width_m, part.scale_x_min, part.scale_x_max
		)
		model.scale = Vector3(stretch, 1.0, 1.0)
	_universal[slot] = model


func _remove_universal(slot: String) -> void:
	if not _universal.has(slot):
		return
	var old: Node3D = _universal[slot]
	_universal.erase(slot)
	old.get_parent().remove_child(old)
	old.queue_free()


## Hides car slots listed in `rules.hides` of the installed universal parts.
func _refresh_hidden_by_rules() -> void:
	var hidden: Dictionary = {}
	for slot: String in _universal:
		var part: PartDef = library.get_part(str(config.parts.get(slot, "")))
		if part != null:
			for hidden_slot: String in part.hides:
				hidden[hidden_slot] = true
	for slot: String in _scan.parts:
		if not hidden.has(slot) or _universal.has(slot):
			continue
		for node: Node3D in (_scan.parts[slot] as Dictionary).values():
			node.visible = false


# --- Materials --------------------------------------------------------------------


func _apply_paints(shown: CarConfig) -> void:
	for zone: String in ["paint_body", "paint_secondary"]:
		materials.set_paint(
			zone, _paint_or_default(shown.paint.get(zone), car.paint_default.get(zone), zone)
		)
	var wheel: WheelDef = library.get_wheel(shown.wheel_front.wheel_id)
	for zone: String in ["rim", "rim_accent"]:
		var fallback: Variant = wheel.default_paint.get(zone) if wheel != null else null
		materials.set_paint(zone, _paint_or_default(shown.wheel_paint.get(zone), fallback, zone))
	if not shown.caliper_color.is_empty():
		var caliper: PaintSpec = PaintSpec.new()
		caliper.color = shown.caliper_color
		materials.set_paint("caliper", caliper)


func _paint_or_default(value: Variant, fallback: Variant, zone: String) -> PaintSpec:
	if value is PaintSpec:
		return value
	if fallback is PaintSpec:
		return fallback
	var spec: PaintSpec = PaintSpec.new()
	spec.color = CarMaterialSet.DEFAULT_PAINTS.get(zone, "#FFFFFF")
	return spec


## Assigns the game's material to every surface under [param root], by name.
func _apply_materials(root: Node, finish: String) -> void:
	for mesh_node: MeshInstance3D in _meshes_under(root):
		var mesh: Mesh = mesh_node.mesh
		if mesh == null:
			continue
		for surface: int in mesh.get_surface_count():
			var original: Material = mesh.surface_get_material(surface)
			var material_name: String = original.resource_name if original != null else ""
			var material: Material = materials.material_for(material_name, finish, _trim_as_body)
			mesh_node.set_surface_override_material(surface, material)


func _apply_slot_finish(slot: String) -> void:
	var finish: String = str(config.part_finish.get(slot, ""))
	for node: Node3D in (_scan.parts.get(slot, {}) as Dictionary).values():
		_apply_materials(node, finish)
	if _universal.has(slot):
		_apply_materials(_universal[slot], finish)


# --- Wheels -----------------------------------------------------------------------


func _apply_wheels(front: CarConfig.WheelSetting, rear: CarConfig.WheelSetting) -> void:
	for position_name: String in _wheels:
		var wheel: WheelVisual = _wheels[position_name]
		var setting: CarConfig.WheelSetting = front if position_name.begins_with("F") else rear
		wheel.set_rim(_rim_instance(setting.wheel_id))
		wheel.apply_setting(setting, car.wheels.tire_outer_diameter_m)
		_apply_materials(wheel, "")


## A new rim instance (meshes shared): library rim, or the car's own `rim-stock`.
func _rim_instance(wheel_id: String) -> Node3D:
	var wheel: WheelDef = library.get_wheel(wheel_id) if not wheel_id.is_empty() else null
	if wheel != null:
		var model: Node3D = ModelLoader.load_model(wheel.model_path)
		if model != null:
			return model
		issues.append("modelo do aro não encontrado: %s" % wheel.model_path)
	if _scan.rim == null:
		return null
	var stock: Node3D = _scan.rim.duplicate() as Node3D
	return stock


# --- Helpers ----------------------------------------------------------------------


func _check_model_matches_car() -> void:
	for entry: CarDef.PartEntry in car.parts:
		if not _scan.has_part(entry.slot, entry.variant):
			issues.append("peça do car.json ausente no modelo: %s" % entry.node_name())
	for socket: String in car.sockets:
		if not _scan.sockets.has(socket):
			issues.append("soquete do car.json ausente no modelo: %s" % socket)


static func _meshes_under(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		result.append(root)
	for child: Node in root.get_children():
		result.append_array(_meshes_under(child))
	return result


func _visible_up_to_self(node: Node) -> bool:
	var current: Node = node
	while current != null and current != self:
		if current is Node3D and not (current as Node3D).visible:
			return false
		current = current.get_parent()
	return true


func _transform_to_self(node: Node3D) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != self:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
