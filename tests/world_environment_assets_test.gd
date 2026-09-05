extends SceneTree

const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")
const WorldTerrainScript = preload("res://scripts/world_editor/world_terrain.gd")
const MaterialCatalogScript = preload("res://scripts/environment/material_catalog.gd")
const MaterialLibraryScript = preload("res://scripts/environment/procedural_material_library.gd")

func _initialize() -> void:
	var terrain_properties := WorldTerrainScript.default_properties("flat", 17, 417)
	terrain_properties["width"] = 16.0
	terrain_properties["depth"] = 16.0
	terrain_properties["foliage_amount"] = 1.0
	WorldTerrainScript.paint_foliage(terrain_properties, Vector3.ZERO, 10.0, 1.0, false, "flowers")
	var source := WorldDocumentScript.create_default()
	(source["atmosphere"] as Dictionary)["sky_id"] = "cloud_layers"
	(source["entities"] as Array).append(WorldDocumentScript.entity("terrain", "Terrain probe", Vector3.ZERO, terrain_properties))
	(source["entities"] as Array).append(WorldDocumentScript.entity("surface", "PBR probe", Vector3(0.0, 0.2, 0.0), {"shape": "floor", "size": [4.0, 0.4, 4.0], "material": "poly_stone_floor"}))
	(source["entities"] as Array).append(WorldDocumentScript.entity("water", "Water probe", Vector3(6.0, 0.5, 0.0), {"size": [8.0, 0.08, 6.0], "texture": "poly_dirt", "texture_strength": 0.12, "wave_height": 0.05}))
	(source["entities"] as Array).append(WorldDocumentScript.entity("fire", "Fire probe", Vector3(-4.0, 0.1, 0.0), {"amount": 32, "size": 1.2, "light_enabled": true}))
	var document := WorldDocumentScript.new(source)
	_assert(document.data.get("version") == WorldDocumentScript.CURRENT_VERSION, "document migration")
	_assert(MaterialCatalogScript.all_ids().size() >= 20, "categorized material count")
	var material := MaterialLibraryScript.material(&"poly_stone_floor") as ShaderMaterial
	_assert(material != null, "PBR material")
	_assert(material.get_shader_parameter("use_normal_texture") == true, "PBR normal map")
	_assert(material.get_shader_parameter("use_roughness_texture") == true, "PBR roughness map")
	var runtime := WorldRuntimeScript.new()
	root.add_child(runtime)
	runtime.build(document, true, Vector3.ZERO, INF, document.start_chapter())
	_assert(runtime.world_environment != null and runtime.world_environment.environment != null, "world environment")
	_assert(runtime.world_environment.environment.sky != null, "sky")
	var water := _entity_node(runtime, document, "water")
	var fire := _entity_node(runtime, document, "fire")
	_assert(water != null and water.find_child("WaterSurface", true, false) is MeshInstance3D, "water mesh")
	var water_mesh := water.find_child("WaterSurface", true, false) as MeshInstance3D
	var water_material := water_mesh.mesh.surface_get_material(0) as ShaderMaterial
	_assert(water_material.get_shader_parameter("use_surface_texture") == true, "water texture")
	_assert(fire != null and fire.find_child("OptimizedFire", true, false) is GPUParticles3D, "fire particles")
	var particles := fire.find_child("OptimizedFire", true, false) as GPUParticles3D
	_assert(particles.amount == 32 and particles.fixed_fps == 30, "fire budget")
	var terrain := _entity_node(runtime, document, "terrain")
	var foliage := terrain.get_node_or_null("TerrainFoliage") if terrain != null else null
	_assert(foliage != null and int(foliage.get_meta("foliage_instance_count", 0)) > 0, "foliage generated")
	for child: Node in foliage.get_children():
		_assert(child is MultiMeshInstance3D, "foliage is MultiMesh")
	print("WORLD_ENVIRONMENT_ASSETS_OK")
	quit(0)

func _entity_node(runtime: Node, document: RefCounted, entity_type: String) -> Node3D:
	for raw: Variant in document.call("entities"):
		var entity := raw as Dictionary
		if String(entity.get("type", "")) == entity_type:
			return runtime.get("nodes_by_id").get(String(entity.get("id", ""))) as Node3D
	return null

func _assert(condition: bool, label: String) -> void:
	if condition:
		return
	push_error("WORLD ENVIRONMENT ASSETS TEST FAILED: %s" % label)
	quit(1)
