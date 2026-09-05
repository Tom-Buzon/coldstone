extends Node
class_name HopliteCameraOcclusionFader

## Global camera readability pass. Geometry between camera and player receives
## per-instance fade materials derived from its authored materials. Original
## render state is restored exactly afterward.

const OutlineScript = preload("res://scripts/camera/player_occlusion_outline.gd")
const DEFAULT_OUTLINE_COLOR := Color(0.0, 0.78622156, 0.5315931, 1.0)
const DEFAULT_ENEMY_ATTACK_OUTLINE_COLOR := Color(1.0, 0.141, 0.0, 1.0)
const DEFAULT_OUTLINE_OPACITY := 0.68
const SETTINGS_PATH := "user://hoplite_global_settings_v1.cfg"
const OCCLUSION_GROUP := &"camera_occlusion_fader"
const IGNORE_GROUP := &"camera_occlusion_ignore"
const IGNORE_META := &"camera_occlusion_ignore"
const COLLIDER_AUTHORITATIVE_META := &"camera_occlusion_collider_authoritative"
const DYNAMIC_ACTOR_GROUP := &"camera_occlusion_dynamic_actor"
const GIANT_OWNER_META := &"giant_owner"
const BASE_TERRAIN_NAME_PARTS: Array[String] = ["terrain", "ground", "floor"]

const DEFAULT_ENABLED := true
const DEFAULT_OPACITY := 0.44
const DEFAULT_RADIUS := 0.10
const REFRESH_INTERVAL := 1.0 / 20.0
const FADE_OUT_SPEED := 5.8
const FADE_IN_SPEED := 4.2
const PLAYER_FOCUS_HEIGHT := 1.12
const PLAYER_DEPTH_LIMIT := 0.985
const PHYSICS_TARGET_CLEARANCE := 0.24
const CAMERA_OVERLAP_MIN_RADIUS := 0.45
const LARGE_VISUAL_EXTENT := 18.0
const SPATIAL_CELL_SIZE := 8.0
const MAX_RAY_OCCLUDERS := 24
const MAX_CAMERA_OVERLAPS := 32
const DYNAMIC_ACTOR_REFRESH_INTERVAL := 0.50
const DYNAMIC_ACTOR_RADIUS := 0.48
const DYNAMIC_ACTOR_HEIGHT := 2.05

var outline: Node
var outline_color := DEFAULT_OUTLINE_COLOR
var enemy_attack_outline_color := DEFAULT_ENEMY_ATTACK_OUTLINE_COLOR
var outline_opacity := DEFAULT_OUTLINE_OPACITY

var enabled := DEFAULT_ENABLED
var occluder_opacity := DEFAULT_OPACITY
var probe_radius := DEFAULT_RADIUS

var camera: Camera3D
var target: Node3D
var spring_arm: SpringArm3D

var _spring_arm_collision_mask := 0
var _spring_arm_mask_captured := false
var _refresh_elapsed := REFRESH_INTERVAL
var _visuals: Dictionary = {}
var _spatial_cells: Dictionary = {}
var _pending_visuals: Dictionary = {}
var _pending_visual_flush_scheduled := false
var _last_visual_candidate_count := 0
var _last_spatial_cell_count := 0
var _visited_visuals: Dictionary = {}
var _stale_visual_ids: Array[int] = []
var _fade_states: Dictionary = {}
var _ignore_cache: Dictionary = {}
var _collider_visual_cache: Dictionary = {}
var _camera_overlap_shape := SphereShape3D.new()
var _ray_query := PhysicsRayQueryParameters3D.new()
var _camera_overlap_query := PhysicsShapeQueryParameters3D.new()
var _dynamic_actors: Array[Node3D] = []
var _dynamic_actor_refresh_elapsed := DYNAMIC_ACTOR_REFRESH_INTERVAL


func _ready() -> void:
	add_to_group(OCCLUSION_GROUP)
	_load_settings()
	_ray_query.collision_mask = 0xFFFFFFFF
	_ray_query.collide_with_bodies = true
	_ray_query.collide_with_areas = false
	_ray_query.hit_from_inside = true
	_camera_overlap_query.shape = _camera_overlap_shape
	_camera_overlap_query.collision_mask = 0xFFFFFFFF
	_camera_overlap_query.collide_with_bodies = true
	_camera_overlap_query.collide_with_areas = false
	_cache_existing_visuals()
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	if not get_tree().node_removed.is_connected(_on_tree_node_removed):
		get_tree().node_removed.connect(_on_tree_node_removed)
	set_process(false)
	set_physics_process(enabled)
	_apply_spring_arm_policy()


