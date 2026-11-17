class_name LogWriter
extends RefCounted
## Writes leveled log lines to a file, keeping a few rotated copies of past runs.
##
## The `Log` autoload is a thin node around this class. Rotation happens once
## per [method open]: `s-senna.log` becomes `s-senna.1.log`, `.1` becomes `.2`
## and so on, so at most [constant DEFAULT_MAX_FILES] files exist.

enum Level { DEBUG, INFO, WARN, ERROR }

const LEVEL_NAMES: PackedStringArray = ["DEBUG", "INFO", "WARN", "ERROR"]
const DEFAULT_MAX_FILES: int = 5

## Messages below this level are ignored.
var min_level: Level = Level.DEBUG

var _file: FileAccess = null
var _path: String = ""


## Builds the path of a rotated file: (`logs/a.log`, 2) -> `logs/a.2.log`.
static func rotated_path(path: String, index: int) -> String:
	return "%s.%d.%s" % [path.get_basename(), index, path.get_extension()]


## Shifts existing log files one position, dropping the oldest, so that after
## the current file is created there are at most [param max_files] files.
static func rotate(path: String, max_files: int = DEFAULT_MAX_FILES) -> void:
	for i: int in range(max_files - 1, 0, -1):
		var source: String = path if i == 1 else rotated_path(path, i - 1)
		var target: String = rotated_path(path, i)
		if not FileAccess.file_exists(source):
			continue
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)
		DirAccess.rename_absolute(source, target)


## Formats one log line (without the trailing newline).
static func format_line(
	level: Level, message: String, context: String, timestamp: String
) -> String:
	var prefix: String = "" if context.is_empty() else "[%s] " % context
	return "%s [%s] %s%s" % [timestamp, LEVEL_NAMES[level], prefix, message]


## Rotates old files and opens [param path] for writing. Creates the folder if needed.
func open(path: String, max_files: int = DEFAULT_MAX_FILES) -> Error:
	close()
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if dir_error != OK:
		return dir_error
	rotate(path, max_files)
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		return FileAccess.get_open_error()
	_path = path
	return OK


func close() -> void:
	if _file != null:
		_file.close()
	_file = null
	_path = ""


func is_open() -> bool:
	return _file != null


## Path given to the last successful [method open], or an empty string.
func get_path() -> String:
	return _path


## Writes one line and returns it. Returns an empty string when the message is
## filtered out by [member min_level]. Still returns the line when no file is
## open, so the caller can print it to the console.
func write(level: Level, message: String, context: String = "") -> String:
	if level < min_level:
		return ""
	var timestamp: String = Time.get_datetime_string_from_system(false, true)
	var line: String = format_line(level, message, context, timestamp)
	if _file != null:
		_file.store_line(line)
		# Flush every line: the log matters most right before a crash.
		_file.flush()
	return line
