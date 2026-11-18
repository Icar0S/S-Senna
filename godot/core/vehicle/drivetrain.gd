class_name Drivetrain
extends RefCounted
## Engine RPM and gearbox (automatic with hysteresis, or manual), limiter and
## the drive torque at the wheels. Pure logic: [method update] gets the wheel
## speed and the pedals, and returns the torque for the driven axle(s).
##
## Gears: 1..n forward, 0 = neutral (only while shifting), -1 = reverse.
## Arcade reverse: holding the brake when (almost) stopped engages reverse; then
## the brake pedal accelerates backwards and the throttle brakes.

const REVERSE: int = -1
## Speed (m/s) under which holding the brake engages reverse.
const REVERSE_SPEED: float = 1.0
## Seconds holding the brake while stopped before reverse engages.
const REVERSE_DELAY: float = 0.35
## Fraction of the redline where the limiter cuts the torque.
const LIMITER_FRAC: float = 0.995

var params: VehicleParams = null
var gear: int = 1
var rpm: float = 900.0
## True during the torque cut of a gear change.
var shifting: bool = false
## True while the rev limiter is cutting.
var limiter: bool = false

var _shift_timer: float = 0.0
var _target_gear: int = 1
var _reverse_timer: float = 0.0


func _init(vehicle_params: VehicleParams = null) -> void:
	params = vehicle_params
	if params != null:
		rpm = params.idle_rpm


## Advances one physics step. [param speed_ms] is the forward speed (negative when
## going backwards). Returns the total drive torque at the wheels (N·m; negative
## pushes backwards). [param throttle]/[param brake] are 0..1.
func update(
	delta: float, speed_ms: float, throttle: float, brake: float, input: VehicleInput
) -> float:
	_handle_reverse(delta, speed_ms, throttle, brake)
	if params.auto_gearbox:
		_auto_shift(speed_ms)
	else:
		_manual_shift(input)
	if shifting:
		_shift_timer -= delta
		if _shift_timer <= 0.0:
			shifting = false
			gear = _target_gear
	var ratio: float = current_ratio()
	var wheel_rpm: float = absf(HandlingModel.wheel_rpm(params, speed_ms))
	var engine_rpm: float = wheel_rpm * absf(ratio)
	var pedal: float = brake if gear == REVERSE else throttle
	# Free revving when stopped or clutch in: the needle rises with the pedal.
	var free_rpm: float = lerpf(params.idle_rpm, params.redline_rpm * 0.6, pedal)
	rpm = clampf(
		maxf(engine_rpm, free_rpm if engine_rpm < params.idle_rpm * 1.5 else engine_rpm),
		params.idle_rpm,
		params.redline_rpm
	)
	limiter = engine_rpm >= params.redline_rpm * LIMITER_FRAC
	if shifting or limiter or pedal <= 0.0:
		return 0.0
	var torque: float = HandlingModel.engine_torque(params, maxf(engine_rpm, params.idle_rpm))
	return torque * pedal * ratio * params.drive_efficiency


## Total ratio of the current gear (negative in reverse, 0 in neutral).
func current_ratio() -> float:
	if gear == REVERSE:
		return -params.reverse_ratio
	if gear <= 0 or shifting:
		return 0.0
	return params.gear_ratios[gear - 1]


## 0..1 position of the needle between idle and redline (for the HUD and audio).
func rpm_fraction() -> float:
	return clampf((rpm - params.idle_rpm) / (params.redline_rpm - params.idle_rpm), 0.0, 1.0)


func is_reverse() -> bool:
	return gear == REVERSE


func shift_to(new_gear: int) -> void:
	if new_gear == gear or shifting:
		return
	_target_gear = new_gear
	if new_gear == REVERSE or gear == REVERSE:
		gear = new_gear
		return
	shifting = params.shift_time_s > 0.0
	_shift_timer = params.shift_time_s
	if not shifting:
		gear = new_gear


func _auto_shift(speed_ms: float) -> void:
	if shifting or gear == REVERSE:
		return
	var wheel_rpm: float = HandlingModel.wheel_rpm(params, maxf(speed_ms, 0.0))
	var up_rpm: float = params.redline_rpm * params.upshift_rpm_frac
	var down_rpm: float = params.redline_rpm * params.downshift_rpm_frac
	if gear < params.gear_count() and wheel_rpm * params.gear_ratios[gear - 1] > up_rpm:
		shift_to(gear + 1)
	elif gear > 1:
		# Hysteresis: only downshift if the lower gear would not be near the upshift point.
		var lower_rpm: float = wheel_rpm * params.gear_ratios[gear - 2]
		if wheel_rpm * params.gear_ratios[gear - 1] < down_rpm and lower_rpm < up_rpm * 0.9:
			shift_to(gear - 1)


func _manual_shift(input: VehicleInput) -> void:
	if input == null or shifting:
		return
	if input.shift_up and gear < params.gear_count():
		shift_to(1 if gear == REVERSE else gear + 1)
	elif input.shift_down:
		if gear > 1:
			shift_to(gear - 1)


func _handle_reverse(delta: float, speed_ms: float, throttle: float, brake: float) -> void:
	if gear == REVERSE:
		if throttle > 0.1 and speed_ms > -REVERSE_SPEED:
			gear = 1
			_target_gear = 1
		return
	if brake > 0.5 and throttle < 0.1 and absf(speed_ms) < REVERSE_SPEED:
		_reverse_timer += delta
		if _reverse_timer >= REVERSE_DELAY:
			_reverse_timer = 0.0
			shift_to(REVERSE)
	else:
		_reverse_timer = 0.0
