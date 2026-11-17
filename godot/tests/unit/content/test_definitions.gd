extends GdUnitTestSuite
## `from_dict` of every content type: valid, missing field, wrong type,
## value out of range (clamped with a warning) and unknown field (warning).

const POWER: Array = ["categories", "engine", "effects_per_level", 1, "power_pct"]


func test_pack() -> void:
	var check: DefinitionCheck = _check(PackDef.from_dict, TestContent.pack_dict("teste"))
	check.missing(["name"])
	check.wrong_type(["priority"], "alta")
	var getter: Callable = func(pack: PackDef) -> Variant: return pack.priority
	check.out_of_range(["priority"], 5000, getter, 1000)


func test_car() -> void:
	var check: DefinitionCheck = _check(CarDef.from_dict, TestContent.car_dict())
	check.missing(["display_name"])
	check.wrong_type(["year"], "1999")
	var getter: Callable = func(car: CarDef) -> Variant: return car.stats.grip
	check.out_of_range(["stats", "grip"], 1.5, getter, 1.0)


func test_part() -> void:
	var check: DefinitionCheck = _check(PartDef.from_dict, TestContent.part_dict())
	check.missing(["slot"])
	check.wrong_type(["price"], "caro")
	var getter: Callable = func(part: PartDef) -> Variant: return part.scale_x_min
	check.out_of_range(["fit", "scale_x_min"], 0.2, getter, 0.5)


func test_wheel() -> void:
	var check: DefinitionCheck = _check(WheelDef.from_dict, TestContent.wheel_dict())
	check.missing(["model"])
	check.wrong_type(["spinner"], "sim")
	var getter: Callable = func(wheel: WheelDef) -> Variant: return wheel.rim_in_min
	check.out_of_range(["rim_in_min"], 5, getter, 10)


func test_vinyl() -> void:
	var check: DefinitionCheck = _check(VinylDef.from_dict, TestContent.vinyl_entry_dict())
	check.missing(["file"])
	check.wrong_type(["colors"], "dois")
	var getter: Callable = func(vinyl: VinylDef) -> Variant: return vinyl.colors
	check.out_of_range(["colors"], 7, getter, 3)


func test_paint_spec() -> void:
	var check: DefinitionCheck = _check(PaintSpec.from_dict, TestContent.paint_spec_dict())
	check.missing(["color"])
	check.wrong_type(["flake"], "muito")
	var getter: Callable = func(spec: PaintSpec) -> Variant: return spec.gloss
	check.out_of_range(["gloss"], 3.0, getter, 1.0)


func test_paint_catalog() -> void:
	var check: DefinitionCheck = _check(PaintCatalog.from_dict, TestContent.paints_dict())
	check.missing(["presets"])
	check.wrong_type(["finishes"], "solid")
	var getter: Callable = func(catalog: PaintCatalog) -> Variant:
		return catalog.presets[1].spec.flake
	check.out_of_range(["presets", 1, "flake"], 2.0, getter, 1.0)


func test_track() -> void:
	var check: DefinitionCheck = _check(TrackDef.from_dict, TestContent.track_dict())
	check.missing(["scene"])
	check.wrong_type(["layouts", 0, "default_laps"], "três")
	var getter: Callable = func(track: TrackDef) -> Variant: return track.layouts[0].default_laps
	check.out_of_range(["layouts", 0, "default_laps"], 99, getter, 50)


func test_sound_profile() -> void:
	var check: DefinitionCheck = _check(SoundProfileDef.from_dict, TestContent.sound_dict())
	check.missing(["loops"])
	check.wrong_type(["loops", 0, "rpm"], "alto")
	var getter: Callable = func(profile: SoundProfileDef) -> Variant: return profile.loops[1].rpm
	check.out_of_range(["loops", 1, "rpm"], 50000, getter, 20000)


func test_upgrades() -> void:
	var check: DefinitionCheck = _check(UpgradeTable.from_dict, TestContent.upgrades_dict())
	check.missing(["levels"])
	check.wrong_type(POWER, "x")
	var getter: Callable = func(table: UpgradeTable) -> Variant:
		return table.effects_for("engine", 1)["power_pct"]
	check.out_of_range(POWER, 500, getter, 100.0)


