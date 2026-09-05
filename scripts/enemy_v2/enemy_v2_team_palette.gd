extends RefCounted
static var materials: Dictionary = {}
static func apply(root: Node, faction: StringName) -> void:
	if faction != &"spartan": return
	for node: Node in root.find_children("*","MeshInstance3D",true,false):
		var visual := node as MeshInstance3D
		if visual.mesh == null: continue
		for surface in range(visual.mesh.get_surface_count()):
			var source := visual.get_active_material(surface)
			if not source is StandardMaterial3D: continue
			var key := source.get_instance_id()
			if not materials.has(key):
				var material := source.duplicate() as StandardMaterial3D
				material.albedo_color = Color(0.3,0.55,1.0,1.0)
				materials[key] = material
			visual.set_surface_override_material(surface,materials[key])
