extends SceneTree

const LabScene = preload("res://combat_lab.tscn")
const OUTPUT_PATH := "res://docs/world_editor/world_portals.png"

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	_capture.call_deferred()

func _capture() -> void:
	change_scene_to_packed(LabScene)
	await scene_changed
	await process_frame
	for raw: Node in current_scene.find_children("*", "Camera3D", true, false):
		(raw as Camera3D).current = false
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.position = Vector3(22.0, 8.5, -44.0)
	camera.look_at(Vector3(10.0, 1.8, -58.0), Vector3.UP)
	camera.fov = 58.0
	camera.current = true
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("WORLD_PORTAL_CAPTURE %s (%s)" % [OUTPUT_PATH, error_string(error)])
	quit(0 if error == OK else 2)
