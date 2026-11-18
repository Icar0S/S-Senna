extends GdUnitTestSuite
## HandlingModel (pure): conversions, monotonicity, upgrades, tuning, assists, overrides.

const PROTOTYPE: String = "car:base/prototipo"


func _car() -> CarDef:
	var source: CarDef = ContentDB.get_car(PROTOTYPE)
	# A copy whose stats the tests can change without touching ContentDB.
	var copy: CarDef = CarDef.from_dict(
		JSON.parse_string(FileAccess.get_file_as_string(source.source_file)),
		LoadContext.new(null, source.source_file)
	)
	return copy


func test_gearing_reaches_the_top_speed_near_the_redline() -> void:
	var p: VehicleParams = HandlingModel.compute(_car())
	assert_int(p.gear_count()).is_equal(6)
	for i: int in p.gear_count() - 1:
		assert_float(p.gear_ratios[i]).is_greater(p.gear_ratios[i + 1])
	var top_rpm: float = (
		HandlingModel.wheel_rpm(p, p.top_speed_ms) * p.gear_ratios[p.gear_count() - 1]
	)
	assert_float(top_rpm / p.redline_rpm).is_equal_approx(0.9, 0.01)
	# Drag balances the power at the top speed.
	var resistance: float = (
		p.drag_coef * pow(p.top_speed_ms, 3) + p.rolling_coef * p.mass_kg * 9.8 * p.top_speed_ms
	)
	assert_float(resistance).is_equal_approx(p.max_power_w * p.drive_efficiency, 1.0)


func test_springs_hold_the_car_at_its_anchors() -> void:
	var p: VehicleParams = HandlingModel.compute(_car())
	assert_float(p.spring_rest_front).is_greater(p.suspension_travel)
	assert_float(p.spring_rest_rear).is_greater(p.suspension_travel)
	assert_float(p.center_of_mass.y).is_less(0.5)


func test_engine_torque_curve() -> void:
	var p: VehicleParams = HandlingModel.compute(_car())
	assert_float(HandlingModel.engine_torque(p, p.idle_rpm)).is_less(p.max_torque_nm)
	assert_float(HandlingModel.engine_torque(p, p.redline_rpm * 0.45)).is_equal_approx(
		p.max_torque_nm, 1.0
	)
	var power_at_redline: float = (
		HandlingModel.engine_torque(p, p.redline_rpm) * p.redline_rpm * TAU / 60.0
	)
	assert_float(power_at_redline).is_less_equal(p.max_power_w + 1.0)


func test_more_power_accelerates_more() -> void:
	var weak: CarDef = _car()
	var strong: CarDef = _car()
	strong.stats.power_hp *= 1.5
	strong.stats.torque_nm *= 1.5
	var t_weak: float = HandlingModel.estimate_acceleration_time(HandlingModel.compute(weak))
	var t_strong: float = HandlingModel.estimate_acceleration_time(HandlingModel.compute(strong))
	assert_float(t_strong).is_less(t_weak)


func test_more_grip_gives_more_lateral_force() -> void:
	var low: CarDef = _car()
	var high: CarDef = _car()
	low.stats.grip = 0.2
	high.stats.grip = 0.9
	var p_low: VehicleParams = HandlingModel.compute(low)
	var p_high: VehicleParams = HandlingModel.compute(high)
	# Maximum lateral force of the car = mu x weight.
	assert_float(p_high.tire_mu * p_high.mass_kg).is_greater(p_low.tire_mu * p_low.mass_kg)


func test_better_brakes_and_lighter_car() -> void:
	var weak_brakes: CarDef = _car()
	var strong_brakes: CarDef = _car()
	weak_brakes.stats.braking = 0.1
	strong_brakes.stats.braking = 1.0
	(
		assert_float(HandlingModel.estimate_braking_distance(HandlingModel.compute(strong_brakes)))
		. is_less(HandlingModel.estimate_braking_distance(HandlingModel.compute(weak_brakes)))
	)
	var heavy: CarDef = _car()
	heavy.stats.mass_kg *= 1.6
	assert_float(HandlingModel.estimate_acceleration_time(HandlingModel.compute(heavy))).is_greater(
		HandlingModel.estimate_acceleration_time(HandlingModel.compute(_car()))
	)


