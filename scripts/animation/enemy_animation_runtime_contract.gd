extends RefCounted
class_name HopliteEnemyAnimationRuntimeContract

const ExternalAnimationBank = preload("res://scripts/animation/external_animation_bank.gd")
const SharedHopliteDriver = preload("res://scripts/animation/shared_hoplite_animation_driver.gd")

const UAL1_PATH := "res://assets/runtime/ual1/UAL1_Standard.glb"
const UAL2_PATH := "res://assets/runtime/ual2/UAL2_Standard.glb"
const SHARED_HOPLITE_LIBRARY_PATH := "res://assets/animations/hoplite_animation_library_v4.res"

const SHARED_DRIVER_IDS: Array[StringName] = [&"ngeneral", &"ngeneral_veteran"]
const SHARED_ACTION_KEYS: Array[StringName] = [
	&"spear_thrust", &"spear_thrust_low", &"shield_bash", &"block_idle", &"block_impact",
]

const PROVENANCE: Dictionary = {
	"shared_bake": {"label": "Bake runtime Hoplite", "color": "#8B5CF6"},
	"ual1": {"label": "UAL1", "color": "#3B82F6"},
	"ual2": {"label": "UAL2", "color": "#06B6D4"},
	"mixamo": {"label": "Mixamo", "color": "#F59E0B"},
	"custom_pack": {"label": "Pack custom", "color": "#22C55E"},
	"fallback": {"label": "Fallback runtime", "color": "#64748B"},
	"future": {"label": "Animation future", "color": "#94A3B8"},
	"unreachable": {"label": "Inatteignable", "color": "#EF4444"},
	"unknown": {"label": "Provenance inconnue", "color": "#EC4899"},
}


static func uses_shared_driver(archetype_id: StringName) -> bool:
	return SHARED_DRIVER_IDS.has(archetype_id)


static func needs_specialized_driver(profile: Dictionary) -> bool:
	return needs_specialized_driver_values(
		StringName(profile.get("rank", &"troop")),
		StringName(profile.get("behavior", &"aggressive")),
		StringName(profile.get("weapon", &"unarmed")),
		Array(profile.get("external_animation_keys", []))
	)


static func needs_specialized_driver_values(rank: StringName, behavior: StringName, weapon: StringName, external_keys: Array) -> bool:
	return (
		rank in [&"elite", &"miniboss", &"boss"]
		or behavior in [&"phalanx", &"phalanx_veteran"]
		or weapon == &"bow"
		or not external_keys.is_empty()
	)


static func driver_kind(archetype_id: StringName, profile: Dictionary) -> String:
	if uses_shared_driver(archetype_id):
		return "shared_bake"
	if needs_specialized_driver(profile):
		return "selective_retarget"
	return "lightweight_fallback"


static func provenance_for_source(path: String) -> String:
	var normalized := path.replace("\\", "/").to_lower()
	if normalized == SHARED_HOPLITE_LIBRARY_PATH.to_lower():
		return "shared_bake"
	if "/runtime/ual1/" in normalized:
		return "ual1"
	if "/runtime/ual2/" in normalized:
		return "ual2"
	if "/runtime/mixamo/" in normalized:
		return "mixamo"
	if "/animations/source_packs/" in normalized or "/animations/sources/" in normalized:
		return "custom_pack"
	return "unknown" if not path.is_empty() else "future"


static func provenance_info(provenance: String) -> Dictionary:
	return Dictionary(PROVENANCE.get(provenance, PROVENANCE["unknown"])).duplicate(true)


