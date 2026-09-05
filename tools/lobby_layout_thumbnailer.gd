extends SceneTree

const LOBBY_PATH := "user://hoplite_worlds/lobbyy.hoplite.json"
const LOBBY_SCENE := "res://lobby.tscn"
const OUTPUT_PATH := "res://docs/world_editor/lobby_layout.png"


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	set_meta("hoplite_world_path", LOBBY_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	_capture.call_deferred()


func _capture() -> void:
	var scene_error := change_scene_to_file(LOBBY_SCENE)
	if scene_error != OK:
		push_error("LOBBY_LAYOUT_CAPTURE_FAILED scene=%s" % error_string(scene_error))
		quit(2)
		return
	await scene_changed
	await process_frame
	await process_frame
	for raw: Node in current_scene.find_children("*", "Camera3D", true, false):
		(raw as Camera3D).current = false
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.position = Vector3(2.0, 72.0, 78.0)
	camera.look_at(Vector3(-4.0, 0.0, 8.0), Vector3.UP)
	camera.fov = 62.0
	camera.current = true
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("LOBBY_LAYOUT_CAPTURE %s (%s)" % [OUTPUT_PATH, error_string(error)])
	quit(0 if error == OK else 2)
