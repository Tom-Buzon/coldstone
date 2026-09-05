extends SceneTree

const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const EnemyArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")
const AssetLibraryRoomScript = preload("res://scripts/environment/asset_library_room.gd")
const AssetCatalogScript = preload("res://scripts/environment/environment_asset_catalog.gd")

func _init() -> void:
	var asset_scanner := AssetLibraryRoomScript.new()
	var catalog := asset_scanner.call("_scan_catalog") as Array[Dictionary]
	asset_scanner.free()
	var nature_entries := catalog.filter(func(entry: Dictionary) -> bool: return String(entry.get("path", "")).contains("/stylized_nature/"))
	_assert(nature_entries.size() == 68, "the complete Stylized Nature pack must expose 68 unique models")
	_assert(nature_entries.all(func(entry: Dictionary) -> bool: return not String(entry.get("preview_path", "")).is_empty()), "every nature asset must expose a catalog thumbnail")
	for expected_category: StringName in [&"trees", &"shrubs", &"ground_cover", &"rocks", &"stone_paths"]:
		_assert(nature_entries.any(func(entry: Dictionary) -> bool: return StringName(entry.get("subcategory", &"")) == expected_category), "nature catalog category missing: %s" % expected_category)
	_assert(nature_entries.filter(func(entry: Dictionary) -> bool: return StringName(entry.get("subcategory", &"")) in [&"shrubs", &"ground_cover"]).all(func(entry: Dictionary) -> bool: return not bool(entry.get("collision_enabled", true))), "shrubs and ground cover must default to no gameplay collider")
	_assert(nature_entries.filter(func(entry: Dictionary) -> bool: return String(entry.get("path", "")).get_file().begins_with("Pebble_")).all(func(entry: Dictionary) -> bool: return bool(entry.get("collision_enabled", false))), "pebbles must default to a gameplay collider")
	_assert(nature_entries.filter(func(entry: Dictionary) -> bool: return StringName(entry.get("subcategory", &"")) == &"stone_paths").all(func(entry: Dictionary) -> bool: return not bool(entry.get("collision_enabled", true))), "every stone path must default to no gameplay collider")
	_assert(nature_entries.filter(func(entry: Dictionary) -> bool: return String(entry.get("path", "")).get_file().begins_with("Rock_Medium_")).all(func(entry: Dictionary) -> bool: return bool(entry.get("collision_enabled", false)) and String(entry.get("collision_shape", "")) == "convex"), "medium rocks must keep a simplified convex collider by default")
	_assert(nature_entries.filter(func(entry: Dictionary) -> bool: return StringName(entry.get("subcategory", &"")) in [&"rocks", &"stone_paths"]).all(func(entry: Dictionary) -> bool: return bool(entry.get("align_to_ground", false))), "rocks, pebbles and stone paths must align to terrain slopes by default")
	_assert(AssetCatalogScript.migrate_asset_path("res://assets/environment/stylized_nature/Clover_1.gltf") == "res://assets/environment/stylized_nature/ground_cover/Clover_1.gltf", "legacy nature paths must migrate to categorized folders")
	var legacy_collision_data := WorldDocumentScript.create_default()
	legacy_collision_data["version"] = 4
	var legacy_pebble := WorldDocumentScript.entity("prop", "Ancien galet", Vector3.ZERO, {"asset_path": "res://assets/environment/stylized_nature/rocks/Pebble_Round_1.gltf", "collision_enabled": false})
	var legacy_path := WorldDocumentScript.entity("prop", "Ancienne route", Vector3.ZERO, {"asset_path": "res://assets/environment/stylized_nature/stone_paths/RockPath_Round_Wide.gltf", "collision_enabled": true})
	(legacy_collision_data["entities"] as Array).append_array([legacy_pebble, legacy_path])
	var migrated_collision_document := WorldDocumentScript.new(legacy_collision_data)
	_assert(bool((migrated_collision_document.find_by_name("Ancien galet").get("properties", {}) as Dictionary).get("collision_enabled", false)), "version 4 documents must restore colliders on already placed pebbles")
	_assert(not bool((migrated_collision_document.find_by_name("Ancienne route").get("properties", {}) as Dictionary).get("collision_enabled", true)), "version 4 documents must remove colliders from already placed stone paths")
	var document := WorldDocumentScript.new(WorldDocumentScript.example_world())
	_assert(document.validation_report().valid, "example world must validate")
	_assert(document.theoretical_mob_count() == 8, "example must expose eight theoretical enemies")
	var encoded := document.to_json()
	var decoded := WorldDocumentScript.from_json(encoded)
	_assert(decoded != null, "JSON round-trip must load")
	_assert(decoded.entities().size() == document.entities().size(), "round-trip must preserve entities")
	var heavy_group := WorldDocumentScript.entity("enemy_group", "Stress group", Vector3.ZERO, {
		"group_id": "stress", "count": 300, "archetype": "nathenian1", "active_on_start": false,
		"match_perfect_hitbox": true, "giant_traversal_mode": "invalid",
		"giant_capsule_radius_multiplier": 9.0, "giant_capsule_height_multiplier": 0.1,
		"giant_walkable_tops": false
	})
	decoded.add_entity(heavy_group)
	decoded = WorldDocumentScript.from_json(decoded.to_json())
	_assert(decoded != null, "document with traversal settings must survive normalization round-trip")
	var normalized_heavy := decoded.find_by_name("Stress group")
	var normalized_properties := normalized_heavy.get("properties", {}) as Dictionary
	_assert(bool(normalized_properties.get("match_perfect_hitbox", false)), "Forge perfect-hitbox option must survive document normalization")
	_assert(String(normalized_properties.get("giant_traversal_mode", "")) == "assisted", "invalid giant traversal mode must normalize to assisted")
	_assert(is_equal_approx(float(normalized_properties.get("giant_capsule_radius_multiplier", 0.0)), 1.35), "giant capsule width must be clamped")
	_assert(is_equal_approx(float(normalized_properties.get("giant_capsule_height_multiplier", 0.0)), 0.80), "giant capsule height must be clamped")
	_assert(not bool(normalized_properties.get("giant_walkable_tops", true)), "giant walkable-top option must survive normalization")
	_assert(EnemyArchetypesScript.giant_ids().size() == 5, "Forge must expose three giant tiers and two dinosaurs")
	for giant_id: StringName in EnemyArchetypesScript.giant_ids():
		var profile := EnemyArchetypesScript.profile(giant_id)
		_assert(is_equal_approx(float(profile.get("scale", 0.0)), 1.0), "%s must default to standard size" % giant_id)
		var expected_climbable := giant_id != &"velociraptor"
		_assert(bool(profile.get("forge_default_match_perfect_hitbox", false)) == expected_climbable, "%s must expose its intended climbable default" % giant_id)
		var expected_traversal_mode: StringName = &"exact" if EnemyArchetypesScript.is_dinosaur(giant_id) else &"assisted"
		_assert(StringName(profile.get("giant_traversal_mode", &"")) == expected_traversal_mode, "%s must expose its intended traversal mode" % giant_id)
		decoded.add_entity(WorldDocumentScript.entity("enemy_group", "Forge %s" % giant_id, Vector3.ZERO, {
			"group_id": String(giant_id), "count": 1, "archetype": String(giant_id),
			"rank": "normal", "size_multiplier": 1.0, "match_perfect_hitbox": true,
			"giant_traversal_mode": "assisted", "giant_capsule_radius_multiplier": 0.85,
			"giant_capsule_height_multiplier": 1.10, "giant_walkable_tops": true
		}))
		var normalized_giant := decoded.find_by_name("Forge %s" % giant_id)
		var giant_properties := normalized_giant.get("properties", {}) as Dictionary
		_assert(String(giant_properties.get("archetype", "")) == String(giant_id), "%s Forge archetype must survive serialization" % giant_id)
		_assert(bool(giant_properties.get("match_perfect_hitbox", false)), "%s Forge climbable flag must survive serialization" % giant_id)
		_assert(String(giant_properties.get("giant_traversal_mode", "")) == "assisted", "%s traversal mode must survive serialization" % giant_id)
		_assert(is_equal_approx(float(giant_properties.get("giant_capsule_radius_multiplier", 0.0)), 0.85), "%s capsule width must survive serialization" % giant_id)
		_assert(is_equal_approx(float(giant_properties.get("giant_capsule_height_multiplier", 0.0)), 1.10), "%s capsule height must survive serialization" % giant_id)
		_assert(bool(giant_properties.get("giant_walkable_tops", false)), "%s walkable tops must survive serialization" % giant_id)
	var report := decoded.validation_report()
	_assert(report.mob_count == 313, "population accounting must include deferred, giant and dinosaur spawn groups")
	_assert(not report.warnings.is_empty(), "population guard must warn at configured threshold")
	print("WORLD_EDITOR_PROBE_OK entities=%d mobs=%d warnings=%d" % [decoded.entities().size(), report.mob_count, report.warnings.size()])
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("WORLD_EDITOR_PROBE_FAILED: " + message)
	quit(1)
