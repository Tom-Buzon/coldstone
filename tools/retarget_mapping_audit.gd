extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	world.name = "RetargetMappingAuditWorld"
	get_root().add_child(world)
	current_scene = world
	var player := PlayerScript.new() as HopliteUALNativePlayer
	world.add_child(player)
	for _frame: int in range(4):
		await physics_frame
		await process_frame
	if player.animation_driver == null or player.animation_driver.external_bank == null:
		push_error("[RETARGET MAPPING AUDIT] external bank unavailable")
		quit(1)
		return
	var bank: HopliteExternalAnimationBank = player.animation_driver.external_bank
	var donor: Dictionary = bank.donors.get(&"light1", {})
	var source: Skeleton3D = donor.get("proxy", donor.get("skeleton")) as Skeleton3D
	var bridge: HopliteAuthoredPoseBridge = donor.get("bridge") as HopliteAuthoredPoseBridge
	var target: Skeleton3D = player.skeleton
	if source == null or target == null or bridge == null:
		push_error("[RETARGET MAPPING AUDIT] skeleton/bridge unavailable")
		quit(1)
		return

	var failures: int = 0
	var seen_roles: Dictionary = {}
	print("[RETARGET MAPPING AUDIT] source_bones=", source.get_bone_count(), " target_bones=", target.get_bone_count(), " pairs=", bridge.bone_pairs.size())
	for index: int in range(bridge.bone_pairs.size()):
		var pair: Vector2i = bridge.bone_pairs[index]
		var role: String = bridge.pair_roles[index]
		var source_name: String = source.get_bone_name(pair.y)
		var target_name: String = target.get_bone_name(pair.x)
		var source_parent: int = source.get_bone_parent(pair.y)
		var target_parent: int = target.get_bone_parent(pair.x)
		var source_parent_name: String = source.get_bone_name(source_parent) if source_parent >= 0 else "<none>"
		var target_parent_name: String = target.get_bone_name(target_parent) if target_parent >= 0 else "<none>"
		var source_side: String = _side(source_name)
		var target_side: String = _side(target_name)
		var side_ok: bool = source_side == "" or target_side == "" or source_side == target_side
		if role != "" and source_side != "":
			seen_roles[role + ":" + source_side] = true
		if not side_ok:
			failures += 1
		print("[RETARGET PAIR] role=", role, " source=", source_name, " parent=", source_parent_name, " -> target=", target_name, " parent=", target_parent_name, " side_ok=", side_ok)

	for required: String in ["upper_arm:l", "upper_arm:r", "forearm:l", "forearm:r", "hand:l", "hand:r", "thigh:l", "thigh:r", "shin:l", "shin:r", "foot:l", "foot:r"]:
		if not seen_roles.has(required):
			push_error("[RETARGET MAPPING AUDIT] missing semantic pair " + required)
			failures += 1
	print("[RETARGET MAPPING AUDIT] failures=", failures)
	world.free()
	quit(1 if failures > 0 else 0)

func _side(raw: String) -> String:
	var lower: String = raw.to_lower()
	if "left" in lower or lower.ends_with(".l") or lower.ends_with("_l") or lower.ends_with("-l"):
		return "l"
	if "right" in lower or lower.ends_with(".r") or lower.ends_with("_r") or lower.ends_with("-r"):
		return "r"
	return ""
