extends SceneTree

const WorldDocumentScript = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntimeScript = preload("res://scripts/world_editor/world_runtime.gd")
const WorldTerrainScript = preload("res://scripts/world_editor/world_terrain.gd")

func _init() -> void:
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
		var mesh_colors := mesh_arrays[Mesh.ARRAY_COLOR] as PackedColorArray
		var resolution := int(first.get("resolution", 0))
		_assert(mesh_indices.size() >= 6, "terrain mesh must contain indexed triangles")
		_assert(mesh_colors.size() == resolution * resolution, "terrain mesh must carry per-vertex material weights")
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
	_assert(WorldTerrainScript.paint_foliage(first, Vector3.ZERO, 12.0, 4.0, false, "flowers"), "foliage brush must paint localized density")
	_assert((first.get("foliage_density", []) as Array).any(func(value: Variant) -> bool: return float(value) > 0.0), "foliage density must be serialized")
	_assert(WorldTerrainScript.foliage_preset_at_normalized(first, 0.0, 0.0) == "flowers", "foliage brush must preserve the local vegetation type")
	WorldTerrainScript.resize_resolution(first, 65)
	_assert((first.get("heights", []) as Array).size() == 65 * 65, "resolution changes must resample heights")
	_assert((first.get("material_weights", []) as Array).size() == 65 * 65 * 3, "resolution changes must resample material weights")
	_assert((first.get("foliage_density", []) as Array).size() == 65 * 65, "resolution changes must resample foliage density")
	_assert((first.get("foliage_types", []) as Array).size() == 65 * 65, "resolution changes must resample local foliage types")

	var document := WorldDocumentScript.new()
	var terrain_entity := WorldDocumentScript.entity("terrain", "Probe terrain", Vector3(4.0, 1.0, -3.0), first)
	terrain_entity["chapter"] = document.start_chapter()
	var terrain_id := document.add_entity(terrain_entity)
	var nature_prop := WorldDocumentScript.entity("prop", "Fleur persistante", Vector3(0.0, 0.0, 0.0), {"asset_path": "res://assets/environment/stylized_nature/ground_cover/Flower_3_Group.gltf", "asset_label": "Fleur", "target_height": 0.7})
	nature_prop["chapter"] = document.start_chapter()
	var nature_prop_id := document.add_entity(nature_prop)
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
	var nature_prop_node := runtime.nodes_by_id.get(nature_prop_id) as Node3D
	_assert(nature_prop_node != null and not nature_prop_node.find_children("*", "MeshInstance3D", true, false).is_empty(), "placed vegetation props must remain visible after a Forge preview rebuild")
	var foliage_root := runtime_body.get_node_or_null("TerrainFoliage") as Node3D
	_assert(foliage_root != null and foliage_root.get_child_count() > 0, "runtime terrain must build painted foliage MultiMeshes")
	_assert(int(foliage_root.get_meta("multimesh_draw_count", 0)) == 1, "one locally painted vegetation type must use exactly one MultiMesh draw")
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
