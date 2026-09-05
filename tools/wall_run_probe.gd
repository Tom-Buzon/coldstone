extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	world.name = "WallRunProbeWorld"
	root.add_child(world)
	current_scene = world
	var obstacle := StaticBody3D.new()
	obstacle.name = "ClimbableWall"
	obstacle.collision_layer = 1
	var obstacle_collision := CollisionShape3D.new()
	var obstacle_shape := BoxShape3D.new()
	obstacle_shape.size = Vector3(4.0, 2.0, 0.5)
	obstacle_collision.shape = obstacle_shape
	obstacle.add_child(obstacle_collision)
	obstacle.position = Vector3(0.0, 1.0, -0.25)
	world.add_child(obstacle)
	var corner_wall := StaticBody3D.new()
	corner_wall.name = "InteriorCornerWall"
	corner_wall.collision_layer = 1
	var corner_collision := CollisionShape3D.new()
	var corner_shape := BoxShape3D.new()
	corner_shape.size = Vector3(0.5, 2.0, 2.5)
	corner_collision.shape = corner_shape
	corner_wall.add_child(corner_collision)
	corner_wall.position = Vector3(1.75, 1.0, 1.25)
	world.add_child(corner_wall)
	var cylinder := StaticBody3D.new()
	cylinder.name = "CurvedWallRunRegressionCylinder"
	cylinder.collision_layer = 1
	cylinder.position = Vector3(20.0, 4.0, 0.0)
	var cylinder_collision := CollisionShape3D.new()
	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = 0.80
	cylinder_shape.height = 8.0
	cylinder_collision.shape = cylinder_shape
	cylinder.add_child(cylinder_collision)
	world.add_child(cylinder)

	var regular_enemy := StaticBody3D.new()
	regular_enemy.name = "RegularEnemyWallRunReject"
	regular_enemy.collision_layer = 4
	regular_enemy.add_to_group("enemy")
	world.add_child(regular_enemy)

	var giant_enemy := StaticBody3D.new()
	giant_enemy.name = "GiantEnemyWallRunSurface"
	giant_enemy.collision_layer = 4
	giant_enemy.scale = Vector3.ONE * 2.0
	giant_enemy.position = Vector3(8.0, 0.0, 0.0)
	giant_enemy.add_to_group("enemy")
	var giant_collision := CollisionShape3D.new()
	var giant_shape := BoxShape3D.new()
	giant_shape.size = Vector3(0.8, 2.0, 0.8)
	giant_collision.shape = giant_shape
	giant_collision.position = Vector3.UP
	giant_enemy.add_child(giant_collision)
	world.add_child(giant_enemy)

	var phalanx_shields: Array[Area3D] = []
	for index: int in range(3):
		var shield := Area3D.new()
		shield.name = "RaisedPhalanxShield%d" % index
		shield.collision_layer = 64
		shield.position = Vector3(float(index) * 1.08, 1.05, 5.0)
		shield.add_to_group("wall_run_phalanx_shield")
		var shield_collision := CollisionShape3D.new()
		var shield_shape := BoxShape3D.new()
		shield_shape.size = Vector3(0.90, 1.0, 0.12)
		shield_collision.shape = shield_shape
		shield.add_child(shield_collision)
		world.add_child(shield)
		phalanx_shields.append(shield)

	var giant_floor := AnimatableBody3D.new()
	giant_floor.name = "ForgeGiantShoulderFloor"
	giant_floor.collision_layer = 128
	giant_floor.collision_mask = 0
	giant_floor.position = Vector3(12.0, 0.05, 0.0)
	giant_floor.add_to_group("enemy_walkable_surface")
	var giant_floor_collision := CollisionShape3D.new()
	var giant_floor_shape := BoxShape3D.new()
	giant_floor_shape.size = Vector3(4.0, 0.10, 4.0)
	giant_floor_collision.shape = giant_floor_shape
	giant_floor.add_child(giant_floor_collision)
	world.add_child(giant_floor)

	var dinosaur_floor := AnimatableBody3D.new()
	dinosaur_floor.name = "TyrannosaurusAnimatedBack"
	dinosaur_floor.collision_layer = 256
	dinosaur_floor.collision_mask = 0
	dinosaur_floor.sync_to_physics = true
	dinosaur_floor.position = Vector3(18.0, 0.05, 0.0)
	dinosaur_floor.add_to_group("giant_wall_run_surface")
	var dinosaur_floor_collision := CollisionShape3D.new()
	var dinosaur_floor_shape := BoxShape3D.new()
	dinosaur_floor_shape.size = Vector3(4.0, 0.10, 4.0)
	dinosaur_floor_collision.shape = dinosaur_floor_shape
	dinosaur_floor.add_child(dinosaur_floor_collision)
	world.add_child(dinosaur_floor)

	var player := PlayerScript.new() as HopliteUALNativePlayer
	player.name = "WallRunProbePlayer"
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector3(0.0, 0.05, 1.0)
	world.add_child(player)
	await process_frame
	await physics_frame

	_assert(player.animation_driver != null, "animation driver was not created")
	_assert((player.collision_mask & 128) != 0, "player cannot collide with Forge giant floor surfaces")
	player.global_position = Vector3(12.0, 0.80, 0.0)
	player.velocity = Vector3.DOWN * 8.0
	player.jumps_used = player.max_jumps
	player.wall_run_runs_used = player.wall_run_max_chain_runs
	player.wall_run_attach_available = false
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	for _step: int in range(16):
		await physics_frame
	_assert(player.is_on_floor(), "horizontal Forge giant surface was not recognized as floor")
	_assert(player.jumps_used == 0, "standing on a giant did not reset double jump")
	_assert(player.wall_run_runs_used == 0 and player.wall_run_attach_available, "standing on a giant did not reset wall runs")
	player.global_position = Vector3(18.0, 0.80, 0.0)
	player.velocity = Vector3.DOWN * 8.0
	for _step: int in range(16):
		await physics_frame
	_assert(player.is_on_floor(), "animated dinosaur traversal surface was not recognized as floor")
	_assert(player.giant_traversal_support_active, "player did not identify the animated dinosaur support")
	_assert(player.platform_on_leave == CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING, "dinosaur support still transfers its leave velocity")
	# Clear CharacterBody3D's cached floor state before the remaining airborne
	# release tests resume in their original disabled/manual mode.
	player.global_position = Vector3(0.0, 2.0, 1.0)
	player.velocity = Vector3.ZERO
	await physics_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(0.0, 0.05, 1.0)
	player.velocity = Vector3.ZERO
	_assert(is_equal_approx(player.wall_run_max_distance, 10.0), "wall-run distance is not 10 m")
	_assert(is_equal_approx(player.wall_run_horizontal_speed, 9.2), "horizontal speed boost is missing")
	_assert(player.wall_run_max_chain_runs == 2, "airborne wall-run chain is not capped at two")
	_assert(player.experimental_enemy_wall_run_enabled, "experimental enemy wall running is not enabled")
	_assert(player._wall_run_hit_kind({"collider": regular_enemy}) == StringName(), "regular-sized enemy became a wall-run surface")
	_assert(player._wall_run_hit_kind({"collider": giant_enemy}) == &"giant_enemy", "double-sized enemy was not accepted as a wall-run surface")
	var giant_probe_found: bool = false
	for giant_hit: Dictionary in player._wall_run_raycast_candidates(Vector3(6.4, 1.22, 0.0), Vector3(9.0, 1.22, 0.0)):
		if player._wall_run_hit_kind(giant_hit) == &"giant_enemy":
			giant_probe_found = true
	_assert(giant_probe_found, "wall-run probes cannot physically detect the giant enemy layer")
	player.global_position = Vector3(6.4, 0.05, 0.0)
	_assert(player._dynamic_wall_run_surface_blocks_parkour(Vector3.RIGHT), "giant enemy does not block mantle probing through its body")
	player.global_position = Vector3(0.0, 0.05, 1.0)
	_assert(player._wall_run_hit_kind({"collider": phalanx_shields[1]}) == &"phalanx_shields", "three raised neighboring phalanx shields did not form a wall-run line")
	phalanx_shields[2].collision_layer = 0
	_assert(player._wall_run_hit_kind({"collider": phalanx_shields[1]}) == StringName(), "fewer than three raised shields still formed a wall-run line")
	phalanx_shields[2].collision_layer = 64
	player.global_position = Vector3(0.54, 0.05, 4.35)
	player.wall_run_surface_kind = &"phalanx_shields"
	player.wall_run_normal = Vector3.FORWARD
	player.wall_run_last_tangent = Vector3.RIGHT
	_assert(not player._probe_next_phalanx_shield().is_empty(), "shield-line lookahead did not acquire the next raised shield across a physical gap")
	player.global_position = Vector3(0.0, 0.05, 1.0)
	player.wall_run_surface_kind = &"world"
	player.experimental_enemy_wall_run_enabled = false
	_assert(player._wall_run_hit_kind({"collider": giant_enemy}) == StringName(), "single rollback switch did not disable enemy wall running")
	player.experimental_enemy_wall_run_enabled = true
	player._begin_wall_run(Vector3.LEFT, Vector3.RIGHT, &"giant_enemy")
	_assert(not player._wall_run_surface_allows_parkour(), "giant enemy wall run can incorrectly trigger mantle/climb")
	player._reset_wall_run_after_landing()
	if player.animation_driver != null:
		var twist_length: float = float(player.animation_driver.wall_movement_bank.clip_length(&"wall_run_detach_twist"))
		_assert(twist_length > 0.50, "Front Twist Flip was not imported as a usable animation")
		_assert(player.animation_driver.wall_movement_bank.pose_bridges_precede(player.animation_driver.pose_bridge), "wall animation modifiers still mask the later sword/charge layer")
		_assert(player.animation_driver.play_wall_run_visual(&"horizontal", false), "Wall Run clip failed")
		_assert(player.animation_driver.play_wall_run_visual(&"horizontal", true), "mirrored Wall Run clip failed")
		_assert(player.animation_driver.wall_visual_mirrored, "right-side wall pose was not mirrored")
		_assert(player.animation_driver.play_wall_run_visual(&"diagonal"), "Diagonal Wall Run clip failed")
		_assert(player.animation_driver.play_wall_run_visual(&"vertical"), "Run To Flip clip failed")
		player.animation_driver.stop_wall_run_visual()

	# A charge begun before contact must survive both attachment and the wall jump.
	player._reset_wall_run_after_landing()
	player._begin_heavy_input(0.24)
	player.primary_attack_held = true
	player.primary_heavy_started = true
	var preserved_charge_before_wall: float = player.heavy_charge
	player._begin_wall_run(Vector3.LEFT, Vector3.FORWARD)
	_assert(player.heavy_charging and player.heavy_charge >= preserved_charge_before_wall, "wall attachment cancelled an existing heavy charge")
	_assert(player.animation_driver == null or player.animation_driver.is_heavy_charging(), "wall attachment removed the authored heavy-charge pose")
	_assert(player.primary_attack_held and player.primary_heavy_started, "wall attachment reset the held primary-heavy input")
	player._perform_wall_jump()
	_assert(player.heavy_charging and player.heavy_charge >= preserved_charge_before_wall, "wall jump cancelled the carried heavy charge")
	_assert(player.animation_driver == null or player.animation_driver.is_heavy_charging(), "wall jump removed the authored heavy-charge pose")
	player._cancel_heavy_charge()
	player._reset_primary_attack_input()
	player._reset_wall_run_after_landing()

	# Wall-local charge/release and light attacks must stay upper-body layers.
	player._begin_wall_run(Vector3.LEFT, Vector3.FORWARD)
	_assert(player._combat_context() == &"wall", "active wall run did not expose the wall combat context")
	player._begin_heavy_input(0.30)
	_assert(player.heavy_charging and (player.animation_driver == null or player.animation_driver.is_heavy_charging()), "heavy charge could not start during wall run")
	player.heavy_charge = player.heavy_charge_max * 0.72
	player._release_heavy_attack()
	_assert(not player.heavy_charging, "heavy attack did not release during wall run")
	_assert(player.animation_driver == null or (player.animation_driver.current_attack_context_name() == &"wall" and player.animation_driver.current_attack_slot_name() == &"heavy"), "released wall heavy did not start in wall context")
	_assert(player.animation_driver == null or (not player.animation_driver.attack_full_body and player.animation_driver.attack_hips_weight <= 0.13), "wall heavy replaced the wall-run lower body")
	if player.animation_driver != null:
		player.animation_driver._finish_attack()
	player._do_light_attack()
	_assert(player.animation_driver == null or (player.animation_driver.current_attack_context_name() == &"wall" and player.animation_driver.current_attack_slot_name() == &"light1"), "light attack could not start during wall run")
	_assert(player.animation_driver == null or (not player.animation_driver.attack_full_body and player.animation_driver.attack_hips_weight <= 0.13), "wall light replaced the wall-run lower body")
	if player.animation_driver != null:
		player.animation_driver._finish_attack()
	player._reset_wall_run_after_landing()

	player.velocity = Vector3(0.0, 5.0, -6.0)
	player._begin_wall_run(Vector3.LEFT, Vector3.FORWARD)
	_assert(player.wall_run_active and player.wall_run_mode == &"horizontal", "horizontal mode classification failed")
	var horizontal_repulsion: Vector3 = player._wall_run_repulsion(&"horizontal", Vector3.FORWARD)
	_assert(is_equal_approx(rad_to_deg(Vector3.FORWARD.angle_to(horizontal_repulsion.normalized())), 25.0), "horizontal repulsion is not 25 degrees")
	_assert(horizontal_repulsion.length() >= player.jump_velocity, "horizontal detachment is weaker than a regular jump")
	player._perform_wall_jump()
	_assert(not player.wall_run_active and player.wall_run_attach_available and player.wall_run_runs_used == 1, "first wall jump did not arm the second run")
	_assert(player.wall_run_chain_armed_by_jump, "a deliberate wall jump did not arm the second wall run")
	_assert(player.wall_run_repulsion_control_lock > 0.0, "wall jump impulse is not protected from immediate air steering")
	_assert(player.animation_driver == null or player.animation_driver.wall_release_air_pose_requested, "wall jump did not arm the airborne ninja pose")
	if player.animation_driver != null:
		var ninja_start_duration: float = player.animation_driver.donor_action_timer
		player.animation_driver.tick(ninja_start_duration + 0.05)
		_assert(player.animation_driver.wall_release_air_pose_active, "finished wall-jump animation did not continue in NinjaJump_Idle")

	player.velocity = Vector3(0.0, 5.0, -6.0)
	player._begin_wall_run(Vector3.LEFT, Vector3(1.0, 0.0, -1.0).normalized())
	_assert(player.wall_run_mode == &"diagonal", "diagonal mode classification failed")
	var diagonal_repulsion: Vector3 = player._wall_run_repulsion(&"diagonal", Vector3.FORWARD)
	_assert(is_equal_approx(rad_to_deg(Vector3.FORWARD.angle_to(diagonal_repulsion.normalized())), 50.0), "diagonal repulsion is not 50 degrees")
	_assert(diagonal_repulsion.length() > horizontal_repulsion.length(), "diagonal repulsion is not stronger than horizontal")
	var enemy_horizontal_repulsion: Vector3 = player._wall_run_repulsion(&"horizontal", Vector3.FORWARD, &"giant_enemy")
	var shield_diagonal_repulsion: Vector3 = player._wall_run_repulsion(&"diagonal", Vector3.FORWARD, &"phalanx_shields")
	_assert(is_equal_approx(enemy_horizontal_repulsion.length(), horizontal_repulsion.length() * 0.20), "giant horizontal repulsion was not reduced by 80%")
	_assert(is_equal_approx(shield_diagonal_repulsion.length(), diagonal_repulsion.length() * 0.20), "shield diagonal repulsion was not reduced by 80%")
	player._perform_wall_jump()
	_assert(not player.wall_run_attach_available and player.wall_run_runs_used == 2, "a third consecutive wall run is still available")

	player._reset_wall_run_after_landing()
	player.velocity = Vector3(0.0, 5.0, -6.0)
	player._begin_wall_run(Vector3.LEFT, Vector3.FORWARD)
	var vertical_rotation_before_jump: float = player.rotation.y
	player.wall_run_mode = &"vertical"
	player.wall_run_last_tangent = Vector3.ZERO
	player._perform_wall_jump()
	_assert(is_equal_approx(player.rotation.y, vertical_rotation_before_jump), "vertical wall jump still rotates the CharacterBody")
	_assert(player.wall_run_release_input_guard and player.wall_run_release_input_guard_timer > 0.0, "vertical wall jump did not briefly protect its release impulse")
	_assert(player.wall_run_release_input_guard_duration < player.wall_run_attach_cooldown, "vertical release input guard still outlives the short detach window")
	var vertical_held_forward: Vector3 = Vector3.RIGHT
	var vertical_filtered_input: Vector3 = player._filter_wall_run_release_input(vertical_held_forward)
	_assert(vertical_filtered_input.length() < 0.001, "held forward input can cancel the initial vertical wall-jump release")
	var slightly_oblique_forward: Vector3 = Vector3(1.0, 0.0, -0.05).normalized()
	var oblique_filtered_input: Vector3 = player._filter_wall_run_release_input(slightly_oblique_forward)
	_assert(oblique_filtered_input.length() < 0.10, "tiny camera tangent was amplified into a 90-degree facing command")
	player.wall_run_release_input_guard_timer = 0.0
	var return_to_wall_input: Vector3 = player._filter_wall_run_release_input(vertical_held_forward)
	_assert(not player.wall_run_release_input_guard, "short vertical release guard did not expire")
	_assert(return_to_wall_input.dot(player.wall_run_release_normal) < -0.90, "expired guard still prevents a double jump back toward the wall")
	player._reset_wall_run_after_landing()
	player.velocity = Vector3(0.0, 5.0, -6.0)
	player._begin_wall_run(Vector3.LEFT, Vector3.FORWARD)
	var horizontal_speed_before_detach: float = Vector2(player.velocity.x, player.velocity.z).length()
	player._detach_wall_run("probe exhaustion", false)
	var horizontal_speed_after_detach: float = Vector2(player.velocity.x, player.velocity.z).length()
	_assert(horizontal_speed_after_detach >= horizontal_speed_before_detach * 0.95, "horizontal detachment cut the wall-run momentum")
	_assert(horizontal_speed_after_detach <= horizontal_speed_before_detach * 1.20, "horizontal detachment adds too much repulsion to the wall-run momentum")
	_assert(not player.wall_run_attach_available, "passive detachment should stay locked")
	_assert(not player.wall_run_chain_armed_by_jump and player.wall_run_passive_detach_locked, "passive detachment incorrectly armed another wall run")
	_assert(player.animation_driver == null or (player.animation_driver.wall_visual_mode == &"twist_release" and player.animation_driver.wall_visual_mirrored), "horizontal detachment did not start the mirrored Front Twist Flip")
	_assert(player.animation_driver == null or player.animation_driver.wall_release_air_pose_requested, "passive wall detachment did not arm the airborne ninja pose")
	_assert(player.animation_driver == null or player.animation_driver.wall_visual_duration < player.animation_driver.wall_movement_bank.clip_length(&"wall_run_detach_twist") * 0.85, "Front Twist Flip still includes too much of its ground take-off")
	_assert(player.wall_run_repulsion_control_lock > 0.0, "passive detachment impulse is not protected from immediate air steering")
	var held_toward_wall: Vector3 = (Vector3.RIGHT + Vector3.FORWARD).normalized()
	var filtered_release_input: Vector3 = player._filter_wall_run_release_input(held_toward_wall)
	_assert(filtered_release_input.dot(player.wall_run_release_normal) >= -0.001, "held input can still steer back into the detached wall")
	_assert(filtered_release_input.dot(Vector3.FORWARD) > 0.65, "release filtering removed parallel steering")
	player.wall_run_release_input_guard_timer = 0.0
	var restored_release_input: Vector3 = player._filter_wall_run_release_input(held_toward_wall)
	_assert(restored_release_input.dot(player.wall_run_release_normal) < -0.60, "expired release guard still blocks intentional steering toward the wall")

	player._reset_wall_run_after_landing()
	player.velocity = Vector3(0.0, 5.0, -6.0)
	player._begin_wall_run(Vector3.RIGHT, Vector3(-1.0, 0.0, -1.0).normalized())
	player.wall_run_mode = &"diagonal"
	player._detach_wall_run("probe diagonal exhaustion", false)
	_assert(player.animation_driver == null or (player.animation_driver.wall_visual_mode == &"twist_release" and not player.animation_driver.wall_visual_mirrored), "diagonal detachment did not use the opposite Front Twist Flip side")

	player._reset_wall_run_after_landing()
	player.velocity = Vector3.UP * 6.0
	player._begin_wall_run(Vector3.LEFT, Vector3.RIGHT)
	_assert(player.wall_run_mode == &"vertical", "vertical mode classification failed")
	var vertical_repulsion: Vector3 = player._wall_run_repulsion(&"vertical", Vector3.FORWARD)
	var enemy_vertical_repulsion: Vector3 = player._wall_run_repulsion(&"vertical", Vector3.FORWARD, &"giant_enemy")
	_assert(is_equal_approx(rad_to_deg(Vector3.FORWARD.angle_to(vertical_repulsion.normalized())), 90.0), "vertical repulsion is not 90 degrees")
	_assert(vertical_repulsion.length() > diagonal_repulsion.length(), "vertical repulsion is not the strongest release")
	_assert(is_equal_approx(enemy_vertical_repulsion.length(), vertical_repulsion.length()), "enemy vertical repulsion changed even though only horizontal/diagonal should be reduced")
	player._perform_wall_jump()
	_assert(player.animation_driver == null or player.animation_driver.wall_visual_mode == &"vertical_release", "early vertical jump did not preserve the backflip")
	var manual_vertical_release_speed: float = player.velocity.y
	_assert(is_equal_approx(manual_vertical_release_speed, player.wall_jump_up_speed), "manual vertical wall jump lost its deliberate upward speed")
	if player.animation_driver != null:
		var release_duration: float = player.animation_driver.wall_visual_timer
		player.animation_driver.tick(release_duration * 0.70)
		_assert(player.animation_driver.wall_visual_mode == StringName(), "vertical backflip did not stop before its extended-leg recovery")
		_assert(player.animation_driver.wall_release_air_pose_active, "finished backflip returned to upright locomotion instead of NinjaJump_Idle")
		_assert(player.animation_driver.movement_source_player.current_animation == String(player.animation_driver.slot_map.get(&"ninja_jump_idle", StringName())), "wall release did not hold the authored ninja airborne pose")
		_assert(player.animation_driver.play_wall_release_double_jump(), "second wall-release jump did not start the aerial twist")
		_assert(player.animation_driver.wall_visual_mode == &"wall_double_jump_twist", "second wall-release jump was delayed behind another animation")
		var double_jump_twist_duration: float = player.animation_driver.wall_visual_timer
		player.animation_driver.tick(double_jump_twist_duration + 0.05)
		_assert(player.animation_driver.wall_visual_mode == StringName(), "second-jump aerial twist did not finish")
		_assert(player.animation_driver.wall_release_air_pose_active, "second-jump twist did not return to NinjaJump_Idle")

	player._reset_wall_run_after_landing()
	player.velocity = Vector3.UP * player.wall_run_vertical_speed
	player._begin_wall_run(Vector3.LEFT, Vector3.RIGHT, &"giant_enemy")
	player._detach_wall_run("probe passive giant crest", true)
	_assert(player.velocity.y <= 2.21, "passive giant vertical detachment still launches the player")
	_assert(is_zero_approx(player.wall_run_repulsion_control_lock), "passive giant vertical detachment unnecessarily locks air steering")

	# Isolate traversal framing from the heavy/light attack FOV residue exercised
	# immediately above; those systems are composed in runtime but tested apart.
	player.combat_feedback.fov_offset = 0.0
	player.combat_feedback.camera_kick = Vector3.ZERO
	player.combat_feedback.perfect_response_active = false
	player.combat_feedback.cinematic_active = false
	player.combat_feedback.epic_run_kind = StringName()
	player.combat_feedback.epic_run_contact_active = false
	player.combat_feedback.epic_run_envelope = 0.0
	player.combat_feedback.epic_run_elapsed = 0.0
	player.combat_feedback.wall_run_envelope = 0.0
	player.combat_feedback.time_effect_owned = false
	Engine.time_scale = 1.0
	player.camera_distance = 7.0
	player.spring_arm.spring_length = 7.0
	player._reset_epic_wall_run_camera_settings()
	player.combat_feedback.configure_epic_wall_run_settings(player.epic_wall_run_camera_settings)
	player.wall_run_active = true
	player.wall_run_mode = &"horizontal"
	player.wall_run_normal = Vector3.LEFT
	player.wall_run_last_tangent = Vector3.FORWARD
	for frame: int in range(5):
		player._update_camera(0.05)
		player.combat_feedback._tick_feedback(0.05)
	_assert(player.camera.fov > player.camera_base_fov + 1.0, "wall-run camera FOV accent did not engage (fov=%.2f base=%.2f envelope=%.2f)" % [player.camera.fov, player.camera_base_fov, player.combat_feedback.wall_run_envelope])
	_assert(absf(player.camera.rotation.z) > deg_to_rad(0.5), "wall-run camera roll did not engage")
	player.wall_run_active = false
	for frame: int in range(20):
		player._update_camera(0.05)
		player.combat_feedback._tick_feedback(0.05)
	_assert(absf(player.camera.fov - player.camera_base_fov) < 0.2, "wall-run camera FOV did not recover smoothly")
	_assert(absf(player.camera.rotation.z) < deg_to_rad(0.2), "wall-run camera roll did not recover smoothly")

	player._begin_wall_run(Vector3.LEFT, Vector3.FORWARD, &"giant_enemy")
	player.combat_feedback._tick_feedback(0.05)
	var giant_raw_entry: float = player.combat_feedback.epic_run_envelope
	var giant_eased_entry: float = player.combat_feedback._epic_run_eased_envelope()
	_assert(giant_eased_entry < giant_raw_entry, "giant run camera did not ease in gently from zero")
	for frame: int in range(14):
		player._update_camera(0.05)
		player.combat_feedback._tick_feedback(0.05)
	var giant_run_scale: float = Engine.time_scale
	_assert(player.combat_feedback.is_epic_wall_run_active(), "giant run did not activate the global epic traversal feedback")
	_assert(giant_run_scale > 0.68 and giant_run_scale < 0.84, "giant run slow motion is not in the reduced readable range")
	_assert(player.combat_feedback.epic_run_label.text == "GIANT RUN", "giant run HUD callout is ambiguous")
	_assert(player.combat_feedback.epic_run_hud_root.visible, "giant run HUD was not shown")
	_assert(absf(player.camera.fov - player.camera_base_fov) < 0.75, "giant run did not preserve the newly tuned subtle FOV zoom")
	_assert(player.camera_yaw.global_position.y - player.global_position.y < 0.25, "giant run camera pivot did not settle near the newly tuned 0.10 metre height")
	_assert(player.camera.rotation.x > deg_to_rad(20.0), "giant run camera did not adopt the strong upward-looking angle")
	_assert(player.spring_arm.spring_length < player.camera_distance - 0.55, "giant run camera did not move closer through the SpringArm (length=%.2f base=%.2f envelope=%.2f)" % [player.spring_arm.spring_length, player.camera_distance, player.combat_feedback.epic_run_envelope])
	player._detach_wall_run("short giant feedback probe", false)
	player.combat_feedback._tick_feedback(0.04)
	_assert(player.combat_feedback.is_epic_wall_run_active(), "a short giant run snapped its presentation off")
	_assert(player.combat_feedback._epic_run_eased_envelope() > player.combat_feedback.epic_run_envelope, "giant run camera did not ease out from full strength")
	for frame: int in range(24):
		player._update_camera(0.05)
		player.combat_feedback._tick_feedback(0.05)
	_assert(not player.combat_feedback.is_epic_wall_run_active(), "giant run presentation did not release")
	_assert(is_equal_approx(Engine.time_scale, 1.0), "giant run did not restore the global time scale")
	_assert(player.spring_arm.spring_length > player.camera_distance - 0.20, "giant run camera distance did not recover")

	player._reset_wall_run_after_landing()
	# Explicit rightward travel: the camera must orbit to the player's left and
	# look right, so it remains behind the action rather than watching side-on.
	player._begin_wall_run(Vector3.FORWARD, Vector3.RIGHT, &"phalanx_shields")
	for frame: int in range(10):
		player._update_camera(0.05)
		player.combat_feedback._tick_feedback(0.05)
	_assert(player.combat_feedback.epic_run_label.text == "SHIELD RUN", "shield run HUD callout is ambiguous")
	_assert(Engine.time_scale > giant_run_scale and Engine.time_scale > 0.86, "shield run did not use the newly tuned light slow-motion profile")
	_assert(absf(player.camera.h_offset) > 0.20, "shield run did not engage its lateral camera displacement")
	var rightward_camera_forward: Vector3 = -player.camera_yaw.global_basis.z
	rightward_camera_forward.y = 0.0
	rightward_camera_forward = rightward_camera_forward.normalized()
	var rightward_camera_position_side: Vector3 = player.camera_yaw.global_basis.z
	rightward_camera_position_side.y = 0.0
	rightward_camera_position_side = rightward_camera_position_side.normalized()
	_assert(rightward_camera_forward.dot(Vector3.RIGHT) > 0.90, "rightward shield run camera did not look along player travel")
	_assert(rightward_camera_position_side.dot(Vector3.LEFT) > 0.90, "rightward shield run camera did not move behind the player on the left")
	_assert(player.camera_pitch.rotation.x > -0.12, "shield run SpringArm did not ease toward a low, level position")
	_assert(player.camera.rotation.x > deg_to_rad(5.0), "shield run camera did not aim back up at the player")

	var yaw_before_direction_change: float = player.camera_yaw.rotation.y
	player.wall_run_last_tangent = Vector3.BACK
	player._update_camera(0.05)
	player.combat_feedback._tick_feedback(0.05)
	var first_yaw_step: float = absf(angle_difference(yaw_before_direction_change, player.camera_yaw.rotation.y))
	_assert(first_yaw_step < deg_to_rad(40.0), "wall-run direction change snapped the chase camera")
	for frame: int in range(9):
		player._update_camera(0.05)
		player.combat_feedback._tick_feedback(0.05)
	var changed_camera_forward: Vector3 = -player.camera_yaw.global_basis.z
	changed_camera_forward.y = 0.0
	changed_camera_forward = changed_camera_forward.normalized()
	_assert(changed_camera_forward.dot(Vector3.BACK) > 0.90, "chase camera did not follow the changed wall-run direction")
	var horizontal_focus_height: float = player.combat_feedback.epic_camera_focus_height(player.camera_pivot_height)
	var horizontal_fov: float = player.camera.fov
	player.wall_run_mode = &"diagonal"
	for frame: int in range(8):
		player._update_camera(0.05)
		player.combat_feedback._tick_feedback(0.05)
	_assert(player.combat_feedback.wall_run_orientation_blend.y > 0.70, "diagonal run did not blend into its camera profile")
	var diagonal_focus_height: float = player.combat_feedback.epic_camera_focus_height(player.camera_pivot_height)
	_assert(diagonal_focus_height < horizontal_focus_height, "diagonal run did not lower the player focus beyond the lateral profile")
	var rotation_before_vertical: Vector3 = player.camera.rotation
	player.wall_run_mode = &"vertical"
	player._update_camera(0.05)
	player.combat_feedback._tick_feedback(0.05)
	_assert(player.camera.rotation.distance_to(rotation_before_vertical) < deg_to_rad(3.0), "orientation change snapped the epic camera rotation")
	for frame: int in range(10):
		player._update_camera(0.05)
		player.combat_feedback._tick_feedback(0.05)
	_assert(player.combat_feedback.wall_run_orientation_blend.z > 0.85, "vertical run did not blend into its camera profile")
	_assert(player.camera.rotation.x > deg_to_rad(3.0), "vertical run camera did not adopt the low upward-looking angle")
	_assert(player.camera.fov < horizontal_fov - 0.45, "vertical run did not receive the stronger directional focus zoom")
	player._detach_wall_run("short shield feedback probe", false)
	for frame: int in range(24):
		player._update_camera(0.05)
		player.combat_feedback._tick_feedback(0.05)
	_assert(is_equal_approx(Engine.time_scale, 1.0), "shield run did not restore the global time scale")
	player._reset_wall_run_after_landing()

	_assert(player._wall_run_corner_is_interior(Vector3.BACK, Vector3.RIGHT, Vector3.LEFT), "90-degree interior corner was rejected")
	_assert(not player._wall_run_corner_is_interior(Vector3.FORWARD, Vector3.RIGHT, Vector3.RIGHT), "270-degree exterior corner was accepted")
	player.global_position = Vector3(0.80, 0.05, 0.45)
	player.wall_run_active = true
	player.wall_run_mode = &"horizontal"
	player.wall_run_normal = Vector3.BACK
	player.wall_run_last_tangent = Vector3.RIGHT
	var transferred_corner: Dictionary = player._try_transfer_wall_corner(Vector3.RIGHT)
	_assert(not transferred_corner.is_empty() and player.wall_run_normal.dot(Vector3.LEFT) > 0.99, "connected interior corner did not transfer to the next wall")
	_assert(player.wall_run_corner_tangent.dot(Vector3.BACK) > 0.99, "interior corner did not rotate travel along the next wall")

	player._reset_wall_run_after_landing()
	_assert(player.animation_driver == null or (not player.animation_driver.wall_release_air_pose_requested and not player.animation_driver.wall_release_air_pose_active), "landing did not clear the wall-release airborne pose")

	# Regression: on a convex cylinder the surface normal rotates until the held
	# direction has almost no tangent component. Normalizing that tiny projection
	# used to flip the run direction every few frames and loop the chase camera.
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.set_physics_process(false)
	player.camera_yaw.rotation.y = 0.0
	player.global_position = Vector3(21.19, 1.0, 0.0)
	player.velocity = Vector3.FORWARD * player.wall_run_horizontal_speed
	Input.action_press(&"move_forward")
	player._begin_wall_run(Vector3.RIGHT, Vector3.FORWARD)
	var cylinder_detach_frame: int = -1
	for frame: int in range(30):
		player._update_wall_run(1.0 / 60.0)
		if not player.wall_run_active:
			cylinder_detach_frame = frame
			break
	Input.action_release(&"move_forward")
	_assert(cylinder_detach_frame >= 0 and cylinder_detach_frame < 20, "cylindrical wall run reached the tangent reversal instead of detaching")
	_assert(player.wall_run_debug_reason == "curved surface course exhausted", "cylindrical wall run did not report the isolated tangent-collapse trigger")
	_assert(player.wall_run_passive_detach_locked, "cylindrical tangent collapse did not reuse passive end-of-run detachment")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player._reset_wall_run_after_landing()

	player.global_position = Vector3(0.0, 0.05, 1.0)
	player.velocity = Vector3.UP * 6.0
	player._begin_wall_run(Vector3.BACK, Vector3.FORWARD)
	_assert(player.wall_run_runs_used == 1 and not player.wall_run_attach_available, "vertical wall-run setup did not consume the airborne attachment")
	var climb_started: bool = player._try_start_parkour(Vector3.FORWARD, true)
	_assert(climb_started and player.parkour_active and player.parkour_kind == &"climb", "climb did not override the vertical wall-run at a reachable lip")
	_assert(player.parkour_started_from_wall_run, "climb did not remember that it interrupted a wall run")
	player._finish_parkour()
	_assert(not player.parkour_active and not player.parkour_started_from_wall_run, "wall-run mantle did not finish cleanly")
	_assert(player.wall_run_attach_available and player.wall_run_runs_used == 0, "wall-run mantle did not rearm before an immediate jump")
	_assert(player.wall_run_debug_reason == "parkour exit -> rearmed", "wall-run mantle rearm did not report its dedicated exit path")

	if failures.is_empty():
		print("[WALL RUN PROBE] PASS — wall combat, curved-surface detach, mantle rearm, enemy traversal, reduced slow-mo, behind-player chase framing, foot-focus aim, directional blends, short-contact tails and corners")
	else:
		for failure: String in failures:
			push_error("[WALL RUN PROBE] " + failure)
	world.free()
	quit(0 if failures.is_empty() else 1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
