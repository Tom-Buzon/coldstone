extends SceneTree

const AssetLibraryRoomScript = preload("res://scripts/environment/asset_library_room.gd")
const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")

const EXPECTED_ASSET_COUNT: int = 112
const EXPECTED_SUBCATEGORY_COUNT: int = 15
const COSY_GREEK_EXPECTATIONS := {
	"column_doric_weathered_LOD0.glb": {"collision": true, "shape": "cylinder"},
	"column_ionic_aegean_LOD0.glb": {"collision": true, "shape": "cylinder"},
	"column_corinthian_garden_LOD0.glb": {"collision": true, "shape": "cylinder"},
	"decor_amphora_cluster_LOD0.glb": {"collision": false, "shape": "cylinder"},
	"decor_olive_planter_LOD0.glb": {"collision": false, "shape": "cylinder"},
	"decor_courtyard_bench_LOD0.glb": {"collision": true, "shape": "box"},
	"decor_tripod_brazier_LOD0.glb": {"collision": true, "shape": "cylinder"},
	"decor_mosaic_roundel_LOD0.glb": {"collision": false, "shape": "box"},
	"decor_courtyard_fountain_LOD0.glb": {"collision": true, "shape": "cylinder"},
}
const PORTAL_EXPECTATIONS := {
	"portal_world_forge_LOD0.glb": {"collision": false, "shape": "box"},
	"portal_saved_world_LOD0.glb": {"collision": false, "shape": "box"},
	"portal_official_campaign_LOD0.glb": {"collision": false, "shape": "box"},
}
const BATTLEFIELD_EXPECTATIONS := {
	"battle_banner_crimson_lambda_LOD0.glb": {"collision": false, "shape": "cylinder"},
	"battle_banner_aegean_owl_LOD0.glb": {"collision": false, "shape": "cylinder"},
	"battle_standard_bronze_sun_LOD0.glb": {"collision": false, "shape": "cylinder"},
	"battle_spiked_field_barricade_LOD0.glb": {"collision": true, "shape": "box"},
	"battle_spear_shield_rack_LOD0.glb": {"collision": true, "shape": "box"},
	"battle_signal_brazier_LOD0.glb": {"collision": true, "shape": "cylinder"},
	"battle_weapon_debris_LOD0.glb": {"collision": false, "shape": "box"},
	"battle_fallen_hoplite_memorial_LOD0.glb": {"collision": true, "shape": "cylinder"},
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scanner := AssetLibraryRoomScript.new()
	var catalog: Array[Dictionary] = scanner.call("_scan_catalog") as Array[Dictionary]
	scanner.free()

	var blender_entries: Array[Dictionary] = []
	for entry: Dictionary in catalog:
		if StringName(entry.get("category", &"")) == &"blender":
			blender_entries.append(entry)

	_expect(
		blender_entries.size() == EXPECTED_ASSET_COUNT,
		"Forge must expose exactly %d Blender assets" % EXPECTED_ASSET_COUNT
	)
	var subcategories: Dictionary = {}
	var unique_paths: Dictionary = {}
	var cosy_greek_found: Dictionary = {}
	var portals_found: Dictionary = {}
	var battlefield_found: Dictionary = {}
	var bridge_entry: Dictionary = {}
	for entry: Dictionary in blender_entries:
		var path := String(entry.get("path", ""))
		var preview_path := String(entry.get("preview_path", ""))
		var subcategory := StringName(entry.get("subcategory", &""))
		subcategories[subcategory] = true
		unique_paths[path] = true
		_expect(path.ends_with("_LOD0.glb"), "Forge Blender entry is not a LOD0: %s" % path)
		_expect(FileAccess.file_exists(path), "Forge Blender model is missing: %s" % path)
		_expect(not preview_path.is_empty() and FileAccess.file_exists(preview_path), "Forge Blender preview is missing: %s" % path)
		_expect(float(entry.get("target_height", 0.0)) > 0.0, "Forge Blender authored height is invalid: %s" % path)
		var filename := path.get_file()
		if COSY_GREEK_EXPECTATIONS.has(filename):
			cosy_greek_found[filename] = true
			var expectation := COSY_GREEK_EXPECTATIONS[filename] as Dictionary
			_expect(bool(entry.get("collision_enabled", true)) == bool(expectation["collision"]), "Forge cosy Greek collision policy is invalid: %s" % path)
			_expect(String(entry.get("collision_shape", "")) == String(expectation["shape"]), "Forge cosy Greek collision shape is invalid: %s" % path)
		if PORTAL_EXPECTATIONS.has(filename):
			portals_found[filename] = true
			var expectation := PORTAL_EXPECTATIONS[filename] as Dictionary
			_expect(bool(entry.get("collision_enabled", true)) == bool(expectation["collision"]), "Forge portal collision policy is invalid: %s" % path)
			_expect(String(entry.get("collision_shape", "")) == String(expectation["shape"]), "Forge portal collision shape is invalid: %s" % path)
		if BATTLEFIELD_EXPECTATIONS.has(filename):
			battlefield_found[filename] = true
			var expectation := BATTLEFIELD_EXPECTATIONS[filename] as Dictionary
			_expect(bool(entry.get("collision_enabled", true)) == bool(expectation["collision"]), "Forge battlefield collision policy is invalid: %s" % path)
			_expect(String(entry.get("collision_shape", "")) == String(expectation["shape"]), "Forge battlefield collision shape is invalid: %s" % path)
		if path.ends_with("/bridge_stone_6x4m_LOD0.glb"):
			bridge_entry = entry

	_expect(unique_paths.size() == EXPECTED_ASSET_COUNT, "Forge Blender paths must be unique")
	_expect(subcategories.size() == EXPECTED_SUBCATEGORY_COUNT, "Forge must expose %d Blender subfolders" % EXPECTED_SUBCATEGORY_COUNT)
	_expect(cosy_greek_found.size() == COSY_GREEK_EXPECTATIONS.size(), "Forge must expose every cosy Greek asset")
	_expect(portals_found.size() == PORTAL_EXPECTATIONS.size(), "Forge must expose every authored portal asset")
	_expect(battlefield_found.size() == BATTLEFIELD_EXPECTATIONS.size(), "Forge must expose every battlefield dressing asset")
	for expected_subcategory: StringName in AssetLibraryRoomScript.BLENDER_SUBCATEGORY_ORDER:
		_expect(subcategories.has(expected_subcategory), "Forge Blender subfolder is missing: %s" % expected_subcategory)
	_probe_runtime_placement(bridge_entry)

	if failures.is_empty():
		print("[BLENDER FORGE CATALOG PROBE] PASS assets=%d folders=%d previews=%d" % [blender_entries.size(), subcategories.size(), blender_entries.size()])
		quit(0)
		return

	for failure: String in failures:
		printerr("[BLENDER FORGE CATALOG PROBE] %s" % failure)
	quit(1)


func _probe_runtime_placement(entry: Dictionary) -> void:
	_expect(not entry.is_empty(), "Bridge placement fixture is absent from the Blender catalog")
	if entry.is_empty():
		return
	var document := WorldDocumentScript.new(WorldDocumentScript.create_default())
	var entity := WorldDocumentScript.entity("prop", "Forge Blender bridge", Vector3.ZERO, {
		"asset_path": String(entry.get("path", "")),
		"asset_label": String(entry.get("display_name", "Bridge")),
		"target_height": float(entry.get("target_height", 2.0)),
		"collision_enabled": false,
	})
	var entity_id := document.add_entity(entity)
	var runtime := WorldRuntimeScript.new()
	root.add_child(runtime)
	runtime.build(document, true)
	var placed := runtime.nodes_by_id.get(entity_id) as Node3D
	_expect(placed != null, "Forge could not build a Blender prop")
	if placed != null:
		_expect(not placed.find_children("*", "MeshInstance3D", true, false).is_empty(), "Placed Blender prop contains no visible mesh")
		var bounds := placed.get_meta("editor_local_bounds", AABB()) as AABB
		_expect(bounds.size.length_squared() > 0.0, "Placed Blender prop has no usable bounds")
	runtime.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
