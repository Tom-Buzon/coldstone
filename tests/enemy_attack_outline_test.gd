extends SceneTree

const FaderScript = preload("res://scripts/camera/camera_occlusion_fader.gd")
const TelegraphScript = preload("res://scripts/combat/enemy_attack_telegraph.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := Node3D.new()
	world.add_child(player)
	var player_body := _mesh("PlayerBody")
	player.add_child(player_body)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var spring_arm := SpringArm3D.new()
	world.add_child(spring_arm)
	var fader := FaderScript.new() as HopliteCameraOcclusionFader
	world.add_child(fader)
	fader.configure(camera, player, spring_arm)
	fader.apply_settings(false, HopliteCameraOcclusionFader.DEFAULT_OPACITY, HopliteCameraOcclusionFader.DEFAULT_RADIUS)

	var enemy := Node3D.new()
	enemy.add_to_group(&"enemy")
	world.add_child(enemy)
	var body := _mesh("Body")
	enemy.add_child(body)
	var equipment := Node3D.new()
	enemy.add_child(equipment)
	var weapon := _mesh("Weapon")
	equipment.add_child(weapon)
	var telegraph := TelegraphScript.new() as HopliteEnemyAttackTelegraph
	enemy.add_child(telegraph)
	telegraph.configure()

	telegraph.begin(0.5)
	await process_frame
	var custom_attack_color := Color(0.9, 0.2, 0.1, 1.0)
	fader.apply_outline_settings(HopliteCameraOcclusionFader.DEFAULT_OUTLINE_COLOR, 0.68, custom_attack_color)
	fader.outline.call("_update_mask")
	_require(enemy.is_in_group(&"enemy_attack_outline_subject"), "enemy did not enter the attack-outline group during windup")
	_require(fader.outline.attack_overlay.visible, "attack outline stayed hidden while camera occlusion was disabled")
	_require(fader.outline.attack_copies.has(body.get_instance_id()), "enemy body is missing from the attack silhouette")
	_require(fader.outline.attack_copies.has(weapon.get_instance_id()), "enemy equipment is missing from the attack silhouette")
	_require(not fader.outline.overlay.visible, "the player outline was activated by an enemy warning")
	var rendered_attack_color: Color = (fader.outline.attack_overlay.material as ShaderMaterial).get_shader_parameter(&"outline_color")
	_require(rendered_attack_color.is_equal_approx(Color(custom_attack_color, 0.68)), "enemy attack outline did not use its independent color")
	fader.apply_settings(true, HopliteCameraOcclusionFader.DEFAULT_OPACITY, HopliteCameraOcclusionFader.DEFAULT_RADIUS)
	fader.set("_fade_states", {1: {&"occluded": true}})
	fader.outline.call("_update_mask")
	_require(fader.outline.overlay.visible and fader.outline.attack_overlay.visible, "player and enemy outlines cannot render simultaneously")
	_require(fader.outline.copies.has(player_body.get_instance_id()), "player silhouette disappeared while an enemy warning was active")
	var rendered_player_color: Color = (fader.outline.overlay.material as ShaderMaterial).get_shader_parameter(&"outline_color")
	_require(not rendered_player_color.is_equal_approx(rendered_attack_color), "player and enemy warning outlines still share one color")

	telegraph.clear()
	fader.outline.call("_update_mask")
	_require(not enemy.is_in_group(&"enemy_attack_outline_subject"), "enemy outline survived impact/cancellation")
	_require(not fader.outline.attack_overlay.visible, "enemy outline overlay remained visible after the warning")

	var ally := Node3D.new()
	ally.add_to_group(&"ally")
	world.add_child(ally)
	var ally_telegraph := TelegraphScript.new() as HopliteEnemyAttackTelegraph
	ally.add_child(ally_telegraph)
	ally_telegraph.configure()
	ally_telegraph.begin(0.5)
	_require(not ally.is_in_group(&"enemy_attack_outline_subject"), "allied attack received an enemy warning outline")

	_require(HopliteCameraOcclusionFader.DEFAULT_OUTLINE_COLOR.is_equal_approx(Color(0.0, 0.78622156, 0.5315931, 1.0)), "saved outline color was not promoted to the default")
	_require(HopliteCameraOcclusionFader.DEFAULT_ENEMY_ATTACK_OUTLINE_COLOR.is_equal_approx(Color(1.0, 0.141, 0.0, 1.0)), "enemy warning outline does not have its own scarlet default")
	_require(is_equal_approx(HopliteCameraOcclusionFader.DEFAULT_OUTLINE_OPACITY, 0.68), "saved outline opacity was not promoted to the default")
	_require(is_equal_approx(HopliteCameraOcclusionFader.DEFAULT_OPACITY, 0.44), "saved occluder opacity was not promoted to the default")
	_require(is_equal_approx(HopliteCameraOcclusionFader.DEFAULT_RADIUS, 0.10), "saved protection radius was not promoted to the default")

	current_scene = null
	world.queue_free()
	if failures.is_empty():
		print("PASS: enemy attack outlines and display defaults")
		quit(0)
		return
	for failure: String in failures:
		push_error("[ENEMY ATTACK OUTLINE] " + failure)
	quit(1)


func _mesh(node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = BoxMesh.new()
	return instance


func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
