extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const SpawnRequest = preload("res://scripts/enemy/enemy_spawn_request.gd")
const RegistryScript = preload("res://scripts/enemy/combatant_registry.gd")


class RejectingRegistry extends RegistryScript:
	var rejected_ref: WeakRef
	var saw_ready: bool = false
	var saw_inside_tree: bool = false
	var saw_combatant_group: bool = false

	func register_combatant(combatant: Node) -> bool:
		rejected_ref = weakref(combatant)
		saw_ready = combatant.is_node_ready()
		saw_inside_tree = combatant.is_inside_tree()
		saw_combatant_group = combatant.is_in_group("combatant")
		return false


var failures: Array[String] = []
var registered_ids: Array[int] = []
var unregistered_ids: Array[int] = []
var ready_observations: Array[bool] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.name = "EnemyFactoryRegistryProbeStage"
	root.add_child(stage)
	var registry: RegistryScript = RegistryScript.new()
	stage.add_child(registry)
	registry.combatant_registered.connect(func(combatant: Node) -> void:
		registered_ids.append(combatant.get_instance_id())
		ready_observations.append(
			combatant.is_node_ready()
			and combatant.is_inside_tree()
			and combatant.is_in_group("combatant")
		)
	)
	registry.combatant_unregistered.connect(func(instance_id: int) -> void:
		unregistered_ids.append(instance_id)
	)

	var athenian := _spawn_registered(stage, registry, "RegisteredAthenian", &"athenian", false)
	var spartan := _spawn_registered(stage, registry, "RegisteredSpartan", &"spartan", true)
	var untracked := _spawn_untracked(stage)
	if athenian == null or spartan == null or untracked == null:
		_finish(stage)
		return
	spartan.set_process(false)
	spartan.set_physics_process(false)

	_expect(registry.registered_count() == 2, "factory registration count changed")
	_expect(_same_nodes(registry.snapshot(), [athenian, spartan]), "factory registration order changed")
	_expect(_same_nodes(registry.snapshot(&"athenian"), [athenian]), "factory faction index changed")
	_expect(_same_nodes(registry.snapshot(&"spartan", true, true), [spartan]), "factory living/AI filter changed")
	_expect(not registry.contains(untracked), "spawn without explicit registry was registered")
	_expect(not registry.register_combatant(athenian), "factory registration was not idempotent")
	_expect(registered_ids.size() == 2, "factory emitted duplicate registration")
	_expect(ready_observations == [true, true], "factory registered before _ready/groups completed")

	var orphan_registry: RegistryScript = RegistryScript.new()
	var invalid_request: SpawnRequest = SpawnRequest.new()
	invalid_request.archetype = &"swordsman"
	invalid_request.ai_enabled = false
	invalid_request.combatant_registry = orphan_registry
	var children_before := stage.get_child_count()
	_expect(EnemyFactory.spawn_request(stage, invalid_request) == null, "out-of-tree registry was accepted")
	_expect(stage.get_child_count() == children_before, "invalid registry constructed an enemy")
	orphan_registry.free()

	var rejecting_registry := RejectingRegistry.new()
	rejecting_registry.name = "RejectingRegistry"
	stage.add_child(rejecting_registry)
	var rejected_request: SpawnRequest = SpawnRequest.new()
	rejected_request.archetype = &"swordsman"
	rejected_request.ai_enabled = true
	rejected_request.combatant_registry = rejecting_registry
	var rejecting_children_before := stage.get_child_count()
	var combatant_group_before := get_nodes_in_group("combatant").size()
	_expect(EnemyFactory.spawn_request(stage, rejected_request) == null, "post-ready registry rejection returned a combatant")
	_expect(rejecting_registry.saw_ready and rejecting_registry.saw_inside_tree and rejecting_registry.saw_combatant_group,
		"rejecting registry did not observe a ready grouped combatant")
	_expect(stage.get_child_count() == rejecting_children_before, "rejected combatant remained parented")
	_expect(get_nodes_in_group("combatant").size() == combatant_group_before, "rejected combatant remained discoverable by group")
	_expect(rejecting_registry.rejected_ref != null and rejecting_registry.rejected_ref.get_ref() != null,
		"rejected combatant was not available for deferred-free verification")
	await process_frame
	_expect(rejecting_registry.rejected_ref.get_ref() == null, "rejected combatant survived deferred free")

	athenian.call("_die", false)
	_expect(registry.registered_count() == 2, "death prematurely unregistered factory combatant")
	_expect(registry.living_count() == 1, "death did not update factory registry liveness")
	_expect(registry.snapshot().has(athenian), "dead factory combatant left registered snapshot")
	_expect(not registry.snapshot(StringName(), true).has(athenian), "dead factory combatant remained living")

	var spartan_id := spartan.get_instance_id()
	var spartan_ref: WeakRef = weakref(spartan)
	spartan.queue_free()
	await process_frame
	_expect(spartan_ref.get_ref() == null, "living factory combatant survived queue_free")
	_expect(registry.registered_count() == 1, "living tree exit did not unregister factory combatant")
	_expect(unregistered_ids.has(spartan_id), "living tree-exit signal missing")

	var athenian_ref: WeakRef = weakref(athenian)
	var untracked_ref: WeakRef = weakref(untracked)
	athenian.queue_free()
	untracked.queue_free()
	await process_frame
	_expect(registry.registered_count() == 0, "factory registry retained dead combatant after tree exit")
	_expect(athenian_ref.get_ref() == null and untracked_ref.get_ref() == null, "factory registry retained a strong reference")
	_expect(unregistered_ids.size() == 2, "factory unregister signal count changed")
	_finish(stage)


func _spawn_registered(
	stage: Node3D,
	registry: RegistryScript,
	combatant_name: String,
	faction: StringName,
	ai_enabled: bool
) -> HopliteAthenianEnemy:
	var request: SpawnRequest = SpawnRequest.new()
	request.archetype = &"swordsman"
	request.ai_enabled = ai_enabled
	request.faction = faction
	request.mass_battle_mode = true
	request.has_name_override = true
	request.name_override = combatant_name
	request.combatant_registry = registry
	return EnemyFactory.spawn_request(stage, request)


func _spawn_untracked(stage: Node3D) -> HopliteAthenianEnemy:
	var request: SpawnRequest = SpawnRequest.new()
	request.archetype = &"swordsman"
	request.ai_enabled = false
	request.mass_battle_mode = true
	request.has_name_override = true
	request.name_override = "UntrackedControl"
	return EnemyFactory.spawn_request(stage, request)


func _same_nodes(actual: Array[Node], expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index: int in range(actual.size()):
		if actual[index] != expected[index]:
			return false
	return true


func _finish(stage: Node) -> void:
	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY_FACTORY_REGISTRY_PROBE PASS: explicit post-ready registration and lifecycle preserved")
		quit(0)
		return
	for failure: String in failures:
		push_error("[ENEMY FACTORY REGISTRY] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
