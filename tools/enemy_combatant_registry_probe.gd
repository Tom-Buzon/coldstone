extends SceneTree

const RegistryScript = preload("res://scripts/enemy/combatant_registry.gd")


class ProbeCombatant extends Node3D:
	signal died(combatant: Node)

	var faction: StringName = &"athenian"
	var ai_enabled: bool = true
	var dead: bool = false

	func configure(combatant_name: String, combatant_faction: StringName, enabled: bool) -> void:
		name = combatant_name
		faction = combatant_faction
		ai_enabled = enabled

	func is_dead_for_combat() -> bool:
		return dead

	func die_for_probe() -> void:
		if dead:
			return
		dead = true
		died.emit(self)


class InvalidDeathCombatant extends Node3D:
	signal died
	var faction: StringName = &"athenian"
	var ai_enabled: bool = true


class InvalidPropertyCombatant extends Node3D:
	var faction: String = "athenian"
	var ai_enabled: int = 1


var failures: Array[String] = []
var registered_ids: Array[int] = []
var unregistered_ids: Array[int] = []
var liveness_events: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.name = "CombatantRegistryProbeStage"
	root.add_child(stage)
	var registry: RegistryScript = RegistryScript.new()
	registry.name = "ProbeCombatantRegistry"
	stage.add_child(registry)
	registry.combatant_registered.connect(_on_registered)
	registry.combatant_unregistered.connect(_on_unregistered)
	registry.combatant_liveness_changed.connect(_on_liveness_changed)

	var athenian := _make_combatant(stage, "Athenian", &"athenian", true)
	var spartan := _make_combatant(stage, "Spartan", &"spartan", true)
	var passive := _make_combatant(stage, "Passive", &"athenian", false)
	var outside_tree := ProbeCombatant.new()
	outside_tree.configure("OutsideTree", &"athenian", true)
	var invalid_shape := Node3D.new()
	stage.add_child(invalid_shape)
	var invalid_death := InvalidDeathCombatant.new()
	stage.add_child(invalid_death)
	var invalid_properties := InvalidPropertyCombatant.new()
	stage.add_child(invalid_properties)

	_expect(registry.is_in_group("combatant_registry"), "registry discovery group missing")
	_expect(not registry.register_combatant(outside_tree), "outside-tree combatant was registered")
	_expect(not registry.register_combatant(invalid_shape), "node without combatant contract was registered")
	_expect(not registry.register_combatant(invalid_death), "incompatible death signal was registered")
	_expect(not registry.register_combatant(invalid_properties), "invalid property types were registered")
	var detached_registry: RegistryScript = RegistryScript.new()
	_expect(not detached_registry.register_combatant(athenian), "out-of-tree registry accepted a live combatant")
	detached_registry.free()
	_expect(registry.register_combatant(athenian), "Athenian registration failed")
	_expect(registry.register_combatant(spartan), "Spartan registration failed")
	_expect(registry.register_combatant(passive), "passive registration failed")
	_expect(not registry.register_combatant(spartan), "duplicate registration was accepted")
	_expect(registry.registered_count() == 3, "registered count changed")
	_expect(registry.living_count() == 3, "initial living count changed")
	_expect(registry.living_count(&"athenian") == 2, "faction living count changed")
	_expect(registry.living_count(StringName(), true) == 2, "AI-enabled living count changed")
	_expect(_same_nodes(registry.snapshot(), [athenian, spartan, passive]), "registration order changed")
	_expect(_same_nodes(registry.snapshot(&"spartan"), [spartan]), "faction snapshot changed")
	_expect(_same_nodes(registry.snapshot(&"athenian", true, true), [athenian]), "combined filter changed")

	var detached_snapshot: Array[Node] = registry.snapshot()
	detached_snapshot.clear()
	_expect(registry.registered_count() == 3, "caller mutated registry through snapshot")
	passive.faction = &"spartan"
	passive.ai_enabled = true
	_expect(_same_nodes(registry.snapshot(&"spartan"), [spartan, passive]), "dynamic faction query changed")
	_expect(registry.living_count(StringName(), true) == 3, "dynamic AI-enabled query changed")
	passive.faction = &"athenian"
	passive.ai_enabled = false

	spartan.die_for_probe()
	_expect(registry.registered_count() == 3, "death unregistered combatant before tree exit")
	_expect(registry.living_count() == 2, "death did not update living count")
	_expect(not registry.snapshot().is_empty() and registry.snapshot().has(spartan), "dead combatant disappeared from registered snapshot")
	_expect(not registry.snapshot(StringName(), true).has(spartan), "dead combatant remained in living snapshot")
	_expect(liveness_events == ["%d:false" % spartan.get_instance_id()], "death liveness signal changed")

	spartan.dead = false
	_expect(registry.refresh_liveness(spartan), "manual liveness refresh did not restore living state")
	_expect(registry.living_count() == 3, "refreshed living count changed")
	_expect(liveness_events == [
		"%d:false" % spartan.get_instance_id(),
		"%d:true" % spartan.get_instance_id(),
	], "refresh liveness signal changed")
	spartan.die_for_probe()
	_expect(liveness_events.size() == 3 and liveness_events.back() == "%d:false" % spartan.get_instance_id(), "persistent death callback was not restored after revival")
	spartan.dead = false
	_expect(registry.refresh_liveness(spartan), "second liveness refresh failed")
	_expect(registry.unregister_combatant(spartan), "Spartan manual unregister failed")
	_expect(registry.register_combatant(spartan), "Spartan re-registration failed")
	_expect(_same_nodes(registry.snapshot(), [athenian, passive, spartan]), "middle re-registration did not move to tail")
	spartan.die_for_probe()
	_expect(not registry.snapshot(StringName(), true).has(spartan), "re-registered death callback was not restored")
	_expect(liveness_events.size() == 5 and liveness_events.back() == "%d:false" % spartan.get_instance_id(), "re-registered death signal changed")

	_expect(registry.unregister_combatant(athenian), "Athenian manual unregister failed")
	_expect(not registry.unregister_combatant(athenian), "duplicate unregister was accepted")
	_expect(not registry.contains(athenian), "manually unregistered combatant remained contained")
	_expect(registry.register_combatant(athenian), "Athenian re-registration failed")
	_expect(_same_nodes(registry.snapshot(), [passive, spartan, athenian]), "first-element re-registration did not move to tail")

	var athenian_id := athenian.get_instance_id()
	var athenian_ref: WeakRef = weakref(athenian)
	var unregister_count_before_exit := unregistered_ids.size()
	athenian.queue_free()
	await process_frame
	_expect(athenian_ref.get_ref() == null, "tree-exited Athenian remained alive")
	_expect(registry.registered_count() == 2, "tree exit did not unregister combatant")
	_expect(unregistered_ids.size() == unregister_count_before_exit + 1 and unregistered_ids.back() == athenian_id, "tree-exit unregister signal missing")

	var spartan_ref: WeakRef = weakref(spartan)
	var passive_ref: WeakRef = weakref(passive)
	spartan.queue_free()
	passive.queue_free()
	await process_frame
	_expect(registry.registered_count() == 0, "registry retained entries after teardown")
	_expect(spartan_ref.get_ref() == null and passive_ref.get_ref() == null, "registry retained a strong combatant reference")
	_expect(registered_ids.size() == 5, "registration signal count changed")
	_expect(unregistered_ids.size() == 5, "unregistration signal count changed")

	outside_tree.free()
	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("ENEMY_COMBATANT_REGISTRY_PROBE PASS: registration, filters, liveness, ordering and weak teardown preserved")
		quit(0)
		return
	for failure: String in failures:
		push_error("[ENEMY COMBATANT REGISTRY] " + failure)
	quit(1)


func _make_combatant(
	stage: Node3D,
	combatant_name: String,
	combatant_faction: StringName,
	ai_enabled: bool
) -> ProbeCombatant:
	var combatant := ProbeCombatant.new()
	combatant.configure(combatant_name, combatant_faction, ai_enabled)
	stage.add_child(combatant)
	return combatant


func _same_nodes(actual: Array[Node], expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index: int in range(actual.size()):
		if actual[index] != expected[index]:
			return false
	return true


func _on_registered(combatant: Node) -> void:
	registered_ids.append(combatant.get_instance_id())


func _on_unregistered(instance_id: int) -> void:
	unregistered_ids.append(instance_id)


func _on_liveness_changed(combatant: Node, living: bool) -> void:
	liveness_events.append("%d:%s" % [combatant.get_instance_id(), str(living)])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
