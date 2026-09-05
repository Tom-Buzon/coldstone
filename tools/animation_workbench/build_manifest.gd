extends SceneTree

const EnemyArchetypes = preload("res://scripts/enemy/enemy_archetypes.gd")
const ExternalAnimationBank = preload("res://scripts/animation/external_animation_bank.gd")
const AnimationRuntimeContract = preload("res://scripts/animation/enemy_animation_runtime_contract.gd")

const SCHEMA_VERSION := 1
const OUTPUT_PATH := "res://tools/animation_workbench/data/animation_workbench_manifest.json"
const OVERRIDES_PATH := "res://tools/animation_workbench/data/workbench_overrides.json"
const RUNTIME_BINDINGS_PATH := "res://assets/animations/generated/runtime_bindings.json"
const THREE_DGEN_ROOT := "res://assets/characters/3dgen_demo/"
const UAL_REFERENCE_MODEL := "res://assets/runtime/ual1/UAL1_Standard.glb"

const SOURCE_ROOTS: Array[Dictionary] = [
	{"path": "res://assets/animations/source_packs", "kind": "mixamo", "legacy": false},
	{"path": "res://assets/runtime/mixamo/animations", "kind": "mixamo", "legacy": true},
	{"path": "res://assets/runtime/ual1", "kind": "ual1", "legacy": true},
	{"path": "res://assets/runtime/ual2", "kind": "ual2", "legacy": true},
	{"path": "res://assets/animations/sources", "kind": "spartan", "legacy": true},
]

const SUPPORTED_EXTENSIONS := {
	"fbx": true,
	"glb": true,
	"gltf": true,
	"blend": true,
}

const CORE_ACTIONS: Array[Dictionary] = [
	{"action_id": "idle", "label": "Repos", "runtime_key": "Idle", "source_path": "res://assets/runtime/ual1/UAL1_Standard.glb", "source_clip": "Idle", "loop": true},
	{"action_id": "jog_forward", "label": "Course avant", "runtime_key": "Jog_Fwd", "source_path": "res://assets/runtime/ual1/UAL1_Standard.glb", "source_clip": "Jog_Fwd", "loop": true},
	{"action_id": "sprint", "label": "Sprint", "runtime_key": "Sprint", "source_path": "res://assets/runtime/ual1/UAL1_Standard.glb", "source_clip": "Sprint", "loop": true},
	{"action_id": "death", "label": "Mort", "runtime_key": "Death01", "source_path": "res://assets/runtime/ual1/UAL1_Standard.glb", "source_clip": "Death01", "loop": false},
]

const REQUIRED_MISSING_ACTIONS: Array[Dictionary] = [
	{"action_id": "turn_left_45", "label": "Rotation gauche 45°"},
	{"action_id": "turn_left_90", "label": "Rotation gauche 90°"},
	{"action_id": "turn_right_45", "label": "Rotation droite 45°"},
	{"action_id": "turn_right_90", "label": "Rotation droite 90°"},
	{"action_id": "turn_180", "label": "Demi-tour 180°"},
	{"action_id": "start_move", "label": "Départ locomotion"},
	{"action_id": "stop_move", "label": "Arrêt locomotion"},
]

var _default_donors: Dictionary = {}
var _source_by_path: Dictionary = {}


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_default_donors = ExternalAnimationBank.default_donor_paths()
	var sources := _scan_animation_sources()
	for source: Dictionary in sources:
		_source_by_path[String(source.get("path", ""))] = source

	var game_archetypes := _build_archetype_catalog()
	_apply_published_runtime_bindings(game_archetypes)
	var archetypes := _build_virtual_profiles(game_archetypes)
	archetypes.append_array(game_archetypes)
	var monitoring := _build_monitoring(game_archetypes)
	var manifest_summary := _summary(archetypes, sources)
	manifest_summary.merge(Dictionary(monitoring.get("summary", {})), true)
	var manifest := {
		"schema_version": SCHEMA_VERSION,
		"generated_at_utc": Time.get_datetime_string_from_system(true, true),
		"source_roots": SOURCE_ROOTS,
		"default_new_source_compatibility": "mixamo",
		"overrides_path": OVERRIDES_PATH,
		"runtime_output_path": "res://assets/animations/generated/runtime_bindings.json",
		"archetypes": archetypes,
		"sources": sources,
		"monitoring": monitoring,
		"summary": manifest_summary,
	}

	var error := _write_json(OUTPUT_PATH, manifest)
	if error != OK:
		push_error("[ANIMATION WORKBENCH] Could not save manifest: %s" % error_string(error))
		quit(1)
		return
	_ensure_override_file()
	print("[ANIMATION WORKBENCH] manifest=", OUTPUT_PATH)
	print("[ANIMATION WORKBENCH] enemies=", game_archetypes.size(), " profiles=", archetypes.size(), " sources=", sources.size(), " clips=", _count_clips(sources))
	quit(0)


