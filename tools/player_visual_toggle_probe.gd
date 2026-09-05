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
	assert(player.get_player_skin_definitions().size() == 3, "Automatic player-skin scan did not find base + two GLBs")
	assert(player.set_player_skin(HopliteUALNativePlayer.PLAYER_SKIN_BASE), "Could not activate the base UAL visual")
	assert(not player.uses_alternate_visual(), "Base UAL visual must not be considered alternate")
	assert(player.skeleton != null and player.animation_driver != null, "Base player rig is incomplete")
	for skin_id: StringName in [HopliteUALNativePlayer.PLAYER_SKIN_NOON, HopliteUALNativePlayer.PLAYER_SKIN_SAMUS]:
		assert(player.set_player_skin(skin_id), "Could not activate player skin: %s" % String(skin_id))
		await process_frame
		assert(player.get_player_skin_id() == skin_id, "Player skin state was not retained: %s" % String(skin_id))
		assert(player.skeleton != null and player.skeleton.get_bone_count() == 53, "Player skin rig is incompatible: %s" % String(skin_id))
		assert(player.animation_player != null and player.animation_player.get_animation_list().size() >= 46, "Player skin animation library is incomplete: %s" % String(skin_id))
		assert(player.animation_driver != null and player.sword_attachment != null and player.shield_attachment != null, "Player skin combat equipment/animation is incomplete: %s" % String(skin_id))
		var parts := player.get_player_skin_parts()
		assert(not parts.is_empty(), "Player skin meshes were not exposed as configurable parts: %s" % String(skin_id))
		var first_part_id := StringName(parts[0]["id"])
		assert(player.set_player_skin_part_enabled(first_part_id, false), "Could not hide a player skin part")
		assert(not bool(player.get_player_skin_parts()[0]["enabled"]), "Player skin part state did not update")
		assert(player.set_player_skin_part_enabled(first_part_id, true), "Could not restore a player skin part")
	assert(player.set_player_skin(HopliteUALNativePlayer.PLAYER_SKIN_BASE), "Could not return to the base visual")
	await process_frame
	assert(not player.uses_alternate_visual(), "Base player state was not restored")
	assert(player.animation_driver != null and player.sword_attachment != null, "Base combat visual did not rebuild")
	print("[PLAYER SKIN SELECTION PROBE] PASS — base -> Noon T1 -> Samus Woopsy -> base")
	quit(0)
