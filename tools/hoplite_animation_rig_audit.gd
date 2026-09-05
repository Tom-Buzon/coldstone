extends SceneTree

const SOURCES: Dictionary = {
	&"canonical": "res://assets/characters/3dgen_demo/ngeneral-1787351044165.glb",
	&"ual1": "res://assets/runtime/ual1/UAL1_Standard.glb",
	&"ual2": "res://assets/runtime/ual2/UAL2_Standard.glb",
	&"spear_thrust": "res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield attack (3).fbx",
}


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var failures: int = 0
	for raw_key: Variant in SOURCES:
		var key := StringName(raw_key)
		var path := String(SOURCES[key])
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("[HOPLITE RIG AUDIT] missing %s: %s" % [key, path])
			failures += 1
			continue
		var root := packed.instantiate()
		get_root().add_child(root)
		var skeleton := _find_skeleton(root)
		var player := _find_animation_player(root)
		if skeleton == null or (key != &"canonical" and player == null):
			push_error("[HOPLITE RIG AUDIT] incomplete source: %s" % key)
			failures += 1
			root.free()
			continue
		print("[HOPLITE RIG] key=", key, " bones=", skeleton.get_bone_count(), " skeleton_path=", root.get_path_to(skeleton), " player_path=", root.get_path_to(player) if player != null else NodePath(), " player_root=", player.root_node if player != null else NodePath())
		var bone_names: PackedStringArray = []
		for bone_index: int in range(skeleton.get_bone_count()):
			bone_names.append(skeleton.get_bone_name(bone_index))
		print("[HOPLITE BONES] key=", key, " names=", ",".join(bone_names))
		if key == &"canonical":
			_print_mesh_inventory(root)
		var clips: PackedStringArray = player.get_animation_list() if player != null else PackedStringArray()
		if not clips.is_empty():
			var clip: StringName = clips[0]
			for candidate: StringName in clips:
				if candidate != &"RESET":
					clip = candidate
					break
			var animation := player.get_animation(clip)
			print("[HOPLITE CLIP] key=", key, " clip=", clip, " tracks=", animation.get_track_count())
			for track_index: int in range(mini(animation.get_track_count(), 4)):
				print("[HOPLITE TRACK] key=", key, " index=", track_index, " type=", animation.track_get_type(track_index), " path=", animation.track_get_path(track_index), " keys=", animation.track_get_key_count(track_index))
		root.free()
	quit(1 if failures > 0 else 0)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _print_mesh_inventory(root: Node) -> void:
	for candidate: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var mesh := mesh_instance.mesh
		var surfaces := mesh.get_surface_count() if mesh != null else 0
		var vertices := 0
		var material_ids: PackedInt64Array = []
		for surface_index: int in range(surfaces):
			var arrays := mesh.surface_get_arrays(surface_index)
			var vertex_array: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays.size() > Mesh.ARRAY_VERTEX else PackedVector3Array()
			vertices += vertex_array.size()
			var material := mesh.surface_get_material(surface_index)
			material_ids.append(material.get_instance_id() if material != null else 0)
			if mesh_instance.name == &"SPARTAN_body_torso" and material is StandardMaterial3D:
				var standard := material as StandardMaterial3D
				print("[HOPLITE MATERIAL] albedo_color=", standard.albedo_color, " albedo_texture=", standard.albedo_texture.resource_path if standard.albedo_texture != null else "", " metallic=", standard.metallic, " roughness=", standard.roughness, " normal_enabled=", standard.normal_enabled, " normal_texture=", standard.normal_texture.resource_path if standard.normal_texture != null else "", " cull_mode=", standard.cull_mode, " transparency=", standard.transparency)
		print("[HOPLITE MESH] name=", mesh_instance.name, " parent=", root.get_path_to(mesh_instance.get_parent()), " skeleton=", mesh_instance.skeleton, " skin=", mesh_instance.skin.get_instance_id() if mesh_instance.skin != null else 0, " surfaces=", surfaces, " vertices=", vertices, " materials=", material_ids, " visible=", mesh_instance.visible)
