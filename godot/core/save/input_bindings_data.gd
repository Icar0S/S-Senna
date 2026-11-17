class_name InputBindingsData
extends RefCounted
## Controller memory and key bindings (`input.json`, doc 03 §15). Only the format
## and persistence for now; `InputRouter` (Etapa 07) is what uses it.

const SCHEMA: String = "input"

## Controller GUID (`Input.get_joy_guid`) -> `{"last_player": int, "name": String}`.
var known_devices: Dictionary = {}
## Player (`p1`, `p2`) -> { action -> PackedStringArray of bindings (`key:W`, `joy_axis:5+`) }.
var bindings: Dictionary = {}
var extra: Dictionary = {}


static func from_dict(data: Dictionary, ctx: LoadContext) -> InputBindingsData:
	var reader: DictReader = DictReader.new(data, ctx)
	reader.raw("schema")
	reader.raw("schema_version")
	var input: InputBindingsData = InputBindingsData.new()
	var devices: DictReader = reader.child("known_devices")
	for guid: String in devices.keys():
		var device: DictReader = devices.child(guid)
		input.known_devices[guid] = {
			"last_player": device.integer("last_player", false, 0, 0, 7),
			"name": device.text("name"),
		}
	var players: DictReader = reader.child("bindings")
	for player: String in players.keys():
		var actions: DictReader = players.child(player)
		var player_bindings: Dictionary = {}
		for action: String in actions.keys():
			player_bindings[action] = actions.string_list(action)
		input.bindings[player] = player_bindings
	input.extra = SaveValues.normalize(reader.take_unread())
	return input


func to_dict() -> Dictionary:
	var bindings_dict: Dictionary = {}
	for player: String in bindings:
		var actions: Dictionary = {}
		for action: String in bindings[player]:
			actions[action] = Array(bindings[player][action])
		bindings_dict[player] = actions
	var data: Dictionary = {
		"schema": SCHEMA,
		"schema_version": Migrations.CURRENT_VERSIONS[SCHEMA],
		"known_devices": known_devices.duplicate(true),
		"bindings": bindings_dict,
	}
	return SaveValues.with_extra(data, extra.duplicate(true))


## Remembers that the controller [param guid] was used by [param player].
func remember_device(guid: String, device_name: String, player: int) -> void:
	known_devices[guid] = {"last_player": player, "name": device_name}


func get_bindings(player: String, action: String) -> PackedStringArray:
	var actions: Dictionary = bindings.get(player, {})
	return actions.get(action, PackedStringArray())


func set_bindings(player: String, action: String, values: PackedStringArray) -> void:
	if not bindings.has(player):
		bindings[player] = {}
	bindings[player][action] = values
