class_name Vehicle
extends RigidBody3D
## An arcade car (ADR 005): a RigidBody3D (Jolt) plus 4 raycast "wheels" that apply
## suspension, traction and grip forces. Car space: +Z front, +X left, +Y up.
##
## The car never knows who drives it: a [VehicleDriver] fills [member input].
## All the "feel" numbers come from [VehicleParams] (made by [HandlingModel]).
## Nothing here is global: cameras and HUDs receive the Vehicle they show.

signal reset_done
## The driver asked for the next camera (cameras listen to THEIR vehicle only).
signal camera_next_requested

const WHEEL_POSITIONS: PackedStringArray = ["FL", "FR", "RL", "RR"]
## Below this speed (m/s) with no throttle, the car holds still (auto hold).
const HOLD_SPEED: float = 0.5
## Speed (m/s) where lateral grip switches from "cancel sliding" to the slip model.
const LOW_SPEED_BLEND: float = 4.0
## How far below the rest length a wheel can drop (m).
const MAX_DROOP: float = 0.1
const HANDBRAKE_DECEL: float = 0.7
const AUTO_RIGHT_DELAY: float = 0.35
const RESET_LIFT: float = 0.6
const RESET_GROUP: String = "reset_points"
const BODY_FRICTION: float = 0.25
## Ground clearance of the generated collision box (m above the ground at rest).
const COLLISION_BOTTOM: float = 0.3

var car: CarDef = null
var config: CarConfig = null
var params: VehicleParams = null
var visual: CarVisual = null
var drivetrain: Drivetrain = null
var driver: VehicleDriver = null
var input: VehicleInput = VehicleInput.new()
var wheels: Array[WheelState] = []
## 0..1 of the nitro capacity.
var nitro_amount: float = 1.0
var nitro_active: bool = false
## Updated every physics step (F1 overlay, HUD, audio).
var telemetry: Dictionary = {}

var _steer: float = 0.0
var _upside_down_time: float = 0.0
var _ride_m: float = 0.0
var _assists: Dictionary = {}
var _library: ContentLibrary = null


## State of one wheel (raycast suspension + tire).
class WheelState:
	extends RefCounted
	var position_name: String = ""
	var is_front: bool = true
	var is_left: bool = true
	## Hub center at rest and suspension mount, car space.
	var anchor: Vector3 = Vector3.ZERO
	var mount: Vector3 = Vector3.ZERO
	var contact: bool = false
	var contact_point: Vector3 = Vector3.ZERO
	var contact_normal: Vector3 = Vector3.UP
	var spring_length: float = 0.0
	var previous_length: float = 0.0
	## Normal force on the ground (N).
	var load: float = 0.0
	var steer: float = 0.0
	var spin: float = 0.0
	var slip_angle: float = 0.0
	var slip_ratio: float = 0.0
	var grip_usage: float = 0.0
	var locked: bool = false


## A ready-to-drive car: physics parameters from the content, the player's
## config and assists, plus `tuning_overrides` of the car.
static func create(
	car_def: CarDef,
	car_config: CarConfig = null,
	assists: Dictionary = {},
	library: ContentLibrary = null
) -> Vehicle:
	var content: ContentLibrary = library if library != null else ContentDB.get_library()
	var shown: CarConfig = (
		car_config if car_config != null else CarConfig.create_default(car_def, "drive")
	)
	var vehicle_params: VehicleParams = HandlingModel.compute(
		car_def,
		shown.performance,
		content.get_upgrades(),
		shown.tuning,
		assists,
		content.get_handling_globals()
	)
	vehicle_params.apply_overrides(car_def.tuning_overrides)
	var vehicle: Vehicle = Vehicle.new()
	vehicle._assists = assists
	vehicle.setup(car_def, shown, vehicle_params, content)
	return vehicle


## Recomputes the parameters with other global constants and per-car overrides
## (F2 panel), keeping the car, its config and the assists.
func recompute_params(globals: HandlingGlobals, overrides: Dictionary) -> void:
	var recomputed: VehicleParams = HandlingModel.compute(
		car, config.performance, _library.get_upgrades(), config.tuning, _assists, globals
	)
	recomputed.apply_overrides(overrides)
	apply_params(recomputed)


