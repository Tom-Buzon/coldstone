extends CharacterBody3D
class_name HopliteAthenianEnemy

const UAL1_PATH := "res://assets/runtime/ual1/UAL1_Standard.glb"
const DriverScript = preload("res://scripts/animation/native_animation_driver.gd")
const AnatomyScript = preload("res://scripts/enemy/anatomy_hitbox.gd")
const AnatomyProfileScript = preload("res://scripts/enemy/anatomy_profile.gd")
const DetachedLimbScript = preload("res://scripts/gore/detached_limb_proxy.gd")
const BloodBurstScript = preload("res://scripts/gore/blood_burst.gd")

signal died(enemy: Node)
signal zone_severed(enemy: Node, zone: StringName)
signal localized_hit(enemy: Node, zone: StringName, damage: float, sever_damage: float)

var max_health: float = 180.0
var health: float = 180.0
var dead: bool = false
var last_hit_zone: StringName = StringName()
var last_hit_damage: float = 0.0
var last_hit_sever: float = 0.0

var visual_root: Node3D
var mannequin_scene: Node
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var anatomy: HopliteAnatomyHitbox
var anatomy_defs: Dictionary = {}
var zone_state: Dictionary = {}
var hidden_bones: Dictionary = {}

var right_hand_bone: String = ""
var left_hand_bone: String = ""
var sword_attachment: BoneAttachment3D
var shield_attachment: BoneAttachment3D
var sword_root: Node3D
var shield_root: Node3D
var sword_dropped: bool = false
var shield_dropped: bool = false

var body_material: StandardMaterial3D
var base_color: Color = Color(0.025, 0.18, 0.72)
var flash_tween: Tween
var status_label: Label3D
var combat_debug_visible: bool = false
var body_collider: CollisionShape3D
var death_collapse_tween: Tween
var corpse_fallback_rest_height: float = 0.40
var miniboss_scale_factor: float = 1.20

# V0.0.5 AI. Static anatomy-test mannequins leave ai_enabled=false, so only the
# dedicated AI group pays for UAL2 donor/retargeting and steering.
var ai_enabled: bool = false
var is_miniboss: bool = false
var ai_player: Node3D
var ai_miniboss: Node3D
var ai_guard_index: int = 0
var ai_home_position: Vector3 = Vector3.ZERO
var ai_state: StringName = &"idle"
var ai_move_speed: float = 4.8
var ai_limp_speed: float = 1.85
var ai_crawl_speed: float = 0.72
var injury_state: StringName = &"healthy"
var ai_acceleration: float = 18.0
var ai_turn_response: float = 12.0
var ai_aggro_distance: float = 20.0
var ai_defend_radius: float = 8.0
var ai_boss_threat_radius: float = 7.0
var ai_guard_radius: float = 2.65
var ai_attack_range: float = 1.72
var ai_attack_damage: float = 14.0
var ai_attack_cooldown_timer: float = 0.0
var ai_attack_pending: bool = false
var ai_attack_windup_timer: float = 0.0
var ai_attack_recovery_timer: float = 0.0
var ai_alert_timer: float = 0.0
var ai_animation_driver = null

func _ready() -> void:
    # Uniformly scale the whole miniboss CharacterBody so the visible mesh,
    # Skeleton3D, anatomy Areas and physical collider all stay in sync.
    # Avoid non-uniform scaling on CharacterBody collision shapes.
    if is_miniboss:
        scale = Vector3.ONE * miniboss_scale_factor

    collision_layer = 4
    collision_mask = (1 | 2 | 4) if ai_enabled else 1
    process_priority = 100
    if is_miniboss:
        max_health = maxf(max_health, 460.0)
        ai_move_speed = maxf(ai_move_speed, 5.25)
        ai_attack_damage = maxf(ai_attack_damage, 34.0)
        # Distance checks are world-space values, so they do not automatically
        # grow with Node3D.scale even though the sword/collider do.
        ai_attack_range = maxf(ai_attack_range, 1.90) * miniboss_scale_factor
        ai_aggro_distance = maxf(ai_aggro_distance, 23.0)
    health = max_health
    ai_home_position = global_position
    ai_attack_cooldown_timer = randf_range(0.15, 0.55) if ai_enabled else 0.0
    _build_body_collider()
    _load_mannequin()
    add_to_group("enemy")
    add_to_group("damageable")
    if ai_enabled:
        add_to_group("enemy_ai")
    if is_miniboss:
        add_to_group("enemy_miniboss")

