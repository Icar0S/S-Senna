class_name EconomyDef
extends RefCounted
## Economy constants (`economy.json`, doc 03 §12.1): starting money, prices,
## performance classes and base race rewards. Used by `Economy` (Etapa 09).

const SCHEMA: String = "economy"
const SCHEMA_VERSION: int = 1
const FILE_NAME: String = "economy.json"
const RACE_MODES: PackedStringArray = ["circuit", "sprint", "drag", "drift", "time_attack"]

var starting_money: int = 0
## Share of the price returned when selling (0..1).
var sell_factor: float = 0.5
var upgrade_min_price: int = 0
## Slot -> default price of a part without `price`.
var part_default_price: Dictionary = {}
var wheel_default_price: int = 0
var vinyl_default_price: int = 0
## Car category -> price multiplier for parts.
var category_price_factor: Dictionary = {}
## Class name (`D`, `C`, ... `S+`) -> minimum performance index.
var pi_classes: Dictionary = {}
## Race mode -> base reward for 1st place.
var race_reward_base: Dictionary = {}


static func from_dict(data: Dictionary, ctx: LoadContext) -> EconomyDef:
	var errors_before: int = ctx.report.error_count()
	var reader: DictReader = DictReader.new(data, ctx)
	reader.check_header(SCHEMA, SCHEMA_VERSION)
	var economy: EconomyDef = EconomyDef.new()
	economy.starting_money = reader.integer("starting_money", true, 0, 0)
	economy.sell_factor = reader.number("sell_factor", true, 0.5, 0.0, 1.0)
	economy.upgrade_min_price = reader.integer("upgrade_min_price", false, 0, 0)
	economy.wheel_default_price = reader.integer("wheel_default_price", false, 0, 0)
	economy.vinyl_default_price = reader.integer("vinyl_default_price", false, 0, 0)
	economy.part_default_price = _read_int_map(
		reader.child("part_default_price", true), Conventions.all_slots()
	)
	economy.category_price_factor = _read_float_map(
		reader.child("category_price_factor"), CarDef.CATEGORIES
	)
	economy.pi_classes = _read_int_map(reader.child("pi_classes"), PackedStringArray())
	economy.race_reward_base = _read_int_map(reader.child("race_reward_base"), RACE_MODES)
	reader.finish()
	return economy if ctx.report.error_count() == errors_before else null


## Default price of a part in [param slot] for a car of [param category].
func default_part_price(slot: String, category: String) -> int:
	var base: int = int(part_default_price.get(slot, 0))
	return roundi(base * float(category_price_factor.get(category, 1.0)))


## Class (`D`...`S+`) of a performance index: the highest class whose minimum is reached.
func pi_class(performance_index: int) -> String:
	var best_name: String = ""
	var best_min: int = -1
	for class_id: String in pi_classes:
		var minimum: int = pi_classes[class_id]
		if performance_index >= minimum and minimum > best_min:
			best_name = class_id
			best_min = minimum
	return best_name


static func _read_int_map(reader: DictReader, allowed: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for key: String in reader.keys():
		var value: int = reader.integer(key, true, 0, 0)
		if not allowed.is_empty() and not allowed.has(key):
			reader.context().error(reader.field_path(key), "chave desconhecida '%s'" % key)
			continue
		result[key] = value
	return result


static func _read_float_map(reader: DictReader, allowed: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for key: String in reader.keys():
		var value: float = reader.number(key, true, 1.0, 0.0, 10.0)
		if not allowed.has(key):
			reader.context().error(reader.field_path(key), "chave desconhecida '%s'" % key)
			continue
		result[key] = value
	return result
