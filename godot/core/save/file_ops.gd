class_name FileOps
extends RefCounted
## File system operations used by the save code. Tests replace this object with
## one that fails on purpose (full disk, no permission) to prove nothing is lost.


## Writes [param text] (UTF-8) to [param path], creating the folder if needed.
func write_text(path: String, text: String) -> Error:
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if dir_error != OK:
		return dir_error
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored: bool = file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if not stored and error == OK:
		return ERR_FILE_CANT_WRITE
	return error


## Contents of [param path], or `null` when it can't be read.
func read_text(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()
	return text


func read_bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


func write_bytes(path: String, bytes: PackedByteArray) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	var error: Error = file.get_error()
	file.close()
	return error


func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func dir_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)


func remove(path: String) -> Error:
	return DirAccess.remove_absolute(path)


## Renames a file or a folder.
func rename(from_path: String, to_path: String) -> Error:
	return DirAccess.rename_absolute(from_path, to_path)


func make_dir(path: String) -> Error:
	return DirAccess.make_dir_recursive_absolute(path)


## Sorted names of the subfolders of [param path].
func list_dirs(path: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(path):
		return PackedStringArray()
	var dirs: PackedStringArray = DirAccess.get_directories_at(path)
	dirs.sort()
	return dirs


func list_files(path: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(path):
		return PackedStringArray()
	var files: PackedStringArray = DirAccess.get_files_at(path)
	files.sort()
	return files
