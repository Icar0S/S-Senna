extends GdUnitTestSuite
## ContentLibrary: discovery, load order, priority, aliases and queries.

const FIXTURE_PACKS: String = "res://tests/fixtures/packs"

var _root: String = ""


func before_test() -> void:
	_root = create_temp_dir("content_library")


func after_test() -> void:
	clean_temp_dir()


func test_base_pack_loads_without_problems() -> void:
	var library: ContentLibrary = ContentLibrary.new()
	var report: ContentReport = library.scan(ContentScanOptions.new())
	assert_bool(report.is_empty()).override_failure_message(report.to_text()).is_true()
	assert_object(library.get_pack("base")).is_not_null()
	var car: CarDef = library.get_car("car:base/prototipo")
	assert_object(car).is_not_null()
	assert_bool(ResourceLoader.exists(car.model_path)).is_true()
	assert_int(library.list_wheels().size()).is_equal(2)
	assert_int(library.get_paint_catalog().presets.size()).is_equal(12)
	assert_object(library.get_upgrades()).is_not_null()
	assert_int(library.get_upgrades().level_count()).is_equal(4)
	assert_object(library.get_economy()).is_not_null()
	var spoilers: Array[PartDef] = library.list_parts_for("car:base/prototipo", "spoiler")
	assert_array(_ids(spoilers)).contains_exactly(
		["part:base/prototipo/spoiler-stock", "part:base/universal/spoiler/asa_simples"]
	)


func test_fixture_pack_as_extra_dir() -> void:
	var options: ContentScanOptions = TestContent.options_for(_root)
	options.extra_dirs = PackedStringArray([FIXTURE_PACKS])
	var library: ContentLibrary = ContentLibrary.new()
	var report: ContentReport = library.scan(options)
	assert_bool(report.is_empty()).override_failure_message(report.to_text()).is_true()
	var car: CarDef = library.get_car("car:fixture/cunha_antiga")
	assert_object(car).is_not_null()
	assert_str(car.id).is_equal("car:fixture/cunha")
	assert_str(library.get_pack("fixture").source_name()).is_equal("extra")


func test_registers_everything_in_a_pack() -> void:
	var dir: String = _root.path_join("test")
	(
		TestContent
		. write_pack(
			dir,
			TestContent.pack_dict("test"),
			{
				"cars/carro/car.json": TestContent.car_dict(),
				"parts/universal/spoiler/asa/part.json": TestContent.part_dict(),
				"wheels/aro/wheel.json": TestContent.wheel_dict(),
				"vinyls/tribal/vinyls.json": TestContent.vinyl_set_dict(),
				"paints/paints.json": TestContent.paints_dict(),
				"sounds/engine/motor/sound.json": TestContent.sound_dict(),
				"tracks/pista/track.json": TestContent.track_dict(),
				"upgrades/upgrades.json": TestContent.upgrades_dict(),
				"economy.json": TestContent.economy_dict(),
			}
		)
	)
	var library: ContentLibrary = _scan()
	(
		assert_bool(library.get_report().is_empty())
		. override_failure_message(library.get_report().to_text())
		. is_true()
	)
	var counts: Dictionary = library.get_counts()
	assert_int(counts["cars"]).is_equal(1)
	# 4 car-specific parts + 1 universal.
	assert_int(counts["parts"]).is_equal(5)
	assert_int(counts["wheels"]).is_equal(1)
	assert_int(counts["vinyls"]).is_equal(2)
	assert_int(counts["paints"]).is_equal(2)
	assert_int(counts["sounds"]).is_equal(1)
	assert_int(counts["tracks"]).is_equal(1)
	assert_object(library.get_part("part:test/carro/bumper_front-kit01")).is_not_null()
	assert_str(library.get_part("part:test/carro/bumper_front-kit01").car_id).is_equal(
		"car:test/carro"
	)
	assert_array(Array(library.list_vinyl_categories())).contains_exactly(["tribal"])
	assert_int(library.list_vinyls("tribal").size()).is_equal(2)
	assert_int(library.list_vinyls("outra").size()).is_equal(0)
	assert_object(library.get_track("track:test/pista").get_layout("arrancada")).is_not_null()
	assert_str(library.get_sound("sound:test/engine/motor").extras["turbo"]).ends_with(
		"sounds/engine/motor/turbo.ogg"
	)
	var jdm: Array[CarDef] = library.list_cars(
		func(car: CarDef) -> bool: return car.category == "jdm"
	)
	assert_int(jdm.size()).is_equal(1)


