extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const MixamoCatalog = preload("res://scripts/enemy/mixamo_catalog.gd")
const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const HitEvent = preload("res://scripts/combat/hit_event.gd")

var archetype: StringName = &"captain"
var failures: Array[String] = []
var variants_tested := 0
var zones_tested := 0

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--id="):
			archetype = StringName(argument.trim_prefix("--id="))
	call_deferred("_run")

func _run() -> void:
	var pool: Array = MixamoCatalog.MODEL_POOLS.get(archetype, [])
	if pool.is_empty() or not Archetypes.all_ids().has(archetype):
		failures.append("%s is not a direct Mixamo archetype with a declared pool" % archetype)
	else:
		for raw_model: Variant in pool:
			await _probe_variant(StringName(raw_model))
		await _probe_rejected_cross_pool_override(pool)
	if failures.is_empty():
		print("ENEMY_MIXAMO_VARIANT_MATRIX_PROBE PASS id=%s variants=%d zones=%d" % [archetype, variants_tested, zones_tested])
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _probe_variant(model_id: StringName) -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var enemy := _spawn(world, model_id)
	await process_frame
	await physics_frame
	_expect(enemy != null, "%s/%s factory spawn failed" % [archetype, model_id])
	if enemy == null:
		world.queue_free()
		await process_frame
		return
	variants_tested += 1
	_expect(enemy.mixamo_model_id == model_id and enemy.uses_mixamo_visual, "%s/%s override did not select the requested direct rig" % [archetype, model_id])
	_expect(enemy.skeleton != null and enemy.skeleton.get_bone_count() > 0, "%s/%s has no populated skeleton" % [archetype, model_id])
	_expect(enemy.animation_player != null and not enemy.animation_player.get_animation_list().is_empty(), "%s/%s has no animation player/library" % [archetype, model_id])
	_expect(enemy.anatomy != null and enemy.anatomy.zone_runtime.size() == 12 and enemy.anatomy.debug_missing_bones.is_empty(), "%s/%s anatomy is not mapped 12/12" % [archetype, model_id])
	_expect(enemy.weapon_kind == &"unarmed" or enemy.sword_root != null, "%s/%s has no detachable weapon anchor" % [archetype, model_id])
	if enemy.shield_enabled:
		_expect(enemy.shield_root != null and enemy.shield_hitbox != null, "%s/%s has no detachable physical shield" % [archetype, model_id])
	var pattern_ids: Array[StringName] = []
	for _step: int in range(maxi(1, enemy.combat_pattern.size())):
		var step: Dictionary = enemy._next_combat_pattern_step()
		if not step.is_empty():
			pattern_ids.append(StringName(step.get("id", StringName())))
	if not enemy.combat_pattern.is_empty():
		_expect(pattern_ids.size() == enemy.combat_pattern.size(), "%s/%s did not cycle its complete combat pattern" % [archetype, model_id])
		var unique: Dictionary = {}
		for id: StringName in pattern_ids:
			unique[id] = true
		_expect(unique.size() == enemy.combat_pattern.size(), "%s/%s combat pattern repeated/omitted a step" % [archetype, model_id])
	enemy.queue_free()
	await process_frame

	var zones: Array = [&"head", &"neck", &"torso", &"pelvis", &"upper_arm_l", &"forearm_l", &"upper_arm_r", &"forearm_r", &"thigh_l", &"shin_l", &"thigh_r", &"shin_r"]
	for raw_zone: Variant in zones:
		var zone := StringName(raw_zone)
		var victim := _spawn(world, model_id)
		await process_frame
		victim.max_health = 100000.0
		victim.health = victim.max_health
		victim.defense_mode = &"none"
		victim.armor_sever_multiplier = 1.0
		var definition: Dictionary = victim.anatomy_defs.get(zone, {})
		var severable := bool(definition.get("severable", false))
		var target_zone := StringName(definition.get("sever_target", zone))
		var hit := HitEvent.new()
		hit.damage = 1.0
		hit.sever_damage = 100000.0
		hit.position = victim.anatomy.get_zone_world_center(zone)
		hit.direction = Vector3.RIGHT
		victim.receive_anatomy_hit(hit, zone)
		await process_frame
		zones_tested += 1
		_expect(victim.is_combat_zone_severed(target_zone) == severable, "%s/%s/%s severability mismatch" % [archetype, model_id, zone])
		if severable and target_zone in [&"upper_arm_r", &"forearm_r"] and victim.weapon_kind != &"unarmed":
			_expect(victim.sword_dropped, "%s/%s/%s did not drop its weapon" % [archetype, model_id, zone])
		if severable and target_zone in [&"upper_arm_l", &"forearm_l"] and victim.shield_enabled:
			_expect(victim.shield_dropped, "%s/%s/%s did not drop its shield" % [archetype, model_id, zone])
		victim.queue_free()
		await process_frame
	world.queue_free()
	await process_frame

func _probe_rejected_cross_pool_override(pool: Array) -> void:
	var invalid_model := StringName()
	for raw_model: Variant in MixamoCatalog.MODEL_SCALES.keys():
		if not pool.has(raw_model):
			invalid_model = StringName(raw_model)
			break
	if invalid_model == StringName():
		failures.append("could not select a cross-pool invalid override")
		return
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var enemy := _spawn(world, invalid_model)
	await process_frame
	_expect(enemy != null and enemy.mixamo_model_id != invalid_model, "%s accepted cross-pool Mixamo override %s" % [archetype, invalid_model])
	world.queue_free()
	await process_frame

func _spawn(parent: Node3D, model_id: StringName) -> HopliteAthenianEnemy:
	return EnemyFactory.spawn(parent, archetype, Vector3.ZERO, null, {
		"ai_enabled": false,
		"mixamo_model_override": model_id,
	})

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
