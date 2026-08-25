extends SceneTree

const Enemy = preload("res://scripts/enemy/athenian_enemy.gd")
const HitEvent = preload("res://scripts/combat/hit_event.gd")
const ShieldHitbox = preload("res://scripts/enemy/shield_hitbox.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_probe_shield_guard()
	_probe_spiral_smash_guard_disengage()
	_probe_physical_shield_contact()
	await _probe_forge_giant_surfaces_and_injury_alignment()
	_probe_parry()
	_probe_pattern_cycle()
	if failures.is_empty():
		print("ENEMY_COMBAT_PROBE PASS: guard, break, parry and elite patterns")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)

func _probe_shield_guard() -> void:
	var enemy := Enemy.new()
	root.add_child(enemy)
	enemy.defense_mode = &"shield"
	enemy.defense_timer = 1.0
	enemy.guard_max = 86.0
	enemy.guard_stamina = 86.0
	enemy.guard_regen_delay = 1.3
	enemy.defense_damage_multiplier = 0.18
	enemy.defense_sever_multiplier = 0.12
	var attacker := Node3D.new()
	root.add_child(attacker)
	attacker.position = Vector3(0.0, 0.0, -1.0)

	var light := HitEvent.new()
	light.source = attacker
	light.damage = 20.0
	light.sever_damage = 18.0
	light.guard_damage = 29.0
	var light_result: Dictionary = enemy.call("_incoming_damage_multipliers", light)
	_expect(StringName(light_result.get("contact", &"")) == &"shield", "frontal light attack was not shielded")
	_expect(is_equal_approx(enemy.guard_stamina, 57.0), "light attack did not consume exact guard stamina")
	_expect(float(light_result.get("damage", 1.0)) < 0.25, "shield did not reduce health damage")

	var heavy := HitEvent.new()
	heavy.source = attacker
	heavy.damage = 76.0
	heavy.sever_damage = 112.0
	heavy.guard_damage = 132.0
	var heavy_result: Dictionary = enemy.call("_incoming_damage_multipliers", heavy)
	_expect(StringName(heavy_result.get("contact", &"")) == &"guard_break", "heavy attack did not break depleted guard")
	_expect(heavy.guard_broken, "guard break flag was not propagated through HitEvent")
	_expect(enemy.guard_break_timer >= 0.48, "guard break produced no punish window")

	var rear_enemy := Enemy.new()
	root.add_child(rear_enemy)
	rear_enemy.defense_mode = &"shield"
	rear_enemy.defense_timer = 1.0
	rear_enemy.guard_max = 86.0
	rear_enemy.guard_stamina = 86.0
	attacker.position = Vector3(0.0, 0.0, 1.0)
	var rear := HitEvent.new()
	rear.source = attacker
	rear.damage = 20.0
	rear.guard_damage = 29.0
	var rear_result: Dictionary = rear_enemy.call("_incoming_damage_multipliers", rear)
	_expect(StringName(rear_result.get("contact", &"")) == &"flesh", "shield incorrectly protected a rear hit")

	attacker.queue_free()
	enemy.queue_free()
	rear_enemy.queue_free()

func _probe_spiral_smash_guard_disengage() -> void:
	var enemy := Enemy.new()
	root.add_child(enemy)
	enemy.defense_mode = &"shield"
	enemy.defense_timer = 1.0
	enemy.guard_max = 86.0
	enemy.guard_stamina = 86.0
	enemy.max_health = 100.0
	enemy.health = 100.0
	enemy.anatomy_defs[&"thigh_r"] = {
		"damage_mult": 1.0,
		"sever_mult": 1.0,
		"severable": false,
		"sever_threshold": 9999.0
	}
	enemy.zone_state[&"thigh_r"] = {"damage": 0.0, "sever": 0.0, "severed": false}
	var attacker := Node3D.new()
	root.add_child(attacker)
	attacker.position = Vector3(-1.0, 0.0, 0.0)
	var smash := HitEvent.new()
	smash.source = attacker
	smash.damage = 68.0
	smash.sever_damage = 38.0
	smash.guard_damage = 120.0
	smash.direction = Vector3.RIGHT
	smash.impulse = Vector3.RIGHT * 2.8
	smash.body_part = &"thigh_r"
	smash.damage_type = &"spiral_smash"
	var accepted: bool = enemy.receive_spiral_smash(smash)
	_expect(accepted, "spiral smash was rejected by a live enemy")
	_expect(enemy.defense_timer <= 0.0 and enemy.guard_break_timer >= 0.46, "spiral smash did not disengage active guard")
	_expect(is_equal_approx(enemy.guard_stamina, 86.0), "spiral smash permanently depleted guard instead of briefly disengaging it")
	_expect(enemy.health < 40.0, "spiral smash did not deliver its large radial damage")
	_expect(Vector2(enemy.velocity.x, enemy.velocity.z).length() > 2.0 and Vector2(enemy.velocity.x, enemy.velocity.z).length() <= 5.0, "spiral smash knockback is missing or excessive")
	attacker.queue_free()
	enemy.queue_free()

