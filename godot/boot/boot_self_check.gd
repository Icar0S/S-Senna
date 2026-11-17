class_name BootSelfCheck
extends RefCounted
## Reports what is inside the running build. Printed by the boot scene when the
## user argument `--self-check` is given; `tools/ci/export.sh` reads it to prove
## that exported builds contain the content JSON and that Game builds do not
## contain the Studio.

const OUTPUT_PREFIX: String = "SELF_CHECK "
const CONTENT_PROBE: String = "res://content/packs/base/pack.json"


## Returns a JSON-friendly dictionary describing the build.
static func run(mode: BootResolver.Mode) -> Dictionary:
	return {
		"mode": BootResolver.mode_name(mode),
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"content_json": is_content_json_readable(CONTENT_PROBE),
		"studio_present": ResourceLoader.exists(BootResolver.STUDIO_SCENE),
		"tests_present": DirAccess.dir_exists_absolute("res://tests"),
	}


## True when [param path] can be opened with `FileAccess` and parsed as a JSON object.
static func is_content_json_readable(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	# JSON instance instead of JSON.parse_string(): that one logs an engine error on bad input.
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return false
	return json.data is Dictionary


## Formats the single line printed to stdout.
static func format_output(report: Dictionary) -> String:
	return OUTPUT_PREFIX + JSON.stringify(report, "", true)
