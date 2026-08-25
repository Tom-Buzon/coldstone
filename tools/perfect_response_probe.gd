extends SceneTree

const PlayerScript = preload("res://scripts/player.gd")
const HUDScript = preload("res://scripts/ui/gore_hud.gd")

class MockEnemy:
    extends Node3D

    var received_area_damage: float = 0.0

    func is_dead_for_combat() -> bool:
        return false

    func get_combat_aim_point() -> Vector3:
        return global_position + Vector3.UP * 1.05

    func receive_ai_hit(damage: float, _attacker: Node3D, _hit_direction: Vector3) -> bool:
        received_area_damage += damage
        return true

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := Node3D.new()
    scene.name = "PerfectResponseProbe"
    root.add_child(scene)
    current_scene = scene

    var player = PlayerScript.new()
    scene.add_child(player)
    var hud = HUDScript.new()
    scene.add_child(hud)
    var enemy := MockEnemy.new()
    enemy.add_to_group("enemy")
    enemy.position = Vector3(0.0, 0.0, -2.4)
    scene.add_child(enemy)
    await process_frame

    _check(is_equal_approx(player.dash_recharge_duration, 3.0), "dash recharge is not 3 seconds")
    _check(is_equal_approx(player.slide_recharge_duration, 1.5), "slide recharge is not 1.5 seconds")
    _check(player.max_spiral_stamina == 12.0 and player.spiral_stamina_cost == 3.0, "spiral storage is not four charges of three stamina")
    _check(player.player_combat_hud != null, "global combat resource HUD was not created by the player")
    if player.player_combat_hud != null:
        var hud_root := player.player_combat_hud.get("root") as Control
        _check(hud_root != null and hud_root.is_in_group("global_hud_combat"), "HUD is not controlled by the global combat HUD setting")
        var hud_dash: Dictionary = player.player_combat_hud.get("dash_card")
        var hud_slide: Dictionary = player.player_combat_hud.get("slide_card")
        var hud_spiral: Dictionary = player.player_combat_hud.get("spiral_card")
        _check(hud_dash.get("meter") is Control, "HUD does not show the dash action bubble")
        _check(hud_slide.get("meter") is Control, "HUD does not show the slide action bubble")
        _check(hud_spiral.get("meter") is Control, "HUD does not show the spiral action bubble")
        _check(player.player_combat_hud.get("health_bar") is ProgressBar, "HUD does not integrate the health bar")
        player.dash_charges = 0
        player.dash_recharge_timer = 1.5
        player.slide_charges = 0
        player.slide_recharge_timer = 0.75
        player.spiral_stamina = 7.0
        player.player_combat_hud.call("_sync_hud")
        var dash_meter := hud_dash.get("meter") as Control
        var slide_meter := hud_slide.get("meter") as Control
        var spiral_meter := hud_spiral.get("meter") as Control
        _check(is_equal_approx(float(dash_meter.get("fill_ratio")), 0.5), "HUD dash bubble does not show partial timer recharge")
        _check(is_equal_approx(float(slide_meter.get("fill_ratio")), 0.5), "HUD slide bubble does not show partial timer recharge")
        _check(is_equal_approx(float(spiral_meter.get("fill_ratio")), 1.0 / 3.0), "HUD spiral bubble does not show partial stamina progress")
        _check("2/4" in ((hud_spiral.get("charge") as Label).text), "HUD spiral storage count is incorrect")
        hud_root.visible = false
        player.player_combat_hud.call("_sync_hud")
        _check(not hud_root.visible, "HUD ignored the global visibility setting")
        hud_root.visible = true

    hud.register_perfect_response(&"block")
    hud._update_perfect_response_overlay(0.11)
    _check(hud.perfect_label.get_theme_font_size("font_size") >= 48, "Perfect UI title is still too small")
    _check(hud.perfect_tint.color.a >= 0.10, "Perfect UI tint is still too faint")
    _check(hud.perfect_frame.modulate.a >= 0.65, "Perfect UI frame is still too faint")
    _check(hud.perfect_bar_fill.size.x < 420.0 and hud.perfect_bar_fill.size.x > 300.0, "Perfect UI countdown is not readable")
    hud.consume_perfect_response()
    _check(hud.perfect_elapsed >= hud.perfect_duration - 0.26, "Perfect UI did not follow counter consumption")

    player.health = player.max_health - 60.0
    player.dash_charges = 0
    player.slide_charges = 0
    player.spiral_stamina = 0.0
    var starting_health: float = player.health
    player._set_shield_blocking(true)
    _check(player.receive_enemy_hit(24.0, enemy, Vector3(0.0, 0.0, 1.0)), "late shield contact was not accepted")
    _check(is_equal_approx(player.health, starting_health), "Perfect Block removed health")
    _check(player.combat_feedback.is_perfect_response_active(), "Perfect Block did not open the response window")
    _check(player.dash_charges == 1 and player.slide_charges == 2, "Perfect Block did not restore every mobility charge")
    _check(player.spiral_stamina >= player.spiral_perfect_reward, "Perfect Block did not build spiral stamina")
    _check(player.perfect_recovery_active, "Perfect Block did not activate empowered recovery")
    player._update_health_recovery(0.25)
    _check(player.health > starting_health, "Perfect Block did not start fast health recovery immediately")
    for _frame: int in range(4):
        await process_frame
    _check(Engine.time_scale < 0.95 and Engine.time_scale >= 0.29, "Perfect response slow motion did not ease in")
    enemy.position = Vector3(0.0, 0.0, -6.0)
    _check(player._do_perfect_counter_light(), "Perfect Block light riposte did not launch")
    _check(not player._perfect_response_available(), "Perfect response could be consumed more than once")
    _check(player.animation_driver.current_attack_context_name() == &"counter_light", "light riposte used the wrong combat context")
    _check(player.animation_driver.current_attack_slot_name() == &"heavy", "light-input riposte was not kept as a fully charged attack")
    _check(player.animation_driver.current_attack_clip == &"external:counter_light", "light riposte did not use its new dedicated animation")
    _check(player.animation_driver.has_external_clip(&"counter_light_alt"), "alternate light riposte animation was not loaded")
    _check(player.attack_assist_target == enemy, "light-input riposte did not retain its full-auto target")
    _check(player.velocity.x == 0.0 and player.velocity.z == 0.0, "light-input riposte retained old dash/run velocity")
    _check(player.perfect_counter_aoe_pending, "light-input riposte did not arm its area damage")
    _check(player.attack_assist_lock_remaining > player.animation_driver.current_attack_length(), "light-input riposte aim lock does not cover the complete animation")
    var counter_hit = player._make_weapon_hit_event(&"heavy", &"counter_light", enemy.global_position, Vector3.FORWARD, 10.0)
    _check(counter_hit.damage >= 95.0 and counter_hit.sever_damage >= 135.0, "light-input riposte did not retain charged counter damage")
    var distance_before_tracking: float = player.global_position.distance_to(enemy.global_position)
    player._update_attack_assist(0.10)
    _check(player.global_position.distance_to(enemy.global_position) < distance_before_tracking - 1.0, "full-auto light-input riposte did not close long-range distance")
    player.global_position = Vector3.ZERO
    enemy.position = Vector3(0.0, 0.0, -2.4)
    player._start_perfect_response(&"block", enemy)
    _check(player._do_perfect_counter_light(), "alternate light riposte did not launch")
    _check(player.animation_driver.current_attack_clip == &"external:counter_light_alt", "light riposte did not alternate its animation")
    player.animation_driver.tick(0.22)
    player._update_perfect_counter_aoe()
    _check(enemy.received_area_damage >= player.perfect_counter_aoe_damage, "light riposte area damage did not reliably hit its nearby target")

    player.combat_feedback.perfect_response_active = false
    player.combat_feedback.time_effect_owned = false
    Engine.time_scale = 1.0
    player._start_regular_dash()
    starting_health = player.health
    _check(player.receive_enemy_hit(24.0, enemy, Vector3(0.0, 0.0, 1.0)), "late dash contact was not accepted")
    _check(is_equal_approx(player.health, starting_health), "Perfect Dodge removed health")
    _check(player.combat_feedback.is_perfect_response_active(), "Perfect Dodge did not open the response window")
    _check(player._do_perfect_counter_dash(), "Perfect Dodge charged dash did not launch")
    _check(player.animation_driver.current_attack_context_name() == &"counter_dash", "charged dash used the wrong combat context")
    _check(player.animation_driver.current_attack_slot_name() == &"heavy", "charged dash did not use charged damage")
    _check(player.animation_driver.current_attack_clip == &"external:run_jump", "charged dash did not use its new dedicated animation")
    _check(player.attack_assist_target == enemy, "full-auto response did not retain the closest target")
    player._start_perfect_response(&"dodge", enemy)
    _check(player._do_perfect_counter_dash(), "alternate charged dash did not launch")
    _check(player.animation_driver.current_attack_clip == &"external:air_down", "charged dash did not alternate its animation")

    player.combat_feedback.perfect_response_active = false
    player.combat_feedback.time_effect_owned = false
    Engine.time_scale = 1.0
    player._start_regular_dash()
    _check(player.register_enemy_near_miss(enemy), "a real last-second near miss did not trigger Perfect Dodge")

    player.combat_feedback.perfect_response_active = false
    player.combat_feedback.time_effect_owned = false
    Engine.time_scale = 1.0
    player.dash_time = 0.0
    player._start_slide(false)
    _check(player.register_enemy_near_miss(enemy), "a last-second slide did not trigger Perfect Dodge")

    player.queue_free()
    enemy.queue_free()
    hud.queue_free()
    await process_frame
    Engine.time_scale = 1.0
    if failures.is_empty():
        print("[PERFECT RESPONSE PROBE] PASS — charged light-input riposte, full-auto tracking, dash/slide dodge, UI and four counter variants")
        quit(0)
    else:
        for failure: String in failures:
            push_error("[PERFECT RESPONSE PROBE] " + failure)
        quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
