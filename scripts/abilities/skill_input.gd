extends Node

const Wheel = preload("res://scripts/ui/ultimate_wheel.gd")
const HOLD_ULTIMATE := 0.24
const HOLD_PICKUP := 0.42
var runtime: Node
var wheel: Control
var ultimate_held := false
var ultimate_elapsed := 0.0
var weapon_held := false
var weapon_elapsed := 0.0
var pickup_attempted := false
var weapon_tap := false
var pickup_target: Area3D
var activation_pending := false
var plunge_pending := false
var edge_pressed := false
var edge_down := false

func configure(value: Node) -> void:
	runtime = value
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	wheel = Wheel.new()
	wheel.runtime = runtime
	layer.add_child(wheel)

func _input(event: InputEvent) -> void:
	if get_tree().paused: return
	if wheel.visible:
		if event is InputEventMouseMotion:
			wheel.pointer += event.relative * 0.015
			wheel.pointer = wheel.pointer.limit_length(1.5)
			wheel.choose(wheel.pointer)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			cancel()
			get_viewport().set_input_as_handled()
			return
	# Cursor capture is a camera preference, not a combat lock. Cancelling here
	# erased LMB holds on motion/release while polling-based spirals still worked.
	if event is InputEventKey and event.echo: return
	if runtime.ultimate == &"thunder" and event.is_action(&"attack_primary"):
		runtime.thunder_button(event.is_action_pressed(&"attack_primary"))
		get_viewport().set_input_as_handled()
	elif event.is_action(&"skill_ultimate"):
		ultimate_button(event.is_pressed())
		get_viewport().set_input_as_handled()
	elif event.is_action(&"skill_weapon_swap") or event.is_action(&"interact"):
		weapon_button(event.is_pressed(), event.is_action(&"skill_weapon_swap"))
		get_viewport().set_input_as_handled()
	elif event.is_action(&"skill_ultimate_next") and event.is_pressed():
		runtime.cycle_ultimate()
		get_viewport().set_input_as_handled()
	elif event.is_action(&"skill_plunge") and event.is_pressed():
		plunge_pending = true
		get_viewport().set_input_as_handled()
	elif event.is_action(&"skill_edge"):
		edge_down = event.is_pressed()
		edge_pressed = edge_down
		if edge_down: runtime.notice("LAME ARMÉE · dash ou spirale" if runtime.active(&"edge") else "Lame horizontale verrouillée · Paramètres → Compétences")
		get_viewport().set_input_as_handled()

func ultimate_button(pressed: bool) -> void:
	if pressed:
		if ultimate_held: return
		ultimate_held = true
		ultimate_elapsed = 0.0
	elif ultimate_held:
		ultimate_held = false
		if wheel.visible:
			runtime.select_ultimate(Wheel.IDS[wheel.selected])
			wheel.visible = false
		else:
			activation_pending = true

func weapon_button(pressed: bool, allow_swap: bool) -> void:
	if pressed:
		if weapon_held: return
		weapon_held = true
		weapon_tap = allow_swap
		weapon_elapsed = 0.0
		pickup_attempted = false
		pickup_target = runtime.player.nearest_equipment_pickup(true)
	elif weapon_held:
		weapon_held = false
		if not pickup_attempted and weapon_tap: runtime.swap_weapon()

func advance(real_delta: float) -> void:
	if ultimate_held:
		ultimate_elapsed += real_delta
		if ultimate_elapsed >= HOLD_ULTIMATE and not wheel.visible:
			# Releasing LMB while choosing must not fire when the wheel closes.
			runtime.thunder_held = false
			runtime.thunder_release_pending = false
			runtime.player._reset_primary_attack_input()
			runtime.player._cancel_heavy_charge()
			wheel.open()
	if wheel.visible and InputMap.has_action(&"camera_left"):
		wheel.choose(Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down", 0.3))
	if weapon_held:
		weapon_elapsed += real_delta
		if weapon_elapsed >= HOLD_PICKUP and not pickup_attempted:
			pickup_attempted = true
			if is_instance_valid(pickup_target) and runtime.player.nearest_equipment_pickup(true) == pickup_target:
				runtime.player._collect_nearest_equipment_pickup()
			else: runtime.notice("Aucun objet à portée")

func reconcile_releases() -> void:
	# Event routing may consume a release while a menu or window takes focus.
	if runtime.thunder_held and not Input.is_action_pressed(&"attack_primary"): runtime.thunder_button(false)
	if ultimate_held and not Input.is_action_pressed(&"skill_ultimate"): ultimate_button(false)
	if weapon_held and not Input.is_action_pressed(&"skill_weapon_swap") and not Input.is_action_pressed(&"interact"): weapon_button(false, weapon_tap)

func cancel() -> void:
	if runtime != null:
		runtime.cancel_preparation()
		runtime.thunder_held = false
		runtime.thunder_release_pending = false
		runtime.player._reset_primary_attack_input()
		runtime.player._cancel_heavy_charge()
	ultimate_held = false
	weapon_held = false
	activation_pending = false
	plunge_pending = false
	edge_down = false
	edge_pressed = false
	if wheel != null: wheel.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED: cancel()
