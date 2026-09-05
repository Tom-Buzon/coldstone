extends Node
class_name HopliteGoreDirector

const BloodBurstScript = preload("res://scripts/gore/blood_burst.gd")
const SpartanDetachedLimbScript = preload("res://scripts/gore/spartan_detached_limb.gd")

const BLOOD_POOL_SIZE: int = 24
const SPARTAN_FRAGMENT_MAX_PER_PACKAGE: int = 8
const SPARTAN_FRAGMENT_GLOBAL_PREWARM_LIMIT: int = 24
const SPARTAN_FRAGMENT_GROW_SIZE: int = 2
const FRAGMENT_LIFETIME: float = 14.0
const FRAGMENT_ACTIVE_PHYSICS: float = 4.0

var _blood_pool: Array[HopliteBloodBurst] = []
var _active_blood: Array[HopliteBloodBurst] = []
var _blood_expire_at := PackedFloat64Array()
var _fragment_pools: Dictionary[String, Array] = {}
var _active_fragments: Array[HopliteSpartanDetachedLimb] = []
var _fragment_retire_at := PackedFloat64Array()
var _fragment_expire_at := PackedFloat64Array()
var _fragment_retired := PackedByteArray()
var _registered_packages: Dictionary[String, PackedScene] = {}
var _package_registration_counts: Dictionary[String, int] = {}
var _prewarmed_fragment_count: int = 0
var blood_reuse_count: int = 0
var fragment_reuse_count: int = 0
var fragment_runtime_growth_count: int = 0


func _ready() -> void:
	add_to_group(&"gore_director")
	process_priority = 90
	_prewarm_blood_pool()
	set_process(false)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	for index: int in range(_active_blood.size() - 1, -1, -1):
		if now >= _blood_expire_at[index]:
			_release_blood_at(index)
	for index: int in range(_active_fragments.size() - 1, -1, -1):
		var fragment := _active_fragments[index]
		if not is_instance_valid(fragment):
			_remove_fragment_at(index)
			continue
		if _fragment_retired[index] == 0 and now >= _fragment_retire_at[index]:
			fragment.retire_now()
			_fragment_retired[index] = 1
		if now >= _fragment_expire_at[index]:
			_release_fragment_at(index)
	_update_processing_state()


func register_spartan_package(package_scene: PackedScene) -> void:
	if package_scene == null:
		return
	var key := _package_key(package_scene)
	if not _registered_packages.has(key):
		_registered_packages[key] = package_scene
		_fragment_pools[key] = []
		_package_registration_counts[key] = 0
	_package_registration_counts[key] = int(_package_registration_counts.get(key, 0)) + 1
	var pool: Array = _fragment_pools.get(key, [])
	var desired := mini(int(_package_registration_counts[key]), SPARTAN_FRAGMENT_MAX_PER_PACKAGE)
	var available_global := maxi(0, SPARTAN_FRAGMENT_GLOBAL_PREWARM_LIMIT - _prewarmed_fragment_count)
	var grow_count := mini(maxi(0, desired - pool.size()), available_global)
	if grow_count > 0:
		_grow_fragment_pool(key, grow_count, false)


func spawn_blood(world_position: Vector3, direction: Vector3, intensity: float, sever: bool) -> HopliteBloodBurst:
	var burst := _acquire_blood()
	if burst == null:
		return null
	burst.activate(world_position, direction, intensity, sever)
	_active_blood.append(burst)
	_blood_expire_at.append(Time.get_ticks_msec() * 0.001 + burst.max_lifetime)
	set_process(true)
	return burst


func spawn_spartan_fragment(
	package_scene: PackedScene,
	source_adapter: RefCounted,
	cut_zone: StringName,
	zone_world_transform: Transform3D,
	radius: float,
	length: float,
	impulse: Vector3
) -> bool:
	if package_scene == null or source_adapter == null:
		return false
	var key := _package_key(package_scene)
	if not _registered_packages.has(key):
		register_spartan_package(package_scene)
	var fragment := _acquire_fragment(key)
	if fragment == null:
		return false
	var display_parent: Node = get_tree().current_scene if get_tree() != null else null
	if display_parent != null and fragment.get_parent() != display_parent:
		fragment.reparent(display_parent, false)
	if not fragment.activate(source_adapter, cut_zone, zone_world_transform, radius, length, impulse):
		fragment.deactivate_to_pool()
		if fragment.get_parent() != self:
			fragment.reparent(self, false)
		return false
	fragment_reuse_count += 1
	var now := Time.get_ticks_msec() * 0.001
	_active_fragments.append(fragment)
	_fragment_retire_at.append(now + FRAGMENT_ACTIVE_PHYSICS)
	_fragment_expire_at.append(now + FRAGMENT_LIFETIME)
	_fragment_retired.append(0)
	set_process(true)
	return true


