extends Node
class_name HopliteV2LodComponent

const SETTINGS_REFRESH_MSEC := 250
const DISTANCE_REFRESH_SECONDS := 0.16

var actor: Node3D
var reference: Node3D
var presentation: HopliteV2PresentationComponent
var animation: HopliteV2AnimationComponent
var equipment: HopliteV2EquipmentComponent
var current_level: int = -1
var cached_distance: float = INF
var distance_accumulator: float = 0.0
var animation_accumulator: float = 0.0
var settings_signature: String = ""
var current_settings: Dictionary = {}
var shadows_initialized: bool = false
var shadows_enabled_cache: bool = true
static var _settings_cache: Dictionary = {}
static var _settings_deadline_msec: int = 0


func install(
	actor_value: Node3D,
	reference_value: Node3D,
	presentation_value: HopliteV2PresentationComponent,
	animation_value: HopliteV2AnimationComponent,
	equipment_value: HopliteV2EquipmentComponent
) -> void:
	actor = actor_value
	reference = reference_value
	presentation = presentation_value
	animation = animation_value
	equipment = equipment_value
	distance_accumulator = _phase_fraction() * DISTANCE_REFRESH_SECONDS
	set_process(true)
	refresh(true)


func _process(delta: float) -> void:
	animation.tick_cycle(delta)
	distance_accumulator += delta
	if distance_accumulator >= DISTANCE_REFRESH_SECONDS:
		distance_accumulator = fmod(distance_accumulator, DISTANCE_REFRESH_SECONDS)
		refresh(false)
	_sample_animation(delta)


func refresh(force: bool = false) -> void:
	if actor == null or presentation == null or animation == null:
		return
	var settings := _runtime_settings()
	current_settings = settings
	var signature := "%s|%.3f|%.3f|%.3f|%.3f|%.3f" % [
		str(settings["enabled"]), settings["near"], settings["far"], settings["cull"], settings["shadow"], settings["full_rate"],
	]
	if force or signature != settings_signature:
		settings_signature = signature
		presentation.apply_lod_policy(bool(settings["enabled"]), float(settings["near"]), float(settings["far"]), float(settings["cull"]))
		if equipment != null:
			equipment.apply_lod_policy(bool(settings["enabled"]), float(settings["cull"]))
	var resolved_reference := reference
	if resolved_reference == null or not is_instance_valid(resolved_reference):
		resolved_reference = actor.get_viewport().get_camera_3d()
	cached_distance = INF if resolved_reference == null else Vector2(
		resolved_reference.global_position.x - actor.global_position.x,
		resolved_reference.global_position.z - actor.global_position.z
	).length()
	var next_level := 0
	if bool(settings["enabled"]):
		if cached_distance > float(settings["cull"]):
			next_level = 3
		elif cached_distance > float(settings["far"]):
			next_level = 2
		elif cached_distance > float(settings["near"]):
			next_level = 1
	if force or next_level != current_level:
		current_level = next_level
		var sample_hz := float(settings["medium_hz"]) if current_level == 1 else float(settings["far_hz"])
		animation_accumulator = _phase_fraction() / maxf(1.0, sample_hz) if current_level in [1, 2] else 0.0
		animation.set_manual_sampling(bool(settings["enabled"]) and current_level > 0)
		actor.set_meta("enemy_v2_lod_level", current_level)
		actor.set_meta("enemy_v2_lod_distance", cached_distance)
		if actor.has_method("on_v2_lod_level_changed"):
			actor.call("on_v2_lod_level_changed", current_level)
	if actor.has_method("on_v2_lod_sample"):
		actor.call("on_v2_lod_sample", current_level, cached_distance)
	var shadows_enabled := not bool(settings["enabled"]) or (current_level == 0 and cached_distance <= float(settings["shadow"]))
	if force or not shadows_initialized or shadows_enabled != shadows_enabled_cache:
		shadows_initialized = true
		shadows_enabled_cache = shadows_enabled
		presentation.set_shadows_enabled(shadows_enabled)
		if equipment != null:
			equipment.set_shadows_enabled(shadows_enabled)


func _sample_animation(delta: float) -> void:
	if current_level <= 0 or current_level >= 3 or animation == null:
		return
	if current_settings.is_empty():
		return
	var settings := current_settings
	var frequency := float(settings["medium_hz"]) if current_level == 1 else float(settings["far_hz"])
	var interval := 1.0 / maxf(1.0, frequency)
	animation_accumulator += delta
	if animation_accumulator < interval:
		return
	animation.sample(animation_accumulator)
	animation_accumulator = fmod(animation_accumulator, interval)


static func invalidate_settings_cache() -> void:
	_settings_deadline_msec = 0


func _phase_fraction() -> float:
	return float(actor.get_instance_id() % 997) / 997.0 if actor != null else 0.0


static func _runtime_settings() -> Dictionary:
	var now := Time.get_ticks_msec()
	if _settings_cache.is_empty() or now >= _settings_deadline_msec:
		var near_distance := maxf(1.0, float(ProjectSettings.get_setting("hoplite/enemy_lod/near_distance", 16.0)))
		var far_distance := maxf(near_distance + 1.0, float(ProjectSettings.get_setting("hoplite/enemy_lod/far_distance", 38.0)))
		_settings_cache = {
			"enabled": bool(ProjectSettings.get_setting("hoplite/enemy_lod/enabled", true)),
			"near": near_distance,
			"far": far_distance,
			"cull": maxf(far_distance + 1.0, float(ProjectSettings.get_setting("hoplite/enemy_lod/cull_distance", 90.0))),
			"full_rate": clampf(float(ProjectSettings.get_setting("hoplite/enemy_lod/full_rate_distance", 3.8)), 1.0, near_distance),
			"medium_hz": clampf(float(ProjectSettings.get_setting("hoplite/enemy_lod/medium_animation_hz", 30.0)), 8.0, 60.0),
			"far_hz": clampf(float(ProjectSettings.get_setting("hoplite/enemy_lod/far_animation_hz", 12.0)), 2.0, 30.0),
			"shadow": maxf(0.0, float(ProjectSettings.get_setting("hoplite/enemy_lod/shadow_distance", 8.0))),
		}
		_settings_deadline_msec = now + SETTINGS_REFRESH_MSEC
	return _settings_cache
