class_name HandlingModel
extends RefCounted
## The whole "feel" of a car in one pure function (doc 02 §5.3):
## stats + upgrades + tuning + assists + global constants -> [VehicleParams].
##
## Key choices (arcade, but predictable):
## - Engine: flat torque (`torque_nm`) until it reaches `power_hp`, then flat power
##   up to the redline.
## - Top gear puts the engine at 90% of the redline exactly at `top_speed_kmh`, and the
##   drag coefficient makes power = drag + rolling there, so the top speed is reached
##   but not passed.
## - Springs from a natural frequency, dampers from a damping ratio, so every car
##   (light or heavy) behaves alike.

const KMH: float = 1.0 / 3.6
const HP: float = 745.7
const TOP_SPEED_RPM_FRAC: float = 0.9
const GRAVITY: float = 9.8
const KMH_200: float = 200.0 / 3.6
## Tuning sliders are 0..1 with 0.5 = neutral.
const NEUTRAL: float = 0.5


## Builds the parameters. [param upgrade_levels]: category -> level; [param tuning]:
## slider -> 0..1; [param assists]: profile assists (`steering`, `stability`, `abs`,
## `traction`, `gearbox`).
static func compute(
	car: CarDef,
	upgrade_levels: Dictionary = {},
	upgrades: UpgradeTable = null,
	tuning: Dictionary = {},
	assists: Dictionary = {},
	globals: HandlingGlobals = null
) -> VehicleParams:
	var g: HandlingGlobals = globals if globals != null else HandlingGlobals.new()
	var effects: Dictionary = _sum_effects(upgrade_levels, upgrades)
	var p: VehicleParams = VehicleParams.new()
	var stats: CarDef.Stats = car.stats
	var handling: float = clampf(stats.handling + float(effects.get("handling_add", 0.0)), 0.0, 1.0)
	var grip: float = clampf(stats.grip + float(effects.get("grip_add", 0.0)), 0.0, 1.0)
	var braking: float = clampf(stats.braking + float(effects.get("braking_add", 0.0)), 0.0, 1.0)
	p.mass_kg = stats.mass_kg * (1.0 + float(effects.get("mass_pct", 0.0)) / 100.0)
	p.max_power_w = stats.power_hp * HP * (1.0 + float(effects.get("power_pct", 0.0)) / 100.0)
	p.max_torque_nm = stats.torque_nm * (1.0 + float(effects.get("torque_pct", 0.0)) / 100.0)
	p.redline_rpm = stats.redline_rpm
	p.idle_rpm = g.idle_rpm
	_geometry(p, car, g)
	_engine_and_gears(p, car, g, effects, tuning)
	_tires_and_steering(p, g, grip, handling, tuning)
	_suspension(p, g, handling)
	var decel_g: float = lerpf(g.brake_decel_g_min, g.brake_decel_g_max, braking)
	p.brake_force_n = p.mass_kg * GRAVITY * decel_g
	p.brake_bias_front = clampf(
		g.brake_bias_front + (_slider(tuning, "brake_bias") - NEUTRAL) * 0.3, 0.3, 0.9
	)
	p.rolling_coef = g.rolling_resistance
	var downforce_mult: float = lerpf(0.5, 1.5, _slider(tuning, "downforce"))
	p.downforce_coef = (
		g.downforce_ratio_200 * p.mass_kg * GRAVITY / (KMH_200 * KMH_200) * downforce_mult
	)
	_drag(p)
	p.tire_force_height = g.tire_force_height
	p.nitro_capacity_s = float(effects.get("nitro_capacity_s", 0.0))
	p.nitro_accel = g.nitro_accel
	p.nitro_refill_per_s = g.nitro_refill_per_s
	p.auto_right_strength = g.auto_right_strength
	_assists(p, g, assists)
	p.update_rest_lengths()
	return p


## Expected time (s) from 0 to [param target_kmh] with full throttle on flat ground,
## by integrating the same force model in 1D (used by the tests as the reference).
static func estimate_acceleration_time(p: VehicleParams, target_kmh: float = 100.0) -> float:
	var dt: float = 1.0 / 120.0
	var v: float = 0.0
	var t: float = 0.0
	var gear: int = 0
	var shift_left: float = 0.0
	var traction: float = (
		p.tire_mu * GRAVITY * p.mass_kg * _driven_weight_share(p) * p.traction_factor
	)
	while v < target_kmh * KMH and t < 120.0:
		var force: float = 0.0
		if shift_left > 0.0:
			shift_left -= dt
		else:
			var rpm: float = wheel_rpm(p, v) * p.gear_ratios[gear]
			if rpm > p.redline_rpm * p.upshift_rpm_frac and gear < p.gear_count() - 1:
				gear += 1
				shift_left = p.shift_time_s
			else:
				var engine_rpm: float = maxf(rpm, p.idle_rpm)
				force = (
					engine_torque(p, engine_rpm)
					* p.gear_ratios[gear]
					* p.drive_efficiency
					/ p.wheel_radius
				)
				force = minf(force, traction)
		force -= p.drag_coef * v * v + p.rolling_coef * p.mass_kg * GRAVITY
		v += force / p.mass_kg * dt
		t += dt
	return t


