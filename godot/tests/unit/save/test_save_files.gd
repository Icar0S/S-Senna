extends GdUnitTestSuite
## Save folder (portable mode), atomic writes with backups, checksum and migrations.

const GOLDEN_V1: String = "res://tests/fixtures/saves/profile_v1.json"

var _dir: String = ""


func before_test() -> void:
	_dir = ProjectSettings.globalize_path(create_temp_dir("save_files"))


func after_test() -> void:
	clean_temp_dir()


func test_portable_mode_changes_base_dir() -> void:
	var game_dir: String = _dir.path_join("Meu Jogo Ção")
	var user_dir: String = _dir.path_join("usuario")
	DirAccess.make_dir_recursive_absolute(game_dir)
	assert_str(SavePaths.resolve_base_dir(game_dir, user_dir + "/")).is_equal(user_dir)
	assert_bool(SavePaths.is_portable(game_dir)).is_false()
	TestContent.write_text(game_dir.path_join("portable.txt"), "")
	assert_str(SavePaths.resolve_base_dir(game_dir, user_dir)).is_equal(game_dir.path_join("save"))
	assert_bool(SavePaths.is_portable(game_dir)).is_true()


func test_atomic_write_keeps_three_backups() -> void:
	var ops: FileOps = FileOps.new()
	var path: String = _dir.path_join("pasta com espaço/arquivo.json")
	for i: int in 6:
		assert_int(SafeFile.write(ops, path, "versão %d" % i, 3)).is_equal(OK)
	assert_str(FileAccess.get_file_as_string(path)).is_equal("versão 5")
	assert_str(FileAccess.get_file_as_string(SafeFile.backup_path(path, 1))).is_equal("versão 4")
	assert_str(FileAccess.get_file_as_string(SafeFile.backup_path(path, 3))).is_equal("versão 2")
	assert_bool(FileAccess.file_exists(SafeFile.backup_path(path, 4))).is_false()
	assert_bool(FileAccess.file_exists(path + ".tmp")).is_false()


func test_failed_write_keeps_previous_file() -> void:
	var path: String = _dir.path_join("arquivo.json")
	assert_int(SafeFile.write(FileOps.new(), path, "bom", 3)).is_equal(OK)
	var full_disk: TestSaves.FaultyFileOps = TestSaves.FaultyFileOps.new()
	full_disk.fail_writes_ending = ".tmp"
	assert_int(SafeFile.write(full_disk, path, "novo", 3)).is_equal(ERR_FILE_CANT_WRITE)
	assert_str(FileAccess.get_file_as_string(path)).is_equal("bom")
	assert_bool(FileAccess.file_exists(SafeFile.backup_path(path, 1))).is_false()
	# A write that "succeeds" but stores garbage is caught by reading it back.
	var silent: TestSaves.FaultyFileOps = TestSaves.FaultyFileOps.new()
	silent.truncate_writes = true
	assert_int(SafeFile.write(silent, path, "conteúdo novo e longo", 3)).is_equal(ERR_FILE_CORRUPT)
	assert_str(FileAccess.get_file_as_string(path)).is_equal("bom")
	assert_bool(FileAccess.file_exists(path + ".tmp")).is_false()


func test_checksum_survives_json_round_trip() -> void:
	var data: Dictionary = TestSaves.full_profile("p1", 2).to_dict()
	var envelope: Dictionary = SaveEnvelope.wrap("profile", 1, data, TestSaves.FIXED_TIME)
	var problem: Array = []
	var parsed: Dictionary = SaveEnvelope.parse(SaveEnvelope.to_text(envelope), "profile", problem)
	assert_bool(parsed.is_empty()).override_failure_message(str(problem)).is_false()
	assert_str(str(envelope["checksum"])).starts_with("sha256:")


func test_tampered_or_broken_files_are_refused() -> void:
	var data: Dictionary = TestSaves.full_profile("p1", 1).to_dict()
	var text: String = SaveEnvelope.to_text(SaveEnvelope.wrap("profile", 1, data, "agora"))
	var cases: Dictionary = {
		text.replace("12000", "99999"): "checksum",
		text.substr(0, text.length() / 2): "JSON inválido",
		text.replace('"schema": "profile"', '"schema": "settings"'): "tipo de arquivo",
		"[1, 2]": "objeto",
	}
	for broken: String in cases:
		var problem: Array = []
		assert_bool(SaveEnvelope.parse(broken, "profile", problem).is_empty()).is_true()
		assert_str(str(problem)).contains(cases[broken])


func test_golden_v1_is_valid() -> void:
	var problem: Array = []
	var text: String = FileAccess.get_file_as_string(GOLDEN_V1)
	var envelope: Dictionary = SaveEnvelope.parse(text, "profile", problem)
	assert_bool(envelope.is_empty()).override_failure_message(str(problem)).is_false()
	assert_int(SaveEnvelope.version_of(envelope)).is_equal(1)


func test_example_migration_v1_to_v2_on_golden_file() -> void:
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_V1))
	var registry: Dictionary = {"profile": {1: ExampleMigrationV1ToV2.new()}}
	var migrations: Migrations = Migrations.new(registry, {"profile": 2})
	assert_bool(migrations.can_migrate("profile", 1)).is_true()
	var migrated: Dictionary = migrations.apply(envelope["data"], "profile", 1)
	assert_str(str(migrated["player_prefs"]["camera_mode"])).is_equal("chase_far")
	assert_bool((migrated["player_prefs"] as Dictionary).has("camera")).is_false()
	assert_int(int(migrated["wallet"]["tokens"])).is_equal(0)
	assert_int(int(migrated["wallet"]["money"])).is_equal(12000)
	# Original data untouched; the result still loads as a profile.
	assert_bool((envelope["data"]["player_prefs"] as Dictionary).has("camera")).is_true()
	assert_object(ProfileData.from_dict(migrated, LoadContext.new())).is_not_null()


func test_missing_migration_step() -> void:
	var migrations: Migrations = Migrations.new({"profile": {}}, {"profile": 3})
	assert_bool(migrations.can_migrate("profile", 1)).is_false()
	assert_dict(migrations.apply({"a": 1}, "profile", 1)).is_empty()
	# Current version: nothing to do.
	assert_dict(Migrations.new().apply({"a": 1}, "profile", 1)).is_equal({"a": 1})


func test_profile_store_migrates_old_files_on_load() -> void:
	var registry: Dictionary = {"profile": {1: ExampleMigrationV1ToV2.new()}}
	var store: ProfileStore = TestSaves.store(_dir, null, Migrations.new(registry, {"profile": 2}))
	var target: String = store.profile_path("golden")
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	DirAccess.copy_absolute(ProjectSettings.globalize_path(GOLDEN_V1), target)
	var loaded: ProfileStore.LoadResult = store.load_profile("golden")
	assert_bool(loaded.ok()).is_true()
	assert_bool(loaded.migrated).is_true()
	assert_int(loaded.profile.money).is_equal(12000)
	assert_int(store.save_profile(loaded.profile)).is_equal(OK)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(target))
	assert_int(int(saved["schema_version"])).is_equal(2)
	# The old v1 file is kept as the first backup.
	var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(target + ".bak1"))
	assert_int(int(backup["schema_version"])).is_equal(1)