func test_economy() -> void:
	var check: DefinitionCheck = _check(EconomyDef.from_dict, TestContent.economy_dict())
	check.missing(["starting_money"])
	check.wrong_type(["sell_factor"], "metade")
	var getter: Callable = func(economy: EconomyDef) -> Variant: return economy.sell_factor
	check.out_of_range(["sell_factor"], 2.0, getter, 1.0)


func test_vinyl_set_skips_only_invalid_entries() -> void:
	var data: Dictionary = TestContent.vinyl_set_dict()
	(data["vinyls"] as Array).append({"id": "vinyl:test/tribal/sem_arquivo"})
	var ctx: LoadContext = LoadContext.new()
	var vinyls: Array[VinylDef] = VinylDef.list_from_set(data, ctx)
	assert_int(vinyls.size()).is_equal(2)
	assert_str(vinyls[0].category).is_equal("tribal")
	assert_int(ctx.report.error_count()).is_equal(1)


func test_car_details() -> void:
	var ctx: LoadContext = LoadContext.new(null, "res://x/cars/carro/car.json", "test")
	var car: CarDef = CarDef.from_dict(TestContent.car_dict(), ctx)
	assert_object(car).is_not_null()
	assert_str(car.model_path).is_equal("res://x/cars/carro/model.glb")
	assert_int(car.parts.size()).is_equal(4)
	assert_str(car.part_id(car.parts[2])).is_equal("part:test/carro/bumper_front-kit01")
	assert_str(car.parts[2].node_name()).is_equal("bumper_front-kit01")
	assert_vector(car.wheels.anchors["RR"]).is_equal(Vector3(-0.76, 0.31, -1.27))
	assert_str((car.paint_default["paint_body"] as PaintSpec).finish).is_equal("metallic")
	assert_bool(car.accepts_universal("spoiler")).is_true()
	assert_bool(car.accepts_universal("bumper_front")).is_false()
	assert_bool(car.accepts_universal("lip_front")).is_true()


func test_car_requires_stock_variants() -> void:
	var data: Dictionary = TestContent.car_dict()
	data["parts"] = [{"slot": "body", "variant": "stock"}, {"slot": "hood", "variant": "kit01"}]
	var ctx: LoadContext = LoadContext.new()
	assert_object(CarDef.from_dict(data, ctx)).is_null()
	assert_array(ctx.report.find("stock")).is_not_empty()


func test_car_rejects_unknown_slot_and_socket() -> void:
	var data: Dictionary = TestContent.car_dict()
	(data["parts"] as Array).append({"slot": "teto_solar", "variant": "stock"})
	(data["sockets"] as Dictionary)["socket_inventado"] = {}
	var ctx: LoadContext = LoadContext.new()
	assert_object(CarDef.from_dict(data, ctx)).is_null()
	assert_int(ctx.report.error_count()).is_equal(2)


func test_id_of_another_pack_needs_dependency() -> void:
	var data: Dictionary = TestContent.car_dict("base", "carro")
	var ctx: LoadContext = LoadContext.new(null, "car.json", "meu_mod")
	assert_object(CarDef.from_dict(data, ctx)).is_null()
	var allowed: LoadContext = LoadContext.new(null, "car.json", "meu_mod")
	allowed.allowed_packs = PackedStringArray(["base"])
	assert_object(CarDef.from_dict(data, allowed)).is_not_null()


func test_paths_cannot_leave_the_pack() -> void:
	for bad_path: String in ["../outro/model.glb", "/etc/model.glb", "C:/model.glb", "res://x.glb"]:
		var data: Dictionary = TestContent.car_dict()
		data["model"] = bad_path
		var ctx: LoadContext = LoadContext.new(null, "user://mods/x/cars/carro/car.json", "test")
		assert_object(CarDef.from_dict(data, ctx)).override_failure_message(bad_path).is_null()


func test_universal_part_rules() -> void:
	var data: Dictionary = TestContent.part_dict()
	TestContent.set_nested(data, ["rules", "requires"], ["hood_scoop", "part:test/universal/x/y"])
	TestContent.set_nested(data, ["rules", "conflicts"], ["nao_existe"])
	var ctx: LoadContext = LoadContext.new()
	assert_object(PartDef.from_dict(data, ctx)).is_null()
	assert_int(ctx.report.error_count()).is_equal(1)