## Expected stopping distance (m) from [param speed_kmh] with full brakes.
static func estimate_braking_distance(p: VehicleParams, speed_kmh: float = 100.0) -> float:
	var dt: float = 1.0 / 120.0
	var v: float = speed_kmh * KMH
	var distance: float = 0.0
	var grip_limit: float = p.tire_mu * GRAVITY * p.mass_kg
	while v > 0.0:
		var force: float = minf(p.brake_force_n, grip_limit) + p.drag_coef * v * v
		force += p.rolling_coef * p.mass_kg * GRAVITY
		v -= force / p.mass_kg * dt
		distance += maxf(v, 0.0) * dt
	return distance


## Engine torque (N·m) at [param rpm]: rises from 70% at idle to the peak by 40%
## of the redline, then limited by the maximum power.
static func engine_torque(p: VehicleParams, rpm: float) -> float:
	var clamped: float = clampf(rpm, p.idle_rpm, p.redline_rpm)
	var rise: float = clampf(
		(clamped - p.idle_rpm) / maxf(p.redline_rpm * 0.4 - p.idle_rpm, 1.0), 0.0, 1.0
	)
	var torque: float = p.max_torque_nm * lerpf(0.7, 1.0, rise)
	var omega: float = clamped * TAU / 60.0
	return minf(torque, p.max_power_w / maxf(omega, 1.0))


## Wheel revolutions per minute at [param speed_ms].
static func wheel_rpm(p: VehicleParams, speed_ms: float) -> float:
	return speed_ms / p.wheel_radius * 60.0 / TAU


static func _geometry(p: VehicleParams, car: CarDef, g: HandlingGlobals) -> void:
	p.wheel_anchors = car.wheels.anchors.duplicate()
	p.wheel_radius = car.wheels.tire_outer_diameter_m / 2.0
	var front_z: float = (car.wheels.anchors["FL"] as Vector3).z
	var rear_z: float = (car.wheels.anchors["RL"] as Vector3).z
	p.wheelbase = front_z - rear_z
	p.track_width = absf((car.wheels.anchors["FL"] as Vector3).x * 2.0)
	var com_z: float = rear_z + p.wheelbase * car.stats.weight_front_pct / 100.0
	p.center_of_mass = Vector3(0.0, g.com_height_m, com_z)
	var length: float = car.dimensions.length_mm / 1000.0
	var width: float = car.dimensions.width_mm / 1000.0
	var height: float = car.dimensions.height_mm / 1000.0
	var m: float = p.mass_kg / 12.0
	p.inertia = Vector3(
		m * (height * height + length * length) * g.roll_inertia_factor,
		m * (width * width + length * length) * g.yaw_inertia_factor,
		m * (width * width + height * height) * g.roll_inertia_factor
	)


static func _engine_and_gears(
	p: VehicleParams, car: CarDef, g: HandlingGlobals, effects: Dictionary, tuning: Dictionary
) -> void:
	var power_ratio: float = p.max_power_w / (car.stats.power_hp * HP)
	# Drag-limited: more power raises the top speed with the cube root.
	p.top_speed_ms = car.stats.top_speed_kmh * KMH * pow(power_ratio, 1.0 / 3.0)
	var gearing: float = lerpf(1.1, 0.92, _slider(tuning, "gearing"))
	var top_ratio: float = (
		p.redline_rpm * TOP_SPEED_RPM_FRAC / wheel_rpm(p, p.top_speed_ms) * gearing
	)
	var gears: int = car.stats.gears
	p.gear_ratios = PackedFloat64Array()
	for i: int in gears:
		var step: float = float(gears - 1 - i) / maxf(gears - 1, 1)
		p.gear_ratios.append(top_ratio * pow(g.gear_spread, step))
	p.reverse_ratio = p.gear_ratios[0] * 1.1
	p.drive_efficiency = g.drive_efficiency
	p.shift_time_s = g.shift_time_s * (1.0 + float(effects.get("shift_time_pct", 0.0)) / 100.0)
	p.upshift_rpm_frac = g.upshift_rpm_frac
	p.downshift_rpm_frac = g.downshift_rpm_frac
	p.traction_factor = g.traction_factor
	match car.stats.drivetrain:
		"FWD":
			p.front_drive_share = 1.0
		"AWD":
			p.front_drive_share = 0.4
		_:
			p.front_drive_share = 0.0


