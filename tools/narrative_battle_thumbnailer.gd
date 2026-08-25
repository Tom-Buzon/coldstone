extends SceneTree

const NarrativeScene = preload("res://battle_03_narrative.tscn")
const OUTPUT_DIR := "res://docs/last_flame"

var mission: Node3D
var camera: Camera3D

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	call_deferred("_capture")

func _capture() -> void:
	change_scene_to_packed(NarrativeScene)
	await scene_changed
	mission = current_scene as Node3D
	await process_frame
	await process_frame
	for player_camera: Node in mission.find_children("*", "Camera3D", true, false):
		(player_camera as Camera3D).current = false
	camera = Camera3D.new()
	camera.fov = 54.0
	camera.current = true
	mission.add_child(camera)

	var shots := [
		{"name": "01_siege_approach", "position": Vector3(39.0, 20.0, 94.0), "target": Vector3(0.0, 2.2, 33.0)},
		{"name": "02_bronze_phalanx", "position": Vector3(11.0, 8.5, 37.0), "target": Vector3(0.0, 1.8, 5.0), "spawn_method": &"_spawn_zone_two"},
		{"name": "03_athenian_agora", "position": Vector3(37.0, 17.0, 34.0), "target": Vector3(0.0, 2.8, -10.0)},
		{"name": "04_theron_sanctuary", "position": Vector3(29.0, 13.5, -54.0), "target": Vector3(0.0, 2.3, -105.0), "spawn_method": &"_spawn_final_boss"}
	]
	for shot: Dictionary in shots:
		var spawn_method := StringName(shot.get("spawn_method", StringName()))
		if spawn_method != StringName():
			mission.call(spawn_method)
			await process_frame
			await process_frame
		camera.position = shot["position"]
		camera.look_at(shot["target"], Vector3.UP)
		await process_frame
		await process_frame
		await process_frame
		var viewport_texture := root.get_texture()
		if viewport_texture == null:
			push_error("[LAST FLAME CAPTURE] Viewport image unavailable with the active renderer")
			quit(2)
			return
		var image := viewport_texture.get_image()
		if image == null:
			push_error("[LAST FLAME CAPTURE] Renderer returned no viewport image")
			quit(2)
			return
		var output_path := "%s/%s.png" % [OUTPUT_DIR, String(shot["name"])]
		var error := image.save_png(ProjectSettings.globalize_path(output_path))
		print("[LAST FLAME CAPTURE] %s (%s)" % [output_path, error_string(error)])

	quit(0)