func _apply_published_runtime_bindings(game_archetypes: Array[Dictionary]) -> void:
	var runtime := _read_json(RUNTIME_BINDINGS_PATH)
	if runtime.is_empty() or int(runtime.get("schema_version", 0)) != SCHEMA_VERSION:
		return
	var global_bindings: Dictionary = runtime.get("global", {})
	var per_archetype_bindings: Dictionary = runtime.get("archetypes", {})
	for archetype: Dictionary in game_archetypes:
		var archetype_id := String(archetype.get("archetype_id", ""))
		# The shared Hoplite driver reads its baked AnimationLibrary directly and
		# deliberately does not consult AnimationWorkbenchBindings.
		if AnimationRuntimeContract.uses_shared_driver(StringName(archetype_id)):
			continue
		var local_bindings: Dictionary = per_archetype_bindings.get(archetype_id, {})
		var actions: Array = archetype.get("actions", [])
		for action_index: int in actions.size():
			var action: Dictionary = actions[action_index]
			var runtime_key := String(action.get("runtime_key", ""))
			if runtime_key.is_empty():
				continue
			var binding: Dictionary = {}
			var binding_origin := ""
			if global_bindings.has(runtime_key) and global_bindings[runtime_key] is Dictionary:
				binding = Dictionary(global_bindings[runtime_key])
				binding_origin = "published_global"
			if local_bindings.has(runtime_key) and local_bindings[runtime_key] is Dictionary:
				binding = Dictionary(local_bindings[runtime_key])
				binding_origin = "published_archetype"
			if binding.is_empty():
				continue
			var source_path := String(binding.get("source_path", ""))
			if source_path.is_empty() or (not ResourceLoader.exists(source_path) and not FileAccess.file_exists(source_path)):
				continue
			var source_clip := String(binding.get("source_clip", runtime_key))
			var provenance := AnimationRuntimeContract.provenance_for_source(source_path)
			var provenance_info := AnimationRuntimeContract.provenance_info(provenance)
			action["runtime_source_path"] = source_path
			action["runtime_source_clip"] = source_clip
			action["preview_source_path"] = source_path
			action["preview_source_clip"] = source_clip
			action["source_path"] = source_path
			action["source_clip"] = source_clip
			action["provenance"] = provenance
			action["provenance_label"] = String(provenance_info.get("label", provenance))
			action["provenance_color"] = String(provenance_info.get("color", "#EC4899"))
			action["runtime_binding_origin"] = binding_origin
			action["runtime_binding_scope"] = String(binding.get("scope", ""))
			action["preview_fidelity"] = "exact_source" if bool(action.get("full_body", true)) else "source_only_missing_runtime_layer"
			action["runtime_reason"] = "Affectation Workbench publiée et réellement lue par ExternalAnimationBank."
			actions[action_index] = action
		archetype["actions"] = actions


func _scan_animation_sources() -> Array[Dictionary]:
	var paths: PackedStringArray = PackedStringArray()
	var root_for_path: Dictionary = {}
	for root_info: Dictionary in SOURCE_ROOTS:
		var root_path := String(root_info["path"])
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_path)):
			continue
		_collect_source_files(root_path, paths)
		for source_path: String in paths:
			if source_path.begins_with(root_path + "/") and not root_for_path.has(source_path):
				root_for_path[source_path] = root_info
	paths = _unique_sorted(paths)

	var result: Array[Dictionary] = []
	for source_path: String in paths:
		var root_info: Dictionary = root_for_path.get(source_path, {})
		var clips := _inspect_clips(source_path)
		var root_path := String(root_info.get("path", ""))
		var relative := source_path.trim_prefix(root_path + "/")
		var segments := relative.split("/", false)
		var pack_id := String(segments[0]).get_basename().to_snake_case() if segments.size() > 1 else source_path.get_file().get_basename().to_snake_case()
		result.append({
			"id": _stable_source_id(source_path),
			"display_name": source_path.get_file().get_basename(),
			"path": source_path,
			"extension": source_path.get_extension().to_lower(),
			"pack_id": pack_id,
			"compatibility": String(root_info.get("kind", "mixamo")),
			"legacy_location": bool(root_info.get("legacy", false)),
			"clips": clips,
			"status": "ready" if not clips.is_empty() else "uninspected",
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["path"]) < String(b["path"]))
	return result


