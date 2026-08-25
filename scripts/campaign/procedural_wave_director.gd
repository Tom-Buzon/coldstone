extends Node
class_name HopliteProceduralWaveDirector

const EnemyFactoryScript = preload("res://scripts/enemy/enemy_factory.gd")
const ArchetypesScript = preload("res://scripts/enemy/enemy_archetypes.gd")

signal wave_started(index: int, total: int, title: String, total_enemies: int)
signal wave_progress(alive: int, remaining_to_spawn: int, defeated: int)
signal enemy_spawned(enemy: HopliteAthenianEnemy)
signal miniboss_spawned(enemy: HopliteAthenianEnemy, title: String)
signal boss_spawned(enemy: HopliteAthenianEnemy)
signal boss_phase_started(phase: int, title: String)
signal zone_completed

const LEGION_SIZE := 10
const MAX_ACTIVE_LEGIONS := 3
const MAX_CONCURRENT := LEGION_SIZE * MAX_ACTIVE_LEGIONS + 2
const SPAWN_BATCH := 2
const SPAWN_INTERVAL := 0.32
const CORPSE_LIFETIME := 4.5
const OVERLAP_REMAINDER := 3
const DUNGEON_SURGE_INTERVAL := 1.0
const DUNGEON_SURGE_TICKS := 10
const DUNGEON_SURGE_PER_TICK := 2

var rng := RandomNumberGenerator.new()
var enemy_parent: Node3D
var player: Node3D
var zone_id: StringName
var spawn_points: Array[Vector3] = []
var entry_reinforcement_points: Array[Vector3] = []
var boss_spawn := Vector3.ZERO
var wave_plan: Array[Dictionary] = []
var spawn_queue: Array[Dictionary] = []
var active_enemies: Dictionary = {}
var current_wave: int = -1
var wave_defeated: int = 0
var spawn_timer: float = 0.0
var intermission_timer: float = 0.0
var running := false
var boss: HopliteAthenianEnemy
var boss_defeated := false
var safe_bounds := Rect2(-100.0, -100.0, 200.0, 200.0)
var safety_audit_timer := 0.0
var encounter_definition: Dictionary = {}
var deployment_stage := -1
var deployment_locked := false
var completion_elite: HopliteAthenianEnemy
var encounter_completed := false
var dungeon_surge_active := false
var dungeon_surge_timer := 0.0
var dungeon_surge_ticks_remaining := 0
var dungeon_surge_spawned := 0

func configure(parent: Node3D, target: Node3D, id: StringName, points: Array[Vector3], boss_position: Vector3, generation_seed: int, safe_bounds_value: Rect2 = Rect2(-100.0, -100.0, 200.0, 200.0), entry_points: Array[Vector3] = []) -> void:
	stop_and_clear()
	enemy_parent = parent
	player = target
	zone_id = id
	spawn_points = points.duplicate()
	entry_reinforcement_points = entry_points.duplicate()
	boss_spawn = boss_position
	safe_bounds = safe_bounds_value
	safety_audit_timer = 0.0
	rng.seed = generation_seed ^ 0x51ED270B
	wave_plan = _plan_for_zone(id)

func start() -> void:
	prepare_initial_force()
	activate_prepared_force()

func prepare_initial_force() -> void:
	if wave_plan.is_empty() or player == null:
		return
	running = false
	deployment_locked = true
	current_wave = -1
	_begin_next_wave()
	# Initial deployment happens synchronously under the loading screen. The map
	# is populated on its first visible frame; progressive spawning is reserved
	# for reinforcements later in the encounter.
	while not spawn_queue.is_empty():
		_spawn_spec(spawn_queue.pop_front())
	wave_progress.emit(active_enemies.size(), 0, wave_defeated)

func activate_prepared_force() -> void:
	deployment_locked = false
	for value: Variant in active_enemies.values():
		if value is HopliteAthenianEnemy and is_instance_valid(value):
			var enemy := value as HopliteAthenianEnemy
			if not enemy.dead:
				enemy.ai_enabled = true
	running = true
	spawn_timer = SPAWN_INTERVAL

