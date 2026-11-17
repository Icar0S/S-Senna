class_name SaveDebug
extends Control
## Simple test screen for the save system (Etapa 02). The real profile screens
## come with the garage (Etapa 09).
##
## Open it with: `tools/scripts/jogar.bat res://game/sandbox/save_debug.tscn`
## (or `.sh`). To check "closing by the X saves": load a profile, press
## "+1000 without saving", close the window and open the screen again.

const MONEY_STEP: int = 1000
const SAVE_REASON: String = "save_debug"
const CONTROL_FONT_SIZE: int = 24

var _profile_id: String = ""
var _profiles: ItemList = null
var _name_edit: LineEdit = null
var _info: Label = null
var _status: Label = null


func _ready() -> void:
	_build()
	SaveManager.saved.connect(_on_saved)
	SaveManager.save_failed.connect(_on_save_failed)
	SaveManager.save_recovered.connect(_on_save_recovered)
	_refresh()


func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	box.add_child(_label(tr("SAVE_DEBUG_TITLE"), 40))
	box.add_child(_label(tr("SAVE_DEBUG_FOLDER") % SaveManager.get_base_dir(), 18))
	_profiles = ItemList.new()
	_profiles.custom_minimum_size = Vector2(0, 260)
	_profiles.add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	_profiles.item_activated.connect(func(_index: int) -> void: _load_selected())
	box.add_child(_profiles)
	var create_row: HBoxContainer = HBoxContainer.new()
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = tr("SAVE_DEBUG_NAME_HINT")
	_name_edit.add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_row.add_child(_name_edit)
	create_row.add_child(_button("SAVE_DEBUG_CREATE", func() -> void: _create(false)))
	create_row.add_child(_button("SAVE_DEBUG_CREATE_SANDBOX", func() -> void: _create(true)))
	box.add_child(create_row)
	var profile_row: HBoxContainer = HBoxContainer.new()
	profile_row.add_child(_button("SAVE_DEBUG_LOAD", _load_selected))
	profile_row.add_child(_button("SAVE_DEBUG_DUPLICATE", _duplicate_selected))
	profile_row.add_child(_button("SAVE_DEBUG_DELETE", _delete_selected))
	box.add_child(profile_row)
	_info = _label("", 24)
	box.add_child(_info)
	var money_row: HBoxContainer = HBoxContainer.new()
	money_row.add_child(_button("SAVE_DEBUG_ADD_SAVE", func() -> void: _add_money(true)))
	money_row.add_child(_button("SAVE_DEBUG_ADD_LATER", func() -> void: _add_money(false)))
	box.add_child(money_row)
	_status = _label("", 20)
	box.add_child(_status)


func _create(sandbox: bool) -> void:
	var profile_name: String = _name_edit.text.strip_edges()
	if profile_name.is_empty():
		profile_name = tr("SAVE_DEBUG_DEFAULT_NAME")
	var profile: ProfileData = SaveManager.create_profile(profile_name, sandbox)
	if profile != null:
		_profile_id = profile.id
		_name_edit.clear()
	_refresh()


func _load_selected() -> void:
	var profile_id: String = _selected_id()
	if not profile_id.is_empty() and SaveManager.load_profile(profile_id) != null:
		_profile_id = profile_id
	_refresh()


func _duplicate_selected() -> void:
	var profile_id: String = _selected_id()
	if not profile_id.is_empty():
		SaveManager.duplicate_profile(profile_id)
	_refresh()


func _delete_selected() -> void:
	var profile_id: String = _selected_id()
	if profile_id.is_empty():
		return
	SaveManager.delete_profile(profile_id)
	if profile_id == _profile_id:
		_profile_id = ""
	_refresh()


func _add_money(save_now: bool) -> void:
	var profile: ProfileData = SaveManager.get_loaded(_profile_id)
	if profile == null:
		return
	profile.money += MONEY_STEP
	if save_now:
		SaveManager.request_save(_profile_id, SAVE_REASON)
	else:
		SaveManager.mark_dirty(_profile_id, SAVE_REASON)
		_status.text = tr("SAVE_DEBUG_PENDING")
	_refresh_info()


func _refresh() -> void:
	_profiles.clear()
	for summary: ProfileStore.Summary in SaveManager.list_profiles():
		var label: String = (
			tr("SAVE_DEBUG_PROFILE_ITEM") % [summary.name, summary.id, summary.car_count]
		)
		if summary.sandbox:
			label += " — " + tr("SAVE_DEBUG_SANDBOX")
		var index: int = _profiles.add_item(label)
		_profiles.set_item_metadata(index, summary.id)
		if summary.id == _profile_id:
			_profiles.select(index)
	_refresh_info()


func _refresh_info() -> void:
	var profile: ProfileData = SaveManager.get_loaded(_profile_id)
	if profile == null:
		_info.text = tr("SAVE_DEBUG_NONE")
		return
	_info.text = tr("SAVE_DEBUG_LOADED") % [profile.name, profile.money, profile.cars.size()]


func _selected_id() -> String:
	var selected: PackedInt32Array = _profiles.get_selected_items()
	if selected.is_empty():
		return ""
	return str(_profiles.get_item_metadata(selected[0]))


func _on_saved(_saved_id: String) -> void:
	_status.text = tr("SAVE_DEBUG_SAVED") % Time.get_time_string_from_system()


func _on_save_failed(_failed_id: String, message: String) -> void:
	_status.text = tr("SAVE_DEBUG_FAILED") % message


func _on_save_recovered(_recovered_id: String, source: String) -> void:
	_status.text = tr("SAVE_DEBUG_RECOVERED") % source


func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(key: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = tr(key)
	button.add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	button.pressed.connect(action)
	return button
