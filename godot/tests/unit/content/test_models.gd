extends GdUnitTestSuite
## ModelLoader (imported and external `.glb`) and ConventionScanner.

const FIXTURE_MODEL: String = "res://tests/fixtures/packs/fixture/cars/cunha/model.glb"
const FIXTURE_CAR_JSON: String = "res://tests/fixtures/packs/fixture/cars/cunha/car.json"
const PROTOTYPE_MODEL: String = "res://content/packs/base/cars/prototipo/model.glb"
const PROTOTYPE_CAR_JSON: String = "res://content/packs/base/cars/prototipo/car.json"
const FIXTURE_PARTS: Array = [
	"body-stock", "bumper_front-kit01", "bumper_front-stock", "hood-stock", "spoiler-stock"
]
const FIXTURE_SOCKETS: Array = [
	"spoiler", "exhaust_L", "exhaust_R", "lip_front", "neon", "light_head_L", "light_head_R"
]


func before_test() -> void:
	ModelLoader.clear_cache()


func after_test() -> void:
	ModelLoader.clear_cache()
	clean_temp_dir()


func test_load_imported_model() -> void:
	assert_bool(ModelLoader.is_imported(FIXTURE_MODEL)).is_true()
	var model: Node3D = auto_free(ModelLoader.load_model(FIXTURE_MODEL))
	assert_object(model).is_not_null()
	assert_object(model.get_node_or_null("body-stock")).is_not_null()
	assert_bool(ModelLoader.is_cached(FIXTURE_MODEL)).is_true()
	var second: Node3D = auto_free(ModelLoader.load_model(FIXTURE_MODEL))
	assert_object(second).is_not_same(model)


func test_load_external_model_like_a_mod() -> void:
	# Copy the fixture to user:// (where mods live) and load it from there.
	var mod_model: String = create_temp_dir("mod_model").path_join("model.glb")
	var copy_error: Error = DirAccess.copy_absolute(
		ProjectSettings.globalize_path(FIXTURE_MODEL), ProjectSettings.globalize_path(mod_model)
	)
	assert_int(copy_error).is_equal(OK)
	assert_bool(ModelLoader.is_imported(mod_model)).is_false()
	var model: Node3D = auto_free(ModelLoader.load_model(mod_model))
	assert_object(model).is_not_null()
	_assert_fixture_scan(ConventionScanner.scan(model))


func test_load_by_absolute_path() -> void:
	var absolute: String = ProjectSettings.globalize_path(FIXTURE_MODEL)
	assert_bool(ModelLoader.is_imported(absolute)).is_false()
	var model: Node3D = auto_free(ModelLoader.load_model(absolute))
	assert_object(model).is_not_null()
	var body: Node = model.get_node("body-stock")
	assert_dict(body.get_meta("extras")).contains_key_value("ss_slot", "body")


func test_scan_fixture_finds_exactly_the_conventions() -> void:
	var model: Node3D = auto_free(ModelLoader.load_model(FIXTURE_MODEL))
	_assert_fixture_scan(ConventionScanner.scan(model))


func test_scan_matches_car_json() -> void:
	for pair: Array in [[FIXTURE_MODEL, FIXTURE_CAR_JSON], [PROTOTYPE_MODEL, PROTOTYPE_CAR_JSON]]:
		var ctx: LoadContext = LoadContext.new(null, pair[1])
		var car: CarDef = CarDef.from_dict(
			JSON.parse_string(FileAccess.get_file_as_string(pair[1])), ctx
		)
		assert_object(car).override_failure_message(ctx.report.to_text()).is_not_null()
		var model: Node3D = auto_free(ModelLoader.load_model(pair[0]))
		var scan: ConventionScanner.ScanResult = ConventionScanner.scan(model)
		var expected_parts: PackedStringArray = []
		for entry: CarDef.PartEntry in car.parts:
			expected_parts.append(entry.node_name())
		expected_parts.sort()
		assert_array(Array(scan.part_names())).is_equal(Array(expected_parts))
		assert_array(scan.sockets.keys()).contains_exactly_in_any_order(car.sockets.keys())
		for position: String in car.wheels.anchors:
			var anchor: Node3D = scan.wheel_anchors[position]
			var expected: Vector3 = car.wheels.anchors[position]
			assert_float(anchor.position.distance_to(expected)).is_less(0.01)
		assert_int(scan.total_triangles).is_less(Conventions.budget("car_total_tris"))


func test_prototype_metadata_gives_socket_params() -> void:
	var model: Node3D = auto_free(ModelLoader.load_model(PROTOTYPE_MODEL))
	var scan: ConventionScanner.ScanResult = ConventionScanner.scan(model)
	assert_array(scan.issues).is_empty()
	assert_float(scan.socket_params["spoiler"]["width_m"]).is_equal_approx(1.3, 0.001)
	assert_int(scan.sockets.size()).is_equal(Conventions.sockets().size())
	assert_bool(scan.has_part("hood", "kit01")).is_true()


