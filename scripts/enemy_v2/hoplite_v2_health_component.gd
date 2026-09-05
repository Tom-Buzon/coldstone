extends Node
class_name HopliteV2HealthComponent

signal health_changed(current: float, maximum: float)
signal depleted(hit: Variant, zone: StringName)
signal sever_requested(zone: StringName, hit: Variant)

const AnatomyScript = preload("res://scripts/enemy/anatomy_hitbox.gd")
const AnatomyProfileScript = preload("res://scripts/enemy/anatomy_profile.gd")

# Anatomy is only useful inside plausible player weapon reach. Keeping its
# twelve animated shapes in the broad phase outside that radius is pure cost.
const ANATOMY_EXACT_DISTANCE := 5.5
const ANATOMY_QUERY_DISTANCE := 8.0
const ANATOMY_EXACT_INTERVAL := 1.0 / 30.0
const ANATOMY_COARSE_INTERVAL := 1.0 / 12.0

var actor: CharacterBody3D
var runtime_state: HopliteEnemyV2RuntimeState
var anatomy: HopliteAnatomyHitbox
var zone_definitions: Dictionary = {}
var zone_damage: Dictionary = {}
var zone_sever_damage: Dictionary = {}
var active: bool = false
var severed_zones: Dictionary = {}


func install(
	actor_value: CharacterBody3D,
	skeleton: Skeleton3D,
	runtime_value: HopliteEnemyV2RuntimeState
) -> bool:
	actor = actor_value
	runtime_state = runtime_value
	if actor == null or skeleton == null or runtime_state == null:
		return false
	zone_definitions = AnatomyProfileScript.default_humanoid()
	anatomy = AnatomyScript.new() as HopliteAnatomyHitbox
	anatomy.name = "HopliteV2Anatomy"
	actor.add_child(anatomy)
	if not anatomy.configure(actor, skeleton, zone_definitions):
		anatomy.queue_free()
		anatomy = null
		return false
	active = true
	health_changed.emit(runtime_state.health, actor.definition.max_health)
	return true


func apply_runtime_lod(level: int, planar_distance: float) -> void:
	if anatomy == null or not active:
		return
	var query_active := level <= 0 and planar_distance <= ANATOMY_QUERY_DISTANCE
	if not query_active:
		anatomy.set_runtime_query_enabled(false)
		actor.set_meta("enemy_v2_anatomy_mode", &"off")
		return
	var exact := planar_distance <= ANATOMY_EXACT_DISTANCE
	anatomy.set_update_interval(ANATOMY_EXACT_INTERVAL if exact else ANATOMY_COARSE_INTERVAL)
	anatomy.set_runtime_query_enabled(true)
	actor.set_meta("enemy_v2_anatomy_mode", &"exact" if exact else &"coarse")


func receive_hit(hit: Variant, zone: StringName) -> void:
	if not active or actor == null or actor.dead or hit == null or not zone_definitions.has(zone):
		return
	var definition := zone_definitions[zone] as Dictionary
	var damage := maxf(0.0, float(hit.damage)) * float(definition.get("damage_mult", 1.0))
	var sever := maxf(0.0, float(hit.sever_damage)) * float(definition.get("sever_mult", 1.0))
	runtime_state.health = maxf(0.0, runtime_state.health - damage)
	zone_damage[zone] = float(zone_damage.get(zone, 0.0)) + damage
	zone_sever_damage[zone] = float(zone_sever_damage.get(zone, 0.0)) + sever
	var sever_target := StringName(definition.get("sever_target", zone))
	var threshold := float(definition.get("sever_threshold", 9999.0))
	if bool(definition.get("severable", false)) and float(zone_sever_damage[zone]) >= threshold and not severed_zones.has(sever_target):
		severed_zones[sever_target] = true
		sever_requested.emit(sever_target, hit)
		if bool(definition.get("fatal_sever", false)) or sever_target == &"head":
			runtime_state.health = 0.0
	health_changed.emit(runtime_state.health, actor.definition.max_health)
	if runtime_state.health <= 0.0:
		active = false
		if anatomy != null:
			anatomy.shutdown()
		depleted.emit(hit, zone)


func shutdown() -> void:
	active = false
	if anatomy != null:
		anatomy.shutdown()


func is_zone_severed(zone: StringName) -> bool:
	return severed_zones.has(zone)
