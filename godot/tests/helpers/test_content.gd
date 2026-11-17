class_name TestContent
extends RefCounted
## Valid content dictionaries and temporary packs for the content tests.
## Each `*_dict()` returns a minimal VALID definition; tests mutate copies of it.

const DUMMY_MODEL: String = "model.glb"


static func pack_dict(
	id: String, priority: int = 0, depends: Array = [], aliases: Dictionary = {}
) -> Dictionary:
	return {
		"schema": "pack",
		"schema_version": 1,
		"id": id,
		"name": "Pacote %s" % id,
		"version": "1.0.0",
		"authors": ["Testes"],
		"license": "MIT",
		"depends": depends,
		"priority": priority,
		"aliases": aliases,
	}


static func car_dict(pack: String = "test", slug: String = "carro") -> Dictionary:
	return {
		"schema": "car",
		"schema_version": 1,
		"id": "car:%s/%s" % [pack, slug],
		"display_name": "Carro %s" % slug,
		"manufacturer": "Teste",
		"year": 2000,
		"category": "jdm",
		"model": DUMMY_MODEL,
		"dimensions_mm": {"length": 4300, "width": 1760, "height": 1250, "wheelbase": 2550},
		"parts":
		[
			{"slot": "body", "variant": "stock"},
			{"slot": "bumper_front", "variant": "stock"},
			{"slot": "bumper_front", "variant": "kit01", "name": "Kit", "price": 1500},
			{"slot": "spoiler", "variant": "stock", "accepts_universal": true},
		],
		"sockets": {"spoiler": {"width_m": 1.3}, "lip_front": {"width_m": 1.6}},
		"wheels":
		{
			"anchors":
			{
				"FL": [0.76, 0.31, 1.27],
				"FR": [-0.76, 0.31, 1.27],
				"RL": [0.76, 0.31, -1.27],
				"RR": [-0.76, 0.31, -1.27],
			},
			"tire_outer_diameter_m": 0.62,
			"stock": {"rim": "rim-stock", "rim_in": 16, "width_in": 7.5},
		},
		"paint":
		{
			"zones": ["paint_body"],
			"default": {"paint_body": {"finish": "metallic", "color": "#B3121B", "flake": 0.5}},
		},
		"stats":
		{
			"power_hp": 200,
			"torque_nm": 250,
			"redline_rpm": 7000,
			"mass_kg": 1200,
			"drivetrain": "RWD",
			"top_speed_kmh": 220,
			"grip": 0.7,
		},
		"economy": {"price": 20000, "unlock": "default"},
	}


static func part_dict(
	pack: String = "test",
	slot: String = "spoiler",
	slug: String = "asa",
	socket: String = "spoiler"
) -> Dictionary:
	var fit: Dictionary = {"reference_width_m": 1.4, "scale_x_min": 0.85, "scale_x_max": 1.15}
	if not socket.is_empty():
		fit["socket"] = socket
	return {
		"schema": "part",
		"schema_version": 1,
		"id": "part:%s/universal/%s/%s" % [pack, slot, slug],
		"slot": slot,
		"display_name": "Peça %s" % slug,
		"model": DUMMY_MODEL,
		"fit": fit,
		"compatible": {"cars": "*", "exclude": []},
		"rules": {"hides": [slot], "requires": [], "conflicts": []},
		"finishes": ["paint", "carbon"],
		"price": 2000,
	}


static func wheel_dict(pack: String = "test", slug: String = "aro") -> Dictionary:
	return {
		"schema": "wheel",
		"schema_version": 1,
		"id": "wheel:%s/%s" % [pack, slug],
		"display_name": "Aro %s" % slug,
		"model": "rim.glb",
		"rim_in_min": 15,
		"rim_in_max": 20,
		"paint_zones": ["rim"],
		"default_paint": {"rim": {"finish": "metallic", "color": "#C0C0C0"}},
		"price": 900,
	}


static func vinyl_set_dict(pack: String = "test", category: String = "tribal") -> Dictionary:
	return {
		"schema": "vinyl_set",
		"schema_version": 1,
		"category": category,
		"category_name_key": "VINYL_CAT_TEST",
		"vinyls":
		[
			{"id": "vinyl:%s/%s/chama_01" % [pack, category], "file": "chama_01.svg", "colors": 1},
			{"id": "vinyl:%s/%s/garra_02" % [pack, category], "file": "garra_02.png", "colors": 3},
		],
	}