func configure(camera_node: Camera3D, target_node: Node3D, spring_arm_node: SpringArm3D) -> void:
	camera = camera_node
	target = target_node
	if outline == null:
		outline = OutlineScript.new()
		outline.fader = self
		outline.color = outline_color
		outline.attack_color = enemy_attack_outline_color
		outline.opacity = outline_opacity
		add_child(outline)
	spring_arm = spring_arm_node
	if spring_arm != null and not _spring_arm_mask_captured:
		_spring_arm_collision_mask = spring_arm.collision_mask
		_spring_arm_mask_captured = true
	_apply_spring_arm_policy()


func apply_settings(next_enabled: bool, next_opacity: float, next_radius: float) -> void:
	enabled = next_enabled
	occluder_opacity = clampf(next_opacity, 0.02, 0.45)
	probe_radius = clampf(next_radius, 0.10, 1.20)
	set_physics_process(enabled)
	_apply_spring_arm_policy()
	_refresh_elapsed = REFRESH_INTERVAL
	if not enabled:
		_mark_all_for_restore()


func apply_outline_settings(next_color: Color, next_opacity: float, next_attack_color: Variant = null) -> void:
	outline_color = Color(next_color, 1.0)
	if next_attack_color is Color:
		enemy_attack_outline_color = Color(next_attack_color as Color, 1.0)
	outline_opacity = clampf(next_opacity, 0.0, 1.0)
	if outline != null:
		outline.color = outline_color
		outline.attack_color = enemy_attack_outline_color
		outline.opacity = outline_opacity


func get_active_occluder_count() -> int:
	var count := 0
	for raw_state: Variant in _fade_states.values():
		var state := raw_state as Dictionary
		if bool(state.get(&"occluded", false)):
			count += 1
	return count


func get_registered_visual_count() -> int:
	return _visuals.size()


func get_last_visual_candidate_count() -> int:
	return _last_visual_candidate_count


func get_last_spatial_cell_count() -> int:
	return _last_spatial_cell_count


func _physics_process(delta: float) -> void:
	if not enabled or camera == null or target == null:
		return
	if not is_instance_valid(camera) or not is_instance_valid(target):
		return
	_refresh_elapsed += delta
	_dynamic_actor_refresh_elapsed += delta
	if _refresh_elapsed < REFRESH_INTERVAL:
		return
	_refresh_elapsed = fmod(_refresh_elapsed, REFRESH_INTERVAL)
	_scan_occluders()


func _process(delta: float) -> void:
	if _fade_states.is_empty():
		return
	var completed: Array[int] = []
	for raw_id: Variant in _fade_states.keys():
		var instance_id := int(raw_id)
		var state := _fade_states[raw_id] as Dictionary
		var visual := _state_visual(state)
		if visual == null:
			completed.append(instance_id)
			continue
		var is_occluded := enabled and bool(state.get(&"occluded", false))
		var current_factor := float(state.get(&"fade_factor", 1.0))
		var desired_factor := occluder_opacity if is_occluded else 1.0
		var speed := FADE_OUT_SPEED if is_occluded else FADE_IN_SPEED
		current_factor = move_toward(current_factor, desired_factor, speed * delta)
		state[&"fade_factor"] = current_factor
		_set_fade_material_factor(state, current_factor)
		# A visual may leave the tree while its fade materials are being restored.
		# Resolve the instance ID again instead of retaining a freed Object handle.
		visual = _state_visual(state)
		if visual == null:
			completed.append(instance_id)
			continue
		if is_occluded:
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif is_equal_approx(current_factor, 1.0):
			_restore_visual_state(state)
			completed.append(instance_id)
	for instance_id: int in completed:
		_fade_states.erase(instance_id)
	if _fade_states.is_empty():
		set_process(false)


func _scan_occluders() -> void:
	for raw_state: Variant in _fade_states.values():
		(raw_state as Dictionary)[&"occluded"] = false

	var from := camera.global_position
	var to := target.global_position + Vector3.UP * PLAYER_FOCUS_HEIGHT
	if from.distance_squared_to(to) < 0.16:
		return
	var camera_to_target := to - from
	var scan_to := to - camera_to_target.normalized() * minf(PHYSICS_TARGET_CLEARANCE, camera_to_target.length() * 0.25)
	_scan_collision_occluders(from, to)
	_scan_camera_overlaps(from, to)
	_scan_dynamic_actor_occluders(from, to)
	_scan_spatial_visuals(from, to, scan_to)


