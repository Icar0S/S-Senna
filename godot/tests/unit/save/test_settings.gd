extends GdUnitTestSuite
## Settings and input bindings: defaults, round trip, broken files, applying.

const SETTINGS_SCRIPT: String = "res://core/save/settings.gd"

var _base: String = ""
var _settings: Node = null


func before_test() -> void:
	_base = ProjectSettings.globalize_path(create_temp_dir("configuracoes"))
	_settings = auto_free((load(SETTINGS_SCRIPT) as GDScript).new())
	_settings.configure(_base)


func after_test() -> void:
	clean_temp_dir()
	# Put the real settings back on the engine.
	Settings.apply()


func test_first_run_writes_defaults() -> void:
	_settings.load_all()
	assert_bool(FileAccess.file_exists(_base.path_join("settings.json"))).is_true()
	assert_bool(FileAccess.file_exists(_base.path_join("input.json"))).is_true()
	var data: SettingsData = _settings.data
	assert_str(data.language).is_equal("pt_BR")
	assert_str(data.window_mode).is_equal("windowed")
	assert_float(float(data.volumes["master"])).is_equal(0.9)


func test_round_trip() -> void:
	var data: SettingsData = SettingsData.new()
	data.window_mode = "fullscreen"
	data.resolution = Vector2i(1920, 1080)
	data.fps_limit = 144
	data.volumes["music"] = 0.25
	data.language = "en"
	data.enabled_mods = PackedStringArray(["meu_mod"])
	data.extra = {"campo_novo": true}
	var text: String = JSON.stringify(data.to_dict())
	var ctx: LoadContext = LoadContext.new()
	var loaded: SettingsData = SettingsData.from_dict(JSON.parse_string(text), ctx)
	assert_bool(ctx.report.has_errors()).is_false()
	assert_dict(loaded.to_dict()).is_equal(data.to_dict())
	assert_object(loaded.resolution).is_equal(Vector2i(1920, 1080))


func test_bad_values_fall_back_to_defaults() -> void:
	var ctx: LoadContext = LoadContext.new()
	var data: Dictionary = {
		"video": {"window_mode": "gigante", "resolution": [10, 10], "fps_limit": -5},
		"audio": {"master": 3.0},
		"gameplay": {"language": "klingon"},
	}
	var loaded: SettingsData = SettingsData.from_dict(data, ctx)
	assert_str(loaded.window_mode).is_equal("windowed")
	assert_object(loaded.resolution).is_equal(Vector2i(1280, 720))
	assert_int(loaded.fps_limit).is_equal(0)
	assert_float(float(loaded.volumes["master"])).is_equal(1.0)
	assert_str(loaded.language).is_equal("pt_BR")


func test_saved_settings_load_back_and_broken_file_uses_backup() -> void:
	_settings.load_all()
	_settings.data.fps_limit = 90
	assert_int(_settings.save_settings()).is_equal(OK)
	_settings.data.fps_limit = 60
	assert_int(_settings.save_settings()).is_equal(OK)
	TestContent.write_text(_base.path_join("settings.json"), "{ quebrado")
	var other: Node = auto_free((load(SETTINGS_SCRIPT) as GDScript).new())
	other.configure(_base)
	other.load_all()
	assert_int(other.data.fps_limit).is_equal(90)


func test_input_bindings_round_trip() -> void:
	var input: InputBindingsData = InputBindingsData.new()
	input.remember_device("030000005e040000ea02000000007801", "Xbox Wireless Controller", 1)
	input.set_bindings("p1", "throttle", PackedStringArray(["joy_axis:5+", "key:W"]))
	input.set_bindings("p2", "throttle", PackedStringArray(["key:UP"]))
	var loaded: InputBindingsData = InputBindingsData.from_dict(
		JSON.parse_string(JSON.stringify(input.to_dict())), LoadContext.new()
	)
	assert_dict(loaded.to_dict()).is_equal(input.to_dict())
	assert_array(Array(loaded.get_bindings("p1", "throttle"))).is_equal(["joy_axis:5+", "key:W"])
	(
		assert_int(int(loaded.known_devices["030000005e040000ea02000000007801"]["last_player"]))
		. is_equal(1)
	)
	assert_array(Array(loaded.get_bindings("p3", "brake"))).is_empty()


func test_apply_sets_language_and_volume() -> void:
	_settings.load_all()
	_settings.data.language = "en"
	_settings.data.volumes["master"] = 0.5
	_settings.data.fps_limit = 30
	_settings.apply()
	assert_str(TranslationServer.get_locale()).is_equal("en")
	assert_str(tr("SAVE_DEBUG_CREATE")).is_equal("Create profile")
	assert_float(AudioServer.get_bus_volume_db(0)).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_int(Engine.max_fps).is_equal(30)
	_settings.data.language = "pt_BR"
	_settings.apply_language()
	assert_str(tr("SAVE_DEBUG_CREATE")).is_equal("Criar perfil")