func _probe_physical_shield_contact() -> void:
	var enemy := Enemy.new()
	root.add_child(enemy)
	enemy.shield_enabled = true
	enemy.shield_root = Node3D.new()
	enemy.add_child(enemy.shield_root)
	var guard_player := AnimationPlayer.new()
	var guard_library := AnimationLibrary.new()
	for clip: StringName in [&"Idle", &"Idle_Shield"]:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR
		guard_library.add_animation(clip, animation)
	guard_player.add_animation_library(&"", guard_library)
	enemy.add_child(guard_player)
	enemy.animation_player = guard_player
	enemy.uses_mixamo_visual = false
	enemy.uses_spartan_package_visual = true
	enemy.guard_max = 70.0
	enemy.guard_stamina = 70.0
	var shield := ShieldHitbox.new()
	enemy.shield_root.add_child(shield)
	shield.configure(enemy)
	enemy.shield_hitbox = shield
	var attacker := Node3D.new()
	root.add_child(attacker)
	attacker.position = Vector3(0.0, 0.0, -1.0)
	var hit := HitEvent.new()
	hit.source = attacker
	hit.damage = 30.0
	hit.sever_damage = 40.0
	hit.guard_damage = 24.0
	_expect(not shield.active, "lowered shield remained in the weapon collision query")
	_expect(not shield.receive_weapon_hit_zone(hit, &"shield"), "lowered shield blocked a direct blade contact")
	enemy.defense_mode = &"shield"
	enemy.ai_player = attacker
	enemy.call("_begin_defense_window")
	_expect(shield.active, "raising guard did not enable the physical shield surface")
	_expect(enemy.simple_anim_state == &"Idle_Shield", "lightweight package did not enter its shield pose")
	enemy.call("_ai_update_animation_speed")
	_expect(enemy.simple_anim_state == &"Idle_Shield", "locomotion replaced the shield pose in the same frame")
	var accepted: bool = shield.receive_weapon_hit_zone(hit, &"shield")
	_expect(accepted, "physical shield Area rejected a direct blade contact")
	_expect(hit.contact_type == &"shield", "physical shield contact did not become a metal block")
	_expect(hit.hit_material == &"metal", "physical shield contact did not report metal material")
	_expect(is_equal_approx(enemy.guard_stamina, 46.0), "direct shield contact did not consume guard stamina")
	_expect(is_equal_approx(enemy.health, enemy.max_health), "direct shield contact damaged body health")
	_expect(shield.zone_priority_from_shape_index(0) > 2.0, "shield does not win overlapping body contact arbitration")
	enemy.call("_end_defense_window")
	enemy.defense_timer = 0.0
	enemy.defense_cooldown_timer = 0.0
	enemy.call("_update_defense", 0.016)
	_expect(enemy.defense_timer > 0.0, "shield infantry did not proactively raise guard at close range")
	_expect(shield.active, "proactive guard did not reactivate the physical shield")
	_expect(not bool(enemy.call("_can_start_attack_at_distance", 1.0)), "shield infantry attacked through its guard pose")
	enemy.call("_end_defense_window")
	enemy.defense_timer = 0.0
	enemy.defense_cooldown_timer = 0.0
	attacker.position = Vector3(0.0, 0.0, -3.4)
	enemy.call("_on_threat_attack_started", &"light1", &"idle", 0.0)
	_expect(enemy.defense_reaction_timer > 0.0, "player attack signal did not prepare a shield reaction")
	enemy.call("_update_defense", 0.20)
	_expect(enemy.defense_timer > 0.0 and shield.active, "prepared shield reaction was lost before the guard opened")
	var combat_facing: Vector3 = enemy.call("_combat_facing_direction", Vector3.RIGHT, true)
	_expect(combat_facing.normalized().dot(Vector3(0.0, 0.0, -1.0)) > 0.99, "combat separation overrode target-facing and can trigger rotation oscillation")
	attacker.queue_free()
	enemy.queue_free()