static func _tires_and_steering(
	p: VehicleParams, g: HandlingGlobals, grip: float, handling: float, tuning: Dictionary
) -> void:
	p.tire_mu = lerpf(g.grip_min, g.grip_max, grip)
	p.peak_slip_rad = deg_to_rad(g.peak_slip_deg)
	var drift_slider: float = _slider(tuning, "grip_drift")
	p.rear_grip_factor = g.rear_grip_factor * lerpf(1.06, 0.88, drift_slider)
	p.handbrake_grip_factor = g.handbrake_grip_factor
	p.max_steer_rad = deg_to_rad(lerpf(g.steer_deg_min, g.steer_deg_max, handling))
	p.steer_falloff_ms = g.steer_falloff_kmh * KMH
	p.steer_speed = g.steer_speed * lerpf(0.7, 1.3, _slider(tuning, "steering"))


static func _suspension(p: VehicleParams, g: HandlingGlobals, handling: float) -> void:
	p.suspension_travel = g.suspension_travel_m
	var stiffer: float = lerpf(0.9, 1.15, handling)
	var front_share: float = _front_share_from_com(p)
	var front_mass: float = p.mass_kg * front_share / 2.0
	var rear_mass: float = p.mass_kg * (1.0 - front_share) / 2.0
	var omega_front: float = TAU * g.suspension_freq_front * stiffer
	var omega_rear: float = TAU * g.suspension_freq_rear * stiffer
	p.spring_k_front = front_mass * omega_front * omega_front
	p.spring_k_rear = rear_mass * omega_rear * omega_rear
	p.damper_front = 2.0 * g.damping_ratio * sqrt(p.spring_k_front * front_mass)
	p.damper_rear = 2.0 * g.damping_ratio * sqrt(p.spring_k_rear * rear_mass)
	p.antiroll_front = p.spring_k_front * g.antiroll
	p.antiroll_rear = p.spring_k_rear * g.antiroll * 0.8


## Drag that balances the maximum power exactly at the top speed.
static func _drag(p: VehicleParams) -> void:
	var v: float = p.top_speed_ms
	var wheel_power: float = p.max_power_w * p.drive_efficiency
	var rolling: float = p.rolling_coef * p.mass_kg * GRAVITY * v
	p.drag_coef = maxf((wheel_power - rolling) / (v * v * v), 0.01)


static func _assists(p: VehicleParams, g: HandlingGlobals, assists: Dictionary) -> void:
	var stability_on: bool = bool(assists.get("stability", true))
	var steering_on: bool = bool(assists.get("steering", true))
	p.stability = g.stability if stability_on else g.stability * 0.15
	p.drift_assist = g.drift_assist if stability_on else 0.0
	p.countersteer = g.countersteer if steering_on else 0.0
	p.progressive_steering = steering_on
	p.max_drift_rad = deg_to_rad(g.max_drift_deg)
	p.abs_enabled = bool(assists.get("abs", true))
	p.traction_control = bool(assists.get("traction", true))
	p.auto_gearbox = str(assists.get("gearbox", "auto")) != "manual"


static func _sum_effects(levels: Dictionary, upgrades: UpgradeTable) -> Dictionary:
	var total: Dictionary = {}
	if upgrades == null:
		return total
	for category: Variant in levels:
		var effects: Dictionary = upgrades.effects_for(str(category), int(levels[category]))
		for effect: String in effects:
			if effect == "nitro_capacity_s":
				total[effect] = float(effects[effect])
			else:
				total[effect] = float(total.get(effect, 0.0)) + float(effects[effect])
	return total


static func _slider(tuning: Dictionary, name: String) -> float:
	return clampf(float(tuning.get(name, NEUTRAL)), 0.0, 1.0)


static func _driven_weight_share(p: VehicleParams) -> float:
	var front: float = _front_share_from_com(p)
	if p.front_drive_share >= 1.0:
		return front
	if p.front_drive_share <= 0.0:
		return 1.0 - front
	return 1.0


static func _front_share_from_com(p: VehicleParams) -> float:
	var front_z: float = (p.wheel_anchors["FL"] as Vector3).z
	var rear_z: float = (p.wheel_anchors["RL"] as Vector3).z
	return clampf((p.center_of_mass.z - rear_z) / maxf(front_z - rear_z, 0.01), 0.1, 0.9)
