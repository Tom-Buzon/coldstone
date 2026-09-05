extends RefCounted
## Editor-only footprint. No runtime physics or enemy queries.
static func add_champion_perimeter(holder: Node3D, radius: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "ChampionAlertPerimeter"
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(1.0,radius-0.10)
	mesh.outer_radius = radius+0.10
	mesh.rings = 64
	mesh.ring_segments = 6
	ring.mesh = mesh
	ring.position.y = 0.10
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0,0.36,0.08,0.65)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ring)
