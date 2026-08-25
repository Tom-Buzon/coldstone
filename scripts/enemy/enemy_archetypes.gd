extends Resource
class_name HopliteEnemyArchetypes

# Data-only enemy archetypes. The controller/anatomy/dismemberment code stays
# shared; profiles only change presentation, equipment, combat spacing and stats.

const ROSTER_IDS: Array[StringName] = [
	&"nathenian1",
	&"nsbire1",
	&"nsbire2",
	&"nathenian2",
	&"nathenian2_soldier",
	&"bronze_colossus",
	&"ncenturion",
	&"ngeneral",
	&"ngeneral_veteran",
	&"giant_novice",
	&"giant_standard",
	&"giant_veteran",
	&"nfull_armor"
]

const GIANT_IDS: Array[StringName] = [
	&"giant_novice",
	&"giant_standard",
	&"giant_veteran"
]

static func profile(archetype: StringName) -> Dictionary:
	var profiles: Dictionary = _profiles()
	# Narrative battles also use Nathenian2 as a dispersed heavy infantryman.
	# It deliberately shares the model/equipment while losing every miniboss flag,
	# phase and health budget from the named line-breaker version.
	var key: StringName = &"nathenian2" if archetype == &"nathenian2_soldier" else (archetype if profiles.has(archetype) else &"swordsman")
	var result: Dictionary = profiles[key]
	result = result.duplicate(true)
	if archetype == &"nathenian2_soldier":
		result["display_name"] = "FANTASSIN LOURD ATHENIEN"
		result["role"] = &"heavy_infantry"
		result["rank"] = &"troop"
		result["scale"] = 1.06
		result["health"] = 185.0
		result["attack_damage"] = 21.0
		result["move_speed"] = 4.05
		result["poise"] = 0.34
		result["phase_two_pattern"] = []
		result["phase_threshold"] = 0.0
		result["procedural_cost"] = 2.15
	# Equipment and mechanics must never silently disagree. Older profiles only
	# declared the shield mesh, so normalize them into the same guard contract as
	# the replacement roster while keeping profile-specific overrides intact.
	if bool(result.get("shield", false)) and not result.has("defense"):
		result["defense"] = &"shield"
		result["defense_chance"] = 0.30
		result["defense_duration"] = 0.68
		result["defense_cooldown"] = 1.55
		result["defense_damage_multiplier"] = 0.20
		result["defense_sever_multiplier"] = 0.12
	if StringName(result.get("defense", &"none")) == &"shield":
		result["guard_max"] = float(result.get("guard_max", 78.0))
		result["guard_regen"] = float(result.get("guard_regen", 18.0))
		result["guard_regen_delay"] = float(result.get("guard_regen_delay", 1.30))
		result["defense_reaction_delay"] = float(result.get("defense_reaction_delay", 0.13))
		result["defense_reaction_range"] = float(result.get("defense_reaction_range", 3.60))
	return result

static func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = [&"swordsman", &"guardian", &"spearman", &"flanker", &"brute", &"captain", &"warlord", &"boss_colossus", &"boss_bronze"]
	ids.append_array(ROSTER_IDS)
	return ids

static func roster_ids() -> Array[StringName]:
	return ROSTER_IDS.duplicate()

static func giant_ids() -> Array[StringName]:
	return GIANT_IDS.duplicate()

static func is_giant(archetype: StringName) -> bool:
	return GIANT_IDS.has(archetype)

static func package_path(archetype: StringName) -> String:
	var candidates: Array = profile(archetype).get("package_candidates", [])
	for candidate: Variant in candidates:
		var path := String(candidate)
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	# 3D generators commonly append a timestamp (`Nsbire2-1787....glb`). Scan
	# only this small asset folder and accept that suffix without requiring a
	# profile/code edit for every export.
	var directory := "res://assets/characters/3dgen_demo"
	var normalized_id := String(archetype).to_lower().replace("_", "").replace("-", "")
	var files := DirAccess.get_files_at(directory)
	files.sort()
	for file_name: String in files:
		if file_name.get_extension().to_lower() != "glb":
			continue
		var normalized_file := file_name.get_basename().to_lower().replace("_", "").replace("-", "")
		if normalized_file.begins_with(normalized_id):
			return "%s/%s" % [directory, file_name]
	return ""

static func rank(archetype: StringName) -> StringName:
	return StringName(profile(archetype).get("rank", &"troop"))

static func is_miniboss(archetype: StringName) -> bool:
	return rank(archetype) == &"miniboss"

static func is_boss(archetype: StringName) -> bool:
	return rank(archetype) == &"boss"