func test_higher_priority_replaces_same_id() -> void:
	var base_car: Dictionary = TestContent.car_dict("base", "carro")
	TestContent.write_pack(
		_root.path_join("base"), TestContent.pack_dict("base"), {"cars/carro/car.json": base_car}
	)
	var mod_car: Dictionary = TestContent.car_dict("base", "carro")
	mod_car["display_name"] = "Carro do Mod"
	mod_car["parts"] = [{"slot": "body", "variant": "stock"}, {"slot": "hood", "variant": "stock"}]
	TestContent.write_pack(
		_root.path_join("mod_forte"),
		TestContent.pack_dict("mod_forte", 10, ["base"]),
		{"cars/carro/car.json": mod_car}
	)
	var library: ContentLibrary = _scan()
	(
		assert_bool(library.get_report().has_errors())
		. override_failure_message(library.get_report().to_text())
		. is_false()
	)
	assert_str(library.get_car("car:base/carro").display_name).is_equal("Carro do Mod")
	# The replaced car's own parts are gone; the new car's parts are registered.
	assert_object(library.get_part("part:base/carro/bumper_front-kit01")).is_null()
	assert_object(library.get_part("part:base/carro/hood-stock")).is_not_null()


func test_lower_priority_does_not_replace() -> void:
	TestContent.write_pack(
		_root.path_join("base"),
		TestContent.pack_dict("base", 5),
		{"cars/carro/car.json": TestContent.car_dict("base", "carro")}
	)
	var weak_car: Dictionary = TestContent.car_dict("base", "carro")
	weak_car["display_name"] = "Fraco"
	TestContent.write_pack(
		_root.path_join("mod_fraco"),
		TestContent.pack_dict("mod_fraco", 0, ["base"]),
		{"cars/carro/car.json": weak_car}
	)
	var library: ContentLibrary = _scan()
	assert_str(library.get_car("car:base/carro").display_name).is_equal("Carro carro")


func test_alias_resolves_old_id() -> void:
	var aliases: Dictionary = {
		"car:test/velho": "car:test/carro",
		"wheel:test/aro_antigo": "wheel:test/aro",
	}
	TestContent.write_pack(
		_root.path_join("test"),
		TestContent.pack_dict("test", 0, [], aliases),
		{
			"cars/carro/car.json": TestContent.car_dict(),
			"wheels/aro/wheel.json": TestContent.wheel_dict()
		}
	)
	var library: ContentLibrary = _scan()
	assert_str(library.resolve_id("car:test/velho")).is_equal("car:test/carro")
	assert_object(library.get_car("car:test/velho")).is_same(library.get_car("car:test/carro"))
	assert_object(library.get_wheel("wheel:test/aro_antigo")).is_not_null()
	assert_str(library.resolve_id("car:test/nao_existe")).is_equal("car:test/nao_existe")


