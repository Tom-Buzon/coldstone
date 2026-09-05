extends Node
class_name HopliteV2AnimationComponent

const LIBRARY_NAME: StringName = &"hoplite_v2"

var definition: HopliteEnemyV2Definition
var player: AnimationPlayer
var current_semantic: StringName
static var _library_cache: Dictionary = {}

const PHALANX_CYCLE: Array[Dictionary] = [
	{"semantic": &"block_idle", "duration": 3.4},
	{"semantic": &"spear_thrust", "duration": 1.46},
	{"semantic": &"block_idle", "duration": 2.8},
	{"semantic": &"spear_thrust_low", "duration": 1.46},
	{"semantic": &"idle", "duration": 2.4},
]

var cycle_active: bool = false
var cycle_index: int = 0
var cycle_elapsed: float = 0.0


func install(target_skeleton: Skeleton3D, value: HopliteEnemyV2Definition) -> bool:
	definition = value
	var library := _library_cache.get(definition.animation_library_path) as AnimationLibrary
	if library == null:
		library = load(definition.animation_library_path) as AnimationLibrary
		if library != null:
			_library_cache[definition.animation_library_path] = library
	if library == null:
		push_error("HopliteV2 animation library is missing: %s" % definition.animation_library_path)
		return false
	player = AnimationPlayer.new()
	player.name = "HopliteV2AnimationPlayer"
	target_skeleton.add_child(player)
	var add_error := player.add_animation_library(LIBRARY_NAME, library)
	if add_error != OK:
		push_error("HopliteV2 could not install animation library: %s" % error_string(add_error))
		player.queue_free()
		player = null
		return false
	return play_semantic(&"idle")


func play_semantic(semantic: StringName, blend: float = 0.12, speed: float = 1.0) -> bool:
	if player == null or definition == null:
		return false
	var clip := StringName(definition.semantic_animations.get(semantic, StringName()))
	if clip.is_empty():
		return false
	var qualified := StringName("%s/%s" % [LIBRARY_NAME, clip])
	if not player.has_animation(qualified):
		return false
	player.play(qualified, blend, speed)
	current_semantic = semantic
	return true


func start_pattern(pattern: StringName, phase_seed: int = 0) -> bool:
	cycle_active = pattern == &"phalanx_cycle"
	set_process(false)
	if not cycle_active:
		return play_semantic(pattern)
	var total_duration := 0.0
	for entry: Dictionary in PHALANX_CYCLE:
		total_duration += float(entry["duration"])
	var phase := fmod(float(absi(phase_seed * 1103515245 + 12345) % 10000) / 10000.0 * total_duration, total_duration)
	cycle_index = 0
	while cycle_index < PHALANX_CYCLE.size() - 1 and phase >= float(PHALANX_CYCLE[cycle_index]["duration"]):
		phase -= float(PHALANX_CYCLE[cycle_index]["duration"])
		cycle_index += 1
	cycle_elapsed = phase
	var started := play_semantic(StringName(PHALANX_CYCLE[cycle_index]["semantic"]), 0.0)
	if started and player != null:
		player.seek(cycle_elapsed, true)
	return started


func tick_cycle(delta: float) -> void:
	if not cycle_active or PHALANX_CYCLE.is_empty():
		return
	cycle_elapsed += delta
	var duration := float(PHALANX_CYCLE[cycle_index]["duration"])
	if cycle_elapsed < duration:
		return
	cycle_elapsed = fmod(cycle_elapsed, duration)
	cycle_index = (cycle_index + 1) % PHALANX_CYCLE.size()
	play_semantic(StringName(PHALANX_CYCLE[cycle_index]["semantic"]), 0.10)


func set_manual_sampling(enabled: bool) -> void:
	if player == null:
		return
	var desired := AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if enabled else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	if player.callback_mode_process == desired:
		return
	player.callback_mode_process = desired
	if not enabled:
		player.advance(0.0)


func sample(delta: float) -> void:
	if player != null and delta > 0.0:
		player.advance(delta)