func setup(
	car_def: CarDef, car_config: CarConfig, vehicle_params: VehicleParams, library: ContentLibrary
) -> void:
	car = car_def
	config = car_config
	_library = library
	name = "Vehicle_" + car_def.id.get_file()
	_ride_m = car_config.ride_height_mm / 1000.0
	visual = CarAssembler.build(car_def, car_config, library)
	visual.body_follows_ride_height = false
	visual.set_ride_height(car_config.ride_height_mm)
	add_child(visual)
	drivetrain = Drivetrain.new(vehicle_params)
	apply_params(vehicle_params)
	_build_collision()
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = BODY_FRICTION
	physics_material_override.bounce = 0.05
	continuous_cd = true
	can_sleep = false
	# Air drag is computed by the HandlingModel: the engine's default damping would
	# brake the car on top of it (0.1 x mass x speed — kills the top speed).
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.3
	add_child(EngineAudio.new(self))


## Replaces the physics parameters (F2 panel, upgrades) without rebuilding the car.
func apply_params(vehicle_params: VehicleParams) -> void:
	params = vehicle_params
	mass = params.mass_kg
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = params.center_of_mass + Vector3(0.0, -_ride_m * 0.5, 0.0)
	inertia = params.inertia
	drivetrain.params = params
	wheels.clear()
	for position_name: String in WHEEL_POSITIONS:
		var wheel: WheelState = WheelState.new()
		wheel.position_name = position_name
		wheel.is_front = position_name.begins_with("F")
		wheel.is_left = position_name.ends_with("L")
		# Lower body (negative ride height) = wheels sit higher in the body.
		wheel.anchor = (params.wheel_anchors[position_name] as Vector3) - Vector3(0.0, _ride_m, 0.0)
		wheel.mount = wheel.anchor + Vector3(0.0, params.suspension_travel, 0.0)
		wheel.spring_length = params.suspension_travel
		wheel.previous_length = wheel.spring_length
		wheels.append(wheel)


func _physics_process(delta: float) -> void:
	if params == null:
		return
	input.shift_up = false
	input.shift_down = false
	input.camera_next = false
	input.reset = false
	if driver != null:
		driver.drive(input, delta, self)
	if input.camera_next:
		camera_next_requested.emit()
	if input.reset:
		reset_to_safe_position()
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var basis: Basis = global_transform.basis
	var forward_speed: float = linear_velocity.dot(basis.z)
	var drive_torque: float = drivetrain.update(
		delta, forward_speed, input.throttle, input.brake, input
	)
	var service_brake: float = input.throttle if drivetrain.is_reverse() else input.brake
	_update_steering(delta, forward_speed)
	var contacts: int = 0
	for wheel: WheelState in wheels:
		_update_suspension(wheel, space, delta)
		if wheel.contact:
			contacts += 1
	_apply_anti_roll()
	for wheel: WheelState in wheels:
		if wheel.contact:
			_apply_suspension_force(wheel)
			_apply_tire_force(wheel, drive_torque, service_brake, delta)
	_apply_body_forces(delta, forward_speed, contacts)
	_apply_assists(delta, forward_speed, contacts)
	_update_visual_wheels(delta)
	_update_telemetry(forward_speed, contacts)


# --- Public info -----------------------------------------------------------------


func get_speed_kmh() -> float:
	return linear_velocity.dot(global_transform.basis.z) * 3.6


func get_forward() -> Vector3:
	return global_transform.basis.z


func get_gear() -> int:
	return drivetrain.gear


func get_rpm() -> float:
	return drivetrain.rpm


## Angle between where the car points and where it goes (radians; + = going left).
func get_drift_angle() -> float:
	var planar: Vector3 = (
		linear_velocity - global_transform.basis.y * linear_velocity.dot(global_transform.basis.y)
	)
	if planar.length() < 3.0:
		return 0.0
	return atan2(planar.dot(global_transform.basis.x), planar.dot(global_transform.basis.z))


func is_upright() -> bool:
	return global_transform.basis.y.dot(Vector3.UP) > 0.7


func wheels_on_ground() -> int:
	var count: int = 0
	for wheel: WheelState in wheels:
		if wheel.contact:
			count += 1
	return count


## Puts the car back on its wheels at the nearest reset point (or where it is,
## lifted a little), facing its current direction, stopped.
func reset_to_safe_position() -> void:
	var target: Transform3D = global_transform
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(RESET_GROUP):
		if node is Node3D:
			var distance: float = (node as Node3D).global_position.distance_to(global_position)
			if distance < best_distance:
				best_distance = distance
				target = (node as Node3D).global_transform
	if best_distance == INF:
		var heading: Vector3 = global_transform.basis.z
		heading.y = 0.0
		if heading.length() < 0.1:
			heading = Vector3.FORWARD
		target = Transform3D(Basis.looking_at(-heading.normalized(), Vector3.UP), global_position)
	target.origin += Vector3(0.0, RESET_LIFT, 0.0)
	global_transform = target
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	drivetrain.shift_to(1)
	reset_physics_interpolation()
	reset_done.emit()


