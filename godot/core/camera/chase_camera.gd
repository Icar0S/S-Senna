class_name ChaseCamera
extends Camera3D
## One player's driving camera (ADR 011: one per player, never global).
## Modes: far, near, hood, bumper. Follows ITS [member vehicle] smoothly, widens
## the field of view with speed and nitro, looks back on request and avoids
## going through walls.

enum Mode { FAR, NEAR, HOOD, BUMPER }

const MODE_KEYS: PackedStringArray = ["far", "near", "hood", "bumper"]
## Chase modes: [distance, height, look-ahead].
const CHASE: Dictionary = {Mode.FAR: [6.6, 2.0, 3.0], Mode.NEAR: [4.8, 1.5, 2.5]}
const FOLLOW_SHARPNESS: float = 7.0
const FOV_SPEED_BONUS: float = 16.0
const FOV_NITRO_BONUS: float = 8.0
const FOV_TOP_SPEED_KMH: float = 250.0
const WALL_MARGIN: float = 0.3
const HOOD_FALLBACK: Vector3 = Vector3(0.0, 1.05, 0.6)
const BUMPER_FALLBACK: Vector3 = Vector3(0.0, 0.55, 2.2)

var vehicle: Vehicle = null:
	set = set_vehicle
var mode: Mode = Mode.FAR
var base_fov: float = 70.0

var _smoothed_position: Vector3 = Vector3.ZERO
var _initialized: bool = false


func _ready() -> void:
	# Moved every frame from the interpolated vehicle transform.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	base_fov = Settings.data.fov


func set_vehicle(new_vehicle: Vehicle) -> void:
	if vehicle != null and vehicle.camera_next_requested.is_connected(next_mode):
		vehicle.camera_next_requested.disconnect(next_mode)
	vehicle = new_vehicle
	_initialized = false
	if vehicle != null:
		vehicle.camera_next_requested.connect(next_mode)


func next_mode() -> void:
	mode = ((mode + 1) % Mode.size()) as Mode


func mode_name() -> String:
	return MODE_KEYS[mode]


func _process(delta: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return
	var car_transform: Transform3D = vehicle.get_global_transform_interpolated()
	var looking_back: bool = vehicle.input.look_back
	if mode == Mode.HOOD or mode == Mode.BUMPER:
		_mounted(car_transform, looking_back)
	else:
		_chase(car_transform, looking_back, delta)
	var speed_ratio: float = clampf(absf(vehicle.get_speed_kmh()) / FOV_TOP_SPEED_KMH, 0.0, 1.0)
	var target_fov: float = base_fov + FOV_SPEED_BONUS * speed_ratio * speed_ratio
	if vehicle.nitro_active:
		target_fov += FOV_NITRO_BONUS
	fov = lerpf(fov, target_fov, 1.0 - exp(-4.0 * delta))


func _chase(car_transform: Transform3D, looking_back: bool, delta: float) -> void:
	var settings: Array = CHASE[mode]
	var forward: Vector3 = car_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.BACK
	var direction: float = -1.0 if looking_back else 1.0
	var target: Vector3 = car_transform.origin + Vector3.UP * 0.9
	var desired: Vector3 = (
		target - forward * direction * float(settings[0]) + Vector3.UP * float(settings[1])
	)
	if not _initialized or looking_back:
		_smoothed_position = desired
		_initialized = true
	else:
		_smoothed_position = _smoothed_position.lerp(desired, 1.0 - exp(-FOLLOW_SHARPNESS * delta))
	global_position = _avoid_walls(target, _smoothed_position)
	look_at(target + forward * direction * float(settings[2]), Vector3.UP)


## Hood/bumper: fixed to the car (sockets `cam_hood` / `cam_bumper` when the car has them).
func _mounted(car_transform: Transform3D, looking_back: bool) -> void:
	var socket_name: String = "cam_hood" if mode == Mode.HOOD else "cam_bumper"
	var offset: Vector3 = HOOD_FALLBACK if mode == Mode.HOOD else BUMPER_FALLBACK
	var socket: Node3D = vehicle.visual.get_socket(socket_name) if vehicle.visual != null else null
	if socket != null:
		offset = socket.position
	var facing: Basis = car_transform.basis * Basis(Vector3.UP, 0.0 if looking_back else PI)
	global_transform = Transform3D(facing, car_transform * offset)
	_initialized = false


func _avoid_walls(target: Vector3, desired: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(target, desired)
	query.exclude = [vehicle.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return desired
	var hit_position: Vector3 = hit["position"]
	return hit_position + (target - hit_position).normalized() * WALL_MARGIN
