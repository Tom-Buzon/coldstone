extends SceneTree

const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const ExternalBank = preload("res://scripts/animation/external_animation_bank.gd")
const MixamoCatalog = preload("res://scripts/enemy/mixamo_catalog.gd")
const Enemy = preload("res://scripts/enemy/athenian_enemy.gd")
const CrowdDirector = preload("res://scripts/ai/battle_crowd_director.gd")

class PhalanxProbeSoldier extends Node3D:
	var faction: StringName = &"athenian"
	var behavior_mode: StringName = &"phalanx"
	var ai_player: Node3D

	func is_dead_for_combat() -> bool:
		return false

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for archetype: StringName in Archetypes.all_ids():
		_audit_archetype(archetype)
	_audit_replacement_roles()
	_audit_specialized_roles()
	if failures.is_empty():
		print("ENEMY_ROSTER_AUDIT PASS: %d legacy + replacement enemies coherent" % Archetypes.all_ids().size())
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("ENEMY_ROSTER_AUDIT FAIL: %d issue(s)" % failures.size())
	quit(1)

func _audit_archetype(archetype: StringName) -> void:
	var profile := Archetypes.profile(archetype)
	var label := String(profile.get("display_name", archetype))
	var rank := StringName(profile.get("rank", &"troop"))
	var package_path := Archetypes.package_path(archetype)
	var replacement := Archetypes.roster_ids().has(archetype)
	if replacement:
		_require(not package_path.is_empty() and ResourceLoader.exists(package_path), "%s: character package missing (%s)" % [label, package_path])
	else:
		var appearance := MixamoCatalog.appearance(archetype, 0, 1, false)
		var appearance_path := String(appearance.get("path", ""))
		_require(ResourceLoader.exists(appearance_path), "%s: Mixamo appearance missing (%s)" % [label, appearance_path])
	_require(float(profile.get("health", 0.0)) > 0.0, "%s: health must be positive" % label)
	_require(float(profile.get("move_speed", 0.0)) > 0.0, "%s: move speed must be positive" % label)
	_require(float(profile.get("attack_damage", 0.0)) > 0.0, "%s: attack damage must be positive" % label)

	var has_shield := bool(profile.get("shield", false))
	var defense := StringName(profile.get("defense", &"none"))
	if has_shield:
		_require(defense == &"shield", "%s: visible shield has no shield defense" % label)
		_require(float(profile.get("guard_max", 0.0)) > 0.0, "%s: shield has no guard stamina" % label)
	elif defense == &"shield":
		_require(false, "%s: shield defense configured without a shield" % label)

	var delivery := StringName(profile.get("attack_delivery", &"melee"))
	if delivery == &"projectile":
		_require(StringName(profile.get("behavior", &"")) == &"ranged", "%s: projectile delivery requires ranged behavior" % label)
		_require(float(profile.get("projectile_speed", 0.0)) > 0.0, "%s: projectile speed must be positive" % label)

	var pattern: Array = Array(profile.get("combat_pattern", []))
	var phase_two: Array = Array(profile.get("phase_two_pattern", []))
	var external_keys: Array = Array(profile.get("external_animation_keys", []))
	if rank in [&"miniboss", &"boss"]:
		_require(pattern.size() >= 2, "%s: elite needs at least two pattern steps" % label)
	_audit_pattern(label, archetype, pattern, external_keys)
	_audit_pattern(label + " phase 2", archetype, phase_two, external_keys)
	if not phase_two.is_empty():
		_require(float(profile.get("phase_threshold", 0.0)) > 0.0, "%s: phase-two pattern has no health threshold" % label)
	for raw_key: Variant in external_keys:
		var key := StringName(raw_key)
		_require(ExternalBank.DONOR_PATHS.has(key), "%s: unknown external animation key %s" % [label, key])
		if ExternalBank.DONOR_PATHS.has(key):
			_require(ResourceLoader.exists(String(ExternalBank.DONOR_PATHS[key])), "%s: missing imported animation %s" % [label, ExternalBank.DONOR_PATHS[key]])

	print("ENEMY %-18s rank=%-8s weapon=%-10s defense=%-6s pattern=%d/%d donors=%d package=%s" % [
		label,
		String(rank),
		String(profile.get("weapon", &"none")),
		String(defense),
		pattern.size(),
		phase_two.size(),
		external_keys.size(),
		package_path.get_file() if replacement else String(MixamoCatalog.appearance(archetype, 0, 1, false).get("path", "")).get_file()
	])

