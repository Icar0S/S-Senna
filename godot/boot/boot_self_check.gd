class_name BootSelfCheck
extends RefCounted
## Reports what is inside the running build. Printed by the boot scene when the
## user argument `--self-check` is given; `tools/ci/export.sh` reads it to prove
## that exported builds contain the content JSON (and that the `base` pack is
## listed and its car model loads), and that Game builds do not contain the Studio.

const OUTPUT_PREFIX: String = "SELF_CHECK "
const CONTENT_PROBE: String = "res://content/packs/base/pack.json"
## A car that must exist in every build; its model is loaded to prove models work.
const PROBE_CAR: String = "car:base/prototipo"


## Returns a JSON-friendly dictionary describing the build.
static func run(mode: BootResolver.Mode) -> Dictionary:
	var counts: Dictionary = ContentDB.get_library().get_counts()
	return {
		"mode": BootResolver.mode_name(mode),
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"content_json": is_content_json_readable(CONTENT_PROBE),
		"content_packs": counts["packs"],
		"content_cars": counts["cars"],
		"content_errors": ContentDB.get_report().error_count(),
		"probe_car_model": can_load_car_model(PROBE_CAR),
		"studio_present": ResourceLoader.exists(BootResolver.STUDIO_SCENE),
		"tests_present": DirAccess.dir_exists_absolute("res://tests"),
	}


## True when the car is in [ContentDB] and its model loads.
static func can_load_car_model(car_id: String) -> bool:
	var car: CarDef = ContentDB.get_car(car_id)
	if car == null:
		return false
	var model: Node3D = ModelLoader.load_model(car.model_path)
	if model == null:
		return false
	model.free()
	return true


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
