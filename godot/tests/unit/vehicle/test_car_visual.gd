extends GdUnitTestSuite
## CarAssembler / CarVisual / MaterialLibrary / TireMeshBuilder (Etapa 03).

const FIXTURE_CAR: String = "car:fixture/cunha"
const PROTOTYPE: String = "car:base/prototipo"
const UNIVERSAL_SPOILER: String = "part:base/universal/spoiler/asa_simples"

var _library: ContentLibrary = null


func before() -> void:
	_library = ContentLibrary.new()
	var options: ContentScanOptions = ContentScanOptions.new()
	options.mods_dir = ""
	options.extra_dirs = PackedStringArray(["res://tests/fixtures/packs"])
	_library.scan(options)


func after_test() -> void:
	clean_temp_dir()


func test_default_fixture_has_no_warnings_and_shows_stock() -> void:
	var visual: CarVisual = _build(FIXTURE_CAR)
	assert_array(visual.issues).is_empty()
	assert_array(visual.missing).is_empty()
	var scan: ConventionScanner.ScanResult = visual.get_scan()
	for slot: String in scan.parts:
		for variant: String in scan.parts[slot]:
			var node: Node3D = scan.parts[slot][variant]
			assert_bool(node.visible).override_failure_message("%s-%s" % [slot, variant]).is_equal(
				variant == "stock"
			)
	assert_bool(scan.rim.visible).is_false()
	for collision: Node3D in scan.collisions:
		assert_bool(collision.visible).is_false()
	for position: String in ["FL", "FR", "RL", "RR"]:
		assert_object(visual.get_wheel(position).get_rim()).is_not_null()


func test_every_variant_of_every_slot() -> void:
	var visual: CarVisual = _build(FIXTURE_CAR)
	var scan: ConventionScanner.ScanResult = visual.get_scan()
	for slot: String in scan.parts:
		for variant: String in scan.parts[slot]:
			visual.set_part(slot, "part:fixture/cunha/%s-%s" % [slot, variant])
			for other: String in scan.parts[slot]:
				var shown: bool = (scan.parts[slot][other] as Node3D).visible
				assert_bool(shown).override_failure_message("%s: %s" % [slot, other]).is_equal(
					other == variant
				)
		visual.set_part(slot, "")
		assert_bool(visual.get_part_node(slot, "stock").visible).is_true()


func test_universal_part_goes_to_socket_and_hides_slot() -> void:
	var visual: CarVisual = _build(FIXTURE_CAR)
	visual.set_part("spoiler", UNIVERSAL_SPOILER)
	assert_bool(visual.get_part_node("spoiler", "stock").visible).is_false()
	var wing: Node3D = visual.get_universal_part("spoiler")
	assert_object(wing).is_not_null()
	assert_object(wing.get_parent()).is_same(visual.get_socket("spoiler"))
	# Socket 1.30 m / reference 1.40 m, inside the allowed 0.85..1.15.
	assert_float(wing.scale.x).is_equal_approx(1.3 / 1.4, 0.001)
	visual.set_part("spoiler", "")
	assert_object(visual.get_universal_part("spoiler")).is_null()
	assert_bool(visual.get_part_node("spoiler", "stock").visible).is_true()


func test_universal_scale_is_limited() -> void:
	var part: PartDef = _library.get_part(UNIVERSAL_SPOILER)
	var car: CarDef = _library.get_car(FIXTURE_CAR)
	var original: float = car.sockets["spoiler"]["width_m"]
	car.sockets["spoiler"]["width_m"] = 3.0
	var visual: CarVisual = _build(FIXTURE_CAR)
	visual.set_part("spoiler", UNIVERSAL_SPOILER)
	assert_float(visual.get_universal_part("spoiler").scale.x).is_equal_approx(
		part.scale_x_max, 0.0001
	)
	car.sockets["spoiler"]["width_m"] = original


func test_materials_by_name_and_shared_instances() -> void:
	var first: CarVisual = _build(FIXTURE_CAR)
	var second: CarVisual = _build(PROTOTYPE)
	var by_name_first: Dictionary = _materials_by_name(first)
	var by_name_second: Dictionary = _materials_by_name(second)
	assert_object(by_name_first["paint_body"]).is_same(first.materials.paints["paint_body"])
	assert_object(by_name_first["glass"]).is_same(first.materials.glass)
	assert_object(by_name_first["light_head"]).is_same(first.materials.lights["light_head"])
	assert_object(by_name_first["rubber"]).is_same(MaterialLibrary.shared("rubber"))
	# Shared materials: the very same instance in both cars.
	for shared_name: String in ["trim_black", "rubber", "metal_dark"]:
		assert_object(by_name_first[shared_name]).is_same(by_name_second[shared_name])
	# Per-car materials: different instances.
	assert_object(by_name_first["paint_body"]).is_not_same(by_name_second["paint_body"])
	assert_object(by_name_first["glass"]).is_not_same(by_name_second["glass"])


