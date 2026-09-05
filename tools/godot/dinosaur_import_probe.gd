extends SceneTree

const EnemyFactoryScript = preload("res://scripts/enemy/enemy_factory.gd")
const EnemyArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")
const FaunaAgentScript = preload("res://scripts/fauna/fauna_agent.gd")
const FaunaSettingsScript = preload("res://scripts/fauna/fauna_settings.gd")
const HitEventScript = preload("res://scripts/combat/hit_event.gd")

var _stage: Node3D
var _failed := false


func _initialize() -> void:
	_stage = Node3D.new()
	_stage.name = "DinosaurImportProbe"
	root.add_child(_stage)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_check(not bool(EnemyArchetypesScript.profile(&"velociraptor").get("forge_default_match_perfect_hitbox", true)), "velociraptor giant traversal defaults to disabled")
	for archetype: StringName in [&"velociraptor", &"tyrannosaurus"]:
		var enemy := EnemyFactoryScript.spawn(_stage, archetype, Vector3.ZERO, null, {
			"ai_enabled": false,
			"match_perfect_hitbox": true,
			"giant_traversal_mode": &"exact",
		}) as HopliteDinosaurEnemy
		await process_frame
		_check_dinosaur(enemy, archetype)
		_check_dinosaur_lod(enemy, archetype)
		if archetype == &"velociraptor":
			await _check_raptor_attack_cycle(enemy)
		else:
			_check_trex_charge_sequence(enemy)
		_check_decapitation(enemy, archetype)
		await process_frame
	var default_raptor := EnemyFactoryScript.spawn(_stage, &"velociraptor", Vector3.ZERO, null, {
		"ai_enabled": false,
	}) as HopliteDinosaurEnemy
	await process_frame
	_check(default_raptor != null and not default_raptor.match_perfect_hitbox and default_raptor.traversal_by_zone.is_empty(), "new velociraptor keeps giant traversal disabled until explicitly checked")
	if default_raptor != null:
		default_raptor.queue_free()
	var player_stub := Node3D.new()
	_stage.add_child(player_stub)
	var fauna := FaunaAgentScript.new() as HopliteFaunaAgent
	_stage.add_child(fauna)
	var definition := FaunaSettingsScript.definition(&"pterodactyl")
	var configured := fauna.configure(definition, 0, player_stub, _stage, 42, Vector3(0.0, 20.0, 0.0), 4.0)
	await process_frame
	_check(configured, "pterodactyl configure")
	var collisions := fauna.find_children("*", "CollisionObject3D", true, false)
	_check(collisions.is_empty() or _all_collisions_disabled(collisions), "pterodactyl has no active collider")
	var animation_players := fauna.find_children("*", "AnimationPlayer", true, false)
	_check(not animation_players.is_empty(), "pterodactyl AnimationPlayer")
	if not animation_players.is_empty():
		var animation_player := animation_players[0] as AnimationPlayer
		_check(String(animation_player.current_animation).to_lower().contains("animation"), "pterodactyl flight loop selected")
	print("[DINOSAUR PROBE] RESULT=", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)