func release_blood(burst: HopliteBloodBurst) -> void:
	var index := _active_blood.find(burst)
	if index >= 0:
		_release_blood_at(index)


func release_fragment(fragment: HopliteSpartanDetachedLimb) -> void:
	var index := _active_fragments.find(fragment)
	if index >= 0:
		_release_fragment_at(index)


func active_blood_count() -> int:
	return _active_blood.size()


func active_fragment_count() -> int:
	return _active_fragments.size()


func _prewarm_blood_pool() -> void:
	for _index: int in range(BLOOD_POOL_SIZE):
		var burst := BloodBurstScript.new() as HopliteBloodBurst
		burst.name = "PooledBloodBurst"
		add_child(burst)
		burst.prepare_for_pool(Callable(self, "release_blood"))
		_blood_pool.append(burst)


func _acquire_blood() -> HopliteBloodBurst:
	for burst: HopliteBloodBurst in _blood_pool:
		if not burst.active:
			blood_reuse_count += 1
			return burst
	# Preserve the hard visual budget: the oldest effect is the least visible and
	# is recycled in O(1), without a SceneTree group scan or allocation.
	if _active_blood.is_empty():
		return null
	var oldest := _active_blood[0]
	_release_blood_at(0)
	blood_reuse_count += 1
	return oldest


func _release_blood_at(index: int) -> void:
	var burst := _active_blood[index]
	_active_blood.remove_at(index)
	_blood_expire_at.remove_at(index)
	if is_instance_valid(burst):
		burst.deactivate_to_pool()


func _grow_fragment_pool(key: String, count: int, runtime_growth: bool) -> void:
	var package_scene := _registered_packages.get(key) as PackedScene
	if package_scene == null:
		return
	var pool: Array = _fragment_pools.get(key, [])
	var initial_size := pool.size()
	for _index: int in range(count):
		var fragment := SpartanDetachedLimbScript.new() as HopliteSpartanDetachedLimb
		fragment.name = "PooledSpartanDetached"
		add_child(fragment)
		if fragment.prepare(package_scene, Callable(self, "release_fragment")):
			pool.append(fragment)
		else:
			fragment.queue_free()
	_fragment_pools[key] = pool
	var created := pool.size() - initial_size
	if runtime_growth:
		fragment_runtime_growth_count += created
	else:
		_prewarmed_fragment_count += created


func _acquire_fragment(key: String) -> HopliteSpartanDetachedLimb:
	var pool: Array = _fragment_pools.get(key, [])
	for value: Variant in pool:
		var fragment := value as HopliteSpartanDetachedLimb
		if fragment != null and not fragment.active:
			return fragment
	_grow_fragment_pool(key, SPARTAN_FRAGMENT_GROW_SIZE, true)
	pool = _fragment_pools.get(key, [])
	for value: Variant in pool:
		var fragment := value as HopliteSpartanDetachedLimb
		if fragment != null and not fragment.active:
			return fragment
	return null


func _release_fragment_at(index: int) -> void:
	var fragment := _active_fragments[index]
	_remove_fragment_at(index)
	if is_instance_valid(fragment):
		fragment.deactivate_to_pool()
		if fragment.get_parent() != self:
			fragment.reparent(self, false)


func _remove_fragment_at(index: int) -> void:
	_active_fragments.remove_at(index)
	_fragment_retire_at.remove_at(index)
	_fragment_expire_at.remove_at(index)
	_fragment_retired.remove_at(index)


func _update_processing_state() -> void:
	set_process(not _active_blood.is_empty() or not _active_fragments.is_empty())


func _package_key(package_scene: PackedScene) -> String:
	if not package_scene.resource_path.is_empty():
		return package_scene.resource_path
	return "instance:%d" % package_scene.get_instance_id()
