extends GdUnitTestSuite
## SaveManager node: grouped autosave, saving on close, signals.

const SAVE_MANAGER_SCRIPT: String = "res://core/save/save_manager.gd"

var _base: String = ""
var _ops: TestSaves.FaultyFileOps = null
var _manager: Node = null


func before_test() -> void:
	_base = ProjectSettings.globalize_path(create_temp_dir("save_manager"))
	_ops = TestSaves.FaultyFileOps.new()
	_manager = auto_free((load(SAVE_MANAGER_SCRIPT) as GDScript).new())
	_manager.configure(_base, _ops)
	add_child(_manager)


func after_test() -> void:
	clean_temp_dir()


func test_20_requests_in_100_ms_make_one_write() -> void:
	var profile: ProfileData = _manager.create_profile("Autosave", false)
	var writes_before: int = _ops.writes
	var saved_ids: Array = []
	_manager.saved.connect(func(profile_id: String) -> void: saved_ids.append(profile_id))
	for i: int in 20:
		profile.money += 1
		_manager.request_save(profile.id, "teste")
		await get_tree().create_timer(0.005).timeout
	assert_int(_ops.writes - writes_before).is_equal(0)
	await get_tree().create_timer(1.5).timeout
	assert_int(_ops.writes - writes_before).is_equal(1)
	assert_array(saved_ids).is_equal([profile.id])
	assert_bool(_manager.is_dirty(profile.id)).is_false()
	var on_disk: ProfileData = _manager.get_store().load_profile(profile.id).profile
	assert_int(on_disk.money).is_equal(profile.money)


func test_closing_the_window_saves_pending_changes() -> void:
	var profile: ProfileData = _manager.create_profile("Fechar", false)
	profile.money = 4242
	_manager.mark_dirty(profile.id)
	_manager.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_bool(_manager.is_dirty(profile.id)).is_false()
	assert_int(_manager.get_store().load_profile(profile.id).profile.money).is_equal(4242)


func test_failures_and_recovery_are_signalled() -> void:
	var profile: ProfileData = _manager.create_profile("Sinais", false)
	var failures: Array = []
	_manager.save_failed.connect(
		func(profile_id: String, _message: String) -> void: failures.append(profile_id)
	)
	_ops.fail_writes_ending = ".tmp"
	assert_bool(_manager.save_profile(profile.id)).is_false()
	assert_array(failures).is_equal([profile.id])
	_ops.fail_writes_ending = ""
	profile.money = 1
	_manager.save_profile(profile.id)
	TestContent.write_text(_manager.get_store().profile_path(profile.id), "{ quebrado")
	var recovered: Array = []
	_manager.save_recovered.connect(
		func(profile_id: String, source: String) -> void: recovered.append(source)
	)
	var fresh: Node = auto_free((load(SAVE_MANAGER_SCRIPT) as GDScript).new())
	fresh.configure(_base)
	fresh.save_recovered.connect(
		func(_profile_id: String, source: String) -> void: recovered.append(source)
	)
	assert_object(fresh.load_profile(profile.id)).is_not_null()
	assert_array(recovered).is_equal(["profile.json.bak1"])


func test_mod_part_survives_load_and_save() -> void:
	var store: ProfileStore = _manager.get_store()
	store.save_profile(TestSaves.full_profile("mod", 1))
	var profile: ProfileData = _manager.load_profile("mod")
	profile.money += 1
	assert_bool(_manager.save_profile("mod")).is_true()
	var reloaded: ProfileData = store.load_profile("mod").profile
	assert_str(reloaded.cars[0].parts["spoiler"]).is_equal(TestSaves.MISSING_MOD_PART)


func test_scheduler_groups_by_window() -> void:
	var scheduler: SaveScheduler = SaveScheduler.new()
	scheduler.delay_ms = 1000
	for now: int in range(0, 100, 5):
		scheduler.request("p1", now)
	assert_array(Array(scheduler.take_due(999))).is_empty()
	assert_array(Array(scheduler.take_due(1000))).is_equal(["p1"])
	assert_bool(scheduler.has_pending()).is_false()
	scheduler.request("p1", 2000)
	scheduler.request("p2", 2100)
	assert_array(Array(scheduler.take_all())).contains_exactly_in_any_order(["p1", "p2"])
