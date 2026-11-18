class_name PlayerHud
extends Control
## One player's HUD: speed, gear, RPM bar and nitro bar. Shows ITS [member vehicle]
## only (in split screen each view has its own HUD). Built in code; scales with
## the size of the area it is placed in.

const KMH_TO_MPH: float = 0.621371
const REDLINE_FRAC: float = 0.9

var vehicle: Vehicle = null

var _speed: Label = null
var _unit: Label = null
var _gear: Label = null
var _rpm: ProgressBar = null
var _nitro: ProgressBar = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel: VBoxContainer = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -330
	panel.offset_top = -210
	panel.offset_right = -30
	panel.offset_bottom = -30
	panel.alignment = BoxContainer.ALIGNMENT_END
	add_child(panel)
	var top: HBoxContainer = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	_speed = _label(84, HORIZONTAL_ALIGNMENT_RIGHT)
	_unit = _label(26, HORIZONTAL_ALIGNMENT_LEFT)
	_gear = _label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_gear.custom_minimum_size = Vector2(70, 0)
	top.add_child(_speed)
	top.add_child(_unit)
	top.add_child(_gear)
	panel.add_child(top)
	_rpm = _bar(Color("#FF5A1F"))
	panel.add_child(_labeled(tr("HUD_RPM"), _rpm))
	_nitro = _bar(Color("#2FA8FF"))
	panel.add_child(_labeled(tr("HUD_NITRO"), _nitro))


func _process(_delta: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle) or vehicle.drivetrain == null:
		return
	var kmh: float = absf(vehicle.get_speed_kmh())
	var mph: bool = Settings.data.units == "mph"
	_speed.text = str(roundi(kmh * KMH_TO_MPH if mph else kmh))
	_unit.text = tr("HUD_MPH") if mph else tr("HUD_KMH")
	_gear.text = gear_text(vehicle.drivetrain.gear, vehicle.drivetrain.shifting)
	var rpm_fraction: float = vehicle.drivetrain.rpm_fraction()
	_rpm.value = rpm_fraction
	_rpm.modulate = Color(1.0, 0.25, 0.2) if rpm_fraction > REDLINE_FRAC else Color.WHITE
	_nitro.value = vehicle.nitro_amount
	_nitro.visible = vehicle.params.nitro_capacity_s > 0.0


## Text of the gear indicator (`R`, `N` while shifting, `1`...).
func gear_text(gear: int, shifting: bool) -> String:
	if gear == Drivetrain.REVERSE:
		return tr("HUD_GEAR_REVERSE")
	if shifting or gear <= 0:
		return tr("HUD_GEAR_NEUTRAL")
	return str(gear)


func get_speed_text() -> String:
	return _speed.text


func _label(font_size: int, alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = alignment
	return label


func _bar(color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _labeled(text: String, bar: ProgressBar) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = _label(18, HORIZONTAL_ALIGNMENT_LEFT)
	label.text = text
	label.custom_minimum_size = Vector2(70, 0)
	row.add_child(label)
	row.add_child(bar)
	return row
