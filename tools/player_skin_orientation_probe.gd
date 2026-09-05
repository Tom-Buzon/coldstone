extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var world := Node3D.new()
	world.name = "PlayerSkinOrientationProbe"
	root.add_child(world)
	current_scene = world
	var player := PlayerScript.new() as HopliteUALNativePlayer
	world.add_child(player)
	for _frame: int in range(4):
		await process_frame
		await physics_frame
	for skin_id: StringName in [
		HopliteUALNativePlayer.PLAYER_SKIN_BASE,
		HopliteUALNativePlayer.PLAYER_SKIN_NOON,
		HopliteUALNativePlayer.PLAYER_SKIN_SAMUS,
	]:
		assert(player.set_player_skin(skin_id), "Could not load skin %s" % String(skin_id))
		for _frame: int in range(3):
			await process_frame
		print("\n[SKIN ORIENTATION] ", skin_id)
		_print_scene_nodes(player.mannequin_scene, player.mannequin_scene)
		_print_rest(player.skeleton)
		if player.skeleton.find_bone("root") < 0:
			var names: Array[String] = []
			for bone_index: int in range(player.skeleton.get_bone_count()):
				names.append(player.skeleton.get_bone_name(bone_index))
			print("[SKIN BONES WITHOUT ROOT] ", names)
		_print_skin_bindings(player.mannequin_scene, player.skeleton)
		_print_pose("idle", player.skeleton)
		player.animation_driver.play_wall_run_visual(&"horizontal", false)
		for _frame: int in range(8):
			await process_frame
		_print_pose("wall_horizontal", player.skeleton)
		player.animation_driver.stop_wall_run_visual()
		player.animation_driver.play_wall_run_visual(&"diagonal", false)
		for _frame: int in range(8):
			await process_frame
		_print_pose("wall_diagonal", player.skeleton)
		player.animation_driver.stop_wall_run_visual()
		var spin_started := player.animation_driver.play_external_attack(&"spin_low", &"spin360", &"idle", true, 1.0, 0.0, 1.0)
		print("[SKIN ORIENTATION] spin_started=", spin_started)
		for _frame: int in range(8):
			await process_frame
		_print_pose("spin_low", player.skeleton)
		_sample_donor(player.animation_driver.wall_movement_bank, &"wall_run", player.skeleton)
		_sample_donor(player.animation_driver.wall_movement_bank, &"wall_run_diagonal", player.skeleton)
		_sample_donor(player.animation_driver.external_bank, &"spin_low", player.skeleton)
	player.queue_free()
	await process_frame
	quit(0)

func _print_scene_nodes(node: Node, root_node: Node) -> void:
	if node is Node3D:
		var spatial := node as Node3D
		if node is Skeleton3D or node is MeshInstance3D or spatial.transform != Transform3D.IDENTITY:
			print("[SKIN NODE] path=", root_node.get_path_to(node), " type=", node.get_class(), " visible=", spatial.visible, " pos=", spatial.position, " rot_deg=", spatial.rotation_degrees, " scale=", spatial.scale)
	for child: Node in node.get_children():
		_print_scene_nodes(child, root_node)

func _print_rest(skeleton: Skeleton3D) -> void:
	for bone_name: String in ["root", "DEF-hips", "DEF-spine", "DEF-spine.001", "DEF-spine.002", "DEF-head", "DEF-foot.L", "DEF-toe.L"]:
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			continue
		var rest := skeleton.get_bone_rest(index)
		var global_rest := skeleton.get_bone_global_rest(index)
		print("[SKIN REST] bone=", bone_name, " local_rot_deg=", rest.basis.get_euler() * 180.0 / PI, " global_origin=", global_rest.origin, " global_rot_deg=", global_rest.basis.get_euler() * 180.0 / PI)

func _print_skin_bindings(node: Node, skeleton: Skeleton3D) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var skin := mesh_instance.skin
		if skin != null:
			var max_origin_error := 0.0
			var max_angle_error := 0.0
			var unresolved := 0
			for bind_index: int in range(skin.get_bind_count()):
				var bone_index := skin.get_bind_bone(bind_index)
				var bind_name := String(skin.get_bind_name(bind_index))
				if bone_index < 0 and bind_name != "":
					bone_index = skeleton.find_bone(bind_name)
				if bone_index < 0 or bone_index >= skeleton.get_bone_count():
					unresolved += 1
					continue
				var expected := skeleton.get_bone_global_rest(bone_index).affine_inverse()
				var actual := skin.get_bind_pose(bind_index)
				max_origin_error = maxf(max_origin_error, expected.origin.distance_to(actual.origin))
				max_angle_error = maxf(max_angle_error, expected.basis.get_rotation_quaternion().angle_to(actual.basis.get_rotation_quaternion()))
			print("[SKIN BINDS] mesh=", mesh_instance.name, " skeleton=", mesh_instance.skeleton, " binds=", skin.get_bind_count(), " unresolved=", unresolved, " max_origin_error=", max_origin_error, " max_angle_error_deg=", rad_to_deg(max_angle_error))
	for child: Node in node.get_children():
		_print_skin_bindings(child, skeleton)

func _print_pose(label: String, skeleton: Skeleton3D) -> void:
	skeleton.force_update_all_bone_transforms()
	var head := _bone_origin(skeleton, "DEF-head")
	var hips := _bone_origin(skeleton, "DEF-hips")
	var left_foot := _bone_origin(skeleton, "DEF-foot.L")
	var right_foot := _bone_origin(skeleton, "DEF-foot.R")
	var feet := (left_foot + right_foot) * 0.5
	var body_axis := head - feet
	var torso_axis := head - hips
	print("[SKIN POSE] label=", label, " body=", body_axis, " body_up=", body_axis.normalized().dot(Vector3.UP), " torso_up=", torso_axis.normalized().dot(Vector3.UP), " height=", body_axis.y)

func _sample_donor(bank: Node, key: StringName, skeleton: Skeleton3D) -> void:
	if bank == null or not bank.donors.has(key):
		return
	var donor: Dictionary = bank.donors[key]
	var donor_player := donor.get("player") as AnimationPlayer
	var source := donor.get("skeleton") as Skeleton3D
	var bridge := donor.get("bridge") as HopliteAuthoredPoseBridge
	var clip := StringName(donor.get("clip", StringName()))
	var animation := donor_player.get_animation(clip) if donor_player != null else null
	if donor_player == null or source == null or bridge == null or animation == null:
		return
	for fraction: float in [0.25, 0.50, 0.75]:
		donor_player.play(clip)
		donor_player.advance(0.0)
		donor_player.seek(animation.length * fraction, true)
		donor_player.pause()
		source.advance(0.0)
		bridge.set_attack_weight(1.0, true, 1.0)
		bridge.call("_process_modification_with_delta", 0.0)
		_print_pose("direct_%s_%.2f" % [String(key), fraction], skeleton)
		assert(_body_up(skeleton) > 0.75, "%s retargeted %s horizontally (body_up=%.3f)" % [skeleton.name, String(key), _body_up(skeleton)])
	bridge.set_attack_weight(0.0, false, 0.0)
	donor_player.stop()

func _bone_origin(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	var index := skeleton.find_bone(bone_name)
	return skeleton.get_bone_global_pose(index).origin if index >= 0 else Vector3.ZERO

func _body_up(skeleton: Skeleton3D) -> float:
	var head := _bone_origin(skeleton, "DEF-head")
	var feet := (_bone_origin(skeleton, "DEF-foot.L") + _bone_origin(skeleton, "DEF-foot.R")) * 0.5
	return (head - feet).normalized().dot(Vector3.UP)
