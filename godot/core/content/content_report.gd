class_name ContentReport
extends RefCounted
## Errors and warnings found while loading content (file, field and message in pt-BR).
## Content errors never crash the game: they end up here, for the log and the Studio.

enum Severity { WARNING, ERROR }

const SEVERITY_LABELS: PackedStringArray = ["AVISO", "ERRO"]

var entries: Array[Entry] = []


class Entry:
	extends RefCounted
	var severity: Severity = Severity.WARNING
	var file: String = ""
	var field: String = ""
	var message: String = ""

	func _init(
		entry_severity: Severity, entry_file: String, entry_field: String, entry_message: String
	) -> void:
		severity = entry_severity
		file = entry_file
		field = entry_field
		message = entry_message

	func is_error() -> bool:
		return severity == Severity.ERROR

	func to_text() -> String:
		var location: String = file
		if not field.is_empty():
			location = field if location.is_empty() else "%s [%s]" % [location, field]
		if location.is_empty():
			return "%s: %s" % [SEVERITY_LABELS[severity], message]
		return "%s: %s: %s" % [SEVERITY_LABELS[severity], location, message]


func add_error(file: String, field: String, message: String) -> void:
	entries.append(Entry.new(Severity.ERROR, file, field, message))


func add_warning(file: String, field: String, message: String) -> void:
	entries.append(Entry.new(Severity.WARNING, file, field, message))


func error_count() -> int:
	return _count(Severity.ERROR)


func warning_count() -> int:
	return _count(Severity.WARNING)


func has_errors() -> bool:
	return error_count() > 0


func is_empty() -> bool:
	return entries.is_empty()


## Entries whose message, field or file contains [param text] (handy in tests and the Studio).
func find(text: String) -> Array[Entry]:
	var found: Array[Entry] = []
	for entry: Entry in entries:
		if entry.message.contains(text) or entry.field.contains(text) or entry.file.contains(text):
			found.append(entry)
	return found


func merge(other: ContentReport) -> void:
	entries.append_array(other.entries)


func clear() -> void:
	entries.clear()


## One line per entry, errors first.
func to_text() -> String:
	var lines: PackedStringArray = []
	for severity: Severity in [Severity.ERROR, Severity.WARNING]:
		for entry: Entry in entries:
			if entry.severity == severity:
				lines.append(entry.to_text())
	return "\n".join(lines)


func _count(severity: Severity) -> int:
	var total: int = 0
	for entry: Entry in entries:
		if entry.severity == severity:
			total += 1
	return total
