class_name DictReader
extends RefCounted
## Typed, validating access to one JSON object, used by every `from_dict`.
##
## Rules (doc 03 §1): a missing required field or a value of the wrong type is an
## ERROR; a value out of range is clamped with a WARNING; a key that was never read
## is reported as an unknown field (WARNING) by [method finish].

const COLOR_PATTERN: String = "^#[0-9A-Fa-f]{6}$"
const UNLOCK_PATTERN: String = "^(default|never|chapter:[0-9]+|event:[a-z0-9_-]+)$"
const KEY_SCHEMA: String = "schema"
const KEY_SCHEMA_VERSION: String = "schema_version"
const NUMBER_TYPES: Array[int] = [TYPE_FLOAT, TYPE_INT]

static var _color_regex: RegEx = null
static var _unlock_regex: RegEx = null

var _data: Dictionary = {}
var _ctx: LoadContext = null
var _prefix: String = ""
var _used: Dictionary = {}
var _children: Array[DictReader] = []


func _init(data: Dictionary, ctx: LoadContext, prefix: String = "") -> void:
	_data = data
	_ctx = ctx
	_prefix = prefix


func context() -> LoadContext:
	return _ctx


## Full field name for messages, e.g. `wheels.anchors.FL`.
func field_path(key: String) -> String:
	return key if _prefix.is_empty() else "%s.%s" % [_prefix, key]


## All keys of the object (does not mark them as read).
func keys() -> PackedStringArray:
	var result: PackedStringArray = []
	for key: Variant in _data.keys():
		result.append(str(key))
	return result


func has(key: String) -> bool:
	_used[key] = true
	return _data.has(key) and _data[key] != null


## The value as it is in the JSON (no validation). Marks the key as read.
func raw(key: String, default_value: Variant = null) -> Variant:
	_used[key] = true
	return _data.get(key, default_value)


func text(key: String, required: bool = false, default_value: String = "") -> String:
	var value: Variant = _get_typed(key, required, [TYPE_STRING], "texto")
	if value == null:
		return default_value
	var result: String = value
	if required and result.strip_edges().is_empty():
		_ctx.error(field_path(key), "campo obrigatório está vazio")
		return default_value
	return result


func number(
	key: String,
	required: bool = false,
	default_value: float = 0.0,
	min_value: float = -INF,
	max_value: float = INF
) -> float:
	var value: Variant = _get_typed(key, required, NUMBER_TYPES, "número")
	if value == null:
		return default_value
	return _clamped(key, float(value), min_value, max_value)


func integer(
	key: String,
	required: bool = false,
	default_value: int = 0,
	min_value: int = -2147483648,
	max_value: int = 2147483647
) -> int:
	var value: Variant = _get_typed(key, required, NUMBER_TYPES, "número inteiro")
	if value == null:
		return default_value
	var as_float: float = float(value)
	if as_float != floorf(as_float):
		_ctx.error(field_path(key), "esperado número inteiro, recebido %s" % as_float)
		return default_value
	return int(_clamped(key, as_float, float(min_value), float(max_value)))


func boolean(key: String, default_value: bool = false) -> bool:
	var value: Variant = _get_typed(key, false, [TYPE_BOOL], "verdadeiro/falso")
	return default_value if value == null else bool(value)


## A string that must be one of [param allowed].
func enum_value(
	key: String, allowed: PackedStringArray, required: bool = false, default_value: String = ""
) -> String:
	if not has(key) and not required:
		return default_value
	var value: String = text(key, required, default_value)
	if not allowed.has(value):
		if has(key):
			_ctx.error(
				field_path(key), "valor '%s' inválido (válidos: %s)" % [value, ", ".join(allowed)]
			)
		return default_value
	return value


## Color `#RRGGBB`.
func color(key: String, required: bool = false, default_value: String = "#FFFFFF") -> String:
	if not required and not has(key):
		return default_value
	var value: String = text(key, required, default_value)
	if not _color_re().search(value):
		_ctx.error(field_path(key), "cor inválida '%s' (formato esperado: #RRGGBB)" % value)
		return default_value
	return value


## A content ID of [param expected_type] (`car`, `part`...); "" when missing or invalid.
func content_id(key: String, expected_type: String, required: bool = false) -> String:
	var value: String = text(key, required)
	if value.is_empty():
		return ""
	return _checked_id(field_path(key), value, expected_type)


## `default`, `never`, `chapter:N` or `event:<id>`.
func unlock(key: String, default_value: String = "default") -> String:
	var value: String = text(key, false, default_value)
	if not _unlock_re().search(value):
		_ctx.error(
			field_path(key),
			"desbloqueio inválido '%s' (use default, never, chapter:N ou event:<id>)" % value
		)
		return default_value
	return value


## A list of strings; when [param allowed] is given, every item must be in it.
func string_list(
	key: String, required: bool = false, allowed: PackedStringArray = PackedStringArray()
) -> PackedStringArray:
	var result: PackedStringArray = []
	var value: Variant = _get_typed(key, required, [TYPE_ARRAY], "lista")
	if value == null:
		return result
	var items: Array = value
	for i: int in items.size():
		var item_field: String = "%s[%d]" % [field_path(key), i]
		if not items[i] is String:
			_ctx.error(item_field, "esperado texto, recebido %s" % _type_label(items[i]))
			continue
		var item: String = items[i]
		if not allowed.is_empty() and not allowed.has(item):
			_ctx.error(item_field, "valor '%s' inválido (válidos: %s)" % [item, ", ".join(allowed)])
			continue
		result.append(item)
	return result


