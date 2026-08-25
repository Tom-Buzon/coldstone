extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const TARGET_ARCHETYPES: Array[StringName] = [
	&"spearman",
	&"ngeneral",
	&"ngeneral_veteran",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	stage.name = "PhalanxEquipmentProbe"
	root.add_child(stage)
	current_scene = stage
	for index: int in range(TARGET_ARCHETYPES.size()):
		var archetype: StringName = TARGET_ARCHETYPES[index]
		var enemy := EnemyFactory.spawn(
			stage,
			archetype,
			Vector3(float(index) * 3.0, 0.0, 0.0),
			null,
			{"ai_enabled": false}
		)
		await process_frame
		_assert_equipment(enemy, archetype)

	var guardian := EnemyFactory.spawn(stage, &"guardian", Vector3(12.0, 0.0, 0.0), null, {"ai_enabled": false})
	await process_frame
	assert(guardian.shield_root.find_child("SM_Aspis_Shield", true, false) == null, "Non-phalanx guardian received the imported phalanx shield")
	print("[PHALANX EQUIPMENT PROBE] PASS — spearman, standard and veteran use imported dory + aspis")
	quit(0)

func _assert_equipment(enemy: HopliteAthenianEnemy, archetype: StringName) -> void:
	assert(enemy != null, "%s could not spawn" % archetype)
	assert(enemy.weapon_kind == &"spear" and enemy.shield_enabled, "%s profile is not spear-and-shield" % archetype)
	assert(enemy.sword_attachment != null and enemy.sword_attachment.bone_name == enemy.right_hand_bone, "%s dory is not attached to the right hand" % archetype)
	assert(enemy.shield_attachment != null and enemy.shield_attachment.bone_name == enemy.left_hand_bone, "%s aspis is not attached to the left hand" % archetype)
	var spear_mesh := enemy.sword_root.find_child("SM_Dory_Spear", true, false) as MeshInstance3D
	var shield_mesh := enemy.shield_root.find_child("SM_Aspis_Shield", true, false) as MeshInstance3D
	assert(spear_mesh != null, "%s does not use dory_spear.glb" % archetype)
	assert(shield_mesh != null, "%s does not use aspis_shield.glb" % archetype)
	var spear_bounds: AABB = spear_mesh.get_aabb()
	var shield_bounds: AABB = shield_mesh.get_aabb()
	assert(spear_bounds.position.y < -0.88 and spear_bounds.end.y > 1.78, "%s dory scale/origin is invalid: %s" % [archetype, spear_bounds])
	assert(shield_bounds.size.x > 0.90 and shield_bounds.size.y > 0.90, "%s aspis scale is invalid: %s" % [archetype, shield_bounds])
	assert(enemy.shield_hitbox != null and enemy.shield_hitbox.get_parent() == enemy.shield_root, "%s aspis lost its physical guard hitbox" % archetype)
