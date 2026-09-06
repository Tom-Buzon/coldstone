extends Node3D

const Contact = preload("res://scripts/abilities/projectile_contact.gd")
var resolved := false

const Damage = preload("res://scripts/abilities/skill_damage.gd")
var source: Node3D
var direction := Vector3.FORWARD
var speed := 48.0
var damage := 45.0
var thunder := false
var charge_ratio := 0.0
var spear_visual: Node3D
var lifetime := 3.0
var launch_point := Vector3.ZERO
var trail_age := 0.0
var query := PhysicsRayQueryParameters3D.new()

func _ready() -> void:
	top_level = true
	launch_point = global_position
	add_to_group(&"camera_occlusion_ignore")
	query.collision_mask = 1 if thunder else (1 | 4 | 8 | 64 | 256)
	query.collide_with_areas = true
	if source is CollisionObject3D: query.exclude = [source.get_rid()]
	if thunder:
		spear_visual = preload("res://scripts/abilities/electric_javelin.gd").new()
		add_child(spear_visual)
		spear_visual.set_charge(charge_ratio)
	else:
		var mesh := MeshInstance3D.new()
		var spear := CylinderMesh.new()
		spear.top_radius = 0.0
		spear.bottom_radius = 0.055 if thunder else 0.025
		spear.height = 1.8 if thunder else 1.2
		mesh.mesh = spear
		mesh.rotation.x = PI * 0.5
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.35, 0.8, 1.0) if thunder else Color(1.0, 0.7, 0.3)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
	look_at(global_position + direction, Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var end := global_position + direction * speed * delta
	query.from = global_position
	query.to = end
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Node3D
	var zone: StringName = &"torso"
	var contact: Vector3 = hit.position if not hit.is_empty() else end
	var nearest_distance := global_position.distance_to(contact) if not hit.is_empty() else global_position.distance_to(end) + 0.001
	if not hit.is_empty():
		var collider: Node = hit.collider
		if collider.has_method("get_combat_owner"):
			target = collider.get_combat_owner() as Node3D
			if collider.has_method("zone_from_shape_index"): zone = collider.zone_from_shape_index(hit.shape)
		elif collider.is_in_group(&"enemy"): target = collider as Node3D
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		if not node is Node3D or not Damage.alive(node): continue
		var size: float = float(node.get("size_multiplier")) if node.get("size_multiplier") != null else maxf(node.global_basis.get_scale().length(), 1.0)
		if node.get("body_scale_factor") != null:
			size = maxf(size, float(node.body_scale_factor) * float(node.external_scale_multiplier))
		var bound := size * 5.0 + 3.0
		if node.global_position.distance_to(Geometry3D.get_closest_point_to_segment(node.global_position, global_position, end)) > bound: continue
		var precise: Dictionary = Contact.anatomy_hit(node, global_position, end) if thunder else {}
		if not precise.is_empty() and precise.distance <= nearest_distance + 0.01:
			target = node
			nearest_distance = precise.distance
			contact = precise.position
			zone = precise.zone
		elif Contact.anatomy_for(node) == null or not thunder:
			var center: Vector3 = node.global_position + Vector3.UP
			var distance := Contact._sphere(global_position, direction, center, 0.45)
			if distance < nearest_distance:
				target = node
				nearest_distance = distance
				contact = global_position + direction * distance
				zone = &"torso"
	if thunder and source.get("skills") != null:
		trail_age += delta
		if trail_age >= 0.008:
			trail_age = 0.0
			source.skills.cinema.vfx.beam(global_position, contact, Color(0.3, 0.85, 1), lerpf(0.12, 0.32, charge_ratio), 0.35)
	if target != null or not hit.is_empty():
		global_position = contact
		impact(target, zone, contact)
	else: global_position = end

func impact(target: Node3D, zone: StringName, point: Vector3) -> void:
	if resolved: return
	resolved = true
	if target != null:
		Damage.deal(source, target, damage, direction, 24.0 if thunder else 3.0, &"thunder" if thunder else &"javelin", 1000.0 if thunder else 0.0, thunder, zone, point)
	if thunder and source.get("skills") != null:
		var radius: float = source.skills.value(&"thunder_radius") * lerpf(0.6, 1.0, charge_ratio)
		Damage.radial(source, point, radius, damage * source.skills.value(&"thunder_blast"), 20.0, &"thunder_blast", target.get_instance_id() if is_instance_valid(target) else 0)
		source.skills.cinema.vfx.electric_explosion(point, radius)
		source.skills.cinema.thunder_view.impact(self, point, radius)
		source.skills.cinema.accent(0.24, 0.10, 12.0)
		if source.get("combat_feedback") != null: source.combat_feedback.spiral_smash(point, radius)
	queue_free()
