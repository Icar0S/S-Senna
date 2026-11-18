class_name TuningPanel
extends Control
## F2: sliders for the physics of ONE vehicle, live. "This car" edits
## [VehicleParams] fields (saved as `tuning_overrides` in its car.json); "Global"
## edits `handling_global.json` (all cars). The owner tunes the feel without code.

const TOGGLE_KEY: Key = KEY_F2
const SLIDER_STEPS: float = 200.0
const FONT_SIZE: int = 14

var vehicle: Vehicle = null:
	set = set_vehicle

var _globals: HandlingGlobals = null
var _original_globals: HandlingGlobals = null
var _overrides: Dictionary = {}
var _rows: VBoxContainer = null
var _status: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	offset_right = 460
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	_rows = VBoxContainer.new()
	panel.add_child(_rows)
	visible = false
	if vehicle != null:
		_rebuild()


func set_vehicle(new_vehicle: Vehicle) -> void:
	vehicle = new_vehicle
	if vehicle == null:
		return
	_globals = ContentDB.get_library().get_handling_globals().copy()
	_original_globals = _globals.copy()
	_overrides = vehicle.car.tuning_overrides.duplicate()
	if _rows != null:
		_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == TOGGLE_KEY:
			visible = not visible


## Changes one car parameter (as the slider does) and remembers it as an override.
func set_car_value(field: String, value: float) -> void:
	vehicle.params.set_value(field, value)
	_overrides[field] = float(vehicle.params.get(field))


## Changes one global constant (as the slider does) and recomputes the car.
func set_global_value(field: String, value: float) -> void:
	_globals.set(field, value)
	vehicle.recompute_params(_globals, _overrides)


func get_overrides() -> Dictionary:
	return _overrides.duplicate()


func save_car() -> Error:
	var error: Error = TuningStore.save_car_overrides(vehicle.car, _overrides)
	_report(error, vehicle.car.source_file)
	return error


func save_global() -> Error:
	var path: String = ContentDB.get_library().get_handling_globals_file()
	var error: Error = TuningStore.save_globals(_globals, path)
	_report(error, path if not path.is_empty() else TuningStore.DEFAULT_GLOBALS_FILE)
	return error


func undo_changes() -> void:
	_globals = _original_globals.copy()
	_overrides = vehicle.car.tuning_overrides.duplicate()
	vehicle.recompute_params(_globals, _overrides)
	_rebuild()


func _rebuild() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_rows.add_child(_label(tr("TUNING_TITLE"), 22))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_child(_button(tr("TUNING_SAVE_CAR"), save_car))
	buttons.add_child(_button(tr("TUNING_SAVE_GLOBAL"), save_global))
	buttons.add_child(_button(tr("TUNING_RESET"), undo_changes))
	_rows.add_child(buttons)
	_status = _label("", FONT_SIZE)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(_status)
	_rows.add_child(_label(tr("TUNING_CAR"), 18))
	for field: String in VehicleParams.EDITABLE:
		var limits: Array = VehicleParams.EDITABLE[field]
		_add_slider(field, limits, float(vehicle.params.get(field)), set_car_value)
	_rows.add_child(_label(tr("TUNING_GLOBAL"), 18))
	for field: String in HandlingGlobals.RANGES:
		var limits: Array = HandlingGlobals.RANGES[field]
		_add_slider(field, limits, float(_globals.get(field)), set_global_value)


func _add_slider(field: String, limits: Array, value: float, on_change: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = _label(field, FONT_SIZE)
	name_label.custom_minimum_size = Vector2(170, 0)
	name_label.clip_text = true
	var slider: HSlider = HSlider.new()
	slider.min_value = float(limits[0])
	slider.max_value = float(limits[1])
	slider.step = (slider.max_value - slider.min_value) / SLIDER_STEPS
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label: Label = _label(_number(value), FONT_SIZE)
	value_label.custom_minimum_size = Vector2(70, 0)
	slider.value_changed.connect(
		func(new_value: float) -> void:
			on_change.call(field, new_value)
			value_label.text = _number(new_value)
	)
	row.add_child(name_label)
	row.add_child(slider)
	row.add_child(value_label)
	_rows.add_child(row)


func _report(error: Error, path: String) -> void:
	if _status == null:
		return
	if error == OK:
		_status.text = tr("TUNING_SAVED") % path
	else:
		_status.text = tr("TUNING_SAVE_FAILED") % TuningStore.last_error


static func _number(value: float) -> String:
	return "%.0f" % value if absf(value) >= 100.0 else "%.3f" % value


func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(func() -> void: action.call())
	return button
