class_name PackDef
extends RefCounted
## A content pack (`pack.json`, doc 03 §3.1).

enum Source { BUILTIN, MOD, EXTRA }

const SCHEMA: String = "pack"
const SCHEMA_VERSION: int = 1
const FILE_NAME: String = "pack.json"
const SOURCE_NAMES: PackedStringArray = ["builtin", "mod", "extra"]
const PRIORITY_MIN: int = -1000
const PRIORITY_MAX: int = 1000

var id: String = ""
var name: String = ""
var version: String = ""
var authors: PackedStringArray = []
var license: String = ""
var depends: PackedStringArray = []
## Higher wins when two packs define the same ID.
var priority: int = 0
## Old ID -> new ID.
var aliases: Dictionary = {}
## Folder that contains `pack.json` (filled by the scanner).
var root_dir: String = ""
var source: Source = Source.BUILTIN


static func from_dict(data: Dictionary, ctx: LoadContext) -> PackDef:
	var errors_before: int = ctx.report.error_count()
	var reader: DictReader = DictReader.new(data, ctx)
	reader.check_header(SCHEMA, SCHEMA_VERSION)
	var pack: PackDef = PackDef.new()
	pack.id = reader.text("id", true)
	if not pack.id.is_empty() and not ContentId.is_valid_name(pack.id):
		ctx.error("id", "nome de pacote inválido '%s' (use a-z, 0-9, _ e -)" % pack.id)
	pack.name = reader.text("name", true)
	pack.version = reader.text("version", true)
	pack.authors = reader.string_list("authors")
	pack.license = reader.text("license")
	pack.depends = reader.string_list("depends")
	for dependency: String in pack.depends:
		if not ContentId.is_valid_name(dependency):
			ctx.error("depends", "nome de pacote inválido '%s'" % dependency)
	pack.priority = reader.integer("priority", false, 0, PRIORITY_MIN, PRIORITY_MAX)
	pack.aliases = _read_aliases(reader.child("aliases"))
	reader.finish()
	return pack if ctx.report.error_count() == errors_before else null


func source_name() -> String:
	return SOURCE_NAMES[source]


static func _read_aliases(reader: DictReader) -> Dictionary:
	var aliases: Dictionary = {}
	for old_id: String in reader.keys():
		var new_id: String = reader.content_id(old_id, "", true)
		var problem: String = ContentId.validation_error(old_id)
		if not problem.is_empty():
			reader.context().error(reader.field_path(old_id), "%s: '%s'" % [problem, old_id])
			continue
		if new_id.is_empty():
			continue
		if old_id.get_slice(":", 0) != new_id.get_slice(":", 0):
			reader.context().error(reader.field_path(old_id), "alias deve manter o tipo do ID")
			continue
		if old_id == new_id:
			reader.context().error(reader.field_path(old_id), "alias aponta para ele mesmo")
			continue
		aliases[old_id] = new_id
	return aliases
