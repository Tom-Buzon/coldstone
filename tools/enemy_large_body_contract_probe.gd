extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const Archetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const NavigationComponent = preload("res://scripts/ai/enemy_navigation_component.gd")

var archetype: StringName = &"boss_colossus"
var failures: Array[String] = []


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--id="):
			archetype = StringName(argument.trim_prefix("--id="))
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var target := Node3D.new()
	target.add_to_group("player")
	target.position = Vector3(0.0, 0.0, -9.0)
	world.add_child(target)
	var enemy = EnemyFactory.spawn(world, archetype, Vector3.ZERO, target, {
		"ai_enabled": true,
		"mass_battle_mode": false,
	})
	await process_frame
	await physics_frame
	_expect(enemy != null, "%s could not be spawned through the factory" % archetype)
	if enemy != null:
		enemy.set_process(false)
		enemy.set_physics_process(false)
		_validate_profile_contract(enemy)
		_validate_collision_contract(enemy)
		_validate_large_body_navigation(enemy)

	world.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("ENEMY_LARGE_BODY_CONTRACT_PROBE PASS id=%s mode=LARGE_BODY recovery=bounded collider=primitive profile_contract=exact cleanup=true" % archetype)
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _validate_profile_contract(enemy: Node) -> void:
	var profile: Dictionary = Archetypes.profile(archetype)
	var pattern: Array = Array(profile.get("combat_pattern", []))
	var ids: Array[StringName] = []
	for raw_step: Variant in pattern:
		if raw_step is Dictionary:
			ids.append(StringName((raw_step as Dictionary).get("id", StringName())))
	_expect(not pattern.is_empty(), "%s has no declared large-body combat pattern" % archetype)
	match archetype:
		&"boss_colossus":
			_expect(StringName(profile.get("rank", StringName())) == &"miniboss", "%s historical rank is no longer the declared miniboss contract" % archetype)
			_expect(StringName(profile.get("behavior", StringName())) == &"brute", "%s historical brute behavior changed" % archetype)
			_expect(ids == [&"colossus_crush", &"colossus_quake"], "%s lost its exact crush/quake action contract: %s" % [archetype, ids])
			_expect(StringName(pattern[1].get("special", StringName())) == &"shockwave" and float(pattern[1].get("radius", 0.0)) >= 3.4, "%s quake is not an explicit radial shockwave" % archetype)
			_expect(float(profile.get("phase_threshold", 0.0)) <= 0.0 and Array(profile.get("phase_two_pattern", [])).is_empty(), "%s unexpectedly acquired an undeclared phase" % archetype)
			enemy.health = enemy.max_health * 0.25
			enemy.call("_try_activate_combat_phase")
			_expect(enemy.combat_phase == 1, "%s changed phase despite its declared single-phase profile" % archetype)
		&"bronze_colossus":
			_expect(StringName(profile.get("rank", StringName())) == &"miniboss" and StringName(profile.get("behavior", StringName())) == &"juggernaut", "%s lost its miniboss/juggernaut identity" % archetype)
			_expect(ids == [&"colossus_roar", &"colossus_charge", &"colossus_quake", &"colossus_sweep"], "%s large-body action sequence differs from its declaration: %s" % [archetype, ids])
			_expect(StringName(pattern[2].get("special", StringName())) == &"shockwave" and float(pattern[2].get("radius", 0.0)) >= 3.8, "%s quake is not its declared radial shockwave" % archetype)
			_expect(float(profile.get("phase_threshold", 0.0)) > 0.0 and Array(profile.get("phase_two_pattern", [])).size() == 2, "%s lost its declared phase-two contract" % archetype)


func _validate_collision_contract(enemy: Node) -> void:
	var main_collision := enemy.body_collider as CollisionShape3D
	_expect(main_collision != null and main_collision.shape is CapsuleShape3D, "%s main body collider is not a primitive capsule" % archetype)
	if main_collision != null and main_collision.shape is CapsuleShape3D:
		var capsule := main_collision.shape as CapsuleShape3D
		_expect(capsule.radius > 0.0 and capsule.height >= capsule.radius * 2.0, "%s capsule dimensions are invalid" % archetype)
	var scale_value: Vector3 = enemy.global_transform.basis.get_scale()
	_expect(is_equal_approx(scale_value.x, scale_value.y) and is_equal_approx(scale_value.y, scale_value.z), "%s root scale is non-uniform" % archetype)
	for descendant: Node in enemy.find_children("*", "CollisionShape3D", true, false):
		var collision := descendant as CollisionShape3D
		_expect(not (collision.shape is ConcavePolygonShape3D), "%s uses a concave dynamic collider at %s" % [archetype, collision.get_path()])


func _validate_large_body_navigation(enemy: Node) -> void:
	var navigation = enemy.navigation_component
	_expect(navigation != null, "%s has no navigation component" % archetype)
	if navigation == null:
		return
	_expect(navigation.mode == NavigationComponent.Mode.LARGE_BODY, "%s does not select LARGE_BODY navigation" % archetype)
	_expect(enemy.get_node_or_null("NavigationAgent") == null, "%s LARGE_BODY path unexpectedly owns a NavigationAgent" % archetype)
	_expect(is_equal_approx(float(navigation.settings.get("stuck_timeout", 0.0)), 1.15), "%s lost its large-body stuck timeout" % archetype)
	_expect(is_equal_approx(float(navigation.settings.get("recovery_duration", 0.0)), 0.72), "%s lost its bounded recovery duration" % archetype)

	var recoveries: Array[int] = []
	var failures_seen: Array[StringName] = []
	navigation.recovery_started.connect(func(attempt: int) -> void: recoveries.append(attempt))
	navigation.navigation_failed.connect(func(reason: StringName) -> void: failures_seen.append(reason))
	navigation.set_destination(Vector3(0.0, 0.0, -8.0))
	var initial = navigation.sample_intent(1.0 / 60.0)
	_expect(initial.valid and initial.status == &"moving", "%s LARGE_BODY returned no direct movement intent" % archetype)
	_expect(is_equal_approx(initial.speed_scale, 0.78), "%s LARGE_BODY lost its bounded speed scale" % archetype)
	for _frame: int in range(72):
		navigation.sample_intent(1.0 / 60.0)
		navigation.notify_motion_applied(enemy.global_position, enemy.global_position, 1.0 / 60.0)
	var recovery = navigation.sample_intent(1.0 / 60.0)
	_expect(recovery.status == &"recovering" and recovery.recovery_attempt == 1, "%s did not enter first bounded recovery after simulated obstruction" % archetype)
	_expect(recoveries == [1], "%s recovery signal was not emitted exactly once: %s" % [archetype, recoveries])
	_expect(failures_seen.is_empty(), "%s failed navigation before exhausting bounded recovery" % archetype)

	var previous: Vector3 = enemy.global_position
	enemy.global_position += recovery.direction * 0.08
	navigation.notify_motion_applied(previous, enemy.global_position, 1.0 / 60.0, recovery.direction)
	for _frame: int in range(50):
		navigation.sample_intent(1.0 / 60.0)
	_expect(failures_seen.is_empty(), "%s reported failure after successful recovery progress" % archetype)
	navigation.set_destination(enemy.global_position)
	var arrival = navigation.sample_intent(1.0 / 60.0)
	_expect(arrival.status == &"arrived" and not arrival.valid, "%s did not honor arrival tolerance after recovery" % archetype)
	navigation.clear_destination()
	_expect(navigation.sample_intent(1.0 / 60.0).status == &"idle", "%s did not clear its large-body destination" % archetype)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