func _check_dinosaur(enemy: HopliteDinosaurEnemy, archetype: StringName) -> void:
	_check(enemy != null, "%s instantiated" % String(archetype))
	if enemy == null:
		return
	_check(enemy.skeleton != null and enemy.skeleton.get_bone_count() > 0, "%s skeleton" % String(archetype))
	_check(not enemy.dinosaur_animation_players.is_empty(), "%s animations" % String(archetype))
	var collider_authoritative := bool(enemy.get_meta(&"camera_occlusion_collider_authoritative", false))
	_check(collider_authoritative == (archetype == &"tyrannosaurus"), "%s camera occlusion collider authority" % String(archetype))
	var meshes: Array[Node] = enemy.dinosaur_visual.find_children("*", "MeshInstance3D", true, false)
	_check(not meshes.is_empty(), "%s rendered mesh exists" % String(archetype))
	for candidate: Node in meshes:
		var mesh_instance := candidate as MeshInstance3D
		_check(mesh_instance != null and mesh_instance.visible, "%s mesh is visible" % String(archetype))
		if archetype == &"tyrannosaurus" and mesh_instance != null:
			_check(mesh_instance.custom_aabb.size.length() > mesh_instance.get_aabb().size.length(), "tyrannosaurus animated culling bounds")
			_check(mesh_instance.ignore_occlusion_culling, "tyrannosaurus ignores occlusion culling")
	_check(enemy.anatomy != null and enemy.anatomy.zone_runtime.size() >= 10, "%s anatomy zones" % String(archetype))
	_check(enemy.traversal_by_zone.size() == enemy.anatomy.zone_runtime.size(), "%s traversal follows anatomy" % String(archetype))
	var farthest := 0.0
	for raw_zone: Variant in enemy.anatomy.zone_runtime.keys():
		farthest = maxf(farthest, enemy.global_position.distance_to(enemy.anatomy.get_zone_world_center(StringName(raw_zone))))
	_check(farthest <= enemy.target_height * 3.5, "%s collider envelope is plausible (%.2fm)" % [String(archetype), farthest])
	var visual_bounds := enemy._visual_world_bounds()
	var horizontal_center := Vector2(visual_bounds.get_center().x, visual_bounds.get_center().z).length()
	_check(visual_bounds.size.y >= enemy.target_height * 0.72 and visual_bounds.size.y <= enemy.target_height * 1.35, "%s visual height (%.2fm)" % [String(archetype), visual_bounds.size.y])
	_check(horizontal_center <= enemy.target_height * 0.35, "%s visual centered (offset %.2fm)" % [String(archetype), horizontal_center])
	if archetype == &"velociraptor":
		var lowest_toe_y := _lowest_raptor_toe_y(enemy)
		_check(absf(lowest_toe_y - enemy.global_position.y) <= 0.06, "velociraptor animated feet touch ground (%.3fm)" % lowest_toe_y)
		for animation_kind: StringName in [&"run", &"attack"]:
			enemy._play_animation(animation_kind)
			lowest_toe_y = _lowest_raptor_toe_y(enemy)
			_check(absf(lowest_toe_y - enemy.global_position.y) <= 0.06, "velociraptor %s starts grounded (%.3fm)" % [String(animation_kind), lowest_toe_y])
	print("[DINOSAUR PROBE] ", archetype, " bones=", enemy.skeleton.get_bone_count(), " animations=", enemy.dinosaur_animation_players[0].get_animation_list().size(), " zones=", enemy.anatomy.zone_runtime.size(), " envelope=", snappedf(farthest, 0.01), " visual_height=", snappedf(visual_bounds.size.y, 0.01))


func _lowest_raptor_toe_y(enemy: HopliteDinosaurEnemy) -> float:
	var lowest := INF
	for bone_name: StringName in enemy.RAPTOR_GROUND_BONES:
		var bone_index := enemy.skeleton.find_bone(String(bone_name))
		if bone_index >= 0:
			lowest = minf(lowest, enemy.skeleton.to_global(enemy.skeleton.get_bone_global_pose(bone_index).origin).y)
	return lowest


func _check_raptor_attack_cycle(enemy: HopliteDinosaurEnemy) -> void:
	var initial_scale := enemy.dinosaur_visual_pivot.scale
	enemy._play_animation(&"attack")
	var animation_duration := enemy.animation_player.current_animation_length if enemy.animation_player != null else 0.8
	var sample_frames := ceili((animation_duration + 0.24) * 60.0)
	var maximum_ground_error := 0.0
	var maximum_scale_error := 0.0
	for _frame: int in range(sample_frames):
		await physics_frame
		maximum_ground_error = maxf(maximum_ground_error, absf(_lowest_raptor_toe_y(enemy) - enemy.global_position.y))
		maximum_scale_error = maxf(maximum_scale_error, enemy.dinosaur_visual_pivot.scale.distance_to(initial_scale))
	enemy._play_animation(&"idle")
	for _frame: int in range(12):
		await physics_frame
		maximum_ground_error = maxf(maximum_ground_error, absf(_lowest_raptor_toe_y(enemy) - enemy.global_position.y))
		maximum_scale_error = maxf(maximum_scale_error, enemy.dinosaur_visual_pivot.scale.distance_to(initial_scale))
	_check(maximum_ground_error <= 0.08, "velociraptor full attack/recovery stays grounded (max %.3fm)" % maximum_ground_error)
	_check(maximum_scale_error <= 0.001, "velociraptor full attack/recovery keeps scale")


