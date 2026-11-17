class_name ProfileStore
extends RefCounted
## Profiles on disk: `<base>/profiles/<id>/profile.json` (+ `.bak1..3`).
## All the save logic (testable); the `SaveManager` autoload wraps it with signals
## and autosave. Never writes over a save made by a newer game version.

const PROFILE_FILE: String = "profile.json"
const BACKUPS: int = 3
const EXPORT_ENTRY: String = "profile.json"
const COPY_SUFFIX: String = " (cópia)"

var base_dir: String = ""
var ops: FileOps = null
var migrations: Migrations = null
## Returns the current time as text (tests inject a fixed clock).
var clock: Callable = SaveEnvelope.now_utc
## Reason of the last failure (pt-BR), for logs and UI.
var last_error: String = ""


## What [method load_profile] found.
class LoadResult:
	extends RefCounted
	var profile: ProfileData = null
	## File actually used (`profile.json`, `profile.json.bak1`...).
	var source: String = ""
	## True when the main file was bad and a backup was used.
	var recovered: bool = false
	var migrated: bool = false
	## Saved by a newer game version: may be shown, must not be saved.
	var read_only: bool = false
	## `saved_at` of the file used.
	var saved_at: String = ""
	## Why each file was refused (pt-BR).
	var problems: PackedStringArray = []

	func ok() -> bool:
		return profile != null


## Light information for profile lists.
class Summary:
	extends RefCounted
	var id: String = ""
	var name: String = ""
	var sandbox: bool = false
	var saved_at: String = ""
	var money: int = 0
	var car_count: int = 0
	var read_only: bool = false


func _init(
	save_base_dir: String, file_ops: FileOps = null, save_migrations: Migrations = null
) -> void:
	base_dir = save_base_dir
	ops = file_ops if file_ops != null else FileOps.new()
	migrations = save_migrations if save_migrations != null else Migrations.new()


func profiles_dir() -> String:
	return base_dir.path_join(SavePaths.PROFILES_DIR)


func profile_path(profile_id: String) -> String:
	return profiles_dir().path_join(profile_id).path_join(PROFILE_FILE)


## Every profile that can be read, sorted by name.
func list_profiles() -> Array[Summary]:
	var result: Array[Summary] = []
	for profile_id: String in ops.list_dirs(profiles_dir()):
		if not ProfileData.is_valid_id(profile_id):
			continue
		var loaded: LoadResult = load_profile(profile_id)
		if not loaded.ok():
			continue
		var summary: Summary = Summary.new()
		summary.id = profile_id
		summary.name = loaded.profile.name
		summary.sandbox = loaded.profile.sandbox
		summary.money = loaded.profile.money
		summary.car_count = loaded.profile.cars.size()
		summary.read_only = loaded.read_only
		summary.saved_at = loaded.saved_at
		result.append(summary)
	result.sort_custom(func(a: Summary, b: Summary) -> bool: return a.name < b.name)
	return result


## Creates and saves a new profile. Returns null if it could not be saved.
func create_profile(profile_name: String, sandbox: bool, starting_money: int = 0) -> ProfileData:
	var profile: ProfileData = ProfileData.new()
	profile.id = new_profile_id()
	profile.name = profile_name
	profile.created_at = str(clock.call())
	profile.sandbox = sandbox
	profile.money = starting_money
	if save_profile(profile) != OK:
		return null
	return profile


## A profile ID not used yet (`p` + 6 hex digits).
func new_profile_id() -> String:
	var candidate: String = ""
	while candidate.is_empty() or ops.dir_exists(profiles_dir().path_join(candidate)):
		candidate = "p%06x" % (randi() & 0xFFFFFF)
	return candidate


## Reads a profile, falling back to the backups when the main file is damaged.
func load_profile(profile_id: String) -> LoadResult:
	var result: LoadResult = LoadResult.new()
	var main_path: String = profile_path(profile_id)
	for candidate: String in SafeFile.candidates(main_path, BACKUPS):
		var text: Variant = ops.read_text(candidate)
		if text == null:
			if candidate == main_path:
				result.problems.append("%s: arquivo não encontrado" % candidate.get_file())
			continue
		var profile: ProfileData = _profile_from_text(text, result, candidate.get_file())
		if profile == null:
			continue
		if profile.id != profile_id:
			profile.id = profile_id
		result.profile = profile
		result.source = candidate.get_file()
		result.recovered = candidate != main_path
		return result
	return result


## Saves [param profile] atomically with backups. Returns OK or the error
## (and fills [member last_error]).
func save_profile(profile: ProfileData) -> Error:
	last_error = ""
	if profile.read_only:
		return _fail(
			ERR_UNAVAILABLE, "perfil salvo por uma versão mais nova do jogo (somente leitura)"
		)
	if not ProfileData.is_valid_id(profile.id):
		return _fail(ERR_INVALID_PARAMETER, "ID de perfil inválido: '%s'" % profile.id)
	var path: String = profile_path(profile.id)
	var on_disk: int = _version_on_disk(path)
	if on_disk > migrations.current_version(Migrations.SCHEMA_PROFILE):
		return _fail(
			ERR_UNAVAILABLE, "o arquivo no disco é de uma versão mais nova; não foi sobrescrito"
		)
	var envelope: Dictionary = SaveEnvelope.wrap(
		Migrations.SCHEMA_PROFILE,
		migrations.current_version(Migrations.SCHEMA_PROFILE),
		profile.to_dict(),
		str(clock.call())
	)
	var error: Error = SafeFile.write(ops, path, SaveEnvelope.to_text(envelope), BACKUPS)
	if error != OK:
		return _fail(error, "não foi possível gravar %s (%s)" % [path, error_string(error)])
	return OK


