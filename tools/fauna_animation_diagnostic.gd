extends SceneTree

const FaunaSettingsScript = preload("res://scripts/fauna/fauna_settings.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for definition: Dictionary in FaunaSettingsScript.SPECIES:
		var packed := load(String(definition["model_path"])) as PackedScene
		if packed == null:
			continue
		var instance := packed.instantiate()
		var players := instance.find_children("*", "AnimationPlayer", true, false)
		for raw_player: Node in players:
			var animation_player := raw_player as AnimationPlayer
			var wanted := "flying" if StringName(definition["id"]) == &"eagle" else "walk"
			for animation_name: StringName in animation_player.get_animation_list():
				if String(animation_name).to_lower().ends_with(wanted):
					var animation := animation_player.get_animation(animation_name)
					animation_player.play(animation_name)
					animation_player.advance(animation.length + 0.05)
					print("FAUNA_ANIMATION_DIAGNOSTIC species=%s clip=%s length=%.3f loop=%d playing_after_end=%s current=%s" % [String(definition["id"]), String(animation_name), animation.length, animation.loop_mode, str(animation_player.is_playing()), String(animation_player.current_animation)])
					break
		instance.free()
	quit(0)
