extends SceneTree

const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")
const OUTPUT := "res://docs/enemy_refactor/forge_hoplite_animation_probe.png"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	root.size = Vector2i(1000, 700)
	var data := WorldDocumentScript.create_default()
	var spawn := WorldDocumentScript.entity("player_spawn", "Probe Spawn", Vector3(0.0, 0.05, 8.0), {"spawn_id": "probe"})
	spawn["chapter"] = "chapter_1"
	var floor := WorldDocumentScript.entity("surface", "Probe Floor", Vector3(0.0, -0.10, 0.0), {"shape": "floor", "size": [30.0, 0.2, 30.0], "material": "pavers"})
	floor["chapter"] = "chapter_1"
	var solo := WorldDocumentScript.entity("enemy_group", "Solo Hoplite", Vector3(-4.0, 0.05, 0.0), {
		"group_id": "forge_probe_solo", "archetype": "ngeneral", "count": 1,
		"rank": "normal", "formation": "line", "spawn_condition": "start", "deployment_mode": "all"
	})
	solo["chapter"] = "chapter_1"
	var phalanx := WorldDocumentScript.entity("enemy_group", "Probe Phalanx", Vector3(3.0, 0.05, 0.0), {
		"group_id": "forge_probe_phalanx", "archetype": "ngeneral", "count": 5,
		"composition": [{"archetype": "ngeneral", "count": 4}, {"archetype": "ngeneral_veteran", "count": 1}],
		"rank": "normal", "formation": "phalanx", "spawn_condition": "start", "deployment_mode": "all"
	})
	phalanx["chapter"] = "chapter_1"
	data["entities"] = [spawn, floor, solo, phalanx]
	var document := WorldDocumentScript.new(data) as HopliteWorldDocument
	var runtime := WorldRuntimeScript.new() as HopliteWorldRuntime
	runtime.name = "ForgeRuntimeProbe"
	root.add_child(runtime)
	current_scene = runtime
	runtime.build(document, false)
	runtime.player.set_physics_process(false)
	runtime.player.set_process(false)
	for _frame: int in range(30):
		await process_frame
		await physics_frame
	var solo_units := runtime.enemies_by_group.get("forge_probe_solo", []) as Array
	var phalanx_units := runtime.enemies_by_group.get("forge_probe_phalanx", []) as Array
	if solo_units.is_empty() or phalanx_units.is_empty():
		push_error("FORGE_HOPLITE_ANIMATION_PROBE spawn failed")
		quit(1)
		return
	var units: Array[Node] = [solo_units[0], phalanx_units[0]]
	var poses: Array[Array] = []
	for unit: Node in units:
		var skeleton := unit.get("skeleton") as Skeleton3D
		var driver: Node = unit.get("ai_animation_driver") as Node
		var tree := driver.get("animation_tree") as AnimationTree if driver != null else null
		var player := unit.get("animation_player") as AnimationPlayer
		var resolved_player := tree.get_node_or_null(tree.anim_player) if tree != null else null
		print("FORGE_HOPLITE_STATE name=", unit.name, " process_mode=", unit.process_mode, " tree_active=", tree.active if tree != null else false, " player_linked=", resolved_player == player, " pose_angle=", _maximum_pose_angle(skeleton))
		_expect(tree != null and tree.active, "%s has no active AnimationTree" % unit.name)
		_expect(resolved_player == player, "%s AnimationTree points at the wrong AnimationPlayer" % unit.name)
		poses.append(_capture_pose(skeleton))
	for _frame: int in range(12):
		await process_frame
		await physics_frame
	for index: int in range(units.size()):
		var skeleton := units[index].get("skeleton") as Skeleton3D
		var motion := _maximum_pose_delta(skeleton, poses[index])
		print("FORGE_HOPLITE_TIMELINE name=", units[index].name, " motion=", motion)
		_expect(motion > 0.002, "%s skeleton timeline is frozen" % units[index].name)
	# Capture the Forge evidence during the same shared spear action used by a
	# regular fighter and a formation member/sortie striker.
	for unit: Node in units:
		unit.set_physics_process(false)
		var driver := unit.get("ai_animation_driver") as Node
		var started := bool(driver.call("play_external_attack", &"spear_thrust", &"forge_probe", &"forge_probe"))
		driver.call("_set_action_blend", 1.0)
		(driver.get("animation_tree") as AnimationTree).advance(0.55)
		var tree_root := (driver.get("animation_tree") as AnimationTree).tree_root as AnimationNodeBlendTree
		_expect(started, "%s did not activate the baked Blender/UAL2 spear action" % unit.name)
		_expect(tree_root != null and not tree_root.has_node(&"LancerRightArm"), "%s still evaluates a permanent lancer arm layer" % unit.name)
	var camera := Camera3D.new()
	runtime.add_child(camera)
	camera.global_position = Vector3(0.0, 3.0, 11.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.current = true
	if DisplayServer.get_name() != "headless":
		for _frame: int in range(3):
			await process_frame
			await physics_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var save_error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
		_expect(save_error == OK, "could not save Forge screenshot")
	else:
		print("FORGE_HOPLITE_ANIMATION_PROBE headless pose validation complete; screenshot skipped")
	if failures.is_empty():
		print("FORGE_HOPLITE_ANIMATION_PROBE PASS output=", OUTPUT)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _capture_pose(skeleton: Skeleton3D) -> Array[Quaternion]:
	var pose: Array[Quaternion] = []
	for bone_index: int in range(skeleton.get_bone_count()):
		pose.append(skeleton.get_bone_pose_rotation(bone_index))
	return pose

func _maximum_pose_delta(skeleton: Skeleton3D, before: Array) -> float:
	var maximum := 0.0
	for bone_index: int in range(mini(skeleton.get_bone_count(), before.size())):
		maximum = maxf(maximum, (before[bone_index] as Quaternion).angle_to(skeleton.get_bone_pose_rotation(bone_index)))
	return maximum

func _maximum_pose_angle(skeleton: Skeleton3D) -> float:
	var maximum := 0.0
	for bone_index: int in range(skeleton.get_bone_count()):
		maximum = maxf(maximum, skeleton.get_bone_pose_rotation(bone_index).get_angle())
	return maximum

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
