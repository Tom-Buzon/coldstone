extends SceneTree

const Player = preload("res://scripts/player.gd")
const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const Damage = preload("res://scripts/abilities/skill_damage.gd")
const Flame = preload("res://scripts/abilities/flame_wall.gd")
const PhalanxProfile = preload("res://scripts/enemy_v2/hoplite_v2_phalanx_profile.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := Player.new()
	world.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.skills.profile.reset(true)
	var enemies: Array[Node3D] = []
	for kind: StringName in [&"ngeneral", &"infantry_v2", &"giant_v2"]:
		var enemy := Factory.create(kind)
		enemy.combat_lab_enabled = true
		enemy.combat_target = player
		enemy.lod_reference = player
		world.add_child(enemy)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.global_position = Vector3(enemies.size() * 4, 0, -3)
		enemies.append(enemy)
		var before: float = enemy.health
		_require(Damage.deal(player, enemy, 10, Vector3.FORWARD, 0, &"burn") and enemy.health < before, "skill damage failed on " + String(kind))
	var hoplite: Node3D = enemies[0]
	var shield_hit = player._make_weapon_hit_event(&"heavy", &"idle", hoplite.global_position, Vector3.FORWARD, 15.0)
	shield_hit.destroy_shield = true
	_require(hoplite.receive_shield_hit(shield_hit), "real shield did not intercept Ares hit")
	_require(hoplite.equipment.shield_dropped, "Ares did not remove real V2 shield")
	_require(not hoplite.guard.can_guard(), "destroyed shield could still block")
	var runtime_stub := Node.new()
	world.add_child(runtime_stub)
	hoplite.bind_phalanx_runtime(runtime_stub, &"skill_fire_test", 1, 0, PhalanxProfile.new())
	hoplite.mass_transform_mode = true
	hoplite.simulation_lod_level = 3
	hoplite.process_mode = Node.PROCESS_MODE_DISABLED
	var wall := Flame.new()
	wall.source = player
	world.add_child(wall)
	hoplite.global_position = Vector3(1, 0, -4)
	var before_position: Vector3 = hoplite.global_position
	hoplite.set_phalanx_intent(Vector3(-3, 0, -4), Vector3.LEFT, true, false, 0.25)
	_require(hoplite.global_position == before_position, "far LOD snapped a soldier through the fire barrier")
	hoplite.formation_mass_tick(0.25)
	_require(hoplite.global_position.x > 0.5, "collider-free formation member crossed the fire")
	wall.free()
	player.skills._observe_enemies()
	player.skills.profile.selected_ultimate = &"ares"
	player.skills.add_charge(100)
	player.skills.activate_ultimate()
	Damage.deal(player, enemies[1], 100000, Vector3.FORWARD, 0, &"test")
	_require(player.skills.kill_waves.size() == 1, "real enemy death did not queue Ares shockwave")
	var victim := enemies[2]
	victim.global_position = enemies[1].global_position + Vector3.RIGHT
	var health_before: float = victim.health
	player.skills.tick(0.05)
	_require(victim.health < health_before, "Ares death wave did not damage a nearby real enemy")
	player.skills.end_ultimate()
	current_scene = null
	world.queue_free()
	await process_frame
	for failure: String in failures: push_error("[SKILL ENEMIES] " + failure)
	if failures.is_empty(): print("PASS: skills affect V2 infantry, hoplites, giants, shield equipment and mass formations")
	quit(0 if failures.is_empty() else 1)

func _require(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