func test_schema_header() -> void:
	var data: Dictionary = TestContent.wheel_dict()
	data["schema"] = "car"
	var ctx: LoadContext = LoadContext.new()
	assert_object(WheelDef.from_dict(data, ctx)).is_null()
	var newer: Dictionary = TestContent.wheel_dict()
	newer["schema_version"] = 2
	var newer_ctx: LoadContext = LoadContext.new()
	assert_object(WheelDef.from_dict(newer, newer_ctx)).is_not_null()
	assert_int(newer_ctx.report.warning_count()).is_equal(1)


func test_economy_helpers() -> void:
	var economy: EconomyDef = EconomyDef.from_dict(TestContent.economy_dict(), LoadContext.new())
	assert_int(economy.default_part_price("spoiler", "super")).is_equal(1500)
	assert_int(economy.default_part_price("spoiler", "outro")).is_equal(1000)
	assert_str(economy.pi_class(399)).is_equal("D")
	assert_str(economy.pi_class(400)).is_equal("C")
	assert_str(economy.pi_class(950)).is_equal("S")


func test_report_text() -> void:
	var ctx: LoadContext = LoadContext.new(null, "cars/x/car.json")
	ctx.warning("year", "aviso")
	ctx.error("id", "erro")
	assert_str(ctx.report.to_text()).is_equal(
		"ERRO: cars/x/car.json [id]: erro\nAVISO: cars/x/car.json [year]: aviso"
	)


func _check(parser: Callable, valid: Dictionary) -> DefinitionCheck:
	return DefinitionCheck.new(self, parser, valid)


## Runs the 5 standard cases for one type. Each method asserts and returns self.
class DefinitionCheck:
	extends RefCounted
	var _suite: GdUnitTestSuite
	var _parser: Callable
	var _valid: Dictionary

	func _init(suite: GdUnitTestSuite, parser: Callable, valid: Dictionary) -> void:
		_suite = suite
		_parser = parser
		_valid = valid
		var ctx: LoadContext = LoadContext.new()
		var result: Variant = _parser.call(_valid.duplicate(true), ctx)
		_suite.assert_that(result).override_failure_message(ctx.report.to_text()).is_not_null()
		(
			_suite
			. assert_bool(ctx.report.is_empty())
			. override_failure_message(ctx.report.to_text())
			. is_true()
		)
		_unknown_field()

	func missing(path: Array) -> DefinitionCheck:
		var data: Dictionary = _valid.duplicate(true)
		TestContent.erase_nested(data, path)
		_expect_error(data, "obrigatório", path)
		return self

	func wrong_type(path: Array, value: Variant) -> DefinitionCheck:
		var data: Dictionary = _valid.duplicate(true)
		TestContent.set_nested(data, path, value)
		_expect_error(data, "esperad", path)
		return self

	func out_of_range(
		path: Array, value: Variant, getter: Callable, expected: Variant
	) -> DefinitionCheck:
		var data: Dictionary = _valid.duplicate(true)
		TestContent.set_nested(data, path, value)
		var ctx: LoadContext = LoadContext.new()
		var result: Variant = _parser.call(data, ctx)
		var report: String = ctx.report.to_text()
		_suite.assert_that(result).override_failure_message(report).is_not_null()
		_suite.assert_int(ctx.report.error_count()).override_failure_message(report).is_equal(0)
		(
			_suite
			. assert_array(ctx.report.find("fora da faixa"))
			. override_failure_message(report)
			. has_size(1)
		)
		_suite.assert_that(getter.call(result)).is_equal(expected)
		return self

	func _unknown_field() -> void:
		var data: Dictionary = _valid.duplicate(true)
		data["campo_inventado"] = 1
		var ctx: LoadContext = LoadContext.new()
		var result: Variant = _parser.call(data, ctx)
		_suite.assert_that(result).is_not_null()
		_suite.assert_int(ctx.report.error_count()).is_equal(0)
		_suite.assert_array(ctx.report.find("campo desconhecido")).has_size(1)

	func _expect_error(data: Dictionary, text: String, path: Array) -> void:
		var ctx: LoadContext = LoadContext.new()
		var result: Variant = _parser.call(data, ctx)
		var report: String = "%s -> %s" % [path, ctx.report.to_text()]
		_suite.assert_bool(ctx.report.has_errors()).override_failure_message(report).is_true()
		_suite.assert_array(ctx.report.find(text)).override_failure_message(report).is_not_empty()
		# Single definitions are dropped; catalogs drop only the bad entry.
		if result != null and not (result is PaintCatalog):
			_suite.fail("esperado null com erro em %s" % [path])
