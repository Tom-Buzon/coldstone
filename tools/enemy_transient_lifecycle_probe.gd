extends SceneTree

const EnemyProjectile = preload("res://scripts/combat/enemy_projectile.gd")
const BloodBurst = preload("res://scripts/gore/blood_burst.gd")
const DetachedLimb = preload("res://scripts/gore/detached_limb_proxy.gd")
const DebrisLifecycle = preload("res://scripts/gore/transient_rigid_debris_lifecycle.gd")
const Enemy = preload("res://scripts/enemy/athenian_enemy.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _probe_projectile_resources_and_expiration()
	await _probe_blood_resource_and_shadow_policy()
	await _probe_rigid_debris_retirement()
	await _probe_dropped_equipment_resource_reuse()
	await _probe_scaled_detached_collision()
	await _probe_corpse_runtime_retirement()
	if failures.is_empty():
		print("ENEMY_TRANSIENT_LIFECYCLE_PROBE PASS: shared resources, bounded TTL, corpse release, retired collision/shadows")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _probe_projectile_resources_and_expiration() -> void:
	var first := _spawn_projectile(Vector3.ZERO)
	var second := _spawn_projectile(Vector3(2.0, 0.0, 0.0))
	var stone := _spawn_projectile(Vector3(4.0, 0.0, 0.0), &"stone")
	await physics_frame
	var first_shaft := first.get_node("Shaft") as MeshInstance3D
	var second_shaft := second.get_node("Shaft") as MeshInstance3D
	_expect(first_shaft.mesh == second_shaft.mesh, "projectile shaft meshes are not shared")
	_expect(first_shaft.material_override == second_shaft.material_override, "projectile shaft materials are not shared")
	_expect(first_shaft.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "projectile still casts dynamic shadows")
	_expect(stone.has_node("Stone") and not stone.has_node("Shaft"), "post-add setup did not build the configured projectile kind")
	var cached_query: PhysicsRayQueryParameters3D = first.get("_ray_query")
	await physics_frame
	_expect(cached_query == first.get("_ray_query"), "projectile rebuilt its ray query between physics ticks")

	var first_id := first.get_instance_id()
	first.lifetime = 0.0001
	await physics_frame
	await process_frame
	_expect(is_instance_valid(first) and not first.visible and not first.is_physics_processing(), "projectile TTL did not retire the pooled node")
	var recycled := EnemyProjectile.acquire(root, &"arrow") as HopliteEnemyProjectile
	_expect(recycled.get_instance_id() == first_id, "projectile pool did not reuse the retired arrow")
	recycled.setup(null, Vector3(6.0, 0.0, 0.0), Vector3.FORWARD * 2.0, 1.0, &"arrow", 0.0, 1)
	_expect(recycled.visible and recycled.is_physics_processing() and is_equal_approx(recycled.lifetime, 4.0), "recycled projectile did not reset its runtime state")
	recycled.queue_free()
	second.queue_free()
	stone.queue_free()
	await process_frame


func _spawn_projectile(at: Vector3, kind: StringName = &"arrow") -> HopliteEnemyProjectile:
	var projectile := EnemyProjectile.new() as HopliteEnemyProjectile
	root.add_child(projectile)
	projectile.setup(null, at, Vector3.FORWARD * 2.0, 1.0, kind, 0.0, 1)
	return projectile


func _probe_blood_resource_and_shadow_policy() -> void:
	var first := BloodBurst.new() as HopliteBloodBurst
	var second := BloodBurst.new() as HopliteBloodBurst
	root.add_child(first)
	root.add_child(second)
	first.setup(Vector3.ZERO, Vector3.UP, 1.0, false)
	second.setup(Vector3.RIGHT, Vector3.UP, 1.0, false)
	var first_spray := first.get_node("BloodPrimarySpray") as GPUParticles3D
	var second_spray := second.get_node("BloodPrimarySpray") as GPUParticles3D
	_expect(first_spray.draw_pass_1 == second_spray.draw_pass_1, "blood draw meshes are not shared")
	_expect(first_spray.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "blood particles still cast dynamic shadows")
	var first_ref: WeakRef = weakref(first)
	first.expire_now()
	second.expire_now()
	await process_frame
	_expect(first_ref.get_ref() == null, "blood burst explicit expiration did not release the node")


func _probe_rigid_debris_retirement() -> void:
	var first := DetachedLimb.new() as HopliteDetachedLimbProxy
	var second := DetachedLimb.new() as HopliteDetachedLimbProxy
	root.add_child(first)
	root.add_child(second)
	first.setup(&"forearm_r", Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, 0.0)), 0.12, 0.48, Color(0.6, 0.3, 0.2), Vector3.ZERO)
	second.setup(&"forearm_r", Transform3D(Basis.IDENTITY, Vector3(2.0, 2.0, 0.0)), 0.12, 0.48, Color(0.6, 0.3, 0.2), Vector3.ZERO)
	var first_mesh := first.get_node("DetachedBody") as MeshInstance3D
	var second_mesh := second.get_node("DetachedBody") as MeshInstance3D
	_expect(first_mesh.mesh == second_mesh.mesh, "detached limb meshes are not shared for identical dimensions")
	_expect(first_mesh.material_override == second_mesh.material_override, "detached limb materials are not shared for identical colors")

	var lifecycle := first.get_node("TransientDebrisLifecycle")
	lifecycle.call("retire_now")
	await physics_frame
	_expect(bool(lifecycle.get("retired")), "debris lifecycle did not enter retired state")
	_expect(first.collision_layer == 0 and first.collision_mask == 0, "retired debris kept collision routing")
	_expect(first.freeze and first.sleeping, "retired debris kept active rigid-body simulation")
	var collision := lifecycle.get("collision_shape") as CollisionShape3D
	_expect(collision != null and collision.disabled, "retired debris collision shape stayed enabled")
	_expect(first_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "retired debris kept casting shadows")

	var first_ref: WeakRef = weakref(first)
	lifecycle.call("expire_now")
	second.queue_free()
	await process_frame
	_expect(first_ref.get_ref() == null, "debris expiration did not release the rigid body")

	var timed := RigidBody3D.new()
	var timed_collision := CollisionShape3D.new()
	timed_collision.shape = BoxShape3D.new()
	timed.add_child(timed_collision)
	root.add_child(timed)
	var timed_lifecycle: Node = DebrisLifecycle.new()
	timed.add_child(timed_lifecycle)
	timed_lifecycle.setup(timed, timed_collision, 0.08, 0.02)
	var timed_ref: WeakRef = weakref(timed)
	await create_timer(0.12).timeout
	await process_frame
	_expect(timed_ref.get_ref() == null, "two-phase debris timer did not retire and expire its body")


