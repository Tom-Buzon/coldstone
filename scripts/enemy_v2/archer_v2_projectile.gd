extends Node3D

## One swept segment per physics tick: no homing and no contact Area per arrow.
## World collision wins over a target capsule behind cover. A shared cap bounds
## projectile work independently of the number of distant archer formations.
const MAX_PROJECTILES := 40
const SPEED := 24.0
const GRAVITY := 5.0
const LIFETIME := 2.4
var flight_velocity := Vector3.ZERO
var source_ref: WeakRef
var target_ref: WeakRef
var damage := 0.0
var elapsed := 0.0
var near_miss_reported := false
static var shared_mesh: CylinderMesh
static var shared_material: StandardMaterial3D

static func can_spawn(tree: SceneTree) -> bool:
	return tree.get_node_count_in_group(&"enemy_v2_projectile") < MAX_PROJECTILES

func launch(origin: Vector3, aim: Vector3, source: Node3D, target: Node3D, damage_value: float) -> void:
	global_position = origin
	source_ref = weakref(source)
	target_ref = weakref(target)
	damage = damage_value
	var duration := maxf(origin.distance_to(aim) / SPEED, 0.05)
	flight_velocity = (aim - origin) / duration + Vector3.UP * GRAVITY * duration * 0.5
	add_to_group(&"enemy_v2_projectile")
	if shared_mesh == null:
		shared_mesh = CylinderMesh.new()
		shared_mesh.top_radius = 0.012
		shared_mesh.bottom_radius = 0.025
		shared_mesh.height = 0.85
		shared_mesh.radial_segments = 5
		shared_material = StandardMaterial3D.new()
		shared_material.albedo_color = Color(1.0, 0.7, 0.25)
		shared_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var visual := MeshInstance3D.new()
	visual.mesh = shared_mesh
	visual.material_override = shared_material
	visual.rotation.x = PI * 0.5
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	_align()

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed > LIFETIME:
		queue_free()
		return
	var previous := global_position
	var next := previous + flight_velocity * delta + Vector3.DOWN * GRAVITY * delta * delta * 0.5
	flight_velocity.y -= GRAVITY * delta
	# Layer 1 is world geometry; the moving player is tested against a swept
	# capsule so low frame rates cannot tunnel between discrete arrow positions.
	var query := PhysicsRayQueryParameters3D.create(previous, next, 1)
	var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
	if not obstruction.is_empty():
		next = obstruction["position"]
	var target := target_ref.get_ref() as Node3D if target_ref != null else null
	var source := source_ref.get_ref() as Node3D if source_ref != null else null
	if source != null:
		var candidates: Array[Node3D] = []
		var encounter: Node = source.get_meta("v2_encounter") if source.has_meta("v2_encounter") else null
		if is_instance_valid(encounter): candidates = encounter.nearby((previous+next)*0.5,6.0,48)
		if is_instance_valid(target) and not candidates.has(target): candidates.append(target)
		var first: Node3D
		var first_distance := INF
		for candidate: Node3D in candidates:
			if not is_instance_valid(candidate) or candidate == source: continue
			var size := float(candidate.get("size_multiplier")) if candidate is HopliteEnemyActorV2 and candidate.definition.unit_role == &"giant" else 1.0
			var closest := Geometry3D.get_closest_point_to_segment(candidate.global_position + Vector3.UP * 0.95 * size,previous,next)
			var relative := closest - candidate.global_position
			var radial := Vector2(relative.x,relative.z).length()
			if radial < 0.43*size and relative.y >= 0.12 and relative.y <= 1.85*size:
				var distance := previous.distance_squared_to(closest)
				if distance < first_distance:
					first_distance = distance
					first = candidate
			elif candidate == target and not near_miss_reported and radial < 1.5 and absf(relative.y-0.95)<1.5:
				near_miss_reported = true
				if target.has_method("register_enemy_near_miss"): target.call("register_enemy_near_miss",source)
		if first != null:
			if preload("res://scripts/enemy_v2/enemy_v2_factions.gd").hostile(source,first):
				var method := &"receive_enemy_hit" if first.has_method("receive_enemy_hit") else &"receive_ai_hit"
				if first.has_method(method): first.call(method,damage,source,flight_velocity.normalized())
			queue_free()
			return
	global_position = next
	_align()
	if not obstruction.is_empty():
		queue_free()

func _align() -> void:
	if flight_velocity.length_squared() > 0.01:
		look_at(global_position + flight_velocity.normalized(), Vector3.UP)
