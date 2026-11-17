class_name TestSaves
extends RefCounted
## Builders for save tests: fully customized cars and profiles, and file
## operations that fail on purpose.

const MISSING_MOD_PART: String = "part:mod_sumido/universal/spoiler/asa_gigante"
const FIXED_TIME: String = "2026-11-17T12:00:00Z"


## A car with every customization field filled. [param seed_value] varies the values.
static func full_car(seed_value: int) -> CarConfig:
	var car: CarConfig = CarConfig.new()
	car.instance_id = "c%05d" % seed_value
	car.car_id = "car:base/prototipo"
	car.nickname = "Carro nº %d — Ação 🚗" % seed_value
	car.parts = {
		"bumper_front": "part:base/prototipo/bumper_front-kit0%d" % (1 + seed_value % 2),
		"spoiler": MISSING_MOD_PART,
	}
	car.part_finish = {"hood": "carbon", "spoiler": "carbon"}
	car.part_fit = {"spoiler": {"height_m": 0.04}}
	car.wheel_front = _wheel("wheel:base/basica_5", 18, 9.0, 15.0, -3.0)
	car.wheel_rear = _wheel("wheel:base/disco", 18, 10.5, 20.0, -4.5)
	car.wheel_paint = {
		"rim": _paint("metallic", "#202020", "", 0.3, 0.9),
		"rim_accent": _paint("chrome", "#FFFFFF", "", 0.0, 1.0),
	}
	car.caliper_color = "#FFD000"
	car.ride_height_mm = -35.0 - seed_value % 10
	car.paint = {
		"paint_body": _paint("pearl", "#F2F2F2", "#7FD3FF", 0.3, 0.95),
		"paint_secondary": _paint("matte", "#111111", "", 0.0, 0.1),
		"trim_black": "body_color",
	}
	var layer: CarConfig.VinylLayer = CarConfig.VinylLayer.new()
	layer.vinyl_id = "vinyl:base/tribal/chama_01"
	layer.pos = Vector2(0.45, 0.55)
	layer.scale = Vector2(1.25, 0.5)
	layer.rot_deg = 12.0
	layer.colors = PackedStringArray(["#FF3B00"])
	var left: Array[CarConfig.VinylLayer] = [layer]
	var empty: Array[CarConfig.VinylLayer] = []
	car.vinyls = {"left": left, "right": "mirror_left", "top": empty}
	car.glass_tint = "#101418"
	car.glass_darkness = 0.6
	car.headlight_color = "#CFE6FF"
	car.neon_enabled = true
	car.neon_color = "#00E5FF"
	car.neon_mode = "pulsante"
	car.plate_text = "SNN-%04d" % seed_value
	car.performance = {"engine": 2, "turbo": 3, "tires": seed_value % 4}
	car.tuning = {"steering": 0.5, "grip_drift": 0.25, "brake_bias": 0.75}
	car.nitro_style = "curto"
	car.stats_races = 14 + seed_value
	car.stats_wins = 6
	car.stats_distance_km = 182.5
	return car


## A profile with [param car_count] full cars and the free-form parts filled.
static func full_profile(profile_id: String, car_count: int) -> ProfileData:
	var profile: ProfileData = ProfileData.new()
	profile.id = profile_id
	profile.name = "Jogadora Ção 🏁"
	profile.created_at = FIXED_TIME
	profile.avatar = 3
	profile.money = 12000
	profile.reputation = 340
	for i: int in car_count:
		profile.cars.append(full_car(i))
	profile.selected_car = profile.cars[0].instance_id if car_count > 0 else ""
	profile.unlocked_parts = PackedStringArray(["part:base/universal/spoiler/asa_simples"])
	profile.career_chapter = 2
	profile.events_done = {"evt_c1_01": {"best_pos": 1}}
	profile.messages_read = PackedStringArray(["msg_001"])
	profile.records = {
		"track:base/centro#circuito": {"best_lap_ms": 61234, "car_instance": "c00000"}
	}
	profile.my_colors = PackedStringArray(["#00E5FF", "#FF3B00"])
	profile.looks = [
		{
			"name": "Estilo Neon",
			"car_id": "car:base/prototipo",
			"config": {"plate": {"text": "NEON"}}
		}
	]
	profile.assists["abs"] = false
	profile.assists["gearbox"] = "manual"
	profile.stats_races = 40
	profile.stats_distance_km = 610.25
	return profile


static func store(
	base_dir: String, ops: FileOps = null, migrations: Migrations = null
) -> ProfileStore:
	var profile_store: ProfileStore = ProfileStore.new(base_dir, ops, migrations)
	profile_store.clock = func() -> String: return FIXED_TIME
	return profile_store


static func _wheel(
	wheel_id: String, rim_in: int, width_in: float, offset_mm: float, camber_deg: float
) -> CarConfig.WheelSetting:
	var setting: CarConfig.WheelSetting = CarConfig.WheelSetting.new()
	setting.wheel_id = wheel_id
	setting.rim_in = rim_in
	setting.width_in = width_in
	setting.offset_mm = offset_mm
	setting.camber_deg = camber_deg
	return setting


static func _paint(
	finish: String, color: String, color2: String, flake: float, gloss: float
) -> PaintSpec:
	var spec: PaintSpec = PaintSpec.new()
	spec.finish = finish
	spec.color = color
	spec.color2 = color2
	spec.flake = flake
	spec.gloss = gloss
	return spec


## File operations that fail or lie on purpose.
class FaultyFileOps:
	extends FileOps
	## Fail writes of files whose name ends with this ("" = never).
	var fail_writes_ending: String = ""
	## Write only half of the text but report success (silent disk problem).
	var truncate_writes: bool = false
	var writes: int = 0

	func write_text(path: String, text: String) -> Error:
		writes += 1
		if not fail_writes_ending.is_empty() and path.ends_with(fail_writes_ending):
			return ERR_FILE_CANT_WRITE
		if truncate_writes:
			return super.write_text(path, text.substr(0, text.length() / 2))
		return super.write_text(path, text)
