extends Node
class_name HoplitePlayerPresentation

# The player is the only runtime object shared by every playable scene.  Keeping
# this presentation stack here makes Forge tests and user-created worlds inherit
# the same settings, combat feedback and audio without scene-specific wiring.
const CombatAudioScript = preload("res://scripts/audio/combat_audio.gd")
const GoreHUDScript = preload("res://scripts/ui/gore_hud.gd")
const AudioSettingsScript = preload("res://scripts/ui/audio_settings.gd")
const FaunaManagerScript = preload("res://scripts/fauna/fauna_manager.gd")

var player: HopliteUALNativePlayer
var combat_audio: HopliteCombatAudio
var gore_hud: HopliteGoreHUD
var audio_settings: HopliteAudioSettings
var fauna_manager: HopliteFaunaManager
var owns_presentation_stack := false
var initialized := false


func configure(owner: HopliteUALNativePlayer) -> void:
	player = owner
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Legacy levels currently finish constructing their scene-owned stack just
	# after add_child(player). Waiting one turn lets us reuse it instead of ever
	# producing two HUDs while all new/Forge runtimes remain player-owned.
	call_deferred("_initialize")


func _initialize() -> void:
	if initialized or player == null or not is_instance_valid(player) or not is_inside_tree():
		return
	initialized = true
	_find_existing_stack()
	_ensure_fauna_manager()
	if combat_audio != null and gore_hud != null and audio_settings != null:
		return

	owns_presentation_stack = true
	if combat_audio == null:
		combat_audio = CombatAudioScript.new() as HopliteCombatAudio
		combat_audio.name = "PlayerCombatAudio"
		add_child(combat_audio)
	if gore_hud == null:
		gore_hud = GoreHUDScript.new() as HopliteGoreHUD
		gore_hud.name = "PlayerGoreHUD"
		add_child(gore_hud)
	if audio_settings == null:
		audio_settings = AudioSettingsScript.new() as HopliteAudioSettings
		audio_settings.name = "PlayerSettings"
		audio_settings.combat_audio = combat_audio
		audio_settings.gore_hud = gore_hud
		audio_settings.player = player
		add_child(audio_settings)

	_wire_player()
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		_wire_enemy(enemy)
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)


func _find_existing_stack() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node: Node in scene.find_children("*", "", true, false):
		if combat_audio == null and node is HopliteCombatAudio:
			combat_audio = node as HopliteCombatAudio
		elif gore_hud == null and node is HopliteGoreHUD:
			gore_hud = node as HopliteGoreHUD
		elif audio_settings == null and node is HopliteAudioSettings:
			audio_settings = node as HopliteAudioSettings
		elif fauna_manager == null and node is HopliteFaunaManager:
			fauna_manager = node as HopliteFaunaManager


func _ensure_fauna_manager() -> void:
	if fauna_manager != null and is_instance_valid(fauna_manager):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	fauna_manager = FaunaManagerScript.new() as HopliteFaunaManager
	fauna_manager.name = "RuntimeFauna"
	scene.add_child(fauna_manager)
	fauna_manager.configure(player)


func _wire_player() -> void:
	if not player.damage_received.is_connected(_on_player_damage_received):
		player.damage_received.connect(_on_player_damage_received)
	if not player.movement_sfx_requested.is_connected(combat_audio.play_movement_sfx):
		player.movement_sfx_requested.connect(combat_audio.play_movement_sfx)
	if not player.combat_hit.is_connected(_on_player_combat_hit):
		player.combat_hit.connect(_on_player_combat_hit)
	if not player.perfect_response_started.is_connected(gore_hud.register_perfect_response):
		player.perfect_response_started.connect(gore_hud.register_perfect_response)
	if not player.perfect_response_consumed.is_connected(gore_hud.consume_perfect_response):
		player.perfect_response_consumed.connect(gore_hud.consume_perfect_response)
	var feedback := player.get_combat_feedback()
	if feedback != null:
		if not feedback.audio_cue_requested.is_connected(combat_audio.play_feedback_cue):
			feedback.audio_cue_requested.connect(combat_audio.play_feedback_cue)
		if not feedback.cinematic_started.is_connected(gore_hud.register_cinematic):
			feedback.cinematic_started.connect(gore_hud.register_cinematic)


func _on_tree_node_added(node: Node) -> void:
	if node.is_in_group("enemy") or node is HopliteAthenianEnemy:
		_wire_enemy(node)


func _wire_enemy(node: Node) -> void:
	var enemy := node as HopliteAthenianEnemy
	if enemy == null:
		return
	if not enemy.localized_hit.is_connected(_on_enemy_localized_hit):
		enemy.localized_hit.connect(_on_enemy_localized_hit)
	if not enemy.attack_started.is_connected(_on_enemy_attack_started):
		enemy.attack_started.connect(_on_enemy_attack_started)
	if not enemy.zone_severed.is_connected(_on_enemy_zone_severed):
		enemy.zone_severed.connect(_on_enemy_zone_severed)
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)


func _on_player_damage_received(damage: float, _attacker: Node) -> void:
	combat_audio.play_player_hurt(damage)
	gore_hud.register_player_hurt(damage)


func _on_player_combat_hit(_target: Node, zone: StringName, hit: Variant) -> void:
	if hit == null:
		return
	var contact := StringName(hit.contact_type)
	var defended := contact in [&"shield", &"parry", &"armor", &"guard_break"]
	var contact_count := gore_hud.register_contact(zone, float(hit.damage), defended)
	combat_audio.play_hit_confirm(zone, contact_count, defended)


func _on_enemy_localized_hit(enemy: Node, zone: StringName, damage: float, sever_damage: float) -> void:
	var combo_count := gore_hud.register_hit(enemy, zone, damage, sever_damage)
	combat_audio.play_combo_tick(combo_count)


func _on_enemy_attack_started(enemy: Node, weapon_kind: StringName) -> void:
	if player == null or not (enemy is Node3D):
		return
	var distance_to_player := (enemy as Node3D).global_position.distance_to(player.global_position)
	if distance_to_player <= 10.5:
		combat_audio.play_enemy_swing(weapon_kind, distance_to_player)


func _on_enemy_zone_severed(enemy: Node, zone: StringName) -> void:
	combat_audio.play_sever(zone)
	gore_hud.register_sever(enemy, zone)


func _on_enemy_died(enemy: Node) -> void:
	var archetype_id := &"swordsman"
	var archetype_value: Variant = enemy.get("archetype_id") if enemy != null else null
	if archetype_value != null:
		archetype_id = StringName(archetype_value)
	combat_audio.play_kill(archetype_id)
	gore_hud.register_kill(enemy)


func _input(event: InputEvent) -> void:
	if not owns_presentation_stack:
		return
	if event.is_action_pressed(&"toggle_settings") and audio_settings != null and not audio_settings.is_open():
		audio_settings.set_open(true)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if _is_settings_key(key):
			if audio_settings != null and not audio_settings.is_open():
				audio_settings.set_open(true)
			get_viewport().set_input_as_handled()


func _is_settings_key(key: InputEventKey) -> bool:
	return key.unicode == 0x00B2 or key.keycode == KEY_QUOTELEFT or key.physical_keycode == KEY_QUOTELEFT


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)
