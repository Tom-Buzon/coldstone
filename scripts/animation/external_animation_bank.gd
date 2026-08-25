extends Node
class_name HopliteExternalAnimationBank

const BridgeScript = preload("res://scripts/animation/authored_pose_bridge.gd")
const HumanoidRetargetScript = preload("res://scripts/animation/humanoid_retarget_proxy.gd")
const ROOT := "res://assets/runtime/mixamo/animations/"
const PACK := ROOT + "sword_and_shield_pack/"
const CREATURE_PACK := ROOT + "creature_pack/"

const DONOR_PATHS := {
	# Compact single cut: unlike the original clip, it does not redraw a second
	# flourish before returning to guard.
	&"light1": PACK + "sword and shield slash (5).fbx",
	&"light2": PACK + "sword and shield slash (3).fbx",
	&"light3": PACK + "sword and shield attack (3).fbx",
	&"dash_attack": PACK + "sword and shield slash (4).fbx",
	# Dedicated ripostes deliberately avoid the regular light/heavy silhouettes.
	# The alternate is longer and gets trimmed/speed-matched by player.gd.
	&"counter_light": ROOT + "Stable Sword Outward Slash.fbx",
	&"counter_light_alt": PACK + "sword and shield slash (2).fbx",
	&"heavy_fast": PACK + "sword and shield attack (4).fbx",
	&"heavy_release": PACK + "sword and shield attack (2).fbx",
	&"heavy_max": PACK + "sword and shield attack.fbx",
	&"spin_high": ROOT + "Great Sword High Spin Attack.fbx",
	# The Great Sword Slash donor only cuts toward the character's left side.  The
	# explicitly authored 360 Low donor is the actual circular leg sweep expected
	# by the Spiral Down input; keep the old slash as a diagnostics-only fallback.
	&"spin_low": ROOT + "Standing Melee Attack 360 Low.fbx",
	&"spin_low_alt": ROOT + "Great Sword Slash.fbx",
	&"slide_left": ROOT + "Great Sword Slide Attackleft.fbx",
	&"slide_right": ROOT + "Great Sword Slide Attackright.fbx",
	&"air_down": ROOT + "Great Sword Jump Attack.fbx",
	&"run_jump": ROOT + "Standing Melee Run Jump Attack.fbx",
	# Dedicated parkour movement. Wall Run and Diagonal Wall Run are short
	# Mixamo clips; the movement driver loops their actual running cycle so the
	# mechanical run can cover the full configured distance without slow motion.
	&"wall_run": ROOT + "Wall Run.fbx",
	&"wall_run_diagonal": ROOT + "Diagonal Wall Run.fbx",
	&"wall_run_vertical": ROOT + "Run To Flip.fbx",
	&"wall_run_detach_twist": ROOT + "Front Twist Flip.fbx",
	&"block_enter": PACK + "sword and shield block.fbx",
	&"block_idle": PACK + "sword and shield block idle.fbx",
	&"block_impact": PACK + "sword and shield impact.fbx",
	&"power_up": PACK + "sword and shield power up.fbx",
	# Enemy weapon layers. The bow donor is played upper-body only so the package
	# locomotion keeps ownership of the legs. The two shield attacks are compact
	# enough to become short dory thrusts once the weapon is procedurally aimed.
	&"bow_aim": ROOT + "Bow Standing Aim Walk Back.fbx",
	&"spear_thrust": PACK + "sword and shield attack (3).fbx",
	&"spear_thrust_low": PACK + "sword and shield slash (3).fbx",
	&"shield_bash": PACK + "sword and shield impact.fbx",
	# Enemy-only signatures. They remain dormant for the player and are loaded
	# selectively by elite controllers, never as one large bank on every soldier.
	&"axe_down": ROOT + "Axe Standing Melee Attack Downward.fbx",
	&"axe_horizontal": ROOT + "Axe Standing Melee Attack Horizontal.fbx",
	&"axe_combo": ROOT + "Axe Standing Melee Combo Attack Ver. 1.fbx",
	&"battlecry": ROOT + "Axe Standing Taunt Battlecry.fbx",
	&"mutant_punch": ROOT + "Mutant Punch.fbx",
	&"mutant_roar": ROOT + "Mutant Roaring.fbx",
	&"mutant_swipe": ROOT + "Mutant Swiping.fbx",
	# Dedicated giant kit imported from Creature Pack. These names stay separate
	# from the three historical Mutant donors above so replacing or re-exporting
	# the complete pack cannot silently change older brute/boss encounters.
	&"giant_punch": CREATURE_PACK + "mutant punch.fbx",
	&"giant_swipe": CREATURE_PACK + "mutant swiping.fbx",
	&"giant_roar": CREATURE_PACK + "mutant roaring.fbx",
	&"giant_jump_attack": CREATURE_PACK + "mutant jump attack.fbx",
	&"giant_jump_attack_alt": CREATURE_PACK + "jump attack.fbx",
	&"giant_flex": CREATURE_PACK + "mutant flexing muscles.fbx",
	&"sword_slash": ROOT + "Stable Sword Outward Slash.fbx",
	&"vertical_sword": ROOT + "verticalSwordAttack.fbx",
	&"flying_knee": ROOT + "Flying Knee Punch Combo.fbx",
}

