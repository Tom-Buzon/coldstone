extends SceneTree

const BattleLayoutRuntime = preload("res://scripts/enemy_v2/enemy_v2_battle_layout_runtime.gd")
const FocusTracker = preload("res://scripts/enemy_v2/enemy_v2_tactical_focus_tracker.gd")
const PhalanxProfile = preload("res://scripts/enemy_v2/hoplite_v2_phalanx_profile.gd")
const TroopRuntime = preload("res://scripts/enemy_v2/hoplite_v2_troop_runtime.gd")
const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var target := Node3D.new()
	world.add_child(target)
	_test_focus_handoff(target)
	_test_contact_facing_and_anchor_exclusion(target)
	_test_breach_width(world)
	await _test_formation_attack_alignment(world)
	world.free()
	if failures.is_empty():
		print("HOPLITE_V2_TACTICAL_STABILITY_PROBE PASS focus=responsive facing=threat anchor=exclusive breach=wide")
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 TACTICAL STABILITY] " + failure)
	quit(1)


func _test_focus_handoff(target: Node3D) -> void:
	var tracker: RefCounted = FocusTracker.new()
	target.global_position = Vector3.ZERO
	tracker.call("register_target", target)
	target.global_position = Vector3(0.0, 0.0, 7.0)
	var early: Vector3 = tracker.call("update_target", target, 100) as Vector3
	var settled: Vector3 = tracker.call("update_target", target, 600) as Vector3
	_expect(_planar_distance(early, Vector3.ZERO) < 0.1, "tactical focus moved without dwell")
	_expect(_planar_distance(settled, target.global_position) < 0.1, "tactical focus ignored a stable seven-metre relocation")


func _test_contact_facing_and_anchor_exclusion(target: Node3D) -> void:
	var layout: RefCounted = BattleLayoutRuntime.new()
	target.global_position = Vector3.ZERO
	var anchors: Array[Vector3] = [
		Vector3(6.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 6.0),
		Vector3(-6.0, 0.0, 0.0),
		Vector3(0.0, 0.0, -6.0),
	]
	for index: int in range(anchors.size()):
		layout.call("register_group", StringName("front_%d" % index), target, anchors[index], {}, &"hoplite_phalanx", 24)
	for index: int in range(anchors.size()):
		layout.call("assignment", StringName("front_%d" % index))
	# Move behind the north line while it is locally engaged. Its tactical slot
	# may stay stable, but its facing must immediately acknowledge the threat.
	var north_id := &"front_1"
	var initial_order: Dictionary = layout.call("assignment", north_id) as Dictionary
	var initial_facing := initial_order.get("facing", Vector3(0.0, 0.0, -1.0)) as Vector3
	target.global_position = anchors[1] - initial_facing.normalized() * 3.0
	layout.call("update_group", north_id, anchors[1], 24, 1.0, true, false, initial_facing)
	var north_order: Dictionary = layout.call("assignment", north_id) as Dictionary
	var wanted := _planar_direction(anchors[1], target.global_position, Vector3.FORWARD)
	var facing := north_order.get("facing", Vector3.ZERO) as Vector3
	_expect(facing.dot(wanted) >= 0.75, "an engaged contact formation kept its back toward the real target")

	_expect(layout.has_method("constrain_anchor_step"), "battle layout has no execution-time anchor exclusion")
	if layout.has_method("constrain_anchor_step"):
		var proposed := anchors[0]
		var constrained: Vector3 = layout.call("constrain_anchor_step", north_id, anchors[1], proposed) as Vector3
		_expect(_planar_distance(constrained, proposed) > 0.5, "two phalanx anchors were allowed to converge on the same position")
		layout.call("update_group", &"front_0", proposed, 24, 1.0, true, false, Vector3.FORWARD)
		layout.call("update_group", north_id, proposed, 24, 1.0, true, false, Vector3.FORWARD)
		var separated_a: Vector3 = layout.call("resolve_anchor_overlap", &"front_0", proposed, 1.0) as Vector3
		var separated_b: Vector3 = layout.call("resolve_anchor_overlap", north_id, proposed, 1.0) as Vector3
		_expect(_planar_distance(separated_a, separated_b) > 1.5, "an existing phalanx overlap had no deterministic escape correction")


