extends RefCounted
class_name HopliteWorldTerrainFoliage

const WorldTerrainScript = preload("res://scripts/world_editor/world_terrain.gd")
const ASSET_ROOT := "res://assets/environment/stylized_nature"
const MAX_INSTANCES := 6000
const VARIANTS := [
	{"preset": "mediterranean_grass", "name": "GrassShort", "path": ASSET_ROOT + "/ground_cover/Grass_Common_Short.gltf", "scale": Vector2(0.62, 0.92)},
	{"preset": "wild_grass", "name": "GrassTall", "path": ASSET_ROOT + "/ground_cover/Grass_Wispy_Tall.gltf", "scale": Vector2(0.55, 0.86)},
	{"preset": "clover", "name": "Clover", "path": ASSET_ROOT + "/ground_cover/Clover_1.gltf", "scale": Vector2(0.48, 0.76)},
	{"preset": "flowers", "name": "Flowers", "path": ASSET_ROOT + "/ground_cover/Flower_3_Group.gltf", "scale": Vector2(0.28, 0.46)},
	# Fern_1 is authored as a broad 9 m cluster; reduce it to a ground accent.
	{"preset": "ferns", "name": "Ferns", "path": ASSET_ROOT + "/ground_cover/Fern_1.gltf", "scale": Vector2(0.08, 0.13)},
	{"preset": "shrubs", "name": "Shrubs", "path": ASSET_ROOT + "/shrubs/Bush_Common.gltf", "scale": Vector2(0.38, 0.62)},
	{"preset": "mushrooms", "name": "Mushrooms", "path": ASSET_ROOT + "/ground_cover/Mushroom_Common.gltf", "scale": Vector2(0.65, 1.15)},
]

static var mesh_cache: Dictionary = {}

static func rebuild(body: StaticBody3D, properties: Dictionary, editing: bool = false) -> void:
	WorldTerrainScript.normalize(properties)
	var foliage_root := body.get_node_or_null("TerrainFoliage") as Node3D
	if foliage_root == null:
		foliage_root = Node3D.new()
		foliage_root.name = "TerrainFoliage"
		body.add_child(foliage_root)
	for child in foliage_root.get_children():
		foliage_root.remove_child(child)
		child.queue_free()
	var preset := String(properties.get("foliage_preset", "mediterranean_grass"))
	var amount := float(properties.get("foliage_amount", 0.65))
	if preset == "none" or amount <= 0.001:
		return
	var width := float(properties["width"])
	var depth := float(properties["depth"])
	var candidate_count := mini(MAX_INSTANCES, roundi(width * depth * amount * (0.48 if editing else 0.72)))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(properties.get("foliage_seed", 9256))
	var transforms_by_variant: Array[Array] = []
	for _index in range(VARIANTS.size()):
		transforms_by_variant.append([])
	for _candidate in range(candidate_count):
		var local_x := rng.randf_range(-width * 0.5, width * 0.5)
		var local_z := rng.randf_range(-depth * 0.5, depth * 0.5)
		var density := WorldTerrainScript.foliage_at_normalized(properties, local_x, local_z)
		if rng.randf() > density:
			continue
		var local_preset := WorldTerrainScript.foliage_preset_at_normalized(properties, local_x, local_z)
		var variant_index := _variant_for_preset(local_preset)
		var definition := VARIANTS[variant_index] as Dictionary
		var scale_range := definition["scale"] as Vector2
		var uniform_scale := rng.randf_range(scale_range.x, scale_range.y)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * uniform_scale)
		var local_y := WorldTerrainScript.height_at_normalized(properties, local_x, local_z)
		(transforms_by_variant[variant_index] as Array).append(Transform3D(basis, Vector3(local_x, local_y, local_z)))
	var bounds := WorldTerrainScript.local_bounds(properties).grow(2.0)
	var spawned_count := 0
	for variant_index in range(VARIANTS.size()):
		var transforms := transforms_by_variant[variant_index] as Array
		if transforms.is_empty():
			continue
		var definition := VARIANTS[variant_index] as Dictionary
		var mesh := _mesh_from_scene(String(definition["path"]))
		if mesh == null:
			continue
		var multi_mesh := MultiMesh.new()
		multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		multi_mesh.mesh = mesh
		multi_mesh.instance_count = transforms.size()
		for instance_index in range(transforms.size()):
			multi_mesh.set_instance_transform(instance_index, transforms[instance_index] as Transform3D)
		var instance := MultiMeshInstance3D.new()
		instance.name = String(definition["name"])
		instance.multimesh = multi_mesh
		instance.custom_aabb = bounds
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = 110.0 if editing else 140.0
		instance.set_meta("foliage_preset", String(definition["preset"]))
		instance.set_meta("foliage_instance_count", transforms.size())
		foliage_root.add_child(instance)
		spawned_count += transforms.size()
	foliage_root.set_meta("multimesh_draw_count", foliage_root.get_child_count())
	foliage_root.set_meta("foliage_instance_count", spawned_count)

static func _variant_for_preset(preset: String) -> int:
	for index in range(VARIANTS.size()):
		if String((VARIANTS[index] as Dictionary)["preset"]) == preset:
			return index
	return 0

static func _mesh_from_scene(path: String) -> Mesh:
	if mesh_cache.has(path):
		return mesh_cache[path] as Mesh
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("[TERRAIN FOLIAGE] Asset introuvable : %s" % path)
		return null
	var root := packed.instantiate()
	var mesh := _find_mesh(root)
	root.free()
	if mesh != null:
		mesh_cache[path] = mesh
	return mesh

static func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var mesh := _find_mesh(child)
		if mesh != null:
			return mesh
	return null
