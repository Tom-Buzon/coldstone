extends SceneTree

const PORTAL_OUTPUT := "res://docs/enemy_refactor/hoplite_combat_lab_portal_probe.png"
const GALLERY_OUTPUT := "res://docs/enemy_refactor/hoplite_combat_lab_gallery_probe.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1000, 700)
	var packed := load("res://combat_lab.tscn") as PackedScene
	if packed == null or change_scene_to_packed(packed) != OK:
		push_error("HOPLITE_COMBAT_LAB_VISUAL_PROBE could not open combat_lab")
		quit(1)
		return
	await process_frame
	var portal_hoplites: Array[Node3D] = []
	var gallery_hoplites: Array[Node3D] = []
	for _frame: int in range(45):
		await process_frame
		await physics_frame
		portal_hoplites.clear()
		gallery_hoplites.clear()
		for node: Node in get_nodes_in_group("phalanx_unit"):
			if not node is Node3D or not StringName(node.get("archetype_id")) in [&"ngeneral", &"ngeneral_veteran"]:
				continue
			var formation_group := StringName(node.get_meta("formation_group", StringName()))
			if formation_group == &"portal_phalanx_patrol":
				portal_hoplites.append(node as Node3D)
			elif formation_group == &"legion_ngeneral":
				gallery_hoplites.append(node as Node3D)
		if portal_hoplites.size() >= 15 and gallery_hoplites.size() >= 7:
			break
	if portal_hoplites.is_empty() or gallery_hoplites.is_empty():
		push_error("HOPLITE_COMBAT_LAB_VISUAL_PROBE missing portal or gallery hoplites")
		quit(1)
		return
	var portal_before := _capture_pose(portal_hoplites[0].get("skeleton") as Skeleton3D)
	var gallery_before := _capture_pose(gallery_hoplites[0].get("skeleton") as Skeleton3D)
	for _frame: int in range(12):
		await process_frame
		await physics_frame
	var portal_motion := _maximum_pose_delta(portal_hoplites[0].get("skeleton") as Skeleton3D, portal_before)
	var gallery_motion := _maximum_pose_delta(gallery_hoplites[0].get("skeleton") as Skeleton3D, gallery_before)
	print("HOPLITE_COMBAT_LAB_TIMELINE portal=", portal_motion, " gallery=", gallery_motion)
	if portal_motion <= 0.002 or gallery_motion <= 0.002:
		push_error("HOPLITE_COMBAT_LAB_VISUAL_PROBE found a frozen hoplite group")
		quit(1)
		return
	var scene := current_scene
	var camera := Camera3D.new()
	scene.add_child(camera)
	await _capture_group(portal_hoplites, camera, PORTAL_OUTPUT)
	await _capture_group(gallery_hoplites, camera, GALLERY_OUTPUT)
	print("HOPLITE_COMBAT_LAB_VISUAL_PROBE saved portal=", PORTAL_OUTPUT, " gallery=", GALLERY_OUTPUT)
	quit(0)

func _capture_group(hoplites: Array[Node3D], camera: Camera3D, output_path: String) -> void:
	var centre := Vector3.ZERO
	for hoplite: Node3D in hoplites:
		centre += hoplite.global_position
	centre /= float(hoplites.size())
	camera.global_position = centre + Vector3(0.0, 3.0, 9.0)
	camera.look_at(centre + Vector3.UP * 1.0, Vector3.UP)
	camera.current = true
	for _frame: int in range(3):
		await process_frame
		await physics_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		push_error("HOPLITE_COMBAT_LAB_VISUAL_PROBE could not save screenshot: %s" % error_string(error))

func _capture_pose(skeleton: Skeleton3D) -> Array[Quaternion]:
	var pose: Array[Quaternion] = []
	if skeleton == null:
		return pose
	for bone_index: int in range(skeleton.get_bone_count()):
		pose.append(skeleton.get_bone_pose_rotation(bone_index))
	return pose

func _maximum_pose_delta(skeleton: Skeleton3D, before: Array[Quaternion]) -> float:
	if skeleton == null:
		return 0.0
	var maximum := 0.0
	for bone_index: int in range(mini(skeleton.get_bone_count(), before.size())):
		maximum = maxf(maximum, before[bone_index].angle_to(skeleton.get_bone_pose_rotation(bone_index)))
	return maximum
