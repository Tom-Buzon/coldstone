extends Node3D
class_name HopliteV2EquipmentComponent

const DORY_SPEAR_SCENE := preload("res://assets/weapons/dory_spear.glb")
const ASPIS_SHIELD_SCENE := preload("res://assets/weapons/aspis_shield.glb")
const XIPHOS_SCENE := preload("res://assets/weapons/xiphos_main.glb")
const BOW_SCENE := preload("res://assets/blenderAseet/08_armes/greek_composite_bow/greek_composite_bow_LOD1.glb")
const ShieldHitboxScript = preload("res://scripts/enemy/shield_hitbox.gd")
const DroppedShieldScript = preload("res://scripts/enemy_v2/hoplite_v2_dropped_shield.gd")

var weapon_attachment: BoneAttachment3D
var shield_attachment: BoneAttachment3D
var shield_hitbox: HopliteShieldHitbox
var weapon_visual: Node3D
var shield_visual: Node3D
var shield_root: Node3D
var shield_mesh: MeshInstance3D
var standard_weapon_basis := Basis.IDENTITY
var geometry: Array[GeometryInstance3D] = []
var shield_dropped := false

const BAYONET_WEAPON_BASIS := Basis(
	Vector3(0.741353, -0.049012, -0.669323),
	Vector3(0.325474, 0.898450, 0.294710),
	Vector3(0.586909, -0.436332, 0.682021)
)
## Imported aspis geometry is a 0.94 x 0.94 disc with its thin axis on local Z;
## local +Z is its face and local +Y its top rim. The carried shield stays in
## this actor-space guard anchor: an
## arbitrary hand/forearm clip can no longer put it behind the unit or flat
## above its head.
const SHIELD_MESH_BASIS := Basis.IDENTITY
const SHIELD_MESH_CENTER := Vector3(0.36, 1.08, 0.32)


func install(skeleton: Skeleton3D, definition: HopliteEnemyV2Definition, combat_owner: Node = null) -> bool:
	if skeleton == null or skeleton.find_bone("DEF-hand.R") < 0 or skeleton.find_bone("DEF-forearm.L") < 0:
		push_error("HopliteV2 equipment requires the canonical right hand and left forearm bones")
		return false
	if definition.equipment_profile == &"bow":
		return _install_bow(skeleton, definition)
	weapon_attachment = _attachment(skeleton, "HopliteV2WeaponAttachment", "DEF-hand.R")
	var sword := definition.equipment_profile == &"sword_buckler"
	var weapon_root := _instantiate_gear(XIPHOS_SCENE if sword else DORY_SPEAR_SCENE, "Xiphos" if sword else "DorySpear", "SM_Xiphos_Main" if sword else "SM_Dory_Spear")
	weapon_root.scale = Vector3.ONE * definition.weapon_scale
	weapon_attachment.add_child(weapon_root)
	weapon_visual = weapon_root.get_child(0) as Node3D if weapon_root.get_child_count() > 0 else null
	if weapon_visual != null:
		# The visually dominant spearhead is on imported local +Y (the opposite
		# end is the sauroter). This skin is authored facing actor +Z, so the dory
		# must use the same visual-forward convention.
		weapon_visual.rotation_degrees.x = 55.0
		standard_weapon_basis = weapon_visual.basis
		weapon_visual.set_meta("hoplite_v2_grip_calibrated", true)

	# Keep the canonical bone attachment as a semantic/equipment contract, but
	# anchor the current V2 visual to the actor. The animation pack contains
	# incompatible left-arm poses (notably Jog and Bayonet); letting those poses
	# own the aspis transform made both its visual and red debug collider detach.
	shield_attachment = _attachment(skeleton, "HopliteV2ShieldAttachment", "DEF-forearm.L")
	shield_root = _instantiate_gear(ASPIS_SHIELD_SCENE, "AspisShield", "SM_Aspis_Shield")
	add_child(shield_root)
	shield_visual = shield_root.get_child(0) as Node3D if shield_root.get_child_count() > 0 else null
	shield_mesh = shield_root.find_child("SM_Aspis_Shield", true, false) as MeshInstance3D
	if shield_visual != null and shield_mesh != null:
		_anchor_shield_mesh(definition.shield_scale)
		shield_visual.set_meta("hoplite_v2_grip_calibrated", true)
		shield_mesh.set_meta("hoplite_v2_actor_space_anchor", true)
		if combat_owner != null:
			shield_hitbox = ShieldHitboxScript.new() as HopliteShieldHitbox
			shield_hitbox.name = "HopliteV2PhysicalShield"
			# Parenting the collider to the actual disc mesh guarantees that the red
			# collision-debug cylinder and visible aspis share one exact transform.
			shield_mesh.add_child(shield_hitbox)
			shield_hitbox.configure(combat_owner, 0.48, &"z")
	_collect_geometry(self)
	_collect_geometry(weapon_attachment)
	set_meta("equipment_profile", definition.equipment_profile)
	return true