func _audit_pattern(label: String, archetype: StringName, pattern: Array, external_keys: Array) -> void:
	var ids: Dictionary = {}
	for raw_step: Variant in pattern:
		_require(raw_step is Dictionary, "%s: pattern entry is not a Dictionary" % label)
		if not raw_step is Dictionary:
			continue
		var step := raw_step as Dictionary
		var id := StringName(step.get("id", StringName()))
		_require(id != StringName(), "%s: pattern step has no id" % label)
		_require(not ids.has(id), "%s: duplicate pattern step %s" % [label, id])
		ids[id] = true
		_require(float(step.get("windup", 0.0)) >= 0.10, "%s/%s: unreadable windup" % [label, id])
		_require(float(step.get("recovery", 0.0)) >= 0.10, "%s/%s: missing recovery" % [label, id])
		var external := StringName(step.get("external", StringName()))
		if external != StringName():
			_require(external_keys.has(external), "%s/%s: animation %s not declared in selective donor list" % [label, id, external])
		var mixamo := StringName(step.get("mixamo", StringName()))
		if mixamo != StringName():
			_require(MixamoCatalog.CLIP_FILES.has(mixamo), "%s/%s: unknown direct Mixamo clip %s" % [label, id, mixamo])
			var pool: Array = Array(MixamoCatalog.ATTACK_POOLS.get(archetype, []))
			_require(pool.has(mixamo), "%s/%s: direct Mixamo clip %s is not installed for this archetype" % [label, id, mixamo])

func _audit_specialized_roles() -> void:
	var light_infantry := Archetypes.profile(&"nathenian1")
	var hoplite := Archetypes.profile(&"ngeneral")
	var veteran := Archetypes.profile(&"ngeneral_veteran")
	var archer := Archetypes.profile(&"nsbire2")
	_require(StringName(light_infantry.get("weapon", &"")) == &"sword", "Nathenian1 did not keep its sword")
	_require(StringName(light_infantry.get("behavior", &"")) == &"guardian", "Nathenian1 is no longer light shield infantry")
	_require(StringName(hoplite.get("weapon", &"")) == &"spear", "hoplite did not receive a spear")
	_require(StringName(veteran.get("weapon", &"")) == &"spear", "veteran did not receive a spear")
	_require(bool(hoplite.get("shield", false)) and bool(veteran.get("shield", false)), "phalanx spear profiles require shields")
	_require(StringName(hoplite.get("behavior", &"")) == &"phalanx", "hoplite is not formation-driven")
	_require(StringName(veteran.get("behavior", &"")) == &"phalanx_veteran", "veteran is not formation-driven")
	_require(is_equal_approx(float(veteran.get("scale", 0.0)), float(hoplite.get("scale", 0.0)) * 1.20), "veteran is not exactly 20%% larger than the hoplite")
	_require(Archetypes.package_path(&"ngeneral") == Archetypes.package_path(&"ngeneral_veteran"), "hoplite and veteran do not share NGeneral")
	_require(Archetypes.package_path(&"nathenian1") != Archetypes.package_path(&"ngeneral"), "Nathenian1 still resolves to the NGeneral package")
	_require(Array(archer.get("external_animation_keys", [])).has(&"bow_aim"), "archer does not use the Mixamo bow layer")
	_require(not Array(archer.get("signature_animations", [])).has(&"Pistol_Shoot"), "archer still uses the cannon-like pistol clip")
	_require(float(archer.get("height_preference", 0.0)) > 0.0, "archer no longer values nearby high ground")
	_require(float(archer.get("ranged_retreat_delay", 0.0)) >= 0.75, "archer lost the punish window before retreating")
	var bow_owner := Enemy.new()
	var bow := bow_owner.call("_make_bow") as Node3D
	_require(is_equal_approx(absf(bow.rotation_degrees.z), 90.0), "bow is not perpendicular to the archer's forearm")
	bow.free()
	bow_owner.free()

	var director := CrowdDirector.new()
	var candidates: Array[Node3D] = []
	for index: int in range(4):
		var line_soldier := Enemy.new()
		line_soldier.behavior_mode = &"phalanx"
		candidates.append(line_soldier)
	var flank_veteran := Enemy.new()
	flank_veteran.behavior_mode = &"phalanx_veteran"
	candidates.append(flank_veteran)
	var slots: Dictionary = director.call("_build_phalanx_slots", candidates, 5)
	_require(slots.size() == 5, "five-soldier phalanx did not receive five unique assignments")
	var veteran_slot: Dictionary = slots.get(flank_veteran.get_instance_id(), {})
	_require(absi(int(veteran_slot.get("column", 0))) == 2, "veteran was not assigned to a phalanx flank")
	var limited_turn := director.call("_turn_flat_direction", Vector3.FORWARD, Vector3.RIGHT, deg_to_rad(10.0)) as Vector3
	_require(is_equal_approx(rad_to_deg(Vector3.FORWARD.angle_to(limited_turn)), 10.0), "phalanx direction ignores its angular speed limit")
	for candidate: Node3D in candidates:
		candidate.free()
	director.free()
	_audit_phalanx_assembly_then_advance()