func _probe_dropped_equipment_resource_reuse() -> void:
	var scene_root := Node3D.new()
	root.add_child(scene_root)
	current_scene = scene_root
	var enemy := Enemy.new() as HopliteAthenianEnemy
	enemy.ai_enabled = false
	scene_root.add_child(enemy)
	await process_frame
	var carried_weapon_mesh := _first_mesh(enemy.sword_root)
	var carried_shield_mesh := _first_mesh(enemy.shield_root)
	enemy.call("_drop_weapon")
	enemy.call("_drop_shield")
	var dropped_weapon := scene_root.find_child("DroppedAthenian*", true, false) as RigidBody3D
	if dropped_weapon != null and dropped_weapon.name == "DroppedAthenianShield":
		dropped_weapon = null
		for child: Node in scene_root.get_children():
			if child is RigidBody3D and child.name != "DroppedAthenianShield":
				dropped_weapon = child as RigidBody3D
				break
	var dropped_shield := scene_root.get_node_or_null("DroppedAthenianShield") as RigidBody3D
	_expect(dropped_weapon != null, "weapon drop did not create a bounded rigid prop")
	_expect(dropped_shield != null, "shield drop did not create a bounded rigid prop")
	if dropped_weapon != null:
		_expect(_first_mesh(dropped_weapon) == carried_weapon_mesh, "dropped weapon rebuilt its carried mesh resource")
		_expect(dropped_weapon.has_node("TransientDebrisLifecycle"), "dropped weapon has no lifecycle component")
		dropped_weapon.get_node("TransientDebrisLifecycle").call("expire_now")
	if dropped_shield != null:
		_expect(_first_mesh(dropped_shield) == carried_shield_mesh, "dropped shield rebuilt its carried mesh resource")
		_expect(dropped_shield.has_node("TransientDebrisLifecycle"), "dropped shield has no lifecycle component")
		dropped_shield.get_node("TransientDebrisLifecycle").call("expire_now")
	enemy.queue_free()
	await process_frame
	current_scene = null
	scene_root.queue_free()
	await process_frame