func test_every_convention_material_has_a_game_material() -> void:
	var material_set: CarMaterialSet = CarMaterialSet.new()
	for material_name: String in Conventions.materials():
		(
			assert_object(material_set.material_for(material_name))
			. override_failure_message(material_name)
			. is_not_null()
		)
	assert_object(material_set.material_for("tex_grade")).is_null()
	assert_array(Array(MaterialLibrary.SHADER_FINISH_ORDER)).is_equal(
		Array(Conventions.paint_finishes())
	)
	for zone: String in MaterialLibrary.PAINT_ZONES:
		assert_bool(Conventions.materials().has(zone)).is_true()


func test_part_finish_and_trim_in_body_color() -> void:
	var visual: CarVisual = _build(FIXTURE_CAR)
	visual.set_part_finish("hood", "carbon")
	var hood: MeshInstance3D = visual.get_part_node("hood", "stock")
	assert_object(_surface_material(hood, "paint_body")).is_same(MaterialLibrary.shared("carbon"))
	visual.set_part_finish("hood", "black")
	assert_object(_surface_material(hood, "paint_body")).is_same(
		MaterialLibrary.shared("trim_black")
	)
	visual.set_part_finish("hood", "paint")
	assert_object(_surface_material(hood, "paint_body")).is_same(
		visual.materials.paints["paint_body"]
	)
	var config: CarConfig = visual.config.copy()
	config.paint["trim_black"] = "body_color"
	visual.apply_config(config)
	var body: MeshInstance3D = visual.get_part_node("body", "stock")
	assert_object(_surface_material(body, "trim_black")).is_same(
		visual.materials.paints["paint_body"]
	)


func test_changing_paint_reuses_the_material() -> void:
	var visual: CarVisual = _build(FIXTURE_CAR)
	var material: ShaderMaterial = visual.materials.paints["paint_body"]
	for finish: String in Conventions.paint_finishes():
		var spec: PaintSpec = PaintSpec.new()
		spec.finish = finish
		spec.color = "#123456"
		visual.set_paint("paint_body", spec)
		assert_object(visual.materials.paints["paint_body"]).is_same(material)
		assert_int(material.get_shader_parameter("finish")).is_equal(
			Conventions.paint_finishes().find(finish)
		)


func test_tire_outer_diameter_is_constant() -> void:
	var heights: Array = []
	for rim_in: int in range(15, 23):
		var tire: ArrayMesh = TireMeshBuilder.build(0.632, rim_in, 8.5)
		heights.append(tire.get_aabb().size.y)
		assert_float(tire.get_aabb().size.y).is_equal_approx(0.632, 0.002)
	assert_object(TireMeshBuilder.build(0.632, 18, 8.5)).is_same(
		TireMeshBuilder.build(0.632, 18, 8.5)
	)
	# Bigger rim, lower profile: the inner radius grows.
	var small: ArrayMesh = TireMeshBuilder.build(0.632, 15, 8.5)
	var big: ArrayMesh = TireMeshBuilder.build(0.632, 22, 8.5)
	assert_float(_inner_radius(big)).is_greater(_inner_radius(small))


