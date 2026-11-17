class_name CarConfig
extends RefCounted
## One car of the player's garage and all its customization (doc 03 §13).
##
## Rules: IDs that no longer exist (disabled mod) are KEPT here untouched; use
## [method resolve] to get the "effective" version with stock parts in their
## place. Unknown fields are preserved too. The `with_*` functions are pure:
## they return a modified copy (the garage previews changes without touching the save).

const AXLE_FRONT: String = "front"
const AXLE_REAR: String = "rear"
const VINYL_SIDES: PackedStringArray = ["left", "right", "top", "front", "rear"]
## A side may copy another one instead of having its own layers.
const VINYL_MIRRORS: PackedStringArray = ["mirror_left", "mirror_right"]
## Paint zones may hold a mode string instead of a paint (e.g. `trim_black: body_color`).
const PAINT_MODES: PackedStringArray = ["body_color", "stock"]
const NEON_MODES: PackedStringArray = ["fixo", "pulsante", "arco_iris"]
const NITRO_STYLES: PackedStringArray = ["curto", "longo"]
const TUNING_SLIDERS: PackedStringArray = [
	"steering", "grip_drift", "brake_bias", "gearing", "downforce"
]
const DEFAULT_TUNING: float = 0.5

var instance_id: String = ""
var car_id: String = ""
var nickname: String = ""
## Slot -> part ID (missing slot = stock part).
var parts: Dictionary = {}
## Slot -> finish (`paint`, `carbon`, `black`).
var part_finish: Dictionary = {}
## Slot -> fine fit values (e.g. `{"height_m": 0.04}`).
var part_fit: Dictionary = {}
var wheel_front: WheelSetting = WheelSetting.new()
var wheel_rear: WheelSetting = WheelSetting.new()
## Rim zone -> [PaintSpec].
var wheel_paint: Dictionary = {}
var caliper_color: String = ""
var ride_height_mm: float = 0.0
## Paint zone -> [PaintSpec] or a mode String (see [constant PAINT_MODES]).
var paint: Dictionary = {}
## Side -> Array[VinylLayer] or a mirror String (see [constant VINYL_MIRRORS]).
var vinyls: Dictionary = {}
var glass_tint: String = "#101418"
var glass_darkness: float = 0.0
var headlight_color: String = "#FFFFFF"
var neon_enabled: bool = false
var neon_color: String = "#00E5FF"
var neon_mode: String = "fixo"
var plate_text: String = ""
var plate_style: String = "generica_br"
## Upgrade category -> level (0 = stock).
var performance: Dictionary = {}
## Slider name -> 0..1.
var tuning: Dictionary = {}
var nitro_style: String = "longo"
var stats_races: int = 0
var stats_wins: int = 0
var stats_distance_km: float = 0.0
## Unknown fields, written back unchanged.
var extra: Dictionary = {}


## Rim, size and alignment of one axle.
class WheelSetting:
	extends RefCounted
	## "" = the car's stock rim.
	var wheel_id: String = ""
	var rim_in: int = 17
	var width_in: float = 8.0
	var offset_mm: float = 0.0
	var camber_deg: float = 0.0

	func to_dict() -> Dictionary:
		return {
			"wheel_id": wheel_id,
			"rim_in": rim_in,
			"width_in": width_in,
			"offset_mm": offset_mm,
			"camber_deg": camber_deg,
		}

	static func from_reader(reader: DictReader) -> WheelSetting:
		var setting: WheelSetting = WheelSetting.new()
		setting.wheel_id = reader.text("wheel_id")
		setting.rim_in = reader.integer("rim_in", false, 17, 10, 30)
		setting.width_in = reader.number("width_in", false, 8.0, 4.0, 15.0)
		setting.offset_mm = reader.number("offset_mm", false, 0.0, -100.0, 100.0)
		setting.camber_deg = reader.number("camber_deg", false, 0.0, -20.0, 20.0)
		return setting


## One vinyl layer on a side of the car (positions normalized 0..1).
class VinylLayer:
	extends RefCounted
	var vinyl_id: String = ""
	var pos: Vector2 = Vector2(0.5, 0.5)
	var scale: Vector2 = Vector2.ONE
	var rot_deg: float = 0.0
	var colors: PackedStringArray = []
	var flip_h: bool = false

	func to_dict() -> Dictionary:
		return {
			"vinyl_id": vinyl_id,
			"pos": [pos.x, pos.y],
			"scale": [scale.x, scale.y],
			"rot_deg": rot_deg,
			"colors": Array(colors),
			"flip_h": flip_h,
		}

	static func from_reader(reader: DictReader) -> VinylLayer:
		var layer: VinylLayer = VinylLayer.new()
		layer.vinyl_id = reader.text("vinyl_id")
		layer.pos = _vector2(reader.raw("pos"), Vector2(0.5, 0.5))
		layer.scale = _vector2(reader.raw("scale"), Vector2.ONE)
		layer.rot_deg = reader.number("rot_deg", false, 0.0, -360.0, 360.0)
		layer.colors = reader.string_list("colors")
		layer.flip_h = reader.boolean("flip_h")
		return layer

	static func _vector2(value: Variant, default_value: Vector2) -> Vector2:
		if value is Array and (value as Array).size() == 2:
			var items: Array = value
			if (items[0] is float or items[0] is int) and (items[1] is float or items[1] is int):
				return Vector2(items[0], items[1])
		return default_value


