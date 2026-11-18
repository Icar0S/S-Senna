extends GdUnitTestSuite
## Two vehicles, two cameras and two HUDs in the same scene (nothing global), and
## the F2 tuning panel / TuningStore.

var _lab: PhysicsLab = null


func before_test() -> void:
	_lab = PhysicsLab.new(get_tree(), self)
	_lab.speed_up()


func after_test() -> void:
	_lab.restore()
	_lab.free_all()
	clean_temp_dir()


func test_two_vehicles_two_cameras_two_huds() -> void:
	var car: CarDef = ContentDB.get_car("car:base/prototipo")
	var first: Vehicle = _vehicle(car, Vector3(0, 0.05, 0))
	var second: Vehicle = _vehicle(car, Vector3(40, 0.05, 0))
	var driver: PhysicsLab.ScriptedDriver = PhysicsLab.ScriptedDriver.new()
	driver.program = func(input: VehicleInput, _v: Vehicle, _t: float) -> void: input.throttle = 1.0
	first.driver = driver
	var cameras: Array[ChaseCamera] = []
	var huds: Array[PlayerHud] = []
	for vehicle: Vehicle in [first, second]:
		var camera: ChaseCamera = ChaseCamera.new()
		_lab.root.add_child(camera)
		camera.vehicle = vehicle
		cameras.append(camera)
		var hud: PlayerHud = PlayerHud.new()
		hud.vehicle = vehicle
		_lab.root.add_child(hud)
		huds.append(hud)
	await _lab.run(4.0)
	await get_tree().process_frame
	assert_float(first.get_speed_kmh()).is_greater(20.0)
	assert_float(absf(second.get_speed_kmh())).is_less(1.0)
	# Each camera stays with its own car (the moving one lags a little: smoothing).
	for i: int in 2:
		var own: Vehicle = [first, second][i]
		var other: Vehicle = [second, first][i]
		var to_own: float = cameras[i].global_position.distance_to(own.global_position)
		assert_float(to_own).is_less(14.0)
		assert_float(to_own).is_less(cameras[i].global_position.distance_to(other.global_position))
	assert_str(huds[1].get_speed_text()).is_equal("0")
	assert_str(huds[0].get_speed_text()).is_not_equal("0")
	# Camera change asked by car 1 only affects camera 1.
	first.camera_next_requested.emit()
	assert_int(cameras[0].mode).is_equal(ChaseCamera.Mode.NEAR)
	assert_int(cameras[1].mode).is_equal(ChaseCamera.Mode.FAR)


func test_tuning_panel_changes_the_car_live() -> void:
	var car: CarDef = ContentDB.get_car("car:base/prototipo")
	var vehicle: Vehicle = _vehicle(car, Vector3(0, 0.05, 0))
	var panel: TuningPanel = TuningPanel.new()
	_lab.root.add_child(panel)
	panel.vehicle = vehicle
	panel.set_car_value("tire_mu", 2.2)
	assert_float(vehicle.params.tire_mu).is_equal(2.2)
	assert_dict(panel.get_overrides()).contains_key_value("tire_mu", 2.2)
	var stability_before: float = vehicle.params.stability
	panel.set_global_value("stability", 0.1)
	assert_float(vehicle.params.stability).is_less(stability_before)
	# Overrides survive a global change.
	assert_float(vehicle.params.tire_mu).is_equal(2.2)
	panel.undo_changes()
	assert_float(vehicle.params.stability).is_equal(stability_before)


func test_tuning_store_writes_car_and_globals() -> void:
	var folder: String = create_temp_dir("tuning")
	var source: CarDef = ContentDB.get_car("car:base/prototipo")
	var copy_path: String = folder.path_join("car.json")
	DirAccess.copy_absolute(
		ProjectSettings.globalize_path(source.source_file),
		ProjectSettings.globalize_path(copy_path)
	)
	var car: CarDef = CarDef.from_dict(
		JSON.parse_string(FileAccess.get_file_as_string(copy_path)), LoadContext.new()
	)
	car.source_file = copy_path
	assert_int(TuningStore.save_car_overrides(car, {"tire_mu": 1.777777})).is_equal(OK)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(copy_path))
	assert_float(float(saved["tuning_overrides"]["tire_mu"])).is_equal_approx(1.7778, 0.00001)
	assert_str(str(saved["id"])).is_equal("car:base/prototipo")
	var ctx: LoadContext = LoadContext.new()
	assert_object(CarDef.from_dict(saved, ctx)).is_not_null()
	assert_float(float(car.tuning_overrides["tire_mu"])).is_equal_approx(1.7778, 0.00001)
	assert_int(TuningStore.save_car_overrides(car, {})).is_equal(OK)
	(
		assert_bool(
			(JSON.parse_string(FileAccess.get_file_as_string(copy_path)) as Dictionary).has(
				"tuning_overrides"
			)
		)
		. is_false()
	)
	var globals_path: String = folder.path_join("handling_global.json")
	var globals: HandlingGlobals = HandlingGlobals.new()
	globals.stability = 0.25
	assert_int(TuningStore.save_globals(globals, globals_path)).is_equal(OK)
	var loaded: HandlingGlobals = HandlingGlobals.from_dict(
		JSON.parse_string(FileAccess.get_file_as_string(globals_path)), LoadContext.new()
	)
	assert_float(loaded.stability).is_equal(0.25)
	(
		assert_int(TuningStore.save_globals(globals, "res://nao/existe/handling_global.json"))
		. is_not_equal(OK)
	)
	assert_str(TuningStore.last_error).contains("não pode ser gravado")


func _vehicle(car: CarDef, position: Vector3) -> Vehicle:
	var vehicle: Vehicle = Vehicle.create(car, null, ProfileData.default_assists())
	_lab.root.add_child(vehicle)
	vehicle.global_position = position
	return vehicle