func _test_breach_width(world: Node3D) -> void:
	var profile := PhalanxProfile.new() as HopliteV2PhalanxProfile
	var members: Array[Node3D] = []
	var slots: Dictionary = {}
	for index: int in range(24):
		var member := Node3D.new()
		world.add_child(member)
		members.append(member)
		var row := int(index / 8)
		var column := index % 8
		slots[member.get_instance_id()] = Vector3((float(column) - 3.5) * profile.column_spacing, 0.0, float(1 - row) * profile.rank_spacing)
	var state := {
		"members": members,
		"profile": profile,
		"slots": slots,
		"active_columns": 8,
		"breach_column": 4,
		"breach_lateral": 0.0,
	}
	var reacting_columns: Dictionary = {}
	for index: int in range(members.size()):
		if TroopRuntime._member_reacts_to_breach(state, index):
			reacting_columns[index % 8] = true
	_expect(reacting_columns.size() >= 5, "the local breach still moves fewer than five columns")
	var left: Vector3 = TroopRuntime._breach_slot_position(state, 4, Vector3.ZERO, Vector3.FORWARD, Vector3.RIGHT)
	var right: Vector3 = TroopRuntime._breach_slot_position(state, 5, Vector3.ZERO, Vector3.FORWARD, Vector3.RIGHT)
	_expect(right.x - left.x >= 3.4, "the breach channel is still too narrow for the player, shields and weapons")
	for member: Node3D in members:
		member.free()


func _test_formation_attack_alignment(world: Node3D) -> void:
	var target := Node3D.new()
	world.add_child(target)
	var actor := Factory.create(&"ngeneral") as HopliteEnemyActorV2
	actor.combat_lab_enabled = true
	actor.combat_target = target
	actor.lod_reference = target
	world.add_child(actor)
	await process_frame
	var runtime_stub := Node.new()
	world.add_child(runtime_stub)
	var profile := PhalanxProfile.new() as HopliteV2PhalanxProfile
	actor.bind_phalanx_runtime(runtime_stub, &"alignment_probe", 0, 0, profile)
	actor.mass_transform_mode = true
	actor.set_physics_process(false)
	var initial_forward := actor.global_basis.z.normalized()
	target.global_position = actor.global_position - initial_forward * 5.0
	var target_direction := _planar_direction(actor.global_position, target.global_position, -initial_forward)
	var origin := actor.global_position
	actor.combat.attack_cooldown = 0.0
	actor.combat._transition(HopliteV2CombatComponent.State.GUARD)
	actor.set_phalanx_intent(origin, target_direction, false, true, 0.125)
	_expect(actor.combat.state == HopliteV2CombatComponent.State.APPROACH, "a rear formation attack started before the soldier turned")
	actor.formation_mass_tick(1.0 / 30.0)
	_expect(_planar_distance(actor.global_position, origin) < 0.05, "a rear attacker translated before acquiring a forward arc")
	var attack_facing_dot := -1.0
	for tick: int in range(90):
		if tick % 4 == 0:
			actor.set_phalanx_intent(actor.global_position, target_direction, false, true, 0.125)
		actor.formation_mass_tick(1.0 / 30.0)
		if actor.combat.state == HopliteV2CombatComponent.State.ATTACK:
			attack_facing_dot = actor.global_basis.z.normalized().dot(_planar_direction(actor.global_position, target.global_position, target_direction))
			break
	_expect(attack_facing_dot >= HopliteV2CombatComponent.ATTACK_FACING_DOT - 0.02, "formation attack began without a valid forward arc")
	_expect((actor.global_position - origin).dot(target_direction) > 0.35, "the aligned attacker never closed the spear gap")
	actor.free()
	target.free()
	runtime_stub.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


static func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _planar_direction(from: Vector3, to: Vector3, fallback: Vector3) -> Vector3:
	var direction := to - from
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0001 else fallback