## A new config with the car exactly as it comes from the dealership.
static func create_default(car: CarDef, new_instance_id: String) -> CarConfig:
	var config: CarConfig = CarConfig.new()
	config.instance_id = new_instance_id
	config.car_id = car.id
	for setting: WheelSetting in [config.wheel_front, config.wheel_rear]:
		setting.rim_in = car.wheels.stock_rim_in
		setting.width_in = car.wheels.stock_width_in
	for zone: String in car.paint_default:
		config.paint[zone] = _copy_paint(car.paint_default[zone])
	return config


static func from_dict(data: Dictionary, ctx: LoadContext) -> CarConfig:
	var reader: DictReader = DictReader.new(data, ctx)
	var config: CarConfig = CarConfig.new()
	config.instance_id = reader.text("instance_id", true)
	config.car_id = reader.text("car_id", true)
	config.nickname = reader.text("nickname")
	config.parts = _string_map(reader.child("parts"))
	config.part_finish = _string_map(reader.child("part_finish"))
	config.part_fit = SaveValues.dict_or_empty(reader.raw("part_fit"))
	var wheels: DictReader = reader.child("wheels")
	config.wheel_front = WheelSetting.from_reader(wheels.child(AXLE_FRONT))
	config.wheel_rear = WheelSetting.from_reader(wheels.child(AXLE_REAR))
	config.wheel_paint = _read_paints(wheels.child("paint"))
	config.caliper_color = wheels.text("caliper_color")
	wheels.take_unread()
	config.ride_height_mm = reader.child("stance").number(
		"ride_height_mm", false, 0.0, -200.0, 200.0
	)
	config.paint = _read_paints(reader.child("paint"))
	config.vinyls = _read_vinyls(reader.child("vinyls"))
	var glass: DictReader = reader.child("glass")
	config.glass_tint = glass.color("tint", false, "#101418")
	config.glass_darkness = glass.number("darkness", false, 0.0, 0.0, 1.0)
	var lights: DictReader = reader.child("lights")
	config.headlight_color = lights.color("headlight_color", false, "#FFFFFF")
	var neon: DictReader = lights.child("neon")
	config.neon_enabled = neon.boolean("enabled")
	config.neon_color = neon.color("color", false, "#00E5FF")
	config.neon_mode = neon.enum_value("mode", NEON_MODES, false, "fixo")
	var plate: DictReader = reader.child("plate")
	config.plate_text = plate.text("text")
	config.plate_style = plate.text("style", false, "generica_br")
	var performance_reader: DictReader = reader.child("performance")
	for category: String in performance_reader.keys():
		config.performance[category] = performance_reader.integer(category, true, 0, 0, 10)
	var tuning_reader: DictReader = reader.child("tuning")
	for slider: String in TUNING_SLIDERS:
		if tuning_reader.has(slider):
			config.tuning[slider] = tuning_reader.number(slider, false, DEFAULT_TUNING, 0.0, 1.0)
	config.nitro_style = tuning_reader.enum_value("nitro_style", NITRO_STYLES, false, "longo")
	var stats: DictReader = reader.child("stats")
	config.stats_races = stats.integer("races", false, 0, 0)
	config.stats_wins = stats.integer("wins", false, 0, 0)
	config.stats_distance_km = stats.number("distance_km", false, 0.0, 0.0)
	config.extra = SaveValues.normalize(reader.take_unread())
	return config


func to_dict() -> Dictionary:
	var paint_dict: Dictionary = {}
	for zone: String in paint:
		paint_dict[zone] = _paint_value_to_json(paint[zone])
	var wheel_paint_dict: Dictionary = {}
	for zone: String in wheel_paint:
		wheel_paint_dict[zone] = _paint_value_to_json(wheel_paint[zone])
	var vinyls_dict: Dictionary = {}
	for side: String in vinyls:
		var value: Variant = vinyls[side]
		if value is String:
			vinyls_dict[side] = value
		else:
			var layers: Array = []
			for layer: VinylLayer in value:
				layers.append(layer.to_dict())
			vinyls_dict[side] = layers
	var tuning_dict: Dictionary = tuning.duplicate()
	tuning_dict["nitro_style"] = nitro_style
	var data: Dictionary = {
		"instance_id": instance_id,
		"car_id": car_id,
		"nickname": nickname,
		"parts": parts.duplicate(),
		"part_finish": part_finish.duplicate(),
		"part_fit": part_fit.duplicate(true),
		"wheels":
		{
			"front": wheel_front.to_dict(),
			"rear": wheel_rear.to_dict(),
			"paint": wheel_paint_dict,
			"caliper_color": caliper_color,
		},
		"stance": {"ride_height_mm": ride_height_mm},
		"paint": paint_dict,
		"vinyls": vinyls_dict,
		"glass": {"tint": glass_tint, "darkness": glass_darkness},
		"lights":
		{
			"headlight_color": headlight_color,
			"neon": {"enabled": neon_enabled, "color": neon_color, "mode": neon_mode},
		},
		"plate": {"text": plate_text, "style": plate_style},
		"performance": performance.duplicate(),
		"tuning": tuning_dict,
		"stats": {"races": stats_races, "wins": stats_wins, "distance_km": stats_distance_km},
	}
	return SaveValues.with_extra(data, extra.duplicate(true))


