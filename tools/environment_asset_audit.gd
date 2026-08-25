extends SceneTree

const RuntimeGLTFCacheScript = preload("res://scripts/environment/runtime_gltf_cache.gd")

const ASSETS: Array[Dictionary] = [
	{"id": "big_rock", "visual": "res://_source/environment_props_raw/bigRock/bigRock_LOD0.glb", "collision": "res://_source/environment_props_raw/bigRock/bigRock_collision.glb"},
	{"id": "brazier", "visual": "res://_source/environment_props_raw/brazier/brazier_LOD0.glb", "collision": "res://_source/environment_props_raw/brazier/brazier_collision.glb"},
	{"id": "crates", "visual": "res://_source/environment_props_raw/caisse/caisses.glb", "collision": "res://_source/environment_props_raw/caisse/caisses_collision.glb"},
	{"id": "catapult", "visual": "res://_source/environment_props_raw/catapulte/catapulte.glb", "collision": "res://_source/environment_props_raw/catapulte/catapulte_collision.glb"},
	{"id": "cypress_tree", "visual": "res://_source/environment_props_raw/cypressTree/cypressTree_LOD0.glb", "collision": "res://_source/environment_props_raw/cypressTree/cypressTree_collision.glb"},
	{"id": "fountain", "visual": "res://_source/environment_props_raw/fontaine1/fontaine1_LOD0.glb", "collision": "res://_source/environment_props_raw/fontaine1/fontaine1_collision.glb"},
	{"id": "jar", "visual": "res://_source/environment_props_raw/jare/jare.glb", "collision": ""},
	{"id": "barricade", "visual": "res://_source/environment_props_raw/obstacle/obstacle.glb", "collision": "res://_source/environment_props_raw/obstacle/obstacle_collision.glb"},
	{"id": "athena_statue", "visual": "res://_source/environment_props_raw/statusAthena/statusAthena_LOD0.glb", "collision": "res://_source/environment_props_raw/statusAthena/statusAthena_collision.glb"},
	{"id": "lion_statue", "visual": "res://_source/environment_props_raw/statusLion/statusLion_LOD0.glb", "collision": "res://_source/environment_props_raw/statusLion/statusLion_collision.glb"},
	{"id": "magistrate_statue", "visual": "res://_source/environment_props_raw/statusMagistrale/statusMagistrale_LOD0.glb", "collision": "res://_source/environment_props_raw/statusMagistrale/statusMagistrale_collision.glb"},
	{"id": "temple", "visual": "res://_source/environment_props_raw/temple1/temple1_LOD0.glb", "collision": "res://_source/environment_props_raw/temple1/temple1_collision.glb"},
	{"id": "tomb", "visual": "res://_source/environment_props_raw/tombe1/tombe1_LOD0.glb", "collision": "res://_source/environment_props_raw/tombe1/tombe1_collision.glb"}
]

func _initialize() -> void:
	var results: Array[Dictionary] = []
	for definition: Dictionary in ASSETS:
		var data := _inspect(String(definition["visual"]))
		data["id"] = definition["id"]
		data["visual"] = definition["visual"]
		var collision_path := String(definition["collision"])
		data["collision"] = _inspect(collision_path) if not collision_path.is_empty() else {}
		results.append(data)
	print(JSON.stringify(results, "  ", false))
	quit(0)

func _inspect(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"available": false}
	var packed := RuntimeGLTFCacheScript.scene(path)
	if packed == null:
		return {"available": false}
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return {"available": false}
	var meshes: Array[MeshInstance3D] = []
	if instance is MeshInstance3D:
		meshes.append(instance as MeshInstance3D)
	for child: Node in instance.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child as MeshInstance3D)
	var initialized := false
	var bounds := AABB()
	var vertices := 0
	var triangles := 0
	var surfaces := 0
	var materials: Array[String] = []
	var mesh_names: Array[String] = []
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null:
			continue
		mesh_names.append(mesh_instance.name)
		var transform := _transform_to_ancestor(mesh_instance, instance)
		var mesh_bounds := mesh_instance.get_aabb()
		for corner: int in range(8):
			var point := transform * mesh_bounds.get_endpoint(corner)
			if not initialized:
				bounds = AABB(point, Vector3.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(point)
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			surfaces += 1
			vertices += mesh_instance.mesh.surface_get_array_len(surface_index)
			var indices: int = mesh_instance.mesh.surface_get_array_index_len(surface_index)
			triangles += indices / 3 if indices > 0 else mesh_instance.mesh.surface_get_array_len(surface_index) / 3
			var material := mesh_instance.mesh.surface_get_material(surface_index)
			if material != null:
				var material_name := material.resource_name if not material.resource_name.is_empty() else material.get_class()
				if not materials.has(material_name):
					materials.append(material_name)
	var result := {
		"available": true,
		"mesh_count": meshes.size(),
		"surface_count": surfaces,
		"vertices": vertices,
		"triangles": triangles,
		"bounds_origin": [bounds.position.x, bounds.position.y, bounds.position.z],
		"bounds_size": [bounds.size.x, bounds.size.y, bounds.size.z],
		"mesh_names": mesh_names,
		"materials": materials
	}
	instance.free()
	return result

func _transform_to_ancestor(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
