extends GdUnitTestSuite
## CarConfig: defaults, round trip, pure edit functions and missing content.


func test_create_default_uses_the_car() -> void:
	var car: CarDef = ContentDB.get_car("car:base/prototipo")
	var config: CarConfig = CarConfig.create_default(car, "abc123")
	assert_str(config.instance_id).is_equal("abc123")
	assert_str(config.car_id).is_equal("car:base/prototipo")
	assert_dict(config.parts).is_empty()
	assert_int(config.wheel_front.rim_in).is_equal(car.wheels.stock_rim_in)
	assert_float(config.wheel_rear.width_in).is_equal(car.wheels.stock_width_in)
	var body: PaintSpec = config.paint["paint_body"]
	assert_str(body.color).is_equal("#D4421E")
	# A copy: changing the config does not change the car definition.
	body.color = "#000000"
	assert_str((car.paint_default["paint_body"] as PaintSpec).color).is_equal("#D4421E")


func test_round_trip_through_json() -> void:
	var original: Dictionary = TestSaves.full_car(7).to_dict()
	var text: String = JSON.stringify(original)
	var ctx: LoadContext = LoadContext.new()
	var loaded: CarConfig = CarConfig.from_dict(JSON.parse_string(text), ctx)
	assert_bool(ctx.report.has_errors()).override_failure_message(ctx.report.to_text()).is_false()
	assert_dict(loaded.to_dict()).is_equal(original)
	assert_str(loaded.paint["trim_black"]).is_equal("body_color")
	assert_str(loaded.vinyls["right"]).is_equal("mirror_left")
	assert_vector((loaded.vinyls["left"] as Array)[0].pos).is_equal(Vector2(0.45, 0.55))


func test_unknown_fields_are_preserved() -> void:
	var data: Dictionary = TestSaves.full_car(1).to_dict()
	data["campo_do_futuro"] = {"x": 1}
	var loaded: CarConfig = CarConfig.from_dict(data, LoadContext.new())
	assert_dict(loaded.to_dict()["campo_do_futuro"]).is_equal({"x": 1})


func test_edit_functions_are_pure() -> void:
	var original: CarConfig = TestSaves.full_car(1)
	var before: Dictionary = original.to_dict()
	var with_part: CarConfig = original.with_part("hood", "part:base/prototipo/hood-kit01")
	var stock: CarConfig = original.with_stock_part("spoiler")
	var spec: PaintSpec = PaintSpec.new()
	spec.finish = "chameleon"
	spec.color = "#5B1E8A"
	var painted: CarConfig = original.with_paint("paint_body", spec)
	var rims: CarConfig.WheelSetting = CarConfig.WheelSetting.new()
	rims.wheel_id = "wheel:base/disco"
	rims.rim_in = 19
	var wheels: CarConfig = original.with_wheels("both", rims)
	assert_dict(original.to_dict()).is_equal(before)
	assert_str(with_part.parts["hood"]).is_equal("part:base/prototipo/hood-kit01")
	assert_bool(stock.parts.has("spoiler")).is_false()
	assert_bool(stock.part_finish.has("spoiler")).is_false()
	assert_str((painted.paint["paint_body"] as PaintSpec).finish).is_equal("chameleon")
	assert_int(wheels.wheel_front.rim_in).is_equal(19)
	assert_str(wheels.wheel_rear.wheel_id).is_equal("wheel:base/disco")
	# Changing the paint spec afterwards does not leak into the copy.
	spec.color = "#000000"
	assert_str((painted.paint["paint_body"] as PaintSpec).color).is_equal("#5B1E8A")


func test_missing_mod_content_is_kept_in_the_save() -> void:
	var config: CarConfig = TestSaves.full_car(0)
	config.wheel_rear.wheel_id = "wheel:mod_sumido/aro"
	var library: ContentLibrary = ContentDB.get_library()
	var resolution: CarConfig.Resolution = config.resolve(library)
	assert_bool(resolution.car_missing).is_false()
	assert_array(Array(resolution.missing)).contains_exactly_in_any_order(
		[TestSaves.MISSING_MOD_PART, "wheel:mod_sumido/aro", "vinyl:base/tribal/chama_01"]
	)
	# Effective version: stock spoiler, stock rear rim, no missing vinyl.
	assert_bool(resolution.config.parts.has("spoiler")).is_false()
	assert_str(resolution.config.parts["bumper_front"]).is_equal(config.parts["bumper_front"])
	assert_str(resolution.config.wheel_rear.wheel_id).is_empty()
	assert_array(resolution.config.vinyls["left"]).is_empty()
	# The config itself (what goes to the save) is untouched.
	assert_str(config.parts["spoiler"]).is_equal(TestSaves.MISSING_MOD_PART)
	assert_str(config.wheel_rear.wheel_id).is_equal("wheel:mod_sumido/aro")
	assert_int((config.vinyls["left"] as Array).size()).is_equal(1)


func test_missing_car_is_reported() -> void:
	var config: CarConfig = TestSaves.full_car(0)
	config.car_id = "car:mod_sumido/fusca"
	var resolution: CarConfig.Resolution = config.resolve(ContentDB.get_library())
	assert_bool(resolution.car_missing).is_true()
	assert_array(Array(resolution.missing)).contains(["car:mod_sumido/fusca"])
