extends SceneTree

const Player = preload("res://scripts/player.gd")
const Flame = preload("res://scripts/abilities/flame_wall.gd")
var failures: Array[String] = []

class Pickup extends Area3D:
	var collected := 0
	func can_be_collected_by(player: Node3D) -> bool: return player.global_position.distance_to(global_position) < 2.0
	func collect_by(_player: Node3D) -> bool:
		collected += 1
		return true

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := Player.new()
	world.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.skills.profile.reset(true)
	var skills: Node = player.skills
	var input: Node = skills.controls
	# Reproduce the reported sequence: fill FIRST, select afterwards.
	for id: StringName in [&"aura", &"flame", &"thunder", &"ares"]:
		skills.add_charge(100)
		_require(skills.select_ultimate(id), "late selection refused")
		_require(skills.ultimate_charge == 100, "selection reset full gauge")
		_require(skills.activate_ultimate(), "late-selected ultimate did not activate: " + String(id))
		_require(skills.ultimate == id and skills.ultimate_charge == 0, "wrong ultimate or cost")
		skills.end_ultimate()
	# A tap can begin/end between two physics ticks; request must survive.
	skills.add_charge(100)
	input.ultimate_button(true)
	input.ultimate_button(false)
	_require(input.activation_pending, "short tap disappeared")
	skills._process(0.01)
	_require(skills.ultimate == &"ares", "buffered tap did not launch")
	skills.end_ultimate()
	skills.add_charge(100)
	input.ultimate_button(true)
	input.advance(0.25)
	_require(input.wheel.visible, "hold failed to open wheel")
	input.wheel.choose(Vector2.RIGHT)
	input.ultimate_button(false)
	_require(skills.profile.selected_ultimate == &"flame" and not input.activation_pending, "wheel release launched instead of selecting")
	_require(skills.ultimate_charge == 100, "wheel spent the gauge")
	skills.profile.set_feature(&"thunder", false)
	input.ultimate_button(true)
	input.advance(0.3)
	input.wheel.choose(Vector2.DOWN)
	input.ultimate_button(false)
	_require(skills.profile.selected_ultimate == &"flame", "locked wheel entry became selected")
	# E short swaps; hold collects ONCE and must never swap on release.
	var pickup := Pickup.new()
	world.add_child(pickup)
	pickup.add_to_group(&"equipment_pickup")
	input.weapon_button(true, true)
	input.advance(0.1)
	input.weapon_button(false, true)
	_require(skills.ranged_active and pickup.collected == 0, "short E collected an object")
	input.weapon_button(true, true)
	input.advance(0.5)
	input.advance(0.5)
	input.weapon_button(false, true)
	_require(pickup.collected == 1 and skills.ranged_active, "held E repeated pickup or swapped")
	input.weapon_button(true, true)
	input.cancel()
	input.weapon_button(false, true)
	_require(skills.ranged_active, "cancelled hold swapped on resume")
	# World-height framing and complete release of camera/time state.
	player.global_position.y = 12
	player._update_camera(1)
	skills.cinema.begin_plunge()
	for i: int in 12: skills.cinema.advance(0.025)
	var anchor: float = skills.cinema.anchor_y
	player.global_position.y = 2
	player._update_camera(0.05)
	_require(absf(player.camera.global_position.y - anchor) < 0.25, "plunge camera lost its original world height")
	skills.cinema.impact(player.global_position, 5)
	for i: int in 60:
		skills.cinema.advance(0.025)
		player._update_camera(0.025)
	_require(skills.cinema.camera_weight == 0 and player.combat_feedback.skill_time_scale == 1.0, "camera/slow motion stuck after impact")
	# F has a visible armed state before the dash, then contacts follow motion.
	skills.ranged_active = false
	input.edge_down = true
	skills.cinema.vfx._process(0.016)
	_require(skills.cinema.vfx.blade.visible, "F armed blade is invisible")
	player.dash_time = 0.2
	skills.tick(0.016)
	_require(skills.edge_active, "held F did not activate during dash")
	input.cancel()
	skills.tick(0.016)
	_require(not skills.edge_active, "F remained active after cancellation")
	current_scene = null
	world.queue_free()
	await process_frame
	for failure: String in failures: push_error("[SKILL REVISION] " + failure)
	if failures.is_empty(): print("PASS: late ultimate selection, buffered taps, wheel, hold pickup, plunge camera release and visible F")
	quit(0 if failures.is_empty() else 1)

func _require(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
