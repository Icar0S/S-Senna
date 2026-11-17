class_name SoundProfileDef
extends RefCounted
## Engine sound profile (`sound.json`, doc 03 §10): loops cross-faded by RPM and load.

const SCHEMA: String = "sound_profile"
const SCHEMA_VERSION: int = 1
const FILE_NAME: String = "sound.json"
const LOADS: PackedStringArray = ["any", "on", "off"]

var id: String = ""
var loops: Array[Loop] = []
## Extra sound name (`turbo`, `blowoff`, `backfire`...) -> resolved file path.
var extras: Dictionary = {}


class Loop:
	extends RefCounted
	var file_path: String = ""
	var rpm: int = 1000
	var load: String = "any"


static func from_dict(data: Dictionary, ctx: LoadContext) -> SoundProfileDef:
	var errors_before: int = ctx.report.error_count()
	var reader: DictReader = DictReader.new(data, ctx)
	reader.check_header(SCHEMA, SCHEMA_VERSION)
	var profile: SoundProfileDef = SoundProfileDef.new()
	profile.id = reader.content_id("id", ContentId.TYPE_SOUND, true)
	ctx.check_id_pack("id", profile.id)
	for loop_reader: DictReader in reader.child_list("loops", true):
		var loop: Loop = Loop.new()
		loop.file_path = ctx.resolve_path(
			loop_reader.field_path("file"), loop_reader.text("file", true)
		)
		loop.rpm = loop_reader.integer("rpm", true, 1000, 0, 20000)
		loop.load = loop_reader.enum_value("load", LOADS, false, "any")
		profile.loops.append(loop)
	if profile.loops.is_empty():
		ctx.error("loops", "o perfil precisa de pelo menos um loop")
	var extras: DictReader = reader.child("extras")
	for extra_name: String in extras.keys():
		var file: String = extras.text(extra_name, true)
		profile.extras[extra_name] = ctx.resolve_path(extras.field_path(extra_name), file)
	reader.finish()
	return profile if ctx.report.error_count() == errors_before else null