func test_classify_name() -> void:
	var cases: Array = [
		["bumper_front-kit01", ConventionScanner.Role.PART, "bumper_front", "kit01"],
		["body-wide01", ConventionScanner.Role.PART, "body", "wide01"],
		["socket-spoiler", ConventionScanner.Role.SOCKET, "spoiler", ""],
		["wheel-RR", ConventionScanner.Role.WHEEL, "RR", ""],
		["rim-stock", ConventionScanner.Role.RIM, "", "stock"],
		["collision-1", ConventionScanner.Role.COLLISION, "", "1"],
		["glass-stock", ConventionScanner.Role.FIXED, "glass", "stock"],
		["socket-asa", ConventionScanner.Role.UNKNOWN, "", ""],
		["wheel-XX", ConventionScanner.Role.UNKNOWN, "", ""],
		["porta-esquerda", ConventionScanner.Role.UNKNOWN, "", ""],
		["body", ConventionScanner.Role.UNKNOWN, "", ""],
		["hood-", ConventionScanner.Role.UNKNOWN, "", ""],
	]
	for case: Array in cases:
		var info: ConventionScanner.Classification = ConventionScanner.classify_name(case[0])
		var message: String = "%s -> %s" % [case[0], info.problem]
		assert_int(info.role).override_failure_message(message).is_equal(case[1])
		if info.role != ConventionScanner.Role.UNKNOWN:
			assert_str(info.slot).override_failure_message(message).is_equal(case[2])
			assert_str(info.variant).override_failure_message(message).is_equal(case[3])
		else:
			assert_str(info.problem).override_failure_message(message).is_not_empty()


func test_metadata_wins_over_name() -> void:
	var node: Node3D = auto_free(Node3D.new())
	node.name = "Cube"
	node.set_meta("extras", {"ss_role": "part", "ss_slot": "hood", "ss_variant": "kit09"})
	var info: ConventionScanner.Classification = ConventionScanner.classify(node)
	assert_int(info.role).is_equal(ConventionScanner.Role.PART)
	assert_str(info.slot).is_equal("hood")
	assert_str(info.variant).is_equal("kit09")
	assert_bool(info.from_metadata).is_true()
	# Missing metadata fields come from the name.
	var socket: Node3D = auto_free(Node3D.new())
	socket.name = "socket-neon"
	socket.set_meta("extras", {"ss_role": "socket", "length_m": 3.0})
	assert_str(ConventionScanner.classify(socket).slot).is_equal("neon")


func test_scan_reports_problems() -> void:
	var root: Node3D = auto_free(Node3D.new())
	var good: MeshInstance3D = _mesh("hood-stock", "paint_body")
	var wrong_material: MeshInstance3D = _mesh("bumper_front-stock", "Material.001")
	var stray: MeshInstance3D = _mesh("Cube", "paint_body")
	var bad_suffix: Node3D = Node3D.new()
	bad_suffix.name = "spoiler-col"
	for node: Node in [good, wrong_material, stray, bad_suffix]:
		root.add_child(node)
	var scan: ConventionScanner.ScanResult = ConventionScanner.scan(root)
	assert_int(scan.parts.size()).is_equal(3)
	# 3 boxes of 12 triangles: the stray "Cube" counts too (it is reported, not ignored).
	assert_int(scan.total_triangles).is_equal(36)
	assert_int(scan.triangles["hood-stock"]).is_equal(12)
	assert_array(scan.issues).has_size(3)
	assert_str(" ".join(scan.issues)).contains("Material.001")
	assert_str(" ".join(scan.issues)).contains("Cube")
	assert_str(" ".join(scan.issues)).contains("sufixo")


func _assert_fixture_scan(scan: ConventionScanner.ScanResult) -> void:
	assert_array(scan.issues).is_empty()
	assert_array(Array(scan.part_names())).is_equal(FIXTURE_PARTS)
	assert_array(scan.sockets.keys()).contains_exactly_in_any_order(FIXTURE_SOCKETS)
	assert_array(scan.wheel_anchors.keys()).contains_exactly_in_any_order(["FL", "FR", "RL", "RR"])
	assert_object(scan.rim).is_not_null()
	assert_str(String(scan.rim.name)).is_equal("rim-stock")
	assert_int(scan.collisions.size()).is_equal(1)
	assert_array(scan.fixed.keys()).contains_exactly(["glass-stock"])
	assert_array(scan.materials.keys()).contains_exactly_in_any_order(
		[
			"paint_body",
			"trim_black",
			"glass",
			"light_head",
			"light_tail",
			"rim",
			"rim_accent",
			"metal_dark"
		]
	)
	assert_int(scan.total_triangles).is_greater(100)
	assert_int(scan.triangles["body-stock"]).is_greater(0)


func _mesh(node_name: String, material_name: String) -> MeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = material_name
	box.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = box
	return instance
