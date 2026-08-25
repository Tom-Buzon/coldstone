extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Node3D.new()
	scene.name = "PlayerVisualToggleProbe"
	root.add_child(scene)
	current_scene = scene
	var player := PlayerScript.new() as HopliteUALNativePlayer
	scene.add_child(player)
	await process_frame
	assert(not player.uses_alternate_visual(), "Player must start with the base UAL visual")
	assert(player.skeleton != null and player.animation_driver != null, "Base player rig is incomplete")
	assert(player.toggle_player_visual(), "P toggle could not activate the 3DGen visual")
	await process_frame
	assert(player.uses_alternate_visual(), "3DGen state was not retained")
	assert(player.skeleton != null and player.skeleton.get_bone_count() == 53, "3DGen player rig is incompatible")
	assert(player.animation_driver != null and player.sword_attachment != null and player.shield_attachment != null, "3DGen combat equipment/animation is incomplete")
	assert(not player.toggle_player_visual(), "Second P toggle did not return to the base visual")
	await process_frame
	assert(not player.uses_alternate_visual(), "Base player state was not restored")
	assert(player.animation_driver != null and player.sword_attachment != null, "Base combat visual did not rebuild")
	print("[PLAYER VISUAL TOGGLE PROBE] PASS — base -> 3DGen -> base")
	quit(0)
