extends Node3D
class_name HopliteV2ImpostorBatch

const ATLAS_PATH := "res://assets/characters/enemy_v2/hoplite/impostor/hoplite_v2_guard_cycle.png"
const ROLE_ATLASES := {
	&"archer": "res://assets/characters/enemy_v2/hoplite/impostor/archer_v2_cycle.png",
	&"infantry": "res://assets/characters/enemy_v2/hoplite/impostor/infantry_v2_cycle.png",
}
const IMPOSTOR_SHADER := preload("res://scripts/enemy_v2/hoplite_v2_impostor.gdshader")
const UPDATE_INTERVAL := 0.25
# Calibrated in the project's real viewport/stretch path against the live 3D
# actor. The unusual nominal size and pivot compensate the billboard matrix and
# atlas framing so the silhouette and feet match exactly at the LOD hand-off.
const QUAD_SIZE := Vector2(4.82, 7.14)
const ORIGIN_Y := -0.52

var tracked: Dictionary = {}
var elapsed := 0.0
var capacity := 0
var dirty := false
var renderer: MultiMeshInstance3D
var multi_mesh: MultiMesh
var installed := false
## Root retains the historical phalanx batch and lazily creates at most two
## role batches. No extra renderer or processing callback is added per actor.
var batch_role: StringName = &"phalanx"
var role_batches: Dictionary = {}


func _ready() -> void:
	top_level = true
	process_priority = 30
	installed = _install_renderer()
	set_process(false)


func set_actor_active(actor: Node3D, active: bool) -> void:
	if actor == null:
		return
	var role := StringName(actor.get_meta("enemy_v2_impostor_role", &"phalanx"))
	if batch_role == &"phalanx" and ROLE_ATLASES.has(role):
		if active or role_batches.has(role):
			_role_batch(role).set_actor_active(actor, active)
		return
	var actor_id := actor.get_instance_id()
	if not active:
		tracked.erase(actor_id)
		dirty = true
		set_process(installed)
		return
	tracked[actor_id] = weakref(actor)
	dirty = true
	set_process(installed)


func remove_actor(actor: Node3D) -> void:
	if actor != null:
		var role := StringName(actor.get_meta("enemy_v2_impostor_role", &"phalanx"))
		if batch_role == &"phalanx" and role_batches.has(role):
			(role_batches[role] as HopliteV2ImpostorBatch).remove_actor(actor)
			return
		tracked.erase(actor.get_instance_id())
	dirty = true
	set_process(installed)


func active_count() -> int:
	var total := tracked.size()
	for child_batch: HopliteV2ImpostorBatch in role_batches.values():
		total += child_batch.active_count()
	return total


func _role_batch(role: StringName) -> HopliteV2ImpostorBatch:
	if not role_batches.has(role):
		var child_batch := HopliteV2ImpostorBatch.new()
		child_batch.name = "%sImpostors" % String(role).to_pascal_case()
		child_batch.batch_role = role
		role_batches[role] = child_batch
		add_child(child_batch)
	return role_batches[role] as HopliteV2ImpostorBatch


func _process(delta: float) -> void:
	elapsed += delta
	if not dirty and elapsed < UPDATE_INTERVAL:
		return
	elapsed = 0.0 if dirty else fmod(elapsed, UPDATE_INTERVAL)
	dirty = false
	_refresh_instances()


func _install_renderer() -> bool:
	var atlas_path := String(ROLE_ATLASES.get(batch_role, ATLAS_PATH))
	if not ResourceLoader.exists(atlas_path):
		push_warning("Enemy V2 impostor atlas is missing: %s" % atlas_path)
		return false
	var atlas := load(atlas_path) as Texture2D
	if atlas == null:
		return false
	var material := ShaderMaterial.new()
	material.shader = IMPOSTOR_SHADER
	material.set_shader_parameter(&"impostor_atlas", atlas)
	var quad := QuadMesh.new()
	quad.size = QUAD_SIZE * _role_frame_scale()
	quad.material = material
	multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_custom_data = true
	multi_mesh.mesh = quad
	renderer = MultiMeshInstance3D.new()
	renderer.name = "HopliteV2FarImpostors"
	renderer.multimesh = multi_mesh
	renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	renderer.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	renderer.custom_aabb = AABB(Vector3(-2000.0, -10.0, -2000.0), Vector3(4000.0, 30.0, 4000.0))
	add_child(renderer)
	return true


func _refresh_instances() -> void:
	if not installed or multi_mesh == null:
		set_process(false)
		return
	var actors: Array[Node3D] = []
	for raw_id: Variant in tracked.keys():
		var reference := tracked[raw_id] as WeakRef
		var actor := reference.get_ref() as Node3D if reference != null else null
		if actor == null or not is_instance_valid(actor) or bool(actor.get("dead")):
			tracked.erase(raw_id)
			continue
		if actor.has_method("far_impostor_lod_tick"):
			actor.call("far_impostor_lod_tick")
			if int(actor.get_meta("enemy_v2_lod_level", 0)) < 3:
				tracked.erase(raw_id)
				continue
		actors.append(actor)
	_ensure_capacity(actors.size())
	for index: int in range(actors.size()):
		var actor := actors[index]
		var scale := float(actor.call("impostor_visual_scale")) if actor.has_method("impostor_visual_scale") else 1.0
		# Archer frame leaves extra room above the helmet for the tall bow. Keep
		# body height and feet identical when expanding its billboard geometry.
		var origin_y := ORIGIN_Y + QUAD_SIZE.y * (_role_frame_scale() - 1.0) * 0.484375
		var transform := Transform3D(Basis.IDENTITY, actor.global_position + Vector3.UP * origin_y * scale)
		multi_mesh.set_instance_transform(index, transform)
		var phase := float(actor.get_instance_id() % 997) / 997.0
		multi_mesh.set_instance_custom_data(index, Color(phase, scale, 0.0, 1.0))
	multi_mesh.visible_instance_count = actors.size()
	set_process(not actors.is_empty())


func _ensure_capacity(required: int) -> void:
	if required <= capacity:
		return
	capacity = maxi(16, capacity)
	while capacity < required:
		capacity *= 2
	multi_mesh.instance_count = capacity


func _role_frame_scale() -> float:
	return 256.0 / 224.0 if batch_role == &"archer" else 1.0