func _scan_dynamic_actor_occluders(camera_from: Vector3, target_point: Vector3) -> void:
	if _dynamic_actor_refresh_elapsed >= DYNAMIC_ACTOR_REFRESH_INTERVAL:
		_refresh_dynamic_actor_cache()
	var segment := target_point - camera_from
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return
	for index: int in range(_dynamic_actors.size() - 1, -1, -1):
		var actor := _dynamic_actors[index]
		if actor == null or not is_instance_valid(actor) or not actor.is_inside_tree():
			_dynamic_actors.remove_at(index)
			continue
		if not actor.is_visible_in_tree() or _is_camera_occlusion_ignored(actor):
			continue
		var actor_scale := actor.global_basis.get_scale()
		var radius := (DYNAMIC_ACTOR_RADIUS + probe_radius) * maxf(actor_scale.x, actor_scale.z)
		var actor_center := actor.global_position + Vector3.UP * DYNAMIC_ACTOR_HEIGHT * actor_scale.y * 0.5
		var actor_bottom := actor.global_position.y - 0.10
		var actor_top := actor.global_position.y + DYNAMIC_ACTOR_HEIGHT * actor_scale.y
		var camera_horizontal_delta := Vector2(camera_from.x - actor.global_position.x, camera_from.z - actor.global_position.z)
		# Collider-free mass actors are absent from the physics overlap query.
		# Their torso can surround the camera even when their origin is behind it;
		# in that case fade every body/equipment surface, not just ray-hit pieces.
		var near_camera := camera_horizontal_delta.length_squared() <= radius * radius and camera_from.y >= actor_bottom - probe_radius and camera_from.y <= actor_top + probe_radius
		if not near_camera:
			var depth := (actor_center - camera_from).dot(segment) / length_squared
			if depth <= 0.005 or depth >= PLAYER_DEPTH_LIMIT:
				continue
			var corridor_point := camera_from + segment * depth
			if corridor_point.y < actor_bottom - probe_radius or corridor_point.y > actor_top + probe_radius:
				continue
			var horizontal_delta := Vector2(corridor_point.x - actor.global_position.x, corridor_point.z - actor.global_position.z)
			if horizontal_delta.length_squared() > radius * radius:
				continue
		for visual: GeometryInstance3D in _collider_visuals(actor):
			if visual != null and is_instance_valid(visual) and visual.is_visible_in_tree() and not _is_ignored_visual(visual):
				_mark_occluded(visual)


func _refresh_dynamic_actor_cache() -> void:
	_dynamic_actor_refresh_elapsed = 0.0
	_dynamic_actors.clear()
	for node: Node in get_tree().get_nodes_in_group(DYNAMIC_ACTOR_GROUP):
		if node is Node3D and node != target and not (target != null and target.is_ancestor_of(node)):
			_dynamic_actors.append(node as Node3D)


func _scan_spatial_visuals(from: Vector3, target_point: Vector3, scan_to: Vector3) -> void:
	_last_visual_candidate_count = 0
	_last_spatial_cell_count = 0
	var bounds := _segment_bounds(from, scan_to, probe_radius)
	var minimum_cell := _world_to_cell(bounds.position)
	var maximum_cell := _world_to_cell(bounds.end)
	_visited_visuals.clear()
	_stale_visual_ids.clear()
	for cell_x: int in range(minimum_cell.x, maximum_cell.x + 1):
		for cell_y: int in range(minimum_cell.y, maximum_cell.y + 1):
			for cell_z: int in range(minimum_cell.z, maximum_cell.z + 1):
				var cell := Vector3i(cell_x, cell_y, cell_z)
				var raw_bucket: Variant = _spatial_cells.get(cell)
				if not raw_bucket is Dictionary:
					continue
				_last_spatial_cell_count += 1
				var bucket := raw_bucket as Dictionary
				for raw_id: Variant in bucket:
					var instance_id := int(raw_id)
					if _visited_visuals.has(instance_id):
						continue
					_visited_visuals[instance_id] = true
					var visual := bucket[raw_id] as GeometryInstance3D
					if visual == null or not is_instance_valid(visual) or not visual.is_inside_tree():
						_stale_visual_ids.append(instance_id)
						continue
					_last_visual_candidate_count += 1
					if _is_ignored_visual(visual) or not visual.is_visible_in_tree():
						continue
					var local_aabb := visual.get_aabb()
					if local_aabb.size.length_squared() <= 0.000001:
						continue
					var world_aabb: AABB = visual.global_transform * local_aabb
					if not _small_visual_blocks_camera(world_aabb, from, target_point, scan_to):
						continue
					_mark_occluded(visual)
	for instance_id: int in _stale_visual_ids:
		_remove_visual(instance_id, false)


