class_name InputActions
extends RefCounted
## The base actions of a player and their default bindings (table in etapa-07).
## The InputRouter turns them into `p1_<action>`, `p2_<action>` in the InputMap.

const THROTTLE: String = "throttle"
const BRAKE: String = "brake"
const STEER_LEFT: String = "steer_left"
const STEER_RIGHT: String = "steer_right"
const NITRO: String = "nitro"
const HANDBRAKE: String = "handbrake"
const CAMERA: String = "camera"
const LOOK_BACK: String = "look_back"
const SHIFT_UP: String = "shift_up"
const SHIFT_DOWN: String = "shift_down"
const RESET: String = "reset"
const PAUSE: String = "pause"

const ALL: PackedStringArray = [
	THROTTLE,
	BRAKE,
	STEER_LEFT,
	STEER_RIGHT,
	NITRO,
	HANDBRAKE,
	CAMERA,
	LOOK_BACK,
	SHIFT_UP,
	SHIFT_DOWN,
	RESET,
	PAUSE,
]

const DEADZONE: float = 0.15

## Keyboard of player 1 (physical keys, so WASD works on any layout).
const KEYBOARD_P1: Dictionary = {
	THROTTLE: [KEY_W],
	BRAKE: [KEY_S],
	STEER_LEFT: [KEY_A],
	STEER_RIGHT: [KEY_D],
	NITRO: [KEY_SHIFT],
	HANDBRAKE: [KEY_SPACE],
	CAMERA: [KEY_C],
	LOOK_BACK: [KEY_Q],
	SHIFT_UP: [KEY_X],
	SHIFT_DOWN: [KEY_Z],
	RESET: [KEY_R],
	PAUSE: [KEY_ESCAPE],
}

## Controller: buttons and axes. Axis entries are [axis, direction].
const JOY_BUTTONS: Dictionary = {
	STEER_LEFT: [JOY_BUTTON_DPAD_LEFT],
	STEER_RIGHT: [JOY_BUTTON_DPAD_RIGHT],
	NITRO: [JOY_BUTTON_A],
	HANDBRAKE: [JOY_BUTTON_X],
	CAMERA: [JOY_BUTTON_Y],
	LOOK_BACK: [JOY_BUTTON_B],
	SHIFT_UP: [JOY_BUTTON_RIGHT_SHOULDER],
	SHIFT_DOWN: [JOY_BUTTON_LEFT_SHOULDER],
	RESET: [JOY_BUTTON_BACK],
	PAUSE: [JOY_BUTTON_START],
}
const JOY_AXES: Dictionary = {
	THROTTLE: [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	BRAKE: [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
	STEER_LEFT: [[JOY_AXIS_LEFT_X, -1.0]],
	STEER_RIGHT: [[JOY_AXIS_LEFT_X, 1.0]],
}


## `p1_throttle` for player 0.
static func action_name(player: int, action: String) -> String:
	return "p%d_%s" % [player + 1, action]


## Default events of [param action] for a keyboard and (when >= 0) a controller.
static func default_events(action: String, joy_device: int) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for keycode: int in KEYBOARD_P1.get(action, []):
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = keycode as Key
		key.device = -1
		events.append(key)
	if joy_device < 0:
		return events
	for button: int in JOY_BUTTONS.get(action, []):
		var joy_button: InputEventJoypadButton = InputEventJoypadButton.new()
		joy_button.button_index = button as JoyButton
		joy_button.device = joy_device
		events.append(joy_button)
	for axis_entry: Array in JOY_AXES.get(action, []):
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.axis = int(axis_entry[0]) as JoyAxis
		motion.axis_value = float(axis_entry[1])
		motion.device = joy_device
		events.append(motion)
	return events
