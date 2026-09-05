extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Node3D.new()
	scene.name = "PlayerXiphosProbe"
	root.add_child(scene)
	current_scene = scene
	var player := PlayerScript.new() as HopliteUALNativePlayer
	scene.add_child(player)
	await process_frame
	assert(player.set_player_skin(HopliteUALNativePlayer.PLAYER_SKIN_BASE), "Could not activate the base player visual")
	_assert_xiphos_equipped(player, "base")
	for skin_id: StringName in [HopliteUALNativePlayer.PLAYER_SKIN_NOON, HopliteUALNativePlayer.PLAYER_SKIN_SAMUS]:
		assert(player.set_player_skin(skin_id), "Could not activate player skin: %s" % String(skin_id))
		await process_frame
		_assert_xiphos_equipped(player, String(skin_id))
	print("[PLAYER XIPHOS PROBE] PASS — imported xiphos equipped on all three player skins")
	quit(0)

func _assert_xiphos_equipped(player: HopliteUALNativePlayer, rig_label: String) -> void:
	assert(player.sword_attachment != null, "%s rig has no sword attachment" % rig_label)
	assert(player.sword_attachment.get_parent() == player.skeleton, "%s sword is not attached to its skeleton" % rig_label)
	assert(player.sword_attachment.bone_name == player.right_hand_bone, "%s sword is not bound to the right hand" % rig_label)
	assert(player.sword_root != null, "%s rig has no sword root" % rig_label)
	var xiphos_mesh := player.sword_root.find_child("SM_Xiphos_Main", true, false) as MeshInstance3D
	assert(xiphos_mesh != null, "%s rig does not use xiphos_main.glb" % rig_label)
	var bounds: AABB = xiphos_mesh.get_aabb()
	assert(bounds.position.y < -0.30 and bounds.end.y > 1.02, "%s xiphos scale/origin is invalid: %s" % [rig_label, bounds])
	assert(player.sword_base != null and player.sword_tip != null, "%s rig has no blade contact markers" % rig_label)
	assert(is_equal_approx(player.sword_base.position.y, 0.12), "%s blade base marker moved" % rig_label)
	assert(is_equal_approx(player.sword_tip.position.y, 1.03), "%s blade tip marker moved" % rig_label)
	assert(player.sword_blade_material != null, "%s xiphos steel material is not configurable" % rig_label)
	var configured_surface_found := false
	for surface_index: int in range(xiphos_mesh.mesh.get_surface_count()):
		if xiphos_mesh.get_active_material(surface_index) == player.sword_blade_material:
			configured_surface_found = true
			break
	assert(configured_surface_found, "%s charge material is not assigned to the xiphos blade" % rig_label)
