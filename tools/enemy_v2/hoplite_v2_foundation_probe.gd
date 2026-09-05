extends SceneTree

const Package = preload("res://scripts/enemy_v2/hoplite_v2_package.gd")
const Catalog = preload("res://scripts/enemy_v2/hoplite_v2_catalog.gd")
const ShadowFactory = preload("res://scripts/enemy_v2/hoplite_v2_shadow_factory.gd")
const Fragment = preload("res://scripts/enemy_v2/hoplite_v2_fragment.gd")
const Migration = preload("res://scripts/enemy/enemy_runtime_migration.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var package := Package.load_default() as HopliteV2Package
	_expect(package == Package.load_default(), "default package must be cached once for every HopliteV2")
	for error: String in package.validate(false):
		failures.append(error)
	_expect(not package.validate(true).is_empty(), "production gate must remain closed")
	_validate_shared_definition()
	_validate_body_and_donor(package)
	_validate_fragments(package)
	_validate_shadow_actors()
	_validate_v1_safety_gate()
	if failures.is_empty():
		print("HOPLITE_V2_FOUNDATION_PROBE PASS: body=23 bones lods=3 clips=14 fragments=9 production=legacy_v1")
		quit(0)
		return
	for failure: String in failures:
		push_error("[HOPLITE V2 FOUNDATION] " + failure)
	quit(1)


func _validate_shared_definition() -> void:
	var standard := Catalog.definition(&"ngeneral") as HopliteEnemyV2Definition
	var veteran := Catalog.definition(&"ngeneral_veteran") as HopliteEnemyV2Definition
	_expect(standard != null and veteran != null, "standard or veteran definition is missing")
	if standard == null or veteran == null:
		return
	_expect(standard.body_scene_path == veteran.body_scene_path, "standard and veteran must share one skin")
	_expect(standard.animation_library_path == veteran.animation_library_path, "standard and veteran must share one donor")
	_expect(standard.semantic_animations == veteran.semantic_animations, "standard and veteran animation contracts diverged")
	_expect(standard.archetype_id != veteran.archetype_id, "gameplay identities must remain distinct")
	_expect(not is_equal_approx(standard.max_health, veteran.max_health), "veteran gameplay stats were flattened")


func _validate_body_and_donor(package: HopliteV2Package) -> void:
	var body_contract: Dictionary = package.contract.get("body", {})
	var packed := load(String(body_contract.get("path", ""))) as PackedScene
	_expect(packed != null, "body PackedScene cannot be loaded")
	if packed == null:
		return
	var root := packed.instantiate()
	var skeleton := _find_skeleton(root)
	_expect(skeleton != null, "body has no Skeleton3D")
	if skeleton != null:
		_expect(skeleton.get_bone_count() == 23, "body skeleton is not 23 bones")
		for bone_index: int in range(skeleton.get_bone_count()):
			_expect(not _is_finger(skeleton.get_bone_name(bone_index)), "finger bone remains in body")
	var animations: Dictionary = package.contract.get("animations", {})
	var library := load(String(animations.get("library", ""))) as AnimationLibrary
	_expect(library != null, "shared animation donor cannot be loaded")
	if library != null and skeleton != null:
		_expect(library.get_animation_list().size() == 14, "shared donor must contain exactly 14 published clips")
		_expect(library.has_animation(&"spear_bayonet_step"), "shared donor is missing the two-handed bayonet step")
		var allowed: Dictionary = {}
		for bone_index: int in range(skeleton.get_bone_count()):
			allowed[skeleton.get_bone_name(bone_index)] = true
		for clip_name: StringName in library.get_animation_list():
			var animation := library.get_animation(clip_name)
			for track_index: int in range(animation.get_track_count()):
				var path := animation.track_get_path(track_index)
				var bone := StringName(path.get_subname(path.get_subname_count() - 1))
				_expect(allowed.has(bone), "%s targets unknown bone %s" % [clip_name, bone])
				_expect(not _is_finger(bone), "%s still contains a finger track" % clip_name)
		for partial_clip: StringName in [&"spear_thrust", &"spear_thrust_low", &"block_idle", &"block_impact"]:
			var animation := library.get_animation(partial_clip)
			for leg_bone: StringName in [&"DEF-thigh.L", &"DEF-shin.L", &"DEF-foot.L", &"DEF-thigh.R", &"DEF-shin.R", &"DEF-foot.R"]:
				_expect(animation.find_track(NodePath(".:%s" % leg_bone), Animation.TYPE_ROTATION_3D) >= 0,
					"%s leaves %s stuck in the preceding locomotion pose" % [partial_clip, leg_bone])
		var bayonet := library.get_animation(&"spear_bayonet_step")
		_expect(_moving_rotation_track_count(bayonet) >= 8, "bayonet bake is static or lost its full-body motion")
	root.free()


func _validate_fragments(package: HopliteV2Package) -> void:
	var fragment_contract: Dictionary = package.contract.get("fragments", {})
	var required: Array = fragment_contract.get("required", [])
	_expect(required.size() == 9, "package must expose nine severable fragments")
	for raw_zone: Variant in required:
		var zone := StringName(raw_zone)
		var definition := package.fragment_definition(zone)
		var packed := load(String(definition.get("runtime_path", ""))) as PackedScene
		_expect(packed != null, "fragment cannot load: %s" % zone)
		if packed == null:
			continue
		var root := packed.instantiate()
		var skeleton := _find_skeleton(root)
		var expected_bones := (definition.get("skeleton", []) as Array).size()
		_expect((0 if skeleton == null else skeleton.get_bone_count()) == expected_bones,
			"fragment %s skeleton contract changed" % zone)
		root.free()
		var rigid := Fragment.new() as HopliteV2Fragment
		_expect(rigid.configure(definition), "fragment rigid-body configuration failed: %s" % zone)
		_expect(rigid.get_child_count() == 2, "fragment %s must contain only visual + primitive collision" % zone)
		rigid.free()


func _validate_shadow_actors() -> void:
	var shared_body_mesh: Mesh
	var shared_animation_library: AnimationLibrary
	for archetype: StringName in [&"ngeneral", &"ngeneral_veteran"]:
		var actor := ShadowFactory.create(archetype) as HopliteEnemyActorV2
		_expect(actor != null, "shadow actor could not be created: %s" % archetype)
		if actor == null:
			continue
		get_root().add_child(actor)
		_expect(StringName(actor.get_meta("enemy_runtime_generation", &"")) == &"modular_v2_shadow",
			"shadow actor metadata is missing")
		_expect(actor.presentation != null and actor.presentation.lod_meshes.size() == 3,
			"shadow actor must expose the three-level body LOD chain")
		_expect(actor.equipment != null and actor.equipment.weapon_attachment != null and actor.equipment.shield_attachment != null,
			"shadow actor must expose spear and shield presentation")
		_expect(actor.performance_lod != null, "shadow actor must expose runtime LOD control")
		if actor.presentation != null:
			_expect(_count_skeletons(actor.presentation) == 1,
				"LOD chain must reuse exactly one animated skeleton")
			var body_mesh := actor.presentation.lod_meshes[0].mesh
			if shared_body_mesh == null:
				shared_body_mesh = body_mesh
			else:
				_expect(shared_body_mesh == body_mesh, "standard and veteran instantiated duplicate body Mesh resources")
			for mesh: MeshInstance3D in actor.presentation.lod_meshes:
				_expect(mesh.get_parent() == actor.presentation.skeleton,
					"every LOD mesh must be bound under the shared skeleton")
		var animation_library := actor.animation.player.get_animation_library(HopliteV2AnimationComponent.LIBRARY_NAME)
		if shared_animation_library == null:
			shared_animation_library = animation_library
		else:
			_expect(shared_animation_library == animation_library, "standard and veteran instantiated duplicate animation libraries")
		for semantic: StringName in actor.definition.semantic_animations:
			_expect(actor.play_semantic_animation(semantic), "%s cannot play %s" % [archetype, semantic])
		actor.free()


func _validate_v1_safety_gate() -> void:
	for archetype: StringName in [&"ngeneral", &"ngeneral_veteran"]:
		_expect(Migration.stage_for(archetype) == Migration.MigrationStage.CONTRACT_READY,
			"Hoplite must be contract-ready")
		_expect(Migration.resolved_generation_for(archetype) == Migration.RuntimeGeneration.LEGACY_V1,
			"production route switched away from V1")


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _is_finger(bone_name: StringName) -> bool:
	var value := String(bone_name)
	return value.begins_with("DEF-f_") or value.begins_with("DEF-thumb.")


func _count_skeletons(node: Node) -> int:
	var result := 1 if node is Skeleton3D else 0
	for child: Node in node.get_children():
		result += _count_skeletons(child)
	return result


func _moving_rotation_track_count(animation: Animation) -> int:
	if animation == null:
		return 0
	var moving := 0
	for track_index: int in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_ROTATION_3D or animation.track_get_key_count(track_index) < 2:
			continue
		var first := animation.track_get_key_value(track_index, 0) as Quaternion
		var maximum_angle := 0.0
		for key_index: int in range(1, animation.track_get_key_count(track_index)):
			var sample := animation.track_get_key_value(track_index, key_index) as Quaternion
			maximum_angle = maxf(maximum_angle, first.angle_to(sample))
		if maximum_angle > 0.03:
			moving += 1
	return moving


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
