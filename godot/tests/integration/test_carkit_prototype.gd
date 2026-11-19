extends GdUnitTestSuite
## Etapa 05: the prototype exported by the Blender add-on (tools/blender/make_prototipo_v2.py)
## enters the game with no manual fixes. Its carkit_manifest.json must match what the
## ConventionScanner finds in model.glb and what car.json says, and CarAssembler must
## build it without a single warning.

const CAR_ID: String = "car:base/prototipo"
const CAR_DIR: String = "res://content/packs/base/cars/prototipo"
const POSITION_TOLERANCE: float = 0.001

var _manifest: Dictionary = {}
var _scan: ConventionScanner.ScanResult = null


func before() -> void:
	var text: String = FileAccess.get_file_as_string(CAR_DIR.path_join("carkit_manifest.json"))
	_manifest = JSON.parse_string(text)
	ModelLoader.clear_cache()


func before_test() -> void:
	var model: Node3D = auto_free(ModelLoader.load_model(CAR_DIR.path_join(_manifest["model"])))
	_scan = ConventionScanner.scan(model)


func after() -> void:
	ModelLoader.clear_cache()


func test_manifest_header() -> void:
	assert_str(_manifest["schema"]).is_equal("carkit_manifest")
	assert_str(_manifest["kind"]).is_equal("car")
	assert_str(_manifest["slug"]).is_equal("prototipo")
	assert_array(_scan.issues).is_empty()


func test_parts_match_the_scanner() -> void:
	var expected: Array = []
	for part: Dictionary in _manifest["parts"]:
		expected.append("%s%s%s" % [part["slot"], Conventions.name_separator(), part["variant"]])
	expected.sort()
	assert_array(Array(_scan.part_names())).is_equal(expected)


func test_sockets_match_the_scanner() -> void:
	var sockets: Dictionary = _manifest["sockets"]
	assert_array(_scan.sockets.keys()).contains_exactly_in_any_order(sockets.keys())
	for socket: String in sockets:
		var entry: Dictionary = sockets[socket]
		var node: Node3D = _scan.sockets[socket]
		(
			assert_float(node.position.distance_to(_vec(entry["position"])))
			. override_failure_message(socket)
			. is_less(POSITION_TOLERANCE)
		)
		for key: String in entry:
			if key != "position":
				assert_float(_scan.socket_params[socket][key]).is_equal_approx(entry[key], 0.0001)


func test_wheels_rim_and_fixed_pieces() -> void:
	var wheels: Dictionary = _manifest["wheels"]
	assert_array(_scan.wheel_anchors.keys()).contains_exactly_in_any_order(
		Array(Conventions.wheel_positions())
	)
	for position: String in wheels:
		var anchor: Node3D = _scan.wheel_anchors[position]
		var expected: Vector3 = _vec(wheels[position]["position"])
		assert_float(anchor.position.distance_to(expected)).is_less(POSITION_TOLERANCE)
		assert_float(expected.y).is_equal_approx(wheels[position]["radius_m"], 0.015)
	assert_object(_scan.rim).is_not_null()
	assert_str(String(_scan.rim.name)).is_equal(_manifest["rim"])
	assert_array(_scan.fixed.keys()).contains_exactly_in_any_order(_manifest["fixed"])


func test_materials_and_triangles() -> void:
	assert_array(_scan.materials.keys()).contains_exactly_in_any_order(_manifest["materials"])
	var triangles: Dictionary = _manifest["triangles"]
	assert_int(_scan.total_triangles).is_equal(int(triangles["total"]))
	for owner: String in triangles["by_object"]:
		assert_int(int(_scan.triangles.get(owner, -1))).override_failure_message(owner).is_equal(
			int(triangles["by_object"][owner])
		)
	assert_int(_scan.total_triangles).is_less(Conventions.budget("car_total_tris"))


func test_car_json_comes_from_the_manifest() -> void:
	var car: CarDef = ContentDB.get_car(CAR_ID)
	assert_object(car).is_not_null()
	for position: String in _manifest["wheels"]:
		var expected: Vector3 = _vec(_manifest["wheels"][position]["position"])
		assert_float(car.wheels.anchors[position].distance_to(expected)).is_less(0.001)
	var names: Array = []
	for entry: CarDef.PartEntry in car.parts:
		names.append(entry.node_name())
	names.sort()
	assert_array(names).is_equal(Array(_scan.part_names()))
	assert_array(car.sockets.keys()).contains_exactly_in_any_order(_manifest["sockets"].keys())
	var measured: Dictionary = _manifest["measured_mm"]
	assert_int(car.dimensions.length_mm).is_equal(int(measured["length"]))
	assert_int(car.dimensions.width_mm).is_equal(int(measured["width"]))


func test_car_assembler_builds_without_warnings() -> void:
	var visual: CarVisual = auto_free(CarAssembler.build_by_id(CAR_ID))
	assert_object(visual).is_not_null()
	assert_array(visual.issues).is_empty()
	assert_array(visual.missing).is_empty()


func _vec(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
