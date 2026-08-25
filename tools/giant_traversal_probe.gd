extends SceneTree

const EnemyScript = preload("res://scripts/enemy/athenian_enemy.gd")
const PlayerScript = preload("res://scripts/player.gd")
const HitEventScript = preload("res://scripts/combat/hit_event.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	world.name = "GiantTraversalProbeWorld"
	root.add_child(world)
	current_scene = world

	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(30.0, 0.2, 30.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.1
	floor.add_child(floor_collision)
	world.add_child(floor)

	var giant := EnemyScript.new() as HopliteAthenianEnemy
	giant.name = "ForgeGiantTraversalProbe"
	giant.archetype_id = &"giant_standard"
	giant.ai_enabled = true
	giant.external_scale_multiplier = 3.0
	giant.match_perfect_hitbox = true
	giant.position = Vector3(0.0, 1.0, 0.0)
	world.add_child(giant)

	var player := PlayerScript.new() as HopliteUALNativePlayer
	player.name = "GiantTraversalProbePlayer"
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector3(0.0, 1.0, 5.0)
	world.add_child(player)

	for _frame: int in range(75):
		await physics_frame

	_assert(giant.anatomy != null, "giant anatomy missing")
	if giant.anatomy == null:
		_finish()
		return
	_assert(giant.giant_traversal_mode == &"assisted", "giant profile did not select assisted traversal")
	_assert(giant.body_collider != null and not giant.body_collider.disabled, "internal world-floor collider is disabled")
	_assert(giant.collision_layer == 0, "internal floor collider is still exposed to player collision")
	_assert(giant.is_on_floor(), "assisted giant did not settle on the Forge floor")
	_assert(giant.global_position.y > -0.05, "assisted giant passed through the Forge floor")
	_assert(giant.matched_physical_colliders.is_empty(), "assisted giant still exposes animated convex physics")
	_assert(giant.giant_traversal_body != null and giant.giant_traversal_body.collision_layer == 256, "independent smooth traversal body missing")
	_assert(giant.giant_traversal_collision.shape is CylinderShape3D, "assisted body traversal is not a smooth cylinder")
	_assert(giant.giant_traversal_head_body != null and giant.giant_traversal_head_body.collision_layer == 256, "exact head traversal body missing")
	_assert(giant.giant_traversal_head_collision != null and giant.giant_traversal_head_collision.shape is ConvexPolygonShape3D, "head collider was not extracted from the real mesh")
	_assert(giant.matched_walkable_surfaces.size() == 1 and giant.matched_walkable_surfaces[0].name == "HeadFloor", "assisted traversal should keep only the exact-head top stabilizer")
	_assert(giant.is_wall_run_giant(), "standard-size Forge giant did not opt into wallrun")
	var torso_center: Vector3 = giant.anatomy.get_zone_world_center(&"torso")
	var pelvis_center: Vector3 = giant.anatomy.get_zone_world_center(&"pelvis")
	var head_center: Vector3 = giant.anatomy.get_zone_world_center(&"head")
	print("GIANT_TRAVERSAL_GEOMETRY torso=", torso_center, " pelvis=", pelvis_center, " head=", head_center, " arms=", giant.anatomy.get_zone_world_center(&"upper_arm_l"), "/", giant.anatomy.get_zone_world_center(&"upper_arm_r"), " radii=", giant.anatomy.get_zone_radius(&"torso"), "/", giant.anatomy.get_zone_radius(&"pelvis"), "/", giant.anatomy.get_zone_radius(&"head"))
	var traversal_shape := giant.giant_traversal_collision.shape as CylinderShape3D
	var standing_traversal_radius := traversal_shape.radius
	print("GIANT_TRAVERSAL_COLLIDERS matched=", giant.matched_physical_colliders.size(), " walkable=", giant.matched_walkable_surfaces.size(), " body_disabled=", giant.body_collider.disabled, " floor_layer=", giant.collision_layer, " on_floor=", giant.is_on_floor(), " giant_y=", giant.global_position.y, " traversal_layer=", giant.giant_traversal_body.collision_layer, " cylinder_height=", traversal_shape.height if traversal_shape != null else -1.0, " cylinder_radius=", traversal_shape.radius if traversal_shape != null else -1.0, " traversal_center=", giant.giant_traversal_body.global_position, " head_mesh=", giant.giant_traversal_head_collision.get_meta("matched_model_mesh", ""))
	var torso_collision := giant.matched_physical_colliders.get(&"torso") as CollisionShape3D
	if torso_collision != null and torso_collision.shape is ConvexPolygonShape3D:
		var hull := torso_collision.shape as ConvexPolygonShape3D
		var minimum := Vector3(INF, INF, INF)
		var maximum := Vector3(-INF, -INF, -INF)
		for point: Vector3 in hull.points:
			var world_point: Vector3 = torso_collision.global_transform * point
			minimum = minimum.min(world_point)
			maximum = maximum.max(world_point)
		print("GIANT_TRAVERSAL_TORSO_BOUNDS min=", minimum, " max=", maximum, " size=", maximum - minimum)

	var directions: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
	var torso_hits := 0
	var rejected_torso_normals := 0
	for direction: Vector3 in directions:
		var hit := _ray(giant, torso_center + direction * 5.0, torso_center - direction * 5.0, 256)
		if not hit.is_empty():
			torso_hits += 1
			var normal := hit.get("normal", Vector3.ZERO) as Vector3
			if absf(normal.dot(Vector3.UP)) > 0.48:
				rejected_torso_normals += 1
			print("GIANT_TRAVERSAL_TORSO dir=", direction, " point=", hit.get("position"), " normal=", normal, " collider=", (hit.get("collider") as Node).name)
	_assert(torso_hits == directions.size(), "smooth torso cannot be reached from every horizontal direction")
	_assert(rejected_torso_normals == 0, "torso still returns normals rejected by player wallrun")

	var false_floor_hits := 0
	var shoulder_floor_y := minf(torso_center.y + 0.30 * giant.global_basis.get_scale().y, head_center.y - 0.08 * giant.global_basis.get_scale().y)
	for zone: StringName in [&"thigh_l", &"thigh_r", &"shin_l", &"shin_r"]:
		var center: Vector3 = giant.anatomy.get_zone_world_center(zone)
		var hit := _ray(giant, center + Vector3.UP * 4.0, center + Vector3.DOWN * 0.2, 256)
		var hit_point := hit.get("position", Vector3.ZERO) as Vector3
		if not hit.is_empty() and hit.get("collider") != giant.giant_traversal_body and (hit.get("normal", Vector3.ZERO) as Vector3).dot(Vector3.UP) > 0.72 and hit_point.y < shoulder_floor_y - 0.02:
			false_floor_hits += 1
			print("GIANT_TRAVERSAL_FALSE_FLOOR zone=", zone, " point=", hit.get("position"), " normal=", hit.get("normal"))
	print("GIANT_TRAVERSAL_FALSE_FLOOR_COUNT ", false_floor_hits)
	_assert(false_floor_hits == 0, "limbs still expose intermediate floor-like facets")

	var player_hit := _ray(giant, torso_center + Vector3.BACK * 5.0, torso_center + Vector3.FORWARD * 5.0, 256)
	_assert(not player_hit.is_empty() and player._wall_run_hit_kind(player_hit) == &"giant_enemy", "player does not classify the scaled giant torso")
	var head_hit := _ray(giant, head_center + Vector3.BACK * 5.0, head_center + Vector3.FORWARD * 5.0, 256)
	_assert(not head_hit.is_empty() and head_hit.get("collider") == giant.giant_traversal_head_body, "ray at head height does not reach the real head mesh")
	_assert(not head_hit.is_empty() and player._wall_run_hit_kind(head_hit) == &"giant_enemy", "real head mesh is not classified as giant traversal")
	var head_hull := giant.giant_traversal_head_collision.shape as ConvexPolygonShape3D
	var head_minimum := Vector3(INF, INF, INF)
	var head_maximum := Vector3(-INF, -INF, -INF)
	for point: Vector3 in head_hull.points:
		var head_world_point := giant.giant_traversal_head_body.global_transform * point
		head_minimum = head_minimum.min(head_world_point)
		head_maximum = head_maximum.max(head_world_point)
	var head_hull_size := head_maximum - head_minimum
	print("GIANT_TRAVERSAL_HEAD_BOUNDS min=", head_minimum, " max=", head_maximum, " size=", head_hull_size)
	_assert(head_hull_size.x < 2.8 and head_hull_size.y < 2.8 and head_hull_size.z < 2.8, "real head hull unexpectedly includes non-head geometry")
	var standing_cylinder_top := giant.giant_traversal_body.global_position.y + traversal_shape.height * 0.5
	_assert(head_minimum.y - standing_cylinder_top > -0.20 and head_minimum.y - standing_cylinder_top < 0.15, "standing body/head traversal split has a bad seam")
	_assert(absf(giant.matched_walkable_surfaces[0].global_position.y - head_maximum.y) < 0.06, "head-top stabilizer is not aligned to the real mesh")

	for leg_zone: StringName in [&"thigh_l", &"thigh_r"]:
		var state := giant.zone_state.get(leg_zone, {}) as Dictionary
		state["severed"] = true
		giant.zone_state[leg_zone] = state
		giant._disable_related_hitboxes(leg_zone)
		giant._hide_zone_bone_chain(leg_zone)
	giant._refresh_injury_state()
	for _frame: int in range(45):
		await physics_frame
	var crawl_torso := giant.anatomy.get_zone_world_center(&"torso")
	var crawl_pelvis := giant.anatomy.get_zone_world_center(&"pelvis")
	var crawl_head := giant.anatomy.get_zone_world_center(&"head")
	var crawl_shape := giant.giant_traversal_collision.shape as CylinderShape3D
	var crawl_core := crawl_torso * 0.50 + crawl_pelvis * 0.30 + crawl_head * 0.20
	print("GIANT_TRAVERSAL_CRAWL torso=", crawl_torso, " pelvis=", crawl_pelvis, " head=", crawl_head, " arms=", giant.anatomy.get_zone_world_center(&"upper_arm_l"), "/", giant.anatomy.get_zone_world_center(&"upper_arm_r"), " visual_y=", giant.visual_root.position.y, " visual_pitch=", rad_to_deg(giant.visual_root.rotation.x), " cylinder_center=", giant.giant_traversal_body.global_position, " height=", crawl_shape.height, " radius=", crawl_shape.radius, " head_center=", giant.giant_traversal_head_body.global_position)
	var crawl_cylinder_center := giant.giant_traversal_body.global_position
	var horizontal_offset := Vector2(crawl_cylinder_center.x - crawl_core.x, crawl_cylinder_center.z - crawl_core.z).length()
	_assert(horizontal_offset < 0.12, "crawl traversal cylinder does not follow the pitched skin core")
	_assert(crawl_shape.radius < standing_traversal_radius * 0.90, "crawl traversal cylinder did not become narrow enough")
	var body_scale := maxf(giant.global_basis.get_scale().y, 0.01)
	var expected_bottom := crawl_pelvis.y - giant.anatomy.get_zone_radius(&"pelvis") * body_scale * 0.72
	var expected_shoulder_top := minf(crawl_torso.y + 0.30 * body_scale, crawl_head.y - 0.08 * body_scale)
	_assert(crawl_cylinder_center.y - crawl_shape.height * 0.5 <= expected_bottom + 0.05, "crawl cylinder no longer covers the pelvis")
	_assert(absf(crawl_cylinder_center.y + crawl_shape.height * 0.5 - expected_shoulder_top) < 0.06, "crawl cylinder does not stop at shoulder height")
	_assert(giant.giant_traversal_head_body.global_position.distance_to(crawl_head) < 0.08, "real head collider does not follow the severed-leg pose")
	_assert(giant.is_on_floor() and giant.global_position.y > -0.05, "legless assisted giant lost its Forge floor collision")
	var crawl_torso_hits := 0
	for direction: Vector3 in directions:
		var crawl_hit := _ray(giant, crawl_torso + direction * 5.0, crawl_torso - direction * 5.0, 256)
		if not crawl_hit.is_empty():
			crawl_torso_hits += 1
			var crawl_normal := crawl_hit.get("normal", Vector3.ZERO) as Vector3
			_assert(absf(crawl_normal.dot(Vector3.UP)) <= 0.48, "crawl torso returns a normal rejected by wallrun")
			_assert(player._wall_run_hit_kind(crawl_hit) == &"giant_enemy", "crawl surface is no longer classified as a giant")
	_assert(crawl_torso_hits == directions.size(), "crawl torso cannot be reached from every horizontal direction")
	var crawl_head_hit := _ray(giant, crawl_head + Vector3.BACK * 5.0, crawl_head + Vector3.FORWARD * 5.0, 256)
	_assert(not crawl_head_hit.is_empty() and crawl_head_hit.get("collider") == giant.giant_traversal_head_body, "crawl head ray does not reach the real head mesh")
	# Damage Areas must reach the outside of the wallrun body. They follow bone
	# positions in world space, so this guards against accidentally retaining
	# human-sized radii when Forge scales the giant.
	var crawl_damage_hit := _area_ray(giant, crawl_torso + Vector3.BACK * 5.0, crawl_torso + Vector3.FORWARD * 5.0, 8)
	_assert(not crawl_damage_hit.is_empty(), "legless giant exposes no damage Area at torso height")
	if not crawl_damage_hit.is_empty():
		var damage_collider := crawl_damage_hit.get("collider") as Node
		var damage_shape_index := int(crawl_damage_hit.get("shape", -1))
		var damage_zone := StringName(damage_collider.call("zone_from_shape_index", damage_shape_index)) if damage_collider != null and damage_collider.has_method("zone_from_shape_index") else StringName()
		var damage_radius := float(damage_collider.call("zone_radius_from_shape_index", damage_shape_index)) if damage_collider != null and damage_collider.has_method("zone_radius_from_shape_index") else 0.0
		print("GIANT_TRAVERSAL_CRAWL_DAMAGE zone=", damage_zone, " radius=", damage_radius, " hit=", crawl_damage_hit.get("position"))
		_assert(damage_zone != StringName(), "legless giant damage ray did not resolve an anatomy zone")
		_assert(damage_radius >= crawl_shape.radius * 0.90, "legless giant damage hitbox remains trapped inside the wallrun body")
		if damage_collider != null and damage_zone != StringName() and damage_collider.has_method("receive_weapon_hit_zone"):
			var test_hit = HitEventScript.new()
			test_hit.source = player
			test_hit.position = crawl_damage_hit.get("position", crawl_torso)
			test_hit.direction = Vector3.FORWARD
			test_hit.damage = 7.0
			test_hit.sever_damage = 0.0
			var health_before := giant.health
			var accepted := bool(damage_collider.call("receive_weapon_hit_zone", test_hit, damage_zone))
			_assert(accepted and giant.health < health_before, "legless giant anatomy accepts contact but no longer takes damage")
	var crawl_head_min_y := INF
	for point: Vector3 in head_hull.points:
		crawl_head_min_y = minf(crawl_head_min_y, (giant.giant_traversal_head_body.global_transform * point).y)
	var crawl_cylinder_top := crawl_cylinder_center.y + crawl_shape.height * 0.5
	_assert(crawl_head_min_y - crawl_cylinder_top > -0.20 and crawl_head_min_y - crawl_cylinder_top < 0.15, "crawl body/head traversal split has a bad seam")
	_finish()

func _ray(giant: Node3D, from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return giant.get_world_3d().direct_space_state.intersect_ray(query)

func _area_ray(giant: Node3D, from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	query.collide_with_bodies = false
	query.collide_with_areas = true
	return giant.get_world_3d().direct_space_state.intersect_ray(query)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("GIANT_TRAVERSAL_PROBE PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error("GIANT_TRAVERSAL_PROBE FAILED: " + failure)
	quit(1)
