class_name ContentLibrary
extends RefCounted
## The content database: discovers packs, reads their JSON into typed definitions
## and answers queries. Pure logic (testable); the `ContentDB` autoload wraps it.
##
## Only `.json` files are read during a scan — models are never opened here
## (exported builds list imported files as `.import`/`.remap`, and loading `.glb`
## is slow). Use [ModelLoader] on demand.

const CARS_DIR: String = "cars"
const UNIVERSAL_PARTS_DIR: String = "parts/universal"
const WHEELS_DIR: String = "wheels"
const VINYLS_DIR: String = "vinyls"
const PAINTS_FILE: String = "paints/paints.json"
const SOUNDS_DIR: String = "sounds"
const TRACKS_DIR: String = "tracks"
const UPGRADES_FILE: String = "upgrades/upgrades.json"
const ECONOMY_FILE: String = "economy.json"
const PACKS_SUBDIR: String = "packs"
const MAX_ALIAS_DEPTH: int = 16

var _report: ContentReport = ContentReport.new()
var _packs: Array[PackDef] = []
var _aliases: Dictionary = {}
var _alias_priority: Dictionary = {}
var _cars: Dictionary = {}
var _parts: Dictionary = {}
var _wheels: Dictionary = {}
var _vinyls: Dictionary = {}
var _paints: Dictionary = {}
var _tracks: Dictionary = {}
var _sounds: Dictionary = {}
## ID -> [owner pack priority, owner pack id].
var _owners: Dictionary = {}
var _paint_catalog: PaintCatalog = PaintCatalog.new()
var _upgrades: UpgradeTable = null
var _upgrades_priority: int = -2147483648
var _economy: EconomyDef = null
var _economy_priority: int = -2147483648


## Clears everything and loads the packs found with [param options].
func scan(options: ContentScanOptions) -> ContentReport:
	_clear()
	var found: Array[PackDef] = _discover(options)
	_packs = _order_by_dependencies(found)
	for pack: PackDef in _packs:
		_load_pack(pack)
	_check_references()
	return _report


func get_report() -> ContentReport:
	return _report


## Loaded packs, in load order.
func get_packs() -> Array[PackDef]:
	return _packs


func get_pack(pack_id: String) -> PackDef:
	for pack: PackDef in _packs:
		if pack.id == pack_id:
			return pack
	return null


## Follows `aliases` from old IDs to the current one (returns the ID itself if not an alias).
func resolve_id(content_id: String) -> String:
	var current: String = content_id
	for i: int in MAX_ALIAS_DEPTH:
		if not _aliases.has(current):
			break
		current = _aliases[current]
	return current


func get_car(car_id: String) -> CarDef:
	return _cars.get(resolve_id(car_id))


## All cars sorted by ID; [param filter] is an optional `func(car: CarDef) -> bool`.
func list_cars(filter: Callable = Callable()) -> Array[CarDef]:
	var result: Array[CarDef] = []
	for id: String in _sorted_keys(_cars):
		var car: CarDef = _cars[id]
		if not filter.is_valid() or filter.call(car):
			result.append(car)
	return result


func get_part(part_id: String) -> PartDef:
	return _parts.get(resolve_id(part_id))


## Parts that can go in [param slot] of [param car_id]: the car's own parts (in
## `car.json` order) followed by compatible universal parts (sorted by ID).
func list_parts_for(car_id: String, slot: String) -> Array[PartDef]:
	var result: Array[PartDef] = []
	var car: CarDef = get_car(car_id)
	if car == null:
		return result
	for entry: CarDef.PartEntry in car.get_part_entries(slot):
		var own: PartDef = _parts.get(car.part_id(entry))
		if own != null:
			result.append(own)
	for id: String in _sorted_keys(_parts):
		var part: PartDef = _parts[id]
		if part.fits_car(car, slot, resolve_id):
			result.append(part)
	return result


func get_wheel(wheel_id: String) -> WheelDef:
	return _wheels.get(resolve_id(wheel_id))


func list_wheels(filter: Callable = Callable()) -> Array[WheelDef]:
	var result: Array[WheelDef] = []
	for id: String in _sorted_keys(_wheels):
		var wheel: WheelDef = _wheels[id]
		if not filter.is_valid() or filter.call(wheel):
			result.append(wheel)
	return result


func get_vinyl(vinyl_id: String) -> VinylDef:
	return _vinyls.get(resolve_id(vinyl_id))


