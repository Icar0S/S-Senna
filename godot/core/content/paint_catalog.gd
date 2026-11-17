class_name PaintCatalog
extends RefCounted
## Paint presets (`paints.json`, doc 03 §9). The finishes themselves come from
## `conventions.json` (they are shader features, not content).

const SCHEMA: String = "paint_catalog"
const SCHEMA_VERSION: int = 1
const FILE_NAME: String = "paints.json"

var finishes: PackedStringArray = []
var presets: Array[Preset] = []


class Preset:
	extends RefCounted
	var id: String = ""
	var name_key: String = ""
	var spec: PaintSpec = PaintSpec.new()


## Parses a `paints.json`. Invalid presets are skipped (and reported).
static func from_dict(data: Dictionary, ctx: LoadContext) -> PaintCatalog:
	var errors_before: int = ctx.report.error_count()
	var reader: DictReader = DictReader.new(data, ctx)
	reader.check_header(SCHEMA, SCHEMA_VERSION)
	var catalog: PaintCatalog = PaintCatalog.new()
	catalog.finishes = reader.string_list("finishes", false, Conventions.paint_finishes())
	if ctx.report.error_count() != errors_before:
		reader.finish()
		return null
	for preset_reader: DictReader in reader.child_list("presets", true):
		var preset_errors: int = ctx.report.error_count()
		var preset: Preset = Preset.new()
		preset.id = preset_reader.content_id("id", ContentId.TYPE_PAINT, true)
		ctx.check_id_pack(preset_reader.field_path("id"), preset.id)
		preset.name_key = preset_reader.text("name_key", true)
		preset.spec = PaintSpec.from_reader(preset_reader)
		if ctx.report.error_count() == preset_errors:
			catalog.presets.append(preset)
	reader.finish()
	return catalog


func get_preset(preset_id: String) -> Preset:
	for preset: Preset in presets:
		if preset.id == preset_id:
			return preset
	return null
