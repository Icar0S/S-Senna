class_name TuningStore
extends RefCounted
## Saves what the F2 panel tuned: the global constants (`handling_global.json`)
## or one car's `tuning_overrides` (in its `car.json`). Works when the content
## folder is writable: running from source, or the Studio with `--content-dir`.
## Exported games keep `res://` read-only, so saving reports an error there.

const DEFAULT_GLOBALS_FILE: String = "res://content/packs/base/handling_global.json"
const DECIMALS: float = 0.0001

## Reason of the last failure (pt-BR).
static var last_error: String = ""


## Writes [param globals] to [param path] (the file they were loaded from).
static func save_globals(globals: HandlingGlobals, path: String = "") -> Error:
	var target: String = path if not path.is_empty() else DEFAULT_GLOBALS_FILE
	return _write(target, globals.to_dict())


## Stores [param overrides] (VehicleParams field -> value) in the car's `car.json`
## and in the loaded definition. An empty dictionary removes the field.
static func save_car_overrides(car: CarDef, overrides: Dictionary) -> Error:
	last_error = ""
	if car.source_file.is_empty() or not FileAccess.file_exists(car.source_file):
		last_error = "car.json do carro não encontrado"
		return ERR_FILE_NOT_FOUND
	var json: JSON = JSON.new()
	if (
		json.parse(FileAccess.get_file_as_string(car.source_file)) != OK
		or not json.data is Dictionary
	):
		last_error = "car.json inválido"
		return ERR_PARSE_ERROR
	var data: Dictionary = json.data
	var rounded: Dictionary = {}
	for field: Variant in overrides:
		rounded[str(field)] = snappedf(float(overrides[field]), DECIMALS)
	if rounded.is_empty():
		data.erase("tuning_overrides")
	else:
		data["tuning_overrides"] = rounded
	var error: Error = _write(car.source_file, data)
	if error == OK:
		car.tuning_overrides = rounded
	return error


static func _write(path: String, data: Dictionary) -> Error:
	last_error = ""
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var error: Error = FileAccess.get_open_error()
		last_error = (
			"%s não pode ser gravado (%s). Rode do código-fonte ou use --content-dir."
			% [path, error_string(error)]
		)
		return error
	file.store_string(JSON.stringify(data, "  ", false) + "\n")
	file.close()
	return OK