func test_wheel_size_offset_camber_and_sides() -> void:
	var visual: CarVisual = _build(PROTOTYPE)
	var setting: CarConfig.WheelSetting = CarConfig.WheelSetting.new()
	setting.wheel_id = "wheel:base/disco"
	setting.rim_in = 18
	setting.width_in = 9.0
	setting.offset_mm = 20.0
	setting.camber_deg = -4.0
	visual.set_wheels(setting, setting)
	var left: WheelVisual = visual.get_wheel("FL")
	var right: WheelVisual = visual.get_wheel("FR")
	var anchors: Dictionary = visual.get_wheel_anchors()
	assert_vector(left.rim_holder.scale).is_equal_approx(
		Vector3(9.0 / 8.0, 1.0, 1.0), Vector3.ONE * 0.001
	)
	assert_float(left.rim_holder.rotation.y).is_equal(0.0)
	assert_float(absf(right.rim_holder.rotation.y)).is_equal_approx(PI, 0.001)
	assert_float(left.position.x - (anchors["FL"] as Transform3D).origin.x).is_equal_approx(
		0.02, 0.0001
	)
	assert_float(right.position.x - (anchors["FR"] as Transform3D).origin.x).is_equal_approx(
		-0.02, 0.0001
	)
	# Negative camber: the top of both wheels leans toward the car.
	assert_float((left.transform.basis * Vector3.UP).x).is_less(0.0)
	assert_float((right.transform.basis * Vector3.UP).x).is_greater(0.0)
	assert_str(String(left.get_rim().name)).is_equal("disco")
	# Nothing is scaled negatively (no mirroring).
	for wheel: WheelVisual in [left, right]:
		assert_float(wheel.rim_holder.scale.x).is_greater(0.0)


func test_ride_height_moves_only_the_body() -> void:
	var visual: CarVisual = _build(PROTOTYPE)
	var wheel_before: Vector3 = visual.get_wheel("RL").position
	visual.set_ride_height(-40.0)
	assert_float(visual.get_ride_height_m()).is_equal_approx(-0.04, 0.0001)
	assert_vector(visual.get_wheel("RL").position).is_equal(wheel_before)
	assert_float(visual.config.ride_height_mm).is_equal(-40.0)


func test_lights() -> void:
	var visual: CarVisual = _build(PROTOTYPE)
	visual.set_lights(true, 1.0, true)
	assert_float(visual.materials.lights["light_head"].get_shader_parameter("on")).is_equal(1.0)
	assert_float(visual.materials.lights["light_tail"].get_shader_parameter("boost")).is_equal(1.0)
	assert_bool(visual.is_reverse_on()).is_true()
	visual.set_lights(false, 0.0, false)
	assert_float(visual.materials.lights["light_head"].get_shader_parameter("on")).is_equal(0.0)


func test_saved_config_rebuilds_the_same_car() -> void:
	var visual: CarVisual = _build(PROTOTYPE)
	visual.set_part("bumper_front", "part:base/prototipo/bumper_front-kit02")
	visual.set_part("spoiler", UNIVERSAL_SPOILER)
	visual.set_part_finish("hood", "carbon")
	var spec: PaintSpec = PaintSpec.new()
	spec.finish = "chameleon"
	spec.color = "#5B1E8A"
	spec.color2 = "#1E8A6E"
	visual.set_paint("paint_body", spec)
	var setting: CarConfig.WheelSetting = CarConfig.WheelSetting.new()
	setting.wheel_id = "wheel:base/basica_5"
	setting.rim_in = 19
	setting.width_in = 9.5
	setting.camber_deg = -3.5
	visual.set_wheels(setting, setting)
	visual.set_ride_height(-30.0)
	var before: Dictionary = _snapshot(visual)
	var store: ProfileStore = TestSaves.store(
		ProjectSettings.globalize_path(create_temp_dir("showroom"))
	)
	var profile: ProfileData = ProfileData.new()
	profile.id = "showroom"
	profile.cars.append(visual.config)
	assert_int(store.save_profile(profile)).is_equal(OK)
	var reloaded: CarConfig = store.load_profile("showroom").profile.cars[0]
	var rebuilt: CarVisual = auto_free(
		CarAssembler.build(_library.get_car(PROTOTYPE), reloaded, _library)
	)
	assert_dict(_snapshot(rebuilt)).is_equal(before)


func test_meshes_are_shared_between_cars() -> void:
	var first: CarVisual = _build(PROTOTYPE)
	var second: CarVisual = _build(PROTOTYPE)
	var body_a: MeshInstance3D = first.get_part_node("body", "stock")
	var body_b: MeshInstance3D = second.get_part_node("body", "stock")
	assert_object(body_a.mesh).is_same(body_b.mesh)
	assert_object(first.get_wheel("FL").tire.mesh).is_same(second.get_wheel("RR").tire.mesh)
	var rim_a: MeshInstance3D = _first_mesh(first.get_wheel("FL").get_rim())
	var rim_b: MeshInstance3D = _first_mesh(second.get_wheel("FR").get_rim())
	assert_object(rim_a.mesh).is_same(rim_b.mesh)