func stop_and_clear() -> void:
	running = false
	spawn_queue.clear()
	for value: Variant in active_enemies.values():
		if value is Node and is_instance_valid(value):
			(value as Node).queue_free()
	active_enemies.clear()
	boss = null
	completion_elite = null
	boss_defeated = false
	encounter_completed = false
	encounter_definition.clear()
	deployment_stage = -1
	deployment_locked = false
	dungeon_surge_active = false
	dungeon_surge_timer = 0.0
	dungeon_surge_ticks_remaining = 0
	dungeon_surge_spawned = 0
	current_wave = -1

func _process(delta: float) -> void:
	if not running:
		return
	_update_dungeon_entry_surge(delta)
	safety_audit_timer -= delta
	if safety_audit_timer <= 0.0:
		_audit_active_enemies()
		safety_audit_timer = 0.35
	var concurrent_limit := MAX_CONCURRENT + DUNGEON_SURGE_TICKS * DUNGEON_SURGE_PER_TICK if zone_id == &"dungeon" else MAX_CONCURRENT
	if not spawn_queue.is_empty() and active_enemies.size() < concurrent_limit:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			var available := mini(SPAWN_BATCH, concurrent_limit - active_enemies.size())
			for _index: int in range(available):
				if spawn_queue.is_empty():
					break
				_spawn_spec(spawn_queue.pop_front())
			spawn_timer = SPAWN_INTERVAL
			emit_signal("wave_progress", active_enemies.size(), spawn_queue.size(), wave_defeated)
	if spawn_queue.is_empty():
		_update_staged_deployment()

func _begin_next_wave() -> void:
	current_wave += 1
	if current_wave >= wave_plan.size():
		running = false
		zone_completed.emit()
		return
	var definition: Dictionary = wave_plan[current_wave]
	encounter_definition = definition
	wave_defeated = 0
	intermission_timer = 0.0
	deployment_stage = 0
	encounter_completed = false
	_queue_legion_set((definition.get("legions", []) as Array).slice(0, 2), 0)
	var total_enemies := (definition.get("legions", []) as Array).size() * LEGION_SIZE + 1
	wave_started.emit(current_wave + 1, wave_plan.size(), String(definition.get("title", "ASSAUT")), total_enemies)

func _queue_regular_wave(definition: Dictionary) -> void:
	_queue_legion_set(definition.get("legions", []) as Array, 0)

func _queue_legion_set(legions: Array, first_legion_index: int) -> void:
	if legions.is_empty():
		return
	var reserved_anchors := _active_legion_anchors()
	var legion_specs: Array = []
	for local_index: int in range(legions.size()):
		var legion: Dictionary = legions[local_index]
		var archetype := StringName(legion.get("archetype", &"nsbire1"))
		var legion_count := clampi(int(legion.get("count", LEGION_SIZE)), 1, LEGION_SIZE)
		var anchor := _select_legion_anchor(archetype, reserved_anchors)
		reserved_anchors.append(anchor)
		var specs: Array = []
		for formation_index: int in range(legion_count):
			specs.append({
				"archetype": archetype,
				"mass": true,
				"guard_index": formation_index,
				"formation_index": formation_index,
				"legion_id": _legion_id(first_legion_index + local_index),
				"legion_anchor": anchor
			})
		legion_specs.append(specs)
	# Interleave the legions: the director grows several distinct formations at
	# once instead of fully materialising ten identical actors on one frame.
	for formation_index: int in range(LEGION_SIZE):
		for specs: Array in legion_specs:
			if formation_index < specs.size():
				spawn_queue.append(specs[formation_index] as Dictionary)

