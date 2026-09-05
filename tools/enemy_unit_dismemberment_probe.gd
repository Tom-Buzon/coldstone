extends SceneTree

const Enemy = preload("res://scripts/enemy/athenian_enemy.gd")
const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const HitEvent = preload("res://scripts/combat/hit_event.gd")

var archetype: StringName = &"ngeneral"
var failures: Array[String] = []
var tested_zones: int = 0
var severed_zones: int = 0

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--id="):
			archetype = StringName(argument.trim_prefix("--id="))
	if not Archetypes.all_ids().has(archetype):
		failures.append("unknown archetype: %s" % archetype)
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	world.name = "DismembermentProbe_%s" % archetype
	root.add_child(world)
	current_scene = world
	if failures.is_empty():
		var definitions: Dictionary = await _load_definitions(world)
		var zones: Array = definitions.keys()
		zones.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
		for raw_zone: Variant in zones:
			await _probe_zone(world, StringName(raw_zone))
	if failures.is_empty():
		print("ENEMY_UNIT_DISMEMBERMENT_PROBE PASS id=%s zones=%d severed=%d" % [archetype, tested_zones, severed_zones])
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _load_definitions(world: Node3D) -> Dictionary:
	var enemy := _spawn(world, "DefinitionSource")
	await process_frame
	await physics_frame
	var result := enemy.anatomy_defs.duplicate(true)
	enemy.queue_free()
	await process_frame
	return result

func _probe_zone(world: Node3D, zone: StringName) -> void:
	var enemy := _spawn(world, "Zone_%s" % zone)
	await process_frame
	await physics_frame
	if enemy.anatomy == null or not enemy.anatomy_defs.has(zone) or not enemy.zone_state.has(zone):
		failures.append("%s/%s missing anatomy runtime" % [archetype, zone])
		enemy.queue_free()
		await process_frame
		return
	var definition: Dictionary = enemy.anatomy_defs[zone]
	var severable := bool(definition.get("severable", false))
	var sever_target := StringName(definition.get("sever_target", zone))
	if not enemy.zone_state.has(sever_target):
		sever_target = zone
	var expected_fatal := bool(definition.get("fatal_sever", false)) or sever_target == &"head"
	enemy.max_health = 100000.0
	enemy.health = enemy.max_health
	enemy.defense_mode = &"none"
	enemy.defense_timer = 0.0
	enemy.armor_damage_multiplier = 1.0
	enemy.armor_sever_multiplier = 1.0
	enemy.poise = 1.0
	var hit := HitEvent.new()
	hit.damage = 1.0
	hit.sever_damage = 100000.0
	hit.position = enemy.anatomy.get_zone_world_center(zone)
	hit.direction = Vector3.RIGHT
	hit.source = null
	enemy.receive_anatomy_hit(hit, zone)
	await process_frame
	tested_zones += 1
	var state: Dictionary = enemy.zone_state.get(sever_target, {})
	if severable:
		severed_zones += 1
		_expect(bool(state.get("severed", false)), "%s/%s did not mark %s severed" % [archetype, zone, sever_target])
		_expect(enemy.dead == expected_fatal, "%s/%s fatality mismatch expected=%s actual=%s" % [archetype, zone, expected_fatal, enemy.dead])
		var fragment := world.get_node_or_null("SpartanDetached_%s" % sever_target) as RigidBody3D
		if fragment == null:
			fragment = world.get_node_or_null("Detached_%s" % sever_target) as RigidBody3D
		_expect(fragment != null, "%s/%s spawned no exact detached fragment for %s" % [archetype, zone, sever_target])
		if fragment != null:
			var fragment_collision := fragment.find_child("DetachedCollision", true, false) as CollisionShape3D
			if fragment_collision == null:
				for candidate: Node in fragment.get_children():
					if candidate is CollisionShape3D:
						fragment_collision = candidate as CollisionShape3D
						break
			_expect(fragment_collision != null and (fragment_collision.shape is CapsuleShape3D or fragment_collision.shape is SphereShape3D), "%s/%s detached fragment has no primitive collision" % [archetype, zone])
			_expect(fragment.has_node("TransientDebrisLifecycle"), "%s/%s detached fragment has no bounded lifecycle" % [archetype, zone])
		if sever_target in [&"upper_arm_r", &"forearm_r"] and enemy.weapon_kind != &"unarmed":
			_expect(enemy.sword_dropped, "%s/%s did not release right-hand equipment" % [archetype, zone])
		if sever_target in [&"upper_arm_l", &"forearm_l"]:
			if enemy.weapon_kind == &"bow":
				_expect(enemy.sword_dropped, "%s/%s did not release bow" % [archetype, zone])
			elif enemy.shield_enabled:
				_expect(enemy.shield_dropped, "%s/%s did not release shield" % [archetype, zone])
	else:
		_expect(not bool(state.get("severed", false)), "%s/%s non-severable zone was severed" % [archetype, zone])
		_expect(not enemy.dead, "%s/%s non-severable chip hit killed the unit" % [archetype, zone])
	_expect(float((enemy.zone_state.get(zone, {}) as Dictionary).get("damage", 0.0)) > 0.0, "%s/%s did not record localized damage" % [archetype, zone])
	for child: Node in world.get_children():
		child.queue_free()
	await process_frame
	await physics_frame

func _spawn(world: Node3D, suffix: String) -> HopliteAthenianEnemy:
	var enemy := Enemy.new() as HopliteAthenianEnemy
	enemy.name = "%s_%s" % [archetype, suffix]
	enemy.archetype_id = archetype
	enemy.ai_enabled = false
	world.add_child(enemy)
	return enemy

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
