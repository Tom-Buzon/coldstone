extends SceneTree

const Enemy = preload("res://scripts/enemy/athenian_enemy.gd")
const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")

class ProbeTarget:
	extends CharacterBody3D
	signal combat_attack_started(slot: StringName, context: StringName, power: float)
	func receive_enemy_hit(_damage: float, _attacker: Node = null, _direction: Vector3 = Vector3.ZERO) -> bool:
		return true
	func get_combat_aim_point() -> Vector3:
		return global_position + Vector3.UP

const SPECIALIZED: Array[StringName] = [
	&"captain", &"warlord", &"boss_colossus", &"boss_bronze",
	&"nsbire2", &"nathenian2", &"bronze_colossus", &"ncenturion", &"ngeneral", &"ngeneral_veteran", &"nfull_armor",
	&"giant_novice", &"giant_standard", &"giant_veteran"
]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var target := ProbeTarget.new()
	target.name = "AnimationProbeTarget"
	target.position = Vector3(0.0, 0.0, -1.5)
	root.add_child(target)
	for archetype: StringName in SPECIALIZED:
		await _probe_specialized(archetype, target)
	target.queue_free()
	if failures.is_empty():
		print("ENEMY_ANIMATION_PROBE PASS: %d specialized rigs played their pattern opener" % SPECIALIZED.size())
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _probe_specialized(archetype: StringName, target: Node3D) -> void:
	var profile := Archetypes.profile(archetype)
	var enemy := Enemy.new()
	enemy.name = "AnimationProbe_" + String(archetype)
	enemy.archetype_id = archetype
	enemy.ai_enabled = true
	enemy.ai_player = target
	enemy.battle_player = target
	enemy.position = Vector3.ZERO
	enemy.match_perfect_hitbox = bool(profile.get("forge_default_match_perfect_hitbox", false))
	root.add_child(enemy)
	await process_frame
	await process_frame
	var label := String(profile.get("display_name", archetype))
	_expect(enemy.skeleton != null and enemy.animation_player != null, "%s: rig or AnimationPlayer missing" % label)
	_expect(not enemy.combat_pattern.is_empty(), "%s: runtime pattern missing" % label)
	if Archetypes.is_giant(archetype):
		_expect(enemy.character_package_path.ends_with("geant1-1787584159710.glb"), "%s: final Geant1 model not selected" % label)
		_expect(enemy.sword_root == null and enemy.shield_root == null, "%s: unarmed giant received procedural equipment" % label)
		_expect(enemy.body_collider != null and not enemy.body_collider.disabled, "%s: internal world-floor collider missing" % label)
		_expect(enemy.collision_layer == 0, "%s: internal floor collider is still exposed to the player" % label)
		_expect(enemy.matched_physical_colliders.is_empty(), "%s: assisted giant still exposes animated model colliders" % label)
		_expect(enemy.giant_traversal_body != null and enemy.giant_traversal_body.collision_layer == 256 and enemy.giant_traversal_collision.shape is CylinderShape3D, "%s: shoulder-height traversal cylinder missing" % label)
		_expect(enemy.giant_traversal_head_body != null and enemy.giant_traversal_head_collision.shape is ConvexPolygonShape3D, "%s: real head-mesh collider missing" % label)
		_expect(enemy.matched_walkable_surfaces.size() == 1 and enemy.matched_walkable_surfaces[0].name == "HeadFloor", "%s: exact-head top stabilizer missing" % label)
		_expect(enemy.is_wall_run_giant(), "%s: giant did not opt into player wallrun" % label)
	if bool(profile.get("shield", false)):
		var authored_shield := enemy.uses_mixamo_visual and enemy.mixamo_model_id == &"knight3"
		_expect(enemy.shield_root != null or authored_shield, "%s: shield profile has no visible shield" % label)

	enemy.call("_begin_ai_attack")
	var step_id := StringName(enemy.active_attack_step.get("id", StringName()))
	_expect(step_id != StringName(), "%s: pattern opener did not start" % label)
	var expected_duration := enemy.active_attack_windup_total + float(enemy.active_attack_step.get("recovery", enemy.ai_attack_recovery))
	var played_duration: float = enemy.simple_anim_lock_timer if enemy.uses_mixamo_visual else (float(enemy.ai_animation_driver.current_attack_length()) if enemy.ai_animation_driver != null else 0.0)
	_expect(absf(played_duration - expected_duration) <= 0.10, "%s/%s: animation %.2fs is not synchronized to mechanical %.2fs" % [label, step_id, played_duration, expected_duration])
	if enemy.uses_mixamo_visual:
		var direct_key := StringName(enemy.active_attack_step.get("mixamo", StringName()))
		var expected := StringName("mixamo/" + String(direct_key))
		_expect(direct_key != StringName() and enemy.simple_anim_state == expected, "%s/%s: direct Mixamo pattern clip did not play (%s)" % [label, step_id, enemy.simple_anim_state])
	else:
		_expect(enemy.ai_animation_driver != null, "%s: specialized retarget driver missing" % label)
		if enemy.ai_animation_driver != null:
			var current_clip := String(enemy.ai_animation_driver.current_attack_clip)
			_expect(current_clip.begins_with("external:"), "%s/%s: selective retarget clip did not play (%s)" % [label, step_id, current_clip])
	print("ANIMATION %-18s visual=%-8s opener=%-20s clip=%s" % [
		label,
		"mixamo" if enemy.uses_mixamo_visual else "retarget",
		String(step_id),
		String(enemy.simple_anim_state) if enemy.uses_mixamo_visual else String(enemy.ai_animation_driver.current_attack_clip if enemy.ai_animation_driver != null else &"missing")
	])
	enemy.queue_free()
	await process_frame
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
