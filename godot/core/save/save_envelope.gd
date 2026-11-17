class_name SaveEnvelope
extends RefCounted
## The wrapper of a profile file (doc 03 §14):
## `{schema, schema_version, game_version, saved_at, checksum, data}`.
##
## The checksum is SHA-256 of the *canonical* text of `data`. Canonical means
## "stringify -> parse -> stringify with sorted keys": after reading a file every
## number is a float (`2026` comes back as `2026.0`), so hashing the raw text of the
## original dictionary would never match on load.

const CHECKSUM_PREFIX: String = "sha256:"
const KEY_SCHEMA: String = "schema"
const KEY_VERSION: String = "schema_version"
const KEY_GAME_VERSION: String = "game_version"
const KEY_SAVED_AT: String = "saved_at"
const KEY_CHECKSUM: String = "checksum"
const KEY_DATA: String = "data"


## Builds the envelope for [param data].
static func wrap(schema: String, version: int, data: Dictionary, saved_at: String) -> Dictionary:
	return {
		KEY_SCHEMA: schema,
		KEY_VERSION: version,
		KEY_GAME_VERSION: str(ProjectSettings.get_setting("application/config/version", "")),
		KEY_SAVED_AT: saved_at,
		KEY_CHECKSUM: checksum(data),
		KEY_DATA: data,
	}


## Text written to disk (indented, so a person can read and fix it if needed).
static func to_text(envelope: Dictionary) -> String:
	return JSON.stringify(envelope, "  ", false) + "\n"


static func checksum(data: Dictionary) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical_text(data).to_utf8_buffer())
	return CHECKSUM_PREFIX + context.finish().hex_encode()


static func canonical_text(data: Dictionary) -> String:
	var reparsed: Variant = JSON.parse_string(JSON.stringify(data))
	return JSON.stringify(reparsed, "", true)


## Parses [param text]. Returns the envelope, or `{}` when the text is not a
## valid envelope of [param schema] (bad JSON, missing data, wrong checksum).
## [param problem] receives the reason, in pt-BR.
static func parse(text: String, schema: String, problem: Array) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		problem.append("JSON inválido na linha %d" % json.get_error_line())
		return {}
	if not json.data is Dictionary:
		problem.append("o arquivo não contém um objeto JSON")
		return {}
	var envelope: Dictionary = json.data
	if str(envelope.get(KEY_SCHEMA, "")) != schema:
		problem.append("tipo de arquivo inesperado (esperado '%s')" % schema)
		return {}
	var version: Variant = envelope.get(KEY_VERSION)
	if not (version is float or version is int) or int(version) < 1:
		problem.append("schema_version ausente ou inválida")
		return {}
	if not envelope.get(KEY_DATA) is Dictionary:
		problem.append("campo 'data' ausente")
		return {}
	if str(envelope.get(KEY_CHECKSUM, "")) != checksum(envelope[KEY_DATA]):
		problem.append("checksum não confere (arquivo alterado ou corrompido)")
		return {}
	return envelope


static func version_of(envelope: Dictionary) -> int:
	return int(envelope.get(KEY_VERSION, 0))


## Current UTC time as `2026-11-15T21:03:00Z`.
static func now_utc() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"