func _segment_bounds(from: Vector3, to: Vector3, margin: float) -> AABB:
	var minimum := Vector3(minf(from.x, to.x), minf(from.y, to.y), minf(from.z, to.z))
	var maximum := Vector3(maxf(from.x, to.x), maxf(from.y, to.y), maxf(from.z, to.z))
	return AABB(minimum, maximum - minimum).grow(margin)


func _world_to_cell(world_position: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_position.x / SPATIAL_CELL_SIZE),
		floori(world_position.y / SPATIAL_CELL_SIZE),
		floori(world_position.z / SPATIAL_CELL_SIZE)
	)


func _small_visual_blocks_camera(world_aabb: AABB, from: Vector3, target_point: Vector3, scan_to: Vector3) -> bool:
	if world_aabb.grow(probe_radius).intersects_segment(from, scan_to) == null:
		return false
	var camera_to_target := target_point - from
	var length_squared := camera_to_target.length_squared()
	if length_squared <= 0.000001:
		return false
	var center_depth := (world_aabb.get_center() - from).dot(camera_to_target) / length_squared
	# An expanded AABB may touch the corridor endpoint even when the object is
	# beside or in front of the player. Its centre must remain strictly on the
	# camera side of the player plane.
	return center_depth > 0.005 and center_depth < PLAYER_DEPTH_LIMIT


func _scan_collision_occluders(from: Vector3, target_point: Vector3) -> void:
	var world: World3D = camera.get_world_3d() if camera != null else null
	if world == null:
		return
	var right := camera.global_transform.basis.x.normalized()
	var up := camera.global_transform.basis.y.normalized()
	var diagonal_scale := probe_radius * 0.70
	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		right * probe_radius,
		-right * probe_radius,
		up * probe_radius,
		-up * probe_radius,
		(right + up).normalized() * diagonal_scale,
		(-right + up).normalized() * diagonal_scale,
		(right - up).normalized() * diagonal_scale,
		(-right - up).normalized() * diagonal_scale,
	]
	for offset: Vector3 in offsets:
		var ray_from := from + offset
		var ray_target := target_point + offset
		var camera_to_target := ray_target - ray_from
		if camera_to_target.length_squared() <= 0.000001:
			continue
		var ray_to := ray_target - camera_to_target.normalized() * minf(PHYSICS_TARGET_CLEARANCE, camera_to_target.length() * 0.25)
		_scan_collision_ray(world.direct_space_state, ray_from, ray_to, from, target_point)


func _scan_collision_ray(space_state: PhysicsDirectSpaceState3D, ray_from: Vector3, ray_to: Vector3, camera_from: Vector3, target_point: Vector3) -> void:
	var excluded: Array[RID] = []
	if target is CollisionObject3D:
		excluded.append((target as CollisionObject3D).get_rid())
	_ray_query.from = ray_from
	_ray_query.to = ray_to
	_ray_query.exclude = excluded
	for index: int in MAX_RAY_OCCLUDERS:
		var hit: Dictionary = space_state.intersect_ray(_ray_query)
		if hit.is_empty():
			break
		var collider := hit.get("collider") as Node
		if collider != null and is_instance_valid(collider):
			_mark_collider_visuals(collider, ray_from, ray_to, camera_from, target_point, false)
		var rid: RID = hit.get("rid", RID())
		if not rid.is_valid():
			break
		excluded.append(rid)
		_ray_query.exclude = excluded


func _scan_camera_overlaps(camera_from: Vector3, target_point: Vector3) -> void:
	var world: World3D = camera.get_world_3d() if camera != null else null
	if world == null:
		return
	_camera_overlap_shape.radius = maxf(CAMERA_OVERLAP_MIN_RADIUS, probe_radius * 1.35)
	_camera_overlap_query.transform = Transform3D(Basis.IDENTITY, camera_from)
	if target is CollisionObject3D:
		_camera_overlap_query.exclude = [(target as CollisionObject3D).get_rid()]
	else:
		_camera_overlap_query.exclude = []
	var overlaps: Array[Dictionary] = world.direct_space_state.intersect_shape(_camera_overlap_query, MAX_CAMERA_OVERLAPS)
	for hit: Dictionary in overlaps:
		var collider := hit.get("collider") as Node
		if collider != null and is_instance_valid(collider):
			_mark_collider_visuals(collider, camera_from, camera_from, camera_from, target_point, true)