func _update_staged_deployment() -> void:
	if encounter_completed or encounter_definition.is_empty():
		return
	var legions := encounter_definition.get("legions", []) as Array
	if legions.size() < 4:
		return
	if deployment_stage == 0 and (_is_legion_decimated(_legion_id(0)) or _is_legion_decimated(_legion_id(1))):
		deployment_stage = 1
		if zone_id == &"dungeon":
			_start_dungeon_entry_surge()
		_queue_legion_set([legions[2]], 2)
		spawn_timer = 0.0
	elif deployment_stage == 1 and _is_legion_decimated(_legion_id(2)):
		deployment_stage = 2
		_queue_final_assault(legions[3] as Dictionary)
		spawn_timer = 0.0

func _start_dungeon_entry_surge() -> void:
	if dungeon_surge_active or dungeon_surge_spawned > 0:
		return
	dungeon_surge_active = true
	dungeon_surge_timer = DUNGEON_SURGE_INTERVAL
	dungeon_surge_ticks_remaining = DUNGEON_SURGE_TICKS

func _update_dungeon_entry_surge(delta: float) -> void:
	if not dungeon_surge_active or encounter_completed:
		return
	dungeon_surge_timer -= delta
	while dungeon_surge_timer <= 0.0 and dungeon_surge_ticks_remaining > 0:
		_spawn_dungeon_entry_pair()
		dungeon_surge_ticks_remaining -= 1
		dungeon_surge_timer += DUNGEON_SURGE_INTERVAL
	if dungeon_surge_ticks_remaining <= 0:
		dungeon_surge_active = false

func _spawn_dungeon_entry_pair() -> void:
	var corners := entry_reinforcement_points
	if corners.size() < 2:
		corners = _entry_side_corners()
	for index: int in range(DUNGEON_SURGE_PER_TICK):
		var corner := corners[index % corners.size()] if not corners.is_empty() else _next_spawn_position()
		_spawn_spec({
			"archetype": &"nsbire1",
			"mass": true,
			"guard_index": 400 + dungeon_surge_spawned,
			"entry_surge": true,
			"position": corner
		})
		dungeon_surge_spawned += 1

func _entry_side_corners() -> Array[Vector3]:
	var player_position := player.global_position if player != null else Vector3.ZERO
	var left := safe_bounds.position.x + 5.0
	var right := safe_bounds.end.x - 5.0
	var near_z := safe_bounds.position.y + 5.0
	var far_z := safe_bounds.end.y - 5.0
	var entry_z := far_z if absf(player_position.z - far_z) <= absf(player_position.z - near_z) else near_z
	return [Vector3(left, 0.05, entry_z), Vector3(right, 0.05, entry_z)]

func _queue_final_assault(final_legion: Dictionary) -> void:
	var elite_archetype := StringName(encounter_definition.get("final_elite", &"ncenturion"))
	var reserved := _active_legion_anchors()
	spawn_queue.append({
		"archetype": elite_archetype,
		"mass": false,
		"boss": ArchetypesScript.is_boss(elite_archetype),
		"completion_elite": true,
		"elite_title": String(encounter_definition.get("elite_title", "UN CHAMPION ENTRE DANS LA MELEE")),
		"guard_index": 100,
		"position": boss_spawn if ArchetypesScript.is_boss(elite_archetype) else _select_legion_anchor(elite_archetype, reserved)
	})
	_queue_legion_set([final_legion], 3)

func _legion_id(index: int) -> int:
	return current_wave * 10 + index

func _is_legion_decimated(legion_id: int) -> bool:
	var alive := 0
	for value: Variant in active_enemies.values():
		if value is HopliteAthenianEnemy and is_instance_valid(value):
			var enemy := value as HopliteAthenianEnemy
			if not enemy.dead and int(enemy.get_meta("campaign_legion_id", -999)) == legion_id:
				alive += 1
	return alive <= 3

