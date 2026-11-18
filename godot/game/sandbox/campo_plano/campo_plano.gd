class_name CampoPlano
extends Node3D
## Flat test field (Etapa 04): big grid floor, walls, ramps, speed bumps, a cone
## slalom, a banked curve, a 400 m straight marked every 100 m and a skidpad.
## Spawns the player's car with a chase camera, HUD, telemetry (F1) and tuning (F2).
##
## Open: `tools/scripts/jogar.bat res://game/sandbox/campo_plano/campo_plano.tscn`
## Options (after `--`): `--campo-car=<car id>`, `--campo-no-ui` (screenshots).
## The course is built in code so it is easy to tweak.

const DEFAULT_CAR: String = "car:base/prototipo"
const PLAYER: int = 0
const FIELD_SIZE: float = 1200.0
const WALL_HEIGHT: float = 1.6
const SPAWN: Vector3 = Vector3(0.0, 0.3, 0.0)
const STRAIGHT_START: Vector3 = Vector3(-150.0, 0.0, -460.0)
const STRAIGHT_LENGTH: float = 400.0
const SKIDPAD_CENTER: Vector3 = Vector3(160.0, 0.0, 160.0)
const SKIDPAD_RADIUS: float = 30.0
const BANK_CENTER: Vector3 = Vector3(-230.0, 0.0, 230.0)
const BANK_RADIUS: float = 70.0
const BANK_DEG: float = 20.0
const CONE_MASS: float = 4.0
## Test drives get some nitro (stock cars have none until the nitrous upgrade).
const TEST_NITRO_LEVEL: int = 2
const ARG_PREFIX: String = "--campo-"

var vehicle: Vehicle = null
var camera: ChaseCamera = null
var hud: PlayerHud = null

var _materials: Dictionary = {}


func _ready() -> void:
	_build_course()
	_spawn_player(_arg("car", DEFAULT_CAR))


func _arg(option: String, default_value: String) -> String:
	return CmdlineArgs.get_value(OS.get_cmdline_user_args(), ARG_PREFIX + option, default_value)


# --- Player ----------------------------------------------------------------------


func _spawn_player(car_id: String) -> void:
	var car: CarDef = ContentDB.get_car(car_id)
	if car == null:
		Log.error("Carro não encontrado: %s" % car_id, "CampoPlano")
		return
	var config: CarConfig = CarConfig.create_default(car, "campo")
	config.performance["nitrous"] = TEST_NITRO_LEVEL
	vehicle = Vehicle.create(car, config, ProfileData.default_assists())
	vehicle.driver = PlayerDriver.new(PLAYER)
	add_child(vehicle)
	vehicle.global_position = SPAWN
	camera = ChaseCamera.new()
	camera.name = "ChaseCamera"
	add_child(camera)
	camera.vehicle = vehicle
	camera.make_current()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = PlayerHud.new()
	hud.vehicle = vehicle
	layer.add_child(hud)
	var telemetry: TelemetryOverlay = TelemetryOverlay.new()
	telemetry.vehicle = vehicle
	layer.add_child(telemetry)
	var tuning: TuningPanel = TuningPanel.new()
	layer.add_child(tuning)
	tuning.vehicle = vehicle
	var help: Label = Label.new()
	help.text = tr("CAMPO_HELP")
	help.add_theme_font_size_override("font_size", 16)
	help.position = Vector2(16, 12)
	layer.add_child(help)
	if CmdlineArgs.has_flag(OS.get_cmdline_user_args(), ARG_PREFIX + "no-ui"):
		layer.visible = false


# --- Course ----------------------------------------------------------------------


func _build_course() -> void:
	var floor_material: ShaderMaterial = ShaderMaterial.new()
	floor_material.shader = preload("res://game/sandbox/campo_plano/grid_floor.gdshader")
	_static_box(
		"Floor",
		Vector3(FIELD_SIZE, 1.0, FIELD_SIZE),
		Transform3D(Basis(), Vector3(0, -0.5, 0)),
		floor_material
	)
	var half: float = FIELD_SIZE / 2.0
	for side: Array in [
		[Vector3(0, 0, half), 0.0],
		[Vector3(0, 0, -half), 0.0],
		[Vector3(half, 0, 0), 90.0],
		[Vector3(-half, 0, 0), 90.0]
	]:
		var basis: Basis = Basis(Vector3.UP, deg_to_rad(float(side[1])))
		var center: Vector3 = (side[0] as Vector3) + Vector3(0, WALL_HEIGHT / 2.0, 0)
		_static_box(
			"Wall",
			Vector3(FIELD_SIZE, WALL_HEIGHT, 1.0),
			Transform3D(basis, center),
			_color("#C9CDD2")
		)
	_build_ramps()
	_build_bumps()
	_build_slalom()
	_build_banked_curve()
	_build_straight()
	_build_skidpad()
	_add_reset_point(SPAWN, 0.0)


