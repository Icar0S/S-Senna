class_name ShowroomSandbox
extends Node3D
## Test showroom (Etapa 03): the car on a turntable with a debug panel to change
## every slot, part finish, paint finish and color, wheel, rim size, width,
## camber, offset and ride height, plus saving to / reloading from a test profile.
##
## Open: `tools/scripts/jogar.bat res://game/sandbox/showroom_sandbox.tscn`
## Options (after `--`, used by the screenshots): `--showroom-car=<id>`,
## `--showroom-finish=<finish>`, `--showroom-color=<paint id>`, `--showroom-wheel=<id>`,
## `--showroom-yaw=<deg>`, `--showroom-pitch=<deg>`, `--showroom-no-ui`, `--showroom-lights`.

const DEFAULT_CAR: String = "car:base/prototipo"
const TEST_PROFILE_NAME: String = "Showroom (teste)"
const TEST_INSTANCE: String = "showroom"
const TURNTABLE_SPEED: float = 12.0
const RIM_RANGE: Vector2i = Vector2i(15, 22)
const WIDTH_RANGE: Vector2 = Vector2(6.5, 11.0)
const UI_FONT_SIZE: int = 20
const ARG_PREFIX: String = "--showroom-"

var _visual: CarVisual = null
var _car_index: int = 0
var _cars: Array[CarDef] = []
var _spin: bool = true
var _headlights: bool = false
var _brake: bool = false
var _rows: Array[Callable] = []
var _status: Label = null
var _panel: Control = null

@onready var _turntable: Node3D = %Turntable
@onready var _camera: OrbitCamera = %Camera


func _ready() -> void:
	_cars = ContentDB.list_cars()
	var car_id: String = _arg("car", DEFAULT_CAR)
	for i: int in _cars.size():
		if _cars[i].id == ContentDB.resolve_id(car_id):
			_car_index = i
	_build_ui()
	_load_car(CarConfig.create_default(_cars[_car_index], TEST_INSTANCE))
	_apply_capture_args()


func _process(delta: float) -> void:
	if _spin:
		_turntable.rotate_y(deg_to_rad(TURNTABLE_SPEED) * delta)


func get_visual() -> CarVisual:
	return _visual


# --- Car -------------------------------------------------------------------------


func _load_car(config: CarConfig) -> void:
	if _visual != null:
		_turntable.remove_child(_visual)
		_visual.queue_free()
	_visual = CarAssembler.build(_cars[_car_index], config)
	_turntable.add_child(_visual)
	_visual.set_lights(_headlights, 1.0 if _brake else 0.0, false)
	for issue: String in _visual.issues:
		Log.warn(issue, "Showroom")
	_rebuild_rows()


func _apply_capture_args() -> void:
	var finish: String = _arg("finish", "")
	var paint_id: String = _arg("color", "")
	if not paint_id.is_empty() or not finish.is_empty():
		var spec: PaintSpec = _body_paint()
		var preset: PaintCatalog.Preset = ContentDB.get_library().get_paint(paint_id)
		if preset != null:
			spec = _copy_spec(preset.spec)
		if not finish.is_empty():
			spec.finish = finish
		_visual.set_paint("paint_body", spec)
	var wheel_id: String = _arg("wheel", "")
	if not wheel_id.is_empty():
		var front: CarConfig.WheelSetting = _visual.config.wheel_front
		front.wheel_id = wheel_id
		var rear: CarConfig.WheelSetting = _visual.config.wheel_rear
		rear.wheel_id = wheel_id
		_visual.set_wheels(front, rear)
	if CmdlineArgs.has_flag(OS.get_cmdline_user_args(), ARG_PREFIX + "lights"):
		_headlights = true
		_visual.set_lights(true, 0.0, false)
	var yaw: String = _arg("yaw", "")
	if not yaw.is_empty():
		_spin = false
		_camera.yaw = float(yaw)
		_camera.pitch = float(_arg("pitch", str(_camera.pitch)))
		_camera.update_transform()
	if CmdlineArgs.has_flag(OS.get_cmdline_user_args(), ARG_PREFIX + "no-ui"):
		_panel.visible = false


