class_name Migrations
extends RefCounted
## Applies save migrations in sequence (v1 -> v2 -> v3...) BEFORE the data is
## turned into classes (doc 03 §16).

const SCHEMA_PROFILE: String = "profile"
const SCHEMA_SETTINGS: String = "settings"
const SCHEMA_INPUT: String = "input"

## Current version of each save format.
const CURRENT_VERSIONS: Dictionary = {
	SCHEMA_PROFILE: 1,
	SCHEMA_SETTINGS: 1,
	SCHEMA_INPUT: 1,
}

## Schema -> { from_version -> script path }. Empty while every format is at v1.
const REGISTRY: Dictionary = {
	SCHEMA_PROFILE: {},
	SCHEMA_SETTINGS: {},
	SCHEMA_INPUT: {},
}

var _registry: Dictionary = {}
var _current_versions: Dictionary = {}


## [param registry] / [param current_versions] default to the game's own; tests
## pass their own (e.g. with the example migration).
func _init(
	registry: Dictionary = REGISTRY, current_versions: Dictionary = CURRENT_VERSIONS
) -> void:
	_registry = registry
	_current_versions = current_versions


func current_version(schema: String) -> int:
	return int(_current_versions.get(schema, 1))


## True when [param from_version] can be brought to the current version.
func can_migrate(schema: String, from_version: int) -> bool:
	var steps: Dictionary = _registry.get(schema, {})
	for version: int in range(from_version, current_version(schema)):
		if not steps.has(version):
			return false
	return true


## Migrates [param data] from [param from_version] to the current version.
## Returns `{}` when a step is missing (the caller treats the save as unreadable).
func apply(data: Dictionary, schema: String, from_version: int) -> Dictionary:
	if not can_migrate(schema, from_version):
		return {}
	var steps: Dictionary = _registry.get(schema, {})
	var result: Dictionary = data
	for version: int in range(from_version, current_version(schema)):
		var step: SaveMigration = _load_step(steps[version])
		if step == null or step.from_version() != version:
			return {}
		result = step.migrate(result)
	return result


static func _load_step(source: Variant) -> SaveMigration:
	if source is SaveMigration:
		return source
	if source is String:
		var script: GDScript = load(source) as GDScript
		if script != null:
			return script.new() as SaveMigration
	return null
