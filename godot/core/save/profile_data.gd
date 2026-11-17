class_name ProfileData
extends RefCounted
## A player profile: the `data` part of `profile.json` (doc 03 §14).
## Unknown fields are preserved; free-form parts (career, records, looks) are kept
## as dictionaries until the stages that use them define their own classes.

const ID_PATTERN: String = "^[a-z0-9_]+$"
const GEARBOX_MODES: PackedStringArray = ["auto", "manual"]
const DEFAULT_CAMERA: String = "chase_far"
const ASSISTS: PackedStringArray = ["steering", "stability", "abs", "traction"]

var id: String = ""
var name: String = ""
var created_at: String = ""
## Collector mode: everything unlocked and free (Economy checks this flag).
var sandbox: bool = false
var avatar: int = 0
var money: int = 0
var reputation: int = 0
## `instance_id` of the selected car.
var selected_car: String = ""
var cars: Array[CarConfig] = []
var unlocked_parts: PackedStringArray = []
var unlocked_cars: PackedStringArray = []
var unlocked_vinyls: PackedStringArray = []
var unlocked_wheels: PackedStringArray = []
var career_chapter: int = 1
## Event ID -> result (e.g. `{"best_pos": 1}`).
var events_done: Dictionary = {}
var messages_read: PackedStringArray = []
## `track:...#layout` -> record (e.g. `{"best_lap_ms": 61234, "car_instance": "c7f3a2"}`).
var records: Dictionary = {}
var my_colors: PackedStringArray = []
## Saved looks: `{"name", "car_id", "config"}`.
var looks: Array = []
var camera: String = DEFAULT_CAMERA
## Assist name -> bool, plus `gearbox` -> `auto`/`manual`.
var assists: Dictionary = default_assists()
var stats_races: int = 0
var stats_wins: int = 0
var stats_distance_km: float = 0.0
var stats_money_earned: int = 0
## Unknown fields, written back unchanged.
var extra: Dictionary = {}
## Runtime only: loaded from a newer game version, so it must not be saved.
var read_only: bool = false


static func default_assists() -> Dictionary:
	return {"steering": true, "stability": true, "abs": true, "traction": true, "gearbox": "auto"}


static func is_valid_id(profile_id: String) -> bool:
	return RegEx.create_from_string(ID_PATTERN).search(profile_id) != null


static func from_dict(data: Dictionary, ctx: LoadContext) -> ProfileData:
	var reader: DictReader = DictReader.new(data, ctx)
	var profile: ProfileData = ProfileData.new()
	var info: DictReader = reader.child("profile", true)
	profile.id = info.text("id", true)
	profile.name = info.text("name")
	profile.created_at = info.text("created_at")
	profile.sandbox = info.boolean("sandbox")
	profile.avatar = info.integer("avatar", false, 0, 0, 999)
	var wallet: DictReader = reader.child("wallet")
	profile.money = wallet.integer("money", false, 0, 0)
	profile.reputation = wallet.integer("reputation", false, 0, 0)
	var garage: DictReader = reader.child("garage")
	profile.selected_car = garage.text("selected")
	for car_reader: DictReader in garage.child_list("cars"):
		var car_data: Dictionary = {}
		for key: String in car_reader.keys():
			car_data[key] = car_reader.raw(key)
		profile.cars.append(CarConfig.from_dict(car_data, ctx))
	var unlocks: DictReader = reader.child("unlocks")
	profile.unlocked_parts = unlocks.string_list("parts")
	profile.unlocked_cars = unlocks.string_list("cars")
	profile.unlocked_vinyls = unlocks.string_list("vinyls")
	profile.unlocked_wheels = unlocks.string_list("wheels")
	var career: DictReader = reader.child("career")
	profile.career_chapter = career.integer("chapter", false, 1, 1)
	profile.events_done = SaveValues.dict_or_empty(career.raw("events_done"))
	profile.messages_read = career.string_list("messages_read")
	profile.records = SaveValues.dict_or_empty(reader.raw("records"))
	profile.my_colors = reader.string_list("my_colors")
	var looks_value: Variant = reader.raw("looks", [])
	profile.looks = SaveValues.normalize(looks_value) if looks_value is Array else []
	var prefs: DictReader = reader.child("player_prefs")
	profile.camera = prefs.text("camera", false, DEFAULT_CAMERA)
	var assists_reader: DictReader = prefs.child("assists")
	for assist: String in ASSISTS:
		profile.assists[assist] = assists_reader.boolean(assist, true)
	profile.assists["gearbox"] = assists_reader.enum_value("gearbox", GEARBOX_MODES, false, "auto")
	var stats: DictReader = reader.child("stats")
	profile.stats_races = stats.integer("races", false, 0, 0)
	profile.stats_wins = stats.integer("wins", false, 0, 0)
	profile.stats_distance_km = stats.number("distance_km", false, 0.0, 0.0)
	profile.stats_money_earned = stats.integer("money_earned", false, 0, 0)
	profile.extra = SaveValues.normalize(reader.take_unread())
	return profile


func to_dict() -> Dictionary:
	var cars_list: Array = []
	for car: CarConfig in cars:
		cars_list.append(car.to_dict())
	var data: Dictionary = {
		"profile":
		{"id": id, "name": name, "created_at": created_at, "sandbox": sandbox, "avatar": avatar},
		"wallet": {"money": money, "reputation": reputation},
		"garage": {"selected": selected_car, "cars": cars_list},
		"unlocks":
		{
			"parts": Array(unlocked_parts),
			"cars": Array(unlocked_cars),
			"vinyls": Array(unlocked_vinyls),
			"wheels": Array(unlocked_wheels),
		},
		"career":
		{
			"chapter": career_chapter,
			"events_done": events_done.duplicate(true),
			"messages_read": Array(messages_read),
		},
		"records": records.duplicate(true),
		"my_colors": Array(my_colors),
		"looks": looks.duplicate(true),
		"player_prefs": {"camera": camera, "assists": assists.duplicate()},
		"stats":
		{
			"races": stats_races,
			"wins": stats_wins,
			"distance_km": stats_distance_km,
			"money_earned": stats_money_earned,
		},
	}
	return SaveValues.with_extra(data, extra.duplicate(true))


## The car with [param instance_id], or null.
func get_car(instance_id: String) -> CarConfig:
	for car: CarConfig in cars:
		if car.instance_id == instance_id:
			return car
	return null


## A new `instance_id` not used by any car of this profile.
func new_car_instance_id() -> String:
	var candidate: String = ""
	while candidate.is_empty() or get_car(candidate) != null:
		candidate = "%06x" % (randi() & 0xFFFFFF)
	return candidate
