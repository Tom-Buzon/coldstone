extends Area3D
class_name HopliteWolfBossHitbox

var boss_owner: Node


func configure(owner_node: Node, body_length: float = 3.8) -> void:
	boss_owner = owner_node
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("damageable")
	_add_zone(&"torso", Vector3(0.0, 1.20, 0.15), Vector3(body_length * 0.72, 1.35, body_length), 0.35)
	_add_sphere_zone(&"head", Vector3(0.0, 1.48, -body_length * 0.56), body_length * 0.34, 1.0)
	_add_sphere_zone(&"flanks", Vector3(0.0, 1.12, body_length * 0.42), body_length * 0.38, 0.55)


func _add_zone(zone: StringName, position_value: Vector3, size: Vector3, priority: float) -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Zone_%s" % String(zone)
	collision.position = position_value
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)
	_register_zone(collision, zone, maxf(size.x, maxf(size.y, size.z)) * 0.5, priority)


func _add_sphere_zone(zone: StringName, position_value: Vector3, radius: float, priority: float) -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Zone_%s" % String(zone)
	collision.position = position_value
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	add_child(collision)
	_register_zone(collision, zone, radius, priority)


func _register_zone(collision: CollisionShape3D, zone: StringName, radius: float, priority: float) -> void:
	collision.set_meta("damage_zone", zone)
	collision.set_meta("zone_radius", radius)
	collision.set_meta("zone_priority", priority)


func receive_weapon_hit(hit: Variant, shape_index: int) -> bool:
	return receive_weapon_hit_zone(hit, zone_from_shape_index(shape_index))


func receive_weapon_hit_zone(hit: Variant, zone: StringName) -> bool:
	if boss_owner == null or not is_instance_valid(boss_owner) or zone == StringName():
		return false
	if boss_owner.has_method("can_receive_hit_from") and not bool(boss_owner.call("can_receive_hit_from", hit.source)):
		return false
	if boss_owner.has_method("receive_anatomy_hit"):
		boss_owner.call("receive_anatomy_hit", hit, zone)
		return true
	return false


func get_combat_owner() -> Node:
	return boss_owner


func zone_from_shape_index(shape_index: int) -> StringName:
	if shape_index < 0:
		return StringName()
	var owner_id := shape_find_owner(shape_index)
	if owner_id < 0:
		return StringName()
	var owner_node := shape_owner_get_owner(owner_id)
	if owner_node is CollisionShape3D:
		return StringName((owner_node as CollisionShape3D).get_meta("damage_zone", StringName()))
	return StringName()


func zone_world_center_from_shape_index(shape_index: int) -> Vector3:
	var collision := _collision_from_shape_index(shape_index)
	return collision.global_position if collision != null else global_position


func zone_radius_from_shape_index(shape_index: int) -> float:
	var collision := _collision_from_shape_index(shape_index)
	return float(collision.get_meta("zone_radius", 0.8)) if collision != null else 0.8


func zone_priority_from_shape_index(shape_index: int) -> float:
	var collision := _collision_from_shape_index(shape_index)
	return float(collision.get_meta("zone_priority", 0.0)) if collision != null else 0.0


func shutdown() -> void:
	collision_layer = 0
	monitorable = false
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)


func _collision_from_shape_index(shape_index: int) -> CollisionShape3D:
	if shape_index < 0:
		return null
	var owner_id := shape_find_owner(shape_index)
	if owner_id < 0:
		return null
	return shape_owner_get_owner(owner_id) as CollisionShape3D