func _mark_collider_visuals(collider: Node, segment_from: Vector3, segment_to: Vector3, camera_from: Vector3, target_point: Vector3, near_camera: bool) -> void:
	var authoritative_owner := _authoritative_occlusion_owner(collider)
	var visual_source := authoritative_owner if authoritative_owner != null else collider
	if target != null and (visual_source == target or target.is_ancestor_of(visual_source)):
		return
	if _is_camera_occlusion_ignored(collider) or (visual_source != collider and _is_camera_occlusion_ignored(visual_source)):
		return
	if authoritative_owner != null and not near_camera:
		if not _authoritative_owner_is_between_camera_and_player(authoritative_owner, camera_from, target_point):
			return
	for visual: GeometryInstance3D in _collider_visuals(visual_source):
		if visual == null or not is_instance_valid(visual) or _is_ignored_visual(visual):
			continue
		if authoritative_owner != null:
			# Some imported skinned meshes have unusable authored AABBs. Their
			# explicitly opted-in collider is the reliable proof of occlusion.
			_mark_occluded(visual)
			continue
		var local_aabb: AABB = visual.get_aabb()
		var world_aabb: AABB = visual.global_transform * local_aabb
		if _physics_visual_blocks_camera(world_aabb, segment_from, segment_to, camera_from, target_point, near_camera):
			_mark_occluded(visual)


func _authoritative_occlusion_owner(collider: Node) -> Node:
	if collider.has_meta(COLLIDER_AUTHORITATIVE_META) and bool(collider.get_meta(COLLIDER_AUTHORITATIVE_META)):
		return collider
	if not collider.has_meta(GIANT_OWNER_META):
		return null
	var owner := collider.get_meta(GIANT_OWNER_META) as Node
	if owner == null or not is_instance_valid(owner):
		return null
	if owner.has_meta(COLLIDER_AUTHORITATIVE_META) and bool(owner.get_meta(COLLIDER_AUTHORITATIVE_META)):
		return owner
	return null


func _authoritative_owner_is_between_camera_and_player(owner: Node, camera_from: Vector3, target_point: Vector3) -> bool:
	if not owner is Node3D:
		return false
	var camera_to_target := target_point - camera_from
	var length_squared := camera_to_target.length_squared()
	if length_squared <= 0.000001:
		return false
	var owner_depth := ((owner as Node3D).global_position - camera_from).dot(camera_to_target) / length_squared
	return owner_depth > 0.005 and owner_depth < PLAYER_DEPTH_LIMIT


func _collider_visuals(collider: Node) -> Array[GeometryInstance3D]:
	var collider_id := collider.get_instance_id()
	if _collider_visual_cache.has(collider_id):
		return _collider_visual_cache[collider_id] as Array[GeometryInstance3D]
	var result: Array[GeometryInstance3D] = []
	var cursor := collider
	var scene := get_tree().current_scene
	for depth: int in 6:
		if cursor == null or cursor == scene:
			break
		if cursor is GeometryInstance3D:
			result.append(cursor as GeometryInstance3D)
			break
		var candidates := cursor.find_children("*", "GeometryInstance3D", true, false)
		if not candidates.is_empty():
			for node: Node in candidates:
				var visual := node as GeometryInstance3D
				if visual != null:
					result.append(visual)
			break
		cursor = cursor.get_parent()
	_collider_visual_cache[collider_id] = result
	return result


func _physics_visual_blocks_camera(world_aabb: AABB, segment_from: Vector3, segment_to: Vector3, camera_from: Vector3, target_point: Vector3, near_camera: bool) -> bool:
	if near_camera:
		return world_aabb.grow(_camera_overlap_shape.radius).has_point(camera_from)
	if world_aabb.grow(0.02).intersects_segment(segment_from, segment_to) == null:
		return false
	var maximum_extent := maxf(world_aabb.size.x, maxf(world_aabb.size.y, world_aabb.size.z))
	if maximum_extent > LARGE_VISUAL_EXTENT:
		# The physics ray already proved an actual surface hit. Large terrain and
		# architecture batches cannot use their often map-sized AABB centre.
		return true
	return _visual_center_is_before_player(world_aabb, camera_from, target_point)


func _visual_center_is_before_player(world_aabb: AABB, camera_from: Vector3, target_point: Vector3) -> bool:
	var camera_to_target := target_point - camera_from
	var length_squared := camera_to_target.length_squared()
	if length_squared <= 0.000001:
		return false
	var center_depth := (world_aabb.get_center() - camera_from).dot(camera_to_target) / length_squared
	return center_depth > 0.005 and center_depth < PLAYER_DEPTH_LIMIT


