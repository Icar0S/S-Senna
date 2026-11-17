class_name PaintSpec
extends RefCounted
## One paint: finish + colors (doc 03 §9.1). Used by car defaults, wheel defaults,
## paint presets and, later, by saves (`CarConfig`).

const DEFAULT_FINISH: String = "solid"
const DEFAULT_COLOR: String = "#FFFFFF"
const DEFAULT_GLOSS: float = 0.9

var finish: String = DEFAULT_FINISH
var color: String = DEFAULT_COLOR
## Second color (pearl / chameleon / candy); "" when not used.
var color2: String = ""
var flake: float = 0.0
var gloss: float = DEFAULT_GLOSS


## Parses a standalone paint object. Returns null if it has errors.
static func from_dict(data: Dictionary, ctx: LoadContext) -> PaintSpec:
	var errors_before: int = ctx.report.error_count()
	var reader: DictReader = DictReader.new(data, ctx)
	var spec: PaintSpec = from_reader(reader)
	reader.finish()
	return spec if ctx.report.error_count() == errors_before else null


## Reads the paint fields from [param reader] (part of a bigger object).
static func from_reader(reader: DictReader) -> PaintSpec:
	var spec: PaintSpec = PaintSpec.new()
	spec.finish = reader.enum_value("finish", Conventions.paint_finishes(), true, DEFAULT_FINISH)
	spec.color = reader.color("color", true, DEFAULT_COLOR)
	spec.color2 = reader.color("color2", false, "")
	spec.flake = reader.number("flake", false, 0.0, 0.0, 1.0)
	spec.gloss = reader.number("gloss", false, DEFAULT_GLOSS, 0.0, 1.0)
	return spec


func get_color() -> Color:
	return Color.html(color)


## Second color, or the main color when there is none.
func get_color2() -> Color:
	return Color.html(color2 if not color2.is_empty() else color)


func to_dict() -> Dictionary:
	var result: Dictionary = {"finish": finish, "color": color}
	if not color2.is_empty():
		result["color2"] = color2
	result["flake"] = flake
	result["gloss"] = gloss
	return result
