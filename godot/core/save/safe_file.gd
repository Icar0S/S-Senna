class_name SafeFile
extends RefCounted
## Atomic writes with rotating backups (ADR 008) and reading with fallback.
##
## Write: `file.tmp` -> check it reads back -> rotate `.bak3 <- .bak2 <- .bak1 <- file`
## -> rename `.tmp` to `file`. If any step fails, the previous file stays (as the
## file itself or as `.bak1`) and the error is returned. Reading tries the file and
## then `.bak1`, `.bak2`, `.bak3`.

const TMP_SUFFIX: String = ".tmp"
const BACKUP_SUFFIX: String = ".bak"


## Path of backup [param index] (1 = newest): `profile.json.bak1`.
static func backup_path(path: String, index: int) -> String:
	return "%s%s%d" % [path, BACKUP_SUFFIX, index]


## The file followed by its backups, in the order they should be tried.
static func candidates(path: String, backups: int) -> PackedStringArray:
	var result: PackedStringArray = [path]
	for i: int in range(1, backups + 1):
		result.append(backup_path(path, i))
	return result


## Writes [param text] to [param path] keeping [param backups] older copies.
static func write(ops: FileOps, path: String, text: String, backups: int) -> Error:
	var tmp: String = path + TMP_SUFFIX
	var error: Error = ops.write_text(tmp, text)
	if error == OK:
		var written: Variant = ops.read_text(tmp)
		if written == null or written != text:
			error = ERR_FILE_CORRUPT
	if error != OK:
		if ops.file_exists(tmp):
			ops.remove(tmp)
		return error
	error = _rotate(ops, path, backups)
	if error != OK:
		return error
	return ops.rename(tmp, path)


static func _rotate(ops: FileOps, path: String, backups: int) -> Error:
	if not ops.file_exists(path):
		return OK
	if backups <= 0:
		return ops.remove(path)
	var oldest: String = backup_path(path, backups)
	if ops.file_exists(oldest):
		var remove_error: Error = ops.remove(oldest)
		if remove_error != OK:
			return remove_error
	for i: int in range(backups - 1, 0, -1):
		var source: String = backup_path(path, i)
		if ops.file_exists(source):
			var shift_error: Error = ops.rename(source, backup_path(path, i + 1))
			if shift_error != OK:
				return shift_error
	return ops.rename(path, backup_path(path, 1))
