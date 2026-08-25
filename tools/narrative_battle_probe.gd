extends SceneTree

const NarrativeScene = preload("res://battle_03_narrative.tscn")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_packed(NarrativeScene)
	await scene_changed
	var mission := current_scene
	await process_frame
	await process_frame

	_require(mission.get_node_or_null("SpartanBattle01") != null, "player was not created")
	_require(mission.get_node_or_null("LastFlameWorldEnvironment") != null, "night environment is missing")
	_require(mission.get_node_or_null("ColdMoon") != null, "moon key light is missing")
	_require(mission.get_node_or_null("LastFlameQuestSystem") != null, "quest HUD is missing")
	_require(mission.get_node_or_null("NarrativeOverlay") != null, "narrative overlay is missing")
	_require(mission.find_children("StoryTrigger_*", "Area3D", true, false).size() == 5, "expected five story triggers")
	var environment := (mission.get_node("LastFlameWorldEnvironment") as WorldEnvironment).environment
	_require(environment != null and environment.ambient_light_energy >= 0.80, "mission lighting is still too dark")
	_require((mission.get("boss_brazier_lights") as Array).size() == 4, "final boss needs four dormant altar braziers")
	_require(int((mission.get("story_role_alive") as Dictionary).get(&"zone1_infantry_a", 0)) == 8, "eight zone-one soldiers must be present at mission start")

	var required_props: Array[StringName] = [
		&"catapult", &"big_rock", &"barricade", &"crates", &"jar", &"tomb", &"brazier",
		&"athena_statue", &"cypress_tree", &"fountain", &"temple", &"lion_statue", &"magistrate_statue"
	]
	for asset_id: StringName in required_props:
		_require(not mission.find_children("StoryProp_%s_*" % String(asset_id), "Node3D", true, false).is_empty(), "story prop is missing: %s" % String(asset_id))

	mission.call("_spawn_phalanx_cohort", &"zone_two", &"zone2_phalanx_left", Vector3(-13.0, 0.05, 7.0), 3, 4)
	mission.call("_spawn_phalanx_cohort", &"zone_two", &"zone2_phalanx_right", Vector3(13.0, 0.05, 7.0), 3, 4)
	await process_frame
	await process_frame
	var phalanx: Array[Node] = []
	for candidate: Node in get_nodes_in_group("enemy"):
		var formation_group := StringName(candidate.get_meta("formation_group", StringName()))
		if mission.is_ancestor_of(candidate) and formation_group in [&"story_zone2_phalanx_left", &"story_zone2_phalanx_right"]:
			phalanx.append(candidate)
	_require(phalanx.size() == 24, "agora must contain two 12-soldier phalanxes (got %d)" % phalanx.size())
	var veterans := 0
	var standards := 0
	var left_group := 0
	var right_group := 0
	for soldier: Node in phalanx:
		var archetype := StringName(soldier.get("archetype_id"))
		if archetype == &"ngeneral_veteran":
			veterans += 1
		elif archetype == &"ngeneral":
			standards += 1
		var group := StringName(soldier.get_meta("formation_group", StringName()))
		if group == &"story_zone2_phalanx_left":
			left_group += 1
		elif group == &"story_zone2_phalanx_right":
			right_group += 1
	_require(veterans == 8, "two phalanxes must have eight veteran flank guards")
	_require(standards == 16, "two phalanxes must have sixteen standard hoplites")
	_require(left_group == 12 and right_group == 12, "the fountain phalanxes must stay in separate cohorts")

	if failures.is_empty():
		print("NARRATIVE_BATTLE_PROBE PASS: eight starting soldiers, bright 3-act siege, 13 props, 5 triggers, two 12-soldier phalanxes")
		quit(0)
		return
	for failure: String in failures:
		push_error("[NARRATIVE BATTLE] " + failure)
	quit(1)

func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