func _process(delta: float) -> void:
    _update_injury_visual(delta)
    if ai_animation_driver != null and ai_enabled and not dead:
        ai_animation_driver.tick(delta)
    if skeleton != null and not hidden_bones.is_empty():
        # Prototype visual severing for the single-piece UAL1 mesh. A future gore
        # mesh can replace this without touching AnatomyHitbox / HitEvent.
        for raw_index: Variant in hidden_bones.keys():
            var bone_index: int = int(raw_index)
            if bone_index >= 0 and bone_index < skeleton.get_bone_count():
                skeleton.set_bone_pose_scale(bone_index, Vector3(0.001, 0.001, 0.001))
    _update_status_label()

func _physics_process(delta: float) -> void:
    if not ai_enabled or dead:
        return

    ai_attack_cooldown_timer = maxf(0.0, ai_attack_cooldown_timer - delta)
    ai_attack_recovery_timer = maxf(0.0, ai_attack_recovery_timer - delta)
    ai_alert_timer = maxf(0.0, ai_alert_timer - delta)

    if ai_attack_pending and not _can_ai_attack():
        ai_attack_pending = false
        ai_attack_windup_timer = 0.0
        ai_attack_recovery_timer = 0.15

    if not is_on_floor():
        velocity.y -= 24.0 * delta
    elif velocity.y < 0.0:
        velocity.y = 0.0

    if ai_attack_recovery_timer > 0.0 and not ai_attack_pending:
        velocity.x = move_toward(velocity.x, 0.0, ai_acceleration * 1.8 * delta)
        velocity.z = move_toward(velocity.z, 0.0, ai_acceleration * 1.8 * delta)
        if ai_player != null and is_instance_valid(ai_player):
            _ai_face_direction(ai_player.global_position - global_position, delta)
        move_and_slide()
        _ai_update_animation_speed()
        return

    if ai_attack_pending:
        velocity.x = move_toward(velocity.x, 0.0, ai_acceleration * 1.8 * delta)
        velocity.z = move_toward(velocity.z, 0.0, ai_acceleration * 1.8 * delta)
        if ai_player != null and is_instance_valid(ai_player):
            _ai_face_direction(ai_player.global_position - global_position, delta)
        ai_attack_windup_timer -= delta
        if ai_attack_windup_timer <= 0.0:
            _resolve_ai_attack()
        move_and_slide()
        _ai_update_animation_speed()
        return

    var goal: Dictionary = _ai_goal()
    var active: bool = bool(goal.get("active", false))
    var attack_player: bool = bool(goal.get("attack_player", false))
    var target: Vector3 = goal.get("target", global_position)

    if attack_player and ai_player != null and is_instance_valid(ai_player):
        var player_flat: Vector3 = ai_player.global_position - global_position
        player_flat.y = 0.0
        if player_flat.length() <= ai_attack_range and ai_attack_cooldown_timer <= 0.0 and _can_ai_attack():
            _begin_ai_attack()
            move_and_slide()
            _ai_update_animation_speed()
            return

    var flat_to_goal: Vector3 = target - global_position
    flat_to_goal.y = 0.0
    var desired_velocity: Vector3 = Vector3.ZERO

    if active and flat_to_goal.length() > 0.28:
        var direction: Vector3 = flat_to_goal.normalized()
        var separation: Vector3 = _ai_separation_vector()
        if separation.length() > 0.001:
            direction = (direction + separation * 0.85).normalized()
        desired_velocity = direction * _current_ai_move_speed()
        _ai_face_direction(direction, delta)
    elif attack_player and ai_player != null and is_instance_valid(ai_player):
        _ai_face_direction(ai_player.global_position - global_position, delta)

    velocity.x = move_toward(velocity.x, desired_velocity.x, ai_acceleration * delta)
    velocity.z = move_toward(velocity.z, desired_velocity.z, ai_acceleration * delta)
    move_and_slide()
    _ai_update_animation_speed()