static func describe_core(archetype_id: StringName, profile: Dictionary, source_path: String, source_clip: String) -> Dictionary:
	var runtime_path := SHARED_HOPLITE_LIBRARY_PATH if uses_shared_driver(archetype_id) else source_path
	var runtime_clip := source_clip
	var provenance := provenance_for_source(runtime_path)
	return _descriptor({
		"runtime_reachable": true,
		"runtime_truth": "runtime_exact",
		"runtime_truth_label": "Runtime reel",
		"runtime_modes": ["detailed", "mass", "lightweight"],
		"runtime_driver": driver_kind(archetype_id, profile),
		"runtime_source_path": runtime_path,
		"runtime_source_clip": runtime_clip,
		"preview_source_path": source_path,
		"preview_source_clip": source_clip,
		"preview_fidelity": "baked_equivalent" if uses_shared_driver(archetype_id) else "exact_source",
		"provenance": provenance,
		"full_body": true,
		"hips_weight": 1.0,
		"start_fraction": 0.0,
		"weapon_family": String(profile.get("weapon", "unarmed")),
	})


static func describe_missing(profile: Dictionary) -> Dictionary:
	return _descriptor({
		"runtime_reachable": false,
		"runtime_truth": "future_missing",
		"runtime_truth_label": "Future / manquante",
		"runtime_modes": [],
		"runtime_driver": "none",
		"runtime_source_path": "",
		"runtime_source_clip": "",
		"preview_source_path": "",
		"preview_source_clip": "",
		"preview_fidelity": "unavailable",
		"provenance": "future",
		"full_body": true,
		"hips_weight": 1.0,
		"start_fraction": 0.0,
		"weapon_family": String(profile.get("weapon", "unarmed")),
		"runtime_reason": "Action declaree pour EnemyV2 mais absente du runtime actuel",
	})


static func describe_pattern(archetype_id: StringName, profile: Dictionary, step: Dictionary) -> Dictionary:
	var external_key := StringName(step.get("external", StringName()))
	var authored: Array = Array(step.get("authored", []))
	var source_path := String(ExternalAnimationBank.DONOR_PATHS.get(external_key, ""))
	var source_clip := ""
	var full_body := bool(step.get("full_body", true))
	var hips_weight := float(step.get("hips", 0.86))
	var start_fraction := float(step.get("start_fraction", 0.0))
	var reachable := false
	var runtime_path := source_path
	var runtime_clip := String(external_key)
	var provenance := provenance_for_source(source_path)
	var preview_fidelity := "exact_source" if full_body else "source_only_missing_runtime_layer"
	var truth := "runtime_exact" if full_body else "runtime_layered"
	var truth_label := "Runtime reel" if full_body else "Runtime reel - couche haut du corps"
	var reason := ""

	if uses_shared_driver(archetype_id):
		reachable = SHARED_ACTION_KEYS.has(external_key)
		runtime_path = SHARED_HOPLITE_LIBRARY_PATH
		runtime_clip = String(SharedHopliteDriver.ACTION_SOURCE_CLIPS.get(external_key, external_key))
		provenance = "shared_bake"
		preview_fidelity = "approximate_raw_donor_instead_of_shared_bake"
		truth = "runtime_layered"
		truth_label = "Runtime reel - bake partage + couche"
		reason = "Le runtime joue le bake partage Hoplite, pas le donneur Mixamo brut"
	elif external_key != StringName() and not source_path.is_empty() and needs_specialized_driver(profile):
		reachable = true
	elif not authored.is_empty() and needs_specialized_driver(profile):
		reachable = true
		runtime_path = UAL2_PATH
		runtime_clip = String(authored[0])
		provenance = "ual2"
		preview_fidelity = "exact_source" if full_body else "source_only_missing_runtime_layer"
	else:
		truth = "runtime_unreachable"
		truth_label = "Inatteignable actuellement"
		provenance = "unreachable"
		preview_fidelity = "unavailable"
		reason = "Aucun driver runtime ne peut resoudre cette etape"

	return _descriptor({
		"runtime_reachable": reachable,
		"runtime_truth": truth,
		"runtime_truth_label": truth_label,
		"runtime_modes": ["detailed"] if reachable else [],
		"runtime_driver": driver_kind(archetype_id, profile),
		"runtime_source_path": runtime_path if reachable else "",
		"runtime_source_clip": runtime_clip if reachable else "",
		"preview_source_path": source_path,
		"preview_source_clip": source_clip,
		"preview_fidelity": preview_fidelity,
		"provenance": provenance,
		"full_body": full_body,
		"hips_weight": hips_weight,
		"start_fraction": start_fraction,
		"weapon_family": String(profile.get("weapon", "unarmed")),
		"runtime_reason": reason,
	})