## Moves the profile folder to `profiles/_lixeira/` (never deletes for real).
func delete_profile(profile_id: String) -> Error:
	last_error = ""
	var folder: String = profiles_dir().path_join(profile_id)
	if not ProfileData.is_valid_id(profile_id) or not ops.dir_exists(folder):
		return _fail(ERR_DOES_NOT_EXIST, "perfil não encontrado: %s" % profile_id)
	var trash: String = profiles_dir().path_join(SavePaths.TRASH_DIR)
	ops.make_dir(trash)
	var stamp: String = str(clock.call()).replace(":", "-")
	var error: Error = ops.rename(folder, trash.path_join("%s_%s" % [profile_id, stamp]))
	if error != OK:
		return _fail(error, "não foi possível mover %s para a lixeira" % profile_id)
	return OK


## Copies a profile under a new ID (name + " (cópia)"). Returns null on failure.
func duplicate_profile(profile_id: String) -> ProfileData:
	var loaded: LoadResult = load_profile(profile_id)
	if not loaded.ok():
		last_error = "perfil não encontrado: %s" % profile_id
		return null
	var copy: ProfileData = ProfileData.from_dict(loaded.profile.to_dict(), LoadContext.new())
	copy.id = new_profile_id()
	copy.name = loaded.profile.name + COPY_SUFFIX
	if save_profile(copy) != OK:
		return null
	return copy


## Writes the profile to a `.zip` (to back it up or move it to another PC).
func export_profile(profile_id: String, zip_path: String) -> Error:
	last_error = ""
	var loaded: LoadResult = load_profile(profile_id)
	if not loaded.ok():
		return _fail(ERR_DOES_NOT_EXIST, "perfil não encontrado: %s" % profile_id)
	var text: Variant = ops.read_text(
		profile_path(profile_id).get_base_dir().path_join(loaded.source)
	)
	var packer: ZIPPacker = ZIPPacker.new()
	var error: Error = packer.open(zip_path)
	if error == OK:
		error = packer.start_file(EXPORT_ENTRY)
	if error == OK:
		error = packer.write_file(str(text).to_utf8_buffer())
		packer.close_file()
	packer.close()
	if error != OK:
		return _fail(error, "não foi possível exportar para %s" % zip_path)
	return OK


## Reads a `.zip` made by [method export_profile] and saves it as a new profile
## (a new ID if the original is already in use).
func import_profile(zip_path: String) -> LoadResult:
	var result: LoadResult = LoadResult.new()
	var reader: ZIPReader = ZIPReader.new()
	if reader.open(zip_path) != OK:
		result.problems.append("não foi possível abrir %s" % zip_path)
		return result
	var files: PackedStringArray = reader.get_files()
	if not files.has(EXPORT_ENTRY):
		reader.close()
		result.problems.append("o arquivo não contém %s" % EXPORT_ENTRY)
		return result
	var text: String = reader.read_file(EXPORT_ENTRY).get_string_from_utf8()
	reader.close()
	var profile: ProfileData = _profile_from_text(text, result, zip_path.get_file())
	if profile == null:
		return result
	if result.read_only:
		result.problems.append(
			"save de uma versão mais nova do jogo; atualize o jogo para importar"
		)
		result.profile = null
		return result
	if (
		not ProfileData.is_valid_id(profile.id)
		or ops.dir_exists(profiles_dir().path_join(profile.id))
	):
		profile.id = new_profile_id()
	if save_profile(profile) != OK:
		result.problems.append(last_error)
		return result
	result.profile = profile
	result.source = zip_path.get_file()
	return result


## Parses one file's text; fills [param result] flags/problems. Null when unusable.
func _profile_from_text(text: String, result: LoadResult, label: String) -> ProfileData:
	var problem: Array = []
	var envelope: Dictionary = SaveEnvelope.parse(text, Migrations.SCHEMA_PROFILE, problem)
	if envelope.is_empty():
		result.problems.append("%s: %s" % [label, problem[0]])
		return null
	var version: int = SaveEnvelope.version_of(envelope)
	var current: int = migrations.current_version(Migrations.SCHEMA_PROFILE)
	var data: Dictionary = envelope[SaveEnvelope.KEY_DATA]
	result.saved_at = str(envelope.get(SaveEnvelope.KEY_SAVED_AT, ""))
	if version < current:
		data = migrations.apply(data, Migrations.SCHEMA_PROFILE, version)
		if data.is_empty():
			result.problems.append("%s: sem migração da versão %d" % [label, version])
			return null
		result.migrated = true
	var profile: ProfileData = ProfileData.from_dict(data, LoadContext.new(null, label))
	if version > current:
		profile.read_only = true
		result.read_only = true
	return profile


func _version_on_disk(path: String) -> int:
	var text: Variant = ops.read_text(path)
	if text == null:
		return 0
	var parsed: Variant = JSON.parse_string(str(text)) if not str(text).is_empty() else null
	if parsed is Dictionary:
		return int((parsed as Dictionary).get(SaveEnvelope.KEY_VERSION, 0))
	return 0


func _fail(error: Error, message: String) -> Error:
	last_error = message
	return error