const DEFAULT_PLAYER_KEYS: Array[StringName] = [
	&"light1", &"light2", &"light3", &"dash_attack", &"counter_light", &"counter_light_alt",
	&"heavy_fast", &"heavy_release", &"heavy_max",
	&"spin_high", &"spin_low", &"spin_low_alt",
	&"slide_left", &"slide_right", &"air_down", &"run_jump",
	&"block_enter", &"block_idle", &"block_impact", &"power_up"
]

var target_skeleton: Skeleton3D
var donors: Dictionary = {}
var active_key: StringName = StringName()

func configure(target: Skeleton3D, requested_keys: Array = []) -> bool:
	target_skeleton = target
	if target_skeleton == null:
		return false
	var keys: Array = requested_keys.duplicate()
	if keys.is_empty():
		keys.assign(DEFAULT_PLAYER_KEYS)
	var loaded: int = 0
	for raw_key: Variant in keys:
		var key := StringName(raw_key)
		if not DONOR_PATHS.has(key):
			push_warning("[EXTERNAL ANIMATION BANK] unknown selective key: " + String(key))
			continue
		if _load_donor(key, String(DONOR_PATHS[key])):
			loaded += 1
	print("[EXTERNAL ANIMATION BANK] loaded=", loaded, "/", keys.size())
	return loaded > 0

func has_clip(key: StringName) -> bool:
	return donors.has(key)

func clip_length(key: StringName) -> float:
	if not donors.has(key):
		return 0.0
	var donor: Dictionary = donors[key]
	var player := donor.get("player") as AnimationPlayer
	var clip := StringName(donor.get("clip", StringName()))
	var animation := player.get_animation(clip) if player != null and clip != StringName() else null
	return animation.length if animation != null else 0.0

func play(key: StringName, blend: float, speed: float, full_body: bool, hips_weight: float, start_fraction: float = 0.0) -> float:
	if not donors.has(key):
		return 0.0
	stop()
	var donor: Dictionary = donors[key]
	var player: AnimationPlayer = donor.get("player") as AnimationPlayer
	var bridge: HopliteAuthoredPoseBridge = donor.get("bridge") as HopliteAuthoredPoseBridge
	var clip: StringName = StringName(donor.get("clip", StringName()))
	if player == null or bridge == null or clip == StringName():
		return 0.0
	var animation: Animation = player.get_animation(clip)
	if animation == null:
		return 0.0
	animation.loop_mode = Animation.LOOP_NONE
	player.play(clip, maxf(blend, 0.0), speed)
	player.advance(0.0)
	var fraction: float = clampf(start_fraction, 0.0, 0.75)
	if fraction > 0.001:
		player.seek(animation.length * fraction, true)
	bridge.set_attack_weight(0.001, full_body, hips_weight)
	active_key = key
	return maxf((animation.length * (1.0 - fraction)) / maxf(absf(speed), 0.05), 0.10)

func play_loop(key: StringName, blend: float, speed: float, full_body: bool, hips_weight: float) -> bool:
	if not donors.has(key):
		return false
	stop()
	var donor: Dictionary = donors[key]
	var player: AnimationPlayer = donor.get("player") as AnimationPlayer
	var bridge: HopliteAuthoredPoseBridge = donor.get("bridge") as HopliteAuthoredPoseBridge
	var clip: StringName = StringName(donor.get("clip", StringName()))
	if player == null or bridge == null or clip == StringName():
		return false
	var animation: Animation = player.get_animation(clip)
	if animation == null:
		return false
	animation.loop_mode = Animation.LOOP_LINEAR
	player.play(clip, maxf(blend, 0.0), speed)
	player.advance(0.0)
	bridge.set_attack_weight(0.001, full_body, hips_weight)
	active_key = key
	return true

func hold(key: StringName, pose_fraction: float, full_body: bool, hips_weight: float) -> bool:
	if not donors.has(key):
		return false
	stop()
	var donor: Dictionary = donors[key]
	var player: AnimationPlayer = donor.get("player") as AnimationPlayer
	var bridge: HopliteAuthoredPoseBridge = donor.get("bridge") as HopliteAuthoredPoseBridge
	var clip: StringName = StringName(donor.get("clip", StringName()))
	if player == null or bridge == null:
		return false
	var animation: Animation = player.get_animation(clip)
	if animation == null:
		return false
	player.play(clip, 0.06, 1.0)
	player.advance(0.0)
	player.seek(animation.length * clampf(pose_fraction, 0.0, 0.95), true)
	player.pause()
	bridge.set_attack_weight(1.0, full_body, hips_weight)
	active_key = key
	return true

func set_weight(weight: float, full_body: bool, hips_weight: float) -> void:
	var bridge: HopliteAuthoredPoseBridge = active_bridge()
	if bridge != null:
		bridge.set_attack_weight(weight, full_body, hips_weight)

