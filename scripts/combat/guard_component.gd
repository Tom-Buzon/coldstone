extends Node
class_name CombatGuardComponent

signal guard_held(hit: Variant, attack_kind: StringName, break_chance: float)
signal guard_broken(
	hit: Variant,
	attack_kind: StringName,
	stun_seconds: float,
	step_back_distance: float,
	step_direction: Vector3
)
signal guard_recovered()

var combatant: Node3D
var profile: CombatGuardProfile
var broken: bool = false
var stun_remaining: float = 0.0
var _rng := RandomNumberGenerator.new()


func configure(combatant_value: Node3D, profile_value: CombatGuardProfile) -> bool:
	combatant = combatant_value
	profile = profile_value
	if combatant == null or profile == null:
		return false
	_rng.seed = int(combatant.get_instance_id()) * 7919 + 104729
	set_physics_process(false)
	return true


func can_guard() -> bool:
	return combatant != null and is_instance_valid(combatant) and not broken and not bool(combatant.get_meta(&"skill_shield_destroyed", false))


## Returns true when the raised guard intercepted the contact. A broken guard
## still intercepts this contact, but marks the shared HitEvent and emits the
## reaction contract used by the combatant's own movement/state controller.
func resolve_guard(hit: Variant, roll_override: float = -1.0) -> bool:
	if hit == null or not can_guard():
		return false
	if hit is HopliteHitEvent and hit.destroy_shield:
		if combatant.has_method("destroy_skill_shield"):
			combatant.destroy_skill_shield()
		hit.guard_bypassed = true
		hit.guard_broken = true
		return true
	var attack_kind := classify_attack(hit)
	var guaranteed := attack_kind == &"heavy_fully_charged"
	var chance := 1.0 if guaranteed else _break_chance(attack_kind) / maxf(profile.break_resistance, 0.1)
	chance = clampf(chance, 0.0, 1.0)
	var roll := clampf(roll_override, 0.0, 1.0) if roll_override >= 0.0 else _rng.randf()
	if guaranteed or roll < chance:
		broken = true
		stun_remaining = profile.stun_seconds
		set_physics_process(true)
		hit.guard_broken = true
		hit.guard_bypassed = guaranteed
		hit.contact_type = &"guard_break"
		guard_broken.emit(
			hit,
			attack_kind,
			profile.stun_seconds,
			profile.step_back_distance,
			_step_direction_from(hit.source as Node3D)
		)
	else:
		hit.guard_broken = false
		hit.guard_bypassed = false
		hit.contact_type = &"shield"
		guard_held.emit(hit, attack_kind, chance)
	return true


func force_recover() -> void:
	var was_broken := broken
	broken = false
	stun_remaining = 0.0
	set_physics_process(false)
	if was_broken:
		guard_recovered.emit()


func _physics_process(delta: float) -> void:
	if not broken:
		set_physics_process(false)
		return
	stun_remaining = maxf(0.0, stun_remaining - delta)
	if stun_remaining <= 0.0:
		force_recover()


func classify_attack(hit: Variant) -> StringName:
	if hit == null:
		return &"unknown"
	var slot := StringName(hit.attack_slot)
	if slot in [&"light1", &"light2", &"light3", &"counter_wave"]:
		return &"light"
	if slot == &"heavy":
		if float(hit.attack_charge_ratio) >= profile.fully_charged_threshold:
			return &"heavy_fully_charged"
		return &"heavy"
	if slot == &"spin360":
		var vertical_direction := int(hit.attack_vertical_direction)
		return &"spiral_up" if vertical_direction > 0 else &"spiral_down"
	return &"unknown"


func _break_chance(attack_kind: StringName) -> float:
	match attack_kind:
		&"light":
			return profile.light_break_chance
		&"heavy":
			return profile.heavy_break_chance
		&"spiral_up":
			return profile.spiral_up_break_chance
		&"spiral_down":
			return profile.spiral_down_break_chance
		_:
			return profile.fallback_break_chance


func _step_direction_from(source: Node3D) -> Vector3:
	if source != null and is_instance_valid(source):
		var away := combatant.global_position - source.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			return away.normalized()
	var fallback := -combatant.global_basis.z
	fallback.y = 0.0
	return fallback.normalized()
