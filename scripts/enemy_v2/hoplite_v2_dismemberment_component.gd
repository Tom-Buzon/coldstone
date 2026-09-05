extends Node
class_name HopliteV2DismembermentComponent

signal severed(zone: StringName, fragment: HopliteV2Fragment)
signal equipment_lost(slot: StringName)

const PackageScript = preload("res://scripts/enemy_v2/hoplite_v2_package.gd")
const FragmentScript = preload("res://scripts/enemy_v2/hoplite_v2_fragment.gd")
const BloodBurstScript = preload("res://scripts/gore/blood_burst.gd")

var actor: Node3D
var skeleton: Skeleton3D
var anatomy: HopliteAnatomyHitbox
var package: HopliteV2Package
var definition: HopliteEnemyV2Definition
var severed_zones: Dictionary = {}
var hidden_bones: Dictionary = {}
var last_fragment: HopliteV2Fragment
static var _fragments_warmed: bool = false


func install(
	actor_value: Node3D,
	skeleton_value: Skeleton3D,
	anatomy_value: HopliteAnatomyHitbox,
	definition_value: HopliteEnemyV2Definition
) -> bool:
	actor = actor_value
	skeleton = skeleton_value
	anatomy = anatomy_value
	definition = definition_value
	package = PackageScript.load_default() as HopliteV2Package
	if actor == null or skeleton == null or anatomy == null or definition == null or not package.validate(false).is_empty():
		return false
	if not _fragments_warmed:
		for raw_zone: Variant in (package.contract.get("fragments", {}) as Dictionary).get("required", []):
			if not FragmentScript.preload_fragment(package.fragment_definition(StringName(raw_zone))):
				return false
		_fragments_warmed = true
	return true


func sever(zone: StringName, hit: Variant) -> bool:
	if severed_zones.has(zone) or hit == null:
		return false
	var fragment_definition := package.fragment_definition(zone)
	if fragment_definition.is_empty():
		return false
	var root_bone := anatomy.get_zone_primary_bone(zone)
	if root_bone < 0:
		return false
	var cut_position := (skeleton.global_transform * skeleton.get_bone_global_pose(root_bone)).origin
	var fragment := _spawn_fragment(zone, fragment_definition, root_bone, cut_position, hit)
	if fragment == null:
		return false
	severed_zones[zone] = true
	_disable_related_hitboxes(zone)
	_hide_bone_branch(root_bone)
	_spawn_blood(cut_position, hit.direction, float(hit.sever_damage))
	if zone in [&"upper_arm_r", &"forearm_r"]:
		equipment_lost.emit(&"weapon")
	elif zone in [&"upper_arm_l", &"forearm_l"]:
		equipment_lost.emit(&"shield")
	last_fragment = fragment
	severed.emit(zone, fragment)
	return true


func is_severed(zone: StringName) -> bool:
	return severed_zones.has(zone)


func _spawn_fragment(
	zone: StringName,
	fragment_definition: Dictionary,
	root_bone: int,
	cut_position: Vector3,
	hit: Variant
) -> HopliteV2Fragment:
	var fragment := FragmentScript.new() as HopliteV2Fragment
	fragment.name = "HopliteV2Fragment_%s" % zone
	if not fragment.configure(fragment_definition):
		fragment.free()
		return null
	var debris_parent := get_tree().current_scene
	if debris_parent == null:
		debris_parent = actor.get_parent()
	if debris_parent == null:
		fragment.free()
		return null
	debris_parent.add_child(fragment)
	fragment.add_to_group(&"enemy_v2_fragment")
	var source_pivot := _source_vector_to_godot((fragment_definition.get("pivot", {}) as Dictionary).get("position", []))
	var centered_pivot := fragment.centered_point(source_pivot)
	var world_basis := actor.global_basis.orthonormalized()
	# 3DGen fragments keep body-space vertices. Align their authored cut pivot to
	# the currently animated root bone after recentering the RigidBody on its mesh.
	fragment.global_transform = Transform3D(world_basis, cut_position - world_basis * centered_pivot)
	fragment.set_ground_reference(actor.global_position.y)
	var direction: Vector3 = hit.direction
	if hit.impulse is Vector3 and (hit.impulse as Vector3).length_squared() > 0.0001:
		direction = hit.impulse as Vector3
	if direction.length_squared() < 0.0001:
		direction = actor.global_basis.z
	# A cut needs one readable projection, not pinball energy. The fragment owns
	# the remaining damping and puts itself to sleep after sustained ground contact.
	var impulse_strength := clampf(1.55 + float(hit.sever_damage) * 0.020, 1.8, 3.8)
	fragment.launch(
		direction.normalized() * impulse_strength,
		centered_pivot,
		Vector3(0.035, 0.055, 0.03) * minf(impulse_strength, 3.0)
	)
	fragment.set_meta("source_bone", skeleton.get_bone_name(root_bone))
	return fragment


func _disable_related_hitboxes(zone: StringName) -> void:
	anatomy.disable_zone(zone)
	match zone:
		&"head":
			anatomy.disable_zone(&"neck")
		&"upper_arm_l":
			anatomy.disable_zone(&"forearm_l")
		&"upper_arm_r":
			anatomy.disable_zone(&"forearm_r")
		&"thigh_l":
			anatomy.disable_zone(&"shin_l")
		&"thigh_r":
			anatomy.disable_zone(&"shin_r")


func _hide_bone_branch(root_bone: int) -> void:
	for bone_index: int in range(skeleton.get_bone_count()):
		if _bone_is_descendant_of(bone_index, root_bone):
			hidden_bones[bone_index] = true
			skeleton.set_bone_pose_scale(bone_index, Vector3.ONE * 0.001)


func _bone_is_descendant_of(bone_index: int, root_bone: int) -> bool:
	var current := bone_index
	while current >= 0:
		if current == root_bone:
			return true
		current = skeleton.get_bone_parent(current)
	return false


func _spawn_blood(position_value: Vector3, direction: Vector3, sever_damage: float) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = actor.get_parent()
	if parent == null:
		return
	var burst := BloodBurstScript.new() as HopliteBloodBurst
	parent.add_child(burst)
	burst.setup(position_value, direction, clampf(2.0 + sever_damage / 80.0, 2.0, 3.2), true)


func _source_vector_to_godot(raw: Variant) -> Vector3:
	var values := raw as Array
	if values == null or values.size() < 3:
		return Vector3.ZERO
	# 3DGen manifest is Blender Z-up; Godot's glTF scene is Y-up.
	return Vector3(float(values[0]), float(values[2]), -float(values[1]))
