class_name TrackDef
extends RefCounted
## A track (`track.json`, doc 03 §11). The scene itself lives in `game/tracks/`.

const SCHEMA: String = "track"
const SCHEMA_VERSION: int = 1
const FILE_NAME: String = "track.json"
const LAYOUT_TYPES: PackedStringArray = ["circuit", "sprint", "drag", "drift"]

var id: String = ""
var display_name_key: String = ""
var scene_path: String = ""
var time_of_day: String = ""
var weather: String = ""
var layouts: Array[Layout] = []


class Layout:
	extends RefCounted
	var id: String = ""
	var type: String = "circuit"
	## Node path (inside the track scene) that holds Checkpoints, RacingLine and Grid.
	var node: String = ""
	var default_laps: int = 1
	var reversible: bool = false


static func from_dict(data: Dictionary, ctx: LoadContext) -> TrackDef:
	var errors_before: int = ctx.report.error_count()
	var reader: DictReader = DictReader.new(data, ctx)
	reader.check_header(SCHEMA, SCHEMA_VERSION)
	var track: TrackDef = TrackDef.new()
	track.id = reader.content_id("id", ContentId.TYPE_TRACK, true)
	ctx.check_id_pack("id", track.id)
	track.display_name_key = reader.text("display_name_key", true)
	track.scene_path = reader.text("scene", true)
	if not track.scene_path.is_empty() and not track.scene_path.begins_with("res://"):
		ctx.error("scene", "a cena da pista deve ser um caminho res://")
	track.time_of_day = reader.text("time_of_day")
	track.weather = reader.text("weather")
	var seen: Dictionary = {}
	for layout_reader: DictReader in reader.child_list("layouts", true):
		var layout: Layout = Layout.new()
		layout.id = layout_reader.text("id", true)
		layout.type = layout_reader.enum_value("type", LAYOUT_TYPES, true, "circuit")
		layout.node = layout_reader.text("node", true)
		layout.default_laps = layout_reader.integer("default_laps", false, 1, 1, 50)
		layout.reversible = layout_reader.boolean("reversible")
		if seen.has(layout.id):
			ctx.error(layout_reader.field_path("id"), "traçado repetido: '%s'" % layout.id)
		seen[layout.id] = true
		track.layouts.append(layout)
	reader.finish()
	return track if ctx.report.error_count() == errors_before else null


func get_layout(layout_id: String) -> Layout:
	for layout: Layout in layouts:
		if layout.id == layout_id:
			return layout
	return null
