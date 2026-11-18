extends GdUnitTestSuite
## InputRouter (per-player actions) and PlayerDriver (keyboard steering ramp).


func after_test() -> void:
	for action: String in InputActions.ALL:
		Input.action_release(InputActions.action_name(0, action))
	InputRouter.assign(0, InputRouter.KEYBOARD)


func test_player_actions_exist() -> void:
	for action: String in InputActions.ALL:
		var name: String = InputActions.action_name(0, action)
		assert_bool(InputMap.has_action(name)).override_failure_message(name).is_true()
	assert_str(InputActions.action_name(1, "throttle")).is_equal("p2_throttle")
	assert_bool(InputRouter.has_player(0)).is_true()
	assert_array(InputRouter.get_devices(0)).contains([InputRouter.KEYBOARD])


func test_keyboard_defaults() -> void:
	var events: Array[InputEvent] = InputMap.action_get_events(
		InputActions.action_name(0, "throttle")
	)
	var keys: Array = []
	for event: InputEvent in events:
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
	assert_array(keys).contains([KEY_W])
	var joy_events: Array[InputEvent] = InputActions.default_events("throttle", 3)
	var has_trigger: bool = false
	for event: InputEvent in joy_events:
		if event is InputEventJoypadMotion:
			has_trigger = (
				(event as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT
				and event.device == 3
			)
	assert_bool(has_trigger).is_true()


func test_reading_actions_through_the_router() -> void:
	Input.action_press(InputActions.action_name(0, "throttle"), 0.6)
	Input.action_press(InputActions.action_name(0, "steer_right"), 1.0)
	assert_float(InputRouter.get_strength(0, "throttle")).is_equal_approx(0.6, 0.001)
	assert_float(InputRouter.get_axis(0, "steer_left", "steer_right")).is_equal_approx(1.0, 0.001)
	assert_bool(InputRouter.is_pressed(0, "throttle")).is_true()
	assert_bool(InputRouter.is_pressed(0, "nitro")).is_false()
	var vehicle_input: VehicleInput = VehicleInput.new()
	var driver: PlayerDriver = PlayerDriver.new(0)
	driver.drive(vehicle_input, 1.0 / 60.0, null)
	assert_float(vehicle_input.throttle).is_equal_approx(0.6, 0.001)
	assert_float(vehicle_input.steer).is_greater(0.0)
	assert_float(vehicle_input.steer).is_less(0.2)


func test_release_and_assign() -> void:
	var left: Array = []
	InputRouter.player_left.connect(
		func(player: int) -> void: left.append(player), CONNECT_ONE_SHOT
	)
	InputRouter.release(0)
	assert_bool(InputRouter.has_player(0)).is_false()
	assert_array(InputMap.action_get_events(InputActions.action_name(0, "throttle"))).is_empty()
	assert_array(left).is_equal([0])
	InputRouter.assign(0, InputRouter.KEYBOARD)
	assert_bool(InputRouter.has_player(0)).is_true()
	assert_array(InputMap.action_get_events(InputActions.action_name(0, "throttle"))).is_not_empty()


func test_keyboard_steering_ramps_in_and_returns_faster() -> void:
	var steer: float = 0.0
	var steps_in: int = 0
	while steer < 1.0:
		steer = PlayerDriver.smooth_steer(steer, 1.0, 1.0 / 60.0)
		steps_in += 1
	var steps_out: int = 0
	while steer > 0.0:
		steer = PlayerDriver.smooth_steer(steer, 0.0, 1.0 / 60.0)
		steps_out += 1
	assert_int(steps_in).is_greater(steps_out)
	assert_int(steps_in).is_between(10, 40)
	# Analog values follow quickly.
	assert_float(PlayerDriver.smooth_steer(0.0, 0.4, 1.0 / 60.0)).is_greater(0.2)
