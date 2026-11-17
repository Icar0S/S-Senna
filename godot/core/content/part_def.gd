class_name PartDef
extends RefCounted
## A part: universal (`part.json`, doc 03 §6) or car-specific (an entry of
## `car.json.parts`, registered by the scanner without opening the `.glb`).

const SCHEMA: String = "part"
const SCHEMA_VERSION: int = 1
const FILE_NAME: String = "part.json"
const ALL_CARS: String = "*"

var id: String = ""
var slot: String = ""
var display_name: String = ""
var brand: String = ""
var model_path: String = ""
var thumbnail_path: String = ""
## Car-specific parts: owner car and variant ("" for universal parts).
var car_id: String = ""
var variant: String = ""
## Node name inside the model (car-specific parts: `<slot>-<variant>`).
var node_name: String = ""
var fit_socket: String = ""
var reference_width_m: float = 0.0
var scale_x_min: float = 1.0
var scale_x_max: float = 1.0
var compatible_all: bool = true
var compatible_cars: PackedStringArray = []
var exclude: PackedStringArray = []
## Car slots hidden while this part is installed.
var hides: PackedStringArray = []
var requires: PackedStringArray = []
var conflicts: PackedStringArray = []
var finishes: PackedStringArray = []
## -1 = default price from `economy.json`.
var price: int = -1
var style_points: int = 0
var unlock: String = "default"


static func from_dict(data: Dictionary, ctx: LoadContext) -> PartDef:
	var errors_before: int = ctx.report.error_count()
	var reader: DictReader = DictReader.new(data, ctx)
	reader.check_header(SCHEMA, SCHEMA_VERSION)
	var part: PartDef = PartDef.new()
	part.id = reader.content_id("id", ContentId.TYPE_PART, true)
	ctx.check_id_pack("id", part.id)
	part.slot = reader.enum_value("slot", Conventions.all_slots(), true)
	part.display_name = reader.text("display_name", true)
	part.brand = reader.text("brand")
	part.model_path = ctx.resolve_path("model", reader.text("model", true))
	part.thumbnail_path = ctx.resolve_path("thumbnail", reader.text("thumbnail"))
	_read_fit(part, reader.child("fit"))
	_read_compatible(part, reader.child("compatible"))
	var rules: DictReader = reader.child("rules")
	part.hides = rules.string_list("hides", false, Conventions.all_slots())
	part.requires = _read_part_refs(rules, "requires")
	part.conflicts = _read_part_refs(rules, "conflicts")
	part.finishes = reader.string_list("finishes", false, Conventions.part_finishes())
	part.price = reader.integer("price", false, -1, 0)
	part.style_points = reader.integer("style_points", false, 0, 0, 10)
	part.unlock = reader.unlock("unlock")
	reader.finish()
	return part if ctx.report.error_count() == errors_before else null


## Builds the definition of a car-specific part from the car's entry.
static func from_car_entry(car: CarDef, entry: CarDef.PartEntry) -> PartDef:
	var part: PartDef = PartDef.new()
	part.id = car.part_id(entry)
	part.slot = entry.slot
	part.display_name = entry.name
	part.model_path = car.model_path
	part.car_id = car.id
	part.variant = entry.variant
	part.node_name = entry.node_name()
	part.compatible_all = false
	part.compatible_cars = [car.id]
	part.finishes = entry.finishes
	part.price = entry.price
	part.style_points = entry.style_points
	part.unlock = entry.unlock
	return part


func is_universal() -> bool:
	return car_id.is_empty()


## True when this universal part may be offered for [param car] in [param slot_name].
## [param resolve] maps old IDs to current ones (aliases), so lists written with
## an old car ID keep working.
func fits_car(car: CarDef, slot_name: String, resolve: Callable) -> bool:
	if not is_universal() or slot != slot_name:
		return false
	if not compatible_all and not _resolved(compatible_cars, resolve).has(car.id):
		return false
	if _resolved(exclude, resolve).has(car.id):
		return false
	if not fit_socket.is_empty() and not car.has_socket(fit_socket):
		return false
	return car.accepts_universal(slot_name)


static func _read_fit(part: PartDef, reader: DictReader) -> void:
	part.fit_socket = reader.enum_value("socket", Conventions.sockets())
	part.reference_width_m = reader.number("reference_width_m", false, 0.0, 0.0, 5.0)
	part.scale_x_min = reader.number("scale_x_min", false, 1.0, 0.5, 1.0)
	part.scale_x_max = reader.number("scale_x_max", false, 1.0, 1.0, 2.0)


static func _read_compatible(part: PartDef, reader: DictReader) -> void:
	var cars_value: Variant = reader.raw("cars", ALL_CARS)
	if cars_value is String and cars_value == ALL_CARS:
		part.compatible_all = true
	elif cars_value is Array:
		part.compatible_all = false
		part.compatible_cars = reader.id_list("cars", ContentId.TYPE_CAR)
	else:
		reader.context().error(reader.field_path("cars"), 'use "*" ou uma lista de IDs de carros')
	part.exclude = reader.id_list("exclude", ContentId.TYPE_CAR)


## `requires` / `conflicts`: part IDs or slot names.
static func _read_part_refs(reader: DictReader, key: String) -> PackedStringArray:
	var refs: PackedStringArray = []
	var items: PackedStringArray = reader.string_list(key)
	for i: int in items.size():
		var item: String = items[i]
		if Conventions.is_slot(item) or ContentId.is_valid(item, ContentId.TYPE_PART):
			refs.append(item)
		else:
			reader.context().error(
				"%s[%d]" % [reader.field_path(key), i], "'%s' não é slot nem ID de peça" % item
			)
	return refs


static func _resolved(ids: PackedStringArray, resolve: Callable) -> PackedStringArray:
	if not resolve.is_valid():
		return ids
	var result: PackedStringArray = []
	for item: String in ids:
		result.append(str(resolve.call(item)))
	return result
