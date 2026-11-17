class_name BootResolver
extends RefCounted
## Decides which program the boot scene opens: the Game or the S-Senna Studio.
##
## The Studio is selected by the export feature `studio` (Studio builds) or by
## the user argument `--studio` (running from source: `godot --path godot -- --studio`).

enum Mode { GAME, STUDIO }

const STUDIO_FEATURE: String = "studio"
const STUDIO_ARG: String = "--studio"

const GAME_SCENE: String = "res://game/main_menu/main_menu.tscn"
# Text path on purpose (never `preload`): the `studio/` folder is excluded from
# Game exports, so nothing may hold a hard reference to it.
const STUDIO_SCENE: String = "res://studio/studio_main.tscn"

const MODE_NAMES: PackedStringArray = ["game", "studio"]


static func resolve_mode(has_studio_feature: bool, user_args: PackedStringArray) -> Mode:
	if has_studio_feature or CmdlineArgs.has_flag(user_args, STUDIO_ARG):
		return Mode.STUDIO
	return Mode.GAME


static func scene_path_for(mode: Mode) -> String:
	return STUDIO_SCENE if mode == Mode.STUDIO else GAME_SCENE


static func mode_name(mode: Mode) -> String:
	return MODE_NAMES[mode]
