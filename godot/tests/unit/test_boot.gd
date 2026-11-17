extends GdUnitTestSuite
## Boot: with no argument the Game opens; with `--studio` (or the `studio`
## export feature) the Studio opens.

const NO_ARGS: PackedStringArray = []
const STUDIO_ARGS: PackedStringArray = ["--studio"]
const OTHER_ARGS: PackedStringArray = ["--content-dir=/tmp/pack", "--verbose"]


func test_no_argument_resolves_game() -> void:
	assert_int(BootResolver.resolve_mode(false, NO_ARGS)).is_equal(BootResolver.Mode.GAME)
	assert_int(BootResolver.resolve_mode(false, OTHER_ARGS)).is_equal(BootResolver.Mode.GAME)


func test_studio_argument_resolves_studio() -> void:
	assert_int(BootResolver.resolve_mode(false, STUDIO_ARGS)).is_equal(BootResolver.Mode.STUDIO)


func test_studio_feature_resolves_studio() -> void:
	assert_int(BootResolver.resolve_mode(true, NO_ARGS)).is_equal(BootResolver.Mode.STUDIO)


func test_scene_paths_exist() -> void:
	var game_path: String = BootResolver.scene_path_for(BootResolver.Mode.GAME)
	var studio_path: String = BootResolver.scene_path_for(BootResolver.Mode.STUDIO)
	assert_str(game_path).is_equal("res://game/main_menu/main_menu.tscn")
	assert_str(studio_path).is_equal("res://studio/studio_main.tscn")
	assert_bool(ResourceLoader.exists(game_path)).is_true()
	assert_bool(ResourceLoader.exists(studio_path)).is_true()


func test_boot_without_argument_loads_main_menu() -> void:
	var boot: Boot = auto_free(Boot.new())
	var scene: Node = _instantiate(boot.resolve_scene_path(false, NO_ARGS))
	assert_object(scene).is_instanceof(MainMenu)


func test_boot_with_studio_argument_loads_studio_main() -> void:
	var boot: Boot = auto_free(Boot.new())
	var scene: Node = _instantiate(boot.resolve_scene_path(false, STUDIO_ARGS))
	assert_object(scene).is_instanceof(StudioMain)


func test_main_menu_shows_name_and_version() -> void:
	var menu: MainMenu = _instantiate(BootResolver.GAME_SCENE)
	add_child(menu)
	var title: Label = menu.get_node("%TitleLabel")
	var version: Label = menu.get_node("%VersionLabel")
	assert_str(title.text).is_equal("S-Senna")
	assert_str(version.text).is_equal("v" + _project_version())


func test_studio_main_shows_name_and_version() -> void:
	var studio: StudioMain = _instantiate(BootResolver.STUDIO_SCENE)
	add_child(studio)
	var title: Label = studio.get_node("%TitleLabel")
	var version: Label = studio.get_node("%VersionLabel")
	assert_str(title.text).is_equal("S-Senna Studio")
	assert_str(version.text).is_equal("v" + _project_version())


func test_boot_scene_is_the_main_scene() -> void:
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene"))
	assert_str(main_scene).is_equal("res://boot/boot.tscn")
	var boot: Node = _instantiate(main_scene)
	assert_object(boot).is_instanceof(Boot)


func test_self_check_reports_source_build() -> void:
	var report: Dictionary = BootSelfCheck.run(BootResolver.Mode.GAME)
	assert_str(str(report["mode"])).is_equal("game")
	assert_str(str(report["version"])).is_equal(_project_version())
	assert_bool(report["content_json"]).is_true()
	# Running from source (not an exported Game build), so the Studio is there.
	assert_bool(report["studio_present"]).is_true()
	assert_str(BootSelfCheck.format_output(report)).starts_with("SELF_CHECK {")


func test_self_check_rejects_missing_or_invalid_json() -> void:
	var missing: String = "res://content/does_not_exist.json"
	var not_json: String = "res://project.godot"
	assert_bool(BootSelfCheck.is_content_json_readable(missing)).is_false()
	assert_bool(BootSelfCheck.is_content_json_readable(not_json)).is_false()


func _instantiate(scene_path: String) -> Node:
	var packed: PackedScene = load(scene_path)
	assert_object(packed).is_not_null()
	return auto_free(packed.instantiate())


func _project_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version"))