func _audit_phalanx_assembly_then_advance() -> void:
	var director := CrowdDirector.new()
	root.add_child(director)
	var target := Node3D.new()
	target.position = Vector3(0.0, 0.0, -20.0)
	root.add_child(target)
	var soldiers: Array[PhalanxProbeSoldier] = []
	for index: int in range(5):
		var soldier := PhalanxProbeSoldier.new()
		soldier.ai_player = target
		soldier.position = Vector3((float(index) - 2.0) * 3.0, 0.0, 4.0 + float(index % 2))
		soldier.set_meta("formation_group", &"audit_cohort")
		root.add_child(soldier)
		soldier.add_to_group("phalanx_unit")
		soldiers.append(soldier)

	var staging_positions: Array[Vector3] = []
	for soldier: PhalanxProbeSoldier in soldiers:
		var assignment: Dictionary = director.phalanx_assignment(soldier, target, 5, 1.08, 1.18, 2.42)
		staging_positions.append(assignment.get("position", Vector3.ZERO))
		_require(not bool(assignment.get("cohort_formed", true)), "scattered phalanx advanced before assembling")
		_require((assignment.get("position", Vector3.ZERO) as Vector3).distance_to(target.position) > 10.0, "initial phalanx slots snapped beside the target")
	for index: int in range(soldiers.size()):
		soldiers[index].position = staging_positions[index]
	var formed_assignment: Dictionary = director.phalanx_assignment(soldiers[0], target, 5, 1.08, 1.18, 2.42)
	_require(bool(formed_assignment.get("cohort_formed", false)), "assembled phalanx never entered collective advance")
	var position_before: Vector3 = formed_assignment.get("position", Vector3.ZERO)
	for key: Variant in director.phalanx_cohort_states.keys():
		var state: Dictionary = director.phalanx_cohort_states[key]
		state["last_update"] = Time.get_ticks_msec() * 0.001 - 0.05
		director.phalanx_cohort_states[key] = state
	var advanced_assignment: Dictionary = director.phalanx_assignment(soldiers[0], target, 5, 1.08, 1.18, 2.42)
	var advance_distance := position_before.distance_to(advanced_assignment.get("position", position_before))
	_require(advance_distance > 0.01 and advance_distance <= 0.10, "formed phalanx did not advance through its slow shared anchor")
	for soldier: PhalanxProbeSoldier in soldiers:
		soldier.free()
	target.free()
	director.free()

func _audit_replacement_roles() -> void:
	var used_roles: Dictionary = {}
	for archetype: StringName in Archetypes.roster_ids():
		var profile := Archetypes.profile(archetype)
		var role := StringName(profile.get("role", StringName()))
		_require(role != StringName(), "%s has no gameplay role" % archetype)
		_require(not used_roles.has(role), "%s duplicates roster role %s" % [archetype, role])
		used_roles[role] = archetype

func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