func _collect_source_files(directory_path: String, output: PackedStringArray) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var path := directory_path.path_join(entry)
			if directory.current_is_dir():
				_collect_source_files(path, output)
			elif SUPPORTED_EXTENSIONS.has(entry.get_extension().to_lower()):
				output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _inspect_clips(source_path: String) -> Array[Dictionary]:
	var root: Node = null
	if ResourceLoader.exists(source_path):
		var packed := load(source_path) as PackedScene
		if packed != null:
			root = packed.instantiate()
	elif source_path.get_extension().to_lower() in ["glb", "gltf"] and FileAccess.file_exists(source_path):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var flags := GLTFDocument.IMPORT_FLAG_DISCARD_MESHES_AND_MATERIALS | GLTFDocument.IMPORT_FLAG_USE_NAMED_SKIN_BINDS
		if document.append_from_file(ProjectSettings.globalize_path(source_path), state, flags) == OK:
			root = document.generate_scene(state)
	if root == null:
		return []

	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root, players)
	var found: Dictionary = {}
	for player: AnimationPlayer in players:
		for clip_name: StringName in player.get_animation_list():
			if clip_name == &"RESET":
				continue
			var animation := player.get_animation(clip_name)
			if animation == null or animation.length <= 0.001:
				continue
			var key := String(clip_name)
			if not found.has(key):
				found[key] = {
					"name": key,
					"length": snappedf(animation.length, 0.001),
					"tracks": animation.get_track_count(),
					"loop": animation.loop_mode != Animation.LOOP_NONE,
				}
	root.free()
	var result: Array[Dictionary] = []
	for key: String in found:
		result.append(found[key])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]) < String(b["name"]))
	return result


func _build_archetype_catalog() -> Array[Dictionary]:
	var candidates: Array[StringName] = EnemyArchetypes.all_ids()
	var result: Array[Dictionary] = []
	var canonical_fingerprint := String(_model_rig_info(EnemyArchetypes.package_path(&"ngeneral")).get("fingerprint", ""))
	for archetype_id: StringName in candidates:
		var model_path: String = EnemyArchetypes.package_path(archetype_id)
		if not model_path.begins_with(THREE_DGEN_ROOT):
			continue
		var profile: Dictionary = EnemyArchetypes.profile(archetype_id)
		var rig: Dictionary = _model_rig_info(model_path)
		var bone_count := int(rig.get("bone_count", 0))
		var fingerprint := String(rig.get("fingerprint", ""))
		var fingerprint_short := fingerprint.substr(0, 12) if not fingerprint.is_empty() else "unknown"
		var rig_family := "custom_%s_%s" % [bone_count, fingerprint_short]
		if bone_count == 23:
			rig_family = "spartan_enemy_v2_23_%s" % fingerprint_short
		elif bone_count == 53 and fingerprint == canonical_fingerprint:
			rig_family = "spartan_53_exact"
		elif bone_count == 53:
			rig_family = "ual1_53_%s" % fingerprint_short
		var declared_origin := String(EnemyArchetypes.asset_origin(archetype_id))
		var resolved_origin := "3dgen" if model_path.begins_with(THREE_DGEN_ROOT) else declared_origin
		result.append({
			"archetype_id": String(archetype_id),
			"display_name": String(profile.get("display_name", String(archetype_id).capitalize())),
			"model_path": model_path,
			"declared_asset_origin": declared_origin,
			"resolved_asset_origin": resolved_origin,
			"origin_mismatch": declared_origin != resolved_origin,
			"rig_family": rig_family,
			"rig": rig,
			"weapon_family": String(profile.get("weapon", "unarmed")),
			"role": String(profile.get("role", "standard")),
			"rank": String(profile.get("rank", "troop")),
			"behavior": String(profile.get("behavior", "aggressive")),
			"actions": _actions_for_archetype(archetype_id, profile),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["display_name"]) < String(b["display_name"]))
	return result


