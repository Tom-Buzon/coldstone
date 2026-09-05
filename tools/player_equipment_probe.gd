extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")
const AEGIS_FANG: HopliteEquipmentItemData = preload("res://data/equipment/weapons/aegis_fang.tres")
const XIPHOS: HopliteEquipmentItemData = preload("res://data/equipment/weapons/xiphos.tres")
const TITAN_AEGIS: HopliteEquipmentItemData = preload("res://data/equipment/shields/titan_aegis.tres")
const ASPIS: HopliteEquipmentItemData = preload("res://data/equipment/shields/aspis.tres")
const AEGIS_FANG_PICKUP := preload("res://scenes/equipment/aegis_fang_pickup.tscn")
const XIPHOS_PICKUP := preload("res://scenes/equipment/xiphos_pickup.tscn")
const TITAN_AEGIS_PICKUP := preload("res://scenes/equipment/titan_aegis_pickup.tscn")
const ASPIS_PICKUP := preload("res://scenes/equipment/aspis_pickup.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node3D.new()
	scene.name = "PlayerEquipmentProbe"
	root.add_child(scene)
	current_scene = scene
	var player := PlayerScript.new() as HopliteUALNativePlayer
	scene.add_child(player)
	await process_frame
	assert(player.set_player_skin(HopliteUALNativePlayer.PLAYER_SKIN_BASE), "Could not activate base player")
	await process_frame

	_assert_weapon(player, XIPHOS, "SM_Xiphos_Main")
	_assert_shield(player, ASPIS, "SM_Aspis_Shield")
	_assert_interact_binding()

	await _collect_with_interact(scene, player, AEGIS_FANG_PICKUP)
	_assert_weapon(player, AEGIS_FANG, "SM_Aegis_Fang")
	assert(is_equal_approx(player.weapon_hit_radius, 0.14), "Aegis Fang hit radius was not equipped")
	_assert_dropped_replacement(scene, XIPHOS)
	await _collect_with_interact(scene, player, TITAN_AEGIS_PICKUP)
	_assert_shield(player, TITAN_AEGIS, "SM_Titan_Aegis")
	_assert_dropped_replacement(scene, ASPIS)
	assert(player.shield_root.get_parent() == player.shield_attachment, "Shield hand attachment must be its pivot")
	assert(player.shield_root.global_position.distance_to(player.shield_attachment.global_position) < 0.09, "Shield must stay in contact with the left hand")
	assert(player.shield_root.global_basis.y.normalized().dot(Vector3.UP) > 0.995, "Resting shield must remain upright")
	assert(player.shield_root.global_basis.z.normalized().dot(-player.global_basis.x.normalized()) > 0.995, "Resting shield front must face outward on the player's left side")
	var player_basis := Basis(Vector3.UP, player.rotation.y).orthonormalized()
	var expected_guard_orientation := Basis(-player_basis.x, player_basis.y, -player_basis.z)
	player.shield_blocking = true
	player._set_shield_guard_visual_enabled(true)
	assert(player.shield_root.global_basis.orthonormalized().x.dot(expected_guard_orientation.x) > 0.999, "Shield guard discarded the authored hand-pivot rotation")
	assert(player.shield_root.global_basis.orthonormalized().z.dot(-player.global_basis.z.normalized()) > 0.999, "Shield decorated face must point forward during guard")
	player.shield_blocking = false
	player._set_shield_guard_visual_enabled(false)

	# Equipment must survive a visual skin rebuild because it belongs to gameplay,
	# not to one imported skeleton instance.
	assert(player.set_player_skin(HopliteUALNativePlayer.PLAYER_SKIN_NOON), "Could not activate Noon skin")
	await process_frame
	_assert_weapon(player, AEGIS_FANG, "SM_Aegis_Fang")
	_assert_shield(player, TITAN_AEGIS, "SM_Titan_Aegis")

	await _collect_with_interact(scene, player, XIPHOS_PICKUP)
	_assert_weapon(player, XIPHOS, "SM_Xiphos_Main")
	assert(is_equal_approx(player.weapon_hit_radius, 0.12), "Xiphos hit radius was not restored")
	await _collect_with_interact(scene, player, ASPIS_PICKUP)
	_assert_shield(player, ASPIS, "SM_Aspis_Shield")

	print("[PLAYER EQUIPMENT PROBE] PASS — E pickups swap visuals and weapon contact geometry")
	quit(0)


func _collect_with_interact(scene: Node3D, player: HopliteUALNativePlayer, pickup_scene: PackedScene) -> void:
	var pickup := pickup_scene.instantiate() as Area3D
	scene.add_child(pickup)
	pickup.global_position = player.global_position
	player.register_equipment_pickup(pickup)
	player.player_combat_hud.call("_sync_hud")
	var prompt := player.player_combat_hud.find_child("EquipmentPickupPrompt", true, false) as Control
	var prompt_text := player.player_combat_hud.find_child("EquipmentPickupPromptText", true, false) as Label
	assert(prompt != null and prompt.visible, "Equipment pickup prompt must be visible in range")
	assert(prompt_text != null and String(pickup.equipment.display_name).to_upper() in prompt_text.text, "Equipment pickup prompt must name the item")
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	player._unhandled_input(event)
	await process_frame
	assert(not is_instance_valid(pickup), "Interact did not consume the equipment pickup")
	player.player_combat_hud.call("_sync_hud")
	assert(prompt.visible, "The dropped replacement must remain interactable")
	assert(not prompt_text.text.is_empty(), "The replacement pickup prompt must name a nearby item")


func _assert_weapon(player: HopliteUALNativePlayer, expected: HopliteEquipmentItemData, mesh_name: String) -> void:
	assert(player.equipped_weapon.item_id == expected.item_id, "Wrong equipped weapon")
	assert(player.sword_root.find_child(mesh_name, true, false) is MeshInstance3D, "Missing weapon mesh: %s" % mesh_name)
	assert(is_equal_approx(player.sword_base.position.y, expected.blade_base_y), "Wrong blade base for %s" % expected.item_id)
	assert(is_equal_approx(player.sword_tip.position.y, expected.blade_tip_y), "Wrong blade tip for %s" % expected.item_id)
	assert(is_equal_approx(player.weapon_hit_radius, expected.hit_radius), "Wrong hit radius for %s" % expected.item_id)
	assert(player.sword_blade_material != null, "Weapon charge material missing for %s" % expected.item_id)


func _assert_shield(player: HopliteUALNativePlayer, expected: HopliteEquipmentItemData, mesh_name: String) -> void:
	assert(player.equipped_shield.item_id == expected.item_id, "Wrong equipped shield")
	assert(player.shield_root.find_child(mesh_name, true, false) is MeshInstance3D, "Missing shield mesh: %s" % mesh_name)


func _assert_dropped_replacement(scene: Node3D, expected: HopliteEquipmentItemData) -> void:
	var dropped := scene.find_child("Dropped_%s" % String(expected.item_id), true, false) as RigidBody3D
	assert(dropped != null, "Replaced equipment did not fall into the world: %s" % expected.item_id)
	var pickup := dropped.find_child("EquipmentPickup_%s" % String(expected.item_id), true, false) as HopliteEquipmentPickup
	assert(pickup != null and pickup.equipment == expected, "Dropped equipment is not collectible: %s" % expected.item_id)


func _assert_interact_binding() -> void:
	assert(InputMap.has_action(&"interact"), "Interact action is missing")
	var found_e := false
	for event: InputEvent in InputMap.action_get_events(&"interact"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_E:
			found_e = true
			break
	assert(found_e, "Interact action is not bound to physical E")
