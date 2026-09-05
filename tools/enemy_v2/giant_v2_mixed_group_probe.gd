extends SceneTree
const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const Troops = preload("res://scripts/enemy_v2/hoplite_v2_troop_runtime.gd")
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func expect(condition: bool, label: String) -> void:
	print("MIXED_GROUP ", "PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var target := Node3D.new()
	target.position = Vector3(0, 0, 20)
	world.add_child(target)
	var troops := Troops.new()
	world.add_child(troops)
	var members: Array[Node] = []
	for source: StringName in [&"ngeneral", &"archer_v2", &"infantry_v2", &"giant_v2"]:
		var actor := Factory.create(source)
		actor.position = Vector3(members.size() * 5.0, 0, 0)
		actor.combat_lab_enabled = true
		actor.combat_target = target
		actor.lod_reference = target
		actor.troop_controlled = true
		actor.set_meta("forge_enemy_v2", true)
		actor.set_meta("formation_unit_index", members.size())
		world.add_child(actor)
		members.append(actor)
	var properties := {"v2_persistent_fronts": true, "v2_unit_role": "phalanx", "formation_columns": 4, "size_multiplier": 3.0, "v2_front_id": 0}
	expect(troops.register_group(&"mixed", members, target, properties), "mixed registration accepted")
	expect(troops.groups.size() == 4 and troops.group_children[&"mixed"].size() == 4, "four homogeneous execution groups")
	for actor: Node in members:
		var role: StringName = actor.definition.unit_role
		var key := StringName("mixed/" + String(role))
		var state: Dictionary = troops.groups.get(key, {})
		expect(not state.is_empty(), "child exists " + String(role))
		if state.is_empty():
			continue
		var cap: Resource = state.capabilities
		var kind: StringName = &"heavy" if role == &"giant" else (&"ranged" if role == &"archer" else &"melee")
		var cost := 3 if role == &"giant" else (2 if role == &"archer" else 1)
		expect(cap.role == role and cap.threat_kind == kind and cap.threat_cost == cost, "correct doctrine/cost " + String(role))
		expect(actor.phalanx_group_id == key and actor.phalanx_runtime == troops, "actor bound to child " + String(role))
	# Re-registration must replace, not duplicate, the child collection.
	expect(troops.register_group(&"mixed", members, target, properties), "mixed re-registration accepted")
	expect(troops.groups.size() == 4 and troops.group_ids.size() == 4 and troops.battle_layout.records.size() == 4, "re-registration has no stale groups")
	var archer := members[1] as Node3D
	var giant := members[3] as Node3D
	expect(troops.threat_budget.request(archer, target, &"ranged", 2, 4.0), "archer lease admitted")
	expect(troops.threat_budget.request(giant, target, &"heavy", 3, 4.0), "giant lease admitted")
	expect(troops.threat_budget.active_cost() == 5, "pressure costs reflect archer and giant")
	troops.remove_group(&"mixed")
	expect(troops.groups.is_empty() and troops.group_ids.is_empty() and troops.group_children.is_empty() and troops.battle_layout.records.is_empty(), "parent removal releases all group indexes")
	for actor: Node in members:
		expect(actor.phalanx_runtime == null and not actor.troop_controlled, "parent removal unbinds " + String(actor.definition.unit_role))
	expect(troops.threat_budget.active_cost() == 0, "parent removal releases uncommitted pressure leases")
	# A once-mixed Forge composition may be edited to only one remaining family.
	var only_archers: Array[Node] = [members[1]]
	expect(troops.register_group(&"mixed", only_archers, target, properties), "re-register surviving archer family")
	var actual_id: StringName = members[1].phalanx_group_id
	var actual_cap: Resource = troops.groups[actual_id].capabilities
	expect(actual_cap.role == &"archer" and actual_cap.threat_cost == 2, "remaining single family retains its real doctrine")
	# Explicit unregistration must detach a live actor as well as remove indexes.
	troops.unregister_member(actual_id, members[1])
	expect(not troops.groups.has(actual_id), "last actor unregister removes execution group")
	expect(members[1].phalanx_runtime == null and not members[1].troop_controlled, "last actor unregister clears actor binding")
	print("MIXED_GROUP_RESULT ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