func _ai_goal() -> Dictionary:
    if ai_player == null or not is_instance_valid(ai_player):
        ai_state = &"idle"
        return {"active": false, "target": global_position, "attack_player": false}

    var to_player: Vector3 = ai_player.global_position - global_position
    to_player.y = 0.0
    var player_distance: float = to_player.length()

    if is_miniboss:
        if player_distance <= ai_aggro_distance or ai_alert_timer > 0.0:
            ai_state = &"boss_attack"
            return {"active": true, "target": ai_player.global_position, "attack_player": true}
        ai_state = &"boss_idle"
        return {"active": true, "target": ai_home_position, "attack_player": false}

    var boss_alive: bool = ai_miniboss != null and is_instance_valid(ai_miniboss)
    if boss_alive and ai_miniboss.has_method("is_dead_for_combat"):
        boss_alive = not bool(ai_miniboss.call("is_dead_for_combat"))

    if boss_alive:
        var to_boss: Vector3 = ai_miniboss.global_position - global_position
        to_boss.y = 0.0
        if to_boss.length() <= ai_defend_radius:
            var boss_to_player: Vector3 = ai_player.global_position - ai_miniboss.global_position
            boss_to_player.y = 0.0
            var boss_player_distance: float = boss_to_player.length()
            if boss_player_distance <= ai_boss_threat_radius or ai_alert_timer > 0.0:
                var toward_player: Vector3 = boss_to_player.normalized() if boss_player_distance > 0.01 else -global_basis.z
                var lateral: Vector3 = Vector3(-toward_player.z, 0.0, toward_player.x)
                var lateral_slot: float = (float(ai_guard_index) - 2.0) * 0.42
                var intercept: Vector3 = ai_miniboss.global_position + toward_player * 2.15 + lateral * lateral_slot
                ai_state = &"defend_boss"
                return {"active": true, "target": intercept, "attack_player": true}

            var angle: float = (TAU / 5.0) * float(ai_guard_index)
            var guard_offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * ai_guard_radius
            ai_state = &"guard"
            return {"active": true, "target": ai_miniboss.global_position + guard_offset, "attack_player": false}

    if player_distance <= ai_aggro_distance or ai_alert_timer > 0.0:
        ai_state = &"attack"
        return {"active": true, "target": ai_player.global_position, "attack_player": true}

    ai_state = &"idle"
    return {"active": true, "target": ai_home_position, "attack_player": false}

func _ai_separation_vector() -> Vector3:
    var push: Vector3 = Vector3.ZERO
    if get_tree() == null:
        return push
    for other: Node in get_tree().get_nodes_in_group("enemy_ai"):
        if other == self or not (other is Node3D):
            continue
        var delta_pos: Vector3 = global_position - (other as Node3D).global_position
        delta_pos.y = 0.0
        var distance: float = delta_pos.length()
        if distance > 0.001 and distance < 1.35:
            push += delta_pos.normalized() * ((1.35 - distance) / 1.35)
    return push

func _begin_ai_attack() -> void:
    if ai_attack_pending or ai_player == null or not is_instance_valid(ai_player) or not _can_ai_attack():
        return
    ai_attack_pending = true
    velocity.x = 0.0
    velocity.z = 0.0

    var slot: StringName = &"heavy" if is_miniboss else (&"light1" if randi() % 2 == 0 else &"light2")
    ai_attack_windup_timer = 0.43 if is_miniboss else 0.27
    ai_attack_cooldown_timer = 1.55 if is_miniboss else randf_range(1.00, 1.28)
    ai_state = &"attack_windup"

    if ai_animation_driver != null:
        var attack_speed: float = 0.96 if is_miniboss else 1.08
        ai_animation_driver.play_attack_variant(slot, &"idle", false, attack_speed)

func _resolve_ai_attack() -> void:
    if not ai_attack_pending:
        return
    if not _can_ai_attack():
        ai_attack_pending = false
        ai_state = &"disarmed"
        return
    ai_attack_pending = false
    ai_attack_recovery_timer = 0.42 if is_miniboss else 0.28
    ai_state = &"attack_recover"
    if ai_player == null or not is_instance_valid(ai_player):
        return

    var to_player: Vector3 = ai_player.global_position - global_position
    to_player.y = 0.0
    if to_player.length() > ai_attack_range + 0.48:
        return

    var forward: Vector3 = -global_basis.z
    forward.y = 0.0
    forward = forward.normalized()
    var hit_dir: Vector3 = to_player.normalized() if to_player.length() > 0.01 else forward
    if forward.dot(hit_dir) < 0.10:
        return

    var damage: float = ai_attack_damage
    if ai_player.has_method("receive_enemy_hit"):
        ai_player.call("receive_enemy_hit", damage, self, hit_dir)

func _ai_update_animation_speed() -> void:
    if ai_animation_driver == null:
        return
    var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
    var leg_count: int = _lost_leg_count()
    if leg_count >= 2:
        # No dedicated crawl clip exists in UAL1, so keep modest upper-body motion
        # while the visual root is lowered/leaned by _update_injury_visual().
        ai_animation_driver.set_locomotion(0.24 if horizontal_speed > 0.08 else 0.0)
    else:
        ai_animation_driver.set_locomotion(clampf(horizontal_speed / 7.2, 0.0, 1.0))

func _ai_face_direction(direction: Vector3, delta: float) -> void:
    var flat: Vector3 = direction
    flat.y = 0.0
    if flat.length() < 0.001:
        return
    flat = flat.normalized()
    var target_yaw: float = atan2(-flat.x, -flat.z)
    var amount: float = clampf(1.0 - exp(-ai_turn_response * delta), 0.0, 1.0)
    rotation.y = lerp_angle(rotation.y, target_yaw, amount)

