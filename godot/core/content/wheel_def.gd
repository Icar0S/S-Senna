class_name WheelDef
extends RefCounted
## A rim of the wheel library (`wheel.json`, doc 03 §7). Modeled at 18" x 8".

const SCHEMA: String = "wheel"
const SCHEMA_VERSION: int = 1
const FILE_NAME: String = "wheel.json"
const STYLES: PackedStringArray = [
	"esportiva", "multi_raios", "deep_dish", "classica", "aero", "luxo", "off_road"
]

var id: String = ""
var display_name: String = ""
var brand: String = ""
var style: String = "esportiva"
var model_path: String = ""
var thumbnail_path: String = ""
var rim_in_min: int = 15
var rim_in_max: int = 22
var width_in_min: float = 7.0
var width_in_max: float = 11.0
var paint_zones: PackedStringArray = []
## Paint zone -> [PaintSpec].
var default_paint: Dictionary = {}
var price: int = -1
var style_points: int = 0
var unlock: String = "default"
var spinner: bool = false


static func from_dict(data: Dictionary, ctx: LoadContext) -> WheelDef:
	var errors_before: int = ctx.report.error_count()
	var reader: DictReader = DictReader.new(data, ctx)
	reader.check_header(SCHEMA, SCHEMA_VERSION)
	var wheel: WheelDef = WheelDef.new()
	wheel.id = reader.content_id("id", ContentId.TYPE_WHEEL, true)
	ctx.check_id_pack("id", wheel.id)
	wheel.display_name = reader.text("display_name", true)
	wheel.brand = reader.text("brand")
	wheel.style = reader.enum_value("style", STYLES, false, "esportiva")
	wheel.model_path = ctx.resolve_path("model", reader.text("model", true))
	wheel.thumbnail_path = ctx.resolve_path("thumbnail", reader.text("thumbnail"))
	wheel.rim_in_min = reader.integer("rim_in_min", false, 15, 10, 30)
	wheel.rim_in_max = reader.integer("rim_in_max", false, 22, wheel.rim_in_min, 30)
	wheel.width_in_min = reader.number("width_in_min", false, 7.0, 4.0, 15.0)
	wheel.width_in_max = reader.number("width_in_max", false, 11.0, wheel.width_in_min, 15.0)
	wheel.paint_zones = reader.string_list("paint_zones", false, Conventions.materials())
	var paints: DictReader = reader.child("default_paint")
	for zone: String in paints.keys():
		var spec_reader: DictReader = paints.child(zone)
		if not wheel.paint_zones.has(zone):
			ctx.error(paints.field_path(zone), "zona de pintura fora de 'paint_zones'")
			continue
		wheel.default_paint[zone] = PaintSpec.from_reader(spec_reader)
	wheel.price = reader.integer("price", false, -1, 0)
	wheel.style_points = reader.integer("style_points", false, 0, 0, 10)
	wheel.unlock = reader.unlock("unlock")
	wheel.spinner = reader.boolean("spinner")
	reader.finish()
	return wheel if ctx.report.error_count() == errors_before else null