## An independent copy.
func copy() -> CarConfig:
	return CarConfig.from_dict(to_dict(), LoadContext.new())


## Copy with [param part_id] in [param slot].
func with_part(slot: String, part_id: String) -> CarConfig:
	var result: CarConfig = copy()
	result.parts[slot] = part_id
	return result


## Copy with the stock part back in [param slot].
func with_stock_part(slot: String) -> CarConfig:
	var result: CarConfig = copy()
	result.parts.erase(slot)
	result.part_finish.erase(slot)
	result.part_fit.erase(slot)
	return result


## Copy with [param spec] painted on [param zone] (e.g. `paint_body`).
func with_paint(zone: String, spec: PaintSpec) -> CarConfig:
	var result: CarConfig = copy()
	result.paint[zone] = _copy_paint(spec)
	return result


## Copy with [param setting] on [param axle] (`front`, `rear` or `both`).
func with_wheels(axle: String, setting: WheelSetting) -> CarConfig:
	var result: CarConfig = copy()
	var source: Dictionary = setting.to_dict()
	var ctx: LoadContext = LoadContext.new()
	if axle == AXLE_FRONT or axle == "both":
		result.wheel_front = WheelSetting.from_reader(DictReader.new(source, ctx))
	if axle == AXLE_REAR or axle == "both":
		result.wheel_rear = WheelSetting.from_reader(DictReader.new(source, ctx))
	return result


## The config as the game should show it with the content available now.
## Unknown parts, rims and vinyls are replaced by the stock ones (or removed) in
## the returned copy; this config is never changed.
func resolve(library: ContentLibrary) -> Resolution:
	var resolution: Resolution = Resolution.new()
	var effective: CarConfig = copy()
	resolution.config = effective
	if library.get_car(car_id) == null:
		resolution.missing.append(car_id)
		resolution.car_missing = true
		return resolution
	for slot: String in parts.keys():
		var part: PartDef = library.get_part(parts[slot])
		if part == null or part.slot != slot:
			resolution.missing.append(str(parts[slot]))
			effective.parts.erase(slot)
	for setting: WheelSetting in [effective.wheel_front, effective.wheel_rear]:
		if not setting.wheel_id.is_empty() and library.get_wheel(setting.wheel_id) == null:
			if not resolution.missing.has(setting.wheel_id):
				resolution.missing.append(setting.wheel_id)
			setting.wheel_id = ""
	for side: String in effective.vinyls:
		var value: Variant = effective.vinyls[side]
		if value is String:
			continue
		var kept: Array[VinylLayer] = []
		for layer: VinylLayer in value:
			if library.get_vinyl(layer.vinyl_id) != null:
				kept.append(layer)
			elif not resolution.missing.has(layer.vinyl_id):
				resolution.missing.append(layer.vinyl_id)
		effective.vinyls[side] = kept
	return resolution


## Result of [method resolve].
class Resolution:
	extends RefCounted
	var config: CarConfig = null
	## IDs that are in the save but not in the loaded content.
	var missing: PackedStringArray = []
	var car_missing: bool = false


static func _string_map(reader: DictReader) -> Dictionary:
	var result: Dictionary = {}
	for key: String in reader.keys():
		result[key] = reader.text(key)
	return result


static func _read_paints(reader: DictReader) -> Dictionary:
	var result: Dictionary = {}
	for zone: String in reader.keys():
		var value: Variant = reader.raw(zone)
		if value is String:
			result[zone] = value
		elif value is Dictionary:
			var spec_reader: DictReader = reader.child(zone)
			result[zone] = PaintSpec.from_reader(spec_reader)
			spec_reader.take_unread()
	return result


static func _read_vinyls(reader: DictReader) -> Dictionary:
	var result: Dictionary = {}
	for side: String in reader.keys():
		var value: Variant = reader.raw(side)
		if value is String:
			result[side] = value
			continue
		var layers: Array[VinylLayer] = []
		for layer_reader: DictReader in reader.child_list(side):
			layers.append(VinylLayer.from_reader(layer_reader))
		result[side] = layers
	return result


static func _paint_value_to_json(value: Variant) -> Variant:
	if value is PaintSpec:
		return (value as PaintSpec).to_dict()
	return value


static func _copy_paint(spec: PaintSpec) -> PaintSpec:
	var copy_spec: PaintSpec = PaintSpec.new()
	copy_spec.finish = spec.finish
	copy_spec.color = spec.color
	copy_spec.color2 = spec.color2
	copy_spec.flake = spec.flake
	copy_spec.gloss = spec.gloss
	return copy_spec