static func describe_signature(archetype_id: StringName, profile: Dictionary, clip_name: String) -> Dictionary:
	var source_kind := String(profile.get("signature_source", ""))
	var source_path := UAL2_PATH if source_kind == "ual2" else UAL1_PATH
	var blocked_by_pattern := _has_reachable_pattern(archetype_id, profile)
	var driver_available := needs_specialized_driver(profile) or source_kind == "ual1"
	var reachable := not blocked_by_pattern and driver_available and source_kind in ["ual1", "ual2"]
	var reason := ""
	if blocked_by_pattern:
		reason = "Le pattern d'attaque reussit avant la branche signature"
	elif not driver_available:
		reason = "Le personnage n'instancie pas le driver requis pour cette source"
	elif source_kind not in ["ual1", "ual2"]:
		reason = "Aucune source signature runtime"
	var provenance := provenance_for_source(source_path) if reachable else "unreachable"
	return _descriptor({
		"runtime_reachable": reachable,
		"runtime_truth": "runtime_layered" if reachable else "runtime_unreachable",
		"runtime_truth_label": "Runtime reel - signature" if reachable else "Inatteignable actuellement",
		"runtime_modes": ["detailed"] if reachable else [],
		"runtime_driver": driver_kind(archetype_id, profile),
		"runtime_source_path": source_path if reachable else "",
		"runtime_source_clip": clip_name if reachable else "",
		"preview_source_path": source_path,
		"preview_source_clip": clip_name,
		"preview_fidelity": "source_only_missing_runtime_layer" if reachable else "declared_only",
		"provenance": provenance,
		"full_body": false,
		"hips_weight": 0.52,
		"start_fraction": 0.0,
		"weapon_family": String(profile.get("weapon", "unarmed")),
		"runtime_reason": reason,
	})


static func describe_mass_fallback(archetype_id: StringName, profile: Dictionary, source_clip: String) -> Dictionary:
	var modes: Array[String] = ["mass"]
	if not needs_specialized_driver(profile) and not uses_shared_driver(archetype_id):
		modes.append("detailed")
		modes.append("lightweight")
	return _descriptor({
		"runtime_reachable": true,
		"runtime_truth": "runtime_fallback",
		"runtime_truth_label": "Fallback runtime conditionnel",
		"runtime_modes": modes,
		"runtime_driver": "ual1_direct",
		"runtime_source_path": UAL1_PATH,
		"runtime_source_clip": source_clip,
		"preview_source_path": UAL1_PATH,
		"preview_source_clip": source_clip,
		"preview_fidelity": "exact_source",
		"provenance": "fallback",
		"full_body": true,
		"hips_weight": 1.0,
		"start_fraction": 0.0,
		"weapon_family": String(profile.get("weapon", "unarmed")),
		"runtime_reason": "Utilise en mode foule ou quand aucun driver detaille n'est instancie",
	})


static func _has_reachable_pattern(archetype_id: StringName, profile: Dictionary) -> bool:
	for field: String in ["combat_pattern", "phase_two_pattern", "phase_three_pattern"]:
		for raw_step: Variant in Array(profile.get(field, [])):
			if not raw_step is Dictionary:
				continue
			var step := raw_step as Dictionary
			var external_key := StringName(step.get("external", StringName()))
			if uses_shared_driver(archetype_id) and SHARED_ACTION_KEYS.has(external_key):
				return true
			if needs_specialized_driver(profile) and (
				ExternalAnimationBank.DONOR_PATHS.has(external_key)
				or not Array(step.get("authored", [])).is_empty()
			):
				return true
	return false


static func _descriptor(values: Dictionary) -> Dictionary:
	var provenance := String(values.get("provenance", "unknown"))
	var info := provenance_info(provenance)
	values["provenance_label"] = String(info.get("label", provenance))
	values["provenance_color"] = String(info.get("color", "#EC4899"))
	return values