func _install_bow(skeleton: Skeleton3D, definition: HopliteEnemyV2Definition) -> bool:
	weapon_attachment = _attachment(skeleton, "ArcherV2BowAttachment", "DEF-hand.L")
	weapon_visual = BOW_SCENE.instantiate() as Node3D
	weapon_attachment.add_child(weapon_visual)
	# Calibrated against the baked draw pose. glTF converts Blender's -Y
	# projectile axis to +Z; limbs are X, thin axis Y. Keep the bow vertical,
	# its curve pointing forward and its grip on the actual animated hand.
	weapon_visual.basis = Basis(
		Vector3(-0.425795, 0.217162, 0.878373),
		Vector3(0.607881, -0.650403, 0.455473),
		Vector3(0.670208, 0.727885, 0.144929)
	).orthonormalized().scaled(Vector3.ONE * definition.weapon_scale)
	standard_weapon_basis = weapon_visual.basis
	_collect_geometry(weapon_attachment)
	set_meta("equipment_profile", &"bow")
	return true


func projectile_origin() -> Vector3:
	# Keep launch clear of the body regardless of the current animation blend.
	var actor := get_parent() as Node3D
	return actor.global_position + Vector3.UP * 1.4 + actor.global_basis.z.normalized() * 0.75


func apply_lod_policy(enabled: bool, cull_distance: float, fade_margin: float = 2.0) -> void:
	_prune_freed_geometry()
	for item: GeometryInstance3D in geometry:
		item.visibility_range_begin = 0.0
		item.visibility_range_end = cull_distance if enabled else 0.0
		item.visibility_range_begin_margin = 0.0
		item.visibility_range_end_margin = fade_margin if enabled else 0.0
		item.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


func set_shadows_enabled(enabled: bool) -> void:
	_prune_freed_geometry()
	for item: GeometryInstance3D in geometry:
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_guard_active(enabled: bool) -> void:
	if shield_hitbox != null:
		shield_hitbox.set_guard_active(enabled)


func shutdown_combat() -> void:
	if shield_hitbox != null:
		shield_hitbox.shutdown()


