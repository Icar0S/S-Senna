class_name CarDef
extends RefCounted
## A car (`car.json`, doc 03 §5).

const SCHEMA: String = "car"
const SCHEMA_VERSION: int = 1
const FILE_NAME: String = "car.json"
const CATEGORIES: PackedStringArray = [
	"jdm", "euro", "muscle", "super", "classico", "utilitario", "outro"
]
const DRIVETRAINS: PackedStringArray = ["FWD", "RWD", "AWD"]
const STOCK_VARIANT: String = "stock"
const BODY_SLOT: String = "body"
const VARIANT_PATTERN: String = "^[a-z0-9_]+$"

static var _variant_regex: RegEx = null

var id: String = ""
var display_name: String = ""
var manufacturer: String = ""
var year: int = 0
var country: String = ""
var category: String = "outro"
var description_key: String = ""
## Resolved path of the model (`.glb`).
var model_path: String = ""
var thumbnail_path: String = ""
var dimensions: Dimensions = Dimensions.new()
## Car-specific parts, in file order (see [PartEntry]).
var parts: Array[PartEntry] = []
## Socket name -> Dictionary of numeric parameters (`width_m`, `length_m`...).
var sockets: Dictionary = {}
var wheels: WheelSetup = WheelSetup.new()
var paint_zones: PackedStringArray = []
## Paint zone (material name) -> [PaintSpec].
var paint_default: Dictionary = {}
var stats: Stats = Stats.new()
var sound_id: String = ""
var price: int = 0
var unlock: String = "default"
var garage_distance_m: float = 5.0
var collection: Collection = Collection.new()
var credits: Dictionary = {}
## Physics fine-tuning saved by the F2 panel (Etapa 04): VehicleParams field -> number.
var tuning_overrides: Dictionary = {}
## The `car.json` this came from (filled by the scanner; the F2 panel saves there).
var source_file: String = ""

var _part_id_prefix: String = ""


## One entry of `parts` (a part modeled in the car's own `.glb`).
class PartEntry:
	extends RefCounted
	var slot: String = ""
	var variant: String = ""
	var name: String = ""
	## -1 = default price from `economy.json`.
	var price: int = -1
	var style_points: int = 0
	var unlock: String = "default"
	var finishes: PackedStringArray = []
	var accepts_universal: bool = false

	## Node name in the model, e.g. `bumper_front-kit01`.
	func node_name() -> String:
		return slot + Conventions.name_separator() + variant


class Dimensions:
	extends RefCounted
	var length_mm: int = 0
	var width_mm: int = 0
	var height_mm: int = 0
	var wheelbase_mm: int = 0


class WheelSetup:
	extends RefCounted
	## Wheel position (`FL`...) -> hub center in car space (meters; +Z front, +X left).
	var anchors: Dictionary = {}
	var tire_outer_diameter_m: float = 0.65
	var stock_rim: String = ""
	var stock_rim_in: int = 17
	var stock_width_in: float = 8.0
	var rim_in_min: int = 15
	var rim_in_max: int = 20
	var width_in_min: float = 7.0
	var width_in_max: float = 10.5
	var max_offset_mm: float = 30.0
	var max_camber_deg: float = 8.0


class Stats:
	extends RefCounted
	var power_hp: float = 150.0
	var torque_nm: float = 200.0
	var redline_rpm: int = 7000
	var mass_kg: float = 1200.0
	var weight_front_pct: float = 50.0
	var drivetrain: String = "RWD"
	var gears: int = 5
	var top_speed_kmh: float = 200.0
	var grip: float = 0.7
	var handling: float = 0.7
	var braking: float = 0.7


class Collection:
	extends RefCounted
	var has_miniature: bool = false
	var miniature_brand: String = ""
	var scale: String = ""
	var acquired: String = ""
	var photo_path: String = ""
	var notes: String = ""
	var livery_preset_path: String = ""


