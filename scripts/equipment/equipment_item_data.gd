extends Resource
class_name HopliteEquipmentItemData

enum Slot {
	WEAPON,
	SHIELD,
}

@export_group("Identity")
@export var item_id: StringName = &""
@export var display_name: String = ""
@export var slot: Slot = Slot.WEAPON

@export_group("Visual")
@export var visual_scene: PackedScene
@export var visual_mesh_name: StringName = &""
@export var hand_position: Vector3 = Vector3.ZERO
@export var hand_rotation_degrees: Vector3 = Vector3.ZERO
@export var hand_scale: Vector3 = Vector3.ONE

@export_group("Weapon contact")
@export var blade_material_name: StringName = &""
@export var blade_base_y: float = 0.0
@export var blade_tip_y: float = 0.0
@export_range(0.01, 0.5, 0.01) var hit_radius: float = 0.12
@export_range(0.1, 5.0, 0.05) var damage_multiplier: float = 1.0


func has_valid_weapon_contact() -> bool:
	return slot == Slot.WEAPON and blade_tip_y > blade_base_y
