extends SceneTree
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/animations/enemy_v2/packs")
	var hoplite := load("res://assets/animations/enemy_v2/hoplite/hoplite_v2_animation_library.res") as AnimationLibrary
	var roles := load("res://assets/animations/enemy_v2/hoplite/enemy_v2_roles.res") as AnimationLibrary
	var catalog = load("res://scripts/enemy_v2/hoplite_v2_catalog.gd")
	var spear_clips: Array[StringName] = []
	for semantic: StringName in [&"spear_thrust", &"spear_thrust_low", &"spear_bayonet_step", &"shield_bash"]:
		var clip := StringName(catalog.SEMANTIC_ANIMATIONS.get(semantic, &""))
		if not clip.is_empty() and hoplite.has_animation(clip): spear_clips.append(clip)
	var common: Array[StringName] = []
	for semantic: Variant in catalog.SEMANTIC_ANIMATIONS:
		var clip := StringName(catalog.SEMANTIC_ANIMATIONS[semantic])
		if not spear_clips.has(clip) and not common.has(clip) and hoplite.has_animation(clip): common.append(clip)
	_save(hoplite, common, "hoplite_common")
	_save(hoplite, spear_clips, "hoplite_spear")
	_save(roles, [&"sword_cut", &"sword_heavy"], "hoplite_sword")
	_save(roles, [&"bow_draw"], "hoplite_bow")
	var giant := load("res://assets/animations/enemy_v2/giant/giant_v2_animation_library.res") as AnimationLibrary
	_save(giant, [&"Idle", &"Jog_Fwd", &"Sprint", &"Death01"], "giant_common")
	_save(giant, [&"giant_punch", &"giant_swipe"], "giant_unarmed")
	_save(giant, [&"giant_jump_attack_alt"], "giant_slam")
	print("COMPOSED_ANIMATION_PACKS PASS")
	quit()
func _save(source: AnimationLibrary, names: Array[StringName], suffix: String) -> void:
	var pack := AnimationLibrary.new()
	for clip: StringName in names:
		assert(source.has_animation(clip), "Missing baked clip: %s" % clip)
		pack.add_animation(clip, source.get_animation(clip))
	assert(ResourceSaver.save(pack, "res://assets/animations/enemy_v2/packs/%s.res" % suffix) == OK)
