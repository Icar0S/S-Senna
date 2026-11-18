extends Node
## Autoload `InputRouter`: devices -> players, actions per player (doc 02 §5.4).
##
## Etapa 04 version: ONE player (index 0) using the keyboard plus the first
## connected controller. The API is the final one of Etapa 07 (`get_axis`,
## `is_pressed`, `just_pressed`, `assign`, `release` and the signals), so player
## code never changes. Player code NEVER calls `Input.is_action_pressed("throttle")`.

signal player_joined(player: int)
signal player_left(player: int)
signal device_lost(player: int)

const MAX_PLAYERS: int = 2
const KEYBOARD: String = "kbd"
const JOY_PREFIX: String = "joy:"
const LOG_CONTEXT: String = "InputRouter"

## Player index -> Array of device keys (`kbd`, `joy:0`...).
var _devices: Dictionary = {}


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var joypads: Array[int] = Input.get_connected_joypads()
	var first_device: Array = [KEYBOARD]
	if not joypads.is_empty():
		first_device.append(JOY_PREFIX + str(joypads[0]))
	_set_devices(0, first_device)


## -1..1 from two actions (e.g. `steer_left`, `steer_right`).
func get_axis(player: int, negative: String, positive: String) -> float:
	return Input.get_axis(
		InputActions.action_name(player, negative), InputActions.action_name(player, positive)
	)


## 0..1 (analog triggers give values in between).
func get_strength(player: int, action: String) -> float:
	return Input.get_action_strength(InputActions.action_name(player, action))


func is_pressed(player: int, action: String) -> bool:
	return Input.is_action_pressed(InputActions.action_name(player, action))


func just_pressed(player: int, action: String) -> bool:
	return Input.is_action_just_pressed(InputActions.action_name(player, action))


## Gives [param device] (`kbd` or `joy:<id>`) to [param player].
func assign(player: int, device: String) -> void:
	var devices: Array = _devices.get(player, []).duplicate()
	if not devices.has(device):
		devices.append(device)
	_set_devices(player, devices)


## Removes every device of [param player] (its actions stop answering).
func release(player: int) -> void:
	if not _devices.has(player):
		return
	_set_devices(player, [])
	_devices.erase(player)
	player_left.emit(player)


func get_devices(player: int) -> Array:
	return _devices.get(player, []).duplicate()


func has_player(player: int) -> bool:
	return _devices.has(player) and not (_devices[player] as Array).is_empty()


## Device key of a controller id.
static func joy_key(device_id: int) -> String:
	return JOY_PREFIX + str(device_id)


func _set_devices(player: int, devices: Array) -> void:
	var was_active: bool = has_player(player)
	_devices[player] = devices
	var joy_device: int = -1
	for device: String in devices:
		if device.begins_with(JOY_PREFIX):
			joy_device = int(device.trim_prefix(JOY_PREFIX))
	var has_keyboard: bool = devices.has(KEYBOARD)
	for action: String in InputActions.ALL:
		var name: String = InputActions.action_name(player, action)
		if InputMap.has_action(name):
			InputMap.action_erase_events(name)
		else:
			InputMap.add_action(name, InputActions.DEADZONE)
		for event: InputEvent in InputActions.default_events(action, joy_device):
			if event is InputEventKey and not has_keyboard:
				continue
			InputMap.action_add_event(name, event)
	if not was_active and has_player(player):
		player_joined.emit(player)


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	var key: String = joy_key(device_id)
	for player: int in _devices:
		var devices: Array = _devices[player]
		if not connected and devices.has(key):
			devices.erase(key)
			_set_devices(player, devices)
			Log.warn("Controle %s do jogador %d desconectado" % [key, player + 1], LOG_CONTEXT)
			device_lost.emit(player)
			return
	if connected:
		var player_one: Array = _devices.get(0, [])
		for device: String in player_one:
			if device.begins_with(JOY_PREFIX):
				return
		assign(0, key)
		Log.info("Controle %s atribuído ao jogador 1" % key, LOG_CONTEXT)
