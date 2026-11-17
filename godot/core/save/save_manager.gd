extends Node
## Autoload `SaveManager`: profiles, autosave and the "saving" signals.
##
## All the file logic is in [ProfileStore]; this node adds what needs the scene tree:
## grouped autosave ([method request_save], ~1 s), saving pending changes when the
## game closes, and signals for the UI (saving icon, warnings).

signal saved(profile_id: String)
signal save_failed(profile_id: String, message: String)
signal save_recovered(profile_id: String, source: String)

const LOG_CONTEXT: String = "SaveManager"
const AUTOSAVE_DELAY_MS: int = 1000

var _store: ProfileStore = null
var _scheduler: SaveScheduler = SaveScheduler.new()
## Profiles loaded in this session: id -> ProfileData.
var _loaded: Dictionary = {}
## Profiles changed but not saved yet: id -> reason.
var _dirty: Dictionary = {}


func _ready() -> void:
	if _store == null:
		configure(SavePaths.detect_base_dir())
	Log.info("Pasta de saves: %s" % get_base_dir(), LOG_CONTEXT)


## Points the manager at [param base_dir] (tests use a temporary folder).
func configure(base_dir: String, ops: FileOps = null, migrations: Migrations = null) -> void:
	_store = ProfileStore.new(base_dir, ops, migrations)
	_scheduler.delay_ms = AUTOSAVE_DELAY_MS
	_loaded.clear()
	_dirty.clear()
	_store.ops.make_dir(_store.profiles_dir())


func get_base_dir() -> String:
	return _store.base_dir


func get_store() -> ProfileStore:
	return _store


func list_profiles() -> Array[ProfileStore.Summary]:
	return _store.list_profiles()


## Creates, saves and loads a new profile (money from `economy.json`).
func create_profile(profile_name: String, sandbox: bool) -> ProfileData:
	var economy: EconomyDef = ContentDB.get_library().get_economy()
	var money: int = economy.starting_money if economy != null else 0
	var profile: ProfileData = _store.create_profile(profile_name, sandbox, money)
	if profile == null:
		_report_failure("", _store.last_error)
		return null
	_loaded[profile.id] = profile
	Log.info("Perfil criado: %s (%s)" % [profile.name, profile.id], LOG_CONTEXT)
	return profile


## Loads a profile (or returns the one already loaded). Null when no copy is readable.
func load_profile(profile_id: String) -> ProfileData:
	if _loaded.has(profile_id):
		return _loaded[profile_id]
	var result: ProfileStore.LoadResult = _store.load_profile(profile_id)
	for problem: String in result.problems:
		Log.warn("Perfil %s: %s" % [profile_id, problem], LOG_CONTEXT)
	if not result.ok():
		_report_failure(profile_id, "nenhuma cópia legível do perfil")
		return null
	if result.recovered:
		Log.warn("Perfil %s recuperado de %s" % [profile_id, result.source], LOG_CONTEXT)
		save_recovered.emit(profile_id, result.source)
	if result.read_only:
		Log.warn("Perfil %s é de uma versão mais nova: somente leitura" % profile_id, LOG_CONTEXT)
	_loaded[profile_id] = result.profile
	return result.profile


func get_loaded(profile_id: String) -> ProfileData:
	return _loaded.get(profile_id)


## Saves now. Returns true on success (emits [signal saved] or [signal save_failed]).
func save_profile(profile_id: String) -> bool:
	var profile: ProfileData = _loaded.get(profile_id)
	if profile == null:
		_report_failure(profile_id, "perfil não carregado")
		return false
	if _store.save_profile(profile) != OK:
		_report_failure(profile_id, _store.last_error)
		return false
	_dirty.erase(profile_id)
	saved.emit(profile_id)
	return true


## Asks for a save; requests within ~1 s become a single write.
func request_save(profile_id: String, reason: String = "") -> void:
	mark_dirty(profile_id, reason)
	_scheduler.request(profile_id, Time.get_ticks_msec())


## Marks a change that must be saved at the latest when the game closes.
func mark_dirty(profile_id: String, reason: String = "") -> void:
	_dirty[profile_id] = reason


func is_dirty(profile_id: String) -> bool:
	return _dirty.has(profile_id)


## Saves every pending or changed profile right now.
func flush() -> void:
	var pending: PackedStringArray = _scheduler.take_all()
	for profile_id: String in _dirty.keys():
		if not pending.has(profile_id):
			pending.append(profile_id)
	for profile_id: String in pending:
		save_profile(profile_id)


func delete_profile(profile_id: String) -> bool:
	_loaded.erase(profile_id)
	_dirty.erase(profile_id)
	if _store.delete_profile(profile_id) != OK:
		_report_failure(profile_id, _store.last_error)
		return false
	return true


func duplicate_profile(profile_id: String) -> ProfileData:
	flush()
	var copy: ProfileData = _store.duplicate_profile(profile_id)
	if copy == null:
		_report_failure(profile_id, _store.last_error)
		return null
	_loaded[copy.id] = copy
	return copy


func export_profile(profile_id: String, zip_path: String) -> bool:
	flush()
	if _store.export_profile(profile_id, zip_path) != OK:
		_report_failure(profile_id, _store.last_error)
		return false
	return true


func import_profile(zip_path: String) -> ProfileData:
	var result: ProfileStore.LoadResult = _store.import_profile(zip_path)
	if not result.ok():
		_report_failure("", "; ".join(result.problems))
		return null
	_loaded[result.profile.id] = result.profile
	return result.profile


func _process(_delta: float) -> void:
	if not _scheduler.has_pending():
		return
	for profile_id: String in _scheduler.take_due(Time.get_ticks_msec()):
		save_profile(profile_id)


func _notification(what: int) -> void:
	# Closing by the window's X: save what is pending before the game quits.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()


func _exit_tree() -> void:
	# get_tree().quit() and other exits.
	if _store != null:
		flush()


func _report_failure(profile_id: String, message: String) -> void:
	Log.error("Falha ao salvar/carregar %s: %s" % [profile_id, message], LOG_CONTEXT)
	save_failed.emit(profile_id, message)
