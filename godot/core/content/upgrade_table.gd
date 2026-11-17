class_name UpgradeTable
extends RefCounted
## Performance upgrade levels (`upgrades.json`, doc 03 §12).

const SCHEMA: String = "upgrades"
const SCHEMA_VERSION: int = 1
const FILE_NAME: String = "upgrades.json"
## Effects understood by the game (HandlingModel, Etapa 04/10).
const KNOWN_EFFECTS: PackedStringArray = [
	"power_pct",
	"torque_pct",
	"shift_time_pct",
	"handling_add",
	"grip_add",
	"braking_add",
	"nitro_capacity_s",
	"mass_pct",
]

## Level names, e.g. `stock`, `rua`, `pro`, `elite`.
var levels: PackedStringArray = []
## Category -> Array of Dictionary (one effects object per level).
var categories: Dictionary = {}
## Price of a level = car price x factor.
var price_factor_per_level: PackedFloat64Array = []


static func from_dict(data: Dictionary, ctx: LoadContext) -> UpgradeTable:
	var errors_before: int = ctx.report.error_count()
	var reader: DictReader = DictReader.new(data, ctx)
	reader.check_header(SCHEMA, SCHEMA_VERSION)
	var table: UpgradeTable = UpgradeTable.new()
	table.levels = reader.string_list("levels", true)
	if table.levels.is_empty():
		ctx.error("levels", "a tabela precisa de pelo menos um nível")
	var categories: DictReader = reader.child("categories", true)
	for category: String in categories.keys():
		var effects: Array = _read_effects(categories.child(category), table.levels.size())
		if not effects.is_empty():
			table.categories[category] = effects
	table.price_factor_per_level = _read_factors(reader, table.levels.size())
	reader.finish()
	return table if ctx.report.error_count() == errors_before else null


func level_count() -> int:
	return levels.size()


## Effects of [param category] at [param level] (`{}` when unknown).
func effects_for(category: String, level: int) -> Dictionary:
	var per_level: Array = categories.get(category, [])
	if level < 0 or level >= per_level.size():
		return {}
	return per_level[level]


func price_factor(level: int) -> float:
	if level < 0 or level >= price_factor_per_level.size():
		return 0.0
	return price_factor_per_level[level]


static func _read_effects(reader: DictReader, level_count: int) -> Array:
	var effects: Array = []
	var level_readers: Array[DictReader] = reader.child_list("effects_per_level", true)
	if level_readers.size() != level_count:
		reader.context().error(
			reader.field_path("effects_per_level"),
			"esperados %d níveis, encontrados %d" % [level_count, level_readers.size()]
		)
		return []
	for level_reader: DictReader in level_readers:
		var level_effects: Dictionary = {}
		for effect: String in level_reader.keys():
			if not KNOWN_EFFECTS.has(effect):
				level_reader.raw(effect)
				reader.context().warning(
					level_reader.field_path(effect), "efeito desconhecido (ignorado)"
				)
				continue
			level_effects[effect] = level_reader.number(effect, true, 0.0, -100.0, 100.0)
		effects.append(level_effects)
	return effects


static func _read_factors(reader: DictReader, level_count: int) -> PackedFloat64Array:
	var factors: PackedFloat64Array = []
	var value: Variant = reader.raw("price_factor_per_level", [])
	if not value is Array or (value as Array).size() != level_count:
		reader.context().error(
			"price_factor_per_level", "esperada uma lista de %d números" % level_count
		)
		return factors
	for item: Variant in value:
		if not (item is float or item is int):
			reader.context().error("price_factor_per_level", "esperada uma lista de números")
			return PackedFloat64Array()
		factors.append(clampf(float(item), 0.0, 10.0))
	return factors