## Vinyls of [param category] (all when empty), sorted by ID.
func list_vinyls(category: String = "") -> Array[VinylDef]:
	var result: Array[VinylDef] = []
	for id: String in _sorted_keys(_vinyls):
		var vinyl: VinylDef = _vinyls[id]
		if category.is_empty() or vinyl.category == category:
			result.append(vinyl)
	return result


func list_vinyl_categories() -> PackedStringArray:
	var categories: PackedStringArray = []
	for vinyl: VinylDef in list_vinyls():
		if not categories.has(vinyl.category):
			categories.append(vinyl.category)
	categories.sort()
	return categories


func get_paint(paint_id: String) -> PaintCatalog.Preset:
	return _paints.get(resolve_id(paint_id))


## All paint presets of all packs.
func get_paint_catalog() -> PaintCatalog:
	return _paint_catalog


func get_track(track_id: String) -> TrackDef:
	return _tracks.get(resolve_id(track_id))


func list_tracks() -> Array[TrackDef]:
	var result: Array[TrackDef] = []
	for id: String in _sorted_keys(_tracks):
		result.append(_tracks[id])
	return result


func get_sound(sound_id: String) -> SoundProfileDef:
	return _sounds.get(resolve_id(sound_id))


## Upgrade table of the highest-priority pack that has one (null if none).
func get_upgrades() -> UpgradeTable:
	return _upgrades


func get_economy() -> EconomyDef:
	return _economy


## Number of definitions of each kind (for logs and the self-check).
func get_counts() -> Dictionary:
	return {
		"packs": _packs.size(),
		"cars": _cars.size(),
		"parts": _parts.size(),
		"wheels": _wheels.size(),
		"vinyls": _vinyls.size(),
		"paints": _paints.size(),
		"tracks": _tracks.size(),
		"sounds": _sounds.size(),
	}


func _clear() -> void:
	_report = ContentReport.new()
	_packs.clear()
	for table: Dictionary in [
		_aliases,
		_alias_priority,
		_cars,
		_parts,
		_wheels,
		_vinyls,
		_paints,
		_tracks,
		_sounds,
		_owners
	]:
		table.clear()
	_paint_catalog = PaintCatalog.new()
	_paint_catalog.finishes = Conventions.paint_finishes()
	_upgrades = null
	_economy = null
	_upgrades_priority = -2147483648
	_economy_priority = -2147483648


# --- Discovery -------------------------------------------------------------------


func _discover(options: ContentScanOptions) -> Array[PackDef]:
	var by_id: Dictionary = {}
	var found: Array[PackDef] = []
	for dir: String in options.builtin_dirs:
		for pack_dir: String in _pack_dirs_in(dir):
			_add_found(_read_pack(pack_dir, PackDef.Source.BUILTIN), by_id, found)
	for pack_dir: String in _pack_dirs_in(options.mods_dir):
		var pack: PackDef = _read_pack(pack_dir, PackDef.Source.MOD)
		if pack != null and options.enabled_mods.has(pack.id):
			_add_found(pack, by_id, found)
	for dir: String in options.extra_dirs:
		for pack_dir: String in _extra_pack_dirs(dir):
			_add_found(_read_pack(pack_dir, PackDef.Source.EXTRA), by_id, found)
	return found


func _add_found(pack: PackDef, by_id: Dictionary, found: Array[PackDef]) -> void:
	if pack == null:
		return
	if not by_id.has(pack.id):
		by_id[pack.id] = pack
		found.append(pack)
		return
	var previous: PackDef = by_id[pack.id]
	var file: String = pack.root_dir.path_join(PackDef.FILE_NAME)
	if pack.source == PackDef.Source.EXTRA:
		# --content-dir is how the Studio edits a pack: its copy wins.
		_report.add_warning(
			file, "id", "pacote '%s' substitui o de %s" % [pack.id, previous.root_dir]
		)
		found[found.find(previous)] = pack
		by_id[pack.id] = pack
		return
	_report.add_error(
		file, "id", "pacote '%s' já carregado de %s; ignorado" % [pack.id, previous.root_dir]
	)


