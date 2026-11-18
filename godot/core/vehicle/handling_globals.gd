class_name HandlingGlobals
extends RefCounted
## Global "feel" constants of the driving model (`handling_global.json`, doc 03 §12.2).
## The F2 tuning panel edits these live and can save them back to the pack.
## Every field has a [constant RANGES] entry (min, max) used by the reader and the panel.

const SCHEMA: String = "handling_global"
const SCHEMA_VERSION: int = 1
const FILE_NAME: String = "handling_global.json"

## Field -> [min, max]. Order = order in the F2 panel.
const RANGES: Dictionary = {
	"grip_min": [0.5, 2.5],
	"grip_max": [0.5, 3.0],
	"peak_slip_deg": [2.0, 20.0],
	"rear_grip_factor": [0.6, 1.4],
	"handbrake_grip_factor": [0.1, 1.0],
	"steer_deg_min": [10.0, 50.0],
	"steer_deg_max": [10.0, 50.0],
	"steer_falloff_kmh": [40.0, 400.0],
	"steer_speed": [1.0, 20.0],
	"suspension_freq_front": [0.8, 4.0],
	"suspension_freq_rear": [0.8, 4.0],
	"damping_ratio": [0.1, 1.2],
	"antiroll": [0.0, 2.0],
	"suspension_travel_m": [0.05, 0.4],
	"com_height_m": [0.15, 0.8],
	"yaw_inertia_factor": [0.5, 3.0],
	"roll_inertia_factor": [0.5, 4.0],
	"downforce_ratio_200": [0.0, 1.5],
	"rolling_resistance": [0.0, 0.05],
	"brake_decel_g_min": [0.4, 2.0],
	"brake_decel_g_max": [0.4, 2.5],
	"brake_bias_front": [0.3, 0.9],
	"drive_efficiency": [0.5, 1.0],
	"traction_factor": [0.5, 2.0],
	"gear_spread": [1.5, 6.0],
	"shift_time_s": [0.0, 1.0],
	"upshift_rpm_frac": [0.6, 1.0],
	"downshift_rpm_frac": [0.2, 0.8],
	"idle_rpm": [400.0, 2000.0],
	"tire_force_height": [0.0, 1.0],
	"stability": [0.0, 1.0],
	"drift_assist": [0.0, 1.0],
	"countersteer": [0.0, 1.0],
	"max_drift_deg": [10.0, 80.0],
	"nitro_accel": [0.0, 15.0],
	"nitro_refill_per_s": [0.0, 1.0],
	"auto_right_strength": [0.0, 30.0],
}

var grip_min: float = 1.05
var grip_max: float = 1.6
var peak_slip_deg: float = 7.0
var rear_grip_factor: float = 1.02
var handbrake_grip_factor: float = 0.4
var steer_deg_min: float = 30.0
var steer_deg_max: float = 38.0
var steer_falloff_kmh: float = 120.0
var steer_speed: float = 6.0
var suspension_freq_front: float = 1.8
var suspension_freq_rear: float = 1.9
var damping_ratio: float = 0.45
var antiroll: float = 0.6
var suspension_travel_m: float = 0.15
var com_height_m: float = 0.36
var yaw_inertia_factor: float = 1.3
var roll_inertia_factor: float = 1.8
var downforce_ratio_200: float = 0.3
var rolling_resistance: float = 0.012
var brake_decel_g_min: float = 0.85
var brake_decel_g_max: float = 1.25
var brake_bias_front: float = 0.62
var drive_efficiency: float = 0.85
var traction_factor: float = 1.0
var gear_spread: float = 3.4
var shift_time_s: float = 0.16
var upshift_rpm_frac: float = 0.95
var downshift_rpm_frac: float = 0.5
var idle_rpm: float = 900.0
var tire_force_height: float = 0.55
var stability: float = 0.6
var drift_assist: float = 0.6
var countersteer: float = 0.45
var max_drift_deg: float = 40.0
var nitro_accel: float = 4.5
var nitro_refill_per_s: float = 0.06
var auto_right_strength: float = 10.0


static func from_dict(data: Dictionary, ctx: LoadContext) -> HandlingGlobals:
	var errors_before: int = ctx.report.error_count()
	var reader: DictReader = DictReader.new(data, ctx)
	reader.check_header(SCHEMA, SCHEMA_VERSION)
	var globals: HandlingGlobals = HandlingGlobals.new()
	for field: String in RANGES:
		var limits: Array = RANGES[field]
		var value: float = reader.number(
			field, false, float(globals.get(field)), limits[0], limits[1]
		)
		globals.set(field, value)
	reader.finish()
	return globals if ctx.report.error_count() == errors_before else null


func to_dict() -> Dictionary:
	var data: Dictionary = {"schema": SCHEMA, "schema_version": SCHEMA_VERSION}
	for field: String in RANGES:
		data[field] = snappedf(float(get(field)), 0.0001)
	return data


func copy() -> HandlingGlobals:
	var result: HandlingGlobals = HandlingGlobals.new()
	for field: String in RANGES:
		result.set(field, get(field))
	return result