func test_aabb_and_sockets() -> void:
	var visual: CarVisual = _build(PROTOTYPE)
	var box: AABB = visual.get_aabb_car_space()
	var car: CarDef = _library.get_car(PROTOTYPE)
	assert_float(box.size.z).is_equal_approx(car.dimensions.length_mm / 1000.0, 0.05)
	assert_float(box.position.y).is_equal_approx(0.0, 0.02)
	assert_object(visual.get_socket("neon")).is_not_null()
	assert_object(visual.get_socket("nao_existe")).is_null()


func test_assembly_and_part_swap_are_fast() -> void:
	var car: CarDef = _library.get_car(PROTOTYPE)
	auto_free(CarAssembler.build(car, null, _library))
	var build_times: Array = []
	for i: int in 5:
		var started: int = Time.get_ticks_usec()
		var visual: CarVisual = CarAssembler.build(car, null, _library)
		build_times.append((Time.get_ticks_usec() - started) / 1000.0)
		visual.free()
	var visual: CarVisual = _build(PROTOTYPE)
	var swap_times: Array = []
	for variant: String in ["kit01", "kit02", "stock", "kit01", "kit02"]:
		var started: int = Time.get_ticks_usec()
		visual.set_part("bumper_front", "part:base/prototipo/bumper_front-" + variant)
		swap_times.append((Time.get_ticks_usec() - started) / 1000.0)
	build_times.sort()
	swap_times.sort()
	prints("Montagem (mediana): %.1f ms · troca de peça: %.2f ms" % [build_times[2], swap_times[2]])
	assert_float(build_times[2]).is_less(50.0)
	assert_float(swap_times[2]).is_less(5.0)


func _build(car_id: String) -> CarVisual:
	var visual: CarVisual = CarAssembler.build(_library.get_car(car_id), null, _library)
	assert_object(visual).is_not_null()
	return auto_free(visual)


## Material name in the model -> material the game assigned (first one found).
func _materials_by_name(visual: CarVisual) -> Dictionary:
	var result: Dictionary = {}
	for mesh_node: MeshInstance3D in CarVisual._meshes_under(visual):
		for surface: int in mesh_node.mesh.get_surface_count():
			var original: Material = mesh_node.mesh.surface_get_material(surface)
			if original != null and not result.has(original.resource_name):
				result[original.resource_name] = mesh_node.get_surface_override_material(surface)
	return result


func _surface_material(mesh_node: MeshInstance3D, material_name: String) -> Material:
	for surface: int in mesh_node.mesh.get_surface_count():
		if mesh_node.mesh.surface_get_material(surface).resource_name == material_name:
			return mesh_node.get_surface_override_material(surface)
	return null


func _inner_radius(mesh: ArrayMesh) -> float:
	var smallest: float = INF
	for vertex: Vector3 in mesh.get_faces():
		smallest = minf(smallest, Vector2(vertex.y, vertex.z).length())
	return smallest


func _first_mesh(root: Node) -> MeshInstance3D:
	return CarVisual._meshes_under(root)[0]


## What a player would see: parts, universal parts, materials and wheels.
func _snapshot(visual: CarVisual) -> Dictionary:
	var visible_parts: Array = []
	var scan: ConventionScanner.ScanResult = visual.get_scan()
	for slot: String in scan.parts:
		for variant: String in scan.parts[slot]:
			if (scan.parts[slot][variant] as Node3D).visible:
				visible_parts.append("%s-%s" % [slot, variant])
	visible_parts.sort()
	var paint: ShaderMaterial = visual.materials.paints["paint_body"]
	var wheels: Dictionary = {}
	for position: String in ["FL", "FR", "RL", "RR"]:
		var wheel: WheelVisual = visual.get_wheel(position)
		wheels[position] = [
			str(wheel.transform.origin.snapped(Vector3.ONE * 0.0001)),
			str(wheel.rotation.snapped(Vector3.ONE * 0.0001)),
			str(wheel.rim_holder.scale.snapped(Vector3.ONE * 0.0001)),
			String(wheel.get_rim().name),
			wheel.tire.mesh.resource_name,
		]
	var hood: MeshInstance3D = visual.get_part_node("hood", "stock")
	return {
		"parts": visible_parts,
		"universal": visual.get_universal_part("spoiler") != null,
		"finish": paint.get_shader_parameter("finish"),
		"color": str(paint.get_shader_parameter("color")),
		"color2": str(paint.get_shader_parameter("color2")),
		"hood": _surface_material(hood, "paint_body").resource_name,
		"wheels": wheels,
		"ride": snappedf(visual.get_ride_height_m(), 0.0001),
	}