func _build_virtual_profiles(game_archetypes: Array[Dictionary]) -> Array[Dictionary]:
	if game_archetypes.is_empty():
		return []
	var reference_rig := _model_rig_info(UAL_REFERENCE_MODEL)
	var common_actions: Array[Dictionary] = []
	for raw_action: Variant in game_archetypes[0].get("actions", []):
		if raw_action is Dictionary and String((raw_action as Dictionary).get("category", "")) == "common":
			var action: Dictionary = (raw_action as Dictionary).duplicate(true)
			action["scope"] = "rig_common"
			common_actions.append(action)
	var target_ids := PackedStringArray()
	for archetype: Dictionary in game_archetypes:
		target_ids.append(String(archetype.get("archetype_id", "")))
	var result: Array[Dictionary] = [{
		"archetype_id": "__rig_common__",
		"display_name": "00 - RIG COMMUN (UAL)",
		"model_path": UAL_REFERENCE_MODEL,
		"declared_asset_origin": "ual1",
		"resolved_asset_origin": "ual1",
		"origin_mismatch": false,
		"rig_family": "rig_common",
		"rig": reference_rig,
		"weapon_family": "all",
		"role": "animation_library",
		"rank": "virtual",
		"behavior": "preview_only",
		"virtual": true,
		"assignment_scope": "rig_common",
		"scope_id": "all",
		"target_archetypes": Array(target_ids),
		"actions": common_actions,
	}]

	var weapons: Dictionary = {}
	for archetype: Dictionary in game_archetypes:
		var weapon := String(archetype.get("weapon_family", "unarmed"))
		var group: Dictionary = weapons.get(weapon, {"targets": PackedStringArray(), "actions": {}, "order": PackedStringArray()})
		var targets: PackedStringArray = group["targets"]
		var group_actions: Dictionary = group["actions"]
		var group_order: PackedStringArray = group["order"]
		targets.append(String(archetype.get("archetype_id", "")))
		for raw_action: Variant in archetype.get("actions", []):
			if not raw_action is Dictionary:
				continue
			var action: Dictionary = raw_action
			if String(action.get("category", "")) != "weapon":
				continue
			var action_id := String(action.get("action_id", ""))
			if not group_actions.has(action_id):
				var shared_action := action.duplicate(true)
				shared_action["scope"] = "weapon_pack"
				group_actions[action_id] = shared_action
				group_order.append(action_id)
			elif bool(action.get("runtime_binding_supported", false)):
				var shared_action: Dictionary = group_actions[action_id]
				shared_action["runtime_binding_supported"] = true
				group_actions[action_id] = shared_action
		group["targets"] = targets
		group["actions"] = group_actions
		group["order"] = group_order
		weapons[weapon] = group

	var weapon_names := PackedStringArray(weapons.keys())
	weapon_names.sort()
	for weapon: String in weapon_names:
		var group: Dictionary = weapons[weapon]
		var actions: Array[Dictionary] = []
		for common_action: Dictionary in common_actions:
			var weapon_common := common_action.duplicate(true)
			weapon_common["scope"] = "weapon_pack"
			actions.append(weapon_common)
		for action_id: String in group["order"]:
			actions.append((group["actions"] as Dictionary)[action_id])
		result.append({
			"archetype_id": "__weapon__%s" % weapon,
			"display_name": "01 - ARME : %s" % weapon.to_upper(),
			"model_path": UAL_REFERENCE_MODEL,
			"declared_asset_origin": "ual1",
			"resolved_asset_origin": "ual1",
			"origin_mismatch": false,
			"rig_family": "rig_common",
			"rig": reference_rig,
			"weapon_family": weapon,
			"role": "animation_weapon_pack",
			"rank": "virtual",
			"behavior": "preview_only",
			"virtual": true,
			"assignment_scope": "weapon_pack",
			"scope_id": weapon,
			"target_archetypes": Array(group["targets"] as PackedStringArray),
			"actions": actions,
		})
	return result


