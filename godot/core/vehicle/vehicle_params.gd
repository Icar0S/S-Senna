class_name VehicleParams
extends RefCounted
## Everything the physics of one car needs, in SI units. Produced by
## [method HandlingModel.compute]; `tuning_overrides` of `car.json` and the F2
## panel change single fields through [method set_value].

## Fields editable in the F2 panel / `tuning_overrides`: name -> [min, max].
const EDITABLE: Dictionary = {
	"mass_kg": [300.0, 5000.0],
	"max_torque_nm": [10.0, 3000.0],
	"max_power_w": [10000.0, 2000000.0],
	"redline_rpm": [2000.0, 20000.0],
	"tire_mu": [0.3, 3.0],
	"rear_grip_factor": [0.5, 1.5],
	"handbrake_grip_factor": [0.05, 1.0],
	"peak_slip_rad": [0.03, 0.4],
	"max_steer_rad": [0.15, 0.9],
	"steer_falloff_ms": [5.0, 120.0],
	"steer_speed": [1.0, 20.0],
	"spring_k_front": [5000.0, 300000.0],
	"spring_k_rear": [5000.0, 300000.0],
	"damper_front": [200.0, 30000.0],
	"damper_rear": [200.0, 30000.0],
	"antiroll_front": [0.0, 200000.0],
	"antiroll_rear": [0.0, 200000.0],
	"brake_force_n": [1000.0, 80000.0],
	"brake_bias_front": [0.3, 0.9],
	"drag_coef": [0.0, 5.0],
	"downforce_coef": [0.0, 10.0],
	"tire_force_height": [0.0, 1.0],
	"stability": [0.0, 1.0],
	"drift_assist": [0.0, 1.0],
	"countersteer": [0.0, 1.0],
	"nitro_accel": [0.0, 15.0],
	"shift_time_s": [0.0, 1.0],
}

var mass_kg: float = 1200.0
## Center of mass in car space (meters).
var center_of_mass: Vector3 = Vector3(0.0, 0.36, 0.0)
## Principal moments of inertia (kg·m²).
var inertia: Vector3 = Vector3(1000.0, 1500.0, 500.0)
var wheel_radius: float = 0.31
var wheelbase: float = 2.5
var track_width: float = 1.5
## Wheel position (`FL`...) -> hub center at rest, car space.
var wheel_anchors: Dictionary = {}

var max_torque_nm: float = 250.0
var max_power_w: float = 150000.0
var idle_rpm: float = 900.0
var redline_rpm: float = 7000.0
## Total ratio (gearbox x final drive) per forward gear, first gear first.
var gear_ratios: PackedFloat64Array = []
var reverse_ratio: float = 12.0
var drive_efficiency: float = 0.85
## Share of the drive torque on the front axle (FWD 1, RWD 0, AWD ~0.4).
var front_drive_share: float = 0.0
var shift_time_s: float = 0.16
var upshift_rpm_frac: float = 0.95
var downshift_rpm_frac: float = 0.5
var top_speed_ms: float = 60.0

var tire_mu: float = 1.3
var rear_grip_factor: float = 1.0
var handbrake_grip_factor: float = 0.4
var peak_slip_rad: float = 0.12
var traction_factor: float = 1.0
var max_steer_rad: float = 0.6
var steer_falloff_ms: float = 33.0
var steer_speed: float = 6.0

var suspension_travel: float = 0.15
var spring_k_front: float = 40000.0
var spring_k_rear: float = 40000.0
var damper_front: float = 3000.0
var damper_rear: float = 3000.0
var antiroll_front: float = 20000.0
var antiroll_rear: float = 15000.0
## Spring length with no load (mount to wheel center).
var spring_rest_front: float = 0.23
var spring_rest_rear: float = 0.23

var brake_force_n: float = 14000.0
var brake_bias_front: float = 0.62
var drag_coef: float = 0.4
var rolling_coef: float = 0.012
var downforce_coef: float = 1.0
var tire_force_height: float = 0.55

var stability: float = 0.6
var drift_assist: float = 0.6
var countersteer: float = 0.45
var max_drift_rad: float = 0.7
var abs_enabled: bool = true
var traction_control: bool = true
var progressive_steering: bool = true
var auto_gearbox: bool = true
var auto_right_strength: float = 10.0

var nitro_capacity_s: float = 0.0
var nitro_accel: float = 4.5
var nitro_refill_per_s: float = 0.06


## Sets [param field] (one of [constant EDITABLE]), clamped to its range. Springs
## and dampers keep the static ride height consistent (rest lengths are recomputed).
func set_value(field: String, value: float) -> void:
	if not EDITABLE.has(field):
		return
	var limits: Array = EDITABLE[field]
	set(field, clampf(value, limits[0], limits[1]))
	if field.begins_with("spring_k") or field == "mass_kg":
		update_rest_lengths()


## Applies `tuning_overrides` (field -> number). Unknown fields are ignored.
func apply_overrides(overrides: Dictionary) -> void:
	for field: Variant in overrides:
		var value: Variant = overrides[field]
		if value is float or value is int:
			set_value(str(field), float(value))


## The editable fields and their current values.
func editable_values() -> Dictionary:
	var values: Dictionary = {}
	for field: String in EDITABLE:
		values[field] = float(get(field))
	return values


## Rest lengths so that, under the car's weight, the wheels sit at their anchors.
func update_rest_lengths() -> void:
	var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var front_share: float = _front_weight_share()
	var front_load: float = mass_kg * gravity * front_share / 2.0
	var rear_load: float = mass_kg * gravity * (1.0 - front_share) / 2.0
	spring_rest_front = suspension_travel + front_load / spring_k_front
	spring_rest_rear = suspension_travel + rear_load / spring_k_rear


func gear_count() -> int:
	return gear_ratios.size()


func _front_weight_share() -> float:
	if wheel_anchors.is_empty():
		return 0.5
	var front_z: float = (wheel_anchors["FL"] as Vector3).z
	var rear_z: float = (wheel_anchors["RL"] as Vector3).z
	return clampf((center_of_mass.z - rear_z) / maxf(front_z - rear_z, 0.01), 0.1, 0.9)
