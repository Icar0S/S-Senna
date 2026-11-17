extends GdUnitTestSuite
## Log: writes leveled lines to a file and keeps at most 5 files.

const TEMP_DIR_NAME: String = "test_log"

var _dir: String = ""


func before_test() -> void:
	_dir = create_temp_dir(TEMP_DIR_NAME)


func after_test() -> void:
	clean_temp_dir()


func test_format_line() -> void:
	var line: String = LogWriter.format_line(
		LogWriter.Level.WARN, "missing part", "ContentDB", "2026-11-16 10:00:00"
	)
	assert_str(line).is_equal("2026-11-16 10:00:00 [WARN] [ContentDB] missing part")
	var without_context: String = LogWriter.format_line(
		LogWriter.Level.INFO, "hello", "", "2026-11-16 10:00:00"
	)
	assert_str(without_context).is_equal("2026-11-16 10:00:00 [INFO] hello")


func test_writes_lines_to_file() -> void:
	var path: String = _dir.path_join("app.log")
	var writer: LogWriter = LogWriter.new()
	assert_int(writer.open(path)).is_equal(OK)
	assert_bool(writer.is_open()).is_true()
	assert_str(writer.get_path()).is_equal(path)

	writer.write(LogWriter.Level.DEBUG, "first")
	writer.write(LogWriter.Level.INFO, "second", "Test")
	writer.write(LogWriter.Level.WARN, "third")
	writer.write(LogWriter.Level.ERROR, "fourth")
	writer.close()

	var lines: PackedStringArray = _read_lines(path)
	assert_int(lines.size()).is_equal(4)
	assert_str(lines[0]).ends_with("[DEBUG] first")
	assert_str(lines[1]).ends_with("[INFO] [Test] second")
	assert_str(lines[2]).ends_with("[WARN] third")
	assert_str(lines[3]).ends_with("[ERROR] fourth")


func test_line_is_on_disk_before_close() -> void:
	var path: String = _dir.path_join("flush.log")
	var writer: LogWriter = LogWriter.new()
	writer.open(path)
	writer.write(LogWriter.Level.ERROR, "about to crash")
	# Not closed yet: a crash right now must not lose the line.
	assert_str(FileAccess.get_file_as_string(path)).contains("about to crash")
	writer.close()


func test_min_level_filters_messages() -> void:
	var path: String = _dir.path_join("filtered.log")
	var writer: LogWriter = LogWriter.new()
	writer.min_level = LogWriter.Level.WARN
	writer.open(path)
	assert_str(writer.write(LogWriter.Level.DEBUG, "hidden")).is_empty()
	assert_str(writer.write(LogWriter.Level.INFO, "hidden too")).is_empty()
	assert_str(writer.write(LogWriter.Level.WARN, "shown")).is_not_empty()
	writer.close()

	var lines: PackedStringArray = _read_lines(path)
	assert_int(lines.size()).is_equal(1)
	assert_str(lines[0]).ends_with("[WARN] shown")


func test_write_without_open_file_still_returns_line() -> void:
	var writer: LogWriter = LogWriter.new()
	assert_bool(writer.is_open()).is_false()
	assert_str(writer.write(LogWriter.Level.INFO, "console only")).ends_with("[INFO] console only")


func test_creates_missing_folders() -> void:
	var path: String = _dir.path_join("nested/deeper/app.log")
	var writer: LogWriter = LogWriter.new()
	assert_int(writer.open(path)).is_equal(OK)
	writer.close()
	assert_bool(FileAccess.file_exists(path)).is_true()


func test_rotated_path() -> void:
	assert_str(LogWriter.rotated_path("user://logs/s-senna.log", 2)).is_equal(
		"user://logs/s-senna.2.log"
	)


func test_rotation_keeps_at_most_five_files() -> void:
	var path: String = _dir.path_join("rot.log")
	var writer: LogWriter = LogWriter.new()
	for run: int in 8:
		writer.open(path)
		writer.write(LogWriter.Level.INFO, "run %d" % run)
		writer.close()

	var files: PackedStringArray = DirAccess.get_files_at(_dir)
	assert_int(files.size()).is_equal(LogWriter.DEFAULT_MAX_FILES)
	# Newest run in the main file, then each older run one position further.
	assert_str(_read_lines(path)[0]).ends_with("run 7")
	assert_str(_read_lines(LogWriter.rotated_path(path, 1))[0]).ends_with("run 6")
	assert_str(_read_lines(LogWriter.rotated_path(path, 4))[0]).ends_with("run 3")
	assert_bool(FileAccess.file_exists(LogWriter.rotated_path(path, 5))).is_false()


func test_autoload_writes_to_user_logs() -> void:
	var marker: String = "log autoload test %d" % Time.get_ticks_usec()
	Log.info(marker, "Test")
	assert_str(Log.LOG_PATH).is_equal("user://logs/s-senna.log")
	assert_bool(FileAccess.file_exists(Log.LOG_PATH)).is_true()
	assert_str(FileAccess.get_file_as_string(Log.LOG_PATH)).contains("[INFO] [Test] " + marker)
	assert_str(Log.get_log_path()).ends_with("logs/s-senna.log")


func _read_lines(path: String) -> PackedStringArray:
	var text: String = FileAccess.get_file_as_string(path)
	return text.strip_edges().split("\n", false)
