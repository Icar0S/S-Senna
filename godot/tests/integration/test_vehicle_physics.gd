extends GdUnitTestSuite
## Headless driving tests with simulated input (Etapa 04 acceptance criteria).
## Physics runs 8x faster than real time with the same 1/120 s step.

var _lab: PhysicsLab = null
var _vehicle: Vehicle = null


func before_test() -> void:
	_lab = PhysicsLab.new(get_tree(), self)
	_lab.speed_up()
	_vehicle = _lab.spawn(
		"car:base/prototipo", Vector3(0.0, 0.05, -2600.0), ProfileData.default_assists()
	)
	await _lab.run(1.0)


func after_test() -> void:
	_lab.restore()
	_lab.free_all()


func test_parked_car_does_not_slide() -> void:
	var start: Vector3 = _vehicle.global_position
	await _lab.run(10.0)
	assert_float(_vehicle.global_position.distance_to(start)).is_less(0.01)
	assert_int(_vehicle.wheels_on_ground()).is_equal(4)


func test_zero_to_100_matches_the_handling_model() -> void:
	var expected: float = HandlingModel.estimate_acceleration_time(_vehicle.params)
	_lab.driver.program = func(input: VehicleInput, _v: Vehicle, _t: float) -> void:
		input.throttle = 1.0
	var measured: float = await _lab.run(
		30.0, func(v: Vehicle, _t: float) -> bool: return v.get_speed_kmh() >= 100.0
	)
	prints("0-100: %.2f s (esperado %.2f s)" % [measured, expected])
	assert_float(measured).is_between(expected * 0.85, expected * 1.15)


func test_top_speed_matches_the_car() -> void:
	_lab.driver.program = func(input: VehicleInput, _v: Vehicle, _t: float) -> void:
		input.throttle = 1.0
	var top: Array = [0.0]
	await _lab.run(
		80.0,
		func(v: Vehicle, _t: float) -> bool:
			top[0] = maxf(top[0], v.get_speed_kmh())
			return false
	)
	var target: float = _vehicle.car.stats.top_speed_kmh
	prints("Velocidade máxima: %.1f km/h (alvo %.0f)" % [top[0], target])
	assert_float(top[0]).is_between(target * 0.95, target * 1.05)


func test_braking_from_100() -> void:
	_lab.driver.program = func(input: VehicleInput, _v: Vehicle, _t: float) -> void:
		input.throttle = 1.0
	await _lab.run(30.0, func(v: Vehicle, _t: float) -> bool: return v.get_speed_kmh() >= 100.0)
	var start: Vector3 = _vehicle.global_position
	_lab.driver.program = func(input: VehicleInput, _v: Vehicle, _t: float) -> void:
		input.throttle = 0.0
		input.brake = 1.0
	await _lab.run(15.0, func(v: Vehicle, _t: float) -> bool: return v.get_speed_kmh() <= 0.5)
	var distance: float = _vehicle.global_position.distance_to(start)
	var expected: float = HandlingModel.estimate_braking_distance(_vehicle.params)
	prints("Frenagem 100-0: %.1f m (esperado %.1f m)" % [distance, expected])
	assert_float(distance).is_between(expected * 0.85, expected * 1.2)


func test_slalom_at_80_with_assists() -> void:
	_lab.driver.program = func(input: VehicleInput, v: Vehicle, t: float) -> void:
		input.throttle = clampf((82.0 - v.get_speed_kmh()) * 0.3, 0.0, 1.0)
		input.steer = 0.5 * sin(t * TAU / 2.4) if t > 6.0 else 0.0
	var worst: Dictionary = {"up": 1.0, "drift": 0.0, "speed": 999.0}
	await _lab.run(
		22.0,
		func(v: Vehicle, t: float) -> bool:
			if t > 6.0:
				worst["up"] = minf(worst["up"], v.global_transform.basis.y.y)
				worst["drift"] = maxf(worst["drift"], absf(rad_to_deg(v.get_drift_angle())))
				worst["speed"] = minf(worst["speed"], v.get_speed_kmh())
			return false
	)
	prints(
		(
			"Slalom: inclinação mínima %.2f · drift máximo %.1f° · velocidade mínima %.0f km/h"
			% [worst["up"], worst["drift"], worst["speed"]]
		)
	)
	assert_float(worst["up"]).is_greater(0.8)
	assert_float(worst["drift"]).is_less(35.0)
	assert_float(worst["speed"]).is_greater(65.0)


func test_upside_down_car_rights_itself() -> void:
	_vehicle.global_transform = Transform3D(
		Basis(Vector3.BACK, PI), _vehicle.global_position + Vector3(0, 1.5, 0)
	)
	_vehicle.linear_velocity = Vector3.ZERO
	_vehicle.angular_velocity = Vector3.ZERO
	var elapsed: float = await _lab.run(
		5.0,
		func(v: Vehicle, t: float) -> bool:
			return t > 0.3 and v.is_upright() and v.wheels_on_ground() >= 3
	)
	prints("Endireitou em %.2f s" % elapsed)
	assert_float(elapsed).is_less(3.0)


func test_handbrake_starts_a_controlled_drift() -> void:
	_lab.driver.program = func(input: VehicleInput, v: Vehicle, t: float) -> void:
		input.throttle = clampf((70.0 - v.get_speed_kmh()) * 0.3, 0.0, 1.0) if t < 8.0 else 0.6
		input.steer = 0.0 if t < 8.0 else 1.0
		input.handbrake = t > 8.0 and t < 8.7
	var peak: Array = [0.0]
	var min_up: Array = [1.0]
	await _lab.run(
		12.0,
		func(v: Vehicle, _t: float) -> bool:
			peak[0] = maxf(peak[0], absf(rad_to_deg(v.get_drift_angle())))
			min_up[0] = minf(min_up[0], v.global_transform.basis.y.y)
			return false
	)
	prints("Drift com freio de mão: pico %.1f°" % peak[0])
	assert_float(peak[0]).is_greater(10.0)
	assert_float(peak[0]).is_less(60.0)
	assert_float(min_up[0]).is_greater(0.8)


func test_reset_and_visual_wheels() -> void:
	var marker: Marker3D = Marker3D.new()
	marker.add_to_group(Vehicle.RESET_GROUP)
	_lab.root.add_child(marker)
	marker.global_position = _vehicle.global_position + Vector3(5.0, 0.0, 5.0)
	# Wheels drawn where the suspension puts them (close to the anchors at rest).
	var wheel: WheelVisual = _vehicle.visual.get_wheel("FL")
	assert_float(absf(wheel.position.y - wheel.anchor.y)).is_less(0.03)
	_vehicle.global_transform = Transform3D(
		Basis(Vector3.BACK, 2.0), _vehicle.global_position + Vector3(0, 3, 0)
	)
	_vehicle.reset_to_safe_position()
	assert_bool(_vehicle.is_upright()).is_true()
	(
		assert_float(
			_vehicle.global_position.distance_to(
				marker.global_position + Vector3(0, Vehicle.RESET_LIFT, 0)
			)
		)
		. is_less(0.01)
	)
	assert_vector(_vehicle.linear_velocity).is_equal(Vector3.ZERO)