static func vinyl_entry_dict(pack: String = "test") -> Dictionary:
	return {
		"id": "vinyl:%s/tribal/chama_01" % pack, "file": "chama_01.svg", "colors": 1, "price": 300
	}


static func paints_dict(pack: String = "test") -> Dictionary:
	return {
		"schema": "paint_catalog",
		"schema_version": 1,
		"finishes": ["solid", "pearl"],
		"presets":
		[
			{
				"id": "paint:%s/vermelho" % pack,
				"name_key": "PAINT_RED",
				"finish": "solid",
				"color": "#C8102E"
			},
			{
				"id": "paint:%s/perola" % pack,
				"name_key": "PAINT_PEARL",
				"finish": "pearl",
				"color": "#1A3CFF",
				"color2": "#9B5CFF",
				"flake": 0.4,
			},
		],
	}


static func paint_spec_dict() -> Dictionary:
	return {"finish": "pearl", "color": "#1A3CFF", "color2": "#9B5CFF", "flake": 0.4, "gloss": 0.95}


static func track_dict(pack: String = "test", slug: String = "pista") -> Dictionary:
	return {
		"schema": "track",
		"schema_version": 1,
		"id": "track:%s/%s" % [pack, slug],
		"display_name_key": "TRACK_TEST",
		"scene": "res://game/tracks/%s/%s.tscn" % [slug, slug],
		"time_of_day": "noite",
		"layouts":
		[
			{"id": "circuito", "type": "circuit", "node": "Layouts/Circuito", "default_laps": 3},
			{"id": "arrancada", "type": "drag", "node": "Layouts/Arrancada"},
		],
	}


static func sound_dict(pack: String = "test", slug: String = "motor") -> Dictionary:
	return {
		"schema": "sound_profile",
		"schema_version": 1,
		"id": "sound:%s/engine/%s" % [pack, slug],
		"loops":
		[
			{"file": "idle.ogg", "rpm": 1000, "load": "any"},
			{"file": "high_on.ogg", "rpm": 7000, "load": "on"},
		],
		"extras": {"turbo": "turbo.ogg"},
	}


static func upgrades_dict() -> Dictionary:
	return {
		"schema": "upgrades",
		"schema_version": 1,
		"levels": ["stock", "rua"],
		"categories":
		{
			"engine": {"effects_per_level": [{}, {"power_pct": 8}]},
			"tires": {"effects_per_level": [{}, {"grip_add": 0.04}]},
		},
		"price_factor_per_level": [0, 0.06],
	}


static func economy_dict() -> Dictionary:
	return {
		"schema": "economy",
		"schema_version": 1,
		"starting_money": 15000,
		"sell_factor": 0.5,
		"upgrade_min_price": 500,
		"part_default_price": {"bumper_front": 1200, "spoiler": 1000},
		"category_price_factor": {"jdm": 1.0, "super": 1.5},
		"pi_classes": {"D": 0, "C": 400, "S": 800},
		"race_reward_base": {"circuit": 3000},
	}


## Writes a pack at [param dir]: `pack.json` plus [param files] (relative path -> data).
## Every car gets an empty `model.glb` so the scan finds a model (scans never open it).
static func write_pack(dir: String, pack: Dictionary, files: Dictionary = {}) -> void:
	write_json(dir.path_join("pack.json"), pack)
	for relative: String in files:
		var path: String = dir.path_join(relative)
		write_json(path, files[relative])
		if relative.get_file() == "car.json":
			write_bytes(path.get_base_dir().path_join(DUMMY_MODEL), PackedByteArray())


static func write_json(path: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	file.close()


static func write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## Options that read only [param builtin_dir] (no mods, no extra folders).
static func options_for(builtin_dir: String) -> ContentScanOptions:
	var options: ContentScanOptions = ContentScanOptions.new()
	options.builtin_dirs = PackedStringArray([builtin_dir])
	options.mods_dir = ""
	return options


## Sets a nested value: set_nested(d, ["stats", "grip"], 1.5).
static func set_nested(data: Dictionary, path: Array, value: Variant) -> void:
	var target: Variant = data
	for i: int in path.size() - 1:
		target = target[path[i]]
	target[path[path.size() - 1]] = value


static func erase_nested(data: Dictionary, path: Array) -> void:
	var target: Variant = data
	for i: int in path.size() - 1:
		target = target[path[i]]
	if target is Dictionary:
		(target as Dictionary).erase(path[path.size() - 1])
