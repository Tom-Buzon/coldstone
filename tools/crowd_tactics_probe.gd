extends SceneTree

const CrowdDirector = preload("res://scripts/ai/battle_crowd_director.gd")

class TacticalDummy:
    extends Node3D

    var faction: StringName = &"athenian"
    var behavior_mode: StringName = &"aggressive"
    var ai_player: Node3D
    var dead := false

    func is_dead_for_combat() -> bool:
        return dead

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _probe_engagement_layers()
    _probe_dense_attack_budget()
    _probe_phalanx_intrusion_arc()
    if failures.is_empty():
        print("CROWD_TACTICS_PROBE PASS: contact ring, reserves, attack budget and intrusion-expulsion arc")
        quit(0)
        return
    for failure: String in failures:
        push_error(failure)
    quit(1)

func _probe_engagement_layers() -> void:
    var director := CrowdDirector.new()
    root.add_child(director)
    var target := Node3D.new()
    root.add_child(target)
    var contact_count := 0
    var reserve_count := 0
    var min_contact_distance := INF
    var min_reserve_distance := INF
    for index: int in range(12):
        var soldier := TacticalDummy.new()
        root.add_child(soldier)
        var assignment: Dictionary = director.engagement_assignment(soldier, target, 1.55)
        var distance: float = (assignment.get("position", Vector3.ZERO) as Vector3).distance_to(target.global_position)
        if bool(assignment.get("attack_ready", false)):
            contact_count += 1
            min_contact_distance = minf(min_contact_distance, distance)
        else:
            reserve_count += 1
            min_reserve_distance = minf(min_reserve_distance, distance)
    _expect(contact_count == 6, "dense engagement did not keep exactly six soldiers on the contact ring")
    _expect(reserve_count == 6, "second-wave soldiers were not assigned to a visible reserve ring")
    _expect(min_contact_distance >= 1.77, "contact ring still collapses inside readable personal space")
    _expect(min_reserve_distance > min_contact_distance + 1.0, "reserve ring is not separated from the contact fight")
    director.queue_free()
    target.queue_free()

func _probe_dense_attack_budget() -> void:
    var director := CrowdDirector.new()
    root.add_child(director)
    var target := Node3D.new()
    root.add_child(target)
    var nearby: Array = []
    for index: int in range(18):
        var soldier := TacticalDummy.new()
        soldier.position = Vector3(float(index % 6) - 2.5, 0.0, float(index / 6) - 1.0)
        root.add_child(soldier)
        nearby.append(soldier)
    director.spatial_grid[Vector2i.ZERO] = nearby
    _expect(director.attack_capacity_for(target) == 3, "dense crowd can still launch more than three simultaneous attacks")
    director.spatial_grid[Vector2i.ZERO] = nearby.slice(0, 4)
    _expect(director.attack_capacity_for(target) == 2, "small skirmish did not retain the two-attacker readability budget")
    director.queue_free()
    target.queue_free()

func _probe_phalanx_intrusion_arc() -> void:
    var director := CrowdDirector.new()
    root.add_child(director)
    var target := Node3D.new()
    root.add_child(target)
    var soldiers: Array[TacticalDummy] = []
    for index: int in range(10):
        var soldier := TacticalDummy.new()
        soldier.behavior_mode = &"phalanx_veteran" if index in [0, 4] else &"phalanx"
        soldier.ai_player = target
        soldier.position = Vector3(float(index % 5) - 2.0, 0.0, 4.0 + float(index / 5))
        soldier.set_meta("formation_group", &"probe_cohort")
        root.add_child(soldier)
        soldier.add_to_group("phalanx_unit")
        soldiers.append(soldier)

    # First query establishes the cohort anchor. Move everyone onto those staging
    # slots, then query again so the director recognizes a formed shield wall.
    var staging: Array[Vector3] = []
    for soldier: TacticalDummy in soldiers:
        var assignment: Dictionary = director.phalanx_assignment(soldier, target)
        staging.append(assignment.get("position", soldier.global_position))
    for index: int in range(soldiers.size()):
        soldiers[index].global_position = staging[index]
    for soldier: TacticalDummy in soldiers:
        director.phalanx_assignment(soldier, target)

    var state_key: Variant = director.phalanx_cohort_states.keys()[0]
    var state: Dictionary = director.phalanx_cohort_states[state_key]
    var old_facing: Vector3 = state.get("facing", Vector3.FORWARD)
    var old_front: Vector3 = state.get("front_center", Vector3.ZERO)
    target.global_position = old_front - old_facing * 2.25

    var breach_assignments: Array[Dictionary] = []
    for soldier: TacticalDummy in soldiers:
        breach_assignments.append(director.phalanx_assignment(soldier, target))
    var tactic := StringName(breach_assignments[0].get("breach_tactic", &"none"))
    var initial_displacement := (breach_assignments[0].get("position", Vector3.ZERO) as Vector3).distance_to(soldiers[0].global_position)

    # Mature the transition without sleeping so the geometric assertions inspect
    # the final crescent rather than its first blended frame.
    state = director.phalanx_cohort_states[state_key]
    state["breach_started_at"] = Time.get_ticks_msec() * 0.001 - 2.0
    director.phalanx_cohort_states[state_key] = state
    breach_assignments.clear()
    for soldier: TacticalDummy in soldiers:
        breach_assignments.append(director.phalanx_assignment(soldier, target))

    var responders := 0
    var support := 0
    var old_centroid := Vector3.ZERO
    for soldier: TacticalDummy in soldiers:
        old_centroid += soldier.global_position
    old_centroid /= float(soldiers.size())
    var mass_side := old_centroid - target.global_position
    mass_side.y = 0.0
    mass_side = mass_side.normalized()
    var all_on_mass_side := true
    var has_left_tip := false
    var has_right_tip := false
    var mass_right := mass_side.cross(Vector3.UP).normalized()
    for assignment: Dictionary in breach_assignments:
        if bool(assignment.get("breach_can_attack", false)):
            responders += 1
        else:
            support += 1
        var from_target: Vector3 = assignment.get("position", Vector3.ZERO) - target.global_position
        from_target.y = 0.0
        all_on_mass_side = all_on_mass_side and from_target.dot(mass_side) > 0.25
        has_left_tip = has_left_tip or from_target.dot(mass_right) < -1.0
        has_right_tip = has_right_tip or from_target.dot(mass_right) > 1.0
    _expect(bool(breach_assignments[0].get("breach", false)), "player crossing behind the spear line did not trigger a cohort response")
    _expect(tactic == &"expulsion_arc", "formation intrusion did not select the shield expulsion arc")
    _expect(initial_displacement < 0.10, "expulsion arc snapped to its final shape instead of blending from the shield line")
    _expect(all_on_mass_side, "arc placed files face-to-face on opposite sides of the player")
    _expect(has_left_tip and has_right_tip, "expulsion formation did not curve both tips around the player")
    _expect(responders > 0 and support > 0, "arc did not preserve distinct pressing and supporting ranks")
    director.queue_free()
    target.queue_free()

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
