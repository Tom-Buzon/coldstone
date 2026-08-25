extends SceneTree

const SOURCES := [
	"res://assets/runtime/ual1/UAL1_Standard.glb",
	"res://assets/runtime/ual2/UAL2_Standard.glb",
	"res://assets/runtime/mixamo/animations/Axe Standing Block Idle.fbx",
	"res://assets/runtime/mixamo/animations/Axe Standing Melee Attack Downward.fbx",
	"res://assets/runtime/mixamo/animations/Axe Standing Melee Attack Horizontal.fbx",
	"res://assets/runtime/mixamo/animations/Axe Standing Melee Attack Kick Ver. 1.fbx",
	"res://assets/runtime/mixamo/animations/Axe Standing Melee Combo Attack Ver. 1.fbx",
	"res://assets/runtime/mixamo/animations/Great Sword Jump Attack.fbx",
	"res://assets/runtime/mixamo/animations/Great Sword High Spin Attack.fbx",
	"res://assets/runtime/mixamo/animations/Great Sword Slash.fbx",
	"res://assets/runtime/mixamo/animations/Great Sword Slide Attackleft.fbx",
	"res://assets/runtime/mixamo/animations/Great Sword Slide Attackright.fbx",
	"res://assets/runtime/mixamo/animations/Standing Melee Attack 360 Low.fbx",
	"res://assets/runtime/mixamo/animations/Standing Melee Run Jump Attack.fbx",
	"res://assets/runtime/mixamo/animations/Wall Run.fbx",
	"res://assets/runtime/mixamo/animations/Diagonal Wall Run.fbx",
	"res://assets/runtime/mixamo/animations/Run To Flip.fbx",
	"res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield slash.fbx",
	"res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield slash (2).fbx",
	"res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield slash (3).fbx",
	"res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield slash (4).fbx",
	"res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield slash (5).fbx",
	"res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield attack.fbx",
	"res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield attack (2).fbx",
	"res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield attack (3).fbx",
	"res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield attack (4).fbx",
	"res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield block idle.fbx",
	"res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield block.fbx",
	"res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield impact.fbx",
	"res://assets/runtime/mixamo/animations/sword_and_shield_pack/sword and shield power up.fbx",
	"res://assets/runtime/mixamo/animations/Stable Sword Outward Slash.fbx",
	"res://assets/runtime/mixamo/animations/verticalSwordAttack.fbx",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	for path: String in SOURCES:
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("[ANIMATION CATALOG] missing: " + path)
			failures += 1
			continue
		var root := packed.instantiate()
		var players: Array[AnimationPlayer] = []
		_collect_animation_players(root, players)
		for player: AnimationPlayer in players:
			for clip: StringName in player.get_animation_list():
				var animation := player.get_animation(clip)
				print(
					"[ANIMATION CATALOG] ", path,
					" | ", clip,
					" | length=", snappedf(animation.length, 0.001),
					" | tracks=", animation.get_track_count()
				)
		root.free()
	quit(1 if failures > 0 else 0)

func _collect_animation_players(node: Node, output: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		output.append(node as AnimationPlayer)
	for child: Node in node.get_children():
		_collect_animation_players(child, output)