func set_aim_pitch(value: float) -> void:
	var bridge: HopliteAuthoredPoseBridge = active_bridge()
	if bridge != null:
		bridge.set_attack_aim_pitch(value)

func set_mirrored(enabled: bool) -> void:
	var bridge: HopliteAuthoredPoseBridge = active_bridge()
	if bridge != null:
		bridge.set_pose_mirrored(enabled)

func seek_active_fraction(minimum_fraction: float) -> float:
	if active_key == StringName() or not donors.has(active_key):
		return 0.0
	var donor: Dictionary = donors[active_key]
	var player: AnimationPlayer = donor.get("player") as AnimationPlayer
	var clip: StringName = StringName(donor.get("clip", StringName()))
	if player == null or clip == StringName():
		return 0.0
	var animation: Animation = player.get_animation(clip)
	if animation == null or animation.length <= 0.001:
		return 0.0
	var minimum_time: float = animation.length * clampf(minimum_fraction, 0.0, 0.95)
	var target_time: float = maxf(player.current_animation_position, minimum_time)
	player.seek(target_time, true)
	return maxf(animation.length - target_time, 0.05)

func active_bridge() -> HopliteAuthoredPoseBridge:
	if active_key == StringName() or not donors.has(active_key):
		return null
	return donors[active_key].get("bridge") as HopliteAuthoredPoseBridge

func move_pose_bridges_before(anchor: Node) -> void:
	if target_skeleton == null or anchor == null or anchor.get_parent() != target_skeleton:
		return
	# Wall movement must be evaluated before the combat bridges. The latter can
	# then replace arms/spine while the wall animation keeps the hips and legs.
	for raw_donor: Variant in donors.values():
		var donor: Dictionary = raw_donor
		var bridge: Node = donor.get("bridge") as Node
		if bridge != null and bridge.get_parent() == target_skeleton:
			target_skeleton.move_child(bridge, anchor.get_index())

func pose_bridges_precede(anchor: Node) -> bool:
	if target_skeleton == null or anchor == null or anchor.get_parent() != target_skeleton:
		return false
	for raw_donor: Variant in donors.values():
		var donor: Dictionary = raw_donor
		var bridge: Node = donor.get("bridge") as Node
		if bridge == null or bridge.get_parent() != target_skeleton or bridge.get_index() >= anchor.get_index():
			return false
	return not donors.is_empty()

func stop() -> void:
	if active_key != StringName() and donors.has(active_key):
		var donor: Dictionary = donors[active_key]
		var player: AnimationPlayer = donor.get("player") as AnimationPlayer
		var bridge: HopliteAuthoredPoseBridge = donor.get("bridge") as HopliteAuthoredPoseBridge
		if player != null:
			player.stop()
		if bridge != null:
			bridge.set_attack_weight(0.0, false, 0.0)
	active_key = StringName()

func _load_donor(key: StringName, path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_warning("[EXTERNAL ANIMATION BANK] missing: " + path)
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var scene := packed.instantiate()
	scene.name = "ExternalDonor_" + String(key)
	add_child(scene)
	_disable_animation_trees(scene)
	if scene is Node3D:
		(scene as Node3D).visible = false
	var skeleton: Skeleton3D = _find_skeleton(scene)
	var player: AnimationPlayer = _find_animation_player(scene)
	if skeleton == null or player == null:
		scene.queue_free()
		return false
	var clip: StringName = _first_animation(player)
	if clip == StringName():
		scene.queue_free()
		return false
	player.stop()
	var retarget: Dictionary = HumanoidRetargetScript.build(skeleton, player, target_skeleton)
	var proxy := retarget.get("proxy") as Skeleton3D
	if proxy == null:
		scene.queue_free()
		return false
	var bridge := BridgeScript.new() as HopliteAuthoredPoseBridge
	bridge.name = "ExternalPoseBridge_" + String(key)
	target_skeleton.add_child(bridge)
	if not bridge.configure(proxy, true):
		bridge.queue_free()
		scene.queue_free()
		return false
	# The native RetargetModifier3D already converted Mixamo into the UAL1 rest
	# space. A second rest conversion here would recreate the twisted limbs.
	bridge.set_rest_space_retarget(false)
	bridge.set_mixamo_runtime_guards(true, true)
	bridge.set_attack_weight(0.0, false, 0.0)
	donors[key] = {"scene": scene, "skeleton": skeleton, "proxy": proxy, "retarget": retarget.get("modifier"), "player": player, "bridge": bridge, "clip": clip, "path": path}
	return true

func _first_animation(player: AnimationPlayer) -> StringName:
	for clip: StringName in player.get_animation_list():
		if clip != &"RESET" and player.get_animation(clip) != null and player.get_animation(clip).length > 0.02:
			return clip
	return StringName()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _disable_animation_trees(node: Node) -> void:
	if node is AnimationTree:
		(node as AnimationTree).active = false
	for child: Node in node.get_children():
		_disable_animation_trees(child)
