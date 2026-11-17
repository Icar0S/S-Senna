extends GdUnitTestSuite
## ProfileStore: round trip, recovery from backups, future versions, names,
## trash, duplicate, export/import and simulated disk failures.

var _base: String = ""


func before_test() -> void:
	# Spaces and accents in the path on purpose.
	_base = ProjectSettings.globalize_path(create_temp_dir("perfis")).path_join(
		"Pasta com Espaço Ção"
	)


func after_test() -> void:
	clean_temp_dir()


func test_round_trip_profile_with_50_cars_is_identical() -> void:
	var store: ProfileStore = TestSaves.store(_base)
	var profile: ProfileData = TestSaves.full_profile("p50", 50)
	var before: Dictionary = profile.to_dict()
	assert_int(store.save_profile(profile)).is_equal(OK)
	var loaded: ProfileStore.LoadResult = store.load_profile("p50")
	assert_bool(loaded.ok()).override_failure_message(str(loaded.problems)).is_true()
	assert_bool(loaded.recovered).is_false()
	assert_int(loaded.profile.cars.size()).is_equal(50)
	assert_dict(loaded.profile.to_dict()).is_equal(before)


func test_accents_and_emoji_in_names() -> void:
	var store: ProfileStore = TestSaves.store(_base)
	var profile: ProfileData = store.create_profile("Ícaro ação 🚗💨", true, 500)
	assert_object(profile).is_not_null()
	var loaded: ProfileData = store.load_profile(profile.id).profile
	assert_str(loaded.name).is_equal("Ícaro ação 🚗💨")
	assert_bool(loaded.sandbox).is_true()
	assert_int(loaded.money).is_equal(500)
	var names: Array = []
	for summary: ProfileStore.Summary in store.list_profiles():
		names.append(summary.name)
	assert_array(names).contains_exactly(["Ícaro ação 🚗💨"])


func test_truncated_main_file_loads_from_backup() -> void:
	var store: ProfileStore = TestSaves.store(_base)
	var profile: ProfileData = TestSaves.full_profile("p1", 2)
	store.save_profile(profile)
	profile.money = 777
	store.save_profile(profile)
	var path: String = store.profile_path("p1")
	var text: String = FileAccess.get_file_as_string(path)
	TestContent.write_text(path, text.substr(0, text.length() / 3))
	var loaded: ProfileStore.LoadResult = store.load_profile("p1")
	assert_bool(loaded.ok()).is_true()
	assert_bool(loaded.recovered).is_true()
	assert_str(loaded.source).is_equal("profile.json.bak1")
	assert_int(loaded.profile.money).is_equal(12000)
	assert_str(str(loaded.problems)).contains("JSON inválido")


func test_wrong_checksum_loads_from_backup() -> void:
	var store: ProfileStore = TestSaves.store(_base)
	var profile: ProfileData = TestSaves.full_profile("p1", 1)
	store.save_profile(profile)
	profile.money = 1
	store.save_profile(profile)
	var path: String = store.profile_path("p1")
	TestContent.write_text(
		path, FileAccess.get_file_as_string(path).replace('"money": 1,', '"money": 999999,')
	)
	var loaded: ProfileStore.LoadResult = store.load_profile("p1")
	assert_bool(loaded.recovered).is_true()
	assert_int(loaded.profile.money).is_equal(12000)
	assert_str(str(loaded.problems)).contains("checksum")


func test_no_readable_copy() -> void:
	var store: ProfileStore = TestSaves.store(_base)
	TestContent.write_text(store.profile_path("p1"), "lixo")
	var loaded: ProfileStore.LoadResult = store.load_profile("p1")
	assert_bool(loaded.ok()).is_false()
	assert_bool(store.load_profile("nao_existe").ok()).is_false()