static func from_dict(data: Dictionary, ctx: LoadContext) -> CarDef:
	var errors_before: int = ctx.report.error_count()
	var reader: DictReader = DictReader.new(data, ctx)
	reader.check_header(SCHEMA, SCHEMA_VERSION)
	var car: CarDef = CarDef.new()
	car.id = reader.content_id("id", ContentId.TYPE_CAR, true)
	ctx.check_id_pack("id", car.id)
	car.display_name = reader.text("display_name", true)
	car.manufacturer = reader.text("manufacturer")
	car.year = reader.integer("year", false, 0, 0, 2100)
	car.country = reader.text("country")
	car.category = reader.enum_value("category", CATEGORIES, false, "outro")
	car.description_key = reader.text("description_key")
	car.model_path = ctx.resolve_path("model", reader.text("model", true))
	car.thumbnail_path = ctx.resolve_path("thumbnail", reader.text("thumbnail"))
	car.dimensions = _read_dimensions(reader.child("dimensions_mm", true))
	car.parts = _read_parts(reader, ctx)
	car.sockets = _read_sockets(reader.child("sockets"))
	car.wheels = _read_wheels(reader.child("wheels", true))
	_read_paint(car, reader.child("paint"))
	car.stats = _read_stats(reader.child("stats", true))
	car.sound_id = reader.content_id("sound", ContentId.TYPE_SOUND)
	var economy: DictReader = reader.child("economy")
	car.price = economy.integer("price", false, 0, 0)
	car.unlock = economy.unlock("unlock")
	car.garage_distance_m = reader.child("camera").number(
		"garage_distance_m", false, 5.0, 2.0, 15.0
	)
	car.collection = _read_collection(reader.child("collection"), ctx)
	var credits_value: Variant = reader.raw("credits", {})
	car.credits = credits_value if credits_value is Dictionary else {}
	var tuning_value: Variant = reader.raw("tuning_overrides", {})
	car.tuning_overrides = tuning_value if tuning_value is Dictionary else {}
	reader.finish()
	return car if ctx.report.error_count() == errors_before else null


## The part of this car with [param slot] and [param variant], or null.
func get_part_entry(slot: String, variant: String) -> PartEntry:
	for entry: PartEntry in parts:
		if entry.slot == slot and entry.variant == variant:
			return entry
	return null


func get_part_entries(slot: String) -> Array[PartEntry]:
	var result: Array[PartEntry] = []
	for entry: PartEntry in parts:
		if entry.slot == slot:
			result.append(entry)
	return result


## ID of a car-specific part: `part:<pack>/<car slug>/<slot>-<variant>`.
func part_id(entry: PartEntry) -> String:
	if _part_id_prefix.is_empty():
		var parsed: ContentId = ContentId.parse(id)
		if parsed == null:
			return ""
		_part_id_prefix = ContentId.make(ContentId.TYPE_PART, parsed.pack, parsed.path) + "/"
	return _part_id_prefix + entry.node_name()


func has_socket(socket: String) -> bool:
	return sockets.has(socket)


## True when universal parts may replace this car's part in [param slot].
## Slots without car-specific parts (e.g. `lip_front`) always accept them.
func accepts_universal(slot: String) -> bool:
	var entries: Array[PartEntry] = get_part_entries(slot)
	if entries.is_empty():
		return true
	for entry: PartEntry in entries:
		if entry.accepts_universal:
			return true
	return false


static func _read_dimensions(reader: DictReader) -> Dimensions:
	var dimensions: Dimensions = Dimensions.new()
	dimensions.length_mm = reader.integer("length", true, 4000, 1000, 10000)
	dimensions.width_mm = reader.integer("width", true, 1700, 500, 4000)
	dimensions.height_mm = reader.integer("height", true, 1300, 500, 4000)
	dimensions.wheelbase_mm = reader.integer("wheelbase", true, 2500, 500, 8000)
	return dimensions


static func _read_parts(reader: DictReader, ctx: LoadContext) -> Array[PartEntry]:
	var entries: Array[PartEntry] = []
	var seen: Dictionary = {}
	var slots: PackedStringArray = Conventions.all_slots()
	for part_reader: DictReader in reader.child_list("parts", true):
		var entry: PartEntry = PartEntry.new()
		entry.slot = part_reader.enum_value("slot", slots, true)
		entry.variant = part_reader.text("variant", true)
		if not entry.variant.is_empty() and not _variant_re().search(entry.variant):
			ctx.error(part_reader.field_path("variant"), "variante inválida (use a-z, 0-9 e _)")
		entry.name = part_reader.text("name")
		entry.price = part_reader.integer("price", false, -1, 0)
		entry.style_points = part_reader.integer("style_points", false, 0, 0, 10)
		entry.unlock = part_reader.unlock("unlock")
		entry.finishes = part_reader.string_list("finishes", false, Conventions.part_finishes())
		entry.accepts_universal = part_reader.boolean("accepts_universal")
		if entry.slot.is_empty() or entry.variant.is_empty():
			continue
		var key: String = entry.node_name()
		if seen.has(key):
			ctx.error(part_reader.field_path("variant"), "peça repetida: %s" % key)
			continue
		seen[key] = true
		entries.append(entry)
	_check_stock_variants(entries, ctx)
	return entries


static func _check_stock_variants(entries: Array[PartEntry], ctx: LoadContext) -> void:
	var slots_used: Dictionary = {}
	var stock_slots: Dictionary = {}
	for entry: PartEntry in entries:
		slots_used[entry.slot] = true
		if entry.variant == STOCK_VARIANT:
			stock_slots[entry.slot] = true
	if not stock_slots.has(BODY_SLOT):
		ctx.error("parts", "o carro precisa da carroceria original (body-stock)")
	for slot: String in slots_used:
		if not stock_slots.has(slot) and slot != BODY_SLOT:
			ctx.error("parts", "o slot '%s' não tem a variante original (stock)" % slot)