static func procedural_catalog(max_cost: float = INF, wave: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for archetype: StringName in ROSTER_IDS:
		var data := profile(archetype)
		var cost := float(data.get("procedural_cost", 1.0))
		var first_wave := int(data.get("first_wave", 0))
		if cost <= max_cost and first_wave <= wave:
			result.append({
				"id": archetype,
				"rank": StringName(data.get("rank", &"troop")),
				"cost": cost,
				"weight": float(data.get("procedural_weight", 1.0)),
				"package_path": package_path(archetype)
			})
	return result

static func _profiles() -> Dictionary:
	return {
		&"swordsman": {
			"display_name": "SWORDSMAN",
			"color": Color(0.025, 0.18, 0.72),
			"skin": &"swordsman",
			"scale": 1.00,
			"health": 105.0,
			"move_speed": 4.9,
			"attack_damage": 14.0,
			"attack_range": 1.72,
			"aggro_distance": 20.0,
			"weapon": &"sword",
			"weapon_scale": 1.0,
			"shield": true,
			"shield_scale": 1.0,
			"behavior": &"aggressive",
			"attack_style": &"light_mix",
			"windup": 0.24,
			"recovery": 0.25,
			"cooldown_min": 0.86,
			"cooldown_max": 1.12,
			"attack_anim_speed": 1.16,
			"preferred_min": 0.0,
			"preferred_max": 1.65,
			"flank_distance": 0.0
		},
		&"guardian": {
			"display_name": "GUARDIAN",
			"color": Color(0.025, 0.18, 0.72),
			"skin": &"guardian",
			"scale": 1.05,
			"health": 160.0,
			"move_speed": 4.0,
			"attack_damage": 16.0,
			"attack_range": 1.78,
			"aggro_distance": 19.0,
			"weapon": &"axe",
			"weapon_scale": 1.0,
			"shield": true,
			"shield_scale": 1.18,
			"behavior": &"guardian",
			"attack_style": &"light_mix",
			"windup": 0.30,
			"recovery": 0.34,
			"cooldown_min": 1.00,
			"cooldown_max": 1.30,
			"attack_anim_speed": 1.04,
			"preferred_min": 0.0,
			"preferred_max": 1.72,
			"flank_distance": 0.0
		},
		&"spearman": {
			"display_name": "SPEARMAN",
			"color": Color(0.025, 0.18, 0.72),
			"skin": &"spearman",
			"scale": 1.03,
			"health": 115.0,
			"move_speed": 4.25,
			"attack_damage": 19.0,
			"attack_range": 2.62,
			"aggro_distance": 22.0,
			"weapon": &"spear",
			"weapon_scale": 1.0,
			"shield": true,
			"shield_scale": 0.92,
			"behavior": &"reach",
			"attack_style": &"poke",
			"windup": 0.31,
			"recovery": 0.32,
			"cooldown_min": 1.04,
			"cooldown_max": 1.34,
			"attack_anim_speed": 1.08,
			"preferred_min": 1.55,
			"preferred_max": 2.42,
			"flank_distance": 0.0
		},
		&"flanker": {
			"display_name": "FLANKER",
			"color": Color(0.025, 0.18, 0.72),
			"skin": &"flanker",
			"scale": 0.96,
			"health": 80.0,
			"move_speed": 6.15,
			"attack_damage": 12.0,
			"attack_range": 1.58,
			"aggro_distance": 23.0,
			"weapon": &"sword",
			"weapon_scale": 0.88,
			"shield": false,
			"shield_scale": 1.0,
			"behavior": &"flank",
			"attack_style": &"fast",
			"windup": 0.18,
			"recovery": 0.18,
			"cooldown_min": 0.66,
			"cooldown_max": 0.90,
			"attack_anim_speed": 1.36,
			"preferred_min": 0.0,
			"preferred_max": 1.48,
			"flank_distance": 2.25
		},
		&"brute": {
			"display_name": "BRUTE",
			"color": Color(0.025, 0.18, 0.72),
			"skin": &"brute",
			"scale": 1.12,
			"health": 310.0,
			"move_speed": 3.65,
			"attack_damage": 29.0,
			"attack_range": 1.96,
			"aggro_distance": 19.0,
			"weapon": &"axe",
			"weapon_scale": 1.20,
			"shield": false,
			"shield_scale": 1.0,
			"behavior": &"brute",
			"attack_style": &"heavy",
			"windup": 0.44,
			"recovery": 0.48,
			"cooldown_min": 1.38,
			"cooldown_max": 1.72,
			"attack_anim_speed": 0.92,
			"preferred_min": 0.0,
			"preferred_max": 1.86,
			"flank_distance": 0.0
		},
		&"captain": {
			"display_name": "CAPTAIN",
			"rank": &"miniboss",
			"color": Color(0.90, 0.62, 0.035),
			"skin": &"captain",
			"scale": 1.20,
			"health": 460.0,
			"move_speed": 5.25,
			"attack_damage": 34.0,
			"attack_range": 2.28,
			"aggro_distance": 23.0,
			"weapon": &"sword",
			"weapon_scale": 1.18,
			"shield": true,
			"shield_scale": 1.16,
			"behavior": &"boss",
			"attack_style": &"captain",
			"windup": 0.40,
			"recovery": 0.40,
			"cooldown_min": 1.18,
			"cooldown_max": 1.48,
			"attack_anim_speed": 1.00,
			"preferred_min": 0.0,
			"preferred_max": 2.10,
			"flank_distance": 0.0,
			"combat_pattern": [
				{"id": &"shield_bash", "slot": &"light1", "mixamo": &"axe_kick", "external": &"light1", "windup": 0.28, "recovery": 0.24, "cooldown": 0.52, "damage_mult": 0.72, "range_mult": 0.92, "lunge_speed": 4.8},
				{"id": &"cross_cut", "slot": &"light2", "mixamo": &"axe_horizontal", "external": &"light2", "windup": 0.30, "recovery": 0.28, "cooldown": 0.68, "damage_mult": 1.00},
				{"id": &"command_heavy", "slot": &"heavy", "mixamo": &"axe_down", "external": &"heavy_release", "windup": 0.52, "recovery": 0.46, "cooldown": 1.10, "damage_mult": 1.32, "range_mult": 1.08}
			],
			"external_animation_keys": [&"light1", &"light2", &"heavy_release", &"block_idle", &"block_impact"]
		},
		&"warlord": {
			"display_name": "WARLORD",
			"rank": &"boss",
			"color": Color(0.58, 0.045, 0.018),
			"skin": &"warlord",
			"scale": 1.34,
			"health": 980.0,
			"move_speed": 4.85,
			"attack_damage": 46.0,
			"attack_range": 2.48,
			"aggro_distance": 28.0,
			"weapon": &"axe",
			"weapon_scale": 1.34,
			"shield": true,
			"shield_scale": 1.28,
			"behavior": &"boss",
			"attack_style": &"captain",
			"windup": 0.34,
			"recovery": 0.36,
			"cooldown_min": 0.96,
			"cooldown_max": 1.24,
			"attack_anim_speed": 1.10,
			"preferred_min": 0.0,
			"preferred_max": 2.30,
			"flank_distance": 0.0,
			"combat_pattern": [
				{"id": &"war_sweep", "slot": &"spin360", "mixamo": &"mutant_swipe", "external": &"mutant_swipe", "windup": 0.40, "recovery": 0.42, "cooldown": 0.82, "damage_mult": 1.02, "range_mult": 1.16, "arc_dot": -0.25},
				{"id": &"execution", "slot": &"heavy", "mixamo": &"axe_down", "external": &"axe_down", "windup": 0.58, "recovery": 0.54, "cooldown": 1.18, "damage_mult": 1.46, "range_mult": 1.10},
				{"id": &"shield_rush", "slot": &"light3", "mixamo": &"axe_combo", "external": &"axe_combo", "windup": 0.34, "recovery": 0.30, "cooldown": 0.72, "damage_mult": 0.92, "lunge_speed": 6.4}
			],
			"phase_two_pattern": [
				{"id": &"rage_sweep", "slot": &"spin360", "mixamo": &"mutant_swipe", "external": &"mutant_swipe", "windup": 0.30, "recovery": 0.32, "cooldown": 0.52, "damage_mult": 1.12, "range_mult": 1.22, "arc_dot": -0.45},
				{"id": &"rage_combo", "slot": &"heavy", "mixamo": &"axe_combo", "external": &"axe_combo", "windup": 0.36, "recovery": 0.34, "cooldown": 0.58, "damage_mult": 1.26, "lunge_speed": 5.6}
			],
			"phase_threshold": 0.55,
			"phase_speed_multiplier": 1.12,
			"phase_damage_multiplier": 1.18,
			"external_animation_keys": [&"mutant_swipe", &"axe_down", &"axe_combo", &"block_idle", &"block_impact"]
		},
		&"boss_colossus": {
			"display_name": "COLOSSUS",
			"rank": &"miniboss",
			"color": Color(0.28, 0.30, 0.32),
			"skin": &"warlord",
			"scale": 1.20,
			"health": 720.0,
			"move_speed": 3.85,
			"attack_damage": 44.0,
			"attack_range": 2.12,
			"aggro_distance": 24.0,
			"weapon": &"hammer",
			"weapon_scale": 1.24,
			"shield": false,
			"shield_scale": 1.0,
			"behavior": &"brute",
			"attack_style": &"heavy",
			"windup": 0.48,
			"recovery": 0.52,
			"cooldown_min": 1.32,
			"cooldown_max": 1.66,
			"attack_anim_speed": 0.90,
			"preferred_min": 0.0,
			"preferred_max": 2.02,
			"flank_distance": 0.0,
			"combat_pattern": [
				{"id": &"colossus_crush", "slot": &"heavy", "mixamo": &"axe_down", "external": &"axe_down", "windup": 0.66, "recovery": 0.62, "cooldown": 1.22, "damage_mult": 1.42, "range_mult": 1.10},
				{"id": &"colossus_quake", "slot": &"heavy", "mixamo": &"mutant_punch", "external": &"mutant_punch", "special": &"shockwave", "radius": 3.4, "windup": 0.82, "recovery": 0.72, "cooldown": 1.55, "damage_mult": 0.78}
			],
			"external_animation_keys": [&"axe_down", &"mutant_punch"]
		},
		&"boss_bronze": {
			"display_name": "BRONZE BOSS",
			"rank": &"miniboss",
			"color": Color(0.70, 0.38, 0.08),
			"skin": &"captain",
			"scale": 1.20,
			"health": 640.0,
			"move_speed": 4.45,
			"attack_damage": 38.0,
			"attack_range": 2.92,
			"aggro_distance": 25.0,
			"weapon": &"spear",
			"weapon_scale": 1.12,
			"shield": false,
			"shield_scale": 1.0,
			"behavior": &"reach",
			"attack_style": &"poke",
			"windup": 0.36,
			"recovery": 0.38,
			"cooldown_min": 1.06,
			"cooldown_max": 1.36,
			"attack_anim_speed": 1.04,
			"preferred_min": 1.65,
			"preferred_max": 2.68,
			"flank_distance": 0.0,
			"combat_pattern": [
				{"id": &"bronze_thrust", "slot": &"light2", "mixamo": &"vertical_sword", "external": &"vertical_sword", "windup": 0.34, "recovery": 0.30, "cooldown": 0.66, "damage_mult": 1.04, "range_mult": 1.10, "lunge_speed": 4.5},
				{"id": &"bronze_sweep", "slot": &"spin360", "mixamo": &"sword_slash", "external": &"sword_slash", "windup": 0.48, "recovery": 0.44, "cooldown": 0.94, "damage_mult": 1.18, "range_mult": 1.12, "arc_dot": -0.10}
			],
			"external_animation_keys": [&"vertical_sword", &"sword_slash"]
		},
		# Replacement roster. Eight source packages expose nine gameplay roles:
		# the NGeneral package is deliberately shared by both hoplite tiers.
		&"nathenian1": {
			"display_name": "NATHENIAN I",
			"role": &"light_shield_infantry",
			"rank": &"troop",
			"color": Color(0.08, 0.22, 0.63),
			"skin": &"guardian",
			"scale": 1.00,
			"health": 128.0,
			"move_speed": 4.65,
			"attack_damage": 15.0,
			"attack_range": 1.75,
			"aggro_distance": 21.0,
			"weapon": &"sword",
			"weapon_scale": 0.98,
			"shield": true,
			"shield_scale": 1.00,
			"behavior": &"guardian",
			"attack_style": &"disciplined",
			"windup": 0.28,
			"recovery": 0.31,
			"cooldown_min": 0.92,
			"cooldown_max": 1.20,
			"attack_anim_speed": 1.10,
			"preferred_min": 0.0,
			"preferred_max": 1.68,
			"flank_distance": 0.0,
			"tactical_radius": 1.85,
			"separation_weight": 1.35,
			"approach_speed_multiplier": 0.80,
			"defense": &"shield",
			"defense_chance": 0.34,
			"defense_duration": 0.70,
			"defense_cooldown": 1.55,
			"defense_damage_multiplier": 0.18,
			"defense_sever_multiplier": 0.12,
			"guard_max": 86.0,
			"guard_regen": 21.0,
			"defense_reaction_delay": 0.14,
			"poise": 0.12,
			"signature_source": &"ual2",
			"signature_animations": [&"Shield_OneShot", &"Sword_Regular_A"],
			"signature_chance": 0.28,
			"procedural_cost": 1.35,
			"procedural_weight": 1.00,
			"first_wave": 0,
			"package_candidates": [
				"res://assets/characters/3dgen_demo/nathenian1-1787346222233.glb",
				"res://assets/characters/3dgen_demo/Nathenian1.glb",
                "res://assets/characters/3dgen_demo/nathenian1.glb"
			]
		},
		&"ngeneral": {
			"display_name": "LANCIER HOPLITE",
			"role": &"phalanx_core",
			"rank": &"troop",
			"color": Color(0.08, 0.22, 0.63),
			"skin": &"spearman",
			"scale": 1.00,
			"health": 145.0,
			"move_speed": 3.70,
			"attack_damage": 18.0,
			"attack_range": 2.72,
			"aggro_distance": 22.0,
			"weapon": &"spear",
			"weapon_scale": 1.10,
			"shield": true,
			"shield_scale": 1.12,
			"behavior": &"phalanx",
			"attack_style": &"spear_compact",
			"windup": 0.32,
			"recovery": 0.34,
			"cooldown_min": 1.05,
			"cooldown_max": 1.38,
			"attack_anim_speed": 1.18,
			"preferred_min": 1.58,
			"preferred_max": 2.58,
			"flank_distance": 0.0,
			"tactical_radius": 2.42,
			"separation_weight": 0.34,
			"approach_speed_multiplier": 0.66,
			"formation_columns": 5,
			"formation_spacing": 1.08,
			"formation_rank_spacing": 1.18,
			"formation_pursuit_limit": 7.5,
			"formation_turn_speed": deg_to_rad(28.0),
			"formation_role": &"line",
			"cohesion_radius": 4.4,
			"cohesion_guard_bonus": 0.12,
			"defense": &"shield",
			"defense_chance": 0.62,
			"defense_duration": 0.82,
			"defense_cooldown": 1.30,
			"defense_damage_multiplier": 0.14,
			"defense_sever_multiplier": 0.08,
			"guard_max": 112.0,
			"guard_regen": 24.0,
			"defense_reaction_delay": 0.09,
			"poise": 0.28,
			"signature_source": &"none",
			"signature_animations": [],
			"signature_chance": 0.0,
			"combat_pattern": [
				{"id": &"hoplite_torso_thrust", "slot": &"light2", "external": &"spear_thrust", "windup": 0.30, "recovery": 0.30, "cooldown": 0.82, "damage_mult": 1.00, "range_mult": 1.00, "full_body": false, "hips": 0.16, "start_fraction": 0.12},
				{"id": &"hoplite_high_thrust", "slot": &"light2", "external": &"spear_thrust", "windup": 0.38, "recovery": 0.32, "cooldown": 0.94, "damage_mult": 1.08, "range_mult": 1.04, "aim_pitch": 0.12, "full_body": false, "hips": 0.14, "start_fraction": 0.04},
				{"id": &"hoplite_low_thrust", "slot": &"light1", "external": &"spear_thrust_low", "windup": 0.28, "recovery": 0.34, "cooldown": 0.90, "damage_mult": 0.92, "range_mult": 0.98, "aim_pitch": -0.18, "full_body": false, "hips": 0.12, "start_fraction": 0.18},
				{"id": &"hoplite_shield_push", "slot": &"light1", "external": &"shield_bash", "windup": 0.26, "recovery": 0.38, "cooldown": 1.18, "damage_mult": 0.55, "range_mult": 0.72, "lunge_speed": 2.6, "full_body": false, "hips": 0.20}
			],
			"external_animation_keys": [&"spear_thrust", &"spear_thrust_low", &"shield_bash", &"block_idle", &"block_impact"],
			"procedural_cost": 1.55,
			"procedural_weight": 1.15,
			"first_wave": 0,
			"package_candidates": [
				"res://assets/characters/3dgen_demo/ngeneral-1787351044165.glb",
				"res://assets/characters/3dgen_demo/NGeneral.glb",
                "res://assets/characters/3dgen_demo/ngeneral.glb"
			]
		},
		&"nsbire1": {
			"display_name": "LEVEE CIVIQUE",
			"role": &"levy_harasser",
			"rank": &"troop",
			"color": Color(0.38, 0.24, 0.12),
			"skin": &"swordsman",
			"scale": 0.97,
			"health": 82.0,
			"move_speed": 4.80,
			"attack_damage": 13.0,
			"attack_range": 1.92,
			"aggro_distance": 18.0,
			"weapon": &"farm_tool",
			"weapon_scale": 1.00,
			"shield": false,
			"shield_scale": 1.0,
			"behavior": &"coward",
			"attack_style": &"harvest",
			"windup": 0.35,
			"recovery": 0.40,
			"cooldown_min": 1.18,
			"cooldown_max": 1.58,
			"attack_anim_speed": 1.02,
			"preferred_min": 1.10,
			"preferred_max": 1.80,
			"flank_distance": 0.0,
			"tactical_radius": 1.92,
			"separation_weight": 1.60,
			"approach_speed_multiplier": 0.88,
			"defense": &"none",
			"poise": 0.02,
			"signature_source": &"ual2",
			"signature_animations": [&"Farm_Harvest", &"TreeChopping"],
			"signature_chance": 0.72,
			"procedural_cost": 0.70,
			"procedural_weight": 1.30,
			"first_wave": 0,
			"package_candidates": [
				"res://assets/characters/3dgen_demo/Nsbire1.glb",
                "res://assets/characters/3dgen_demo/nsbire1.glb"
			]
		},
		&"nsbire2": {
			"display_name": "ARCHER LEGER",
			"role": &"archer_support",
			"rank": &"troop",
			"color": Color(0.34, 0.29, 0.16),
			"skin": &"flanker",
			"scale": 0.98,
			"health": 48.0,
			"move_speed": 4.55,
			"attack_damage": 12.0,
			"attack_range": 18.0,
			"aggro_distance": 26.0,
			"weapon": &"bow",
			"weapon_scale": 1.0,
			"shield": false,
			"shield_scale": 1.0,
			"behavior": &"ranged",
			"attack_style": &"archer",
			"attack_delivery": &"projectile",
			"projectile_kind": &"arrow",
			"projectile_speed": 22.0,
			"projectile_gravity": 5.2,
			"projectile_spread": 0.022,
			"windup": 0.58,
			"recovery": 0.32,
			"cooldown_min": 1.35,
			"cooldown_max": 1.85,
			"attack_anim_speed": 1.08,
			"preferred_min": 3.65,
			"preferred_max": 13.5,
			"flank_distance": 0.0,
			"tactical_radius": 9.75,
			"separation_weight": 1.45,
			"approach_speed_multiplier": 0.96,
			"height_preference": 1.0,
			"ranged_retreat_delay": 0.82,
			"defense": &"dodge",
			"defense_chance": 0.10,
			"defense_cooldown": 1.65,
			"poise": 0.02,
			"signature_source": &"none",
			"signature_animations": [],
			"signature_chance": 0.0,
			"combat_pattern": [
				{"id": &"archer_draw_release", "slot": &"light2", "external": &"bow_aim", "delivery": &"projectile", "windup": 0.68, "recovery": 0.34, "cooldown": 1.42, "damage_mult": 1.0, "full_body": false, "hips": 0.10, "start_fraction": 0.08}
			],
			"external_animation_keys": [&"bow_aim"],
			"procedural_cost": 1.10,
			"procedural_weight": 0.72,
			"first_wave": 1,
			"package_candidates": [
				"res://assets/characters/3dgen_demo/Nsbire2.glb",
                "res://assets/characters/3dgen_demo/nsbire2.glb"
			]
		},
		&"nathenian2": {
			"display_name": "BRISEUR DE LIGNE",
			"role": &"line_breaker",
			"rank": &"miniboss",
			"color": Color(0.12, 0.20, 0.52),
			"skin": &"brute",
			"scale": 1.18,
			"health": 430.0,
			"move_speed": 3.85,
			"attack_damage": 34.0,
			"attack_range": 2.10,
			"aggro_distance": 22.0,
			"weapon": &"hammer",
			"weapon_scale": 1.16,
			"shield": false,
			"shield_scale": 1.0,
			"behavior": &"brute",
			"attack_style": &"heavy",
			"windup": 0.48,
			"recovery": 0.52,
			"cooldown_min": 1.30,
			"cooldown_max": 1.68,
			"attack_anim_speed": 0.94,
			"preferred_min": 0.0,
			"preferred_max": 1.96,
			"flank_distance": 0.0,
			"tactical_radius": 2.02,
			"separation_weight": 0.62,
			"approach_speed_multiplier": 0.86,
			"defense": &"armor",
			"armor_damage_multiplier": 0.84,
			"armor_sever_multiplier": 0.70,
			"poise": 0.58,
			"signature_source": &"ual2",
			"signature_animations": [&"TreeChopping", &"Sword_Regular_Combo"],
			"signature_chance": 0.68,
			"combat_pattern": [
				{"id": &"hammer_overhead", "slot": &"heavy", "external": &"axe_down", "windup": 0.62, "recovery": 0.58, "cooldown": 1.08, "damage_mult": 1.34, "range_mult": 1.08},
				{"id": &"hammer_shove", "slot": &"light1", "external": &"mutant_punch", "windup": 0.34, "recovery": 0.30, "cooldown": 0.62, "damage_mult": 0.72, "range_mult": 0.86, "lunge_speed": 4.2},
				{"id": &"hammer_sweep", "slot": &"spin360", "external": &"mutant_swipe", "windup": 0.50, "recovery": 0.50, "cooldown": 0.98, "damage_mult": 1.02, "range_mult": 1.18, "arc_dot": -0.24}
			],
			"phase_two_pattern": [
				{"id": &"hammer_quake", "slot": &"heavy", "external": &"axe_down", "special": &"shockwave", "radius": 3.25, "windup": 0.72, "recovery": 0.64, "cooldown": 1.16, "damage_mult": 0.86},
				{"id": &"hammer_rush", "slot": &"heavy", "external": &"axe_combo", "windup": 0.42, "recovery": 0.42, "cooldown": 0.74, "damage_mult": 1.18, "lunge_speed": 5.8}
			],
			"phase_threshold": 0.48,
			"phase_speed_multiplier": 1.10,
			"phase_damage_multiplier": 1.14,
			"external_animation_keys": [&"axe_down", &"mutant_punch", &"mutant_swipe", &"axe_combo"],
			"procedural_cost": 4.20,
			"procedural_weight": 0.28,
			"first_wave": 3,
			"package_candidates": [
				"res://assets/characters/3dgen_demo/nathenian2-1787346736278.glb",
				"res://assets/characters/3dgen_demo/Nathenian2.glb",
                "res://assets/characters/3dgen_demo/nathenian2.glb"
			]
		},
		&"bronze_colossus": {
			"display_name": "BRONZE COLOSSUS",
			"role": &"siege_juggernaut",
			"rank": &"miniboss",
			"color": Color(0.31, 0.27, 0.21),
			"skin": &"warlord",
			"scale": 1.22,
			"health": 780.0,
			"move_speed": 3.45,
			"attack_damage": 46.0,
			"attack_range": 2.20,
			"aggro_distance": 25.0,
			"weapon": &"hammer",
			"weapon_scale": 1.28,
			"shield": false,
			"shield_scale": 1.0,
			"behavior": &"juggernaut",
			"attack_style": &"heavy",
			"windup": 0.54,
			"recovery": 0.58,
			"cooldown_min": 1.44,
			"cooldown_max": 1.82,
			"attack_anim_speed": 0.88,
			"preferred_min": 0.0,
			"preferred_max": 2.04,
			"flank_distance": 0.0,
			"tactical_radius": 2.18,
			"separation_weight": 0.30,
			"approach_speed_multiplier": 0.72,
			"defense": &"armor",
			"armor_damage_multiplier": 0.70,
			"armor_sever_multiplier": 0.46,
			"poise": 0.82,
			"signature_source": &"ual2",
			"signature_animations": [&"TreeChopping", &"Sword_Regular_Combo"],
			"signature_chance": 0.72,
			"combat_pattern": [
				{"id": &"colossus_roar", "slot": &"heavy", "external": &"mutant_roar", "special": &"telegraph", "windup": 0.92, "recovery": 0.22, "cooldown": 0.34, "damage_mult": 0.0},
				{"id": &"colossus_charge", "slot": &"heavy", "external": &"axe_combo", "windup": 0.62, "recovery": 0.62, "cooldown": 1.08, "damage_mult": 1.26, "range_mult": 1.12, "lunge_speed": 6.2},
				{"id": &"colossus_quake", "slot": &"heavy", "external": &"axe_down", "special": &"shockwave", "radius": 3.8, "windup": 0.88, "recovery": 0.78, "cooldown": 1.42, "damage_mult": 0.88},
				{"id": &"colossus_sweep", "slot": &"spin360", "external": &"mutant_swipe", "windup": 0.58, "recovery": 0.60, "cooldown": 1.10, "damage_mult": 1.08, "range_mult": 1.22, "arc_dot": -0.42}
			],
			"phase_two_pattern": [
				{"id": &"colossus_double_quake", "slot": &"heavy", "external": &"axe_down", "special": &"shockwave", "radius": 4.4, "windup": 0.72, "recovery": 0.46, "cooldown": 0.70, "damage_mult": 0.94},
				{"id": &"colossus_frenzy", "slot": &"spin360", "external": &"mutant_swipe", "windup": 0.42, "recovery": 0.44, "cooldown": 0.72, "damage_mult": 1.18, "range_mult": 1.28, "arc_dot": -0.55}
			],
			"phase_threshold": 0.52,
			"phase_speed_multiplier": 1.08,
			"phase_damage_multiplier": 1.16,
			"external_animation_keys": [&"mutant_roar", &"axe_combo", &"axe_down", &"mutant_swipe"],
			"procedural_cost": 6.50,
			"procedural_weight": 0.18,
			"first_wave": 5,
			"package_candidates": [
				"res://assets/characters/3dgen_demo/bronzeColossus.glb",
				"res://assets/characters/3dgen_demo/BronzeColossus.glb",
                "res://assets/characters/3dgen_demo/bosscolossus.glb"
			]
		},
		&"ncenturion": {
			"display_name": "TAXIARQUE",
			"role": &"formation_commander",
			"rank": &"miniboss",
			"color": Color(0.48, 0.10, 0.06),
			"skin": &"captain",
			"scale": 1.18,
			"health": 570.0,
			"move_speed": 4.50,
			"attack_damage": 31.0,
			"attack_range": 1.92,
			"aggro_distance": 25.0,
			"weapon": &"gladius",
			"weapon_scale": 1.08,
			"shield": true,
			"shield_scale": 1.14,
			"behavior": &"commander",
			"attack_style": &"disciplined",
			"windup": 0.30,
			"recovery": 0.34,
			"cooldown_min": 0.92,
			"cooldown_max": 1.20,
			"attack_anim_speed": 1.14,
			"preferred_min": 0.0,
			"preferred_max": 1.82,
			"flank_distance": 0.0,
			"tactical_radius": 2.05,
			"separation_weight": 1.20,
			"approach_speed_multiplier": 0.82,
			"defense": &"shield",
			"defense_chance": 0.50,
			"defense_duration": 0.82,
			"defense_cooldown": 1.25,
			"defense_damage_multiplier": 0.12,
			"defense_sever_multiplier": 0.08,
			"guard_max": 158.0,
			"guard_regen": 27.0,
			"guard_regen_delay": 1.55,
			"defense_reaction_delay": 0.085,
			"poise": 0.48,
			"signature_source": &"ual2",
			"signature_animations": [&"Shield_OneShot", &"Sword_Regular_Combo"],
			"signature_chance": 0.45,
			"combat_pattern": [
				{"id": &"centurion_probe", "slot": &"light1", "external": &"light1", "windup": 0.24, "recovery": 0.22, "cooldown": 0.54, "damage_mult": 0.82, "range_mult": 0.94},
				{"id": &"centurion_bash", "slot": &"light2", "external": &"dash_attack", "windup": 0.32, "recovery": 0.34, "cooldown": 0.72, "damage_mult": 0.76, "lunge_speed": 5.6},
				{"id": &"centurion_combo", "slot": &"heavy", "external": &"heavy_release", "windup": 0.46, "recovery": 0.44, "cooldown": 1.02, "damage_mult": 1.34, "range_mult": 1.08}
			],
			"external_animation_keys": [&"light1", &"dash_attack", &"heavy_release", &"block_idle", &"block_impact"],
			"procedural_cost": 5.00,
			"procedural_weight": 0.24,
			"first_wave": 4,
			"package_candidates": [
				"res://assets/characters/3dgen_demo/Ncenturion.glb",
                "res://assets/characters/3dgen_demo/ncenturion.glb"
			]
		},
		&"ngeneral_veteran": {
			"display_name": "LANCIER VETERAN",
			"role": &"phalanx_flank_guard",
			"rank": &"elite",
			"color": Color(0.72, 0.51, 0.10),
			"skin": &"spearman",
			"scale": 1.20,
			"health": 235.0,
			"move_speed": 3.82,
			"attack_damage": 25.0,
			"attack_range": 2.90,
			"aggro_distance": 25.0,
			"weapon": &"spear",
			"weapon_scale": 1.16,
			"shield": true,
			"shield_scale": 1.18,
			"behavior": &"phalanx_veteran",
			"attack_style": &"spear_veteran",
			"windup": 0.28,
			"recovery": 0.26,
			"cooldown_min": 0.82,
			"cooldown_max": 1.12,
			"attack_anim_speed": 1.34,
			"preferred_min": 1.48,
			"preferred_max": 2.72,
			"flank_distance": 0.0,
			"tactical_radius": 2.55,
			"separation_weight": 0.28,
			"approach_speed_multiplier": 0.68,
			"formation_columns": 5,
			"formation_spacing": 1.12,
			"formation_rank_spacing": 1.22,
			"formation_pursuit_limit": 8.5,
			"formation_turn_speed": deg_to_rad(34.0),
			"formation_role": &"flank_guard",
			"cohesion_radius": 4.4,
			"cohesion_guard_bonus": 0.16,
			"defense": &"shield",
			"defense_chance": 0.78,
			"defense_duration": 0.92,
			"defense_cooldown": 1.05,
			"defense_damage_multiplier": 0.09,
			"defense_sever_multiplier": 0.05,
			"guard_max": 168.0,
			"guard_regen": 32.0,
			"guard_regen_delay": 1.05,
			"defense_reaction_delay": 0.06,
			"poise": 0.52,
			"signature_source": &"none",
			"signature_animations": [],
			"signature_chance": 0.0,
			"combat_pattern": [
				{"id": &"veteran_riposte", "slot": &"light2", "external": &"spear_thrust", "windup": 0.22, "recovery": 0.22, "cooldown": 0.62, "damage_mult": 1.08, "range_mult": 1.04, "full_body": false, "hips": 0.14, "start_fraction": 0.16},
				{"id": &"veteran_low_thrust", "slot": &"light1", "external": &"spear_thrust_low", "windup": 0.24, "recovery": 0.25, "cooldown": 0.70, "damage_mult": 1.02, "range_mult": 1.00, "aim_pitch": -0.20, "full_body": false, "hips": 0.12, "start_fraction": 0.20},
				{"id": &"veteran_delayed_thrust", "slot": &"light2", "external": &"spear_thrust", "windup": 0.52, "recovery": 0.24, "cooldown": 0.88, "damage_mult": 1.28, "range_mult": 1.08, "full_body": false, "hips": 0.16},
				{"id": &"veteran_shield_push", "slot": &"light1", "external": &"shield_bash", "windup": 0.22, "recovery": 0.30, "cooldown": 0.92, "damage_mult": 0.62, "range_mult": 0.74, "lunge_speed": 3.0, "full_body": false, "hips": 0.18}
			],
			"external_animation_keys": [&"spear_thrust", &"spear_thrust_low", &"shield_bash", &"block_idle", &"block_impact"],
			"procedural_cost": 2.80,
			"procedural_weight": 0.42,
			"first_wave": 3,
			"package_candidates": [
				"res://assets/characters/3dgen_demo/ngeneral-1787351044165.glb",
				"res://assets/characters/3dgen_demo/NGeneral.glb",
                "res://assets/characters/3dgen_demo/ngeneral.glb"
			]
		},
		# Forge-first giant family. All three tiers share the final segmented Geant1
		# model at standard gameplay scale; NGeneral remains a rig-compatible fallback.
		&"giant_novice": {
			"display_name": "GEANT — NOVICE",
			"role": &"solo_giant_novice",
			"rank": &"troop",
			"color": Color(0.38, 0.24, 0.14),
			"skin": &"brute",
			"scale": 1.00,
			"health": 280.0,
			"move_speed": 3.35,
			"attack_damage": 25.0,
			"attack_range": 2.05,
			"aggro_distance": 23.0,
			"weapon": &"unarmed",
			"weapon_scale": 1.0,
			"shield": false,
			"shield_scale": 1.0,
			"behavior": &"brute",
			"attack_style": &"giant_novice",
			"windup": 0.54,
			"recovery": 0.52,
			"cooldown_min": 1.32,
			"cooldown_max": 1.62,
			"attack_anim_speed": 0.92,
			"preferred_min": 0.0,
			"preferred_max": 1.95,
			"flank_distance": 0.0,
			"tactical_radius": 2.25,
			"separation_weight": 1.80,
			"approach_speed_multiplier": 0.82,
			"defense": &"none",
			"poise": 0.38,
			"forge_default_match_perfect_hitbox": true,
			"giant_traversal_mode": &"assisted",
			"giant_capsule_radius_multiplier": 0.90,
			"giant_capsule_height_multiplier": 1.00,
			"giant_walkable_tops": true,
			"combat_pattern": [
				{"id": &"novice_punch", "slot": &"heavy", "external": &"giant_punch", "windup": 0.58, "recovery": 0.50, "cooldown": 1.28, "damage_mult": 1.00, "range_mult": 0.96, "full_body": true, "hips": 1.0, "start_fraction": 0.02},
				{"id": &"novice_swipe", "slot": &"spin360", "external": &"giant_swipe", "windup": 0.68, "recovery": 0.62, "cooldown": 1.55, "damage_mult": 0.86, "range_mult": 1.10, "arc_dot": -0.18, "full_body": true, "hips": 1.0, "start_fraction": 0.02}
			],
			"external_animation_keys": [&"giant_punch", &"giant_swipe"],
			"procedural_cost": 4.20,
			"procedural_weight": 0.0,
			"first_wave": 99,
			"package_candidates": [
				"res://assets/characters/3dgen_demo/geant1-1787584159710.glb",
				"res://assets/characters/3dgen_demo/ngeneral-1787351044165.glb",
				"res://assets/characters/3dgen_demo/NGeneral.glb",
				"res://assets/characters/3dgen_demo/ngeneral.glb"
			]
		},
		&"giant_standard": {
			"display_name": "GEANT — STANDARD",
			"role": &"solo_giant_standard",
			"rank": &"elite",
			"color": Color(0.48, 0.27, 0.12),
			"skin": &"brute",
			"scale": 1.00,
			"health": 520.0,
			"move_speed": 3.65,
			"attack_damage": 32.0,
			"attack_range": 2.20,
			"aggro_distance": 26.0,
			"weapon": &"unarmed",
			"weapon_scale": 1.0,
			"shield": false,
			"shield_scale": 1.0,
			"behavior": &"brute",
			"attack_style": &"giant_standard",
			"windup": 0.46,
			"recovery": 0.44,
			"cooldown_min": 1.02,
			"cooldown_max": 1.34,
			"attack_anim_speed": 1.02,
			"preferred_min": 0.0,
			"preferred_max": 2.08,
			"flank_distance": 0.0,
			"tactical_radius": 2.42,
			"separation_weight": 1.95,
			"approach_speed_multiplier": 0.88,
			"defense": &"none",
			"poise": 0.56,
			"forge_default_match_perfect_hitbox": true,
			"giant_traversal_mode": &"assisted",
			"giant_capsule_radius_multiplier": 0.90,
			"giant_capsule_height_multiplier": 1.00,
			"giant_walkable_tops": true,
			"combat_pattern": [
				{"id": &"standard_punch", "slot": &"heavy", "external": &"giant_punch", "windup": 0.44, "recovery": 0.40, "cooldown": 0.92, "damage_mult": 1.02, "range_mult": 1.00, "lunge_speed": 2.8, "lunge_start": 0.62, "full_body": true, "hips": 1.0, "start_fraction": 0.02},
				{"id": &"standard_swipe", "slot": &"spin360", "external": &"giant_swipe", "windup": 0.52, "recovery": 0.48, "cooldown": 1.06, "damage_mult": 0.94, "range_mult": 1.18, "arc_dot": -0.32, "full_body": true, "hips": 1.0, "start_fraction": 0.02},
				{"id": &"standard_jump", "slot": &"air_down", "external": &"giant_jump_attack_alt", "windup": 0.72, "recovery": 0.64, "cooldown": 1.72, "damage_mult": 1.32, "range_mult": 1.16, "lunge_speed": 5.2, "lunge_start": 0.46, "full_body": true, "hips": 1.0, "start_fraction": 0.02}
			],
			"external_animation_keys": [&"giant_punch", &"giant_swipe", &"giant_jump_attack_alt"],
			"procedural_cost": 6.40,
			"procedural_weight": 0.0,
			"first_wave": 99,
			"package_candidates": [
				"res://assets/characters/3dgen_demo/geant1-1787584159710.glb",
				"res://assets/characters/3dgen_demo/ngeneral-1787351044165.glb",
				"res://assets/characters/3dgen_demo/NGeneral.glb",
				"res://assets/characters/3dgen_demo/ngeneral.glb"
			]
		},
		&"giant_veteran": {
			"display_name": "GEANT — VETERAN",
			"role": &"solo_giant_veteran",
			"rank": &"elite",
			"color": Color(0.62, 0.22, 0.08),
			"skin": &"brute",
			"scale": 1.00,
			"health": 860.0,
			"move_speed": 3.95,
			"attack_damage": 40.0,
			"attack_range": 2.38,
			"aggro_distance": 30.0,
			"weapon": &"unarmed",
			"weapon_scale": 1.0,
			"shield": false,
			"shield_scale": 1.0,
			"behavior": &"brute",
			"attack_style": &"giant_veteran",
			"windup": 0.38,
			"recovery": 0.38,
			"cooldown_min": 0.82,
			"cooldown_max": 1.12,
			"attack_anim_speed": 1.12,
			"preferred_min": 0.0,
			"preferred_max": 2.24,
			"flank_distance": 0.0,
			"tactical_radius": 2.58,
			"separation_weight": 2.10,
			"approach_speed_multiplier": 0.94,
			"defense": &"none",
			"poise": 0.72,
			"phase_threshold": 0.48,
			"phase_speed_multiplier": 1.10,
			"phase_damage_multiplier": 1.12,
			"forge_default_match_perfect_hitbox": true,
			"giant_traversal_mode": &"assisted",
			"giant_capsule_radius_multiplier": 0.90,
			"giant_capsule_height_multiplier": 1.00,
			"giant_walkable_tops": true,
			"combat_pattern": [
				{"id": &"veteran_punch", "slot": &"heavy", "external": &"giant_punch", "windup": 0.36, "recovery": 0.32, "cooldown": 0.68, "damage_mult": 1.06, "range_mult": 1.02, "lunge_speed": 3.4, "lunge_start": 0.58, "full_body": true, "hips": 1.0, "start_fraction": 0.02},
				{"id": &"veteran_swipe", "slot": &"spin360", "external": &"giant_swipe", "windup": 0.44, "recovery": 0.38, "cooldown": 0.80, "damage_mult": 1.00, "range_mult": 1.24, "arc_dot": -0.46, "full_body": true, "hips": 1.0, "start_fraction": 0.02},
				{"id": &"veteran_roar", "slot": &"idle", "external": &"giant_roar", "windup": 0.62, "recovery": 0.30, "cooldown": 1.25, "damage_mult": 0.0, "special": &"telegraph", "full_body": true, "hips": 1.0, "start_fraction": 0.02},
				{"id": &"veteran_jump_crush", "slot": &"air_down", "external": &"giant_jump_attack", "windup": 0.68, "recovery": 0.64, "cooldown": 1.52, "damage_mult": 1.34, "special": &"shockwave", "radius": 3.25, "arc_dot": -1.0, "lunge_speed": 5.8, "lunge_start": 0.42, "full_body": true, "hips": 1.0, "start_fraction": 0.02}
			],
			"phase_two_pattern": [
				{"id": &"veteran_rage_swipe", "slot": &"spin360", "external": &"giant_swipe", "windup": 0.32, "recovery": 0.30, "cooldown": 0.56, "damage_mult": 1.08, "range_mult": 1.28, "arc_dot": -0.58, "full_body": true, "hips": 1.0, "start_fraction": 0.04},
				{"id": &"veteran_rage_jump", "slot": &"air_down", "external": &"giant_jump_attack", "windup": 0.54, "recovery": 0.50, "cooldown": 1.06, "damage_mult": 1.46, "special": &"shockwave", "radius": 3.65, "arc_dot": -1.0, "lunge_speed": 6.4, "lunge_start": 0.40, "full_body": true, "hips": 1.0, "start_fraction": 0.02},
				{"id": &"veteran_flex", "slot": &"idle", "external": &"giant_flex", "windup": 0.46, "recovery": 0.24, "cooldown": 0.90, "damage_mult": 0.0, "special": &"telegraph", "full_body": true, "hips": 1.0, "start_fraction": 0.02}
			],
			"external_animation_keys": [&"giant_punch", &"giant_swipe", &"giant_roar", &"giant_jump_attack", &"giant_flex"],
			"procedural_cost": 9.20,
			"procedural_weight": 0.0,
			"first_wave": 99,
			"package_candidates": [
				"res://assets/characters/3dgen_demo/geant1-1787584159710.glb",
				"res://assets/characters/3dgen_demo/ngeneral-1787351044165.glb",
				"res://assets/characters/3dgen_demo/NGeneral.glb",
				"res://assets/characters/3dgen_demo/ngeneral.glb"
			]
		},
		&"nfull_armor": {
			"display_name": "STRATEGE CUIRASSE",
			"role": &"boss_anchor",
			"rank": &"boss",
			"color": Color(0.22, 0.24, 0.28),
			"skin": &"warlord",
			"scale": 1.28,
			"health": 2200.0,
			"move_speed": 4.45,
			"attack_damage": 52.0,
			"attack_range": 2.55,
			"aggro_distance": 32.0,
			"weapon": &"greatsword",
			"weapon_scale": 1.22,
			"shield": false,
			"shield_scale": 1.0,
			"behavior": &"phase_boss",
			"attack_style": &"boss_combo",
			"windup": 0.38,
			"recovery": 0.40,
			"cooldown_min": 0.96,
			"cooldown_max": 1.25,
			"attack_anim_speed": 1.08,
			"preferred_min": 0.0,
			"preferred_max": 2.32,
			"flank_distance": 0.0,
			"tactical_radius": 2.42,
			"separation_weight": 0.38,
			"approach_speed_multiplier": 0.80,
			"defense": &"armor",
			"armor_damage_multiplier": 0.60,
			"armor_sever_multiplier": 0.34,
			"poise": 0.88,
			"signature_source": &"ual2",
			"signature_animations": [&"Sword_Regular_Combo", &"Shield_Dash_RM", &"Sword_Dash_RM"],
			"signature_chance": 0.76,
			"combat_pattern": [
				{"id": &"iron_cleave", "slot": &"heavy", "external": &"heavy_release", "windup": 0.52, "recovery": 0.48, "cooldown": 0.90, "damage_mult": 1.18, "range_mult": 1.08},
				{"id": &"iron_sweep", "slot": &"spin360", "external": &"spin_low", "windup": 0.44, "recovery": 0.46, "cooldown": 0.86, "damage_mult": 0.96, "range_mult": 1.20, "arc_dot": -0.38},
				{"id": &"iron_leap", "slot": &"heavy", "external": &"air_down", "windup": 0.66, "recovery": 0.58, "cooldown": 1.14, "damage_mult": 1.42, "range_mult": 1.15, "lunge_speed": 7.4}
			],
			"phase_two_pattern": [
				{"id": &"iron_rush", "slot": &"light3", "external": &"dash_attack", "windup": 0.24, "recovery": 0.24, "cooldown": 0.40, "damage_mult": 0.84, "lunge_speed": 7.8},
				{"id": &"iron_storm", "slot": &"spin360", "external": &"spin_high", "windup": 0.32, "recovery": 0.35, "cooldown": 0.62, "damage_mult": 1.08, "range_mult": 1.25, "arc_dot": -0.55},
				{"id": &"iron_quake", "slot": &"heavy", "external": &"axe_down", "special": &"shockwave", "radius": 4.2, "windup": 0.72, "recovery": 0.64, "cooldown": 1.10, "damage_mult": 0.92}
			],
			"external_animation_keys": [&"heavy_release", &"spin_low", &"air_down", &"dash_attack", &"spin_high", &"axe_down"],
			"phase_threshold": 0.68,
			"phase_speed_multiplier": 1.16,
			"phase_damage_multiplier": 1.15,
			"phase_three_threshold": 0.32,
			"phase_three_speed_multiplier": 1.15,
			"phase_three_damage_multiplier": 1.18,
			"phase_three_armor_damage_multiplier": 0.78,
			"phase_three_pattern": [
				{"id": &"crown_breaker", "slot": &"light3", "external": &"dash_attack", "windup": 0.18, "recovery": 0.18, "cooldown": 0.31, "damage_mult": 0.88, "lunge_speed": 9.0},
				{"id": &"dread_storm", "slot": &"spin360", "external": &"spin_high", "windup": 0.24, "recovery": 0.28, "cooldown": 0.48, "damage_mult": 1.16, "range_mult": 1.36, "arc_dot": -0.72},
				{"id": &"throne_quake", "slot": &"heavy", "external": &"axe_down", "special": &"shockwave", "radius": 5.4, "windup": 0.56, "recovery": 0.48, "cooldown": 0.82, "damage_mult": 1.04},
				{"id": &"last_execution", "slot": &"heavy", "external": &"heavy_release", "windup": 0.34, "recovery": 0.35, "cooldown": 0.58, "damage_mult": 1.62, "range_mult": 1.16}
			],
			"procedural_cost": 12.0,
			"procedural_weight": 0.05,
			"first_wave": 9,
			"package_candidates": [
				"res://assets/characters/3dgen_demo/NFullArmor.glb",
				"res://assets/characters/3dgen_demo/nfullarmor.glb",
                "res://assets/characters/3dgen_demo/nfull_armor.glb"
			]
		}
	}