func _mark_occluded(visual: GeometryInstance3D) -> void:
	set_process(true)
	var instance_id := visual.get_instance_id()
	if not _fade_states.has(instance_id):
		var state := {
			&"visual_id": instance_id,
			&"transparency": visual.transparency,
			&"cast_shadow": visual.cast_shadow,
			&"material_override": visual.material_override,
			&"material_overlay": visual.material_overlay,
			&"surface_overrides": [],
			&"fade_materials": [],
			&"fade_base_alphas": [],
			&"uses_surface_overrides": false,
			&"fade_factor": 1.0,
			&"occluded": true,
		}
		_install_fade_materials(state)
		_fade_states[instance_id] = state
	else:
		(_fade_states[instance_id] as Dictionary)[&"occluded"] = true


func _install_fade_materials(state: Dictionary) -> void:
	var visual := _state_visual(state)
	if visual == null:
		return
	# Overlays are additional draws and otherwise remain opaque above the fade.
	visual.material_overlay = null
	var original_override := visual.material_override
	if visual is MeshInstance3D and original_override == null:
		var mesh_instance := visual as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
			var originals: Array[Material] = []
			var fade_materials: Array[BaseMaterial3D] = []
			var base_alphas: Array[float] = []
			for surface_index: int in mesh_instance.mesh.get_surface_count():
				var original_surface_override := mesh_instance.get_surface_override_material(surface_index)
				var source := original_surface_override
				if source == null:
					source = mesh_instance.mesh.surface_get_material(surface_index)
				var fade_material := _make_fade_material(source)
				originals.append(original_surface_override)
				fade_materials.append(fade_material)
				base_alphas.append(fade_material.albedo_color.a)
				mesh_instance.set_surface_override_material(surface_index, fade_material)
			state[&"surface_overrides"] = originals
			state[&"fade_materials"] = fade_materials
			state[&"fade_base_alphas"] = base_alphas
			state[&"uses_surface_overrides"] = true
			return

	var fade_material := _make_fade_material(original_override)
	visual.material_override = fade_material
	state[&"fade_materials"] = [fade_material]
	state[&"fade_base_alphas"] = [fade_material.albedo_color.a]


func _make_fade_material(source: Material) -> BaseMaterial3D:
	var material := source.duplicate() as BaseMaterial3D if source is BaseMaterial3D else null
	if material == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(0.42, 0.34, 0.22, 1.0)
		fallback.metallic = 0.0
		fallback.roughness = 1.0
		fallback.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material = fallback
	# A duplicate retains its authored next_pass resource; never let that pass
	# draw an opaque second layer, or mutate the shared source material.
	material.next_pass = null
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Imported cloth/armor is double-sided. Alpha blending alone leaves its
	# inward-facing walls covering the view when the camera enters the model.
	# Only the temporary fade copy is single-sided; restore the authored
	# material (including double-sided cloth/shield backs) when fading ends.
	if material.cull_mode == BaseMaterial3D.CULL_DISABLED:
		material.cull_mode = BaseMaterial3D.CULL_BACK
	return material


func _set_fade_material_factor(state: Dictionary, factor: float) -> void:
	var fade_materials := state.get(&"fade_materials", []) as Array
	var base_alphas := state.get(&"fade_base_alphas", []) as Array
	for index: int in mini(fade_materials.size(), base_alphas.size()):
		var material := fade_materials[index] as BaseMaterial3D
		if material == null:
			continue
		var color := material.albedo_color
		color.a = clampf(float(base_alphas[index]) * factor, 0.0, 1.0)
		material.albedo_color = color


func _restore_fade_materials(state: Dictionary) -> void:
	var visual := _state_visual(state)
	if visual == null:
		return
	if visual.material_overlay == null:
		visual.material_overlay = state.get(&"material_overlay") as Material
	var fade_materials := state.get(&"fade_materials", []) as Array
	if bool(state.get(&"uses_surface_overrides", false)) and visual is MeshInstance3D:
		var mesh_instance := visual as MeshInstance3D
		var originals := state.get(&"surface_overrides", []) as Array
		for index: int in mini(fade_materials.size(), originals.size()):
			if mesh_instance.get_surface_override_material(index) == fade_materials[index]:
				mesh_instance.set_surface_override_material(index, originals[index] as Material)
	elif not fade_materials.is_empty() and visual.material_override == fade_materials[0]:
		visual.material_override = state.get(&"material_override") as Material


func _is_ignored_visual(visual: GeometryInstance3D) -> bool:
	if target != null and (visual == target or target.is_ancestor_of(visual)):
		return true
	return _is_camera_occlusion_ignored(visual)


