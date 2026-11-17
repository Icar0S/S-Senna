class_name Conventions
extends RefCounted
## Shared conventions (slots, sockets, wheel positions, material names, node naming),
## read from `conventions.json` — the single source also used by the Studio, the
## Blender add-on and the CI. Never hard-code these names elsewhere.

const CONVENTIONS_PATH: String = "res://core/content/conventions.json"

static var _data: Dictionary = {}
## Lists already converted from the JSON (they are read many times per scan).
## Packed arrays are passed by reference in Godot 4, so callers get copies.
static var _lists: Dictionary = {}


## The whole parsed file (loaded once, on first use).
static func data() -> Dictionary:
	if _data.is_empty():
		_data = _load(CONVENTIONS_PATH)
	return _data


static func replace_slots() -> PackedStringArray:
	return _list("slots.replace").duplicate()


static func attach_slots() -> PackedStringArray:
	return _list("slots.attach").duplicate()


static func all_slots() -> PackedStringArray:
	return _all_slots().duplicate()


static func is_slot(slot: String) -> bool:
	return _all_slots().has(slot)


static func sockets() -> PackedStringArray:
	return _list("sockets").duplicate()


static func is_socket(socket: String) -> bool:
	return _list("sockets").has(socket)


static func wheel_positions() -> PackedStringArray:
	return _list("wheels").duplicate()


static func materials() -> PackedStringArray:
	return _list("materials").duplicate()


## True for official material names and for `tex_*` (keep the original material).
static func is_material_name(material_name: String) -> bool:
	if _list("materials").has(material_name):
		return true
	var keep_prefix: String = str(data().get("material_prefix_keep", ""))
	return not keep_prefix.is_empty() and material_name.begins_with(keep_prefix)


static func name_separator() -> String:
	return str(data().get("name_separator", "-"))


## Name prefix of a node role (`socket`, `wheel`, `rim`, `collision`).
static func node_prefix(role: String) -> String:
	return str(_dict("node_prefixes").get(role, ""))


static func fixed_prefixes() -> PackedStringArray:
	return _list("fixed_prefixes").duplicate()


## glTF `extras` key for `role`, `slot` or `variant` (e.g. `ss_role`).
static func metadata_key(field: String) -> String:
	return str(_dict("metadata_keys").get(field, ""))


static func metadata_roles() -> PackedStringArray:
	return _list("metadata_roles").duplicate()


static func forbidden_name_suffixes() -> PackedStringArray:
	return _list("forbidden_name_suffixes").duplicate()


## True when [param node_name] ends with a Godot import suffix (e.g. `-col`).
static func has_forbidden_suffix(node_name: String) -> bool:
	var lower: String = node_name.to_lower()
	for suffix: String in _list("forbidden_name_suffixes"):
		if lower.ends_with(suffix):
			return true
	return false


static func part_finishes() -> PackedStringArray:
	return _list("part_finishes").duplicate()


static func paint_finishes() -> PackedStringArray:
	return _list("paint_finishes").duplicate()


## Triangle budget by name (`car_total_tris`, `body_tris`, `part_tris`, `rim_tris`).
static func budget(budget_name: String) -> int:
	return int(_dict("budgets").get(budget_name, 0))


static func _all_slots() -> PackedStringArray:
	if not _lists.has("slots.all"):
		var slots: PackedStringArray = _list("slots.replace").duplicate()
		slots.append_array(_list("slots.attach"))
		_lists["slots.all"] = slots
	return _lists["slots.all"]


## String list at a dotted path of the JSON (e.g. `slots.replace`), converted once.
## The cached array is shared: public functions return copies of it.
static func _list(path: String) -> PackedStringArray:
	if not _lists.has(path):
		var value: Variant = data()
		for key: String in path.split("."):
			value = value.get(key, []) if value is Dictionary else []
		_lists[path] = _strings(value)
	return _lists[path]


static func _dict(key: String) -> Dictionary:
	var value: Variant = data().get(key, {})
	return value if value is Dictionary else {}


static func _strings(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = []
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result


static func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Conventions: file not found: %s" % path)
		return {}
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		push_error("Conventions: invalid JSON in %s" % path)
		return {}
	return json.data
