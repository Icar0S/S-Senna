class_name ContentScanOptions
extends RefCounted
## Where [ContentLibrary] looks for packs.
##
## Order: built-in packs (`res://content/packs/*`), enabled mods (`user://mods/*`)
## and extra folders (`--content-dir=<path>`, used by the Studio). An extra folder
## may be a pack, a folder of packs, or a `content/` folder that has `packs/`.

const DEFAULT_BUILTIN_DIR: String = "res://content/packs"
const DEFAULT_MODS_DIR: String = "user://mods"
const CONTENT_DIR_ARG: String = "--content-dir"

var builtin_dirs: PackedStringArray = [DEFAULT_BUILTIN_DIR]
var mods_dir: String = DEFAULT_MODS_DIR
## Pack IDs of the mods to load (`settings.mods.enabled`; wired in Etapa 02).
var enabled_mods: PackedStringArray = []
var extra_dirs: PackedStringArray = []


## Default options plus `--content-dir` from the user arguments.
static func from_cmdline(user_args: PackedStringArray) -> ContentScanOptions:
	var options: ContentScanOptions = ContentScanOptions.new()
	var extra: String = CmdlineArgs.get_value(user_args, CONTENT_DIR_ARG)
	if not extra.is_empty():
		options.extra_dirs.append(extra)
	return options
