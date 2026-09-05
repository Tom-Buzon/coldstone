extends Node

const Package = preload("res://scripts/enemy/spartan_character_package.gd")
var actor: Node3D
var skeleton: Skeleton3D
var anatomy: HopliteAnatomyHitbox
var definition: HopliteEnemyV2Definition
var severed_zones: Dictionary = {}
var last_fragment: RigidBody3D

func install(value: Node3D, rig: Skeleton3D, anatomy_value: HopliteAnatomyHitbox, data: HopliteEnemyV2Definition) -> bool:
	actor = value
	skeleton = rig
	anatomy = anatomy_value
	definition = data
	return true

func sever(zone: StringName, hit: Variant) -> bool:
	var package: HopliteSpartanCharacterPackage = actor.presentation.package
	zone = package.normalize_cut_zone(zone)
	if severed_zones.has(zone) or not package.body_caps.has(zone):
		return false
	var packed := load(definition.body_scene_path) as PackedScene
	var visual := packed.instantiate() as Node3D
	var fragment := RigidBody3D.new()
	fragment.name = "GiantV2Fragment_" + String(zone)
	fragment.collision_layer = 0
	fragment.collision_mask = 1
	fragment.mass = 4.0
	fragment.linear_damp = 1.8
	fragment.angular_damp = 3.0
	actor.get_parent().add_child(fragment)
	fragment.add_child(visual)
	visual.global_transform = actor.presentation.visual_root.global_transform
	var detached := Package.new()
	if not detached.bind(visual):
		fragment.queue_free()
		return false
	detached.copy_pose_from(skeleton)
	detached.show_detached_branch(zone)
	var pivot := anatomy.get_zone_world_center(zone)
	var old_transform := visual.global_transform
	fragment.global_position = pivot
	visual.global_transform = old_transform
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = anatomy.get_zone_world_radius(zone)
	collision.shape = shape
	fragment.add_child(collision)
	fragment.linear_velocity = Vector3.UP * 2.0 + (hit.direction as Vector3).normalized() * 3.0
	fragment.angular_velocity = Vector3(0.2, 0.7, 0.4)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 9.0
	fragment.add_child(timer)
	timer.timeout.connect(fragment.queue_free)
	timer.start()
	fragment.add_to_group("enemy_v2_fragment")
	package.sever_body(zone)
	for child_zone: StringName in package.branch_for(zone):
		severed_zones[child_zone] = true
		anatomy.disable_zone(child_zone)
	if zone == &"head":
		anatomy.disable_zone(&"neck")
	preload("res://scripts/enemy_v2/enemy_v2_team_palette.gd").apply(fragment,actor.faction)
	last_fragment = fragment
	if zone in [&"thigh_l", &"shin_l", &"thigh_r", &"shin_r"]:
		actor.combat.on_guard_broken(1.6, 0.0, Vector3.ZERO)
		actor.refresh_leg_injury()
	return true

func is_severed(zone: StringName) -> bool:
	return severed_zones.has(zone)
