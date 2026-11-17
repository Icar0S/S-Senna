class_name Boot
extends Node
## Entry scene of the project: opens the Game or the S-Senna Studio.
## The decision lives in [BootResolver]; this node only applies it.

const SELF_CHECK_ARG: String = "--self-check"
const LOG_CONTEXT: String = "Boot"


func _ready() -> void:
	# Deferred: a scene can't be swapped while the tree is still adding this one.
	_start.call_deferred()


## Scene to open for the given launch conditions. Falls back to the Game when
## the Studio was requested but is not part of this build (Game exports).
func resolve_scene_path(has_studio_feature: bool, user_args: PackedStringArray) -> String:
	var mode: BootResolver.Mode = BootResolver.resolve_mode(has_studio_feature, user_args)
	var path: String = BootResolver.scene_path_for(mode)
	if mode == BootResolver.Mode.STUDIO and not ResourceLoader.exists(path):
		Log.warn("Studio requested but not available in this build; opening the game.", LOG_CONTEXT)
		return BootResolver.GAME_SCENE
	return path


func _start() -> void:
	var has_studio_feature: bool = OS.has_feature(BootResolver.STUDIO_FEATURE)
	var user_args: PackedStringArray = OS.get_cmdline_user_args()

	if CmdlineArgs.has_flag(user_args, SELF_CHECK_ARG):
		var mode: BootResolver.Mode = BootResolver.resolve_mode(has_studio_feature, user_args)
		print(BootSelfCheck.format_output(BootSelfCheck.run(mode)))
		get_tree().quit(0)
		return

	var path: String = resolve_scene_path(has_studio_feature, user_args)
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	Log.info("S-Senna %s starting: %s" % [version, path], LOG_CONTEXT)
	var change_error: Error = get_tree().change_scene_to_file(path)
	if change_error != OK:
		Log.error("Could not open %s (%s)" % [path, error_string(change_error)], LOG_CONTEXT)
		get_tree().quit(1)