func _is_camera_occlusion_ignored(node: Node) -> bool:
	var instance_id := node.get_instance_id()
	if _ignore_cache.has(instance_id):
		return bool(_ignore_cache[instance_id])
	var cursor := node
	var scene := get_tree().current_scene
	while cursor != null and cursor != scene:
		if cursor.is_in_group(IGNORE_GROUP):
			_ignore_cache[instance_id] = true
			return true
		if cursor.has_meta(IGNORE_META) and bool(cursor.get_meta(IGNORE_META)):
			_ignore_cache[instance_id] = true
			return true
		var normalized_name := String(cursor.name).to_snake_case().to_lower()
		var name_parts := normalized_name.split("_", false)
		for terrain_part: String in BASE_TERRAIN_NAME_PARTS:
			if name_parts.has(terrain_part):
				_ignore_cache[instance_id] = true
				return true
		cursor = cursor.get_parent()
	_ignore_cache[instance_id] = false
	return false


func _restore_visual_state(state: Dictionary) -> void:
	var visual := _state_visual(state)
	if visual == null:
		return
	visual.transparency = float(state[&"transparency"])
	visual.cast_shadow = int(state[&"cast_shadow"]) as GeometryInstance3D.ShadowCastingSetting
	_restore_fade_materials(state)


func _state_visual(state: Dictionary) -> GeometryInstance3D:
	var instance_id := int(state.get(&"visual_id", 0))
	if instance_id <= 0:
		return null
	# instance_from_id() returns null once the render node has really been
	# destroyed, unlike a Dictionary-held Object reference which becomes the
	# dangerous "previously freed" sentinel seen in the runtime error.
	return instance_from_id(instance_id) as GeometryInstance3D


func _mark_all_for_restore() -> void:
	for raw_state: Variant in _fade_states.values():
		var state := raw_state as Dictionary
		state[&"occluded"] = false


func _cache_existing_visuals() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_register_visuals_recursive(scene)


func _register_visuals_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		_register_visual(node as GeometryInstance3D)
	for child: Node in node.get_children():
		_register_visuals_recursive(child)


func _register_visual(visual: GeometryInstance3D) -> void:
	var instance_id := visual.get_instance_id()
	if _visuals.has(instance_id):
		return
	var record := {
		&"visual": visual,
		&"cells": [],
		&"physics_driven": _has_moving_physics_ancestor(visual),
	}
	_visuals[instance_id] = record
	# CharacterBody, RigidBody and AnimatableBody visuals move with a physics
	# collider. The ray pass follows them live, so duplicating them in a static
	# render index would create stale cells without improving coverage.
	if not bool(record[&"physics_driven"]):
		_index_visual(instance_id, record)


func _index_visual(instance_id: int, record: Dictionary) -> void:
	_unindex_visual(instance_id, record)
	var visual := record.get(&"visual") as GeometryInstance3D
	if visual == null or not is_instance_valid(visual) or not visual.is_inside_tree():
		return
	var local_aabb := visual.get_aabb()
	if local_aabb.size.length_squared() <= 0.000001:
		return
	var world_aabb: AABB = visual.global_transform * local_aabb
	# Keep the existing behavior for terrain, architecture batches and
	# MultiMeshes: their broad AABB must not fade an entire map or forest. Real
	# collision surfaces remain covered by the physics pass.
	if maxf(world_aabb.size.x, maxf(world_aabb.size.y, world_aabb.size.z)) > LARGE_VISUAL_EXTENT:
		return
	var minimum_cell := _world_to_cell(world_aabb.position)
	var maximum_cell := _world_to_cell(world_aabb.end)
	var occupied_cells: Array[Vector3i] = []
	for cell_x: int in range(minimum_cell.x, maximum_cell.x + 1):
		for cell_y: int in range(minimum_cell.y, maximum_cell.y + 1):
			for cell_z: int in range(minimum_cell.z, maximum_cell.z + 1):
				var cell := Vector3i(cell_x, cell_y, cell_z)
				var bucket: Dictionary
				var raw_bucket: Variant = _spatial_cells.get(cell)
				if raw_bucket is Dictionary:
					bucket = raw_bucket as Dictionary
				else:
					bucket = {}
					_spatial_cells[cell] = bucket
				bucket[instance_id] = visual
				occupied_cells.append(cell)
	record[&"cells"] = occupied_cells


func _unindex_visual(instance_id: int, record: Dictionary) -> void:
	var occupied_cells := record.get(&"cells", []) as Array
	for raw_cell: Variant in occupied_cells:
		var cell: Vector3i = raw_cell
		var raw_bucket: Variant = _spatial_cells.get(cell)
		if not raw_bucket is Dictionary:
			continue
		var bucket := raw_bucket as Dictionary
		bucket.erase(instance_id)
		if bucket.is_empty():
			_spatial_cells.erase(cell)
	record[&"cells"] = []


