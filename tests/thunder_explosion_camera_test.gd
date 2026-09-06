extends SceneTree
const Factory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const Shot = preload("res://scripts/abilities/skill_projectile.gd")
const Contact = preload("res://scripts/abilities/projectile_contact.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := preload("res://scripts/player.gd").new()
	world.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.skills.profile.reset(true)
	var giant := Factory.create(&"giant_v2")
	giant.combat_lab_enabled = true
	world.add_child(giant)
	giant.add_to_group(&"enemy")
	giant.process_mode = Node.PROCESS_MODE_DISABLED
	giant.global_position = Vector3(0, 0, -15)
	await process_frame
	var anatomy: Node = giant.health_component.anatomy
	anatomy.force_update()
	var head: Vector3 = anatomy.get_zone_world_center(&"head")
	anatomy.set_runtime_query_enabled(false)
	var shot := Shot.new()
	shot.source = player
	shot.thunder = true
	shot.damage = 1300
	shot.charge_ratio = 1
	shot.speed = 260
	shot.position = head + Vector3.BACK * 6
	world.add_child(shot)
	shot.set_physics_process(false)
	var exact := Contact.anatomy_hit(giant, shot.global_position, head - Vector3.BACK * 2)
	check(not exact.is_empty() and exact.zone in [&"head", &"neck"], "Far LOD giant head was not detected")
	var victim := Factory.create(&"infantry_v2")
	victim.combat_lab_enabled = true
	world.add_child(victim)
	victim.add_to_group(&"enemy")
	victim.process_mode = Node.PROCESS_MODE_DISABLED
	victim.global_position = head + Vector3.RIGHT * 3 - Vector3.UP
	var before: float = victim.health
	var view: Node = player.skills.cinema.thunder_view
	view.begin(shot)
	for step: int in 12: player.skills.cinema.advance(0.016)
	check(view.camera.current and view.slow < 0.3, "Projectile camera did not own slow flight")
	shot._physics_process(0.04)
	check(giant.health_component.is_zone_severed(&"head"), "Electric hit did not sever giant head")
	check(victim.health < before, "Explosion did not damage nearby enemy")
	check(view.phase == &"impact", "Impact camera did not start")
	for step: int in 50: player.skills.cinema.advance(0.016)
	check(view.camera.global_position.y > head.y + 5, "Impact camera did not rise above explosion")
	for step: int in 100: player.skills.cinema.advance(0.016)
	check(view.phase == &"" and player.camera.current and view.slow == 1, "Camera failed to return")
	var missed := Shot.new()
	missed.source = player
	world.add_child(missed)
	view.begin(missed)
	missed.free()
	for step: int in 100: player.skills.cinema.advance(0.016)
	check(view.phase == &"" and player.camera.current, "Missing projectile trapped camera")
	var arm_giant := Factory.create(&"giant_v2")
	arm_giant.combat_lab_enabled = true
	world.add_child(arm_giant)
	arm_giant.add_to_group(&"enemy")
	arm_giant.process_mode = Node.PROCESS_MODE_DISABLED
	arm_giant.position = Vector3(20,0,-15)
	arm_giant.health_component.anatomy.force_update()
	var arm: Vector3 = arm_giant.health_component.anatomy.get_zone_world_center(&"forearm_r")
	var arm_shot := Shot.new()
	arm_shot.source = player
	arm_shot.thunder = true
	arm_shot.damage = 1300
	arm_shot.charge_ratio = 1
	arm_shot.speed = 260
	arm_shot.position = arm + Vector3.BACK * 6
	world.add_child(arm_shot)
	arm_shot.set_physics_process(false)
	arm_shot._physics_process(0.04)
	check(arm_giant.health_component.is_zone_severed(&"forearm_r") or arm_giant.health_component.is_zone_severed(&"upper_arm_r"), "Electric hit did not sever giant arm")
	player.skills.save_dirty = false
	current_scene = null
	world.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("PASS: far LOD giant head sever, radial damage, slow chase, crane and camera recovery")
	quit(0 if failures.is_empty() else 1)
