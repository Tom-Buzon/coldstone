extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const HitEvent = preload("res://scripts/combat/hit_event.gd")
const WolfBossScript = preload("res://scripts/bosses/wolf_boss.gd")


class TestPlayer extends CharacterBody3D:
	var jumps_used := 0
	var max_jumps := 2
	var wall_run_active := false
	var wall_run_repulsion_control_lock := 0.0
	var received_damage := 0.0

	func receive_enemy_hit(damage: float, _attacker: Node = null, _hit_direction: Vector3 = Vector3.ZERO) -> bool:
		received_damage += damage
		return true


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.name = "TheWolfBossProbeStage"
	root.add_child(stage)
	current_scene = stage
	_add_floor(stage)
	var player := TestPlayer.new()
	player.name = "MobilityPlayer"
	player.add_to_group("player")
	player.position = Vector3(0.0, 0.1, -10.0)
	stage.add_child(player)

	var mid := EnemyFactory.spawn(stage, &"the_wolf_mid", Vector3.ZERO, player, {
		"ai_enabled": false,
		"performance_profile": "detailed",
	})
	await process_frame
	await physics_frame
	_expect(mid != null and mid.get_script() == WolfBossScript, "the_wolf_mid did not route to HopliteWolfBoss")
	if mid != null:
		_verify_model_contract(mid)
		_verify_mobility_break(mid, player)
		_verify_mid_phase_contract(mid)

	var veteran := EnemyFactory.spawn(stage, &"the_wolf_veteran", Vector3(8.0, 0.1, 0.0), player, {
		"ai_enabled": true,
		"performance_profile": "detailed",
	})
	await process_frame
	await physics_frame
	_expect(veteran != null and veteran.get_script() == WolfBossScript, "the_wolf_veteran did not route to HopliteWolfBoss")
	if veteran != null:
		_expect(bool(veteran.get("veteran_mode")), "Veteran profile did not enable veteran behavior")
		_expect(Array(veteran.get("phase_three_pattern")).size() >= 3, "Veteran does not expose a distinct three-action phase 3")
		var start_position: Vector3 = veteran.global_position
		for _frame: int in range(115):
			await physics_frame
		_expect(veteran.global_position.distance_to(start_position) > 0.20, "Veteran AI stayed immobile after its intro")
		_expect(int(veteran.get("boss_state")) != 0, "Veteran AI never left INTRO")
		veteran.set_ai_participation(false)
		veteran.set("health", float(veteran.get("max_health")) * 0.10)
		veteran.call("_try_activate_combat_phase")
		_expect(int(veteran.get("combat_phase")) == 2, "one oversized hit skipped Veteran phase 2")

	stage.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("THE_WOLF_BOSS_PROBE PASS model=true animations=true mid_phases=2 veteran_phases=3 mobility_break=true ai_motion=true")
		quit(0)
		return
	for failure: String in failures:
		push_error("[THE WOLF PROBE] " + failure)
	quit(1)


func _verify_model_contract(boss: Node) -> void:
	var visual := boss.get("wolf_visual") as Node3D
	var hitbox := boss.get("wolf_hitbox") as Area3D
	var animation_players: Array = boss.get("wolf_animation_players")
	_expect(visual != null, "Wolf.gltf visual was not instantiated")
	_expect(hitbox != null and hitbox.get_child_count() == 3, "wolf anatomy hitbox zones were not built")
	_expect(not animation_players.is_empty(), "Wolf.gltf contains no usable AnimationPlayer")
	var available: Array[StringName] = []
	for raw_player: Variant in animation_players:
		var animation_player := raw_player as AnimationPlayer
		if animation_player != null:
			available.append_array(animation_player.get_animation_list())
	for required: String in ["Attack", "Death", "Gallop", "Gallop_Jump", "Idle", "Walk"]:
		_expect(_contains_animation(available, required), "Wolf.gltf animation missing: %s" % required)
	_expect(float(boss.get("target_height")) >= 2.69, "boss visual was not enlarged")


func _verify_mobility_break(boss: Node, player: TestPlayer) -> void:
	var starting_health := float(boss.get("health"))
	_hit(boss, player, 100.0, &"idle", StringName())
	_expect(is_equal_approx(float(boss.get("health")), starting_health - 42.0), "ground hit does not use Mid's 0.42 armor multiplier")
	_expect(is_zero_approx(float(boss.get("mobility_break"))), "ground hit incorrectly filled mobility break")

	player.jumps_used = 2
	_hit(boss, player, 100.0, &"air", &"light2")
	_expect(is_equal_approx(float(boss.get("mobility_break")), 46.0), "true double-jump hit did not add 46 mobility break")
	player.jumps_used = 0
	player.wall_run_active = true
	_hit(boss, player, 100.0, &"wall", &"light1")
	player.wall_run_active = false
	_hit(boss, player, 100.0, &"dash", &"light3")
	_expect(bool(boss.get("moon_heart_exposed")), "mobility sequence did not expose the moon heart")
	_expect(is_zero_approx(float(boss.get("mobility_break"))), "mobility gauge did not reset when the heart opened")
	var before_exposed_hit := float(boss.get("health"))
	_hit(boss, player, 100.0, &"idle", StringName())
	_expect(is_equal_approx(float(boss.get("health")), before_exposed_hit - 190.0), "exposed heart does not use Mid's 1.90 damage multiplier")
	_expect(String(boss.get("readout").text).contains("COEUR LUNAIRE EXPOSE"), "boss readout does not announce the damage window")
	boss.call("_close_moon_heart")


func _verify_mid_phase_contract(boss: Node) -> void:
	var profile: Dictionary = Archetypes.profile(&"the_wolf_mid")
	boss.set("health", float(boss.get("max_health")) * float(profile.get("phase_threshold", 0.52)) - 1.0)
	boss.call("_try_activate_combat_phase")
	_expect(int(boss.get("combat_phase")) == 2, "Mid did not transition to phase 2")
	boss.set("health", 1.0)
	boss.call("_try_activate_combat_phase")
	_expect(int(boss.get("combat_phase")) == 2, "Mid incorrectly exposes a third phase")


func _hit(boss: Node, source: Node, damage: float, context: StringName, slot: StringName) -> void:
	var event: HitEvent = HitEvent.new()
	event.source = source
	event.damage = damage
	event.attack_context = context
	event.attack_slot = slot
	event.position = boss.global_position + Vector3.UP
	event.direction = Vector3.FORWARD
	boss.call("receive_anatomy_hit", event, &"torso")


func _contains_animation(available: Array[StringName], wanted_name: String) -> bool:
	var wanted := wanted_name.to_lower()
	for animation_name: StringName in available:
		var normalized := String(animation_name).to_lower()
		if normalized == wanted or normalized.ends_with("|" + wanted) or normalized.ends_with("/" + wanted):
			return true
	return false


func _add_floor(stage: Node3D) -> void:
	var floor := StaticBody3D.new()
	floor.name = "Floor"
	floor.collision_layer = 1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80.0, 1.0, 80.0)
	collider.shape = shape
	collider.position.y = -0.5
	floor.add_child(collider)
	stage.add_child(floor)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
