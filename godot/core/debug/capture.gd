class_name Capture
extends Node
## Debug tool: loads a scene, waits N frames, saves the viewport as PNG and quits.
##
## Used by `tools/scripts/screenshot.sh` so the code agent can check visuals.
## User arguments (after `--`):
##   --capture-scene=res://path/to/scene.tscn   scene to show (required)
##   --capture-out=/absolute/path/out.png       output file (required)
##   --capture-frames=30                        frames to wait before capturing

const ARG_SCENE: String = "--capture-scene"
const ARG_OUT: String = "--capture-out"
const ARG_FRAMES: String = "--capture-frames"
const DEFAULT_FRAMES: int = 30
const LOG_CONTEXT: String = "Capture"


func _ready() -> void:
	# Deferred: the tree is still adding this node, so children can't be added yet.
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = CmdlineArgs.get_value(args, ARG_SCENE)
	var out_path: String = CmdlineArgs.get_value(args, ARG_OUT)
	var frames: int = maxi(1, int(CmdlineArgs.get_value(args, ARG_FRAMES, str(DEFAULT_FRAMES))))

	if scene_path.is_empty() or out_path.is_empty():
		_fail(
			"Usage: -- %s=<res://scene.tscn> %s=<out.png> [%s=N]" % [ARG_SCENE, ARG_OUT, ARG_FRAMES]
		)
		return
	if DisplayServer.get_name() == "headless":
		_fail("Cannot capture with the headless display driver (nothing is rendered).")
		return

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		_fail("Could not load scene: %s" % scene_path)
		return
	add_child(packed.instantiate())

	for i: int in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("The viewport returned an empty image.")
		return
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var save_error: Error = image.save_png(out_path)
	if save_error != OK:
		_fail("Could not save %s (%s)" % [out_path, error_string(save_error)])
		return

	Log.info(
		"Saved %dx%d capture to %s" % [image.get_width(), image.get_height(), out_path], LOG_CONTEXT
	)
	get_tree().quit(0)


func _fail(message: String) -> void:
	Log.error(message, LOG_CONTEXT)
	get_tree().quit(1)
