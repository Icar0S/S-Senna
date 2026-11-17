class_name SavePaths
extends RefCounted
## Where saves, settings, logs and mods live (Etapa 02).
##
## - Normal: the Godot user folder (`%APPDATA%\S-Senna`, `~/.local/share/S-Senna`).
## - Portable mode: when a `portable.txt` file sits next to the executable, everything
##   goes to `<game folder>/save/` (to carry the game on a USB stick).
## Code never writes saves to `user://` directly: it asks for [method detect_base_dir].

const PORTABLE_MARKER: String = "portable.txt"
const PORTABLE_DIR: String = "save"
const SETTINGS_FILE: String = "settings.json"
const INPUT_FILE: String = "input.json"
const PROFILES_DIR: String = "profiles"
const TRASH_DIR: String = "_lixeira"
const LOGS_DIR: String = "logs"
const MODS_DIR: String = "mods"
const PHOTOS_DIR: String = "photos"
const GHOSTS_DIR: String = "ghosts"


## Base folder for this run (absolute OS path, `/` separators).
static func detect_base_dir() -> String:
	return resolve_base_dir(
		OS.get_executable_path().get_base_dir(), ProjectSettings.globalize_path("user://")
	)


## Pure rule behind [method detect_base_dir] (testable): portable when
## [param executable_dir] has `portable.txt`, otherwise [param user_dir].
static func resolve_base_dir(executable_dir: String, user_dir: String) -> String:
	if FileAccess.file_exists(executable_dir.path_join(PORTABLE_MARKER)):
		return executable_dir.path_join(PORTABLE_DIR)
	return user_dir.trim_suffix("/")


static func is_portable(executable_dir: String) -> bool:
	return FileAccess.file_exists(executable_dir.path_join(PORTABLE_MARKER))
