extends "res://scripts/enemy_v2/hoplite_v2_presentation_component.gd"

const GiantPackage = preload("res://scripts/enemy/spartan_character_package.gd")
var package: HopliteSpartanCharacterPackage
var size_multiplier: float = 3.0

func install(definition: HopliteEnemyV2Definition) -> bool:
	clear_visual()
	var packed := load(definition.body_scene_path) as PackedScene
	if packed == null:
		return false
	visual_root = packed.instantiate() as Node3D
	add_child(visual_root)
	visual_root.scale = Vector3.ONE * size_multiplier
	package = GiantPackage.new()
	if not package.bind(visual_root):
		push_error("GiantV2 package: " + package.validation_error)
		return false
	skeleton = package.skeleton
	# Keep the true segmented giant mesh. The old adapter's merged mesh cache is
	# global across assets and must never be used here.
	for part: Variant in package.body_parts.values():
		lod_meshes.append(part as MeshInstance3D)
	return true

func apply_lod_policy(enabled: bool, _near: float, _far: float, cull_distance: float, _fade: float = 2.0) -> void:
	runtime_lod_enabled = enabled
	runtime_cull_distance = cull_distance
	for mesh: MeshInstance3D in lod_meshes:
		mesh.visibility_range_begin = 0.0
		mesh.visibility_range_end = maxf(160.0, cull_distance) if enabled else 0.0
