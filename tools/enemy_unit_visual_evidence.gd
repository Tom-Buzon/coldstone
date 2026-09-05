extends SceneTree

const Enemy = preload("res://scripts/enemy/athenian_enemy.gd")
const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const HitEvent = preload("res://scripts/combat/hit_event.gd")

class EvidenceTarget:
	extends Node3D
	func receive_enemy_hit(_damage: float, _attacker: Node = null, _direction: Vector3 = Vector3.ZERO) -> bool:
		return true
	func get_combat_aim_point() -> Vector3:
		return global_position + Vector3.UP

const STATE_NAMES: Array[String] = ["IDLE NU", "JOG NU", "SPRINT", "ROTATION", "GARDE", "ATTAQUE", "IMPACT", "UPPER BODY", "LOD LOIN", "SOMMEIL", "REVEIL", "MORT", "SECTION"]
const GRID_COLUMNS: int = 7
const X_SPACING: float = 1.78
const Z_SPACING: float = 3.65

var archetype: StringName = &"ngeneral"
var failures: Array[String] = []
var enemies: Array[HopliteAthenianEnemy] = []
var targets: Array[Node3D] = []
var evidence_camera: Camera3D
var state_labels: Array[Label3D] = []
var title_label: Label3D
var variant_override: StringName = StringName()

func _initialize() -> void:
	_parse_arguments()
	call_deferred("_run")

func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--id="):
			archetype = StringName(argument.trim_prefix("--id="))
		elif argument.begins_with("--variant="):
			variant_override = StringName(argument.trim_prefix("--variant="))
	if not Archetypes.all_ids().has(archetype):
		failures.append("unknown archetype: %s" % archetype)

func _run() -> void:
	if not failures.is_empty():
		_finish()
		return
	root.size = Vector2i(1500, 900)
	var world := Node3D.new()
	world.name = "EnemyVisualEvidence_%s" % archetype
	root.add_child(world)
	current_scene = world
	_build_stage(world)

	for index: int in range(STATE_NAMES.size()):
		var target := EvidenceTarget.new()
		target.position = _state_position(index) + Vector3(0.0, 0.0, 2.0)
		world.add_child(target)
		targets.append(target)
		var enemy := Enemy.new() as HopliteAthenianEnemy
		enemy.name = "%s_%s" % [archetype, STATE_NAMES[index].replace(" ", "_")]
		enemy.archetype_id = archetype
		if variant_override != StringName():
			enemy.mixamo_model_override = variant_override
		enemy.ai_enabled = true
		enemy.ai_player = target
		enemy.battle_player = target
		enemy.ai_attack_cooldown_timer = 99.0
		enemy.position = _state_position(index)
		enemy.rotation.y = PI
		world.add_child(enemy)
		enemies.append(enemy)
	print("ENEMY_UNIT_VISUAL_EVIDENCE stage=spawned id=%s count=%d" % [archetype, enemies.size()])

	for _frame: int in range(24):
		await process_frame
		await physics_frame
	print("ENEMY_UNIT_VISUAL_EVIDENCE stage=warmed id=%s" % archetype)
	if variant_override != StringName():
		for enemy: HopliteAthenianEnemy in enemies:
			if not enemy.uses_mixamo_visual or enemy.mixamo_model_id != variant_override:
				failures.append("%s requested variant %s but loaded %s (direct=%s)" % [archetype, variant_override, enemy.mixamo_model_id, enemy.uses_mixamo_visual])
		if not failures.is_empty():
			_finish()
			return
	var maximum_height := _ground_visuals_for_evidence()
	_frame_evidence(maximum_height)
	for enemy: HopliteAthenianEnemy in enemies:
		enemy.set_physics_process(false)
		enemy.set_process(false)

	_prepare_idle(enemies[0])
	_prepare_jog(enemies[1])
	_prepare_sprint(enemies[2])
	_prepare_rotation(enemies[3])
	_prepare_guard(enemies[4])
	_prepare_attack(enemies[5])
	_prepare_impact(enemies[6])
	_prepare_upper_body(enemies[7])
	_prepare_lod_far(enemies[8])
	_prepare_sleep(enemies[9])
	_prepare_wake(enemies[10])
	_prepare_death(enemies[11])
	_prepare_sever(enemies[12])
	print("ENEMY_UNIT_VISUAL_EVIDENCE stage=posed id=%s" % archetype)

	# Give death tweens/authored clips enough render time to become unmistakable;
	# attack mechanics stay frozen because the enemy physics callbacks are off.
	for _frame: int in range(30):
		await process_frame
		await physics_frame
	for enemy: HopliteAthenianEnemy in enemies:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	for _frame: int in range(3):
		await process_frame
	print("ENEMY_UNIT_VISUAL_EVIDENCE stage=render id=%s" % archetype)
	await RenderingServer.frame_post_draw

	var output_dir := "res://docs/enemy_refactor/visual_evidence"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var output_name := String(archetype) if variant_override == StringName() else "%s__%s" % [archetype, variant_override]
	var output_path := "%s/%s.png" % [output_dir, output_name]
	var image := root.get_texture().get_image()
	var save_error := image.save_png(ProjectSettings.globalize_path(output_path)) if image != null else ERR_CANT_CREATE
	if save_error != OK:
		failures.append("could not save %s: %s" % [output_path, error_string(save_error)])
	else:
		print("ENEMY_UNIT_VISUAL_EVIDENCE PASS id=%s output=%s size=%s" % [archetype, output_path, image.get_size()])
	_finish()