func _probe_forge_giant_surfaces_and_injury_alignment() -> void:
	var enemy := Enemy.new()
	enemy.archetype_id = &"ngeneral"
	enemy.match_perfect_hitbox = true
	enemy.external_scale_multiplier = 4.0
	root.add_child(enemy)
	_expect(enemy.body_collider.disabled, "Forge model-matched giant kept its oversized coarse capsule")
	_expect(enemy.matched_physical_colliders.size() >= 8, "Forge giant did not build a segmented physical body")
	var head_collision := enemy.matched_physical_colliders.get(&"head") as CollisionShape3D
	_expect(head_collision != null and head_collision.shape is ConvexPolygonShape3D, "giant head collider was not generated from the real model mesh")
	_expect(head_collision != null and head_collision.has_meta("matched_model_mesh"), "giant head collider fell back to a generic skeletal sphere")
	await process_frame
	await physics_frame
	_expect(enemy.matched_walkable_surfaces.size() == 2, "Forge giant did not create shoulder/head floor surfaces")
	for surface: AnimatableBody3D in enemy.matched_walkable_surfaces:
		_expect(surface.collision_layer == 128, "Forge giant floor surface is not isolated on layer 128")
		_expect(surface.is_in_group("enemy_walkable_surface"), "Forge giant floor surface lacks its player-contact group")
	var shoulder_before := INF
	if not enemy.matched_walkable_surfaces.is_empty():
		shoulder_before = enemy.matched_walkable_surfaces[0].global_position.y
	for zone: StringName in [&"thigh_l", &"thigh_r"]:
		var state: Dictionary = enemy.zone_state.get(zone, {}).duplicate()
		state["severed"] = true
		enemy.zone_state[zone] = state
	enemy.call("_refresh_injury_state")
	enemy.call("_update_injury_visual", 1.0)
	if enemy.anatomy != null:
		enemy.anatomy.force_update()
	enemy.call("_update_matched_walkable_surfaces")
	await physics_frame
	await physics_frame
	var severed_thigh_collision := enemy.matched_physical_colliders.get(&"thigh_l") as CollisionShape3D
	_expect(severed_thigh_collision == null or severed_thigh_collision.disabled, "severed model limb kept its physical convex hull")
	var capsule := enemy.body_collider.shape as CapsuleShape3D
	_expect(capsule != null and is_equal_approx(capsule.height, 1.28), "legless enemy kept the full standing capsule")
	_expect(is_equal_approx(enemy.body_collider.position.y, 0.64), "legless enemy capsule was not lowered")
	if not enemy.matched_walkable_surfaces.is_empty():
		var shoulder_after: float = enemy.matched_walkable_surfaces[0].global_position.y
		_expect(shoulder_after < shoulder_before - 1.5, "giant floor surfaces did not follow the lowered injured skeleton (before=%.3f after=%.3f visual=%.3f)" % [shoulder_before, shoulder_after, enemy.visual_root.position.y])
	if enemy.shield_root == null:
		_expect(false, "shield-bearing test enemy has no shield root")
	else:
		enemy.defense_mode = &"shield"
		enemy.defense_timer = 1.0
		enemy.call("_update_shield_guard_visual")
		var body_scale: float = enemy.global_basis.get_scale().y
		var expected_guard_y := enemy.global_position.y + (1.08 - 0.54) * body_scale
		_expect(is_equal_approx(enemy.shield_root.global_position.y, expected_guard_y), "guard shield ignored the leg-loss visual offset")
	enemy.call("_set_matched_walkable_surfaces_enabled", false)
	for surface: AnimatableBody3D in enemy.matched_walkable_surfaces:
		_expect(surface.collision_layer == 0, "disabled Forge giant kept a walkable collision layer")
	enemy.queue_free()

func _probe_parry() -> void:
	var enemy := Enemy.new()
	root.add_child(enemy)
	enemy.defense_mode = &"parry"
	enemy.defense_timer = 0.30
	enemy.defense_damage_multiplier = 0.08
	enemy.defense_sever_multiplier = 0.06
	var attacker := Node3D.new()
	root.add_child(attacker)
	attacker.position = Vector3(0.0, 0.0, -1.0)
	var hit := HitEvent.new()
	hit.source = attacker
	hit.damage = 24.0
	hit.sever_damage = 23.0
	var result: Dictionary = enemy.call("_incoming_damage_multipliers", hit)
	_expect(StringName(result.get("contact", &"")) == &"parry", "active parry did not report metal parry contact")
	_expect(enemy.parry_counter_queued, "successful parry did not queue a counter")
	_expect(enemy.defense_timer <= 0.06, "parry window did not close after contact")
	attacker.queue_free()
	enemy.queue_free()

func _probe_pattern_cycle() -> void:
	var enemy := Enemy.new()
	root.add_child(enemy)
	enemy.combat_pattern = [
		{"id": &"one", "slot": &"light1"},
		{"id": &"two", "slot": &"heavy"}
	]
	enemy.phase_two_pattern = [{"id": &"rage", "slot": &"spin360"}]
	var first: Dictionary = enemy.call("_next_combat_pattern_step")
	var second: Dictionary = enemy.call("_next_combat_pattern_step")
	var looped: Dictionary = enemy.call("_next_combat_pattern_step")
	_expect(StringName(first.get("id", &"")) == &"one", "pattern did not start with its telegraphed opener")
	_expect(StringName(second.get("id", &"")) == &"two", "pattern did not advance deterministically")
	_expect(StringName(looped.get("id", &"")) == &"one", "pattern did not loop")
	enemy.combat_phase = 2
	var phase_two: Dictionary = enemy.call("_next_combat_pattern_step")
	_expect(StringName(phase_two.get("id", &"")) == &"rage", "phase two did not switch pattern")
	enemy.queue_free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