# --- UI --------------------------------------------------------------------------


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	scroll.custom_minimum_size = Vector2(470, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	var background: PanelContainer = PanelContainer.new()
	background.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(background)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Rows"
	background.add_child(box)
	_panel = scroll


func _rebuild_rows() -> void:
	var box: VBoxContainer = _rows_box()
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
	_rows.clear()
	box.add_child(_label(tr("SHOWROOM_TITLE"), 28))
	var help: Label = _label(tr("SHOWROOM_HELP"), 14)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	_add_row(
		box,
		func() -> String: return tr("SHOWROOM_CAR") % _cars[_car_index].display_name,
		_cycle_car
	)
	for slot: String in _slots():
		_add_row(box, _slot_text.bind(slot), _cycle_part.bind(slot))
		if not _finishes_for(slot).is_empty():
			_add_row(box, _finish_text.bind(slot), _cycle_finish.bind(slot))
	_add_row(
		box,
		func() -> String: return tr("SHOWROOM_PAINT_FINISH") % _body_paint().finish,
		_cycle_paint_finish
	)
	_add_row(box, _color_text, _cycle_color)
	_add_row(box, _wheel_text, _cycle_wheel)
	_add_row(box, func() -> String: return tr("SHOWROOM_RIM_SIZE") % _setting().rim_in, _step_rim)
	_add_row(box, func() -> String: return tr("SHOWROOM_WIDTH") % _setting().width_in, _step_width)
	_add_row(
		box, func() -> String: return tr("SHOWROOM_CAMBER") % _setting().camber_deg, _step_camber
	)
	_add_row(
		box,
		func() -> String: return tr("SHOWROOM_OFFSET") % roundi(_setting().offset_mm),
		_step_offset
	)
	_add_row(
		box,
		func() -> String: return tr("SHOWROOM_HEIGHT") % roundi(_visual.config.ride_height_mm),
		_step_height
	)
	var toggles: HBoxContainer = HBoxContainer.new()
	toggles.add_child(_toggle("SHOWROOM_LIGHTS", _headlights, _on_lights))
	toggles.add_child(_toggle("SHOWROOM_BRAKE", _brake, _on_brake))
	toggles.add_child(_toggle("SHOWROOM_TURNTABLE", _spin, func(on: bool) -> void: _spin = on))
	box.add_child(toggles)
	var save_row: HBoxContainer = HBoxContainer.new()
	save_row.add_child(_button(tr("SHOWROOM_SAVE"), _save_to_profile))
	save_row.add_child(_button(tr("SHOWROOM_RELOAD"), _reload_from_profile))
	box.add_child(save_row)
	_status = _label("", 16)
	box.add_child(_status)


func _rows_box() -> VBoxContainer:
	return _panel.get_child(0).get_child(0)


## A row "< text >": [param step] receives -1 or +1.
func _add_row(box: VBoxContainer, text: Callable, step: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = _label("", UI_FONT_SIZE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	var refresh: Callable = func() -> void: label.text = str(text.call())
	row.add_child(_button("<", func() -> void: _changed(step, -1)))
	row.add_child(label)
	row.add_child(_button(">", func() -> void: _changed(step, 1)))
	box.add_child(row)
	_rows.append(refresh)
	refresh.call()


func _changed(step: Callable, direction: int) -> void:
	step.call(direction)
	for refresh: Callable in _rows:
		refresh.call()


# --- Rows: parts -----------------------------------------------------------------


func _slots() -> PackedStringArray:
	var slots: PackedStringArray = []
	for slot: String in Conventions.all_slots():
		if slot == CarDef.BODY_SLOT and _cars[_car_index].get_part_entries(slot).size() < 2:
			continue
		if ContentDB.list_parts_for(_cars[_car_index].id, slot).size() > 1 or _has_universal(slot):
			slots.append(slot)
	return slots


func _has_universal(slot: String) -> bool:
	for part: PartDef in ContentDB.list_parts_for(_cars[_car_index].id, slot):
		if part.is_universal():
			return true
	return false


## "" (stock) followed by every other option for the slot.
func _options(slot: String) -> PackedStringArray:
	var options: PackedStringArray = [""]
	for part: PartDef in ContentDB.list_parts_for(_cars[_car_index].id, slot):
		if part.variant != CarDef.STOCK_VARIANT:
			options.append(part.id)
	return options


func _slot_text(slot: String) -> String:
	var part_id: String = str(_visual.config.parts.get(slot, ""))
	var part: PartDef = ContentDB.get_part(part_id)
	var shown: String = tr("SHOWROOM_STOCK")
	if part != null:
		shown = part.display_name if not part.display_name.is_empty() else part.variant
	return tr("SHOWROOM_SLOT") % [slot, shown]


func _cycle_part(direction: int, slot: String) -> void:
	var options: PackedStringArray = _options(slot)
	var index: int = options.find(str(_visual.config.parts.get(slot, "")))
	_visual.set_part(slot, options[posmod(index + direction, options.size())])


func _finishes_for(slot: String) -> PackedStringArray:
	var finishes: PackedStringArray = []
	for entry: CarDef.PartEntry in _cars[_car_index].get_part_entries(slot):
		for finish: String in entry.finishes:
			if not finishes.has(finish):
				finishes.append(finish)
	for part: PartDef in ContentDB.list_parts_for(_cars[_car_index].id, slot):
		for finish: String in part.finishes:
			if not finishes.has(finish):
				finishes.append(finish)
	return finishes


func _finish_text(slot: String) -> String:
	return tr("SHOWROOM_FINISH") % [slot, str(_visual.config.part_finish.get(slot, "paint"))]


func _cycle_finish(direction: int, slot: String) -> void:
	var finishes: PackedStringArray = _finishes_for(slot)
	if not finishes.has("paint"):
		finishes.insert(0, "paint")
	var index: int = finishes.find(str(_visual.config.part_finish.get(slot, "paint")))
	_visual.set_part_finish(slot, finishes[posmod(index + direction, finishes.size())])


func _cycle_car(direction: int) -> void:
	_car_index = posmod(_car_index + direction, _cars.size())
	_load_car(CarConfig.create_default(_cars[_car_index], TEST_INSTANCE))


# --- Rows: paint and wheels ------------------------------------------------------


func _body_paint() -> PaintSpec:
	var value: Variant = _visual.config.paint.get("paint_body")
	if value is PaintSpec:
		return _copy_spec(value)
	var fallback: Variant = _cars[_car_index].paint_default.get("paint_body")
	return _copy_spec(fallback) if fallback is PaintSpec else PaintSpec.new()


func _cycle_paint_finish(direction: int) -> void:
	var finishes: PackedStringArray = Conventions.paint_finishes()
	var spec: PaintSpec = _body_paint()
	spec.finish = finishes[posmod(finishes.find(spec.finish) + direction, finishes.size())]
	if spec.color2.is_empty() and spec.finish in ["pearl", "chameleon", "candy"]:
		spec.color2 = "#7FD3FF"
	if spec.finish in ["metallic", "pearl"] and spec.flake == 0.0:
		spec.flake = 0.4
	_visual.set_paint("paint_body", spec)


func _color_text() -> String:
	return tr("SHOWROOM_PAINT_COLOR") % _body_paint().color


func _cycle_color(direction: int) -> void:
	var presets: Array[PaintCatalog.Preset] = ContentDB.get_library().get_paint_catalog().presets
	if presets.is_empty():
		return
	var spec: PaintSpec = _body_paint()
	var index: int = -1
	for i: int in presets.size():
		if presets[i].spec.color == spec.color:
			index = i
	var preset: PaintSpec = presets[posmod(index + direction, presets.size())].spec
	spec.color = preset.color
	spec.color2 = preset.color2
	spec.flake = preset.flake
	_visual.set_paint("paint_body", spec)


func _setting() -> CarConfig.WheelSetting:
	return _visual.config.wheel_front


func _wheel_text() -> String:
	var wheel: WheelDef = ContentDB.get_wheel(_setting().wheel_id)
	return tr("SHOWROOM_WHEEL") % (wheel.display_name if wheel != null else tr("SHOWROOM_STOCK"))


func _cycle_wheel(direction: int) -> void:
	var ids: PackedStringArray = [""]
	for wheel: WheelDef in ContentDB.list_wheels():
		ids.append(wheel.id)
	var next: String = ids[posmod(ids.find(_setting().wheel_id) + direction, ids.size())]
	_edit_wheels(func(setting: CarConfig.WheelSetting) -> void: setting.wheel_id = next)


func _step_rim(direction: int) -> void:
	_edit_wheels(
		func(setting: CarConfig.WheelSetting) -> void:
			setting.rim_in = clampi(setting.rim_in + direction, RIM_RANGE.x, RIM_RANGE.y)
	)


func _step_width(direction: int) -> void:
	_edit_wheels(
		func(setting: CarConfig.WheelSetting) -> void:
			setting.width_in = clampf(
				setting.width_in + 0.5 * direction, WIDTH_RANGE.x, WIDTH_RANGE.y
			)
	)


func _step_camber(direction: int) -> void:
	_edit_wheels(
		func(setting: CarConfig.WheelSetting) -> void:
			setting.camber_deg = clampf(setting.camber_deg + 0.5 * direction, -10.0, 2.0)
	)


func _step_offset(direction: int) -> void:
	_edit_wheels(
		func(setting: CarConfig.WheelSetting) -> void:
			setting.offset_mm = clampf(setting.offset_mm + 5.0 * direction, -30.0, 40.0)
	)


func _step_height(direction: int) -> void:
	_visual.set_ride_height(clampf(_visual.config.ride_height_mm + 5.0 * direction, -90.0, 60.0))


## Applies [param edit] to both axles.
func _edit_wheels(edit: Callable) -> void:
	var front: CarConfig.WheelSetting = _visual.config.wheel_front
	var rear: CarConfig.WheelSetting = _visual.config.wheel_rear
	edit.call(front)
	edit.call(rear)
	_visual.set_wheels(front, rear)


func _on_lights(on: bool) -> void:
	_headlights = on
	_visual.set_lights(_headlights, 1.0 if _brake else 0.0, false)


func _on_brake(on: bool) -> void:
	_brake = on
	_visual.set_lights(_headlights, 1.0 if _brake else 0.0, false)


# --- Test profile ----------------------------------------------------------------


func _test_profile() -> ProfileData:
	for summary: ProfileStore.Summary in SaveManager.list_profiles():
		if summary.name == TEST_PROFILE_NAME:
			return SaveManager.load_profile(summary.id)
	return SaveManager.create_profile(TEST_PROFILE_NAME, true)


func _save_to_profile() -> void:
	var profile: ProfileData = _test_profile()
	if profile == null:
		return
	var saved: CarConfig = _visual.config.copy()
	var existing: CarConfig = profile.get_car(saved.instance_id)
	if existing != null:
		profile.cars.erase(existing)
	profile.cars.append(saved)
	profile.selected_car = saved.instance_id
	if SaveManager.save_profile(profile.id):
		_status.text = tr("SHOWROOM_SAVED")


func _reload_from_profile() -> void:
	var profile: ProfileData = _test_profile()
	if profile == null:
		return
	var loaded: ProfileStore.LoadResult = SaveManager.get_store().load_profile(profile.id)
	var config: CarConfig = loaded.profile.get_car(TEST_INSTANCE) if loaded.ok() else null
	if config == null:
		_status.text = tr("SHOWROOM_NOTHING_SAVED")
		return
	for i: int in _cars.size():
		if _cars[i].id == ContentDB.resolve_id(config.car_id):
			_car_index = i
	_load_car(config)
	_status.text = tr("SHOWROOM_RELOADED")


# --- Small helpers ---------------------------------------------------------------


func _arg(option: String, default_value: String) -> String:
	return CmdlineArgs.get_value(OS.get_cmdline_user_args(), ARG_PREFIX + option, default_value)


static func _copy_spec(spec: PaintSpec) -> PaintSpec:
	var result: PaintSpec = PaintSpec.new()
	result.finish = spec.finish
	result.color = spec.color
	result.color2 = spec.color2
	result.flake = spec.flake
	result.gloss = spec.gloss
	return result


func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", UI_FONT_SIZE)
	button.pressed.connect(action)
	return button


func _toggle(key: String, pressed: bool, action: Callable) -> CheckButton:
	var toggle: CheckButton = CheckButton.new()
	toggle.text = tr(key)
	toggle.button_pressed = pressed
	toggle.add_theme_font_size_override("font_size", UI_FONT_SIZE)
	toggle.toggled.connect(action)
	return toggle