func _check_dinosaur_lod(enemy: HopliteDinosaurEnemy, archetype: StringName) -> void:
	_check(not enemy.anatomy.is_physics_processing(), "%s anatomy has one sampling authority" % String(archetype))
	var target := Node3D.new()
	_stage.add_child(target)
	enemy.ai_enabled = true
	enemy.ai_player = target
	enemy.battle_player = target
	enemy.set_meta("performance_profile", "auto")
	enemy.set_meta("planned_simultaneous_population", 20)

	target.global_position = enemy.global_position + Vector3(20.0, 0.0, 0.0)
	enemy._update_performance_lod()
	_check(enemy.render_lod_level == 1, "%s enters medium LOD" % String(archetype))
	_check(enemy.dinosaur_animation_manual, "%s medium animation uses manual cadence" % String(archetype))
	_check(enemy.anatomy.collision_layer == 8, "%s medium LOD keeps damage anatomy" % String(archetype))
	_check(_all_traversal_layers(enemy, 0), "%s medium LOD removes traversal broadphase" % String(archetype))
	_check(_all_mesh_shadows(enemy, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "%s medium LOD disables shadows" % String(archetype))
	if archetype == &"tyrannosaurus":
		_check(_all_mesh_visibility_range_ends(enemy, 0.0), "tyrannosaurus medium LOD avoids malformed-AABB range culling")

	target.global_position = enemy.global_position + Vector3(50.0, 0.0, 0.0)
	enemy._update_performance_lod()
	_check(enemy.render_lod_level == 2, "%s enters far LOD" % String(archetype))
	_check(enemy.anatomy.collision_layer == 0, "%s far LOD disables anatomy broadphase" % String(archetype))
	_check(_all_mesh_lod_bias_at_most(enemy, 0.23), "%s far LOD applies aggressive mesh bias" % String(archetype))

	target.global_position = enemy.global_position + Vector3(100.0, 0.0, 0.0)
	enemy._update_performance_lod()
	_check(enemy.render_lod_level == 3, "%s enters culled LOD" % String(archetype))
	_check(_all_mesh_visibility(enemy, false), "%s culled LOD hides meshes" % String(archetype))

	target.global_position = enemy.global_position + Vector3(2.0, 0.0, 0.0)
	enemy._update_performance_lod()
	_check(enemy.render_lod_level == 0, "%s wakes into exact LOD" % String(archetype))
	_check(not enemy.dinosaur_animation_manual, "%s close animation returns to realtime" % String(archetype))
	_check(enemy.anatomy.collision_layer == 8, "%s close LOD restores anatomy" % String(archetype))
	_check(_all_traversal_layers(enemy, enemy.TRAVERSAL_LAYER), "%s close LOD restores traversal" % String(archetype))
	_check(_all_mesh_visibility(enemy, true), "%s close LOD restores meshes" % String(archetype))
	enemy.ai_enabled = false
	enemy._update_performance_lod()
	var updates_before: int = enemy.dinosaur_anatomy_updates
	enemy._physics_process(1.0 / 60.0)
	_check(enemy.dinosaur_anatomy_updates == updates_before + 1, "%s performs one anatomy update per close physics step" % String(archetype))
	enemy.ai_player = null
	enemy.battle_player = null
	target.queue_free()


func _all_traversal_layers(enemy: HopliteDinosaurEnemy, expected_layer: int) -> bool:
	for traversal: Dictionary in enemy.traversal_by_zone.values():
		var body := traversal.get("body") as AnimatableBody3D
		if body != null and body.collision_layer != expected_layer:
			return false
	return true


func _all_traversal_bodies_synced(enemy: HopliteDinosaurEnemy) -> bool:
	for traversal: Dictionary in enemy.traversal_by_zone.values():
		var body := traversal.get("body") as AnimatableBody3D
		if body != null and not body.sync_to_physics:
			return false
	return true


func _all_mesh_shadows(enemy: HopliteDinosaurEnemy, expected: int) -> bool:
	for mesh_instance: MeshInstance3D in enemy.dinosaur_meshes:
		if mesh_instance.cast_shadow != expected:
			return false
	return true


func _all_mesh_lod_bias_at_most(enemy: HopliteDinosaurEnemy, maximum: float) -> bool:
	for mesh_instance: MeshInstance3D in enemy.dinosaur_meshes:
		if mesh_instance.lod_bias > maximum:
			return false
	return true


func _all_mesh_visibility(enemy: HopliteDinosaurEnemy, expected: bool) -> bool:
	for mesh_instance: MeshInstance3D in enemy.dinosaur_meshes:
		if mesh_instance.visible != expected:
			return false
	return true


func _all_mesh_visibility_range_ends(enemy: HopliteDinosaurEnemy, expected: float) -> bool:
	for mesh_instance: MeshInstance3D in enemy.dinosaur_meshes:
		if not is_equal_approx(mesh_instance.visibility_range_end, expected):
			return false
	return true


func _check_trex_charge_sequence(enemy: HopliteDinosaurEnemy) -> void:
	var target := Node3D.new()
	_stage.add_child(target)
	_check(_all_traversal_bodies_synced(enemy), "tyrannosaurus traversal bodies synchronize with physics")

	# A player at the feet starts one finite backwards spacing phase without
	# forcing the T-Rex to snap around.
	enemy.basis = Basis.IDENTITY
	target.global_position = enemy.global_position + Vector3(0.0, 0.0, -2.0)
	enemy.ai_player = target
	enemy.ai_attack_cooldown_timer = 0.0
	enemy._enter_state(HopliteDinosaurEnemy.DinosaurState.HUNT, 0.0)
	var close_basis: Basis = enemy.basis
	enemy._update_hunt(0.016)
	_check(enemy.dinosaur_state == HopliteDinosaurEnemy.DinosaurState.CREATE_SPACE, "tyrannosaurus creates space when target is at its feet")
	_check(enemy.basis.is_equal_approx(close_basis), "tyrannosaurus starts spacing without an instant turn")
	var space_start: Vector3 = enemy.global_position
	enemy._update_create_space(0.10)
	var space_motion: Vector3 = enemy.global_position - space_start
	space_motion.y = 0.0
	_check(space_motion.length() > 0.01 and space_motion.normalized().dot(Vector3.BACK) > 0.95, "tyrannosaurus backs up along its locked rear axis")
	enemy.state_time_left = 0.0
	enemy._update_create_space(0.016)
	_check(enemy.dinosaur_state == HopliteDinosaurEnemy.DinosaurState.ALIGN, "tyrannosaurus spacing has a hard time limit")

	# Turning to a target behind is bounded instead of becoming a one-frame 180.
	target.global_position = enemy.global_position + Vector3(0.0, 0.0, 8.0)
	var align_forward_before: Vector3 = -enemy.global_basis.z
	enemy._update_align(0.016)
	var align_forward_after: Vector3 = -enemy.global_basis.z
	_check(align_forward_before.angle_to(align_forward_after) < deg_to_rad(5.0), "tyrannosaurus alignment cannot snap 180 degrees")

	# A target already inside the frontal cone immediately validates one line.
	target.global_position = enemy.global_position + (-enemy.global_basis.z * 8.0)
	enemy.attack_hit_done = true
	enemy._update_align(0.016)
	_check(enemy.dinosaur_state == HopliteDinosaurEnemy.DinosaurState.WINDUP, "tyrannosaurus validates an aligned charge trajectory")
	_check(not enemy.attack_hit_done, "tyrannosaurus validated trajectory rearms charge damage")

	# The previously proven charge sequence remains locked after validation.
	target.global_position = enemy.global_position + Vector3(0.0, 0.0, -8.0)
	var locked_direction: Vector3 = enemy.charge_direction
	var locked_basis: Basis = enemy.basis
	target.global_position = enemy.global_position + Vector3(8.0, 0.0, 0.0)
	enemy.state_time_left = 0.0
	enemy._update_windup(0.016)
	_check(enemy.dinosaur_state == HopliteDinosaurEnemy.DinosaurState.ATTACK, "tyrannosaurus windup starts charge")
	_check(enemy.charge_direction.is_equal_approx(locked_direction), "tyrannosaurus keeps direction locked after target moves")
	_check(enemy.basis.is_equal_approx(locked_basis), "tyrannosaurus does not turn during windup")
	var start_position: Vector3 = enemy.global_position
	enemy.state_time_left = 0.60
	enemy._update_trex_charge(0.10)
	var displacement: Vector3 = enemy.global_position - start_position
	displacement.y = 0.0
	_check(displacement.length() > 0.05 and displacement.normalized().dot(locked_direction) > 0.98, "tyrannosaurus charge follows its locked line")
	_check(enemy.charge_direction.is_equal_approx(locked_direction), "tyrannosaurus charge does not track target")
	enemy.state_time_left = 0.0
	enemy._update_trex_charge(0.016)
	_check(enemy.dinosaur_state == HopliteDinosaurEnemy.DinosaurState.RECOVERY, "tyrannosaurus enters recovery after charge")
	_check(enemy.state_time_left >= enemy.trex_recovery_duration - 0.001, "tyrannosaurus exposes full recovery window")
	var recovery_basis: Basis = enemy.basis
	target.global_position = enemy.global_position + Vector3(0.0, 0.0, 1.5)
	enemy._update_recovery(0.10)
	_check(enemy.basis.is_equal_approx(recovery_basis), "tyrannosaurus stays facing forward during recovery")
	enemy.state_time_left = 0.0
	enemy._update_recovery(0.016)
	_check(enemy.dinosaur_state == HopliteDinosaurEnemy.DinosaurState.CREATE_SPACE, "tyrannosaurus leaves recovery by creating space when target stays close")
	target.queue_free()


func _world_mesh_bounds(root_node: Node3D) -> AABB:
	var initialized := false
	var bounds := AABB()
	for candidate: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local_bounds := mesh_instance.get_aabb()
		for endpoint: int in range(8):
			var world_point := mesh_instance.to_global(local_bounds.get_endpoint(endpoint))
			bounds = AABB(world_point, Vector3.ZERO) if not initialized else bounds.expand(world_point)
			initialized = true
	return bounds


func _check_decapitation(enemy: HopliteDinosaurEnemy, archetype: StringName) -> void:
	var hit := HitEventScript.new() as HopliteHitEvent
	hit.source = _stage
	hit.position = enemy.anatomy.get_zone_world_center(&"head")
	hit.direction = Vector3.RIGHT
	hit.damage = 1.0
	hit.sever_damage = 1000.0
	hit.attack_context = &"wall"
	enemy.receive_anatomy_hit(hit, &"head")
	_check(enemy.dead and enemy.head_severed, "%s wall-run head sever is fatal" % String(archetype))
	var head_traversal: Dictionary = enemy.traversal_by_zone.get(&"head", {})
	var head_body := head_traversal.get("body") as AnimatableBody3D
	_check(head_body != null and head_body.collision_layer == 0, "%s sever disables head traversal" % String(archetype))


func _all_collisions_disabled(collisions: Array[Node]) -> bool:
	for raw_collision: Node in collisions:
		var collision := raw_collision as CollisionObject3D
		if collision != null and (collision.collision_layer != 0 or collision.collision_mask != 0):
			return false
	return true


func _check(condition: bool, label: String) -> void:
	print("[DINOSAUR PROBE] ", "PASS " if condition else "FAIL ", label)
	_failed = _failed or not condition
