class_name ContentId
extends RefCounted
## Content ID `type:pack/path` (e.g. `car:base/mazda_rx7_fd`), see doc 03 §2.
## Lowercase letters, digits, `_` and `-`; the path may have several `/` segments.

const TYPE_CAR: String = "car"
const TYPE_PART: String = "part"
const TYPE_WHEEL: String = "wheel"
const TYPE_VINYL: String = "vinyl"
const TYPE_PAINT: String = "paint"
const TYPE_SOUND: String = "sound"
const TYPE_TRACK: String = "track"
const TYPES: PackedStringArray = [
	TYPE_CAR, TYPE_PART, TYPE_WHEEL, TYPE_VINYL, TYPE_PAINT, TYPE_SOUND, TYPE_TRACK
]

const NAME_PATTERN: String = "^[a-z0-9_-]+$"
const PATH_PATTERN: String = "^[a-z0-9_-]+(/[a-z0-9_-]+)*$"

static var _name_regex: RegEx = null
static var _path_regex: RegEx = null

var type: String = ""
var pack: String = ""
var path: String = ""


## Parses [param text]. Returns null when it is not a valid ID
## (use [method validation_error] to know why).
static func parse(text: String) -> ContentId:
	if not validation_error(text).is_empty():
		return null
	var colon: int = text.find(":")
	var slash: int = text.find("/", colon)
	var id: ContentId = ContentId.new()
	id.type = text.substr(0, colon)
	id.pack = text.substr(colon + 1, slash - colon - 1)
	id.path = text.substr(slash + 1)
	return id


## Empty string when [param text] is a valid ID; otherwise the reason (pt-BR).
static func validation_error(text: String) -> String:
	if text.is_empty():
		return "ID vazio"
	var colon: int = text.find(":")
	if colon <= 0:
		return "ID sem tipo (formato esperado: tipo:pacote/caminho)"
	var type_name: String = text.substr(0, colon)
	if not TYPES.has(type_name):
		return "tipo de ID desconhecido '%s' (válidos: %s)" % [type_name, ", ".join(TYPES)]
	var rest: String = text.substr(colon + 1)
	var slash: int = rest.find("/")
	if slash <= 0:
		return "ID sem pacote ou sem caminho (formato esperado: tipo:pacote/caminho)"
	if not is_valid_name(rest.substr(0, slash)):
		return "nome de pacote inválido (use letras minúsculas, números, _ e -)"
	if not _path_re().search(rest.substr(slash + 1)):
		return "caminho inválido (use letras minúsculas, números, _, - e /)"
	return ""


## True when [param text] is a valid ID (and of [param expected_type], if given).
static func is_valid(text: String, expected_type: String = "") -> bool:
	if not validation_error(text).is_empty():
		return false
	return expected_type.is_empty() or text.begins_with(expected_type + ":")


## True for a pack name or path segment (`[a-z0-9_-]+`).
static func is_valid_name(text: String) -> bool:
	return _name_re().search(text) != null


static func make(type_name: String, pack_name: String, id_path: String) -> String:
	return "%s:%s/%s" % [type_name, pack_name, id_path]


func _to_string() -> String:
	return make(type, pack, path)


static func _name_re() -> RegEx:
	if _name_regex == null:
		_name_regex = RegEx.create_from_string(NAME_PATTERN)
	return _name_regex


static func _path_re() -> RegEx:
	if _path_regex == null:
		_path_regex = RegEx.create_from_string(PATH_PATTERN)
	return _path_regex
