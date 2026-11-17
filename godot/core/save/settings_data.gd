class_name SettingsData
extends RefCounted
## Game settings (`settings.json`, doc 03 §15). Pure data with defaults for the
## first run; the `Settings` autoload loads, saves and applies it.

const SCHEMA: String = "settings"
const WINDOW_MODES: PackedStringArray = ["windowed", "fullscreen", "exclusive_fullscreen"]
const QUALITY_LEVELS: PackedStringArray = ["baixo", "medio", "alto", "ultra"]
const UPSCALERS: PackedStringArray = ["off", "fsr1", "fsr2"]
const SPLIT_LAYOUTS: PackedStringArray = ["horizontal", "vertical"]
const UNITS: PackedStringArray = ["kmh", "mph"]
const LANGUAGES: PackedStringArray = ["pt_BR", "en"]
## Audio bus name -> volume (0..1). Buses other than Master are created later (Etapa 12).
const AUDIO_BUSES: PackedStringArray = ["master", "music", "sfx", "engine", "ui"]

var window_mode: String = "windowed"
var resolution: Vector2i = Vector2i(1280, 720)
var vsync: bool = true
## 0 = no limit.
var fps_limit: int = 0
var quality: String = "alto"
var render_scale: float = 1.0
var upscaler: String = "off"
var split_layout: String = "horizontal"
var fov: float = 75.0
## Bus -> 0..1.
var volumes: Dictionary = {"master": 0.9, "music": 0.6, "sfx": 0.8, "engine": 0.9, "ui": 0.7}
var music_folder: String = ""
var units: String = "kmh"
var language: String = "pt_BR"
var hud_scale: float = 1.0
var vibration: bool = true
## Mod pack IDs to load from `<saves>/mods/`.
var enabled_mods: PackedStringArray = []
var extra: Dictionary = {}


static func from_dict(data: Dictionary, ctx: LoadContext) -> SettingsData:
	var reader: DictReader = DictReader.new(data, ctx)
	reader.raw("schema")
	reader.raw("schema_version")
	var settings: SettingsData = SettingsData.new()
	var video: DictReader = reader.child("video")
	settings.window_mode = video.enum_value("window_mode", WINDOW_MODES, false, "windowed")
	settings.resolution = _resolution(video.raw("resolution"), settings.resolution)
	settings.vsync = video.boolean("vsync", true)
	settings.fps_limit = video.integer("fps_limit", false, 0, 0, 1000)
	settings.quality = video.enum_value("quality", QUALITY_LEVELS, false, "alto")
	settings.render_scale = video.number("render_scale", false, 1.0, 0.5, 2.0)
	settings.upscaler = video.enum_value("upscaler", UPSCALERS, false, "off")
	settings.split_layout = video.enum_value("split_layout", SPLIT_LAYOUTS, false, "horizontal")
	settings.fov = video.number("fov", false, 75.0, 50.0, 110.0)
	var audio: DictReader = reader.child("audio")
	for bus: String in AUDIO_BUSES:
		settings.volumes[bus] = audio.number(bus, false, float(settings.volumes[bus]), 0.0, 1.0)
	settings.music_folder = audio.text("music_folder")
	var gameplay: DictReader = reader.child("gameplay")
	settings.units = gameplay.enum_value("units", UNITS, false, "kmh")
	settings.language = gameplay.enum_value("language", LANGUAGES, false, "pt_BR")
	settings.hud_scale = gameplay.number("hud_scale", false, 1.0, 0.5, 2.0)
	settings.vibration = gameplay.boolean("vibration", true)
	settings.enabled_mods = reader.child("mods").string_list("enabled")
	settings.extra = SaveValues.normalize(reader.take_unread())
	return settings


func to_dict() -> Dictionary:
	var audio: Dictionary = volumes.duplicate()
	audio["music_folder"] = music_folder
	var data: Dictionary = {
		"schema": SCHEMA,
		"schema_version": Migrations.CURRENT_VERSIONS[SCHEMA],
		"video":
		{
			"window_mode": window_mode,
			"resolution": [resolution.x, resolution.y],
			"vsync": vsync,
			"fps_limit": fps_limit,
			"quality": quality,
			"render_scale": render_scale,
			"upscaler": upscaler,
			"split_layout": split_layout,
			"fov": fov,
		},
		"audio": audio,
		"gameplay":
		{"units": units, "language": language, "hud_scale": hud_scale, "vibration": vibration},
		"mods": {"enabled": Array(enabled_mods)},
	}
	return SaveValues.with_extra(data, extra.duplicate(true))


static func _resolution(value: Variant, default_value: Vector2i) -> Vector2i:
	if value is Array and (value as Array).size() == 2:
		var items: Array = value
		if (items[0] is float or items[0] is int) and (items[1] is float or items[1] is int):
			var size: Vector2i = Vector2i(int(items[0]), int(items[1]))
			if size.x >= 640 and size.y >= 360:
				return size
	return default_value
