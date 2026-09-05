extends SceneTree

const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.2, 3.0)
	camera.current = true
	world.add_child(camera)
	var actor := Factory.create(&"ngeneral") as HopliteEnemyActorV2
	actor.lod_reference = camera
	world.add_child(actor)
	var skeleton := actor.presentation.skeleton
	actor.play_semantic_animation(&"block_idle")
	actor.animation.player.seek(1.0, true)
	await process_frame
	for bone_name: String in ["DEF-hand.R", "DEF-hand.L", "DEF-forearm.R", "DEF-forearm.L"]:
		var pose := skeleton.get_bone_global_pose(skeleton.find_bone(bone_name))
		print("EQUIPMENT_AXIS bone=", bone_name, " origin=", pose.origin, " x=", pose.basis.x.normalized(), " y=", pose.basis.y.normalized(), " z=", pose.basis.z.normalized())
	var spear_mesh := actor.equipment.weapon_attachment.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var shield_mesh := actor.equipment.shield_mesh as MeshInstance3D
	print("EQUIPMENT_AXIS shield_aabb=", shield_mesh.mesh.get_aabb())
	actor.animation.set_manual_sampling(true)
	for sample: Dictionary in [
		{"semantic": &"idle", "time": 0.5},
		{"semantic": &"move", "time": 0.5},
		{"semantic": &"block_idle", "time": 1.0},
		{"semantic": &"spear_thrust", "time": 0.25},
		{"semantic": &"spear_thrust", "time": 0.75},
		{"semantic": &"spear_thrust_low", "time": 0.75},
		{"semantic": &"spear_bayonet_step", "time": 1.55},
	]:
		actor.equipment.set_weapon_grip(&"bayonet" if StringName(sample["semantic"]) == &"spear_bayonet_step" else &"standard")
		actor.animation.play_semantic(StringName(sample["semantic"]), 0.0)
		actor.animation.player.seek(float(sample["time"]), true)
		actor.animation.player.advance(0.0)
		skeleton.force_update_all_bone_transforms()
		await process_frame
		# The long combat spearhead is authored on local +Y; -Y is the sauroter.
		var spear_direction := (actor.global_basis.inverse() * spear_mesh.global_basis * Vector3.UP).normalized()
		# The imported mesh AABB proves that Z is the thin/disc-normal axis; Y is up.
		var shield_front := (actor.global_basis.inverse() * shield_mesh.global_basis * Vector3.BACK).normalized()
		var shield_up := (actor.global_basis.inverse() * shield_mesh.global_basis * Vector3.UP).normalized()
		var shield_center := actor.global_transform.affine_inverse() * shield_mesh.global_position
		print("EQUIPMENT_AXIS pose=", sample["semantic"], " time=", sample["time"], " spear_tip=", spear_direction, " shield_front=", shield_front, " shield_up=", shield_up, " shield_center=", shield_center)
		_expect(spear_direction.dot(Vector3.BACK) > 0.80, "%s sends the spear behind the authored visual" % sample["semantic"])
		_expect(shield_front.dot(Vector3.BACK) > 0.98, "%s turns the actor-space aspis away from the target" % sample["semantic"])
		_expect(shield_up.dot(Vector3.UP) > 0.98, "%s turns the actor-space aspis out of vertical alignment" % sample["semantic"])
		_expect(shield_center.distance_to(Vector3(0.36, 1.08, 0.32)) < 0.02, "%s detached the aspis from its stable guard anchor" % sample["semantic"])
	_expect(actor.equipment.shield_attachment.bone_name == "DEF-forearm.L", "aspis is not attached to the left forearm")
	_expect(bool(actor.equipment.weapon_attachment.get_child(0).get_child(0).get_meta("hoplite_v2_grip_calibrated", false)), "spear calibration marker is missing")
	_expect(bool(shield_mesh.get_meta("hoplite_v2_actor_space_anchor", false)), "shield actor-space calibration marker is missing")
	_expect(actor.equipment.shield_hitbox == null or actor.equipment.shield_hitbox.get_parent() == shield_mesh, "shield debug collider is detached from the visible disc")
	actor.free()
	world.free()
	if failures.is_empty():
		print("HOPLITE_V2_EQUIPMENT_ORIENTATION_PROBE PASS idle=anchored move=anchored attacks=anchored collider=disc")
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 EQUIPMENT ORIENTATION] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
