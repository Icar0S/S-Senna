extends Node
## Autoload `Log`: console + file logging with levels.
##
## Usage: `Log.info("Loaded 12 cars", "ContentDB")`.
## The file lives in `<saves>/logs/s-senna.log` (the user folder, or `save/` next
## to the game in portable mode); the 4 previous runs are kept as
## `s-senna.1.log` … `s-senna.4.log`. All the logic is in [LogWriter].

const LOG_FILE: String = "s-senna.log"

var _writer: LogWriter = LogWriter.new()
var _path: String = ""


func _init() -> void:
	# Opened in _init (not _ready) so that other autoloads can log while starting.
	_writer.min_level = LogWriter.Level.DEBUG if OS.is_debug_build() else LogWriter.Level.INFO
	_path = SavePaths.detect_base_dir().path_join(SavePaths.LOGS_DIR).path_join(LOG_FILE)
	var open_error: Error = _writer.open(_path)
	if open_error != OK:
		push_warning("Log: could not open %s (%s)" % [_path, error_string(open_error)])


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_writer.close()


func debug(message: String, context: String = "") -> void:
	var line: String = _writer.write(LogWriter.Level.DEBUG, message, context)
	if not line.is_empty():
		print(line)


func info(message: String, context: String = "") -> void:
	var line: String = _writer.write(LogWriter.Level.INFO, message, context)
	if not line.is_empty():
		print(line)


func warn(message: String, context: String = "") -> void:
	var line: String = _writer.write(LogWriter.Level.WARN, message, context)
	if not line.is_empty():
		push_warning(line)


func error(message: String, context: String = "") -> void:
	var line: String = _writer.write(LogWriter.Level.ERROR, message, context)
	if not line.is_empty():
		push_error(line)


## Absolute OS path of the current log file (useful for "open logs folder").
func get_log_path() -> String:
	return _path


func get_min_level() -> LogWriter.Level:
	return _writer.min_level


func set_min_level(level: LogWriter.Level) -> void:
	_writer.min_level = level
