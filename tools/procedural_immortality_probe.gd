extends SceneTree

const CampaignScript = preload("res://scripts/campaign/procedural_campaign.gd")
const PlayerScript = preload("res://scripts/player.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var campaign := CampaignScript.new() as Node3D
	var player := PlayerScript.new() as HopliteUALNativePlayer
	player.process_mode = Node.PROCESS_MODE_DISABLED
	scene.add_child(player)
	await process_frame
	campaign.set("player", player)
	player.health = 0.0
	campaign.call("_recover_test_player")
	assert(is_equal_approx(player.health, player.max_health), "Test immortality did not restore health")
	assert(player.enemy_hit_invulnerability_timer >= 2.49, "Test immortality did not grant recovery invulnerability")
	campaign.set("safe_player_spawn", Vector3(2.0, 1.35, 3.0))
	campaign.set("current_layout", {"safe_bounds": Rect2(-10.0, -10.0, 20.0, 20.0)})
	player.global_position = Vector3(0.0, -8.0, 0.0)
	campaign.call("_audit_player_position")
	assert(player.global_position.is_equal_approx(Vector3(2.0, 1.35, 3.0)), "Void rescue did not restore the safe spawn")
	assert(player.velocity.is_zero_approx(), "Void rescue retained falling velocity")
	print("[PROCEDURAL IMMORTALITY PROBE] PASS — immortality and player void rescue")
	scene.free()
	campaign.free()
	quit(0)