func drop_shield() -> RigidBody3D:
	if shield_dropped or shield_root == null or shield_mesh == null or not shield_root.is_inside_tree():
		return null
	shield_dropped = true
	if shield_hitbox != null:
		shield_hitbox.shutdown()
	var debris_parent := get_tree().current_scene
	if debris_parent == null:
		debris_parent = get_parent()
	if debris_parent == null:
		return null
	var mesh_transform := shield_mesh.global_transform
	var mesh_scale := mesh_transform.basis.get_scale()
	var body := DroppedShieldScript.new() as RigidBody3D
	body.name = "DroppedHopliteV2Shield"
	body.mass = 6.5
	body.collision_layer = 16
	body.collision_mask = 1
	body.can_sleep = true
	body.continuous_cd = true
	body.linear_damp = 2.2
	# A large vertical disc is metastable on its rim. The previous damping killed
	# its angular impulse before gravity could topple it.
	body.angular_damp = 1.15
	var material := PhysicsMaterial.new()
	material.friction = 1.0
	material.rough = true
	material.bounce = 0.0
	material.absorbent = true
	body.physics_material_override = material
	debris_parent.add_child(body)
	body.global_transform = Transform3D(mesh_transform.basis.orthonormalized(), mesh_transform.origin)
	# The dropped shield now belongs to the debris body. It must leave the actor's
	# LOD geometry cache before that body eventually frees it.
	_forget_geometry_under(shield_root)
	shield_root.reparent(body, true)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "DroppedShieldCollision"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.48 * maxf(mesh_scale.x, mesh_scale.y)
	cylinder.height = maxf(0.035, 0.08 * mesh_scale.z)
	shape_node.shape = cylinder
	# The imported aspis is a disc on local XY, while CylinderShape3D uses Y as
	# its axis. Rotate the primitive so its thin axis follows shield local Z.
	shape_node.basis = Basis(Vector3.RIGHT, PI * 0.5)
	body.add_child(shape_node)
	body.call("configure_ground", global_position.y, cylinder.height)
	# Give the rim a small authored lean, then a local tipping impulse. This keeps
	# the fall physical while guaranteeing that the aspis cannot balance upright.
	var tip_axis := body.global_basis.x.normalized()
	body.global_basis = Basis(tip_axis, deg_to_rad(8.0)) * body.global_basis
	body.apply_central_impulse(global_basis.x.normalized() * 0.35 + Vector3.UP * 0.18)
	body.apply_torque_impulse(body.global_basis.x.normalized() * 2.8 + body.global_basis.y.normalized() * 0.45)
	var timer := get_tree().create_timer(9.0)
	timer.timeout.connect(body.queue_free)
	return body


func set_weapon_grip(profile: StringName) -> void:
	if weapon_visual == null:
		return
	weapon_visual.basis = BAYONET_WEAPON_BASIS if profile == &"bayonet" else standard_weapon_basis


func set_weapon_visible(enabled: bool) -> void:
	if weapon_attachment != null:
		_set_geometry_visible(weapon_attachment, enabled)


func set_shield_visible(enabled: bool) -> void:
	if shield_root != null:
		_set_geometry_visible(shield_root, enabled)
	if not enabled and shield_hitbox != null:
		shield_hitbox.shutdown()


func _attachment(skeleton: Skeleton3D, node_name: String, bone_name: String) -> BoneAttachment3D:
	var result := BoneAttachment3D.new()
	result.name = node_name
	result.bone_name = bone_name
	skeleton.add_child(result)
	return result


func _instantiate_gear(scene: PackedScene, root_name: String, mesh_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = root_name
	var imported := scene.instantiate()
	imported.name = "Imported%sVisual" % root_name
	root.add_child(imported)
	var mesh := imported as MeshInstance3D
	if mesh == null or mesh.name != mesh_name:
		mesh = imported.find_child(mesh_name, true, false) as MeshInstance3D
	if mesh == null:
		push_error("HopliteV2 equipment is missing %s" % mesh_name)
	return root


func _anchor_shield_mesh(scale_value: float) -> void:
	var authored_mesh := _transform_relative_to(shield_mesh, shield_root)
	var authored_scale := authored_mesh.basis.get_scale()
	var desired_scale := authored_scale * maxf(scale_value, 0.01)
	var desired_mesh := Transform3D(SHIELD_MESH_BASIS.scaled(desired_scale), SHIELD_MESH_CENTER)
	shield_root.transform = desired_mesh * authored_mesh.affine_inverse()


func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and parent != ancestor:
		result = parent.transform * result
		parent = parent.get_parent() as Node3D
	return result


func _collect_geometry(node: Node) -> void:
	if node is GeometryInstance3D:
		geometry.append(node as GeometryInstance3D)
	for child: Node in node.get_children():
		_collect_geometry(child)


func _forget_geometry_under(root: Node) -> void:
	for index: int in range(geometry.size() - 1, -1, -1):
		var item := geometry[index]
		if item == null or not is_instance_valid(item) or item == root or root.is_ancestor_of(item):
			geometry.remove_at(index)


func _prune_freed_geometry() -> void:
	for index: int in range(geometry.size() - 1, -1, -1):
		if geometry[index] == null or not is_instance_valid(geometry[index]):
			geometry.remove_at(index)


func _set_geometry_visible(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visible = enabled
	for child: Node in node.get_children():
		_set_geometry_visible(child, enabled)
