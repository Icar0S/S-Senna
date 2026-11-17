extends Node
## Autoload `Settings`: `settings.json` and `input.json` in memory, saved safely,
## and applied to the engine (window, vsync, FPS limit, volumes, language).
## The first run writes the defaults so players can find and edit the file.

signal settings_changed

const LOG_CONTEXT: String = "Settings"
const BACKUPS: int = 1
## Command line options that already decide the window (keep them, don't apply ours).
const WINDOW_ARGS: PackedStringArray = [
	"--windowed", "-w", "--fullscreen", "-f", "--maximized", "-m", "--resolution", "--position"
]
const BUS_NAMES: Dictionary = {
	"master": "Master", "music": "Music", "sfx": "SFX", "engine": "Engine", "ui": "UI"
}
const SILENCE: float = 0.0001

var data: SettingsData = SettingsData.new()
var input: InputBindingsData = InputBindingsData.new()

var _base_dir: String = ""
var _ops: FileOps = FileOps.new()
var _migrations: Migrations = Migrations.new()


func _ready() -> void:
	if _base_dir.is_empty():
		configure(SavePaths.detect_base_dir())
		load_all()
		apply()


## Points at [param base_dir] (tests use a temporary folder). Does not load.
func configure(base_dir: String, ops: FileOps = null) -> void:
	_base_dir = base_dir
	_ops = ops if ops != null else FileOps.new()


func get_base_dir() -> String:
	return _base_dir


func settings_path() -> String:
	return _base_dir.path_join(SavePaths.SETTINGS_FILE)


func input_path() -> String:
	return _base_dir.path_join(SavePaths.INPUT_FILE)


## Loads both files; missing or broken files become defaults (and are rewritten).
func load_all() -> void:
	var settings_dict: Dictionary = _read(settings_path(), SettingsData.SCHEMA)
	data = SettingsData.from_dict(settings_dict, LoadContext.new(null, settings_path()))
	if settings_dict.is_empty():
		save_settings()
	var input_dict: Dictionary = _read(input_path(), InputBindingsData.SCHEMA)
	input = InputBindingsData.from_dict(input_dict, LoadContext.new(null, input_path()))
	if input_dict.is_empty():
		save_input()


func save_settings() -> Error:
	return _write(settings_path(), data.to_dict())


func save_input() -> Error:
	return _write(input_path(), input.to_dict())


## Applies everything and tells listeners.
func apply() -> void:
	apply_language()
	apply_audio()
	apply_video()
	settings_changed.emit()


func apply_language() -> void:
	TranslationServer.set_locale(data.language)


## Sets the volume of every bus that exists (the others are created in Etapa 12).
func apply_audio() -> void:
	for key: String in data.volumes:
		var index: int = AudioServer.get_bus_index(BUS_NAMES.get(key, ""))
		if index < 0:
			continue
		var volume: float = float(data.volumes[key])
		AudioServer.set_bus_mute(index, volume <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, SILENCE)))


func apply_video() -> void:
	Engine.max_fps = data.fps_limit
	if DisplayServer.get_name() == "headless":
		return
	var vsync_mode: DisplayServer.VSyncMode = (
		DisplayServer.VSYNC_ENABLED if data.vsync else DisplayServer.VSYNC_DISABLED
	)
	DisplayServer.window_set_vsync_mode(vsync_mode)
	var root: Window = get_tree().root
	root.scaling_3d_scale = data.render_scale
	root.scaling_3d_mode = _scaling_mode(data.upscaler)
	if _window_decided_by_cmdline():
		return
	match data.window_mode:
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"exclusive_fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(data.resolution)


func _scaling_mode(upscaler: String) -> Viewport.Scaling3DMode:
	# FSR needs Forward+/Mobile; the light mode (Compatibility) only scales bilinearly.
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return Viewport.SCALING_3D_MODE_BILINEAR
	match upscaler:
		"fsr1":
			return Viewport.SCALING_3D_MODE_FSR
		"fsr2":
			return Viewport.SCALING_3D_MODE_FSR2
	return Viewport.SCALING_3D_MODE_BILINEAR


func _window_decided_by_cmdline() -> bool:
	for arg: String in OS.get_cmdline_args():
		if WINDOW_ARGS.has(arg.get_slice("=", 0)):
			return true
	return false


## Reads a settings-like file (falling back to its backup); `{}` if unusable.
func _read(path: String, schema: String) -> Dictionary:
	for candidate: String in SafeFile.candidates(path, BACKUPS):
		var text: Variant = _ops.read_text(candidate)
		if text == null:
			continue
		var json: JSON = JSON.new()
		if json.parse(str(text)) != OK or not json.data is Dictionary:
			Log.warn("%s inválido; tentando a cópia de segurança" % candidate, LOG_CONTEXT)
			continue
		var parsed: Dictionary = json.data
		var version: int = int(parsed.get("schema_version", 1))
		if version < _migrations.current_version(schema):
			parsed = _migrations.apply(parsed, schema, version)
		if not parsed.is_empty():
			return parsed
	return {}


func _write(path: String, content: Dictionary) -> Error:
	var text: String = JSON.stringify(content, "  ", false) + "\n"
	var error: Error = SafeFile.write(_ops, path, text, BACKUPS)
	if error != OK:
		Log.error("Não foi possível salvar %s (%s)" % [path, error_string(error)], LOG_CONTEXT)
	return error
