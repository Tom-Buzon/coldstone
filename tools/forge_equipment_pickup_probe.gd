extends SceneTree

const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")
const AssetLibraryRoomScript = preload("res://scripts/environment/asset_library_room.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scanner := AssetLibraryRoomScript.new()
	var catalog := scanner.call("_scan_catalog") as Array[Dictionary]
	scanner.free()
	var equipment_entries := catalog.filter(
		func(entry: Dictionary) -> bool: return bool(entry.get("equipment_pickup", false))
	)
	assert(equipment_entries.size() == EquipmentCatalogScript.ITEMS_BY_VISUAL_PATH.size(), "Forge must expose every registered collectible equipment model")
	assert(equipment_entries.all(func(entry: Dictionary) -> bool: return not bool(entry.get("collision_enabled", true))), "Forge equipment must not default to a blocking collider")

	var scene := Node3D.new()
	scene.name = "ForgeEquipmentPickupProbe"
	root.add_child(scene)
	current_scene = scene

	var document := WorldDocumentScript.new(WorldDocumentScript.create_default())
	document.add_entity(WorldDocumentScript.entity("player_spawn", "Spawn", Vector3.ZERO, {"spawn_id": "depart"}))
	var sword_id := document.add_entity(_equipment_prop("Lame Forge", "res://assets/weapons/aegis_fang.glb", Vector3(0.25, 0.0, 0.0), 1.82))
	var shield_id := document.add_entity(_equipment_prop("Bouclier Forge", "res://assets/weapons/titan_aegis.glb", Vector3(0.70, 0.0, 0.0), 1.15))

	var runtime := WorldRuntimeScript.new() as HopliteWorldRuntime
	scene.add_child(runtime)
	runtime.build(document, false)
	await process_frame

	var sword_holder := runtime.nodes_by_id.get(sword_id) as Node3D
	var shield_holder := runtime.nodes_by_id.get(shield_id) as Node3D
	assert(sword_holder != null and shield_holder != null, "Forge equipment props were not built")
	assert(sword_holder.find_child("EquipmentPickup_aegis_fang", true, false) is HopliteEquipmentPickup, "Placed sword did not receive pickup gameplay")
	assert(shield_holder.find_child("EquipmentPickup_titan_aegis", true, false) is HopliteEquipmentPickup, "Placed shield did not receive pickup gameplay")

	# Do not register either pickup manually: this verifies the first E press uses
	# the pickup group immediately, before body_entered is required.
	_press_interact(runtime.player)
	await process_frame
	assert(runtime.player.equipped_weapon.item_id == &"aegis_fang", "First E press did not equip the Forge sword")
	assert(not is_instance_valid(sword_holder), "Collected Forge sword prop was not removed")
	assert(runtime.find_child("Dropped_xiphos", true, false) is RigidBody3D, "The previous Forge weapon did not fall to the ground")

	runtime.player.global_position = Vector3(0.70, 0.0, 0.0)
	_press_interact(runtime.player)
	await process_frame
	assert(runtime.player.equipped_shield.item_id == &"titan_aegis", "Second E press did not equip the Forge shield")
	assert(not is_instance_valid(shield_holder), "Collected Forge shield prop was not removed")
	assert(runtime.find_child("Dropped_aspis", true, false) is RigidBody3D, "The previous Forge shield did not fall to the ground")
	assert(runtime.player.shield_root.get_parent() == runtime.player.shield_attachment, "Forge shield must keep the left hand as its pivot")
	assert(runtime.player.shield_root.global_basis.y.normalized().dot(Vector3.UP) > 0.995, "Forge shield is not upright at rest")
	assert(runtime.player.shield_root.global_basis.z.normalized().dot(-runtime.player.global_basis.x.normalized()) > 0.995, "Forge shield does not face outward on the player's left side")

	print("[FORGE EQUIPMENT PICKUP PROBE] PASS — Forge props collect instantly with E")
	quit(0)


func _equipment_prop(label: String, path: String, position: Vector3, target_height: float) -> Dictionary:
	return WorldDocumentScript.entity("prop", label, position, {
		"asset_path": path,
		"asset_label": label,
		"target_height": target_height,
		"collision_enabled": true,
	})


func _press_interact(player: HopliteUALNativePlayer) -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	player._unhandled_input(event)
