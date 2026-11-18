class_name WheelVisual
extends Node3D
## One wheel: tire + rim + brake disc (they spin with [member hub]) and caliper
## (does not spin). Placed at the car's wheel anchor; offset and camber are
## VISUAL only (the physics of Etapa 04 uses the anchors).
##
## Rims are modeled at 18" x 8" facing +X; they are scaled to the chosen size and,
## on the right side, turned 180° around the vertical axis (never mirrored with a
## negative scale).

const MODEL_RIM_IN: float = 18.0
const MODEL_WIDTH_IN: float = 8.0
const MM: float = 0.001

var position_name: String = ""
var is_left: bool = true
var anchor: Vector3 = Vector3.ZERO
## Spins around X (physics/animation). Holds the tire, the rim and the disc.
var hub: Node3D = null
var tire: MeshInstance3D = null
var disc: MeshInstance3D = null
var caliper: MeshInstance3D = null
var rim_holder: Node3D = null

var _rim: Node3D = null
var _base_position: Vector3 = Vector3.ZERO
var _camber_rad: float = 0.0


func _init(wheel_position: String = "FL", anchor_position: Vector3 = Vector3.ZERO) -> void:
	position_name = wheel_position
	anchor = anchor_position
	is_left = anchor_position.x >= 0.0
	name = "Wheel" + wheel_position
	hub = Node3D.new()
	hub.name = "Hub"
	add_child(hub)
	tire = MeshInstance3D.new()
	tire.name = "Tire"
	hub.add_child(tire)
	rim_holder = Node3D.new()
	rim_holder.name = "Rim"
	hub.add_child(rim_holder)
	disc = MeshInstance3D.new()
	disc.name = "BrakeDisc"
	hub.add_child(disc)
	caliper = MeshInstance3D.new()
	caliper.name = "Caliper"
	add_child(caliper)
	position = anchor


## Replaces the rim model (a fresh instance; its meshes are shared resources).
func set_rim(rim: Node3D) -> void:
	if _rim != null:
		rim_holder.remove_child(_rim)
		_rim.queue_free()
	_rim = rim
	if rim != null:
		rim.transform = Transform3D.IDENTITY
		rim.visible = true
		rim_holder.add_child(rim)


func get_rim() -> Node3D:
	return _rim


## Size, offset and camber. [param tire_diameter_m] stays fixed for the car.
func apply_setting(setting: CarConfig.WheelSetting, tire_diameter_m: float) -> void:
	tire.mesh = TireMeshBuilder.build(tire_diameter_m, setting.rim_in, setting.width_in)
	disc.mesh = TireMeshBuilder.disc(setting.rim_in)
	caliper.mesh = TireMeshBuilder.caliper(setting.rim_in)
	var outward: float = 1.0 if is_left else -1.0
	var width_m: float = setting.width_in * TireMeshBuilder.INCH
	# Brakes sit on the inner side of the rim.
	disc.position = Vector3(-outward * width_m * 0.18, 0.0, 0.0)
	caliper.position = Vector3(-outward * width_m * 0.18, 0.0, 0.0)
	var size_scale: float = setting.rim_in / MODEL_RIM_IN
	rim_holder.scale = Vector3(setting.width_in / MODEL_WIDTH_IN, size_scale, size_scale)
	rim_holder.rotation = Vector3(0.0, 0.0 if is_left else PI, 0.0)
	# Positive offset pushes the wheel outward ("poke"); negative tucks it in.
	_base_position = anchor + Vector3(outward * setting.offset_mm * MM, 0.0, 0.0)
	# Negative camber leans the top of the wheel toward the car.
	_camber_rad = deg_to_rad(-setting.camber_deg) * outward
	set_dynamics(0.0, 0.0, hub.rotation.x)


## Placed by the physics: [param suspension_offset] (m, + = compressed, wheel
## moves up), [param steer] (rad around the vertical, + = left), [param spin]
## (rad around the axle).
func set_dynamics(suspension_offset: float, steer: float, spin: float) -> void:
	position = _base_position + Vector3(0.0, suspension_offset, 0.0)
	transform.basis = Basis(Vector3.UP, steer) * Basis(Vector3.BACK, _camber_rad)
	hub.rotation = Vector3(spin, 0.0, 0.0)