func _probe_scaled_detached_collision() -> void:
	var scene_root := Node3D.new()
	root.add_child(scene_root)
	current_scene = scene_root
	var enemy := Enemy.new() as HopliteAthenianEnemy
	enemy.archetype_id = &"giant_standard"
	enemy.external_scale_multiplier = 3.0
	enemy.ai_enabled = false
	scene_root.add_child(enemy)
	await process_frame
	await physics_frame
	var expected_radius: float = enemy.anatomy.get_zone_world_radius(&"forearm_r")
	var hit = preload("res://scripts/combat/hit_event.gd").new()
	hit.damage = 1.0
	hit.sever_damage = 10000.0
	hit.position = enemy.anatomy.get_zone_world_center(&"forearm_r")
	hit.direction = Vector3.RIGHT
	hit.source = null
	enemy.defense_mode = &"none"
	enemy.armor_sever_multiplier = 1.0
	enemy.receive_anatomy_hit(hit, &"forearm_r")
	await process_frame
	var fragment := scene_root.find_child("SpartanDetached_forearm_r", true, false) as RigidBody3D
	_expect(fragment != null, "scaled package sever spawned no real detached fragment")
	if fragment != null:
		_expect(fragment.has_node("TransientDebrisLifecycle"), "real package fragment has no bounded lifecycle")
		var collision := fragment.find_child("DetachedCollision", true, false) as CollisionShape3D
		var capsule := collision.shape as CapsuleShape3D if collision != null else null
		_expect(capsule != null and absf(capsule.radius - expected_radius) <= 0.001, "scaled detached collision radius diverged from anatomy (expected %.3f)" % expected_radius)
	for child: Node in scene_root.get_children():
		child.queue_free()
	await process_frame
	current_scene = null
	scene_root.queue_free()
	await process_frame


func _first_mesh(node: Node) -> Mesh:
	if node == null:
		return null
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	for candidate: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			return mesh_instance.mesh
	return null


func _probe_corpse_runtime_retirement() -> void:
	var corpse := Enemy.new() as HopliteAthenianEnemy
	var geometry := MeshInstance3D.new()
	geometry.mesh = BoxMesh.new()
	geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	corpse.add_child(geometry)
	var particles := GPUParticles3D.new()
	particles.emitting = true
	corpse.add_child(particles)
	root.add_child(corpse)
	corpse.dead = true
	corpse.corpse_lifetime = 0.03
	corpse.set_process(true)
	corpse.call("_retire_corpse_runtime")
	_expect(not corpse.is_processing(), "settled corpse kept its per-frame process callback")
	_expect(geometry.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "settled corpse kept dynamic shadows")
	_expect(not particles.emitting, "settled corpse kept particle emission active")
	var corpse_ref: WeakRef = weakref(corpse)
	corpse.call("_schedule_corpse_release", 0.0)
	await create_timer(0.06).timeout
	await process_frame
	_expect(corpse_ref.get_ref() == null, "general corpse TTL did not release the node")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