func test_upgrades() -> void:
	var upgrades: UpgradeTable = ContentDB.get_library().get_upgrades()
	var stock: VehicleParams = HandlingModel.compute(_car(), {}, upgrades)
	var tuned: VehicleParams = HandlingModel.compute(
		_car(), {"engine": 3, "tires": 3, "nitrous": 2, "weight": 3}, upgrades
	)
	assert_float(tuned.max_power_w).is_equal_approx(stock.max_power_w * 1.3, 1.0)
	assert_float(tuned.top_speed_ms).is_greater(stock.top_speed_ms)
	assert_float(tuned.tire_mu).is_greater(stock.tire_mu)
	assert_float(tuned.mass_kg).is_equal_approx(stock.mass_kg * 0.9, 0.01)
	assert_float(tuned.nitro_capacity_s).is_equal(5.0)
	assert_float(stock.nitro_capacity_s).is_equal(0.0)


func test_tuning_sliders() -> void:
	var neutral: VehicleParams = HandlingModel.compute(
		_car(), {}, null, {"grip_drift": 0.5, "gearing": 0.5}
	)
	var plain: VehicleParams = HandlingModel.compute(_car())
	assert_float(neutral.rear_grip_factor).is_equal_approx(plain.rear_grip_factor, 0.0001)
	var drifty: VehicleParams = HandlingModel.compute(_car(), {}, null, {"grip_drift": 1.0})
	assert_float(drifty.rear_grip_factor).is_less(plain.rear_grip_factor)
	var long_gears: VehicleParams = HandlingModel.compute(_car(), {}, null, {"gearing": 1.0})
	assert_float(long_gears.gear_ratios[0]).is_less(plain.gear_ratios[0])
	var front_brakes: VehicleParams = HandlingModel.compute(_car(), {}, null, {"brake_bias": 1.0})
	assert_float(front_brakes.brake_bias_front).is_greater(plain.brake_bias_front)


func test_assists_and_drivetrain() -> void:
	var off: VehicleParams = HandlingModel.compute(
		_car(),
		{},
		null,
		{},
		{
			"steering": false,
			"stability": false,
			"abs": false,
			"traction": false,
			"gearbox": "manual"
		}
	)
	assert_bool(off.abs_enabled).is_false()
	assert_bool(off.traction_control).is_false()
	assert_bool(off.auto_gearbox).is_false()
	assert_float(off.countersteer).is_equal(0.0)
	assert_float(off.drift_assist).is_equal(0.0)
	var on: VehicleParams = HandlingModel.compute(
		_car(), {}, null, {}, ProfileData.default_assists()
	)
	assert_bool(on.abs_enabled).is_true()
	assert_float(on.stability).is_greater(off.stability)
	var fwd: CarDef = _car()
	fwd.stats.drivetrain = "FWD"
	assert_float(HandlingModel.compute(fwd).front_drive_share).is_equal(1.0)
	assert_float(HandlingModel.compute(_car()).front_drive_share).is_equal(0.0)


func test_overrides_are_applied_and_clamped() -> void:
	var p: VehicleParams = HandlingModel.compute(_car())
	var rest_before: float = p.spring_rest_front
	p.apply_overrides(
		{
			"tire_mu": 2.0,
			"spring_k_front": p.spring_k_front * 2.0,
			"nao_existe": 5,
			"drift_assist": 9.0
		}
	)
	assert_float(p.tire_mu).is_equal(2.0)
	assert_float(p.drift_assist).is_equal(1.0)
	assert_float(p.spring_rest_front).is_less(rest_before)


func test_globals_file_and_round_trip() -> void:
	var library: ContentLibrary = ContentDB.get_library()
	assert_str(library.get_handling_globals_file()).ends_with("handling_global.json")
	var globals: HandlingGlobals = library.get_handling_globals()
	var ctx: LoadContext = LoadContext.new()
	var copy: HandlingGlobals = HandlingGlobals.from_dict(globals.to_dict(), ctx)
	assert_bool(ctx.report.is_empty()).is_true()
	assert_dict(copy.to_dict()).is_equal(globals.to_dict())
	var bad: Dictionary = globals.to_dict()
	bad["grip_max"] = 99.0
	var bad_ctx: LoadContext = LoadContext.new()
	assert_float(HandlingGlobals.from_dict(bad, bad_ctx).grip_max).is_equal(3.0)
	assert_int(bad_ctx.report.warning_count()).is_equal(1)