func alert_ai(duration: float = 8.0) -> void:
    ai_alert_timer = maxf(ai_alert_timer, duration)

func _build_body_collider() -> void:
    body_collider = CollisionShape3D.new()
    body_collider.name = "BodyCollider"
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.39
    capsule.height = 1.82
    body_collider.shape = capsule
    body_collider.position = Vector3(0.0, 0.91, 0.0)
    add_child(body_collider)

func _load_mannequin() -> void:
    visual_root = Node3D.new()
    visual_root.name = "AthenianMinibossVisual" if is_miniboss else "AthenianBlueVisual"
    add_child(visual_root)
    visual_root.rotation.y = PI

    var packed: PackedScene = load(UAL1_PATH) as PackedScene
    if packed == null:
        _make_missing_marker()
        return

    mannequin_scene = packed.instantiate()
    visual_root.add_child(mannequin_scene)
    _disable_animation_trees(mannequin_scene)
    skeleton = _find_skeleton(mannequin_scene)
    animation_player = _find_best_animation_player(mannequin_scene)
    if skeleton == null or animation_player == null:
        _make_missing_marker()
        return

    _tint_body()
    right_hand_bone = _find_hand_bone(true)
    left_hand_bone = _find_hand_bone(false)
    _build_equipment()
    if ai_enabled:
        _setup_ai_animation_driver()
    else:
        _play_idle()

    anatomy_defs = AnatomyProfileScript.default_humanoid()
    for raw_zone: Variant in anatomy_defs.keys():
        zone_state[StringName(raw_zone)] = {
            "sever": 0.0,
            "damage": 0.0,
            "severed": false
        }

    anatomy = AnatomyScript.new() as HopliteAnatomyHitbox
    anatomy.name = "AnatomyHitbox"
    add_child(anatomy)
    anatomy.configure(self, skeleton, anatomy_defs)
    anatomy.set_debug_visible(combat_debug_visible)

    status_label = Label3D.new()
    status_label.name = "DamageDebug"
    status_label.position = Vector3(0.0, 2.32, 0.0)
    status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    status_label.font_size = 32
    status_label.modulate = Color(1.0, 0.86, 0.20) if is_miniboss else Color(0.75, 0.86, 1.0)
    add_child(status_label)

    if not anatomy.debug_missing_bones.is_empty():
        print("[ATHENIAN] Missing anatomy bones: ", anatomy.debug_missing_bones)
    print("[ATHENIAN ANATOMY MAP] ", anatomy.debug_mapping_summary())

func receive_anatomy_hit(hit: Variant, zone: StringName) -> void:
    if dead or not anatomy_defs.has(zone) or not zone_state.has(zone):
        return

    var definition: Dictionary = anatomy_defs[zone]
    var state: Dictionary = zone_state[zone]
    if bool(state.get("severed", false)):
        return

    var damage_mult: float = float(definition.get("damage_mult", 1.0))
    var sever_mult: float = float(definition.get("sever_mult", 1.0))
    var raw_damage: float = float(hit.damage)
    var raw_sever: float = float(hit.sever_damage)
    var zone_damage: float = raw_damage * damage_mult
    var zone_sever: float = raw_sever * sever_mult

    health = maxf(0.0, health - zone_damage)
    state["damage"] = float(state.get("damage", 0.0)) + zone_damage
    state["sever"] = float(state.get("sever", 0.0)) + zone_sever
    zone_state[zone] = state

    last_hit_zone = zone
    last_hit_damage = zone_damage
    last_hit_sever = float(state["sever"])
    localized_hit.emit(self, zone, zone_damage, zone_sever)
    if ai_enabled:
        alert_ai(8.0)
        if ai_miniboss != null and is_instance_valid(ai_miniboss) and ai_miniboss.has_method("alert_ai"):
            ai_miniboss.call("alert_ai", 8.0)

    var hit_position: Vector3 = hit.position
    var hit_direction: Vector3 = hit.direction
    var blood_intensity: float = clampf(1.00 + zone_damage / 42.0 + zone_sever / 72.0, 1.05, 2.85)
    _spawn_blood_hit(hit_position, hit_direction, blood_intensity, false)
    _flash_hit()

    var severable: bool = bool(definition.get("severable", false))
    var threshold: float = float(definition.get("sever_threshold", 9999.0))
    if severable and float(state["sever"]) >= threshold:
        _sever(zone, hit)
        return

    if health <= 0.0:
        _die(false)

