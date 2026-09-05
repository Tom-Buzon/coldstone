extends SceneTree

const Catalog = preload("res://scripts/enemy_v2/hoplite_v2_catalog.gd")
const WorldDocument = preload("res://scripts/world_editor/world_document.gd")
const WorldRuntime = preload("res://scripts/world_editor/world_runtime.gd")
const Migration = preload("res://scripts/enemy/enemy_runtime_migration.gd")
const HopliteV2TroopRuntime = preload("res://scripts/enemy_v2/hoplite_v2_troop_runtime.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var error := change_scene_to_file("res://world_editor.tscn")
	_expect(error == OK, "World Forge scene failed to load")
	if error != OK:
		_finish()
		return
	await process_frame
	await process_frame
	var editor := current_scene
	var category := editor.get("library_category") as OptionButton
	_expect(category != null, "Forge character category is unavailable")
	if category == null:
		_finish()
		return
	category.select(4)
	editor.call("_refresh_library")
	await process_frame

	var library := editor.get("library_items") as VBoxContainer
	var phalanx_button: Button
	var duel_button: Button
	var v2_character_buttons := 0
	for child: Node in library.get_children():
		if not child is Button:
			continue
		var button := child as Button
		if "ENEMY V2 (LAB)" in button.text:
			v2_character_buttons += 1
		if "PHALANGE V2" in button.text:
			phalanx_button = button
		if "DUEL V2 LAB" in button.text:
			duel_button = button
	_expect(v2_character_buttons == 5, "Forge must offer the five explicit V2 character brushes")
	_expect(phalanx_button != null, "Phalange V2 laboratory preset is missing")
	_expect(duel_button != null, "Duel V2 laboratory preset is missing")
	if phalanx_button == null:
		_finish()
		return
	phalanx_button.pressed.emit()
	var preset := (editor.get("brush_properties") as Dictionary).duplicate(true)
	_expect(int(preset.get("count", 0)) == 24, "Phalange V2 preset must contain exactly 24 equipped units")
	_expect(String(preset.get("formation", "")) == "phalanx", "Phalange V2 preset must use the phalanx layout")
	_expect(int(preset.get("formation_columns", 0)) == 8, "Phalange V2 preset must form three ranks of eight")
	_expect(String(preset.get("v2_animation", "")) == "block_idle", "Phalange V2 preset must start in the guarded formation pose")
	_expect(bool(preset.get("v2_combat_lab", false)), "Phalange V2 preset must enable the V2 combat components")
	_expect(String(preset.get("v2_troop_mode", "")) == "hoplite_phalanx", "Phalange V2 preset must opt into the shared troop runtime")
	var composition := preset.get("composition", []) as Array
	_expect(composition.size() == 2, "Phalange V2 preset must preserve standard/veteran identities")
	if composition.size() == 2:
		_expect(String((composition[0] as Dictionary).get("archetype", "")) == String(Catalog.FORGE_HOPLITE_ID), "standard V2 Forge ID is missing from the phalanx")
		_expect(String((composition[1] as Dictionary).get("archetype", "")) == String(Catalog.FORGE_VETERAN_ID), "veteran V2 Forge ID is missing from the phalanx")
	var duel_preset: Dictionary = {}
	if duel_button != null:
		duel_button.pressed.emit()
		duel_preset = (editor.get("brush_properties") as Dictionary).duplicate(true)
		_expect(int(duel_preset.get("count", 0)) == 1, "Duel V2 preset must contain one actor")
		_expect(bool(duel_preset.get("v2_combat_lab", false)), "Duel V2 preset must explicitly opt into combat")

	var runtime := WorldRuntime.new()
	get_root().add_child(runtime)
	var troop_runtime := HopliteV2TroopRuntime.new()
	troop_runtime.name = "EnemyV2TroopRuntimeProbe"
	runtime.add_child(troop_runtime)
	runtime.enemy_v2_troop_runtime = troop_runtime
	var holder := Node3D.new()
	runtime.add_child(holder)
	var phalanx_target := Node3D.new()
	phalanx_target.position = Vector3(0.0, 0.0, 3.2)
	holder.add_child(phalanx_target)
	var entity := WorldDocument.entity("enemy_group", "Phalange V2 probe", Vector3.ZERO, preset)
	var phalanx_units := runtime.spawn_enemy_group(entity, phalanx_target, holder, 24, 0, true)
	_expect(phalanx_units.size() == 24, "Forge runtime could not instantiate the complete V2 phalanx")
	for actor: Node in phalanx_units:
		_expect(StringName(actor.get_meta("enemy_runtime_generation", &"")) == &"modular_v2_forge_lab", "Forge V2 actor lost its explicit laboratory runtime tag")
		_expect(bool(actor.get_meta("forge_enemy_v2", false)), "Forge V2 actor is not identifiable as a laboratory actor")
		var presentation: Variant = actor.get("presentation")
		var animation: Variant = actor.get("animation")
		var equipment: Variant = actor.get("equipment")
		var performance_lod: Variant = actor.get("performance_lod")
		_expect(presentation != null and (presentation.get("lod_meshes") as Array).size() == 3, "Forge V2 actor does not expose all three LOD meshes")
		_expect(animation != null, "Forge V2 actor has no animation component")
		_expect(equipment != null and equipment.get("weapon_attachment") != null and equipment.get("shield_attachment") != null, "Forge V2 actor has no spear/shield attachments")
		var shield_hitbox := equipment.get("shield_hitbox") as HopliteShieldHitbox if equipment != null else null
		_expect(shield_hitbox != null and shield_hitbox.phalanx_wall_run_surface, "Phalange V2 shield did not opt into Shield Run")
		if shield_hitbox != null:
			shield_hitbox.set_guard_active(true)
			_expect((shield_hitbox.collision_layer & 64) != 0 and shield_hitbox.is_in_group(&"wall_run_phalanx_shield"), "a raised Phalange V2 shield is not exposed to the player wall-run probe")
			shield_hitbox.set_guard_active(false)
		_expect(performance_lod != null, "Forge V2 actor has no runtime LOD controller")
		_expect(actor.get("combat") != null and actor.get("health_component") != null, "Phalange V2 actor did not install combat and health")
		_expect(bool(actor.get("troop_controlled")), "Phalange V2 actor retained autonomous duel control")
	_expect(troop_runtime.groups.size() == 1, "Forge phalanx did not register exactly one shared troop")
	for frame in range(60):
		troop_runtime._process(1.0 / 60.0)
	var snapshot := troop_runtime.group_snapshot(&"phalange_v2_lab")
	_expect(int(snapshot.get("member_count", 0)) == 24, "Troop runtime lost phalanx members")
	_expect(int(snapshot.get("columns", 0)) == 8, "Troop runtime lost the authored eight-column profile")
	_expect(int(snapshot.get("front_rank_count", 0)) == 8, "Only one rank of eight may receive attack permissions")
	_expect(int(snapshot.get("attack_lease_count", 0)) <= 3, "Troop runtime exceeded the shared attack budget")
	_expect(int(snapshot.get("decision_ticks", 0)) <= 9, "Troop decisions unexpectedly ran at per-frame cadence")
	if not duel_preset.is_empty():
		var duel_target := Node3D.new()
		duel_target.position = Vector3(0.0, 0.0, 2.0)
		holder.add_child(duel_target)
		var duel_entity := WorldDocument.entity("enemy_group", "Duel V2 probe", Vector3.ZERO, duel_preset)
		var duel_units := runtime.spawn_enemy_group(duel_entity, duel_target, holder, 1, 0, false)
		_expect(duel_units.size() == 1, "Forge runtime could not instantiate the Duel V2 preset")
		if duel_units.size() == 1:
			var duel_actor := duel_units[0] as Node
			_expect(duel_actor.get("combat") != null and duel_actor.get("health_component") != null, "Duel V2 preset did not install combat and health components")
	_expect(Migration.resolved_generation_for(&"ngeneral") == Migration.RuntimeGeneration.LEGACY_V1, "Forge laboratory wiring changed the production Hoplite route")
	runtime.free()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("HOPLITE_V2_FORGE_PROBE PASS: characters=5 phalanx=24 duel=1 equipment=ready lod=runtime production=legacy_v1")
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 FORGE] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
