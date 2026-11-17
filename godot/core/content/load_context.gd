class_name LoadContext
extends RefCounted
## Where a definition is being read from (file, folder, pack) and where its
## problems are reported. One per JSON file; all share the same [ContentReport].

var report: ContentReport = null
## JSON file being read (used in messages).
var file_path: String = ""
## Folder of [member file_path]; relative paths in the JSON are resolved against it.
var base_dir: String = ""
## Pack being loaded ("" when reading a loose file, e.g. in tests).
var pack_id: String = ""
## Other packs whose IDs this pack may (re)define: its `depends`. This is how a
## mod with higher priority replaces, e.g., `car:base/x`.
var allowed_packs: PackedStringArray = []


func _init(
	context_report: ContentReport = null, context_file: String = "", context_pack: String = ""
) -> void:
	report = context_report if context_report != null else ContentReport.new()
	file_path = context_file
	base_dir = context_file.get_base_dir()
	pack_id = context_pack


## A new context for another file of the same pack, sharing the report.
func for_file(path: String) -> LoadContext:
	var ctx: LoadContext = LoadContext.new(report, path, pack_id)
	ctx.allowed_packs = allowed_packs
	return ctx


## Reports an error when [param content_id] belongs to a pack that this pack
## may not define (neither itself nor one of its dependencies).
func check_id_pack(field: String, content_id: String) -> void:
	if pack_id.is_empty():
		return
	var parsed: ContentId = ContentId.parse(content_id)
	if parsed == null or parsed.pack == pack_id or allowed_packs.has(parsed.pack):
		return
	var message: String = "ID do pacote '%s' dentro do pacote '%s'" % [parsed.pack, pack_id]
	error(field, message + " (para usar IDs de outro pacote, declare-o em depends)")


func error(field: String, message: String) -> void:
	report.add_error(file_path, field, message)


func warning(field: String, message: String) -> void:
	report.add_warning(file_path, field, message)


## Resolves a path written in the JSON (relative to the JSON's folder).
## Absolute paths and `..` are refused, so a mod can't point outside its folder.
## Returns "" (and reports an error) when the path is not acceptable.
func resolve_path(field: String, relative: String) -> String:
	if relative.is_empty():
		return ""
	var normalized: String = relative.replace("\\", "/")
	var parts: PackedStringArray = normalized.split("/")
	if normalized.is_absolute_path() or normalized.contains("://") or parts.has(".."):
		error(field, "caminho deve ser relativo à pasta do arquivo, sem '..': '%s'" % relative)
		return ""
	if base_dir.is_empty():
		return normalized
	return base_dir.path_join(normalized)
