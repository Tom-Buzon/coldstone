extends SceneTree

const NarrativeScene = preload("res://battle_03_narrative.tscn")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_packed(NarrativeScene)
	await scene_changed
	await process_frame
	var mission := current_scene
	var constants: Dictionary = mission.get_script().get_script_constant_map()
	_require(int(constants.get("ZONE_ONE_PLANNED_TOTAL", 0)) == 88, "zone one plan must total 88 enemies")
	_require(int(constants.get("ZONE_TWO_PLANNED_TOTAL", 0)) == 46, "zone two plan must total 46 enemies")
	_require(int(constants.get("ZONE_THREE_PRE_BOSS_TOTAL", 0)) == 51, "zone three plan must total 51 enemies before Théron")
	_require(int((mission.get("story_role_alive") as Dictionary).get(&"zone1_infantry_a", 0)) == 8, "zone one must start with an eight-soldier vanguard")

	# Clearing the visible vanguard before crossing the act-one trigger must not
	# accidentally call the later twenty-soldier battalion ahead of the story beat.
	mission.set("story_role_alive", {&"zone1_infantry_a": 1})
	mission.set("story_encounter_alive", {&"zone_one": 1})
	mission.call("_on_story_enemy_died", null, &"zone_one", &"zone1_infantry_a")
	_require(not bool(mission.get("zone_one_second_battalion_spawned")), "clearing the starting vanguard must not spawn the second battalion early")

	mission.call("_spawn_zone_two")
	await process_frame
	var roles: Dictionary = mission.get("story_role_alive")
	var encounters: Dictionary = mission.get("story_encounter_alive")
	_require(int(encounters.get(&"zone_two", 0)) == 46, "zone two runtime count must be 46")
	_require(int(roles.get(&"zone2_phalanx_left", 0)) == 12, "left fountain phalanx must have 12 soldiers")
	_require(int(roles.get(&"zone2_phalanx_right", 0)) == 12, "right fountain phalanx must have 12 soldiers")
	_require(int(roles.get(&"zone2_front_infantry", 0)) == 6, "fountain front must have six infantry")
	_require(int(roles.get(&"zone2_front_levies", 0)) == 6, "fountain front must have six levies")
	_require(int(roles.get(&"zone2_left_archers", 0)) == 3 and int(roles.get(&"zone2_right_archers", 0)) == 3, "each phalanx must have three archers")
	_require(int(roles.get(&"zone2_left_heavy", 0)) == 1 and int(roles.get(&"zone2_right_heavy", 0)) == 1, "each phalanx must have one Nathenian2 soldier")
	_require(int(roles.get(&"zone2_left_centurion", 0)) == 1 and int(roles.get(&"zone2_right_centurion", 0)) == 1, "each phalanx must have one centurion")

	# The local, clearly displayed 24-hoplite objective opens the sanctuary. The
	# 22 support enemies may still be alive and must never hide the progression key.
	roles[&"zone2_phalanx_left"] = 0
	roles[&"zone2_phalanx_right"] = 1
	mission.set("story_role_alive", roles)
	encounters[&"zone_two"] = 23
	mission.set("story_encounter_alive", encounters)
	mission.call("_on_story_enemy_died", null, &"zone_two", &"zone2_phalanx_right")
	await process_frame
	_require(bool(mission.get("zone_two_completed")), "the last phalanx death must complete zone two while supports remain")
	_require(int((mission.get("story_encounter_alive") as Dictionary).get(&"zone_two", 0)) == 22, "zone two must open with its 22 support enemies still alive")
	var sanctuary_gate := mission.get("sanctuary_gate") as AnimatableBody3D
	_require(sanctuary_gate != null and (mission.get("opened_gates") as Dictionary).has(sanctuary_gate.get_instance_id()), "the last phalanx death must physically unlock the sanctuary gate")

	for enemy: Node in get_nodes_in_group("enemy"):
		if mission.is_ancestor_of(enemy):
			enemy.queue_free()
	await process_frame
	await process_frame
	mission.set("story_role_alive", {})
	mission.set("story_encounter_alive", {&"zone_three": 0})
	mission.set("zone_three_army_spawned", false)
	mission.call("_spawn_zone_three_army")
	await process_frame
	roles = mission.get("story_role_alive")
	encounters = mission.get("story_encounter_alive")
	_require(int(encounters.get(&"zone_three", 0)) == 43, "zone three main army must have 43 soldiers before pressure levies")
	_require(int(roles.get(&"zone3_great_phalanx", 0)) == 28, "final phalanx must have 28 spearmen")
	_require(int(roles.get(&"zone3_archers", 0)) == 8, "final phalanx must be protected by eight archers")
	_require(int(roles.get(&"zone3_heavy_guard", 0)) == 4, "final phalanx must be protected by four Nathenian2 soldiers")
	_require(int(roles.get(&"zone3_centurions", 0)) == 3, "three centurions must lock the final boss")
	_require(int(mission.get("zone_three_centurions_alive")) == 3, "centurion objective must begin at three")

	# The second champion, not cleanup of every levy, is the chapter-one gate key.
	mission.set("story_encounter_alive", {&"zone_one": 12})
	mission.set("story_role_alive", {&"zone1_miniboss_b": 1})
	mission.call("_on_story_enemy_died", null, &"zone_one", &"zone1_miniboss_b")
	await process_frame
	_require(bool(mission.get("zone_one_completed")), "second champion death must complete zone one")
	_require(int((mission.get("story_encounter_alive") as Dictionary).get(&"zone_one", 0)) == 11, "zone one must open while ordinary enemies remain")
	var first_gate := mission.get("first_gate") as AnimatableBody3D
	_require(first_gate != null and (mission.get("opened_gates") as Dictionary).has(first_gate.get_instance_id()), "second champion death must physically unlock the first gate")

	if failures.is_empty():
		print("LAST_FLAME_WAVE_PROBE PASS: planned 88 / 46 / 51; champion and phalanx gates are objective-driven")
		quit(0)
		return
	for failure: String in failures:
		push_error("[LAST FLAME WAVES] " + failure)
	quit(1)

func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
