extends SceneTree

const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const HitEventScript = preload("res://scripts/combat/hit_event.gd")
const PackageScript = preload("res://scripts/enemy_v2/hoplite_v2_package.gd")

class PassiveTarget extends Node3D:
	func receive_enemy_hit(_damage: float, _attacker: Node = null, _direction: Vector3 = Vector3.ZERO) -> bool:
		return true


var failures: Array[String] = []
var severed_signals: Array[StringName] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(12.0, 0.2, 12.0)
	collision.shape = floor_shape
	collision.position.y = -0.1
	floor.add_child(collision)
	world.add_child(floor)
	var target := PassiveTarget.new()
	target.position = Vector3(0.0, 0.0, -8.0)
	world.add_child(target)
	var actor := Factory.create(&"ngeneral") as HopliteEnemyActorV2
	actor.combat_lab_enabled = true
	actor.combat_target = target
	actor.lod_reference = target
	actor.zone_severed.connect(func(_enemy: Node, zone: StringName) -> void: severed_signals.append(zone))
	world.add_child(actor)
	for _frame: int in range(3):
		await physics_frame
	_expect(actor.dismemberment != null, "combat V2 actor has no dismemberment component")

	var skeleton := actor.presentation.skeleton
	var forearm_index := skeleton.find_bone("DEF-forearm.R")
	var forearm_cut := (skeleton.global_transform * skeleton.get_bone_global_pose(forearm_index)).origin
	var arm_hit := HitEventScript.new()
	arm_hit.source = target
	arm_hit.damage = 1.0
	arm_hit.sever_damage = 70.0
	# Keep the generic attack direction deliberately different: debris must use
	# the blade contact impulse, which is the actual impact direction at runtime.
	arm_hit.direction = Vector3.LEFT
	arm_hit.impulse = Vector3(0.65, 0.08, 1.0) * 3.0
	arm_hit.position = forearm_cut
	actor.receive_anatomy_hit(arm_hit, &"forearm_r")
	var arm_fragment := actor.dismemberment.last_fragment as HopliteV2Fragment
	_expect(actor.health_component.is_zone_severed(&"forearm_r"), "forearm sever threshold did not persist")
	_expect(actor.dismemberment.is_severed(&"forearm_r"), "dismemberment did not accept the forearm")
	_expect(severed_signals.has(&"forearm_r"), "actor did not expose the common zone_severed signal")
	_expect(arm_fragment != null and arm_fragment.zone == &"forearm_r", "real 3DGen forearm fragment was not spawned")
	_expect(skeleton.get_bone_pose_scale(forearm_index).length() < 0.01, "body forearm remained visible after sever")
	_expect(bool((actor.health_component.anatomy.zone_runtime[&"forearm_r"] as Dictionary).get("disabled", false)), "severed forearm hitbox stayed active")
	_expect(not _has_visible_geometry(actor.equipment.weapon_attachment), "right-arm sever did not remove the carried spear")
	if arm_fragment != null:
		var definition := PackageScript.load_default().fragment_definition(&"forearm_r")
		var pivot := _source_vector_to_godot((definition.get("pivot", {}) as Dictionary).get("position", []))
		var placed_cut := arm_fragment.global_transform * arm_fragment.centered_point(pivot)
		_expect(placed_cut.distance_to(forearm_cut) < 0.04, "forearm fragment pivot is not aligned to the animated cut")
		_expect(arm_fragment.physics_material_override != null and arm_fragment.physics_material_override.bounce == 0.0, "fragment collider still permits rebounds")
		_expect(arm_fragment.linear_damp >= 4.0 and arm_fragment.angular_damp >= 7.0, "fragment damping is too weak to stabilize")
		_expect(arm_fragment.collision_shape != null and arm_fragment.collision_shape.position.is_zero_approx(), "fragment collider is not centred on its rigid body")
		await physics_frame
		var expected_direction := arm_hit.impulse.normalized()
		var actual_direction := arm_fragment.linear_velocity.normalized()
		_expect(actual_direction.dot(expected_direction) > 0.94, "fragment projection does not follow the blade impact direction")
	# A severed part gets one projection, lands, then explicitly enters a sleeping
	# state instead of spending its whole lifetime micro-bouncing on the terrain.
	for _frame: int in range(190):
		await physics_frame
	if arm_fragment != null and is_instance_valid(arm_fragment):
		_expect(arm_fragment.settled or arm_fragment.sleeping, "projected forearm did not settle on the floor")
		var lowest_visual_y := arm_fragment.estimate_lowest_collision_y()
		_expect(arm_fragment.estimate_lowest_visual_y() <= 0.25, "settled fragment mesh remained visibly suspended above the floor")
		_expect(
			lowest_visual_y >= -0.08 and lowest_visual_y <= 0.10,
			"settled fragment collider is not resting on the floor (lowest y=%.3f, body y=%.3f)" % [lowest_visual_y, arm_fragment.global_position.y]
		)
		var settled_position := arm_fragment.global_position
		for _frame: int in range(20):
			await physics_frame
		_expect(arm_fragment.global_position.distance_to(settled_position) < 0.015, "sleeping fragment continued sliding across the floor")
	await process_frame

	# The bone mask must survive subsequent animation sampling.
	actor.play_semantic_animation(&"move", 0.0)
	for _frame: int in range(20):
		await physics_frame
	_expect(skeleton.get_bone_pose_scale(forearm_index).length() < 0.01, "animation restored a severed body branch")

	var head_index := skeleton.find_bone("DEF-head")
	var head_cut := (skeleton.global_transform * skeleton.get_bone_global_pose(head_index)).origin
	var head_hit := HitEventScript.new()
	head_hit.source = target
	head_hit.damage = 0.0
	head_hit.sever_damage = 70.0
	head_hit.direction = Vector3(0.2, 0.5, 1.0).normalized()
	head_hit.position = head_cut
	actor.receive_anatomy_hit(head_hit, &"head")
	await process_frame
	var head_fragment := actor.dismemberment.last_fragment as HopliteV2Fragment
	_expect(head_fragment != null and head_fragment.zone == &"head", "real 3DGen head fragment was not spawned")
	_expect(actor.dead, "fatal head sever did not enter the ordinary death path")
	_expect(skeleton.get_bone_pose_scale(head_index).length() < 0.01, "body head remained visible after sever")
	_expect(get_nodes_in_group(&"enemy_v2_fragment").size() == 2, "fragment count is not exactly one per severed zone")
	var dropped_shield := world.find_child("DroppedHopliteV2Shield", true, false) as RigidBody3D
	_expect(dropped_shield != null, "death left the shield anchored vertically to the actor")
	if dropped_shield != null:
		var shield_start_y := dropped_shield.global_position.y
		for _frame: int in range(120):
			await physics_frame
		_expect(dropped_shield.global_position.y < shield_start_y - 0.05 or dropped_shield.sleeping, "detached shield did not fall toward the floor")
		_expect(absf(dropped_shield.global_basis.z.normalized().dot(Vector3.UP)) >= 0.82, "detached shield remained balanced vertically instead of falling flat")
		dropped_shield.queue_free()
		await process_frame
		# Regression: actor LOD updates must not write cast_shadow on the freed
		# shield mesh retained by an obsolete equipment geometry cache.
		actor.equipment.set_shadows_enabled(false)
	actor.free()
	target.free()
	world.free()
	if failures.is_empty():
		print("HOPLITE_V2_DISMEMBERMENT_PROBE PASS forearm=fragment+mask+equipment+settled head=fragment+fatal fragments=2 bounce=0")
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 DISMEMBERMENT] " + failure)
	quit(1)


func _has_visible_geometry(node: Node) -> bool:
	if node is GeometryInstance3D and (node as GeometryInstance3D).visible:
		return true
	for child: Node in node.get_children():
		if _has_visible_geometry(child):
			return true
	return false


func _source_vector_to_godot(raw: Variant) -> Vector3:
	var values := raw as Array
	return Vector3(float(values[0]), float(values[2]), -float(values[1]))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