func test_future_version_is_read_only_and_never_overwritten() -> void:
	var store: ProfileStore = TestSaves.store(_base)
	var data: Dictionary = TestSaves.full_profile("futuro", 1).to_dict()
	var envelope: Dictionary = SaveEnvelope.wrap("profile", 99, data, "2030-01-01T00:00:00Z")
	var path: String = store.profile_path("futuro")
	TestContent.write_text(path, SaveEnvelope.to_text(envelope))
	var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var loaded: ProfileStore.LoadResult = store.load_profile("futuro")
	assert_bool(loaded.ok()).is_true()
	assert_bool(loaded.read_only).is_true()
	assert_bool(loaded.profile.read_only).is_true()
	assert_int(store.save_profile(loaded.profile)).is_equal(ERR_UNAVAILABLE)
	# Even a fresh object with the same ID cannot overwrite it.
	var impostor: ProfileData = TestSaves.full_profile("futuro", 0)
	assert_int(store.save_profile(impostor)).is_equal(ERR_UNAVAILABLE)
	assert_str(store.last_error).contains("mais nova")
	assert_array(Array(FileAccess.get_file_as_bytes(path))).is_equal(Array(original_bytes))
	assert_bool(FileAccess.file_exists(path + ".bak1")).is_false()


func test_disk_full_keeps_the_previous_save() -> void:
	var ops: TestSaves.FaultyFileOps = TestSaves.FaultyFileOps.new()
	var store: ProfileStore = TestSaves.store(_base, ops)
	var profile: ProfileData = TestSaves.full_profile("p1", 1)
	assert_int(store.save_profile(profile)).is_equal(OK)
	ops.fail_writes_ending = ".tmp"
	profile.money = 5
	assert_int(store.save_profile(profile)).is_equal(ERR_FILE_CANT_WRITE)
	assert_str(store.last_error).contains("não foi possível gravar")
	var loaded: ProfileStore.LoadResult = store.load_profile("p1")
	assert_bool(loaded.recovered).is_false()
	assert_int(loaded.profile.money).is_equal(12000)


func test_delete_moves_to_trash() -> void:
	var store: ProfileStore = TestSaves.store(_base)
	var profile: ProfileData = store.create_profile("Apagar", false)
	assert_int(store.delete_profile(profile.id)).is_equal(OK)
	assert_bool(store.load_profile(profile.id).ok()).is_false()
	assert_array(store.list_profiles()).is_empty()
	var trash: PackedStringArray = DirAccess.get_directories_at(
		store.profiles_dir().path_join("_lixeira")
	)
	assert_int(trash.size()).is_equal(1)
	assert_str(trash[0]).starts_with(profile.id + "_")
	assert_int(store.delete_profile("nao_existe")).is_equal(ERR_DOES_NOT_EXIST)


func test_duplicate_profile() -> void:
	var store: ProfileStore = TestSaves.store(_base)
	store.save_profile(TestSaves.full_profile("orig", 3))
	var copy: ProfileData = store.duplicate_profile("orig")
	assert_object(copy).is_not_null()
	assert_str(copy.id).is_not_equal("orig")
	assert_str(copy.name).is_equal("Jogadora Ção 🏁 (cópia)")
	assert_int(store.load_profile(copy.id).profile.cars.size()).is_equal(3)
	assert_int(store.list_profiles().size()).is_equal(2)


func test_export_and_import_zip() -> void:
	var store: ProfileStore = TestSaves.store(_base)
	store.save_profile(TestSaves.full_profile("exportado", 2))
	var zip_path: String = _base.path_join("meu save.zip")
	assert_int(store.export_profile("exportado", zip_path)).is_equal(OK)
	# Importing into the same folder: the ID is taken, so a new one is used.
	var imported: ProfileStore.LoadResult = store.import_profile(zip_path)
	assert_bool(imported.ok()).override_failure_message(str(imported.problems)).is_true()
	assert_str(imported.profile.id).is_not_equal("exportado")
	assert_int(imported.profile.cars.size()).is_equal(2)
	# Importing into another PC (empty folder) keeps the ID.
	var other: ProfileStore = TestSaves.store(_base.path_join("outro_pc"))
	var moved: ProfileStore.LoadResult = other.import_profile(zip_path)
	assert_str(moved.profile.id).is_equal("exportado")
	assert_bool(other.import_profile(_base.path_join("nao_existe.zip")).ok()).is_false()


func test_create_profile_ids_are_unique() -> void:
	var store: ProfileStore = TestSaves.store(_base)
	var ids: Dictionary = {}
	for i: int in 10:
		ids[store.create_profile("P%d" % i, false).id] = true
	assert_int(ids.size()).is_equal(10)
	for profile_id: String in ids:
		assert_bool(ProfileData.is_valid_id(profile_id)).is_true()