func _active_legion_anchors() -> Array:
	var anchors: Array = []
	var seen := {}
	for value: Variant in active_enemies.values():
		if value is HopliteAthenianEnemy and is_instance_valid(value):
			var enemy := value as HopliteAthenianEnemy
			if enemy.has_meta("campaign_legion_anchor"):
				var anchor: Vector3 = enemy.get_meta("campaign_legion_anchor") as Vector3
				if not seen.has(anchor):
					seen[anchor] = true
					anchors.append(anchor)
	return anchors

func _queue_boss_encounter(_definition: Dictionary) -> void:
	spawn_queue.append({"archetype": &"nfull_armor", "mass": false, "boss": true, "position": boss_spawn})
	var guard_archetype := &"nsbire1"
	var guard_anchor := _select_legion_anchor(guard_archetype, [boss_spawn])
	for index: int in range(LEGION_SIZE):
		spawn_queue.append({
			"archetype": guard_archetype,
			"mass": true,
			"guard_index": index,
			"formation_index": index,
			"legion_id": 90,
			"legion_anchor": guard_anchor
		})

func _spawn_spec(spec: Dictionary) -> void:
	if enemy_parent == null or player == null:
		return
	var archetype := StringName(spec.get("archetype", &"nsbire1"))
	var position_value: Vector3 = spec.get("position", _next_spawn_position())
	if spec.has("legion_anchor"):
		position_value = _legion_formation_position(
			spec.get("legion_anchor", position_value) as Vector3,
			int(spec.get("formation_index", 0)),
			archetype
		)
	elif not bool(spec.get("boss", false)):
		position_value += Vector3(rng.randf_range(-0.65, 0.65), 0.0, rng.randf_range(-0.65, 0.65))
	if bool(spec.get("entry_surge", false)):
		position_value = _find_safe_spawn_floor(position_value, Vector3.RIGHT, Vector3.FORWARD)
	var enemy := EnemyFactoryScript.spawn(enemy_parent, archetype, position_value, player, {
		"ai_enabled": true,
		"mass_battle_mode": bool(spec.get("mass", true)),
		"guard_index": int(spec.get("guard_index", 0)),
		"name": "%s_W%02d_%04d" % [String(archetype).to_pascal_case(), current_wave + 1, rng.randi_range(0, 9999)]
	}) as HopliteAthenianEnemy
	if enemy == null:
		return
	if spec.has("legion_id"):
		var legion_id := int(spec.get("legion_id", 0))
		enemy.add_to_group("campaign_legion_%02d" % legion_id)
		enemy.add_to_group("campaign_type_%s" % String(archetype))
		enemy.set_meta("campaign_legion_id", legion_id)
		enemy.set_meta("campaign_legion_anchor", spec.get("legion_anchor", position_value))
	if bool(spec.get("entry_surge", false)):
		enemy.add_to_group("campaign_dungeon_entry_surge")
		enemy.set_meta("campaign_entry_surge", true)
	if deployment_locked:
		enemy.ai_enabled = false
	active_enemies[enemy.get_instance_id()] = enemy
	enemy.died.connect(_on_enemy_died)
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy.get_instance_id()), CONNECT_ONE_SHOT)
	enemy_spawned.emit(enemy)
	if bool(spec.get("completion_elite", false)):
		completion_elite = enemy
	if bool(spec.get("boss", false)) or ArchetypesScript.is_boss(archetype):
		boss = enemy
		boss_defeated = false
		if not boss.combat_phase_changed.is_connected(_on_boss_phase_changed):
			boss.combat_phase_changed.connect(_on_boss_phase_changed)
		_play_elite_entrance(boss, true)
		boss_spawned.emit(boss)
	elif ArchetypesScript.is_miniboss(archetype):
		_play_elite_entrance(enemy, false)
		miniboss_spawned.emit(enemy, String(spec.get("elite_title", "UN CHAMPION ENTRE DANS LA MELEE")))

