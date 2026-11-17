extends GdUnitTestSuite
## ContentId (`tipo:pacote/caminho`) and the shared conventions.


func test_parse_valid_ids() -> void:
	var id: ContentId = ContentId.parse("car:base/mazda_rx7_fd")
	assert_str(id.type).is_equal("car")
	assert_str(id.pack).is_equal("base")
	assert_str(id.path).is_equal("mazda_rx7_fd")
	var part: ContentId = ContentId.parse("part:base/universal/spoiler/gt_wing_03")
	assert_str(part.path).is_equal("universal/spoiler/gt_wing_03")
	assert_str(str(part)).is_equal("part:base/universal/spoiler/gt_wing_03")
	assert_object(ContentId.parse("part:base/mazda_rx7_fd/bumper_front-kit01")).is_not_null()


func test_invalid_ids_have_clear_errors() -> void:
	var cases: Dictionary = {
		"": "vazio",
		"base/carro": "sem tipo",
		"carro:base/x": "tipo de ID desconhecido",
		"car:base": "sem pacote",
		"car:/x": "sem pacote",
		"car:Base/x": "nome de pacote",
		"car:base/X": "caminho",
		"car:base/x//y": "caminho",
		"car:base/x/": "caminho",
		"car:base/x y": "caminho",
	}
	for text: String in cases:
		assert_object(ContentId.parse(text)).override_failure_message(text).is_null()
		assert_str(ContentId.validation_error(text)).override_failure_message(text).contains(
			cases[text]
		)


func test_is_valid_with_type() -> void:
	assert_bool(ContentId.is_valid("wheel:base/rally_6", ContentId.TYPE_WHEEL)).is_true()
	assert_bool(ContentId.is_valid("wheel:base/rally_6", ContentId.TYPE_CAR)).is_false()
	assert_str(ContentId.make("track", "base", "centro")).is_equal("track:base/centro")


func test_conventions_lists() -> void:
	assert_bool(Conventions.is_slot("bumper_front")).is_true()
	assert_bool(Conventions.is_slot("lip_front")).is_true()
	assert_bool(Conventions.is_slot("socket")).is_false()
	assert_int(Conventions.all_slots().size()).is_equal(
		Conventions.replace_slots().size() + Conventions.attach_slots().size()
	)
	assert_bool(Conventions.is_socket("exhaust_L")).is_true()
	assert_array(Array(Conventions.wheel_positions())).contains_exactly(["FL", "FR", "RL", "RR"])
	assert_str(Conventions.name_separator()).is_equal("-")
	assert_int(Conventions.budget("car_total_tris")).is_equal(45000)


func test_material_names() -> void:
	assert_bool(Conventions.is_material_name("paint_body")).is_true()
	assert_bool(Conventions.is_material_name("tex_grade")).is_true()
	assert_bool(Conventions.is_material_name("Material.001")).is_false()


func test_forbidden_suffixes() -> void:
	assert_bool(Conventions.has_forbidden_suffix("hood-col")).is_true()
	assert_bool(Conventions.has_forbidden_suffix("wheel-FL")).is_false()
	assert_bool(Conventions.has_forbidden_suffix("spoiler-WHEEL")).is_true()


func test_scanner_roles_match_conventions() -> void:
	assert_array(Array(ConventionScanner.ROLE_NAMES)).is_equal(Array(Conventions.metadata_roles()))
	for role: String in ["socket", "wheel", "rim", "collision"]:
		assert_str(Conventions.node_prefix(role)).is_equal(role)
