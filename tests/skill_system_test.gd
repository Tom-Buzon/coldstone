extends SceneTree

const Player = preload("res://scripts/player.gd")
const Profile = preload("res://scripts/abilities/skill_profile.gd")
const Damage = preload("res://scripts/abilities/skill_damage.gd")
const Flame = preload("res://scripts/abilities/flame_wall.gd")
const Shot = preload("res://scripts/abilities/skill_projectile.gd")
var failures: Array[String] = []

class Target extends CharacterBody3D:
	signal died(enemy: Node)
	signal zone_severed(enemy: Node, zone: StringName)
	var health := 2000.0
	var combat: Node
	var shield_destroyed := false
	var last_hit: Variant
	func is_dead_for_combat() -> bool: return health <= 0.0
	func receive_anatomy_hit(hit: Variant, _zone: StringName) -> void:
		last_hit = hit
		health -= hit.damage
		if health <= 0.0: died.emit(self)
	func destroy_skill_shield() -> void: shield_destroyed = true

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var profile := Profile.new()
	profile.reset(true)
	profile.set_feature(&"wall", false)
	_require(not profile.active(&"giant_wall") and not profile.active(&"shield_reset"), "wall prerequisites not enforced")
	profile.set_feature(&"wall", true)
	_require(profile.active(&"giant_wall"), "restoring prerequisite lost child unlocks")
	profile.set_tuning(&"max_jumps", 999)
	_require(profile.value(&"max_jumps") == 8, "setting was not clamped")
	profile.save_path = "res://.godot/skill-profile-test.cfg"
	profile.selected_ultimate = &"ares"
	_require(profile.save_settings() == OK, "profile did not save")
	var restored := Profile.new()
	restored.save_path = profile.save_path
	_require(restored.load_settings() == OK and restored.selected_ultimate == &"ares" and restored.value(&"max_jumps") == 8 and restored.active(&"giant_wall"), "profile round trip failed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile.save_path))
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := Player.new()
	world.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var skills: Node = player.skills
	skills.profile.reset(true)
	_require(is_equal_approx(skills.jump_speed(0) * skills.jump_speed(0) / (2 * player.gravity), skills.value(&"jump_1")), "jump height not mapped to physics")
	skills.profile.set_tuning(&"jump_3", 4.0)
	_require(is_equal_approx(skills.jump_speed(2) * skills.jump_speed(2) / (2 * player.gravity), 4.0), "third jump height not independent")
	skills.profile.set_feature(&"dash", false)
	player.dash_charges = 1
	player._start_regular_dash()
	_require(player.dash_time == 0.0 and player.dash_charges == 1, "disabled dash consumed a charge")
	skills.profile.set_feature(&"dash", true)
	player._start_regular_dash()
	_require(player.dash_time > 0.0, "enabled dash failed")
	Input.action_press(&"move_right")
	var old_direction: Vector3 = player.dash_direction
	skills.steer_dash(0.1)
	_require(not player.dash_direction.is_equal_approx(old_direction), "dash did not follow changed input")
	Input.action_release(&"move_right")
	player.dash_time = 0.0
	player.wall_run_runs_used = 2
	skills.on_wall_jump(&"giant_enemy")
	_require(player.wall_run_runs_used == 0 and player.wall_run_attach_available and skills.wall_boost, "giant exit rewards failed")
	skills.profile.set_feature(&"giant_reset", false)
	player.wall_run_runs_used = 2
	skills.on_wall_jump(&"giant_enemy")
	_require(player.wall_run_runs_used == 2, "disabled giant reset still active")
	player.health = player.max_health * 0.5
	skills.profile.set_tuning(&"max_health", 600)
	_require(is_equal_approx(player.health, 300), "health tuning healed the player instead of preserving ratio")
	var target := Target.new()
	target.add_to_group(&"enemy")
	world.add_child(target)
	target.global_position = player.global_position + Vector3(0, 0, -1.0)
	skills._observe_enemies()
	skills.ultimate_charge = 0.0
	Damage.deal(player, target, 1, Vector3.FORWARD, 0, &"test")
	target.zone_severed.emit(target, &"arm_l")
	_require(skills.ultimate_charge == skills.value(&"sever_reward"), "dismemberment did not charge ultimate")
	skills._on_perfect(&"dodge")
	_require(skills.ultimate_charge == skills.value(&"sever_reward") + skills.value(&"perfect_reward"), "perfect response did not charge ultimate")
	skills.profile.selected_ultimate = &"ares"
	_require(not skills.activate_ultimate(), "ultimate activated without enough charge")
	skills.add_charge(100)
	_require(skills.activate_ultimate() and skills.ultimate == &"ares" and skills.ultimate_charge == 0, "Ares failed to activate/spend charge")
	var hit = player._make_weapon_hit_event(&"heavy", &"idle", Vector3.ZERO, Vector3.RIGHT, 20)
	_require(hit.destroy_shield and hit.impulse.length() > 10, "Ares did not modify knockback/shield destruction")
	var old_health := target.health
	skills.tick(0.05)
	_require(target.health == old_health, "Ares attacked automatically")
	skills.profile.set_feature(&"ares", false)
	_require(skills.ultimate == &"", "disabling active ultimate did not end it")
	skills.plunge_active = true
	skills.airborne_peak = player.global_position.y + 10.0
	old_health = target.health
	skills.on_landed()
	_require(is_equal_approx(old_health - target.health, skills.value(&"plunge_base") + 10 * skills.value(&"plunge_height")), "plunge damage not proportional to height")
	var wall := Flame.new()
	wall.source = player
	wall.duration = 1.0
	wall.burn_duration = 1.0
	world.add_child(wall)
	target.global_position = Vector3(0, 0, -3)
	old_health = target.health
	wall._physics_process(0.2)
	_require(target.health < old_health, "flame did not damage a target inside")
	target.global_position.x = 4
	old_health = target.health
	wall._physics_process(0.2)
	_require(target.health < old_health, "burn stopped immediately outside flame")
	target.global_position.x = 1
	var avoided := Flame.avoid(target, Vector3(-6, 0, 0), 0.1)
	_require(avoided.x > 0, "fear did not turn enemy away from flame")
	wall.rotation.y = PI * 0.5
	target.global_position = wall.to_global(Vector3(1, 0, -3))
	avoided = Flame.avoid(target, wall.global_basis * Vector3(-6, 0, 0), 0.1)
	_require((wall.global_basis.inverse() * avoided).x > 0, "rotated flame fear uses stale world axes")
	wall.free()
	_require(Flame.walls.is_empty(), "flame registry leaked an expired wall")
	target.global_position = Vector3(0, 0, -3)
	var projectile := Shot.new()
	projectile.source = player
	projectile.position = Vector3(0, 1, 0)
	projectile.damage = 50
	world.add_child(projectile)
	old_health = target.health
	projectile._physics_process(0.10)
	_require(target.health == old_health - 50, "fast projectile missed collider-free target")
	skills.end_ultimate()
	skills.profile.selected_ultimate = &"flame"
	skills.add_charge(100)
	_require(skills.activate_ultimate() and skills.cast_remaining == 2.0, "flame did not begin two-second charge")
	player.camera_yaw.rotation.y += PI * 0.5
	skills.tick(2.1)
	_require(Flame.walls.size() == 1, "charged flame did not spawn")
	if not Flame.walls.is_empty():
		_require((-Flame.walls[0].global_basis.z).dot(player._camera_forward_flat()) > 0.99, "flame ignored facing changes during charge")
	skills.profile.set_feature(&"flame", false)
	await process_frame
	_require(Flame.walls.is_empty(), "disabling flame left damage/fear alive")
	skills.profile.selected_ultimate = &"aura"
	skills.add_charge(100)
	_require(skills.activate_ultimate(), "Aura failed to activate")
	target.global_position = player.global_position + Vector3(0, 0, 1.0)
	old_health = target.health
	skills.tick(0.13)
	skills.tick(0.08)
	_require(target.health < old_health, "Aura could not strike a target behind the initial facing")
	_require(not target.shield_destroyed, "Aura incorrectly used Ares shield destruction")
	skills.end_ultimate()
	player.velocity = Vector3.FORWARD * 19.0
	target.global_position = player.global_position + Vector3.RIGHT
	skills.edge_perfect = true
	old_health = target.health
	skills._edge_contacts()
	_require(target.health < old_health, "horizontal edge missed lateral contact")
	player.velocity = Vector3.RIGHT * 19.0
	target.global_position = player.global_position + Vector3.BACK
	old_health = target.health
	skills._edge_contacts()
	_require(target.health < old_health, "horizontal edge failed after changing movement direction")
	player.animation_driver._finish_attack()
	var context: StringName = player._combat_context()
	skills.profile.set_feature(StringName("light_" + String(context)), false)
	player._do_light_attack()
	_require(not player.animation_driver.is_attack_active(), "disabled contextual light still started")
	skills.profile.set_feature(StringName("heavy_" + String(context)), false)
	player._begin_heavy_input()
	_require(not player.heavy_charging, "disabled contextual heavy still charged")
	current_scene = null
	world.queue_free()
	await process_frame
	for failure: String in failures: push_error("[SKILLS] " + failure)
	if failures.is_empty(): print("PASS: skill profiles, movement gates, ultimate lifecycle, damage, burn, fear and projectiles")
	quit(0 if failures.is_empty() else 1)

func _require(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
