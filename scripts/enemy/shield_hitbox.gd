extends Area3D
class_name HopliteShieldHitbox

const EXPERIMENTAL_WALL_RUN_SHIELD_LAYER: int = 64

var combat_owner: Node = null
var shield_radius: float = 0.48
var active: bool = false
var phalanx_wall_run_surface: bool = false


func configure(owner_node: Node, radius: float = 0.48, cylinder_axis: StringName = &"z") -> void:
	combat_owner = owner_node
	shield_radius = maxf(radius, 0.12)
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("damageable")
	phalanx_wall_run_surface = owner_node.has_method("is_phalanx_unit") and bool(owner_node.call("is_phalanx_unit"))
	if phalanx_wall_run_surface:
		add_to_group("wall_run_phalanx_shield")

	var collision := CollisionShape3D.new()
	collision.name = "ShieldCollision"
	collision.set_meta("damage_zone", &"shield")
	var shape := CylinderShape3D.new()
	shape.height = 0.13
	shape.radius = shield_radius
	collision.shape = shape
	# The procedural V1 aspis and the verified V2 imported aspis use local Z as
	# their disc normal. The optional Y path remains for other authored assets.
	collision.rotation_degrees = Vector3.ZERO if cylinder_axis == &"y" else Vector3(90.0, 0.0, 0.0)
	add_child(collision)
	set_guard_active(false)


func set_guard_active(enabled: bool) -> void:
	active = enabled
	# Keeping a lowered shield out of the weapon query is important: otherwise its
	# priority can win over anatomy and silently swallow a hit even when the owner
	# is not guarding.
	# Layer 64 is intentionally isolated from weapon/anatomy queries. It exposes
	# only a raised phalanx shield to the experimental wall-run probes; layer 8
	# keeps the existing combat behavior unchanged.
	collision_layer = (8 | EXPERIMENTAL_WALL_RUN_SHIELD_LAYER) if active and phalanx_wall_run_surface else (8 if active else 0)
	monitorable = active


func receive_weapon_hit(hit: Variant, _shape_index: int) -> bool:
	return receive_weapon_hit_zone(hit, &"shield")


func receive_weapon_hit_zone(hit: Variant, _zone: StringName) -> bool:
	if not active or combat_owner == null or not is_instance_valid(combat_owner):
		return false
	if combat_owner.has_method("can_receive_hit_from") and not bool(combat_owner.call("can_receive_hit_from", hit.source)):
		return false
	if combat_owner.has_method("receive_shield_hit"):
		return bool(combat_owner.call("receive_shield_hit", hit))
	return false


func get_combat_owner() -> Node:
	return combat_owner


func zone_from_shape_index(shape_index: int) -> StringName:
	return &"shield" if shape_index >= 0 and active else StringName()


func zone_world_center_from_shape_index(_shape_index: int) -> Vector3:
	return global_position


func zone_radius_from_shape_index(_shape_index: int) -> float:
	# Hit arbitration operates in world space. The collider itself inherits the
	# archetype and equipment scales, so returning the authored local radius made
	# large shields lose priority near their physical rim.
	var world_scale := maxf(global_basis.x.length(), maxf(global_basis.y.length(), global_basis.z.length()))
	return shield_radius * world_scale


func zone_priority_from_shape_index(_shape_index: int) -> float:
	# If blade, aspis and anatomy overlap, the physical obstacle wins this target's
	# single contact arbitration.
	return 5.0


func shutdown() -> void:
	set_guard_active(false)
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)