func test_list_parts_for_specific_and_compatible_universal() -> void:
	var other_car: Dictionary = TestContent.car_dict("test", "outro")
	other_car["sockets"] = {}
	var excluded: Dictionary = TestContent.part_dict("test", "spoiler", "exclui")
	TestContent.set_nested(excluded, ["compatible", "exclude"], ["car:test/velho_nome"])
	var only_other: Dictionary = TestContent.part_dict("test", "spoiler", "so_outro")
	TestContent.set_nested(only_other, ["compatible", "cars"], ["car:test/outro"])
	var listed: Dictionary = TestContent.part_dict("test", "spoiler", "lista")
	TestContent.set_nested(listed, ["compatible", "cars"], ["car:test/carro", "car:test/outro"])
	var lip: Dictionary = TestContent.part_dict("test", "lip_front", "lamina", "lip_front")
	var bumper: Dictionary = TestContent.part_dict("test", "bumper_front", "universal", "")
	(
		TestContent
		. write_pack(
			_root.path_join("test"),
			TestContent.pack_dict("test", 0, [], {"car:test/velho_nome": "car:test/carro"}),
			{
				"cars/carro/car.json": TestContent.car_dict(),
				"cars/outro/car.json": other_car,
				"parts/universal/spoiler/asa/part.json": TestContent.part_dict(),
				"parts/universal/spoiler/exclui/part.json": excluded,
				"parts/universal/spoiler/so_outro/part.json": only_other,
				"parts/universal/spoiler/lista/part.json": listed,
				"parts/universal/lip_front/lamina/part.json": lip,
				"parts/universal/bumper_front/universal/part.json": bumper,
			}
		)
	)
	var library: ContentLibrary = _scan()
	(
		assert_bool(library.get_report().has_errors())
		. override_failure_message(library.get_report().to_text())
		. is_false()
	)
	# Own spoiler first, then universal ones (sorted); `exclui` excludes this car via an alias.
	(
		assert_array(_ids(library.list_parts_for("car:test/carro", "spoiler")))
		. contains_exactly(
			[
				"part:test/carro/spoiler-stock",
				"part:test/universal/spoiler/asa",
				"part:test/universal/spoiler/lista",
			]
		)
	)
	assert_array(_ids(library.list_parts_for("car:test/carro", "lip_front"))).contains_exactly(
		["part:test/universal/lip_front/lamina"]
	)
	# The car's bumper slot has no `accepts_universal`: only its own bumpers.
	assert_array(_ids(library.list_parts_for("car:test/carro", "bumper_front"))).contains_exactly(
		["part:test/carro/bumper_front-stock", "part:test/carro/bumper_front-kit01"]
	)
	# `outro` has no sockets: universal parts that need one are not offered.
	assert_array(_ids(library.list_parts_for("car:test/outro", "spoiler"))).contains_exactly(
		["part:test/outro/spoiler-stock"]
	)
	assert_array(_ids(library.list_parts_for("car:test/nao_existe", "spoiler"))).is_empty()


func test_dependencies_are_loaded_first() -> void:
	TestContent.write_pack(_root.path_join("a_mod"), TestContent.pack_dict("a_mod", -5, ["z_base"]))
	TestContent.write_pack(_root.path_join("z_base"), TestContent.pack_dict("z_base", 0))
	var library: ContentLibrary = _scan()
	var order: PackedStringArray = []
	for pack: PackDef in library.get_packs():
		order.append(pack.id)
	assert_array(Array(order)).is_equal(["z_base", "a_mod"])


func test_missing_dependency_and_cycle_skip_packs() -> void:
	TestContent.write_pack(_root.path_join("orfao"), TestContent.pack_dict("orfao", 0, ["sumiu"]))
	TestContent.write_pack(
		_root.path_join("ciclo_a"), TestContent.pack_dict("ciclo_a", 0, ["ciclo_b"])
	)
	TestContent.write_pack(
		_root.path_join("ciclo_b"), TestContent.pack_dict("ciclo_b", 0, ["ciclo_a"])
	)
	TestContent.write_pack(_root.path_join("ok"), TestContent.pack_dict("ok"))
	var library: ContentLibrary = _scan()
	assert_int(library.get_packs().size()).is_equal(1)
	assert_array(library.get_report().find("dependência não encontrada")).has_size(1)
	assert_array(library.get_report().find("dependência circular")).has_size(2)


func test_bad_files_do_not_stop_the_scan() -> void:
	var dir: String = _root.path_join("test")
	TestContent.write_pack(
		dir,
		TestContent.pack_dict("test"),
		{"cars/bom/car.json": TestContent.car_dict("test", "bom")}
	)
	TestContent.write_text(dir.path_join("cars/quebrado/car.json"), '{ "schema": "car", ')
	var no_model: Dictionary = TestContent.car_dict("test", "sem_modelo")
	TestContent.write_json(dir.path_join("cars/sem_modelo/car.json"), no_model)
	var library: ContentLibrary = _scan()
	assert_object(library.get_car("car:test/bom")).is_not_null()
	assert_object(library.get_car("car:test/sem_modelo")).is_null()
	assert_array(library.get_report().find("JSON inválido")).has_size(1)
	assert_array(library.get_report().find("modelo não encontrado")).has_size(1)