func _on_enemy_died(enemy_node: Node) -> void:
	if enemy_node == null:
		return
	active_enemies.erase(enemy_node.get_instance_id())
	wave_defeated += 1
	if enemy_node == boss:
		boss_defeated = true
		emit_signal("boss_phase_started", 4, "NFULLARMOR EST TOMBE")
	wave_progress.emit(active_enemies.size(), spawn_queue.size(), wave_defeated)
	if enemy_node == completion_elite:
		_complete_encounter_after_elite()
	var timer := get_tree().create_timer(CORPSE_LIFETIME)
	timer.timeout.connect(_release_corpse.bind(enemy_node))

func _complete_encounter_after_elite() -> void:
	if encounter_completed:
		return
	encounter_completed = true
	running = false
	spawn_queue.clear()
	for value: Variant in active_enemies.values():
		if value is HopliteAthenianEnemy and is_instance_valid(value):
			var survivor := value as HopliteAthenianEnemy
			survivor.ai_enabled = false
			survivor.queue_free()
	active_enemies.clear()
	zone_completed.emit()

func _on_enemy_tree_exited(instance_id: int) -> void:
	# A deleted or externally freed enemy must never remain as an invisible
	# straggler capable of blocking the next act.
	active_enemies.erase(instance_id)

func _audit_active_enemies() -> void:
	for raw_id: Variant in active_enemies.keys():
		var instance_id := int(raw_id)
		var value: Variant = active_enemies.get(raw_id)
		if not (value is HopliteAthenianEnemy) or not is_instance_valid(value):
			active_enemies.erase(instance_id)
			continue
		var enemy := value as HopliteAthenianEnemy
		var flat_position := Vector2(enemy.global_position.x, enemy.global_position.z)
		if enemy.global_position.y >= -3.0 and safe_bounds.has_point(flat_position):
			continue
		var rescue_position := boss_spawn if enemy == boss else _next_spawn_position()
		rescue_position.y = maxf(0.05, rescue_position.y)
		enemy.global_position = rescue_position + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
		enemy.velocity = Vector3.ZERO
		if enemy.has_method("alert_ai"):
			enemy.call("alert_ai", 10.0)
		print("[PROCEDURAL CROWD] Rescued %s from outside the battlefield." % enemy.name)

func _on_boss_phase_changed(_enemy: Node, phase: int) -> void:
	if phase == 2:
		boss_phase_started.emit(phase, "PHASE II — LE SERMENT DE FER")
		_queue_phase_reinforcements(8, false)
	elif phase == 3:
		boss_phase_started.emit(phase, "PHASE III — LA COURONNE BRISEE")
		_queue_phase_reinforcements(6, true)

func _queue_phase_reinforcements(count: int, with_miniboss: bool) -> void:
	var reinforcement_type := &"nathenian1" if with_miniboss else &"nsbire1"
	var reinforcement_anchor := _select_legion_anchor(reinforcement_type, [boss_spawn])
	for index: int in range(count):
		spawn_queue.append({
			"archetype": reinforcement_type,
			"mass": true,
			"guard_index": 200 + index,
			"formation_index": index,
			"legion_id": 91 if with_miniboss else 90,
			"legion_anchor": reinforcement_anchor
		})
	if with_miniboss:
		spawn_queue.append({
			"archetype": &"ncenturion",
			"mass": false,
			"elite_title": "LE DERNIER CENTURION",
			"guard_index": 299,
			"position": _select_legion_anchor(&"ncenturion", [boss_spawn, reinforcement_anchor])
		})

func _release_corpse(enemy_node: Node) -> void:
	if enemy_node != null and is_instance_valid(enemy_node):
		enemy_node.queue_free()

