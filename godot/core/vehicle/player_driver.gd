class_name PlayerDriver
extends VehicleDriver
## Drives with a player's controls, through the InputRouter (never global input).
## Keyboard steering is digital (-1, 0, +1): it is ramped in and returns to the
## center smoothly so the car is easy to control; analog sticks pass almost directly.

const DIGITAL_STEER_IN: float = 3.2
const DIGITAL_STEER_OUT: float = 5.5
const ANALOG_STEER_RATE: float = 14.0

var player: int = 0

var _steer: float = 0.0


func _init(player_index: int = 0) -> void:
	player = player_index


func drive(input: VehicleInput, delta: float, _vehicle: Vehicle) -> void:
	input.throttle = InputRouter.get_strength(player, InputActions.THROTTLE)
	input.brake = InputRouter.get_strength(player, InputActions.BRAKE)
	var target: float = InputRouter.get_axis(
		player, InputActions.STEER_LEFT, InputActions.STEER_RIGHT
	)
	_steer = smooth_steer(_steer, target, delta)
	input.steer = _steer
	input.handbrake = InputRouter.is_pressed(player, InputActions.HANDBRAKE)
	input.nitro = InputRouter.is_pressed(player, InputActions.NITRO)
	input.look_back = InputRouter.is_pressed(player, InputActions.LOOK_BACK)
	input.shift_up = InputRouter.just_pressed(player, InputActions.SHIFT_UP)
	input.shift_down = InputRouter.just_pressed(player, InputActions.SHIFT_DOWN)
	input.camera_next = InputRouter.just_pressed(player, InputActions.CAMERA)
	input.reset = InputRouter.just_pressed(player, InputActions.RESET)


## Moves [param current] toward [param target]. Digital targets (keyboard) ramp
## slowly in and faster back to the center; analog targets follow quickly.
static func smooth_steer(current: float, target: float, delta: float) -> float:
	var digital: bool = is_zero_approx(target) or is_equal_approx(absf(target), 1.0)
	var rate: float = ANALOG_STEER_RATE
	if digital:
		var returning: bool = absf(target) < absf(current) or signf(target) != signf(current)
		rate = DIGITAL_STEER_OUT if returning else DIGITAL_STEER_IN
	return move_toward(current, target, rate * delta)