func test_duplicate_pack_and_folder_name() -> void:
	TestContent.write_pack(_root.path_join("um"), TestContent.pack_dict("mesmo"))
	TestContent.write_pack(_root.path_join("dois"), TestContent.pack_dict("mesmo"))
	var library: ContentLibrary = _scan()
	assert_int(library.get_packs().size()).is_equal(1)
	assert_array(library.get_report().find("já carregado")).has_size(1)
	assert_array(library.get_report().find("nome da pasta")).has_size(2)


func test_only_enabled_mods_are_loaded() -> void:
	var mods: String = _root.path_join("mods")
	TestContent.write_pack(mods.path_join("ligado"), TestContent.pack_dict("ligado"))
	TestContent.write_pack(mods.path_join("desligado"), TestContent.pack_dict("desligado"))
	var options: ContentScanOptions = TestContent.options_for(_root.path_join("nenhum"))
	options.mods_dir = mods
	options.enabled_mods = PackedStringArray(["ligado"])
	var library: ContentLibrary = ContentLibrary.new()
	library.scan(options)
	assert_object(library.get_pack("ligado")).is_not_null()
	assert_str(library.get_pack("ligado").source_name()).is_equal("mod")
	assert_object(library.get_pack("desligado")).is_null()


func test_extra_dir_replaces_builtin_pack() -> void:
	var builtin: String = _root.path_join("builtin")
	var builtin_car: Dictionary = TestContent.car_dict("test", "carro")
	TestContent.write_pack(
		builtin.path_join("test"),
		TestContent.pack_dict("test"),
		{"cars/carro/car.json": builtin_car}
	)
	var edited_car: Dictionary = TestContent.car_dict("test", "carro")
	edited_car["display_name"] = "Editado no Studio"
	var extra: String = _root.path_join("repo/content")
	TestContent.write_pack(
		extra.path_join("packs/test"),
		TestContent.pack_dict("test"),
		{"cars/carro/car.json": edited_car}
	)
	var options: ContentScanOptions = TestContent.options_for(builtin)
	options.extra_dirs = PackedStringArray([extra])
	var library: ContentLibrary = ContentLibrary.new()
	library.scan(options)
	assert_str(library.get_car("car:test/carro").display_name).is_equal("Editado no Studio")
	assert_array(library.get_report().find("substitui")).has_size(1)


func test_missing_extra_dir_is_reported() -> void:
	var options: ContentScanOptions = TestContent.options_for(_root)
	options.extra_dirs = PackedStringArray([_root.path_join("nao_existe")])
	var library: ContentLibrary = ContentLibrary.new()
	library.scan(options)
	assert_array(library.get_report().find("não encontrada")).has_size(1)


func test_options_from_cmdline() -> void:
	var options: ContentScanOptions = ContentScanOptions.from_cmdline(
		PackedStringArray(["--studio", "--content-dir=C:/repo/godot/content"])
	)
	assert_array(Array(options.extra_dirs)).is_equal(["C:/repo/godot/content"])
	assert_array(Array(options.builtin_dirs)).is_equal([ContentScanOptions.DEFAULT_BUILTIN_DIR])


func test_rescan_clears_previous_content() -> void:
	TestContent.write_pack(
		_root.path_join("test"),
		TestContent.pack_dict("test"),
		{"cars/carro/car.json": TestContent.car_dict()}
	)
	var library: ContentLibrary = _scan()
	assert_int(library.list_cars().size()).is_equal(1)
	library.scan(TestContent.options_for(_root.path_join("vazio")))
	assert_int(library.list_cars().size()).is_equal(0)
	assert_int(library.get_packs().size()).is_equal(0)


func test_content_db_autoload_uses_the_library() -> void:
	assert_object(ContentDB.get_car("car:base/prototipo")).is_not_null()
	assert_int(ContentDB.list_cars().size()).is_greater_equal(1)
	assert_int(ContentDB.list_parts_for("car:base/prototipo", "bumper_front").size()).is_equal(3)
	assert_bool(ContentDB.get_report().has_errors()).is_false()


func _scan() -> ContentLibrary:
	var library: ContentLibrary = ContentLibrary.new()
	library.scan(TestContent.options_for(_root))
	return library


func _ids(parts: Array[PartDef]) -> Array:
	var ids: Array = []
	for part: PartDef in parts:
		ids.append(part.id)
	return ids