func _remove_visual(instance_id: int, restore_state: bool) -> void:
	_pending_visuals.erase(instance_id)
	if _fade_states.has(instance_id):
		if restore_state:
			_restore_visual_state(_fade_states[instance_id] as Dictionary)
		_fade_states.erase(instance_id)
	if not _visuals.has(instance_id):
		return
	var record := _visuals[instance_id] as Dictionary
	_unindex_visual(instance_id, record)
	_visuals.erase(instance_id)


func _has_moving_physics_ancestor(visual: GeometryInstance3D) -> bool:
	var cursor: Node = visual
	var scene := get_tree().current_scene
	while cursor != null and cursor != scene:
		if cursor is CharacterBody3D or cursor is RigidBody3D or cursor is AnimatableBody3D:
			return true
		cursor = cursor.get_parent()
	return false


func _queue_visual_registration(visual: GeometryInstance3D) -> void:
	_pending_visuals[visual.get_instance_id()] = visual
	if _pending_visual_flush_scheduled:
		return
	_pending_visual_flush_scheduled = true
	_flush_pending_visual_registrations.call_deferred()


func _flush_pending_visual_registrations() -> void:
	_pending_visual_flush_scheduled = false
	var pending := _pending_visuals
	_pending_visuals = {}
	for raw_visual: Variant in pending.values():
		var visual := raw_visual as GeometryInstance3D
		if visual != null and is_instance_valid(visual) and visual.is_inside_tree():
			_register_visual(visual)


func _on_tree_node_added(node: Node) -> void:
	if node is GeometryInstance3D:
		# A newly added mesh may belong below a collider already resolved by a prior
		# ray. Invalidate only for render-tree changes; transient non-visual gameplay
		# nodes cannot change collider-to-visual ownership.
		_collider_visual_cache.clear()
		_queue_visual_registration(node as GeometryInstance3D)


func _on_tree_node_removed(node: Node) -> void:
	var instance_id := node.get_instance_id()
	_ignore_cache.erase(instance_id)
	if not node is GeometryInstance3D:
		return
	_collider_visual_cache.clear()
	# Transient mesh removals do not invalidate the actor list. The dynamic scan
	# already prunes freed actors; clearing here starves collider-free V2 bodies.
	_remove_visual(instance_id, true)


func _apply_spring_arm_policy() -> void:
	if spring_arm == null or not is_instance_valid(spring_arm):
		return
	if not _spring_arm_mask_captured:
		_spring_arm_collision_mask = spring_arm.collision_mask
		_spring_arm_mask_captured = true
	spring_arm.collision_mask = 0 if enabled else _spring_arm_collision_mask


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	outline_color = config.get_value("display", "camera_outline_color", DEFAULT_OUTLINE_COLOR)
	enemy_attack_outline_color = config.get_value("display", "enemy_attack_outline_color", DEFAULT_ENEMY_ATTACK_OUTLINE_COLOR)
	outline_opacity = clampf(float(config.get_value("display", "camera_outline_opacity", DEFAULT_OUTLINE_OPACITY)), 0.0, 1.0)
	enabled = bool(config.get_value("display", "camera_occlusion", enabled))
	occluder_opacity = clampf(float(config.get_value("display", "camera_occlusion_opacity", occluder_opacity)), 0.02, 0.45)
	probe_radius = clampf(float(config.get_value("display", "camera_occlusion_radius", probe_radius)), 0.10, 1.20)


func _exit_tree() -> void:
	if get_tree() != null:
		if get_tree().node_added.is_connected(_on_tree_node_added):
			get_tree().node_added.disconnect(_on_tree_node_added)
		if get_tree().node_removed.is_connected(_on_tree_node_removed):
			get_tree().node_removed.disconnect(_on_tree_node_removed)
	for raw_state: Variant in _fade_states.values():
		_restore_visual_state(raw_state as Dictionary)
	_fade_states.clear()
	_visuals.clear()
	_spatial_cells.clear()
	_pending_visuals.clear()
	_visited_visuals.clear()
	_stale_visual_ids.clear()
	_ignore_cache.clear()
	_collider_visual_cache.clear()
	_dynamic_actors.clear()
	if spring_arm != null and is_instance_valid(spring_arm) and _spring_arm_mask_captured:
		spring_arm.collision_mask = _spring_arm_collision_mask
