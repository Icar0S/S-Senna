class_name VinylDef
extends RefCounted
## A vinyl (decal). Vinyls come in sets, one `vinyls.json` per category (doc 03 §8).

const SCHEMA: String = "vinyl_set"
const SCHEMA_VERSION: int = 1
const FILE_NAME: String = "vinyls.json"
const MAX_COLORS: int = 3

var id: String = ""
var category: String = ""
var category_name_key: String = ""
## Resolved path of the image (`.svg` or `.png`).
var file_path: String = ""
## 0 = full-color image; 1 = alpha mask; 2-3 = R/G/B channels are color masks.
var colors: int = 1
var price: int = -1
var style_points: int = 0
var unlock: String = "default"


## Parses one vinyl entry of a set.
static func from_dict(
	data: Dictionary, ctx: LoadContext, set_category: String = "", name_key: String = ""
) -> VinylDef:
	var errors_before: int = ctx.report.error_count()
	var reader: DictReader = DictReader.new(data, ctx)
	var vinyl: VinylDef = _read_entry(reader, set_category, name_key)
	reader.finish()
	return vinyl if ctx.report.error_count() == errors_before else null


## Parses a whole `vinyls.json`. Invalid entries are skipped (and reported).
static func list_from_set(data: Dictionary, ctx: LoadContext) -> Array[VinylDef]:
	var vinyls: Array[VinylDef] = []
	var errors_before: int = ctx.report.error_count()
	var reader: DictReader = DictReader.new(data, ctx)
	reader.check_header(SCHEMA, SCHEMA_VERSION)
	var category: String = reader.text("category", true)
	if not category.is_empty() and not ContentId.is_valid_name(category):
		ctx.error("category", "categoria inválida (use a-z, 0-9, _ e -)")
	var name_key: String = reader.text("category_name_key")
	if ctx.report.error_count() != errors_before:
		reader.finish()
		return vinyls
	for entry_reader: DictReader in reader.child_list("vinyls", true):
		var entry_errors: int = ctx.report.error_count()
		var vinyl: VinylDef = _read_entry(entry_reader, category, name_key)
		if ctx.report.error_count() == entry_errors:
			vinyls.append(vinyl)
	reader.finish()
	return vinyls


static func _read_entry(reader: DictReader, set_category: String, name_key: String) -> VinylDef:
	var ctx: LoadContext = reader.context()
	var vinyl: VinylDef = VinylDef.new()
	vinyl.id = reader.content_id("id", ContentId.TYPE_VINYL, true)
	ctx.check_id_pack(reader.field_path("id"), vinyl.id)
	vinyl.category = set_category
	vinyl.category_name_key = name_key
	vinyl.file_path = ctx.resolve_path(reader.field_path("file"), reader.text("file", true))
	vinyl.colors = reader.integer("colors", false, 1, 0, MAX_COLORS)
	vinyl.price = reader.integer("price", false, -1, 0)
	vinyl.style_points = reader.integer("style_points", false, 0, 0, 10)
	vinyl.unlock = reader.unlock("unlock")
	return vinyl
