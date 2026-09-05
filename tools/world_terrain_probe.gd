extends SceneTree

const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")
const WorldTerrainScript = preload("res://scripts/world_editor/world_terrain.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var first := WorldTerrainScript.default_properties("rolling", 33, 4242)
	first["width"] = 96.0
	first["depth"] = 48.0
	WorldTerrainScript.regenerate(first)
	var second := WorldTerrainScript.default_properties("rolling", 33, 4242)
	second["width"] = 96.0
	second["depth"] = 48.0
	WorldTerrainScript.regenerate(second)
	var different := WorldTerrainScript.default_properties("rolling", 33, 4243)
	_assert((first.get("heights", []) as Array).size() == 33 * 33, "terrain height count must match resolution")
	_assert(first.get("heights", []) == second.get("heights", []), "same seed and settings must reproduce the same terrain")
	_assert(first.get("heights", []) != different.get("heights", []), "different seeds must change generated relief")

	var body := StaticBody3D.new()
	WorldTerrainScript.rebuild_body(body, first, StandardMaterial3D.new())
	var mesh_instance := body.get_node_or_null("TerrainMesh") as MeshInstance3D
	var collision := body.get_node_or_null("TerrainCollision") as CollisionShape3D
	_assert(mesh_instance != null and mesh_instance.mesh is ArrayMesh, "terrain must build an ArrayMesh")
	if mesh_instance != null and mesh_instance.mesh is ArrayMesh:
		var mesh_arrays := (mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
		var mesh_indices := mesh_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var mesh_splat_uvs := mesh_arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array
		var resolution := int(first.get("resolution", 0))
		_assert(mesh_indices.size() >= 6, "terrain mesh must contain indexed triangles")
		_assert(mesh_splat_uvs.size() == resolution * resolution, "terrain mesh must carry normalized splat-map coordinates")
		if mesh_indices.size() >= 6:
			var expected_first_quad := PackedInt32Array([0, 1, resolution, 1, resolution + 1, resolution])
			_assert(
				mesh_indices.slice(0, 6) == expected_first_quad,
				"terrain top faces must use Godot's clockwise front-face winding"
			)
	_assert(collision != null and collision.shape is HeightMapShape3D, "terrain must build HeightMapShape3D collision")
	var height_shape := collision.shape as HeightMapShape3D
	_assert(height_shape.map_width == 33 and height_shape.map_depth == 33, "collision resolution must match visual mesh")
	_assert(height_shape.map_data.size() == 33 * 33, "collision must use every serialized height")
	_assert(is_equal_approx(collision.scale.x, 3.0) and is_equal_approx(collision.scale.z, 1.5), "collision scale must follow independent terrain dimensions")

	var center_index := 16 * 33 + 16
	var before_raise := float((first.get("heights", []) as Array)[center_index])
	_assert(WorldTerrainScript.sculpt(first, Vector3.ZERO, "raise", 4.0, 1.0), "raise brush must modify terrain")
	var after_raise := float((first.get("heights", []) as Array)[center_index])
	_assert(after_raise > before_raise, "raise brush must increase center height")
	_assert(WorldTerrainScript.sculpt(first, Vector3(0.0, after_raise, 0.0), "flatten", 3.0, 4.0, 2.0), "flatten brush must modify terrain")
	var flattened := float((first.get("heights", []) as Array)[center_index])
	_assert(absf(flattened - 2.0) < absf(after_raise - 2.0), "flatten brush must approach sampled target height")
	WorldTerrainScript.smooth_all(first, 2)
	_assert((first.get("heights", []) as Array).size() == 33 * 33, "global smoothing must preserve topology")
	_assert(WorldTerrainScript.paint_material(first, Vector3.ZERO, "mediterranean_grass", 8.0, 2.0), "material brush must paint a localized layer")
	_assert((first.get("material_weights", []) as Array).any(func(value: Variant) -> bool: return float(value) > 0.0), "material brush must store blend weights")
	var base_material_before_overlay := String(first.get("material", ""))
	_assert(WorldTerrainScript.paint_material(first, Vector3.ZERO, "rough_stone", 8.0, 1.0), "a second texture must be paintable over an already textured terrain")
	var painted_layers := first.get("paint_layers", []) as Array
	var material_palette := first.get("material_palette", []) as Array
	var painted_weights := first.get("material_weights", []) as Array
	var grass_slot := material_palette.find("mediterranean_grass")
	var stone_slot := material_palette.find("rough_stone")
	_assert(painted_layers.size() == 3 and grass_slot >= 0 and stone_slot >= 0 and float(painted_weights[center_index * material_palette.size() + grass_slot]) > 0.0 and float(painted_weights[center_index * material_palette.size() + stone_slot]) > 0.0, "overlapping texture strokes must preserve both local blend layers")
	_assert(String(first.get("material", "")) == base_material_before_overlay, "local texture painting must not replace the terrain base material")
	var grass_before_stone_erase := float(painted_weights[center_index * material_palette.size() + grass_slot])
	_assert(WorldTerrainScript.paint_material(first, Vector3.ZERO, "rough_stone", 2.0, 1.0, true), "the active material layer must be erasable")
	_assert(is_equal_approx(float((first["material_weights"] as Array)[center_index * material_palette.size() + grass_slot]), grass_before_stone_erase), "erasing stone must preserve the overlapping grass channel")
	var guarded_layers := WorldTerrainScript.default_properties("flat", 17, 1776)
	_assert(WorldTerrainScript.paint_material(guarded_layers, Vector3.ZERO, "mediterranean_grass", 4.0, 2.0), "first guarded material layer must be paintable")
	_assert(WorldTerrainScript.paint_material(guarded_layers, Vector3.ZERO, "rough_stone", 4.0, 2.0), "second guarded material layer must be paintable")
	_assert(WorldTerrainScript.paint_material(guarded_layers, Vector3.ZERO, "sandstone_floor", 4.0, 2.0), "third guarded material layer must be paintable")
	_assert(WorldTerrainScript.can_paint_material(guarded_layers, "fortress") and WorldTerrainScript.paint_material(guarded_layers, Vector3.ZERO, "fortress", 4.0, 2.0), "a fourth local material must remain paintable")
	_assert(WorldTerrainScript.paint_material(guarded_layers, Vector3.ZERO, "poly_mud_leaves", 4.0, 2.0), "a fifth local material must remain paintable without a global layer limit")
	var guarded_palette := guarded_layers.get("material_palette", []) as Array
	var guarded_weights := guarded_layers.get("material_weights", []) as Array
	for guarded_style in ["mediterranean_grass", "rough_stone", "sandstone_floor", "fortress", "poly_mud_leaves"]:
		var guarded_slot := guarded_palette.find(guarded_style)
		_assert(guarded_slot >= 0 and float(guarded_weights[8 * 17 * guarded_palette.size() + 8 * guarded_palette.size() + guarded_slot]) > 0.0, "painting additional materials must preserve %s at the same point" % guarded_style)
	_assert(WorldTerrainScript.paint_foliage(first, Vector3.ZERO, 12.0, 4.0, false, "flowers"), "foliage brush must paint localized density")
	_assert((first.get("foliage_density", []) as Array).any(func(value: Variant) -> bool: return float(value) > 0.0), "foliage density must be serialized")
	_assert(WorldTerrainScript.foliage_preset_at_normalized(first, 0.0, 0.0) == "flowers", "foliage brush must preserve the local vegetation type")
	_assert(WorldTerrainScript.paint_foliage(first, Vector3.ZERO, 10.0, 4.0, false, "mediterranean_grass"), "a second foliage layer must be paintable over the first")
	_assert(WorldTerrainScript.foliage_layer_at_normalized(first, 0.0, 0.0, "flowers") > 0.0, "painting grass must not erase flowers")
	_assert(WorldTerrainScript.foliage_layer_at_normalized(first, 0.0, 0.0, "mediterranean_grass") > 0.0, "grass and flowers must coexist at one point")
	var grass_before_erase := WorldTerrainScript.foliage_layer_at_normalized(first, 0.0, 0.0, "mediterranean_grass")
	_assert(WorldTerrainScript.paint_foliage(first, Vector3.ZERO, 2.0, 4.0, true, "flowers"), "the active foliage layer must be erasable")
	_assert(is_equal_approx(WorldTerrainScript.foliage_layer_at_normalized(first, 0.0, 0.0, "mediterranean_grass"), grass_before_erase), "erasing flowers must preserve overlapping grass")
	_assert(WorldTerrainScript.paint_foliage(first, Vector3.ZERO, 10.0, 4.0, false, "flowers"), "flowers must remain paintable after a localized erase")
	WorldTerrainScript.resize_resolution(first, 65)
	_assert((first.get("heights", []) as Array).size() == 65 * 65, "resolution changes must resample heights")
	_assert((first.get("material_weights", []) as Array).size() == 65 * 65 * (first.get("material_palette", []) as Array).size(), "resolution changes must resample every catalog material weight")
	_assert((first.get("foliage_density", []) as Array).size() == 65 * 65, "resolution changes must resample foliage density")
	_assert((first.get("foliage_types", []) as Array).size() == 65 * 65, "resolution changes must resample local foliage types")
	_assert((first.get("foliage_layers", []) as Array).size() == 65 * 65 * WorldTerrainScript.FOLIAGE_PRESETS.size(), "resolution changes must resample every foliage layer")

	var extension := WorldTerrainScript.default_properties("rolling", 65, 9124)
	WorldTerrainScript.sculpt(extension, Vector3(8.0, 0.0, -6.0), "raise", 5.0, 2.0)
	WorldTerrainScript.paint_foliage(extension, Vector3(8.0, 0.0, -6.0), 5.0, 3.0, false, "clover")
	var preserved_height := WorldTerrainScript.height_at(extension, 8.0, -6.0)
	var old_width := float(extension["width"])
	WorldTerrainScript.resize_dimensions(extension, old_width + 32.0, float(extension["depth"]) + 16.0)
	_assert(is_equal_approx(float(extension["width"]), old_width + 32.0), "terrain width must grow through generated extension")
	_assert(int(extension["resolution"]) > 65, "growing terrain should increase resolution when the limit allows it")
	_assert(absf(WorldTerrainScript.height_at(extension, 8.0, -6.0) - preserved_height) < 0.20, "existing relief must remain at the same physical coordinates after extension")
	_assert(WorldTerrainScript.foliage_layer_at_normalized(extension, 8.0, -6.0, "clover") > 0.0, "painted foliage must stay in place after terrain extension")
	_assert(WorldTerrainScript.contains_local_point(extension, old_width * 0.5 + 8.0, 0.0), "new procedural strip must become part of the terrain")
	var generated_strip_has_relief := false
	for strip_z in [-12.0, 0.0, 12.0]:
		if absf(WorldTerrainScript.height_at(extension, old_width * 0.5 + 12.0, strip_z)) > 0.01:
			generated_strip_has_relief = true
	_assert(generated_strip_has_relief, "new terrain strips must contain generated relief instead of a stretched or empty border")

	var sided_extension := WorldTerrainScript.default_properties("rolling", 65, 5124)
	WorldTerrainScript.sculpt(sided_extension, Vector3(10.0, 0.0, 4.0), "raise", 4.0, 2.0)
	WorldTerrainScript.paint_foliage(sided_extension, Vector3(10.0, 0.0, 4.0), 4.0, 3.0, false, "flowers")
	var sided_height := WorldTerrainScript.height_at(sided_extension, 10.0, 4.0)
	var sided_width := float(sided_extension["width"])
	var added_width := 20.0
	WorldTerrainScript.resize_dimensions(sided_extension, sided_width + added_width, float(sided_extension["depth"]), Vector2(-added_width * 0.5, 0.0))
	_assert(absf(WorldTerrainScript.height_at(sided_extension, 10.0 - added_width * 0.5, 4.0) - sided_height) < 0.20, "one-sided extension must preserve old relief after the terrain entity center moves")
	_assert(WorldTerrainScript.foliage_layer_at_normalized(sided_extension, 10.0 - added_width * 0.5, 4.0, "flowers") > 0.0, "one-sided extension must preserve painted layers in the shifted local frame")

	var legacy := WorldTerrainScript.default_properties("flat", 17, 124)
	legacy.erase("foliage_layers")
	var legacy_density := legacy["foliage_density"] as Array
	var legacy_types := legacy["foliage_types"] as Array
	legacy_density[0] = 0.75
	legacy_types[0] = WorldTerrainScript.FOLIAGE_PRESETS.find("ferns")
	WorldTerrainScript.normalize(legacy)
	_assert(is_equal_approx(float((legacy["foliage_layers"] as Array)[WorldTerrainScript.FOLIAGE_PRESETS.find("ferns")]), 0.75), "legacy foliage maps must migrate into the matching layered channel")

	var document := WorldDocumentScript.new()
	var terrain_entity := WorldDocumentScript.entity("terrain", "Probe terrain", Vector3(4.0, 1.0, -3.0), first)
	terrain_entity["chapter"] = document.start_chapter()
	var terrain_id := document.add_entity(terrain_entity)
	var nature_prop := WorldDocumentScript.entity("prop", "Fleur persistante", Vector3(0.0, 0.0, 0.0), {"asset_path": "res://assets/environment/stylized_nature/ground_cover/Flower_3_Group.gltf", "asset_label": "Fleur", "target_height": 0.7})
	nature_prop["chapter"] = document.start_chapter()
	var nature_prop_id := document.add_entity(nature_prop)
	var convex_rock := WorldDocumentScript.entity("prop", "Rocher convexe", Vector3(3.0, 0.0, 3.0), {"asset_path": "res://assets/environment/stylized_nature/rocks/Rock_Medium_2.gltf", "asset_label": "Rocher", "target_height": 1.15, "collision_enabled": true, "collision_shape": "convex"})
	convex_rock["chapter"] = document.start_chapter()
	var convex_rock_id := document.add_entity(convex_rock)
	var pebble := WorldDocumentScript.entity("prop", "Galet bloquant", Vector3(-3.0, 0.0, 3.0), {"asset_path": "res://assets/environment/stylized_nature/rocks/Pebble_Round_1.gltf", "asset_label": "Galet", "target_height": 1.15})
	pebble["chapter"] = document.start_chapter()
	var pebble_id := document.add_entity(pebble)
	var stone_path := WorldDocumentScript.entity("prop", "Route non bloquante", Vector3(-3.0, 0.0, -3.0), {"asset_path": "res://assets/environment/stylized_nature/stone_paths/RockPath_Round_Wide.gltf", "asset_label": "Route", "target_height": 0.18})
	stone_path["chapter"] = document.start_chapter()
	var stone_path_id := document.add_entity(stone_path)
	var report := document.validation_report()
	_assert(bool(report.get("valid", false)), "document containing normalized terrain must validate")
	var encoded := document.to_json()
	var decoded := WorldDocumentScript.from_json(encoded)
	_assert(decoded != null, "terrain document JSON must load")
	var restored := decoded.find_entity(terrain_id)
	_assert(not restored.is_empty(), "terrain entity must survive JSON round-trip")
	var restored_properties := restored.get("properties", {}) as Dictionary
	_assert((restored_properties.get("heights", []) as Array).size() == 65 * 65, "serialized relief must survive JSON round-trip")

	var runtime := WorldRuntimeScript.new() as HopliteWorldRuntime
	root.add_child(runtime)
	runtime.build(decoded, true)
	var runtime_body := runtime.nodes_by_id.get(terrain_id) as StaticBody3D
	_assert(runtime_body != null, "world runtime must construct the terrain entity")
	var runtime_collision := runtime_body.get_node_or_null("TerrainCollision") as CollisionShape3D
	_assert(runtime_collision != null and runtime_collision.shape is HeightMapShape3D, "runtime terrain must remain collidable")
	var runtime_mesh := runtime_body.get_node_or_null("TerrainMesh") as MeshInstance3D
	var material_before_incremental_paint := runtime_mesh.material_override
	var collision_before_incremental_paint := runtime_collision.shape
	_assert(WorldTerrainScript.paint_material(restored_properties, Vector3(12.0, 0.0, 9.0), "fortress", 3.0, 1.5), "incremental runtime paint must modify a new texture layer")
	WorldTerrainScript.update_body_material(runtime_body, restored_properties)
	_assert(runtime_mesh.material_override == material_before_incremental_paint, "incremental texture paint must reuse the terrain shader material")
	_assert(runtime_collision.shape == collision_before_incremental_paint, "texture paint must not rebuild terrain collision")
	var nature_prop_node := runtime.nodes_by_id.get(nature_prop_id) as Node3D
	_assert(nature_prop_node != null and not nature_prop_node.find_children("*", "MeshInstance3D", true, false).is_empty(), "placed vegetation props must remain visible after a Forge preview rebuild")
	var flower_gameplay_bodies := (nature_prop_node.find_children("*", "StaticBody3D", true, false) as Array).filter(func(node: Node) -> bool: return (node as StaticBody3D).collision_layer == 1)
	var flower_selection_bodies := (nature_prop_node.find_children("*", "StaticBody3D", true, false) as Array).filter(func(node: Node) -> bool: return (node as StaticBody3D).collision_layer == 16)
	_assert(flower_gameplay_bodies.is_empty() and flower_selection_bodies.size() == 1, "ground cover must be non-blocking but remain selectable in the Forge")
	var convex_rock_node := runtime.nodes_by_id.get(convex_rock_id) as Node3D
	var convex_bodies := (convex_rock_node.find_children("*", "StaticBody3D", true, false) as Array).filter(func(node: Node) -> bool: return String((node as StaticBody3D).get_meta("gameplay_collision_shape", "")) == "convex")
	_assert(convex_bodies.size() == 1 and ((convex_bodies[0] as StaticBody3D).get_child(0) as CollisionShape3D).shape is ConvexPolygonShape3D, "convex mode must build a simplified mesh-matching gameplay collider")
	var pebble_node := runtime.nodes_by_id.get(pebble_id) as Node3D
	var pebble_gameplay_bodies := (pebble_node.find_children("*", "StaticBody3D", true, false) as Array).filter(func(node: Node) -> bool: return (node as StaticBody3D).collision_layer == 1)
	_assert(pebble_gameplay_bodies.size() == 1, "pebbles must build one gameplay collider by default")
	var stone_path_node := runtime.nodes_by_id.get(stone_path_id) as Node3D
	var path_gameplay_bodies := (stone_path_node.find_children("*", "StaticBody3D", true, false) as Array).filter(func(node: Node) -> bool: return (node as StaticBody3D).collision_layer == 1)
	var path_selection_bodies := (stone_path_node.find_children("*", "StaticBody3D", true, false) as Array).filter(func(node: Node) -> bool: return (node as StaticBody3D).collision_layer == 16)
	_assert(path_gameplay_bodies.is_empty() and path_selection_bodies.size() == 1, "stone paths must be non-blocking but remain selectable in the Forge")
	var foliage_root := runtime_body.get_node_or_null("TerrainFoliage") as Node3D
	_assert(foliage_root != null and foliage_root.get_child_count() > 0, "runtime terrain must build painted foliage MultiMeshes")
	var rendered_foliage_presets: Dictionary = {}
	for foliage_child: Node in foliage_root.get_children():
		rendered_foliage_presets[String(foliage_child.get_meta("foliage_preset", ""))] = true
	_assert(rendered_foliage_presets.has("mediterranean_grass") and rendered_foliage_presets.has("flowers"), "overlapping grass and flowers must build independent MultiMesh batches")
	_assert(int(foliage_root.get_meta("multimesh_draw_count", 0)) >= int(foliage_root.get_meta("multimesh_batch_count", 0)), "foliage draw metadata must include every MultiMesh surface")
	var foliage_instances := 0
	if foliage_root != null:
		for child in foliage_root.get_children():
			if child is MultiMeshInstance3D and (child as MultiMeshInstance3D).multimesh != null:
				foliage_instances += (child as MultiMeshInstance3D).multimesh.instance_count
	_assert(foliage_instances > 0 and foliage_instances <= 6000, "painted foliage must stay inside the instance budget")
	print("WORLD_TERRAIN_PROBE_OK resolution=65 samples=%d center=%.3f" % [(restored_properties.get("heights", []) as Array).size(), flattened])
	runtime.free()
	body.free()
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("WORLD_TERRAIN_PROBE_FAILED: " + message)
	quit(1)
