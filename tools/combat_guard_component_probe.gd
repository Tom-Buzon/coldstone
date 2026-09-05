extends SceneTree

const GuardComponent = preload("res://scripts/combat/guard_component.gd")
const HitEventScript = preload("res://scripts/combat/hit_event.gd")
const STANDARD_PROFILE := preload("res://data/combat/guard_profiles/hoplite_v2_standard.tres")
const VETERAN_PROFILE := preload("res://data/combat/guard_profiles/hoplite_v2_veteran.tres")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var defender := Node3D.new()
	var source := Node3D.new()
	root.add_child(defender)
	root.add_child(source)
	source.position = Vector3(0.0, 0.0, 2.0)
	var guard := GuardComponent.new() as CombatGuardComponent
	defender.add_child(guard)
	_expect(guard.configure(defender, STANDARD_PROFILE), "standard profile could not configure the shared guard")

	var light := _hit(source, &"light1")
	_expect(guard.resolve_guard(light, 0.50), "light contact was not intercepted")
	_expect(not light.guard_broken and light.contact_type == &"shield", "high-roll light attack unexpectedly broke guard")

	light = _hit(source, &"light2")
	_expect(guard.resolve_guard(light, 0.0), "low-roll light contact was not intercepted")
	_expect(light.guard_broken and light.contact_type == &"guard_break", "low-roll light attack did not use its configured break chance")
	guard.force_recover()

	var heavy := _hit(source, &"heavy")
	heavy.attack_charge_ratio = 0.50
	guard.resolve_guard(heavy, 0.20)
	_expect(heavy.guard_broken, "ordinary heavy attack did not have a higher break chance")
	guard.force_recover()

	var charged := _hit(source, &"heavy")
	charged.attack_charge_ratio = 1.0
	guard.resolve_guard(charged, 1.0)
	_expect(charged.guard_broken and charged.guard_bypassed, "fully charged heavy did not bypass the probability roll and guard")
	guard.force_recover()

	var spiral_up := _hit(source, &"spin360")
	spiral_up.attack_vertical_direction = 1
	guard.resolve_guard(spiral_up, 0.70)
	_expect(spiral_up.guard_broken, "Spiral Up did not receive its large guard-break chance")
	guard.force_recover()

	var spiral_down := _hit(source, &"spin360")
	spiral_down.attack_vertical_direction = -1
	guard.resolve_guard(spiral_down, 0.76)
	_expect(spiral_down.guard_broken, "Spiral Down did not receive its large guard-break chance")
	guard.force_recover()

	var veteran := GuardComponent.new() as CombatGuardComponent
	defender.add_child(veteran)
	veteran.configure(defender, VETERAN_PROFILE)
	var resisted_heavy := _hit(source, &"heavy")
	resisted_heavy.attack_charge_ratio = 0.5
	veteran.resolve_guard(resisted_heavy, 0.25)
	_expect(not resisted_heavy.guard_broken, "veteran resistance did not reduce the ordinary heavy chance")

	_expect(STANDARD_PROFILE.stun_seconds > VETERAN_PROFILE.stun_seconds, "class profiles cannot customize stun duration")
	_expect(STANDARD_PROFILE.step_back_distance > VETERAN_PROFILE.step_back_distance, "class profiles cannot customize the backward step")
	defender.free()
	source.free()
	if failures.is_empty():
		print("COMBAT_GUARD_COMPONENT_PROBE PASS light=low heavy=medium charged=guaranteed spirals=high veteran=resistant")
		quit(0)
		return
	for failure: String in failures:
		push_error("[COMBAT GUARD] " + failure)
	quit(1)


func _hit(source: Node3D, slot: StringName) -> HopliteHitEvent:
	var result := HitEventScript.new() as HopliteHitEvent
	result.source = source
	result.attack_slot = slot
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
