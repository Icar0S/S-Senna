class_name TelemetryOverlay
extends Control
## F1: live numbers of ONE vehicle (speed, RPM, gear, load/slip/grip use of every
## wheel, drift angle, FPS). Debug tool for tuning the feel.

const TOGGLE_KEY: Key = KEY_F1

var vehicle: Vehicle = null

var _label: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -440
	offset_right = -10
	offset_top = 10
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel: PanelContainer = PanelContainer.new()
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_label)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == TOGGLE_KEY:
			visible = not visible


func _process(_delta: float) -> void:
	if visible and vehicle != null and is_instance_valid(vehicle):
		_label.text = format(vehicle.telemetry)


## Text of the overlay for a telemetry dictionary (see [member Vehicle.telemetry]).
func format(data: Dictionary) -> String:
	if data.is_empty():
		return tr("TELEMETRY_TITLE")
	var lines: PackedStringArray = [tr("TELEMETRY_TITLE")]
	lines.append(
		(
			tr("TELEMETRY_MAIN")
			% [
				float(data["speed_kmh"]),
				float(data["rpm"]),
				int(data["gear"]),
				tr("TELEMETRY_SHIFTING") if bool(data["shifting"]) else ""
			]
		)
	)
	lines.append(
		(
			tr("TELEMETRY_INFO")
			% [
				float(data["drift_deg"]),
				float(data["nitro"]) * 100.0,
				int(data["contacts"]),
				Engine.get_frames_per_second()
			]
		)
	)
	lines.append(tr("TELEMETRY_HEADER"))
	var wheels: Dictionary = data["wheels"]
	for position: String in wheels:
		var wheel: Dictionary = wheels[position]
		lines.append(
			(
				"%-4s %8.0f %8.1f %7.2f %8.0f%%%s"
				% [
					position,
					float(wheel["load"]),
					float(wheel["slip_angle_deg"]),
					float(wheel["slip_ratio"]),
					float(wheel["grip_usage"]) * 100.0,
					"" if bool(wheel["contact"]) else tr("TELEMETRY_AIR")
				]
			)
		)
	return "\n".join(lines)
