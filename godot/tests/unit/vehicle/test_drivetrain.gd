extends GdUnitTestSuite
## Drivetrain: automatic shifting with hysteresis, manual, limiter, reverse.

const STEP: float = 1.0 / 120.0

var _params: VehicleParams = null


func before_test() -> void:
	_params = HandlingModel.compute(ContentDB.get_car("car:base/prototipo"))
	_params.shift_time_s = 0.2


func _speed_for_rpm(gear: int, rpm: float) -> float:
	return rpm / _params.gear_ratios[gear - 1] / 60.0 * TAU * _params.wheel_radius


func test_auto_upshift_and_hysteresis() -> void:
	var drivetrain: Drivetrain = Drivetrain.new(_params)
	var input: VehicleInput = VehicleInput.new()
	var near_upshift: float = _speed_for_rpm(1, _params.redline_rpm * 0.96)
	drivetrain.update(STEP, near_upshift, 1.0, 0.0, input)
	assert_bool(drivetrain.shifting).is_true()
	# Torque is cut while shifting.
	assert_float(drivetrain.update(STEP, near_upshift, 1.0, 0.0, input)).is_equal(0.0)
	for i: int in 30:
		drivetrain.update(STEP, near_upshift, 1.0, 0.0, input)
	assert_int(drivetrain.gear).is_equal(2)
	# Right after the upshift the RPM drops, but it must not shift back down.
	for i: int in 30:
		drivetrain.update(STEP, near_upshift, 1.0, 0.0, input)
	assert_int(drivetrain.gear).is_equal(2)
	# Slowing down a lot: downshifts.
	for i: int in 60:
		drivetrain.update(STEP, 2.0, 0.0, 0.0, input)
	assert_int(drivetrain.gear).is_equal(1)


func test_torque_and_rpm() -> void:
	var drivetrain: Drivetrain = Drivetrain.new(_params)
	var input: VehicleInput = VehicleInput.new()
	var torque: float = drivetrain.update(STEP, 5.0, 1.0, 0.0, input)
	assert_float(torque).is_greater(0.0)
	assert_float(drivetrain.update(STEP, 5.0, 0.0, 0.0, input)).is_equal(0.0)
	assert_float(drivetrain.rpm).is_greater_equal(_params.idle_rpm)
	assert_float(drivetrain.rpm_fraction()).is_between(0.0, 1.0)


func test_manual_gearbox_and_limiter() -> void:
	_params.auto_gearbox = false
	var drivetrain: Drivetrain = Drivetrain.new(_params)
	var input: VehicleInput = VehicleInput.new()
	var over_redline: float = _speed_for_rpm(1, _params.redline_rpm * 1.05)
	assert_float(drivetrain.update(STEP, over_redline, 1.0, 0.0, input)).is_equal(0.0)
	assert_bool(drivetrain.limiter).is_true()
	assert_int(drivetrain.gear).is_equal(1)
	input.shift_up = true
	drivetrain.update(STEP, over_redline, 1.0, 0.0, input)
	input.shift_up = false
	for i: int in 30:
		drivetrain.update(STEP, over_redline, 1.0, 0.0, input)
	assert_int(drivetrain.gear).is_equal(2)
	assert_bool(drivetrain.limiter).is_false()
	input.shift_down = true
	drivetrain.update(STEP, 3.0, 0.0, 0.0, input)
	input.shift_down = false
	for i: int in 30:
		drivetrain.update(STEP, 3.0, 0.0, 0.0, input)
	assert_int(drivetrain.gear).is_equal(1)


func test_reverse_by_holding_the_brake() -> void:
	var drivetrain: Drivetrain = Drivetrain.new(_params)
	var input: VehicleInput = VehicleInput.new()
	for i: int in 60:
		drivetrain.update(STEP, 0.0, 0.0, 1.0, input)
	assert_bool(drivetrain.is_reverse()).is_true()
	# In reverse the brake pedal drives backwards.
	assert_float(drivetrain.update(STEP, -1.0, 0.0, 1.0, input)).is_less(0.0)
	drivetrain.update(STEP, -0.5, 1.0, 0.0, input)
	assert_int(drivetrain.gear).is_equal(1)