func _actions_for_archetype(archetype_id: StringName, profile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_core: Dictionary in CORE_ACTIONS:
		var action := raw_core.duplicate(true)
		action.merge({
			"category": "common",
			"phase": "base",
			"status": "active",
			"layer": "full_body",
			"scope": "rig_family",
			"publish_channel": "baked",
			"runtime_binding_supported": false,
		})
		action.merge(AnimationRuntimeContract.describe_core(
			archetype_id,
			profile,
			String(action.get("source_path", "")),
			String(action.get("source_clip", ""))
		), true)
		result.append(action)
	for raw_missing: Dictionary in REQUIRED_MISSING_ACTIONS:
		var action := raw_missing.duplicate(true)
		action.merge({
			"category": "common",
			"phase": "future_contract",
			"status": "missing",
			"layer": "full_body",
			"scope": "rig_family",
			"loop": false,
			"runtime_key": "",
			"source_path": "",
			"source_clip": "",
			"publish_channel": "future_bake",
			"runtime_binding_supported": false,
		})
		action.merge(AnimationRuntimeContract.describe_missing(profile), true)
		result.append(action)

	_add_pattern_actions(result, archetype_id, profile, Array(profile.get("combat_pattern", [])), "base")
	_add_pattern_actions(result, archetype_id, profile, Array(profile.get("phase_two_pattern", [])), "2")
	_add_pattern_actions(result, archetype_id, profile, Array(profile.get("phase_three_pattern", [])), "3")

	var signature_source := String(profile.get("signature_source", ""))
	for raw_signature: Variant in Array(profile.get("signature_animations", [])):
		var clip_name := String(raw_signature)
		var signature := {
			"action_id": "signature_%s" % clip_name.to_snake_case(),
			"label": "Signature - " + clip_name,
			"category": "type",
			"phase": "base",
			"status": "declared",
			"layer": "upper_body",
			"scope": "archetype",
			"loop": false,
			"runtime_key": "",
			"source_path": "res://assets/runtime/ual2/UAL2_Standard.glb" if signature_source == "ual2" else "res://assets/runtime/ual1/UAL1_Standard.glb",
			"source_clip": clip_name,
			"publish_channel": "future_bake",
			"runtime_binding_supported": false,
		}
		signature.merge(AnimationRuntimeContract.describe_signature(archetype_id, profile, clip_name), true)
		result.append(signature)

	var weapon := String(profile.get("weapon", "unarmed"))
	var mass_fallback := {
		"action_id": "mass_attack",
		"label": "Attaque LOD masse",
		"category": "weapon",
		"phase": "fallback_mass",
		"status": "fallback",
		"layer": "full_body",
		"scope": "weapon_pack",
		"loop": false,
		"runtime_key": "",
		"source_path": "res://assets/runtime/ual1/UAL1_Standard.glb",
		"source_clip": "Idle" if weapon == "bow" else "Sword_Attack",
		"publish_channel": "future_bake",
		"runtime_binding_supported": false,
		"note": "Fallback actuel à remplacer par une silhouette adaptée à l'arme",
	}
	mass_fallback.merge(AnimationRuntimeContract.describe_mass_fallback(archetype_id, profile, String(mass_fallback["source_clip"])), true)
	result.append(mass_fallback)
	return result


func _add_pattern_actions(output: Array[Dictionary], archetype_id: StringName, profile: Dictionary, pattern: Array, phase: String) -> void:
	for raw_step: Variant in pattern:
		if not raw_step is Dictionary:
			continue
		var step: Dictionary = raw_step
		var external_key := String(step.get("external", ""))
		var source_path := String(_default_donors.get(StringName(external_key), "")) if not external_key.is_empty() else ""
		var source_clip := _preferred_clip_for_source(source_path)
		var action_id := String(step.get("id", external_key if not external_key.is_empty() else step.get("slot", "unnamed_action")))
		var action := {
			"action_id": action_id,
			"label": action_id.replace("_", " ").capitalize(),
			"category": "type" if phase != "base" or step.has("special") else "weapon",
			"phase": phase,
			"status": "active" if not external_key.is_empty() or not Array(step.get("authored", [])).is_empty() else "declared",
			"layer": "full_body" if bool(step.get("full_body", true)) else "upper_body",
			"scope": "archetype" if phase != "base" or step.has("special") else "weapon_pack",
			"loop": false,
			"runtime_key": external_key,
			"source_path": source_path,
			"source_clip": source_clip,
			"slot": String(step.get("slot", "")),
			"start_fraction": float(step.get("start_fraction", 0.0)),
			"publish_channel": "runtime_donor" if not external_key.is_empty() else "future_bake",
			"runtime_binding_supported": not external_key.is_empty() and not AnimationRuntimeContract.uses_shared_driver(archetype_id),
		}
		var runtime := AnimationRuntimeContract.describe_pattern(archetype_id, profile, step)
		runtime["preview_source_path"] = source_path
		runtime["preview_source_clip"] = source_clip
		if bool(runtime.get("runtime_reachable", false)) and String(runtime.get("provenance", "")) != "shared_bake":
			runtime["runtime_source_clip"] = source_clip
		action.merge(runtime, true)
		output.append(action)


func _preferred_clip_for_source(path: String) -> String:
	if not _source_by_path.has(path):
		return ""
	var clips: Array = _source_by_path[path].get("clips", [])
	return String(clips[0].get("name", "")) if not clips.is_empty() else ""


func _model_rig_info(model_path: String) -> Dictionary:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		return {"bone_count": 0, "finger_bones": 0, "finger_tracks_expected": false, "fingerprint": ""}
	var packed := load(model_path) as PackedScene
	if packed == null:
		return {"bone_count": 0, "finger_bones": 0, "finger_tracks_expected": false, "fingerprint": ""}
	var root := packed.instantiate()
	var skeleton := _find_skeleton(root)
	if skeleton == null:
		root.free()
		return {"bone_count": 0, "finger_bones": 0, "finger_tracks_expected": false, "fingerprint": ""}
	var signature := PackedStringArray()
	var finger_bones := 0
	for bone_index: int in range(skeleton.get_bone_count()):
		var bone_name := String(skeleton.get_bone_name(bone_index))
		if bone_name.begins_with("DEF-f_") or bone_name.begins_with("DEF-thumb"):
			finger_bones += 1
		var rest := skeleton.get_bone_rest(bone_index)
		signature.append("%s|%s|%s" % [bone_name, skeleton.get_bone_parent(bone_index), _transform_signature(rest)])
	var fingerprint := _sha256("\n".join(signature))
	var result := {
		"bone_count": skeleton.get_bone_count(),
		"finger_bones": finger_bones,
		"finger_tracks_expected": finger_bones > 0,
		"fingerprint": fingerprint,
		"skeleton_name": String(skeleton.name),
	}
	root.free()
	return result


func _transform_signature(transform: Transform3D) -> String:
	var values: Array[float] = [
		transform.basis.x.x, transform.basis.x.y, transform.basis.x.z,
		transform.basis.y.x, transform.basis.y.y, transform.basis.y.z,
		transform.basis.z.x, transform.basis.z.y, transform.basis.z.z,
		transform.origin.x, transform.origin.y, transform.origin.z,
	]
	var parts := PackedStringArray()
	for value: float in values:
		parts.append("%.7f" % value)
	return ",".join(parts)


func _sha256(value: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return str(value.hash())
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()


func _stable_source_id(source_path: String) -> String:
	return source_path.trim_prefix("res://").get_basename().replace("/", "__").replace("\\", "__").to_snake_case()


func _build_monitoring(game_archetypes: Array[Dictionary]) -> Dictionary:
	var rows: Array[Dictionary] = []
	var weapon_buckets: Dictionary = {}
	var truth_counts: Dictionary = {}
	var provenance_counts: Dictionary = {}
	var issue_count := 0
	for archetype: Dictionary in game_archetypes:
		var archetype_id := String(archetype.get("archetype_id", ""))
		var display_name := String(archetype.get("display_name", archetype_id))
		var weapon := String(archetype.get("weapon_family", "unarmed"))
		var bucket: Dictionary = weapon_buckets.get(weapon, {
			"weapon_family": weapon,
			"character_ids": PackedStringArray(),
			"character_names": PackedStringArray(),
			"action_count": 0,
			"reachable_count": 0,
			"issue_count": 0,
			"runtime_clips": {},
			"provenances": {},
		})
		var character_ids: PackedStringArray = bucket["character_ids"]
		var character_names: PackedStringArray = bucket["character_names"]
		character_ids.append(archetype_id)
		character_names.append(display_name)
		bucket["character_ids"] = character_ids
		bucket["character_names"] = character_names
		for action: Dictionary in archetype.get("actions", []):
			var row := action.duplicate(true)
			row["archetype_id"] = archetype_id
			row["character_name"] = display_name
			row["weapon_family"] = weapon
			rows.append(row)
			var truth := String(action.get("runtime_truth", "unknown"))
			var provenance := String(action.get("provenance", "unknown"))
			truth_counts[truth] = int(truth_counts.get(truth, 0)) + 1
			provenance_counts[provenance] = int(provenance_counts.get(provenance, 0)) + 1
			bucket["action_count"] = int(bucket["action_count"]) + 1
			if bool(action.get("runtime_reachable", false)):
				bucket["reachable_count"] = int(bucket["reachable_count"]) + 1
				var runtime_path := String(action.get("runtime_source_path", ""))
				var runtime_clip := String(action.get("runtime_source_clip", ""))
				if not runtime_path.is_empty() and not runtime_clip.is_empty():
					(bucket["runtime_clips"] as Dictionary)["%s::%s" % [runtime_path, runtime_clip]] = true
			else:
				bucket["issue_count"] = int(bucket["issue_count"]) + 1
				issue_count += 1
			(bucket["provenances"] as Dictionary)[provenance] = true
		weapon_buckets[weapon] = bucket

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key := "%s::%s" % [String(a.get("character_name", "")), String(a.get("action_id", ""))]
		var b_key := "%s::%s" % [String(b.get("character_name", "")), String(b.get("action_id", ""))]
		return a_key < b_key
	)
	var weapons: Array[Dictionary] = []
	var weapon_names := PackedStringArray(weapon_buckets.keys())
	weapon_names.sort()
	for weapon: String in weapon_names:
		var bucket: Dictionary = weapon_buckets[weapon]
		var runtime_clip_keys := PackedStringArray((bucket["runtime_clips"] as Dictionary).keys())
		var provenance_keys := PackedStringArray((bucket["provenances"] as Dictionary).keys())
		runtime_clip_keys.sort()
		provenance_keys.sort()
		bucket["runtime_clips"] = Array(runtime_clip_keys)
		bucket["provenances"] = Array(provenance_keys)
		weapons.append(bucket)

	var legend: Array[Dictionary] = []
	var provenance_ids := PackedStringArray(AnimationRuntimeContract.PROVENANCE.keys())
	provenance_ids.sort()
	for provenance_id: String in provenance_ids:
		var info := AnimationRuntimeContract.provenance_info(provenance_id)
		legend.append({
			"id": provenance_id,
			"label": String(info.get("label", provenance_id)),
			"color": String(info.get("color", "#EC4899")),
		})
	return {
		"rows": rows,
		"weapons": weapons,
		"provenance_legend": legend,
		"summary": {
			"monitoring_row_count": rows.size(),
			"weapon_family_count": weapons.size(),
			"runtime_issue_count": issue_count,
			"runtime_truth_counts": truth_counts,
			"provenance_counts": provenance_counts,
		},
	}


func _summary(archetypes: Array[Dictionary], sources: Array[Dictionary]) -> Dictionary:
	var missing := 0
	var mismatches := 0
	var game_archetype_count := 0
	var virtual_profile_count := 0
	for archetype: Dictionary in archetypes:
		if bool(archetype.get("virtual", false)):
			virtual_profile_count += 1
		else:
			game_archetype_count += 1
			for action: Dictionary in archetype.get("actions", []):
				if String(action.get("status", "")) == "missing":
					missing += 1
		if bool(archetype.get("origin_mismatch", false)):
			mismatches += 1
	return {
		"archetype_count": game_archetype_count,
		"profile_count": archetypes.size(),
		"virtual_profile_count": virtual_profile_count,
		"source_count": sources.size(),
		"clip_count": _count_clips(sources),
		"missing_action_rows": missing,
		"asset_origin_mismatches": mismatches,
	}


func _count_clips(sources: Array[Dictionary]) -> int:
	var total := 0
	for source: Dictionary in sources:
		total += Array(source.get("clips", [])).size()
	return total


func _unique_sorted(values: PackedStringArray) -> PackedStringArray:
	var seen: Dictionary = {}
	for value: String in values:
		seen[value] = true
	var result := PackedStringArray(seen.keys())
	result.sort()
	return result


func _collect_animation_players(node: Node, output: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		output.append(node as AnimationPlayer)
	for child: Node in node.get_children():
		_collect_animation_players(child, output)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _write_json(path: String, data: Dictionary) -> Error:
	var absolute_directory := ProjectSettings.globalize_path(path.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return directory_error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t", true) + "\n")
	return OK


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _ensure_override_file() -> void:
	if FileAccess.file_exists(OVERRIDES_PATH):
		return
	_write_json(OVERRIDES_PATH, {"schema_version": SCHEMA_VERSION, "bindings": []})