# --- Physics steps ---------------------------------------------------------------


func _update_steering(delta: float, forward_speed: float) -> void:
	var speed: float = linear_velocity.length()
	var max_steer: float = params.max_steer_rad
	if params.progressive_steering:
		max_steer /= 1.0 + speed / params.steer_falloff_ms
	var target: float = -input.steer * max_steer
	var drift: float = get_drift_angle()
	if params.countersteer > 0.0 and forward_speed > 4.0 and absf(drift) > 0.08:
		target += clampf(drift, -params.max_steer_rad, params.max_steer_rad) * params.countersteer
	target = clampf(target, -params.max_steer_rad, params.max_steer_rad)
	_steer = move_toward(_steer, target, params.steer_speed * delta)


func _update_suspension(wheel: WheelState, space: PhysicsDirectSpaceState3D, delta: float) -> void:
	var rest: float = params.spring_rest_front if wheel.is_front else params.spring_rest_rear
	var max_length: float = rest + MAX_DROOP
	var from: Vector3 = to_global(wheel.mount)
	var down: Vector3 = -global_transform.basis.y
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from + down * (max_length + params.wheel_radius)
	)
	query.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	wheel.previous_length = wheel.spring_length
	if hit.is_empty():
		wheel.contact = false
		wheel.load = 0.0
		wheel.spring_length = max_length
		return
	var hit_point: Vector3 = hit["position"]
	wheel.contact = true
	wheel.contact_point = hit_point
	wheel.contact_normal = hit["normal"]
	wheel.spring_length = clampf(from.distance_to(hit_point) - params.wheel_radius, 0.0, max_length)
	var stiffness: float = params.spring_k_front if wheel.is_front else params.spring_k_rear
	var damper: float = params.damper_front if wheel.is_front else params.damper_rear
	var compression_speed: float = (wheel.previous_length - wheel.spring_length) / delta
	var force: float = stiffness * (rest - wheel.spring_length) + damper * compression_speed
	# Bump stop when the spring is almost fully compressed.
	if wheel.spring_length < 0.02:
		force += stiffness * 4.0 * (0.02 - wheel.spring_length)
	wheel.load = maxf(force, 0.0)


func _apply_anti_roll() -> void:
	for axle: Array in [
		[wheels[0], wheels[1], params.antiroll_front], [wheels[2], wheels[3], params.antiroll_rear]
	]:
		var left: WheelState = axle[0]
		var right: WheelState = axle[1]
		if not left.contact and not right.contact:
			continue
		var difference: float = right.spring_length - left.spring_length
		var force: float = float(axle[2]) * difference
		if left.contact:
			left.load = maxf(left.load + force, 0.0)
		if right.contact:
			right.load = maxf(right.load - force, 0.0)


func _apply_suspension_force(wheel: WheelState) -> void:
	var up: Vector3 = global_transform.basis.y
	var point: Vector3 = wheel.contact_point + up * params.wheel_radius
	apply_force(up * wheel.load, point - global_position)


