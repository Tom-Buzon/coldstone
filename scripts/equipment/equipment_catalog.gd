extends RefCounted
class_name HopliteEquipmentCatalog

const XIPHOS: HopliteEquipmentItemData = preload("res://data/equipment/weapons/xiphos.tres")
const AEGIS_FANG: HopliteEquipmentItemData = preload("res://data/equipment/weapons/aegis_fang.tres")
const ASPIS: HopliteEquipmentItemData = preload("res://data/equipment/shields/aspis.tres")
const TITAN_AEGIS: HopliteEquipmentItemData = preload("res://data/equipment/shields/titan_aegis.tres")
const ELEMENTAL_BLOOD_SWORD: HopliteEquipmentItemData = preload("res://data/equipment/weapons/elemental_blood_sword.tres")
const ELEMENTAL_THIN_SWORD: HopliteEquipmentItemData = preload("res://data/equipment/weapons/elemental_thin_sword.tres")
const ELEMENTAL_SUN_SWORD: HopliteEquipmentItemData = preload("res://data/equipment/weapons/elemental_sun_sword.tres")
const ELEMENTAL_METEOR_SWORD: HopliteEquipmentItemData = preload("res://data/equipment/weapons/elemental_meteor_sword.tres")
const ELEMENTAL_ICE_SWORD: HopliteEquipmentItemData = preload("res://data/equipment/weapons/elemental_ice_sword.tres")
const ELEMENTAL_SPACE_SWORD: HopliteEquipmentItemData = preload("res://data/equipment/weapons/elemental_space_sword.tres")
const ELEMENTAL_LAVA_SWORD: HopliteEquipmentItemData = preload("res://data/equipment/weapons/elemental_lava_sword.tres")

const ITEMS_BY_VISUAL_PATH: Dictionary = {
	"res://assets/weapons/xiphos_main.glb": XIPHOS,
	"res://assets/weapons/aegis_fang.glb": AEGIS_FANG,
	"res://assets/weapons/aspis_shield.glb": ASPIS,
	"res://assets/weapons/titan_aegis.glb": TITAN_AEGIS,
	"res://assets/weapons/elemental/elemental_blood_sword.glb": ELEMENTAL_BLOOD_SWORD,
	"res://assets/weapons/elemental/elemental_thin_sword.glb": ELEMENTAL_THIN_SWORD,
	"res://assets/weapons/elemental/elemental_sun_sword.glb": ELEMENTAL_SUN_SWORD,
	"res://assets/weapons/elemental/elemental_meteor_sword.glb": ELEMENTAL_METEOR_SWORD,
	"res://assets/weapons/elemental/elemental_ice_sword.glb": ELEMENTAL_ICE_SWORD,
	"res://assets/weapons/elemental/elemental_space_sword.glb": ELEMENTAL_SPACE_SWORD,
	"res://assets/weapons/elemental/elemental_lava_sword.glb": ELEMENTAL_LAVA_SWORD,
}

const ELEMENTAL_SWORDS: Array[HopliteEquipmentItemData] = [
	ELEMENTAL_BLOOD_SWORD,
	ELEMENTAL_THIN_SWORD,
	ELEMENTAL_SUN_SWORD,
	ELEMENTAL_METEOR_SWORD,
	ELEMENTAL_ICE_SWORD,
	ELEMENTAL_SPACE_SWORD,
	ELEMENTAL_LAVA_SWORD,
]

const ALL_WEAPONS: Array[HopliteEquipmentItemData] = [
	XIPHOS,
	AEGIS_FANG,
	ELEMENTAL_BLOOD_SWORD,
	ELEMENTAL_THIN_SWORD,
	ELEMENTAL_SUN_SWORD,
	ELEMENTAL_METEOR_SWORD,
	ELEMENTAL_ICE_SWORD,
	ELEMENTAL_SPACE_SWORD,
	ELEMENTAL_LAVA_SWORD,
]


static func item_for_visual_path(path: String) -> HopliteEquipmentItemData:
	var normalized_path := path.replace("\\", "/")
	return ITEMS_BY_VISUAL_PATH.get(normalized_path) as HopliteEquipmentItemData


static func is_pickup_visual(path: String) -> bool:
	return item_for_visual_path(path) != null
