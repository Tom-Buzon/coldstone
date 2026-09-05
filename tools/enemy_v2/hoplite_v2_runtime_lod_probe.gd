extends SceneTree

const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ProjectSettings.set_setting("hoplite/enemy_lod/enabled", true)
	ProjectSettings.set_setting("hoplite/enemy_lod/near_distance", 10.0)
	ProjectSettings.set_setting("hoplite/enemy_lod/far_distance", 26.0)
	ProjectSettings.set_setting("hoplite/enemy_lod/cull_distance", 65.0)
	ProjectSettings.set_setting("hoplite/enemy_lod/medium_animation_hz", 24.0)
	ProjectSettings.set_setting("hoplite/enemy_lod/far_animation_hz", 10.0)
	ProjectSettings.set_setting("hoplite/enemy_lod/shadow_distance", 5.5)

	var reference := Node3D.new()
	reference.name = "LODReference"
	get_root().add_child(reference)
	var distances: Array[float] = [4.0, 18.0, 40.0, 80.0]
	var expected_levels: Array[int] = [0, 1, 2, 3]
	var actors: Array[HopliteEnemyActorV2] = []
	for index: int in range(distances.size()):
		var actor := Factory.create(&"ngeneral") as HopliteEnemyActorV2
		actor.lod_reference = reference
		actor.position = Vector3(distances[index], 0.0, 0.0)
		actor.initial_semantic = &"phalanx_cycle"
		get_root().add_child(actor)
		actors.append(actor)
		_expect(int(actor.get_meta("enemy_v2_lod_level", -1)) == expected_levels[index], "distance %.1f resolved to the wrong LOD" % distances[index])
		_expect(actor.presentation.lod_meshes[0].visibility_range_end == 10.0, "LOD0 does not follow the active near distance")
		_expect(actor.presentation.lod_meshes[1].visibility_range_begin == 10.0 and actor.presentation.lod_meshes[1].visibility_range_end == 26.0, "LOD1 does not follow the active profile")
		_expect(actor.presentation.lod_meshes[2].visibility_range_begin == 26.0 and actor.presentation.lod_meshes[2].visibility_range_end == 65.0, "LOD2 is not culled at the active distance")
		for item: GeometryInstance3D in actor.equipment.geometry:
			_expect(item.visibility_range_end == 65.0, "equipment does not share the body cull distance")
		var should_be_manual := expected_levels[index] > 0
		_expect((actor.animation.player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL) == should_be_manual, "animation cadence mode is wrong at LOD%d" % expected_levels[index])
		if actor.health_component != null and actor.health_component.anatomy != null:
			var expected_anatomy := distances[index] <= HopliteV2HealthComponent.ANATOMY_QUERY_DISTANCE and expected_levels[index] == 0
			_expect(actor.health_component.anatomy.query_enabled == expected_anatomy, "anatomy query LOD is wrong at %.1f m" % distances[index])
			_expect(actor.health_component.anatomy.collision_layer == (8 if expected_anatomy else 0), "anatomy collision layer is wrong at %.1f m" % distances[index])

	ProjectSettings.set_setting("hoplite/enemy_lod/enabled", false)
	actors[2]._update_performance_lod()
	_expect(int(actors[2].get_meta("enemy_v2_lod_level", -1)) == 0, "disabled LOD must restore full presentation")
	_expect(actors[2].presentation.lod_meshes[0].visible and not actors[2].presentation.lod_meshes[1].visible and not actors[2].presentation.lod_meshes[2].visible, "disabled LOD must render only LOD0")
	_expect(actors[2].animation.player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE, "disabled LOD must restore autonomous animation")

	for actor: HopliteEnemyActorV2 in actors:
		actor.free()
	reference.free()
	if failures.is_empty():
		print("HOPLITE_V2_RUNTIME_LOD_PROBE PASS levels=0/1/2/3 ranges=10/26/65 animation=24/10Hz")
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 RUNTIME LOD] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