func _apply_tire_force(
	wheel: WheelState, drive_torque: float, service_brake: float, delta: float
) -> void:
	var basis: Basis = global_transform.basis
	var up: Vector3 = basis.y
	var normal: Vector3 = wheel.contact_normal
	wheel.steer = _steer if wheel.is_front else 0.0
	var wheel_forward: Vector3 = basis.z.rotated(up, wheel.steer)
	var forward: Vector3 = (wheel_forward - normal * wheel_forward.dot(normal)).normalized()
	var side: Vector3 = normal.cross(forward).normalized()
	var com: Vector3 = global_transform * center_of_mass
	var velocity: Vector3 = linear_velocity + angular_velocity.cross(wheel.contact_point - com)
	var v_long: float = velocity.dot(forward)
	var v_lat: float = velocity.dot(side)
	var quarter_mass: float = mass / 4.0
	var grip: float = params.tire_mu
	if not wheel.is_front:
		grip *= params.rear_grip_factor
		if input.handbrake:
			grip *= params.handbrake_grip_factor
	var limit: float = grip * wheel.load
	# Lateral: slip-angle model at speed, "cancel the slide" when almost stopped.
	wheel.slip_angle = atan2(v_lat, maxf(absf(v_long), 0.5))
	var slip_ratio_angle: float = wheel.slip_angle / params.peak_slip_rad
	var falloff: float = (
		1.0
		if absf(slip_ratio_angle) <= 1.0
		else lerpf(1.0, 0.85, clampf(absf(slip_ratio_angle) - 1.0, 0.0, 2.0) / 2.0)
	)
	var lateral_slip: float = -limit * clampf(slip_ratio_angle, -1.0, 1.0) * falloff
	var lateral_static: float = clampf(-v_lat * quarter_mass / delta * 0.5, -limit, limit)
	var lateral: float = lerpf(
		lateral_static, lateral_slip, clampf(velocity.length() / LOW_SPEED_BLEND, 0.0, 1.0)
	)
	# Longitudinal: drive, brakes, handbrake, rolling resistance.
	var drive_share: float = (
		params.front_drive_share if wheel.is_front else 1.0 - params.front_drive_share
	)
	var drive: float = (
		drive_torque * drive_share * 0.5 / params.wheel_radius * params.traction_factor
	)
	if params.traction_control and drive != 0.0:
		var room: float = sqrt(maxf(limit * limit - lateral * lateral, 0.0)) * 0.98
		drive = clampf(drive, -room, room)
	var bias: float = params.brake_bias_front if wheel.is_front else 1.0 - params.brake_bias_front
	var brake_demand: float = params.brake_force_n * bias * 0.5 * service_brake
	wheel.locked = false
	if input.handbrake and not wheel.is_front:
		brake_demand += mass * 9.8 * HANDBRAKE_DECEL * 0.5
		wheel.locked = true
	elif brake_demand > limit:
		if params.abs_enabled:
			brake_demand = limit * 0.95
		else:
			wheel.locked = true
	var stop_force: float = absf(v_long) * quarter_mass / delta
	var brake: float = -signf(v_long) * minf(brake_demand, stop_force)
	var rolling: float = -signf(v_long) * minf(params.rolling_coef * wheel.load, stop_force)
	var longitudinal: float = drive + brake + rolling
	if (
		input.throttle < 0.05
		and not drivetrain.is_reverse()
		and input.brake < 0.05
		and velocity.length() < HOLD_SPEED
	):
		longitudinal = clampf(-v_long * quarter_mass / delta * 0.5, -limit, limit)
	if wheel.locked:
		lateral *= 0.5
	var total: float = sqrt(longitudinal * longitudinal + lateral * lateral)
	wheel.slip_ratio = 0.0
	if total > limit and total > 0.0:
		var scale: float = limit / total
		longitudinal *= scale
		lateral *= scale
		wheel.slip_ratio = 1.0 - scale
	wheel.grip_usage = total / maxf(limit, 1.0)
	var force: Vector3 = forward * longitudinal + side * lateral
	var height_above: float = (com - wheel.contact_point).dot(up)
	var point: Vector3 = wheel.contact_point + up * height_above * params.tire_force_height
	apply_force(force, point - global_position)


func _apply_body_forces(delta: float, forward_speed: float, contacts: int) -> void:
	var up: Vector3 = global_transform.basis.y
	var speed: float = linear_velocity.length()
	if speed > 0.1:
		apply_central_force(-linear_velocity.normalized() * params.drag_coef * speed * speed)
	if contacts > 0:
		apply_central_force(-up * params.downforce_coef * forward_speed * forward_speed)
	nitro_active = (
		input.nitro and nitro_amount > 0.0 and params.nitro_capacity_s > 0.0 and contacts > 1
	)
	if nitro_active:
		apply_central_force(global_transform.basis.z * mass * params.nitro_accel)
		nitro_amount = maxf(nitro_amount - delta / params.nitro_capacity_s, 0.0)
	else:
		nitro_amount = minf(nitro_amount + params.nitro_refill_per_s * delta, 1.0)


func _apply_assists(delta: float, forward_speed: float, contacts: int) -> void:
	var up: Vector3 = global_transform.basis.y
	var yaw_rate: float = angular_velocity.dot(up)
	if contacts >= 2 and absf(forward_speed) > 3.0:
		# Stability: damp yaw beyond what the steering asks for.
		var expected: float = forward_speed * tan(_steer) / params.wheelbase
		var tolerance: float = 0.35 + (1.2 if input.handbrake else 0.0)
		var error: float = yaw_rate - expected
		if absf(error) > tolerance:
			var correction: float = -signf(error) * (absf(error) - tolerance)
			apply_torque(up * correction * params.inertia.y * params.stability * 6.0)
		# Drift assist: keep the drift angle under the maximum (no spin-outs).
		var drift: float = get_drift_angle()
		var allowed: float = params.max_drift_rad * 0.85
		if params.drift_assist > 0.0 and absf(drift) > allowed:
			var excess: float = absf(drift) - allowed
			apply_torque(up * signf(drift) * excess * params.inertia.y * params.drift_assist * 16.0)
	_auto_right(delta, contacts)