func _build_stage(world: Node3D) -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.045, 0.065)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.77, 0.90)
	env.ambient_light_energy = 1.05
	environment.environment = env
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key.light_energy = 1.65
	key.shadow_enabled = true
	world.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3.5, 3.0, 3.5)
	fill.omni_range = 15.0
	fill.light_energy = 5.0
	world.add_child(fill)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(14.0, 10.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.11, 0.13, 0.17)
	floor_material.roughness = 0.88
	floor.material_override = floor_material
	world.add_child(floor)
	evidence_camera = Camera3D.new()
	evidence_camera.position = Vector3(0.0, 5.2, 14.8)
	evidence_camera.fov = 48.0
	evidence_camera.current = true
	world.add_child(evidence_camera)
	for index: int in range(STATE_NAMES.size()):
		var label := Label3D.new()
		label.text = STATE_NAMES[index]
		label.position = _state_position(index) + Vector3(0.0, 2.65, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 34
		label.modulate = Color(0.96, 0.88, 0.60)
		label.outline_size = 8
		world.add_child(label)
		state_labels.append(label)
	title_label = Label3D.new()
	title_label.text = String(archetype).to_upper()
	title_label.position = Vector3(0.0, 3.35, 0.0)
	title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title_label.font_size = 48
	title_label.modulate = Color.WHITE
	title_label.outline_size = 10
	world.add_child(title_label)

func _ground_visuals_for_evidence() -> float:
	var maximum_height := 1.8
	for enemy: HopliteAthenianEnemy in enemies:
		var bounds := _visual_world_y_bounds(enemy)
		if is_finite(bounds.x):
			enemy.global_position.y -= bounds.x
			maximum_height = maxf(maximum_height, bounds.y - bounds.x)
	return maximum_height

func _visual_world_y_bounds(enemy: HopliteAthenianEnemy) -> Vector2:
	var minimum := INF
	var maximum := -INF
	for raw_node: Node in enemy.find_children("*", "MeshInstance3D", true, false):
		var instance := raw_node as MeshInstance3D
		if instance == null or instance.mesh == null or not instance.visible:
			continue
		var bounds := instance.get_aabb()
		for endpoint_index: int in range(8):
			var world_point := instance.global_transform * bounds.get_endpoint(endpoint_index)
			minimum = minf(minimum, world_point.y)
			maximum = maxf(maximum, world_point.y)
	return Vector2(minimum, maximum)

func _frame_evidence(maximum_height: float) -> void:
	var label_y := maximum_height + 0.48
	for index: int in range(state_labels.size()):
		state_labels[index].position = _state_position(index) + Vector3(0.0, label_y, 0.0)
	title_label.position = Vector3(0.0, label_y + 0.72, 1.25)
	var target_y := maximum_height * 0.58
	var camera_y := target_y + maximum_height * 0.26
	evidence_camera.look_at_from_position(Vector3(0.0, camera_y + 3.0, 14.8), Vector3(0.0, target_y, -1.8), Vector3.UP)

func _state_position(index: int) -> Vector3:
	var column := index % GRID_COLUMNS
	var row := index / GRID_COLUMNS
	return Vector3((float(column) - float(GRID_COLUMNS - 1) * 0.5) * X_SPACING, 0.0, -float(row) * Z_SPACING)

func _prepare_idle(enemy: HopliteAthenianEnemy) -> void:
	_hide_equipment(enemy)
	if enemy.ai_animation_driver != null:
		enemy.ai_animation_driver.set_locomotion(0.0)
		enemy.ai_animation_driver.force_simulation_sample()
	else:
		enemy.call("_play_simple_loop", &"Idle", 1.0)

func _prepare_jog(enemy: HopliteAthenianEnemy) -> void:
	_hide_equipment(enemy)
	if enemy.ai_animation_driver != null:
		enemy.ai_animation_driver.set_locomotion(0.68)
		enemy.ai_animation_driver.call("_advance_simulation", 0.34)
	elif enemy.animation_player != null:
		var clip := &"Jog_Fwd" if enemy.animation_player.has_animation("Jog_Fwd") else &"Walk"
		enemy.call("_play_simple_loop", clip, 1.0)
		enemy.animation_player.advance(0.34)

func _prepare_sprint(enemy: HopliteAthenianEnemy) -> void:
	if enemy.ai_animation_driver != null:
		enemy.ai_animation_driver.set_locomotion(1.0)
		enemy.ai_animation_driver.call("_advance_simulation", 0.30)
	elif enemy.animation_player != null:
		var clip := &"Sprint" if enemy.animation_player.has_animation(&"Sprint") else &"Jog_Fwd"
		enemy.call("_play_simple_loop", clip, 1.12)
		enemy.animation_player.advance(0.30)

func _prepare_rotation(enemy: HopliteAthenianEnemy) -> void:
	_prepare_jog(enemy)
	enemy.rotation.y = PI * 0.62

func _prepare_guard(enemy: HopliteAthenianEnemy) -> void:
	enemy.call("_begin_defense_window")
	if enemy.ai_animation_driver != null:
		enemy.ai_animation_driver.call("_advance_simulation", 0.20)
		enemy.ai_animation_driver.force_simulation_sample()

func _prepare_attack(enemy: HopliteAthenianEnemy) -> void:
	enemy.ai_attack_cooldown_timer = 0.0
	enemy.call("_begin_ai_attack")
	if not enemy.ai_attack_pending:
		enemy.call("_play_mass_attack_animation")

func _prepare_impact(enemy: HopliteAthenianEnemy) -> void:
	if not bool(enemy.call("_play_hit_reaction")):
		failures.append("%s deterministic impact reaction did not start" % archetype)
	if enemy.ai_animation_driver != null:
		enemy.ai_animation_driver.call("_advance_simulation", 0.16)
		enemy.ai_animation_driver.force_simulation_sample()

func _prepare_upper_body(enemy: HopliteAthenianEnemy) -> void:
	if enemy.ai_animation_driver != null:
		enemy.ai_animation_driver.set_locomotion(0.62)
	_prepare_attack(enemy)
	if enemy.ai_animation_driver != null:
		enemy.ai_animation_driver.call("_advance_simulation", 0.22)
		enemy.ai_animation_driver.force_simulation_sample()

func _prepare_lod_far(enemy: HopliteAthenianEnemy) -> void:
	_prepare_jog(enemy)
	enemy.call("_apply_render_lod", 2, true, 90.0)

func _prepare_sleep(enemy: HopliteAthenianEnemy) -> void:
	_prepare_jog(enemy)
	enemy.call("_apply_render_lod", 3, true, 140.0)

func _prepare_wake(enemy: HopliteAthenianEnemy) -> void:
	_prepare_jog(enemy)
	enemy.call("_apply_render_lod", 3, true, 140.0)
	enemy.call("_apply_render_lod", 0, true, 8.0)
	if enemy.ai_animation_driver != null:
		enemy.ai_animation_driver.force_simulation_sample()

func _prepare_death(enemy: HopliteAthenianEnemy) -> void:
	enemy.call("_die", false)
	if enemy.animation_player != null:
		enemy.animation_player.advance(0.72)

func _prepare_sever(enemy: HopliteAthenianEnemy) -> void:
	enemy.health = maxf(enemy.max_health, 1000.0)
	enemy.max_health = enemy.health
	enemy.defense_timer = 0.0
	var hit := HitEvent.new()
	hit.damage = 1.0
	hit.sever_damage = 10000.0
	hit.position = enemy.global_position + Vector3.UP * 1.35 + Vector3.RIGHT * 0.35
	hit.direction = Vector3.RIGHT
	hit.source = null
	enemy.receive_anatomy_hit(hit, &"upper_arm_r")
	for candidate: Node in enemy.get_tree().current_scene.find_children("*", "GPUParticles3D", true, false):
		var particles := candidate as GPUParticles3D
		if particles != null:
			particles.emitting = false
	if not enemy.is_combat_zone_severed(&"upper_arm_r"):
		failures.append("%s did not sever upper_arm_r for rendered evidence" % archetype)

func _hide_equipment(enemy: HopliteAthenianEnemy) -> void:
	if enemy.sword_root != null:
		enemy.sword_root.visible = false
	if enemy.shield_root != null:
		enemy.shield_root.visible = false
	if enemy.authored_weapon_visual != null:
		enemy.authored_weapon_visual.visible = false
	if enemy.authored_shield_visual != null:
		enemy.authored_shield_visual.visible = false

func _finish() -> void:
	if failures.is_empty():
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
