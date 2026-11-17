extends Node
## Autoload `ContentDB`: the game's content database.
##
## Scans the packs on start and keeps a [ContentLibrary] (all the logic lives
## there). The Studio calls [method rescan] after changing files.

signal content_reloaded

const LOG_CONTEXT: String = "ContentDB"

var _library: ContentLibrary = ContentLibrary.new()
var _options: ContentScanOptions = null


func _ready() -> void:
	var options: ContentScanOptions = ContentScanOptions.from_cmdline(OS.get_cmdline_user_args())
	# Mods live next to the saves (portable mode included) and load only when enabled.
	options.mods_dir = Settings.get_base_dir().path_join(SavePaths.MODS_DIR)
	options.enabled_mods = Settings.data.enabled_mods
	scan(options)


## Loads the packs found with [param options] and logs the result.
func scan(options: ContentScanOptions) -> ContentReport:
	_options = options
	var started: int = Time.get_ticks_usec()
	var report: ContentReport = _library.scan(options)
	var elapsed_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	var counts: Dictionary = _library.get_counts()
	Log.info(
		(
			"%d pacote(s), %d carro(s), %d peça(s), %d roda(s) em %.1f ms"
			% [counts["packs"], counts["cars"], counts["parts"], counts["wheels"], elapsed_ms]
		),
		LOG_CONTEXT
	)
	for entry: ContentReport.Entry in report.entries:
		if entry.is_error():
			Log.error(entry.to_text(), LOG_CONTEXT)
		else:
			Log.warn(entry.to_text(), LOG_CONTEXT)
	content_reloaded.emit()
	return report


## Scans again with the last options (used by the Studio).
func rescan() -> ContentReport:
	return scan(_options if _options != null else ContentScanOptions.new())


func get_library() -> ContentLibrary:
	return _library


func get_report() -> ContentReport:
	return _library.get_report()


func resolve_id(content_id: String) -> String:
	return _library.resolve_id(content_id)


func get_car(car_id: String) -> CarDef:
	return _library.get_car(car_id)


func list_cars(filter: Callable = Callable()) -> Array[CarDef]:
	return _library.list_cars(filter)


func get_part(part_id: String) -> PartDef:
	return _library.get_part(part_id)


func list_parts_for(car_id: String, slot: String) -> Array[PartDef]:
	return _library.list_parts_for(car_id, slot)


func get_wheel(wheel_id: String) -> WheelDef:
	return _library.get_wheel(wheel_id)


func list_wheels(filter: Callable = Callable()) -> Array[WheelDef]:
	return _library.list_wheels(filter)


func list_vinyls(category: String = "") -> Array[VinylDef]:
	return _library.list_vinyls(category)


func get_track(track_id: String) -> TrackDef:
	return _library.get_track(track_id)


func get_sound(sound_id: String) -> SoundProfileDef:
	return _library.get_sound(sound_id)