func _sever(hit_zone: StringName, hit: Variant) -> void:
    var hit_definition: Dictionary = anatomy_defs[hit_zone]
    var sever_target: StringName = StringName(hit_definition.get("sever_target", hit_zone))
    if not zone_state.has(sever_target):
        sever_target = hit_zone
    var target_state: Dictionary = zone_state[sever_target]
    if bool(target_state.get("severed", false)):
        return
    target_state["severed"] = true
    zone_state[sever_target] = target_state

    _disable_related_hitboxes(sever_target)
    _hide_zone_bone_chain(sever_target)

    var proxy_zone: StringName = StringName(hit_definition.get("proxy_zone", StringName()))
    if proxy_zone == StringName():
        proxy_zone = sever_target
    # A sever gets a second, much stronger directional burst at the cut point.
    _spawn_blood_hit(hit.position, hit.direction, clampf(2.10 + float(hit.sever_damage) / 70.0, 2.25, 3.20), true)
    _spawn_detached_proxy(proxy_zone, hit)
    _handle_equipment_loss(sever_target)
    _refresh_injury_state()
    zone_severed.emit(self, sever_target)

    var fatal: bool = bool(hit_definition.get("fatal_sever", false)) or sever_target == &"head"
    if fatal:
        _die(true)

func _disable_related_hitboxes(zone: StringName) -> void:
    if anatomy == null:
        return
    anatomy.disable_zone(zone)
    match zone:
        &"head":
            anatomy.disable_zone(&"neck")
        &"upper_arm_l":
            anatomy.disable_zone(&"forearm_l")
        &"upper_arm_r":
            anatomy.disable_zone(&"forearm_r")
        &"thigh_l":
            anatomy.disable_zone(&"shin_l")
        &"thigh_r":
            anatomy.disable_zone(&"shin_r")

func _hide_zone_bone_chain(zone: StringName) -> void:
    if skeleton == null or anatomy == null:
        return
    var root_bone: int = anatomy.get_zone_primary_bone(zone)
    if root_bone < 0:
        return
    for bone_index: int in range(skeleton.get_bone_count()):
        if _bone_is_descendant_of(bone_index, root_bone):
            hidden_bones[bone_index] = true

func _bone_is_descendant_of(bone_index: int, root_bone: int) -> bool:
    var current: int = bone_index
    while current >= 0:
        if current == root_bone:
            return true
        current = skeleton.get_bone_parent(current)
    return false

func _spawn_detached_proxy(zone: StringName, hit: Variant) -> void:
    if anatomy == null or get_tree().current_scene == null:
        return
    var transform: Transform3D = anatomy.get_zone_world_transform(zone)
    var radius: float = anatomy.get_zone_radius(zone)
    var length: float = anatomy.get_zone_length(zone)
    var direction: Vector3 = hit.direction
    var sever_damage: float = hit.sever_damage
    var impulse: Vector3 = direction.normalized() * clampf(2.2 + sever_damage * 0.055, 2.5, 9.0)

    var proxy = DetachedLimbScript.new()
    get_tree().current_scene.add_child(proxy)
    proxy.setup(zone, transform, radius, length, base_color, impulse)

func _handle_equipment_loss(zone: StringName) -> void:
    if zone == &"upper_arm_r" or zone == &"forearm_r":
        _drop_sword()
    elif zone == &"upper_arm_l" or zone == &"forearm_l":
        _drop_shield()

func _die(_from_sever: bool) -> void:
    if dead:
        return
    dead = true
    health = 0.0
    velocity = Vector3.ZERO
    ai_attack_pending = false
    ai_attack_windup_timer = 0.0
    ai_state = &"dead"
    collision_layer = 0
    collision_mask = 0
    if body_collider != null:
        body_collider.set_deferred("disabled", true)

    # The old V0.0.5-V0.0.7 corpse workaround rotated visual_root by ~90 degrees.
    # That avoided an upright corpse, but because the standing skeleton pose and
    # the root rotation were fighting each other it produced floating/twisted
    # bodies. The real problem was the AI AnimationTree continuing to own the
    # target skeleton after death. Shut the runtime driver/tree down completely,
    # then let the authored UAL1 Death01 animation own the corpse.
    _shutdown_ai_animation_for_death()

    if visual_root != null:
        # Crawl/limp presentation modifies the visual root while alive. Restore the
        # neutral character root before playing the authored death clip. Preserve Y
        # because UAL1 is intentionally flipped to face the correct direction.
        visual_root.position = Vector3.ZERO
        visual_root.rotation = Vector3(0.0, visual_root.rotation.y, 0.0)

    var played_authored_death: bool = false
    if animation_player != null and animation_player.has_animation("Death01"):
        var death_anim: Animation = animation_player.get_animation("Death01")
        if death_anim != null:
            death_anim.loop_mode = Animation.LOOP_NONE
        animation_player.stop()
        animation_player.play("Death01", 0.035, 1.0)
        animation_player.advance(0.0)
        played_authored_death = true

    # UAL1 normally provides Death01. Keep a small deterministic fallback only for
    # replacement characters that do not ship a death animation.
    if not played_authored_death:
        _collapse_dead_body_fallback()

    died.emit(self)

