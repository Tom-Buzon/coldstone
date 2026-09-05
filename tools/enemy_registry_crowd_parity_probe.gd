extends SceneTree

const EnemyFactory = preload("res://scripts/enemy/enemy_factory.gd")
const SpawnRequest = preload("res://scripts/enemy/enemy_spawn_request.gd")
const RegistryScript = preload("res://scripts/enemy/combatant_registry.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.name = "RegistryCrowdParityStage"
	root.add_child(stage)
	var registry: RegistryScript = RegistryScript.new()
	registry.name = "ParityRegistry"
	stage.add_child(registry)

	var athenian_active := _spawn(stage, registry, "AthenianActive", &"athenian", true)
	var athenian_passive := _spawn(stage, registry, "AthenianPassive", &"athenian", false)
	var spartan_active := _spawn(stage, registry, "SpartanActive", &"spartan", true)
	var spartan_passive := _spawn(stage, registry, "SpartanPassive", &"spartan", false)
	var all_combatants: Array[Node] = [athenian_active, athenian_passive, spartan_active, spartan_passive]
	for combatant: Node in all_combatants:
		_expect(combatant != null, "factory returned null for parity fixture")
	if all_combatants.has(null):
		_finish(stage, all_combatants, registry)
		return

	var initial_group_ai := _group_nodes(&"combatant_ai")
	var initial_registry_ai := registry.snapshot(StringName(), true, true)
	_expect(_same_set(initial_group_ai, initial_registry_ai), "initial combatant_ai/registry AI views diverged")
	_expect(_same_order(initial_group_ai, initial_registry_ai), "initial combatant_ai/registry order diverged")
	_expect(
		_same_set(_living_group_nodes(&"enemy"), registry.snapshot(&"athenian", true)),
		"living enemy group did not match Athenian registry snapshot"
	)
	_expect(
		_same_order(_living_group_nodes(&"enemy"), registry.snapshot(&"athenian", true)),
		"living enemy group/Athenian registry order diverged"
	)
	_expect(
		_same_set(_living_group_nodes(&"spartan_ally"), registry.snapshot(&"spartan", true)),
		"living Spartan group did not match Spartan registry snapshot"
	)
	_expect(
		_same_order(_living_group_nodes(&"spartan_ally"), registry.snapshot(&"spartan", true)),
		"living Spartan group/registry order diverged"
	)
	_expect(_same_set(initial_group_ai, [athenian_active, spartan_active]), "spawn-time combatant_ai membership changed")

	athenian_active.set_ai_participation(false)
	spartan_active.set_ai_participation(false)
	athenian_passive.set_ai_participation(true)
	spartan_passive.set_ai_participation(true)

	var group_after_flip := _group_nodes(&"combatant_ai")
	var registry_after_flip := registry.snapshot(StringName(), true, true)
	_expect(_same_set(group_after_flip, [athenian_passive, spartan_passive]), "combatant_ai did not follow atomic runtime participation")
	_expect(_same_set(registry_after_flip, [athenian_passive, spartan_passive]), "registry AI filter stopped reflecting current ai_enabled values")
	_expect(_same_set(group_after_flip, registry_after_flip), "runtime AI groups and registry diverged after participation flip")
	_expect(
		_same_set(_living_group_nodes(&"enemy"), registry.snapshot(&"athenian", true)),
		"AI flip changed Athenian faction parity"
	)
	_expect(
		_same_order(_living_group_nodes(&"enemy"), registry.snapshot(&"athenian", true)),
		"AI flip changed Athenian faction order"
	)
	_expect(
		_same_set(_living_group_nodes(&"spartan_ally"), registry.snapshot(&"spartan", true)),
		"AI flip changed Spartan faction parity"
	)
	_expect(
		_same_order(_living_group_nodes(&"spartan_ally"), registry.snapshot(&"spartan", true)),
		"AI flip changed Spartan faction order"
	)

	_finish(stage, all_combatants, registry)


func _spawn(
	stage: Node3D,
	registry: RegistryScript,
	combatant_name: String,
	faction: StringName,
	ai_enabled: bool
) -> HopliteAthenianEnemy:
	var request: SpawnRequest = SpawnRequest.new()
	request.archetype = &"swordsman"
	request.faction = faction
	request.ai_enabled = ai_enabled
	request.has_name_override = true
	request.name_override = combatant_name
	request.combatant_registry = registry
	return EnemyFactory.spawn_request(stage, request)


func _group_nodes(group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in get_nodes_in_group(group_name):
		result.append(node)
	return result


func _living_group_nodes(group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in get_nodes_in_group(group_name):
		if node.has_method("is_dead_for_combat") and bool(node.call("is_dead_for_combat")):
			continue
		result.append(node)
	return result


func _same_set(actual: Array[Node], expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for node: Node in actual:
		if not expected.has(node):
			return false
	return true


func _same_order(actual: Array[Node], expected: Array[Node]) -> bool:
	if actual.size() != expected.size():
		return false
	for index: int in range(actual.size()):
		if actual[index] != expected[index]:
			return false
	return true


func _finish(stage: Node3D, combatants: Array[Node], registry: RegistryScript) -> void:
	var registry_ref: WeakRef = weakref(registry)
	var combatant_refs: Array[WeakRef] = []
	for combatant: Node in combatants:
		if combatant != null:
			combatant_refs.append(weakref(combatant))
	stage.queue_free()
	await process_frame
	await process_frame
	_expect(registry_ref.get_ref() == null, "parity registry remained alive after teardown")
	for combatant_ref: WeakRef in combatant_refs:
		_expect(combatant_ref.get_ref() == null, "parity combatant remained alive after teardown")
	_expect(get_nodes_in_group("combatant_registry").is_empty(), "parity registry group survived teardown")
	if failures.is_empty():
		print("ENEMY_REGISTRY_CROWD_PARITY_PROBE PASS: initial and dynamic registry/group parity preserved")
		quit(0)
		return
	for failure: String in failures:
		push_error("[ENEMY REGISTRY CROWD PARITY] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
