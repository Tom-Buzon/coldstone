extends SceneTree

const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldPlayScript = preload("res://scripts/world_editor/world_play.gd")

const TEST_PATH := "user://hoplite_worlds/__chapter_probe.hoplite.json"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var document := WorldDocumentScript.new(WorldDocumentScript.example_world()) as HopliteWorldDocument
	var motions := ["pivot_left", "pivot_right", "vertical", "slide_left", "slide_right"]
	for index in range(motions.size()):
		var door := HopliteWorldDocument.entity("door", "Porte probe %s" % motions[index], Vector3(30.0 + float(index) * 5.0, 2.0, 0.0), {
			"size": [3.0, 4.0, 0.45], "door_style": ["wood", "iron", "stone", "bronze"][index % 4],
			"open_motion": motions[index], "open_duration": 0.05, "starts_open": false
		})
		door["chapter"] = "agora"
		document.add_entity(door)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_PATH.get_base_dir()))
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if file == null:
		_fail("could not create temporary world")
		return
	file.store_string(document.to_json())
	file.close()
	set_meta("hoplite_world_path", TEST_PATH)
	# The player installs its camera on current_scene, exactly like the real loader.
	# Run the probe through a PackedScene instead of attaching WorldPlay below root.
	var play_source := WorldPlayScript.new() as HopliteWorldPlay
	var packed := PackedScene.new()
	if packed.pack(play_source) != OK:
		_fail("could not pack the WorldPlay probe scene")
		return
	if change_scene_to_packed(packed) != OK:
		_fail("could not start the WorldPlay probe scene")
		return
	await scene_changed
	play_source.free()
	var play := current_scene as HopliteWorldPlay
	if play == null:
		_fail("WorldPlay probe scene has the wrong root type")
		return
	for wait_index in range(12):
		await process_frame
		if play.runtime != null and not play.chapter_transitioning:
			break
	if play.runtime == null or play.current_chapter_id != "agora":
		_fail("start chapter did not load")
		return
	var agora_runtime := play.runtime
	var agora_world_root := agora_runtime.world_root
	var agora_camera := agora_runtime.player.camera_yaw
	var agora_sword_trail := agora_runtime.player.sword_trail
	for motion: String in motions:
		var door_entity := document.find_by_name("Porte probe %s" % motion)
		if door_entity.is_empty() or not agora_runtime.open_door(String(door_entity.get("id", ""))):
			_fail("door motion %s could not open" % motion)
			return
		var animated_holder := agora_runtime.nodes_by_id.get(String(door_entity.get("id", ""))) as Node3D
		var animated_tween := animated_holder.get_meta("door_tween") as Tween
		animated_tween.custom_step(1.0)
	for motion: String in motions:
		var door_entity := document.find_by_name("Porte probe %s" % motion)
		var holder := agora_runtime.nodes_by_id.get(String(door_entity.get("id", ""))) as Node3D
		var pivot := holder.get_meta("door_leaf_pivot") as Node3D
		var moved := absf(pivot.rotation.y) > 0.5 if motion.begins_with("pivot") else (absf(pivot.position.y) > 2.0 if motion == "vertical" else absf(pivot.position.x) > 2.0)
		if not bool(holder.get_meta("door_open", false)) or not moved:
			_fail("door motion %s did not reach its open transform" % motion)
			return
	var demo_gate := document.find_by_name("Porte nord de l'agora")
	var demo_trigger := document.find_by_name("Ouvrir la porte apres la garde")
	play.event_runtime.call("_fire", demo_trigger)
	var demo_holder := agora_runtime.nodes_by_id.get(String(demo_gate.get("id", ""))) as Node3D
	var demo_tween := demo_holder.get_meta("door_tween") as Tween
	if demo_tween != null:
		demo_tween.custom_step(2.0)
	if demo_holder == null or not bool(demo_holder.get_meta("door_open", false)):
		_fail("demo trigger did not open its selected door")
		return
	var crypt_portal := document.find_by_name("Descendre dans les cryptes")
	var crypt_portal_node := agora_runtime.nodes_by_id.get(String(crypt_portal.get("id", ""))) as Area3D
	if crypt_portal_node == null:
		_fail("the demo chapter portal was not built as an Area3D")
		return
	agora_runtime.player.global_position = crypt_portal_node.global_position
	for wait_index in range(20):
		await physics_frame
		await process_frame
		if play.current_chapter_id == "cryptes" and not play.chapter_transitioning:
			break
	if play.runtime == null or play.current_chapter_id != "cryptes":
		_fail("entering the portal did not load the destination chapter")
		return
	if is_instance_valid(agora_runtime) or is_instance_valid(agora_world_root):
		_fail("previous chapter runtime remained alive after transition")
		return
	if is_instance_valid(agora_camera) or is_instance_valid(agora_sword_trail):
		_fail("a top-level player helper leaked out of the previous chapter")
		return
	if play.runtime.nodes_by_id.has(String(demo_gate.get("id", ""))):
		_fail("an entity from the previous chapter leaked into the destination")
		return
	if play.runtime.player == null or absf(play.runtime.player.global_position.z - 10.0) > 1.0:
		_fail("player did not arrive at the selected chapter spawn")
		return
	var return_portal := document.find_by_name("Remonter vers l'agora")
	var return_portal_node := play.runtime.nodes_by_id.get(String(return_portal.get("id", ""))) as Area3D
	if return_portal_node == null:
		_fail("the return portal was not built")
		return
	play.runtime.player.global_position = return_portal_node.global_position
	for wait_index in range(20):
		await physics_frame
		await process_frame
		if play.current_chapter_id == "agora" and not play.chapter_transitioning:
			break
	if play.current_chapter_id != "agora" or play.runtime.player == null or absf(play.runtime.player.global_position.z - 12.0) > 1.0:
		_fail("return transition did not restore the selected arrival")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	play.runtime.clear_world()
	play.queue_free()
	await process_frame
	await process_frame
	packed = null
	document = null
	await process_frame
	print("WORLD_CHAPTER_PROBE_OK doors=5 cleanup=ok teleport=ok")
	quit(0)

func _fail(message: String) -> void:
	push_error("WORLD_CHAPTER_PROBE_FAILED %s" % message)
	quit(1)