static func _read_sockets(reader: DictReader) -> Dictionary:
	var sockets: Dictionary = {}
	for socket: String in reader.keys():
		var params_reader: DictReader = reader.child(socket)
		if not Conventions.is_socket(socket):
			reader.context().error(reader.field_path(socket), "soquete desconhecido")
			continue
		var params: Dictionary = {}
		for param: String in params_reader.keys():
			params[param] = params_reader.number(param, false, 0.0, 0.0, 20.0)
		sockets[socket] = params
	return sockets


static func _read_wheels(reader: DictReader) -> WheelSetup:
	var setup: WheelSetup = WheelSetup.new()
	var anchors: DictReader = reader.child("anchors", true)
	for position: String in Conventions.wheel_positions():
		setup.anchors[position] = anchors.vector3(position, true)
	for key: String in anchors.keys():
		if not Conventions.wheel_positions().has(key):
			anchors.raw(key)
			reader.context().error(anchors.field_path(key), "posição de roda desconhecida")
	setup.tire_outer_diameter_m = reader.number("tire_outer_diameter_m", true, 0.65, 0.3, 1.5)
	setup.rim_in_min = reader.integer("rim_in_min", false, 15, 10, 30)
	setup.rim_in_max = reader.integer("rim_in_max", false, 20, setup.rim_in_min, 30)
	setup.width_in_min = reader.number("width_in_min", false, 7.0, 4.0, 15.0)
	setup.width_in_max = reader.number("width_in_max", false, 10.5, setup.width_in_min, 15.0)
	setup.max_offset_mm = reader.number("max_offset_mm", false, 30.0, 0.0, 100.0)
	setup.max_camber_deg = reader.number("max_camber_deg", false, 8.0, 0.0, 20.0)
	var stock: DictReader = reader.child("stock", true)
	setup.stock_rim = stock.text("rim")
	setup.stock_rim_in = stock.integer("rim_in", true, 17, setup.rim_in_min, setup.rim_in_max)
	setup.stock_width_in = stock.number(
		"width_in", true, 8.0, setup.width_in_min, setup.width_in_max
	)
	return setup


static func _read_paint(car: CarDef, reader: DictReader) -> void:
	car.paint_zones = reader.string_list("zones", false, Conventions.materials())
	var defaults: DictReader = reader.child("default")
	for zone: String in defaults.keys():
		var spec_reader: DictReader = defaults.child(zone)
		if not car.paint_zones.has(zone):
			reader.context().error(defaults.field_path(zone), "zona de pintura fora de 'zones'")
			continue
		car.paint_default[zone] = PaintSpec.from_reader(spec_reader)


static func _read_stats(reader: DictReader) -> Stats:
	var stats: Stats = Stats.new()
	stats.power_hp = reader.number("power_hp", true, 150.0, 1.0, 3000.0)
	stats.torque_nm = reader.number("torque_nm", true, 200.0, 1.0, 3000.0)
	stats.redline_rpm = reader.integer("redline_rpm", true, 7000, 1000, 20000)
	stats.mass_kg = reader.number("mass_kg", true, 1200.0, 300.0, 5000.0)
	stats.weight_front_pct = reader.number("weight_front_pct", false, 50.0, 20.0, 80.0)
	stats.drivetrain = reader.enum_value("drivetrain", DRIVETRAINS, true, "RWD")
	stats.gears = reader.integer("gears", false, 5, 1, 10)
	stats.top_speed_kmh = reader.number("top_speed_kmh", true, 200.0, 30.0, 600.0)
	stats.grip = reader.number("grip", false, 0.7, 0.0, 1.0)
	stats.handling = reader.number("handling", false, 0.7, 0.0, 1.0)
	stats.braking = reader.number("braking", false, 0.7, 0.0, 1.0)
	return stats


static func _read_collection(reader: DictReader, ctx: LoadContext) -> Collection:
	var info: Collection = Collection.new()
	info.has_miniature = reader.boolean("has_miniature")
	info.miniature_brand = reader.text("miniature_brand")
	info.scale = reader.text("scale")
	info.acquired = reader.text("acquired")
	info.photo_path = ctx.resolve_path(reader.field_path("photo"), reader.text("photo"))
	info.notes = reader.text("notes")
	info.livery_preset_path = ctx.resolve_path(
		reader.field_path("livery_preset"), reader.text("livery_preset")
	)
	return info


static func _variant_re() -> RegEx:
	if _variant_regex == null:
		_variant_regex = RegEx.create_from_string(VARIANT_PATTERN)
	return _variant_regex
