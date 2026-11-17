class_name OrbitCamera
extends Camera3D
## Camera that orbits a point (showroom, garage, Studio): drag with the mouse,
## zoom with the wheel, or use the right stick of [member joy_device].
## Debug/garage camera, not player driving code: it reads one device directly;
## the garage will feed it through the InputRouter in Etapa 07/09.

const STICK_DEADZONE: float = 0.15
const ZOOM_STEP: float = 0.9

@export var target: Vector3 = Vector3(0.0, 0.6, 0.0)
@export var distance: float = 5.5
@export var min_distance: float = 2.5
@export var max_distance: float = 12.0
## Degrees.
@export var yaw: float = 35.0
@export var pitch: float = -12.0
@export var min_pitch: float = -60.0
@export var max_pitch: float = 5.0
@export var mouse_sensitivity: float = 0.3
@export var stick_speed: float = 120.0
@export var joy_device: int = 0

var _dragging: bool = false


func _ready() -> void:
	update_transform()


func _process(delta: float) -> void:
	var stick: Vector2 = Vector2(
		Input.get_joy_axis(joy_device, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(joy_device, JOY_AXIS_RIGHT_Y)
	)
	if stick.length() > STICK_DEADZONE:
		orbit(-stick.x * stick_speed * delta, -stick.y * stick_speed * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(ZOOM_STEP)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.0 / ZOOM_STEP)
	elif event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event
		orbit(-motion.relative.x * mouse_sensitivity, -motion.relative.y * mouse_sensitivity)


## Rotates around the target by [param yaw_delta] and [param pitch_delta] degrees.
func orbit(yaw_delta: float, pitch_delta: float) -> void:
	yaw = fposmod(yaw + yaw_delta, 360.0)
	pitch = clampf(pitch + pitch_delta, min_pitch, max_pitch)
	update_transform()


func zoom(factor: float) -> void:
	distance = clampf(distance * factor, min_distance, max_distance)
	update_transform()


func update_transform() -> void:
	var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.RIGHT, deg_to_rad(pitch)).rotated(
		Vector3.UP, deg_to_rad(yaw)
	)
	position = target - direction * distance
	look_at(target, Vector3.UP)
