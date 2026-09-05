extends RefCounted

static func create() -> HopliteEnemyV2Definition:
	var value := HopliteEnemyV2Definition.new()
	value.archetype_id = &"giant_v2"
	value.legacy_archetype_id = &"giant_standard"
	value.display_name = "GÉANT — MINIBOSS V2"
	value.unit_role = &"giant"
	value.body_scene_path = "res://assets/characters/3dgen_demo/geant1-1787584159710.glb"
	value.package_manifest_path = "res://assets/characters/enemy_v2/giant/giant_v2.package.json"
	value.animation_library_path = "res://assets/animations/enemy_v2/giant/giant_v2_animation_library.res"
	value.equipment_profile = &"unarmed"
	value.guard_profile = preload("res://data/combat/guard_profiles/hoplite_v2_standard.tres")
	value.semantic_animations = {&"idle": &"Idle", &"move": &"Jog_Fwd", &"sprint": &"Sprint", &"death": &"Death01", &"giant_punch": &"giant_punch", &"giant_swipe": &"giant_swipe", &"giant_slam": &"giant_jump_attack_alt"}
	value.max_health = 620.0
	value.move_speed = 3.2
	value.attack_damage = 28.0
	return value
