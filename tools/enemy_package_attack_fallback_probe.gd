extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")

var archetype: StringName = &"nathenian1"
var failures: Array[String] = []


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--id="):
			archetype = StringName(argument.trim_prefix("--id="))
	call_deferred("_run")


func _run() -> void:
	seed(91_337)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var target := Node3D.new()
	target.add_to_group("player")
	target.position = Vector3(0.0, 0.0, -0.8)
	world.add_child(target)
	var enemy = EnemyFactory.spawn(world, archetype, Vector3.ZERO, target, {
		"ai_enabled": true,
		"mass_battle_mode": false,
	})
	await process_frame
	await physics_frame
	_expect(enemy != null, "%s factory fixture failed" % archetype)
	if enemy != null:
		enemy.set_process(false)
		enemy.set_physics_process(false)
		_expect(enemy.uses_spartan_package_visual, "%s did not use its authored package route" % archetype)
		_expect(not enemy.mass_battle_mode, "%s probe accidentally enabled mass mode" % archetype)
		_expect(enemy.ai_animation_driver == null, "%s is not a lightweight direct-donor package" % archetype)
		_expect(enemy.animation_player != null and enemy.animation_player.has_animation(&"Sword_Attack"), "%s UAL1 donor lacks Sword_Attack" % archetype)
		enemy.ai_attack_pending = false
		enemy.ai_attack_cooldown_timer = 0.0
		enemy.ai_attack_recovery_timer = 0.0
		enemy.signature_chance = 0.0
		enemy.sword_dropped = false
		enemy.call("_release_attack_permission")
		enemy.call("_set_combat_target", target)
		enemy.call("_begin_ai_attack")
		_expect(enemy.ai_attack_pending, "%s did not begin its mechanical attack" % archetype)
		_expect(enemy.simple_anim_state == &"Sword_Attack", "%s non-mass attack did not select the visible UAL1 fallback (got %s)" % [archetype, enemy.simple_anim_state])
		_expect(enemy.animation_player.current_animation == &"Sword_Attack" and enemy.animation_player.is_playing(), "%s donor player is not playing Sword_Attack" % archetype)
		var attack := enemy.animation_player.get_animation(&"Sword_Attack") as Animation
		_expect(attack != null and attack.loop_mode == Animation.LOOP_NONE, "%s fallback attack is not one-shot" % archetype)
		_expect(enemy.simple_anim_lock_timer > 0.0, "%s fallback has no visual lock window" % archetype)
		enemy.call("_resolve_ai_attack")
		_expect(not enemy.ai_attack_pending, "%s fallback attack did not resolve cleanly" % archetype)
		enemy.set_ai_participation(false)
		_expect(not enemy.ai_enabled, "%s sleep failed after fallback attack" % archetype)
		enemy.set_ai_participation(true)
		_expect(enemy.ai_enabled, "%s wake failed after fallback attack" % archetype)

	world.queue_free()
	await process_frame
	await process_frame
	_expect(get_nodes_in_group("combatant_ai").is_empty(), "%s teardown retained AI members" % archetype)
	if failures.is_empty():
		print("ENEMY_PACKAGE_ATTACK_FALLBACK_PROBE PASS id=%s non_mass=true clip=Sword_Attack one_shot=true sleep_wake=true cleanup=true" % archetype)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