func _shutdown_ai_animation_for_death() -> void:
    if ai_animation_driver == null:
        # Static anatomy targets can still contain imported AnimationTrees.
        if mannequin_scene != null:
            _disable_animation_trees(mannequin_scene)
        return

    ai_animation_driver.stop_movement_action()
    ai_animation_driver.stop_full_body()
    ai_animation_driver.set_locomotion(0.0)

    # AnimationTree is a child of HopliteNativeAnimationDriver and otherwise keeps
    # evaluating independently even though enemy._process() stops calling tick().
    var tree_value: Variant = ai_animation_driver.get("animation_tree")
    if tree_value is AnimationTree:
        (tree_value as AnimationTree).active = false

    # Zero the two retarget modifiers immediately so Death01 is not mixed with a
    # stale UAL2 run/attack pose during the frame the driver is removed.
    for property_name: String in ["movement_pose_bridge", "pose_bridge"]:
        var bridge_value: Variant = ai_animation_driver.get(property_name)
        if bridge_value is Node and (bridge_value as Node).has_method("set_attack_weight"):
            (bridge_value as Node).call("set_attack_weight", 0.0, false, 0.0)

    ai_animation_driver.queue_free()
    ai_animation_driver = null

    if mannequin_scene != null:
        _disable_animation_trees(mannequin_scene)

func _collapse_dead_body_fallback() -> void:
    if visual_root == null:
        return
    if death_collapse_tween != null and death_collapse_tween.is_valid():
        death_collapse_tween.kill()

    # Fallback only: rotate a neutral standing mannequin sideways. The authored
    # Death01 path above is used for our current UAL1 Athenians.
    var side: float = -1.0 if (get_instance_id() % 2) == 0 else 1.0
    var target_rotation: Vector3 = visual_root.rotation
    target_rotation.z += deg_to_rad(88.0 * side)
    target_rotation.x += deg_to_rad(-6.0)
    var target_position: Vector3 = visual_root.position
    target_position.y = corpse_fallback_rest_height

    death_collapse_tween = create_tween()
    death_collapse_tween.set_trans(Tween.TRANS_QUAD)
    death_collapse_tween.set_ease(Tween.EASE_IN)
    death_collapse_tween.set_parallel(true)
    death_collapse_tween.tween_property(visual_root, "rotation", target_rotation, 0.32)
    death_collapse_tween.tween_property(visual_root, "position", target_position, 0.32)


func _spawn_blood_hit(world_position: Vector3, direction: Vector3, intensity: float = 1.0, sever: bool = false) -> void:
    var scene: Node = get_tree().current_scene
    if scene == null:
        return
    var burst = BloodBurstScript.new()
    scene.add_child(burst)
    burst.setup(world_position, direction, intensity, sever)

func _flash_hit() -> void:
    if body_material == null:
        return
    if flash_tween != null and flash_tween.is_valid():
        flash_tween.kill()
    body_material.albedo_color = Color(0.45, 0.06, 0.08)
    flash_tween = create_tween()
    flash_tween.tween_property(body_material, "albedo_color", base_color, 0.14)

func _update_status_label() -> void:
    if status_label == null:
        return
    if dead:
        status_label.text = ("MINIBOSS" if is_miniboss else "ATHENIAN") + " — DEAD"
        status_label.modulate = Color(0.65, 0.18, 0.18)
        return
    var zone_text: String = String(last_hit_zone) if last_hit_zone != StringName() else "none"
    var title: String = "MINIBOSS" if is_miniboss else "ATHENIAN"
    var ai_text: String = "  AI=" + String(ai_state) if ai_enabled else ""
    var injury_text: String = "  BODY=" + String(injury_state)
    status_label.text = "%s  HP %.0f/%.0f%s%s\nlast=%s dmg=%.0f sever=%.0f" % [title, health, max_health, ai_text, injury_text, zone_text, last_hit_damage, last_hit_sever]

func set_combat_debug_visible(enabled: bool) -> void:
    combat_debug_visible = enabled
    if anatomy != null:
        anatomy.set_debug_visible(enabled)

func get_combat_aim_point() -> Vector3:
    if anatomy != null:
        return anatomy.get_zone_world_center(&"torso")
    return global_position + Vector3.UP * 1.10

func is_dead_for_combat() -> bool:
    return dead

func _zone_is_severed(zone: StringName) -> bool:
    if not zone_state.has(zone):
        return false
    var state: Dictionary = zone_state[zone]
    return bool(state.get("severed", false))

