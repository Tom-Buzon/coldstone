extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")
const AssetLibraryRoomScript = preload("res://scripts/environment/asset_library_room.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node3D.new()
	scene.name = "ElementalSwordsProbe"
	root.add_child(scene)
	current_scene = scene
	var player := PlayerScript.new() as HopliteUALNativePlayer
	scene.add_child(player)
	await process_frame
	assert(player.set_player_skin(HopliteUALNativePlayer.PLAYER_SKIN_BASE))
	await process_frame

	assert(EquipmentCatalogScript.ELEMENTAL_SWORDS.size() == 7, "The elemental pack must contain seven swords")
	for item: HopliteEquipmentItemData in EquipmentCatalogScript.ELEMENTAL_SWORDS:
		assert(item.has_valid_weapon_contact(), "Invalid blade contact for %s" % item.item_id)
		assert(item.blade_tip_y > item.blade_base_y + 0.55, "Blade segment is too short for %s" % item.item_id)
		assert(player.equip_item(item), "Could not equip %s" % item.item_id)
		await process_frame
		assert(player.sword_root.find_child(String(item.visual_mesh_name), true, false) is MeshInstance3D, "Missing mapped mesh for %s" % item.item_id)
		assert(is_equal_approx(player.sword_base.position.y, item.blade_base_y), "Wrong blade base for %s" % item.item_id)
		assert(is_equal_approx(player.sword_tip.position.y, item.blade_tip_y), "Wrong blade tip for %s" % item.item_id)
		assert(is_equal_approx(player.weapon_hit_radius, item.hit_radius), "Wrong hit radius for %s" % item.item_id)
		assert(player.sword_blade_material != null, "Missing charge material mapping for %s" % item.item_id)

	var scanner := AssetLibraryRoomScript.new()
	var catalog := scanner.call("_scan_catalog") as Array[Dictionary]
	scanner.free()
	for item: HopliteEquipmentItemData in EquipmentCatalogScript.ELEMENTAL_SWORDS:
		assert(catalog.any(func(entry: Dictionary) -> bool:
			return EquipmentCatalogScript.item_for_visual_path(String(entry.get("path", ""))) == item \
				and bool(entry.get("equipment_pickup", false))
		), "Forge entry is missing for %s" % item.item_id)

	print("[ELEMENTAL SWORDS PROBE] PASS — 7 swords mapped, equipped and exposed in Forge")
	quit(0)
