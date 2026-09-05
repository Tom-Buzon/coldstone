extends Area3D
class_name HopliteEquipmentPickup

const WeaponTuningScript = preload("res://scripts/equipment/weapon_tuning.gd")

@export var equipment: HopliteEquipmentItemData
@export_range(0.1, 3.0, 0.05) var pickup_radius: float = 0.85
@export_range(0.0, 3.0, 0.05) var hover_height: float = 0.72
@export_range(0.0, 3.0, 0.05) var spin_speed: float = 0.70
@export var create_visual: bool = true

var visual_pivot: Node3D
var collect_target: Node


func _ready() -> void:
	add_to_group(&"equipment_pickup")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = true
	_build_trigger()
	if create_visual:
		_build_visual()
	set_process(visual_pivot != null and not is_zero_approx(spin_speed))
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if visual_pivot != null:
		visual_pivot.rotation.y = wrapf(visual_pivot.rotation.y + spin_speed * delta, -PI, PI)


func collect_by(player: HopliteUALNativePlayer) -> bool:
	if equipment == null or player == null:
		return false
	var replaced_item := player.equipped_item_for_slot(equipment.slot)
	if not player.equip_item(equipment):
		return false
	_spawn_replaced_equipment(replaced_item)
	player.unregister_equipment_pickup(self)
	monitoring = false
	var target: Node = collect_target if collect_target != null and is_instance_valid(collect_target) else self
	target.queue_free()
	return true


func can_be_collected_by(player: HopliteUALNativePlayer) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var offset := player.global_position - global_position
	return Vector2(offset.x, offset.z).length() <= pickup_radius + 0.65 and absf(offset.y) <= 2.0 and player.can_equip_item(equipment)


func interaction_label() -> String:
	return equipment.display_name if equipment != null else "Équipement"


func _build_trigger() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "PickupRange"
	var shape := SphereShape3D.new()
	shape.radius = pickup_radius
	collision.shape = shape
	collision.position = Vector3.UP * hover_height
	add_child(collision)


func _build_visual() -> void:
	visual_pivot = Node3D.new()
	visual_pivot.name = "VisualPivot"
	visual_pivot.position = Vector3.UP * hover_height
	add_child(visual_pivot)
	if equipment == null or equipment.visual_scene == null:
		push_error("HopliteEquipmentPickup._build_visual: missing equipment visual")
		return
	var visual: Node = equipment.visual_scene.instantiate()
	visual.name = "PickupVisual"
	visual_pivot.add_child(visual)
	_apply_weapon_display_scale()
	visual_pivot.rotation_degrees.x = 18.0 if equipment.slot == HopliteEquipmentItemData.Slot.WEAPON else 0.0


func refresh_tuning_visual(item_id: StringName) -> void:
	if equipment == null or equipment.item_id != item_id:
		return
	_apply_weapon_display_scale()


func _apply_weapon_display_scale() -> void:
	if visual_pivot == null or equipment == null or equipment.slot != HopliteEquipmentItemData.Slot.WEAPON:
		return
	var tuning := WeaponTuningScript.load_values(equipment)
	visual_pivot.scale = equipment.hand_scale * float(tuning[&"scale"])


func _spawn_replaced_equipment(replaced_item: HopliteEquipmentItemData) -> void:
	if replaced_item == null or replaced_item.visual_scene == null:
		return
	var consumed_target: Node = collect_target if collect_target != null and is_instance_valid(collect_target) else self
	var world_parent := consumed_target.get_parent() as Node3D
	if world_parent == null:
		return

	var dropped := RigidBody3D.new()
	dropped.name = "Dropped_%s" % String(replaced_item.item_id)
	dropped.mass = 0.55 if replaced_item.slot == HopliteEquipmentItemData.Slot.WEAPON else 1.25
	dropped.linear_damp = 2.4
	dropped.angular_damp = 3.0
	# The dropped item scans the world layer but does not join the enemy/damageable
	# layer, so attacks and AI never mistake it for a combatant.
	dropped.collision_layer = 0
	dropped.collision_mask = 1
	world_parent.add_child(dropped)
	dropped.global_position = global_position + Vector3.UP * 0.55
	dropped.rotation_degrees = Vector3(0.0, randf_range(-180.0, 180.0), 90.0) if replaced_item.slot == HopliteEquipmentItemData.Slot.WEAPON else Vector3(90.0, randf_range(-180.0, 180.0), 0.0)

	var visual_root := Node3D.new()
	visual_root.name = "DroppedVisual"
	dropped.add_child(visual_root)
	var visual := replaced_item.visual_scene.instantiate()
	visual.name = "EquipmentVisual"
	visual_root.add_child(visual)
	if replaced_item.slot == HopliteEquipmentItemData.Slot.WEAPON:
		var tuning := WeaponTuningScript.load_values(replaced_item)
		visual_root.scale = replaced_item.hand_scale * float(tuning[&"scale"])

	var body_collision := CollisionShape3D.new()
	body_collision.name = "GroundCollision"
	body_collision.shape = _drop_collision_shape(replaced_item)
	if replaced_item.slot == HopliteEquipmentItemData.Slot.WEAPON:
		body_collision.position.y = _drop_weapon_center_y(replaced_item)
	dropped.add_child(body_collision)

	var replacement_pickup := HopliteEquipmentPickup.new()
	replacement_pickup.name = "EquipmentPickup_%s" % String(replaced_item.item_id)
	replacement_pickup.equipment = replaced_item
	replacement_pickup.create_visual = false
	replacement_pickup.hover_height = 0.0
	replacement_pickup.spin_speed = 0.0
	replacement_pickup.collect_target = dropped
	replacement_pickup.visual_pivot = visual_root
	dropped.add_child(replacement_pickup)

	dropped.apply_central_impulse(Vector3(randf_range(-0.18, 0.18), 0.38, randf_range(-0.18, 0.18)))
	dropped.apply_torque_impulse(Vector3(randf_range(-0.08, 0.08), randf_range(-0.06, 0.06), randf_range(-0.08, 0.08)))
	dropped.reset_physics_interpolation()


func _drop_collision_shape(item: HopliteEquipmentItemData) -> Shape3D:
	if item.slot == HopliteEquipmentItemData.Slot.SHIELD:
		var shield_shape := BoxShape3D.new()
		shield_shape.size = Vector3(0.82, 0.82, 0.12)
		return shield_shape
	var tuning := WeaponTuningScript.load_values(item)
	var scale_multiplier := float(tuning[&"scale"])
	var weapon_shape := BoxShape3D.new()
	weapon_shape.size = Vector3(0.12, maxf(0.45, float(tuning[&"blade_tip"]) + 0.20) * scale_multiplier, 0.12)
	return weapon_shape


func _drop_weapon_center_y(item: HopliteEquipmentItemData) -> float:
	var tuning := WeaponTuningScript.load_values(item)
	return maxf(0.22, (float(tuning[&"blade_tip"]) + 0.20) * 0.5) * float(tuning[&"scale"])


func _on_body_entered(body: Node3D) -> void:
	if body is HopliteUALNativePlayer:
		(body as HopliteUALNativePlayer).register_equipment_pickup(self)


func _on_body_exited(body: Node3D) -> void:
	if body is HopliteUALNativePlayer:
		(body as HopliteUALNativePlayer).unregister_equipment_pickup(self)


func _exit_tree() -> void:
	for player_node: Node in get_tree().get_nodes_in_group("player"):
		if player_node is HopliteUALNativePlayer:
			(player_node as HopliteUALNativePlayer).unregister_equipment_pickup(self)