func _left_leg_lost() -> bool:
    return _zone_is_severed(&"thigh_l") or _zone_is_severed(&"shin_l")

func _right_leg_lost() -> bool:
    return _zone_is_severed(&"thigh_r") or _zone_is_severed(&"shin_r")

func _lost_leg_count() -> int:
    return (1 if _left_leg_lost() else 0) + (1 if _right_leg_lost() else 0)

func _right_arm_lost() -> bool:
    return _zone_is_severed(&"upper_arm_r") or _zone_is_severed(&"forearm_r")

func _can_ai_attack() -> bool:
    return not dead and not sword_dropped and not _right_arm_lost()

func _current_ai_move_speed() -> float:
    var lost: int = _lost_leg_count()
    if lost >= 2:
        return ai_crawl_speed
    if lost == 1:
        return minf(ai_move_speed, ai_limp_speed)
    return ai_move_speed

func _refresh_injury_state() -> void:
    var lost_legs: int = _lost_leg_count()
    if lost_legs >= 2:
        injury_state = &"crawl"
    elif lost_legs == 1:
        injury_state = &"limp"
    elif _right_arm_lost():
        injury_state = &"disarmed"
    else:
        injury_state = &"healthy"

    if not _can_ai_attack():
        ai_attack_pending = false
        ai_attack_windup_timer = 0.0
        ai_attack_recovery_timer = 0.0

func _update_injury_visual(delta: float) -> void:
    if visual_root == null or dead:
        return
    var lost_legs: int = _lost_leg_count()
    var target_y: float = -0.54 if lost_legs >= 2 else 0.0
    var target_x: float = deg_to_rad(-18.0) if lost_legs >= 2 else 0.0
    visual_root.position.y = move_toward(visual_root.position.y, target_y, 3.8 * delta)
    visual_root.rotation.x = lerp_angle(visual_root.rotation.x, target_x, clampf(1.0 - exp(-8.0 * delta), 0.0, 1.0))

func _play_idle() -> void:
    if animation_player == null:
        return
    var clip: StringName = &"Sword_Idle" if animation_player.has_animation("Sword_Idle") else &"Idle"
    if not animation_player.has_animation(clip):
        return
    var anim: Animation = animation_player.get_animation(clip)
    if anim != null:
        anim.loop_mode = Animation.LOOP_LINEAR
    animation_player.play(clip)

func _setup_ai_animation_driver() -> void:
    if mannequin_scene == null or skeleton == null or animation_player == null:
        return
    ai_animation_driver = DriverScript.new()
    ai_animation_driver.name = "AthenianAIDriver"
    add_child(ai_animation_driver)
    if not ai_animation_driver.configure(mannequin_scene, skeleton, animation_player):
        ai_animation_driver.queue_free()
        ai_animation_driver = null
        _play_idle()

func _tint_body() -> void:
    body_material = StandardMaterial3D.new()
    body_material.albedo_color = base_color
    body_material.roughness = 0.60
    body_material.metallic = 0.04
    _override_mesh_materials(mannequin_scene, body_material)

func _build_equipment() -> void:
    if skeleton == null:
        return
    if right_hand_bone != "":
        sword_attachment = BoneAttachment3D.new()
        sword_attachment.name = "EnemySwordAttachment"
        sword_attachment.bone_name = right_hand_bone
        skeleton.add_child(sword_attachment)
        sword_root = _make_sword()
        sword_attachment.add_child(sword_root)
    if left_hand_bone != "":
        shield_attachment = BoneAttachment3D.new()
        shield_attachment.name = "EnemyShieldAttachment"
        shield_attachment.bone_name = left_hand_bone
        skeleton.add_child(shield_attachment)
        shield_root = _make_shield()
        shield_attachment.add_child(shield_root)

func _drop_sword() -> void:
    if sword_dropped or sword_root == null or get_tree().current_scene == null:
        return
    sword_dropped = true
    var t: Transform3D = sword_root.global_transform
    sword_root.visible = false
    var body := RigidBody3D.new()
    body.name = "DroppedAthenianSword"
    body.global_transform = t
    body.collision_layer = 16
    body.collision_mask = 1
    get_tree().current_scene.add_child(body)
    body.global_transform = t
    var visual: Node3D = _make_sword()
    body.add_child(visual)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(0.10, 1.15, 0.08)
    collision.shape = shape
    collision.position.y = 0.42
    body.add_child(collision)
    body.apply_central_impulse(Vector3(randf_range(-1.2, 1.2), 2.5, randf_range(-1.2, 1.2)))