func _build_ramps() -> void:
	var angles: Array[float] = [6.0, 10.0, 15.0]
	for i: int in angles.size():
		var angle: float = deg_to_rad(angles[i])
		var length: float = 14.0
		var x: float = 40.0 + i * 14.0
		var basis: Basis = Basis(Vector3.RIGHT, -angle)
		var lift: float = sin(angle) * length / 2.0
		var center: Vector3 = Vector3(x, lift - 0.25, 60.0)
		_static_box(
			"Ramp", Vector3(8.0, 0.5, length), Transform3D(basis, center), _color("#E3B23C")
		)
	_add_reset_point(Vector3(54.0, 0.3, 30.0), 0.0)


func _build_bumps() -> void:
	for i: int in 8:
		var center: Vector3 = Vector3(-40.0, 0.06, 20.0 + i * 9.0)
		_static_box(
			"Bump", Vector3(10.0, 0.12, 0.7), Transform3D(Basis(), center), _color("#F2F2F2")
		)


func _build_slalom() -> void:
	for i: int in 14:
		_add_cone(Vector3(90.0, 0.0, -140.0 + i * 18.0))
	_add_reset_point(Vector3(90.0, 0.3, -170.0), 0.0)


func _build_banked_curve() -> void:
	var segments: int = 28
	var width: float = 16.0
	for i: int in segments:
		var angle: float = TAU * i / segments
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var tangent: Vector3 = Vector3(-sin(angle), 0.0, cos(angle))
		var bank: float = deg_to_rad(BANK_DEG)
		var center: Vector3 = BANK_CENTER + direction * BANK_RADIUS
		center.y = sin(bank) * width / 2.0 - 0.3
		# Outer edge higher: tilt around the tangent.
		var basis: Basis = Basis(tangent.cross(Vector3.UP), Vector3.UP, tangent).orthonormalized()
		basis = Basis(tangent, -bank) * basis
		var segment_length: float = TAU * BANK_RADIUS / segments * 1.08
		_static_box(
			"Bank",
			Vector3(width, 0.6, segment_length),
			Transform3D(basis, center),
			_color("#7A8794")
		)
	_add_reset_point(BANK_CENTER + Vector3(BANK_RADIUS, 1.0, 0.0), 0.0)


func _build_straight() -> void:
	for meters: int in range(0, int(STRAIGHT_LENGTH) + 1, 100):
		var position: Vector3 = STRAIGHT_START + Vector3(0.0, 0.01, meters)
		_painted_line(position, Vector3(14.0, 0.02, 0.5))
		var label: Label3D = Label3D.new()
		label.text = tr("CAMPO_MARKER") % meters
		label.font_size = 160
		label.pixel_size = 0.02
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = position + Vector3(9.0, 2.5, 0.0)
		add_child(label)
	_add_reset_point(STRAIGHT_START + Vector3(0.0, 0.3, -8.0), 0.0)


func _build_skidpad() -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = SKIDPAD_RADIUS - 0.25
	torus.outer_radius = SKIDPAD_RADIUS + 0.25
	torus.rings = 96
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.02, 1.0)
	ring.position = SKIDPAD_CENTER + Vector3(0.0, 0.01, 0.0)
	ring.material_override = _color("#F2F2F2")
	add_child(ring)
	_add_reset_point(SKIDPAD_CENTER + Vector3(SKIDPAD_RADIUS, 0.3, 0.0), 0.0)


# --- Helpers ---------------------------------------------------------------------


func _static_box(node_name: String, size: Vector3, xform: Transform3D, material: Material) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.transform = xform
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)


func _painted_line(position: Vector3, size: Vector3) -> void:
	var line: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	line.mesh = box
	line.position = position
	line.material_override = _color("#F2F2F2")
	add_child(line)


func _add_cone(position: Vector3) -> void:
	var cone: RigidBody3D = RigidBody3D.new()
	cone.name = "Cone"
	cone.mass = CONE_MASS
	cone.position = position + Vector3(0.0, 0.35, 0.0)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = 0.22
	cylinder.height = 0.7
	shape.shape = cylinder
	cone.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var cone_mesh: CylinderMesh = CylinderMesh.new()
	cone_mesh.top_radius = 0.04
	cone_mesh.bottom_radius = 0.24
	cone_mesh.height = 0.7
	mesh.mesh = cone_mesh
	mesh.material_override = _color("#FF6A13")
	cone.add_child(mesh)
	add_child(cone)


func _add_reset_point(position: Vector3, yaw_deg: float) -> void:
	var marker: Marker3D = Marker3D.new()
	marker.position = position
	marker.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	marker.add_to_group(Vehicle.RESET_GROUP)
	add_child(marker)


func _color(hex: String) -> StandardMaterial3D:
	if not _materials.has(hex):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(hex)
		material.roughness = 0.8
		_materials[hex] = material
	return _materials[hex]