## A list of content IDs of [param expected_type]; invalid items are dropped.
func id_list(key: String, expected_type: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var items: PackedStringArray = string_list(key)
	for i: int in items.size():
		var id: String = _checked_id("%s[%d]" % [field_path(key), i], items[i], expected_type)
		if not id.is_empty():
			result.append(id)
	return result


## `[x, y, z]` in meters.
func vector3(key: String, required: bool = false) -> Vector3:
	var value: Variant = _get_typed(key, required, [TYPE_ARRAY], "lista [x, y, z]")
	if value == null:
		return Vector3.ZERO
	var items: Array = value
	if items.size() != 3 or not items.all(_is_number):
		_ctx.error(field_path(key), "esperada lista com 3 números [x, y, z]")
		return Vector3.ZERO
	return Vector3(items[0], items[1], items[2])


## Reader for a nested object. A missing optional object reads as `{}`.
func child(key: String, required: bool = false) -> DictReader:
	var value: Variant = _get_typed(key, required, [TYPE_DICTIONARY], "objeto")
	var reader: DictReader = DictReader.new(value if value != null else {}, _ctx, field_path(key))
	_children.append(reader)
	return reader


## Readers for a list of objects (`parts[0]`, `parts[1]`...). Non-objects are errors.
func child_list(key: String, required: bool = false) -> Array[DictReader]:
	var readers: Array[DictReader] = []
	var value: Variant = _get_typed(key, required, [TYPE_ARRAY], "lista")
	if value == null:
		return readers
	var items: Array = value
	for i: int in items.size():
		var item_field: String = "%s[%d]" % [field_path(key), i]
		if not items[i] is Dictionary:
			_ctx.error(item_field, "esperado objeto, recebido %s" % _type_label(items[i]))
			continue
		var reader: DictReader = DictReader.new(items[i], _ctx, item_field)
		_children.append(reader)
		readers.append(reader)
	return readers


## Checks `schema` and `schema_version` (doc 03 §1).
func check_header(schema_name: String, current_version: int) -> void:
	var found: String = text(KEY_SCHEMA, true)
	if not found.is_empty() and found != schema_name:
		_ctx.error(field_path(KEY_SCHEMA), "esperado '%s', encontrado '%s'" % [schema_name, found])
	var version: int = integer(KEY_SCHEMA_VERSION, true, current_version, 1)
	if version > current_version:
		_ctx.warning(
			field_path(KEY_SCHEMA_VERSION),
			(
				"versão %d é mais nova que a suportada (%d); campos novos serão ignorados"
				% [version, current_version]
			)
		)


## Keys of this object that were never read (saves keep them instead of warning).
func unread_keys() -> PackedStringArray:
	var result: PackedStringArray = []
	for key: String in keys():
		if not _used.has(key):
			result.append(key)
	return result


## Unread keys and their raw values (marks them as read).
func take_unread() -> Dictionary:
	var result: Dictionary = {}
	for key: String in unread_keys():
		result[key] = raw(key)
	return result


## Reports keys that were never read as unknown fields, here and in nested readers.
func finish() -> void:
	for key: String in keys():
		if not _used.has(key):
			_ctx.warning(field_path(key), "campo desconhecido (ignorado)")
	for reader: DictReader in _children:
		reader.finish()


func _get_typed(key: String, required: bool, types: Array[int], type_label: String) -> Variant:
	_used[key] = true
	if not _data.has(key) or _data[key] == null:
		if required:
			_ctx.error(field_path(key), "campo obrigatório ausente")
		return null
	var value: Variant = _data[key]
	if not types.has(typeof(value)):
		_ctx.error(field_path(key), "esperado %s, recebido %s" % [type_label, _type_label(value)])
		return null
	return value


func _clamped(key: String, value: float, min_value: float, max_value: float) -> float:
	var clamped: float = clampf(value, min_value, max_value)
	if clamped != value:
		_ctx.warning(
			field_path(key),
			"valor %s fora da faixa [%s, %s]; usando %s" % [value, min_value, max_value, clamped]
		)
	return clamped


func _checked_id(field: String, value: String, expected_type: String) -> String:
	var problem: String = ContentId.validation_error(value)
	if not problem.is_empty():
		_ctx.error(field, "%s: '%s'" % [problem, value])
		return ""
	if not expected_type.is_empty() and not value.begins_with(expected_type + ":"):
		_ctx.error(field, "esperado ID do tipo '%s', recebido '%s'" % [expected_type, value])
		return ""
	return value


static func _is_number(value: Variant) -> bool:
	return value is float or value is int


static func _type_label(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING:
			return "texto"
		TYPE_FLOAT, TYPE_INT:
			return "número"
		TYPE_BOOL:
			return "verdadeiro/falso"
		TYPE_ARRAY:
			return "lista"
		TYPE_DICTIONARY:
			return "objeto"
	return "valor de tipo %s" % type_string(typeof(value))


static func _color_re() -> RegEx:
	if _color_regex == null:
		_color_regex = RegEx.create_from_string(COLOR_PATTERN)
	return _color_regex


static func _unlock_re() -> RegEx:
	if _unlock_regex == null:
		_unlock_regex = RegEx.create_from_string(UNLOCK_PATTERN)
	return _unlock_regex