## In the air, keeps the car level; upside down and stopped, flips it back.
func _auto_right(delta: float, contacts: int) -> void:
	var up: Vector3 = global_transform.basis.y
	var tilt: float = acos(clampf(up.dot(Vector3.UP), -1.0, 1.0))
	if up.y < 0.5 and contacts < 2 and linear_velocity.length() < 4.0:
		_upside_down_time += delta
	else:
		_upside_down_time = 0.0
	var strength: float = params.auto_right_strength
	var flipping: bool = _upside_down_time > AUTO_RIGHT_DELAY
	if contacts == 0 or flipping:
		var axis: Vector3 = up.cross(Vector3.UP)
		if axis.length() < 0.01:
			axis = global_transform.basis.z
		axis = axis.normalized()
		var gain: float = strength if flipping else strength * 0.15
		var level_torque: Vector3 = axis * tilt * gain - angular_velocity * gain * 0.35
		level_torque -= up * angular_velocity.dot(up) * gain * 0.35 * (0.0 if flipping else 1.0)
		apply_torque(level_torque * (params.inertia.x + params.inertia.z) * 0.5)
	if flipping and up.y < 0.2:
		apply_central_force(Vector3.UP * mass * 9.8 * 1.25)


func _update_visual_wheels(delta: float) -> void:
	for wheel: WheelState in wheels:
		var wheel_visual: WheelVisual = visual.get_wheel(wheel.position_name)
		if wheel_visual == null:
			continue
		var offset: float = clampf(
			params.suspension_travel - wheel.spring_length, -MAX_DROOP, params.suspension_travel
		)
		var forward_speed: float = linear_velocity.dot(global_transform.basis.z)
		if not wheel.locked:
			var spin_speed: float = (
				forward_speed / params.wheel_radius * (1.0 + wheel.slip_ratio * 2.0)
			)
			wheel.spin = fposmod(wheel.spin + spin_speed * delta, TAU)
		wheel_visual.set_dynamics(offset, wheel.steer if wheel.is_front else 0.0, wheel.spin)


func _update_telemetry(forward_speed: float, contacts: int) -> void:
	var wheel_data: Dictionary = {}
	for wheel: WheelState in wheels:
		wheel_data[wheel.position_name] = {
			"load": wheel.load,
			"slip_angle_deg": rad_to_deg(wheel.slip_angle),
			"slip_ratio": wheel.slip_ratio,
			"grip_usage": wheel.grip_usage,
			"contact": wheel.contact,
		}
	telemetry = {
		"speed_kmh": forward_speed * 3.6,
		"rpm": drivetrain.rpm,
		"gear": drivetrain.gear,
		"shifting": drivetrain.shifting,
		"drift_deg": rad_to_deg(get_drift_angle()),
		"nitro": nitro_amount,
		"contacts": contacts,
		"wheels": wheel_data,
	}


func _build_collision() -> void:
	var scan: ConventionScanner.ScanResult = visual.get_scan()
	if not scan.collisions.is_empty():
		for collision: Node3D in scan.collisions:
			for mesh_node: MeshInstance3D in CarVisual._meshes_under(collision):
				var shape: CollisionShape3D = CollisionShape3D.new()
				shape.shape = mesh_node.mesh.create_convex_shape()
				shape.transform = _relative_transform(mesh_node)
				add_child(shape)
		return
	var length: float = car.dimensions.length_mm / 1000.0
	var width: float = car.dimensions.width_mm / 1000.0
	var height: float = car.dimensions.height_mm / 1000.0
	var center_z: float = (car.dimensions.length_mm / 1000.0) * 0.0
	var bottom: float = COLLISION_BOTTOM + _ride_m
	var belt: float = minf(height * 0.6, height - 0.1) + _ride_m
	_add_box(
		Vector3(width * 0.94, belt - bottom, length * 0.97),
		Vector3(0.0, (belt + bottom) / 2.0, center_z)
	)
	var roof: float = height + _ride_m - 0.03
	_add_box(
		Vector3(width * 0.72, roof - belt, length * 0.45),
		Vector3(0.0, (roof + belt) / 2.0, center_z - length * 0.05)
	)


func _add_box(size: Vector3, center: Vector3) -> void:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = box
	shape.position = center
	add_child(shape)


func _relative_transform(node: Node3D) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != self:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