func _read_pack(pack_dir: String, source: PackDef.Source) -> PackDef:
	var file: String = pack_dir.path_join(PackDef.FILE_NAME)
	var ctx: LoadContext = LoadContext.new(_report, file)
	var data: Dictionary = _read_json(file, ctx)
	if data.is_empty():
		return null
	var pack: PackDef = PackDef.from_dict(data, ctx)
	if pack == null:
		return null
	pack.root_dir = pack_dir
	pack.source = source
	if pack.id != pack_dir.get_file():
		ctx.warning("id", "o nome da pasta ('%s') difere do ID do pacote" % pack_dir.get_file())
	return pack


## Subfolders of [param dir] that contain `pack.json`.
func _pack_dirs_in(dir: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for sub: String in _list_dirs(dir):
		var pack_dir: String = dir.path_join(sub)
		if FileAccess.file_exists(pack_dir.path_join(PackDef.FILE_NAME)):
			result.append(pack_dir)
	return result


func _extra_pack_dirs(dir: String) -> PackedStringArray:
	if FileAccess.file_exists(dir.path_join(PackDef.FILE_NAME)):
		return PackedStringArray([dir])
	if DirAccess.dir_exists_absolute(dir.path_join(PACKS_SUBDIR)):
		return _pack_dirs_in(dir.path_join(PACKS_SUBDIR))
	if not DirAccess.dir_exists_absolute(dir):
		_report.add_error(dir, "", "pasta de conteúdo não encontrada")
		return PackedStringArray()
	return _pack_dirs_in(dir)


## Dependencies first; among packs ready at the same time, lower priority first
## (so higher priority loads later), then by ID.
func _order_by_dependencies(found: Array[PackDef]) -> Array[PackDef]:
	var available: Dictionary = {}
	for pack: PackDef in found:
		available[pack.id] = pack
	var ordered: Array[PackDef] = []
	var loaded: Dictionary = {}
	var pending: Array[PackDef] = found.duplicate()
	while not pending.is_empty():
		var ready: Array[PackDef] = []
		for pack: PackDef in pending:
			if _all_in(pack.depends, loaded):
				ready.append(pack)
		if ready.is_empty():
			break
		ready.sort_custom(_pack_load_before)
		var next: PackDef = ready[0]
		ordered.append(next)
		loaded[next.id] = true
		pending.erase(next)
	for pack: PackDef in pending:
		var missing: PackedStringArray = []
		for dep: String in pack.depends:
			if not loaded.has(dep):
				missing.append(dep)
		var reason: String = "dependência circular"
		if not _all_in(missing, available):
			reason = "dependência não encontrada"
		_report.add_error(
			pack.root_dir.path_join(PackDef.FILE_NAME),
			"depends",
			"%s (%s); pacote ignorado" % [reason, ", ".join(missing)]
		)
	return ordered


static func _all_in(items: PackedStringArray, table: Dictionary) -> bool:
	for item: String in items:
		if not table.has(item):
			return false
	return true


static func _pack_load_before(a: PackDef, b: PackDef) -> bool:
	if a.priority != b.priority:
		return a.priority < b.priority
	return a.id < b.id


# --- Loading ---------------------------------------------------------------------


func _load_pack(pack: PackDef) -> void:
	for old_id: String in pack.aliases:
		_register_alias(old_id, pack.aliases[old_id], pack)
	for car_dir: String in _list_dirs(pack.root_dir.path_join(CARS_DIR)):
		_load_car(pack, pack.root_dir.path_join(CARS_DIR).path_join(car_dir))
	for file: String in _files_at_depth(
		pack.root_dir.path_join(UNIVERSAL_PARTS_DIR), 2, PartDef.FILE_NAME
	):
		var ctx: LoadContext = _context(file, pack)
		var part: PartDef = _parse(file, ctx, PartDef.from_dict)
		if part != null:
			_register(_parts, part.id, part, pack, ctx)
	for file: String in _files_at_depth(pack.root_dir.path_join(WHEELS_DIR), 1, WheelDef.FILE_NAME):
		var ctx: LoadContext = _context(file, pack)
		var wheel: WheelDef = _parse(file, ctx, WheelDef.from_dict)
		if wheel != null:
			_check_id_matches_folder(wheel.id, file, ctx)
			_register(_wheels, wheel.id, wheel, pack, ctx)
	for file: String in _files_at_depth(pack.root_dir.path_join(VINYLS_DIR), 1, VinylDef.FILE_NAME):
		_load_vinyls(pack, file)
	_load_paints(pack, pack.root_dir.path_join(PAINTS_FILE))
	for file: String in _files_at_depth(
		pack.root_dir.path_join(SOUNDS_DIR), 2, SoundProfileDef.FILE_NAME
	):
		var ctx: LoadContext = _context(file, pack)
		var sound: SoundProfileDef = _parse(file, ctx, SoundProfileDef.from_dict)
		if sound != null:
			_register(_sounds, sound.id, sound, pack, ctx)
	for file: String in _files_at_depth(pack.root_dir.path_join(TRACKS_DIR), 1, TrackDef.FILE_NAME):
		var ctx: LoadContext = _context(file, pack)
		var track: TrackDef = _parse(file, ctx, TrackDef.from_dict)
		if track != null:
			_check_id_matches_folder(track.id, file, ctx)
			_register(_tracks, track.id, track, pack, ctx)
	_load_singletons(pack)


func _load_car(pack: PackDef, car_dir: String) -> void:
	var file: String = car_dir.path_join(CarDef.FILE_NAME)
	var ctx: LoadContext = _context(file, pack)
	# A folder without car.json is simply not a car (no error).
	var data: Dictionary = _read_json(file, ctx, false)
	if data.is_empty():
		return
	var car: CarDef = CarDef.from_dict(data, ctx)
	if car == null:
		return
	_check_id_matches_folder(car.id, file, ctx)
	if not _model_exists(car.model_path):
		ctx.error("model", "modelo não encontrado: %s" % car.model_path)
		return
	var previous: CarDef = _cars.get(car.id)
	if not _register(_cars, car.id, car, pack, ctx):
		return
	if previous != null:
		_unregister_car_parts(previous)
	for entry: CarDef.PartEntry in car.parts:
		var part: PartDef = PartDef.from_car_entry(car, entry)
		_parts[part.id] = part
		_owners[part.id] = _owners[car.id]


func _load_vinyls(pack: PackDef, file: String) -> void:
	var ctx: LoadContext = _context(file, pack)
	var data: Dictionary = _read_json(file, ctx)
	if data.is_empty():
		return
	for vinyl: VinylDef in VinylDef.list_from_set(data, ctx):
		_register(_vinyls, vinyl.id, vinyl, pack, ctx)


func _load_paints(pack: PackDef, file: String) -> void:
	if not FileAccess.file_exists(file):
		return
	var ctx: LoadContext = _context(file, pack)
	var catalog: PaintCatalog = _parse(file, ctx, PaintCatalog.from_dict)
	if catalog == null:
		return
	for preset: PaintCatalog.Preset in catalog.presets:
		var previous: PaintCatalog.Preset = _paints.get(preset.id)
		if _register(_paints, preset.id, preset, pack, ctx):
			if previous != null:
				_paint_catalog.presets.erase(previous)
			_paint_catalog.presets.append(preset)


func _load_singletons(pack: PackDef) -> void:
	var upgrades_file: String = pack.root_dir.path_join(UPGRADES_FILE)
	if FileAccess.file_exists(upgrades_file):
		var ctx: LoadContext = _context(upgrades_file, pack)
		var table: UpgradeTable = _parse(upgrades_file, ctx, UpgradeTable.from_dict)
		if table != null and pack.priority >= _upgrades_priority:
			_upgrades = table
			_upgrades_priority = pack.priority
	var economy_file: String = pack.root_dir.path_join(ECONOMY_FILE)
	if FileAccess.file_exists(economy_file):
		var ctx: LoadContext = _context(economy_file, pack)
		var economy: EconomyDef = _parse(economy_file, ctx, EconomyDef.from_dict)
		if economy != null and pack.priority >= _economy_priority:
			_economy = economy
			_economy_priority = pack.priority


## Registers [param def] under [param id] unless a pack with higher priority
## already did. Returns true when registered.
func _register(
	table: Dictionary, id: String, def: RefCounted, pack: PackDef, ctx: LoadContext
) -> bool:
	if _owners.has(id):
		var owner: Array = _owners[id]
		var owner_priority: int = owner[0]
		var owner_pack: String = owner[1]
		if owner_pack == pack.id:
			ctx.error("id", "ID repetido no mesmo pacote: %s" % id)
			return false
		if pack.priority < owner_priority:
			return false
		if pack.priority == owner_priority:
			ctx.warning(
				"id",
				(
					"ID %s já definido pelo pacote '%s' com a mesma prioridade; mantido o primeiro"
					% [id, owner_pack]
				)
			)
			return false
	table[id] = def
	_owners[id] = [pack.priority, pack.id]
	return true


func _register_alias(old_id: String, new_id: String, pack: PackDef) -> void:
	if int(_alias_priority.get(old_id, -2147483648)) > pack.priority:
		return
	_aliases[old_id] = new_id
	_alias_priority[old_id] = pack.priority


func _unregister_car_parts(car: CarDef) -> void:
	for entry: CarDef.PartEntry in car.parts:
		var part_id: String = car.part_id(entry)
		_parts.erase(part_id)
		_owners.erase(part_id)


func _check_references() -> void:
	for old_id: String in _sorted_keys(_aliases):
		if _owners.has(old_id):
			_report.add_warning(
				"", "aliases", "'%s' é alias e também um ID existente; o ID existente vale" % old_id
			)
			_aliases.erase(old_id)
	for car: CarDef in list_cars():
		if not car.sound_id.is_empty() and get_sound(car.sound_id) == null:
			_report.add_warning(car.id, "sound", "perfil de som não encontrado: %s" % car.sound_id)
	for part: PartDef in _parts.values():
		for car_id: String in part.compatible_cars + part.exclude:
			if part.is_universal() and get_car(car_id) == null:
				_report.add_warning(part.id, "compatible", "carro não encontrado: %s" % car_id)


func _check_id_matches_folder(content_id: String, file: String, ctx: LoadContext) -> void:
	var parsed: ContentId = ContentId.parse(content_id)
	var folder: String = file.get_base_dir().get_file()
	if parsed != null and parsed.path.get_file() != folder:
		ctx.warning("id", "o ID ('%s') não bate com o nome da pasta ('%s')" % [content_id, folder])


# --- Files -----------------------------------------------------------------------


## Context for a file of [param pack]: it may define its own IDs and its dependencies'.
func _context(file: String, pack: PackDef) -> LoadContext:
	var ctx: LoadContext = LoadContext.new(_report, file, pack.id)
	ctx.allowed_packs = pack.depends
	return ctx


## Reads [param file] and calls `parser(data, ctx)`; null when unreadable or invalid.
func _parse(file: String, ctx: LoadContext, parser: Callable) -> Variant:
	var data: Dictionary = _read_json(file, ctx)
	if data.is_empty():
		return null
	return parser.call(data, ctx)


## Reads a JSON object. A missing file is an error only when [param required].
static func _read_json(file: String, ctx: LoadContext, required: bool = true) -> Dictionary:
	# One open() instead of file_exists() + read: scans touch hundreds of files.
	var handle: FileAccess = FileAccess.open(file, FileAccess.READ)
	if handle == null:
		if required:
			ctx.error("", "arquivo não encontrado")
		return {}
	var json: JSON = JSON.new()
	if json.parse(handle.get_as_text()) != OK:
		ctx.error(
			"", "JSON inválido na linha %d: %s" % [json.get_error_line(), json.get_error_message()]
		)
		return {}
	if not json.data is Dictionary:
		ctx.error("", "o arquivo deve conter um objeto JSON")
		return {}
	return json.data


## Files named [param file_name] exactly [param depth] folders below [param dir]
## (depth 1: `dir/<a>/file`, depth 2: `dir/<a>/<b>/file`).
static func _files_at_depth(dir: String, depth: int, file_name: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var level: PackedStringArray = [dir]
	for i: int in depth:
		var next_level: PackedStringArray = []
		for current: String in level:
			for sub: String in _list_dirs(current):
				next_level.append(current.path_join(sub))
		level = next_level
	for folder: String in level:
		var file: String = folder.path_join(file_name)
		if FileAccess.file_exists(file):
			result.append(file)
	return result


## Sorted subfolder names; works with `res://` inside exported `.pck` files too.
static func _list_dirs(dir: String) -> PackedStringArray:
	if dir.is_empty() or not DirAccess.dir_exists_absolute(dir):
		return PackedStringArray()
	var dirs: PackedStringArray = DirAccess.get_directories_at(dir)
	dirs.sort()
	return dirs


static func _model_exists(path: String) -> bool:
	if path.is_empty():
		return false
	if path.begins_with("res://") and ResourceLoader.exists(path):
		return true
	return FileAccess.file_exists(path)


static func _sorted_keys(table: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = []
	for key: Variant in table.keys():
		keys.append(str(key))
	keys.sort()
	return keys
