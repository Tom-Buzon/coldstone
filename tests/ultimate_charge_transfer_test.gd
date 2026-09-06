extends SceneTree

const Player = preload("res://scripts/player.gd")
const Shot = preload("res://scripts/abilities/skill_projectile.gd")
const Icons = preload("res://scripts/ui/ultimate_icons.gd")
var failures: Array[String] = []

class Target extends Node3D:
	var health := 10000.0
	var hits := 0
	func is_dead_for_combat() -> bool: return health <= 0
	func receive_ai_hit(amount: float, _source: Node3D, _direction: Vector3) -> bool:
		health -= amount
		hits += 1
		return true

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := Player.new()
	world.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var skills: Node = player.skills
	var controls: Node = skills.controls
	skills.profile.reset(true)
	for id: StringName in [&"aura", &"flame", &"thunder", &"ares"]:
		_require(Icons.texture_for(id) != null, "missing authored icon")
	# Failed taps must have absolutely no state/cost/lock side effects.
	for count: int in 20:
		controls.ultimate_button(true)
		controls.ultimate_button(false)
		skills._process(0.016)
		_require(skills.ultimate == &"" and skills.activation_buffer == 0.0 and not controls.ultimate_held, "empty gauge tap left an active state")
		var before: bool = skills.ranged_active
		skills.swap_weapon()
		_require(skills.ranged_active != before, "swap blocked after failed ultimate tap")
	# A consumed mouse release must not poison the equipment lock.
	player.primary_attack_held = true
	player.heavy_charging = true
	skills.swap_weapon()
	_require(not player.primary_attack_held and not player.heavy_charging, "stale primary hold survived swap reconciliation")
	skills.select_ultimate(&"thunder")
	skills.add_charge(100)
	_require(skills.activate_ultimate(), "valid activation failed after refused taps")
	skills.tick(3.0)
	_require(skills.ultimate == &"thunder" and _shots(world).is_empty(), "thunder launched before holding/releasing")
	skills.thunder_button(true)
	skills.tick(0.4)
	var low_ratio: float = skills.thunder_charge
	skills.cinema.vfx._process(0.016)
	_require(skills.cinema.vfx.held_javelin.visible, "charging javelin not visible")
	skills.thunder_button(false)
	skills.tick(0.001)
	var shots := _shots(world)
	_require(shots.size() == 1 and skills.ultimate == &"", "release did not launch exactly one projectile")
	var low_damage: float = shots[0].damage
	var low_length: float = shots[0].spear_visual.shaft.scale.y
	shots[0].free()
	skills.add_charge(100)
	skills.activate_ultimate()
	skills.thunder_button(true)
	skills.tick(4.0)
	_require(skills.thunder_charge == 1.0 and _shots(world).is_empty(), "full charge auto-fired or exceeded cap")
	skills.thunder_button(false)
	skills.tick(0.001)
	shots = _shots(world)
	_require(shots.size() == 1 and shots[0].damage > low_damage and shots[0].spear_visual.shaft.scale.y > low_length, "charge did not increase size and power")
	var position: Vector3 = shots[0].global_position
	shots[0]._physics_process(0.016)
	_require(shots[0].global_position != position and not shots[0].is_queued_for_deletion(), "visible projectile did not travel")
	shots[0].free()
	# Cancelling an unthrown javelin frees weapon switching and returns its cost.
	skills.add_charge(100)
	skills.activate_ultimate()
	skills.swap_weapon()
	_require(skills.ultimate == &"" and skills.ultimate_charge == 100, "unthrown javelin trapped weapon switching")
	var first := Target.new()
	world.add_child(first)
	first.add_to_group(&"enemy")
	first.position = Vector3(0, 0, -1)
	var second := Target.new()
	world.add_child(second)
	second.add_to_group(&"enemy")
	second.position = Vector3(2, 0, -1)
	skills.select_ultimate(&"aura")
	skills.activate_ultimate()
	skills.tick(0.13)
	skills.tick(0.08)
	_require(first.hits == 1 and first.health > 0 and skills.aura_target == second, "Aura did not retarget immediately after a nonlethal hit")
	player.position = Vector3(1.2, 0, -1)
	skills.tick(0.15)
	skills.tick(0.08)
	_require(second.hits == 1 and skills.aura_target == first, "Aura could not return to the living previous opponent")
	first.position = player.position + Vector3(0, 0, -5)
	skills.aura_target = first
	skills._begin_aura_leg()
	_require(skills.aura_motion == &"dash", "long transfer not a dash")
	first.position = player.position + Vector3(0, 0, -2.5)
	skills._begin_aura_leg()
	_require(skills.aura_motion == &"slide", "medium transfer not a slide")
	first.position = player.position + Vector3(0, 0, -1)
	skills._begin_aura_leg()
	_require(skills.aura_motion == &"jump", "short transfer not a directed jump")
	skills.end_ultimate()
	for index: int in 60: skills.cinema.advance(0.02)
	_require(skills.cinema.aura_camera_blend == 0, "Aura cinematic camera did not release")
	current_scene = null
	world.queue_free()
	await process_frame
	for failure: String in failures: push_error("[ULTIMATE CHARGE] " + failure)
	if failures.is_empty(): print("PASS: repeated refused ultimates, weapon lock recovery, charge/release projectile, icons and live-target ping-pong")
	quit(0 if failures.is_empty() else 1)

func _shots(world: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node: Node in world.get_children():
		if node is Shot and not node.is_queued_for_deletion(): result.append(node)
	return result

func _require(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