func _select_legion_anchor(archetype: StringName, reserved_anchors: Array) -> Vector3:
	if spawn_points.is_empty():
		return Vector3.ZERO
	if player == null:
		return spawn_points[rng.randi_range(0, spawn_points.size() - 1)]
	var profile := ArchetypesScript.profile(archetype)
	var behavior := StringName(profile.get("behavior", &"aggressive"))
	var desired_distance := 21.0 if behavior == &"ranged" else (15.0 if behavior in [&"guardian", &"reach"] else 12.5)
	var player_position := player.global_position if player.is_inside_tree() else player.position
	var camera := get_viewport().get_camera_3d() if is_inside_tree() and get_viewport() != null else null
	var best_point := spawn_points[rng.randi_range(0, spawn_points.size() - 1)]
	var best_score := -INF
	for point: Vector3 in spawn_points:
		var flat_delta := point - player_position
		flat_delta.y = 0.0
		var distance := flat_delta.length()
		if distance < 8.0:
			continue
		var score := -absf(distance - desired_distance) + rng.randf_range(0.0, 1.25)
		if camera != null:
			var camera_delta := point - camera.global_position
			camera_delta.y = 0.0
			var camera_forward := -camera.global_basis.z
			camera_forward.y = 0.0
			if camera_delta.length_squared() > 0.01 and camera_forward.normalized().dot(camera_delta.normalized()) > 0.20:
				score -= 14.0
			else:
				score += 4.0
		for reserved: Variant in reserved_anchors:
			if reserved is Vector3:
				var separation := point.distance_to(reserved as Vector3)
				if separation < 9.0:
					score -= (9.0 - separation) * 3.5
		if score > best_score:
			best_score = score
			best_point = point
	return best_point

func _legion_formation_position(anchor: Vector3, formation_index: int, archetype: StringName) -> Vector3:
	var toward_player := player.global_position - anchor if player != null else Vector3.FORWARD
	toward_player.y = 0.0
	if toward_player.length_squared() < 0.01:
		toward_player = Vector3.FORWARD
	toward_player = toward_player.normalized()
	var lateral := Vector3(-toward_player.z, 0.0, toward_player.x)
	var behavior := StringName(ArchetypesScript.profile(archetype).get("behavior", &"aggressive"))
	var spacing := 1.75 if behavior == &"ranged" else 1.48
	var column := formation_index % 5
	var row := formation_index / 5
	var position_value := anchor + lateral * (float(column) - 2.0) * spacing - toward_player * float(row) * spacing
	position_value.y = maxf(0.05, anchor.y)
	return _find_safe_spawn_floor(position_value, lateral, toward_player)

func _find_safe_spawn_floor(candidate: Vector3, lateral: Vector3, forward: Vector3) -> Vector3:
	if enemy_parent == null or not enemy_parent.is_inside_tree() or enemy_parent.get_world_3d() == null:
		return candidate
	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		lateral * 1.8, -lateral * 1.8,
		forward * 1.8, -forward * 1.8,
		(lateral + forward).normalized() * 2.8,
		(-lateral + forward).normalized() * 2.8,
		(lateral - forward).normalized() * 2.8,
		(-lateral - forward).normalized() * 2.8
	]
	var exclusions: Array[RID] = []
	if player is CollisionObject3D:
		exclusions.append((player as CollisionObject3D).get_rid())
	for offset: Vector3 in offsets:
		var probe := candidate + offset
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(probe.x, 5.5, probe.z),
			Vector3(probe.x, -2.0, probe.z),
			1,
			exclusions
		)
		var collision := enemy_parent.get_world_3d().direct_space_state.intersect_ray(query)
		if collision.is_empty():
			continue
		var hit_position := collision.get("position", probe) as Vector3
		var hit_normal := collision.get("normal", Vector3.UP) as Vector3
		# Floors in all three acts sit around y=0. Raised hits are props, walls or
		# barricades and would create stuck/floating deployment points.
		if hit_normal.y >= 0.68 and hit_position.y <= 0.38:
			return Vector3(hit_position.x, hit_position.y + 0.05, hit_position.z)
	return candidate

