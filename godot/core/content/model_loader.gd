class_name ModelLoader
extends RefCounted
## Loads 3D models (`.glb`) for content.
##
## - `res://` models imported by the editor: `load()` (LODs, compression, fast).
## - Anything else (`user://mods`, `--content-dir`, absolute paths, or a `res://`
##   file that was not imported): `GLTFDocument` at runtime — this is what lets
##   the exported Studio and mods use models without the editor.
##
## Loaded models are cached per path as [PackedScene]; every call returns a new copy.

const LOG_CONTEXT: String = "ModelLoader"

static var _cache: Dictionary = {}


## A new instance of the model at [param path], or null (with a log message) on failure.
static func load_model(path: String) -> Node3D:
	var packed: PackedScene = load_packed(path)
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	if instance is Node3D:
		return instance
	# A glTF root that is not 3D (rare): wrap it so callers always get a Node3D.
	var wrapper: Node3D = Node3D.new()
	wrapper.name = instance.name
	wrapper.add_child(instance)
	return wrapper


## The cached [PackedScene] for [param path] (loading it on first use).
static func load_packed(path: String) -> PackedScene:
	if _cache.has(path):
		return _cache[path]
	var packed: PackedScene = null
	if is_imported(path):
		packed = load(path) as PackedScene
	elif FileAccess.file_exists(path):
		packed = _load_gltf(path)
	else:
		Log.error("Model not found: %s" % path, LOG_CONTEXT)
		return null
	if packed == null:
		Log.error("Could not load model: %s" % path, LOG_CONTEXT)
		return null
	_cache[path] = packed
	return packed


## True when [param path] is a model imported by the editor (loaded with `load()`).
static func is_imported(path: String) -> bool:
	return path.begins_with("res://") and ResourceLoader.exists(path, "PackedScene")


## Forgets cached models (all, or only [param path]); the Studio calls this after re-exporting.
static func clear_cache(path: String = "") -> void:
	if path.is_empty():
		_cache.clear()
	else:
		_cache.erase(path)


static func is_cached(path: String) -> bool:
	return _cache.has(path)


static func _load_gltf(path: String) -> PackedScene:
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	# Keep textures in memory instead of extracting them to files.
	state.handle_binary_image_mode = GLTFState.HANDLE_BINARY_IMAGE_MODE_EMBED_AS_UNCOMPRESSED
	var error: Error = document.append_from_file(path, state, 0, path.get_base_dir())
	if error != OK:
		Log.error("glTF error %s in %s" % [error_string(error), path], LOG_CONTEXT)
		return null
	var root: Node = document.generate_scene(state)
	if root == null:
		return null
	_set_owner_recursive(root, root)
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(root)
	root.free()
	return packed if pack_error == OK else null


static func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)
