extends SceneTree
const Document = preload("res://scripts/world_editor/world_document.gd")
const Runtime = preload("res://scripts/world_editor/world_runtime.gd")
const Composer = preload("res://scripts/enemy_v2/battlefield/battlefield_composer.gd")
var failures: Array[String] = []
var hit_count := 0
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _on_hit(_target: Node, _zone: StringName, _hit: Variant) -> void:
	hit_count += 1
func _run() -> void:
	for mode: String in ["player", "armies"]:
		var doc := Document.new()
		var props := Composer.defaults()
		props.mode = mode
		for camp: String in ["enemy","ally"]:
			for role: String in Composer.ROLES: props[camp+"_"+role] = 1
		var zone := Document.entity("battlefield","Created battlefield",Vector3.ZERO,props)
		doc.data.entities = [Document.entity("surface","Floor",Vector3(0,-0.2,0),{"shape":"floor","size":[100,0.4,100],"material":"pavers"}),Document.entity("player_spawn","Player",Vector3.ZERO,{}),zone]
		check(Composer.populate(doc.data,zone).errors.is_empty(),"composition rejected")
		var host := Node3D.new()
		root.add_child(host)
		current_scene = host
		var runtime := Runtime.new()
		host.add_child(runtime)
		runtime.build(Document.from_json(doc.to_json()),false)
		for frame in range(300):
			if runtime.pending_enemy_spawns.is_empty(): break
			await process_frame
		var service: Node = runtime.battlefield_runtime
		service.set_process(false)
		for army: RefCounted in service.armies.values(): army.next_orders = 0.0
		service._refresh_snapshot()
		check(service.armies.size()==(1 if mode=="player" else 2),"wrong commander count")
		for army: RefCounted in service.armies.values():
			army.runtime.set_process(false)
			for id: StringName in army.runtime.groups:
				check(army.runtime.battle_layout.records[id].has("command_assignment"),mode+": commander update failed")
		runtime.player.set_physics_process(false)
		runtime.player.combat_hit.connect(_on_hit)
		hit_count = 0
		var enemies: Array[Node] = []
		for list: Array in runtime.enemies_by_group.values():
			for actor: Node3D in list:
				actor.set_physics_process(false)
				actor.combat.set_physics_process(false)
				actor.global_position = runtime.player.global_position + Vector3(1,0,0)
				var before: float = actor.health
				var accepted: Variant = actor.receive_ai_hit(1.0,runtime.player,Vector3.RIGHT)
				check(accepted is bool,"receive_ai_hit must return bool")
				if actor.faction == &"spartan":
					check(accepted == false and actor.health == before,"friendly impact accepted")
				else:
					check(accepted == true and actor.health < before,"hostile impact rejected")
					enemies.append(actor)
		runtime.player.spiral_down_air_impact_pending = true
		runtime.player._trigger_spiral_down_impact()
		check(hit_count == enemies.size(),"spiral impact aborted: " + mode)
		for actor: Node in enemies:
			actor.dead = true
			check(actor.receive_ai_hit(1.0,runtime.player,Vector3.RIGHT) == false,"dead target accepted")
		host.queue_free()
		await process_frame
		await process_frame
	print("BATTLEFIELD_CRASH_REGRESSION ","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