func _play_elite_entrance(enemy: HopliteAthenianEnemy, is_boss: bool) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var landing_position := enemy.global_position
	var final_scale := enemy.scale
	enemy.ai_enabled = false
	enemy.velocity = Vector3.ZERO
	enemy.set_physics_process(false)
	enemy.global_position = landing_position + Vector3.UP * (5.5 if is_boss else 3.8)
	enemy.scale = final_scale * 0.35
	var ring := MeshInstance3D.new()
	ring.name = "BossEntranceSigil" if is_boss else "EliteEntranceSigil"
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.72
	ring_mesh.bottom_radius = 0.72
	ring_mesh.height = 0.035
	ring_mesh.radial_segments = 48
	var ring_material := StandardMaterial3D.new()
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(1.0, 0.12, 0.025, 0.78) if is_boss else Color(1.0, 0.58, 0.10, 0.72)
	ring_material.emission_enabled = true
	ring_material.emission = ring_material.albedo_color * 2.6
	ring_mesh.material = ring_material
	ring.mesh = ring_mesh
	ring.position = landing_position + Vector3.UP * 0.055
	enemy_parent.add_child(ring)
	var entrance := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	entrance.tween_property(enemy, "global_position", landing_position, 0.78)
	entrance.parallel().tween_property(enemy, "scale", final_scale, 0.78).set_trans(Tween.TRANS_BACK)
	entrance.tween_callback(_finish_elite_entrance.bind(enemy))
	var sigil := create_tween().set_parallel(true)
	sigil.tween_property(ring, "scale", Vector3(5.2, 1.0, 5.2), 0.92).set_trans(Tween.TRANS_QUAD)
	sigil.tween_property(ring, "modulate:a", 0.0, 0.92)
	sigil.chain().tween_callback(ring.queue_free)

func _finish_elite_entrance(enemy: HopliteAthenianEnemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.dead:
		return
	enemy.ai_enabled = true
	enemy.set_physics_process(true)
	enemy.alert_ai(10.0)

func _next_spawn_position() -> Vector3:
	return _select_legion_anchor(&"nsbire1", [])

func _shuffle_spawn_queue() -> void:
	for index: int in range(spawn_queue.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value: Dictionary = spawn_queue[index]
		spawn_queue[index] = spawn_queue[swap_index]
		spawn_queue[swap_index] = value

func _plan_for_zone(id: StringName) -> Array[Dictionary]:
	match id:
		&"walls":
			return [
				{
					"title": "LES TROIS LEGIONS DU REMPART",
					"legions": [
						{"archetype": &"nsbire1", "count": LEGION_SIZE},
						{"archetype": &"nsbire2", "count": LEGION_SIZE},
						{"archetype": &"nathenian1", "count": LEGION_SIZE},
						{"archetype": &"nsbire1", "count": LEGION_SIZE}
					],
					"final_elite": &"bronze_colossus",
					"elite_title": "LE COLOSSE DU REMPART"
				}
			]
		&"city":
			return [
				{
					"title": "LES TROIS LEGIONS DE LA CITE",
					"legions": [
						{"archetype": &"nathenian1", "count": LEGION_SIZE},
						{"archetype": &"nsbire1", "count": LEGION_SIZE},
						{"archetype": &"nsbire2", "count": LEGION_SIZE},
						{"archetype": &"nathenian1", "count": LEGION_SIZE}
					],
					"final_elite": &"ngeneral_veteran",
					"elite_title": "LE VETERAN DE L'AGORA"
				}
			]
		&"dungeon":
			return [
				{
					"title": "LES LEGIONS DE LA GARDE NOIRE",
					"legions": [
						{"archetype": &"nathenian1", "count": LEGION_SIZE},
						{"archetype": &"nsbire1", "count": LEGION_SIZE},
						{"archetype": &"nsbire2", "count": LEGION_SIZE},
						{"archetype": &"nathenian1", "count": LEGION_SIZE}
					],
					"final_elite": &"nfull_armor",
					"elite_title": "NFULLARMOR — LE ROI SOUS LE FER"
				}
			]
	return []