func _drop_shield() -> void:
    if shield_dropped or shield_root == null or get_tree().current_scene == null:
        return
    shield_dropped = true
    var t: Transform3D = shield_root.global_transform
    shield_root.visible = false
    var body := RigidBody3D.new()
    body.name = "DroppedAthenianShield"
    body.collision_layer = 16
    body.collision_mask = 1
    get_tree().current_scene.add_child(body)
    body.global_transform = t
    var visual: Node3D = _make_shield()
    body.add_child(visual)
    var collision := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.height = 0.10
    shape.radius = 0.48
    collision.shape = shape
    collision.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    body.add_child(collision)
    body.apply_central_impulse(Vector3(randf_range(-1.0, 1.0), 2.0, randf_range(-1.0, 1.0)))

func _make_sword() -> Node3D:
    var root := Node3D.new()
    var bronze := StandardMaterial3D.new()
    bronze.albedo_color = Color(0.33, 0.16, 0.05)
    bronze.metallic = 0.55
    bronze.roughness = 0.34
    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color(0.68, 0.72, 0.76)
    steel.metallic = 0.82
    steel.roughness = 0.22

    var blade := MeshInstance3D.new()
    var blade_mesh := BoxMesh.new()
    blade_mesh.size = Vector3(0.065, 0.92, 0.025)
    blade.mesh = blade_mesh
    blade.position.y = 0.55
    blade.material_override = steel
    root.add_child(blade)

    var guard := MeshInstance3D.new()
    var guard_mesh := BoxMesh.new()
    guard_mesh.size = Vector3(0.30, 0.055, 0.06)
    guard.mesh = guard_mesh
    guard.position.y = 0.07
    guard.material_override = bronze
    root.add_child(guard)
    return root

func _make_shield() -> Node3D:
    var root := Node3D.new()
    var shield := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.height = 0.09
    mesh.top_radius = 0.48
    mesh.bottom_radius = 0.48
    shield.mesh = mesh
    shield.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    var material := StandardMaterial3D.new()
    material.albedo_color = base_color.darkened(0.18)
    material.metallic = 0.44
    material.roughness = 0.38
    shield.material_override = material
    root.add_child(shield)
    return root

func _find_hand_bone(right: bool) -> String:
    if skeleton == null:
        return ""
    var desired_side: String = "r" if right else "l"
    var best_name: String = ""
    var best_score: int = -999
    for i: int in range(skeleton.get_bone_count()):
        var bone: String = skeleton.get_bone_name(i)
        var low: String = bone.to_lower()
        var compact: String = low.replace(" ", "").replace("_", "").replace("-", "").replace(".", "")
        var score: int = 0
        if "hand" in compact:
            score += 30
        if "wrist" in compact:
            score += 12
        if "finger" in compact or "thumb" in compact:
            score -= 30
        var side: String = _bone_side(bone)
        if side == desired_side:
            score += 45
        elif side != "":
            score -= 60
        if score > best_score:
            best_score = score
            best_name = bone
    return best_name if best_score >= 25 else ""

func _bone_side(raw: String) -> String:
    var s: String = raw.to_lower()
    if ".r" in s or "_r" in s or "-r" in s or "right" in s:
        return "r"
    if ".l" in s or "_l" in s or "-l" in s or "left" in s:
        return "l"
    var compact: String = s.replace(" ", "").replace("_", "").replace("-", "").replace(".", "")
    if compact.ends_with("r"):
        return "r"
    if compact.ends_with("l"):
        return "l"
    return ""

func _override_mesh_materials(node: Node, material: Material) -> void:
    if node is MeshInstance3D:
        (node as MeshInstance3D).material_override = material
    for child: Node in node.get_children():
        _override_mesh_materials(child, material)

func _disable_animation_trees(node: Node) -> void:
    if node is AnimationTree:
        (node as AnimationTree).active = false
    for child: Node in node.get_children():
        _disable_animation_trees(child)

func _find_best_animation_player(root: Node) -> AnimationPlayer:
    var players: Array[AnimationPlayer] = []
    _collect_animation_players(root, players)
    var best: AnimationPlayer = null
    var count_best: int = -1
    for p: AnimationPlayer in players:
        var count: int = p.get_animation_list().size()
        if count > count_best:
            count_best = count
            best = p
    return best

func _collect_animation_players(node: Node, out: Array[AnimationPlayer]) -> void:
    if node is AnimationPlayer:
        out.append(node as AnimationPlayer)
    for child: Node in node.get_children():
        _collect_animation_players(child, out)

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child: Node in node.get_children():
        var result: Skeleton3D = _find_skeleton(child)
        if result != null:
            return result
    return null

func _make_missing_marker() -> void:
    var label := Label3D.new()
    label.text = "UAL1 MISSING"
    label.position = Vector3(0, 1.5, 0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)
