extends Resource
## Difficulty changes response time and player pressure, never unit identity.
@export var reaction_seconds := 1.1
@export var player_pressure := 6
static func create(difficulty: StringName) -> Resource:
	var value = load("res://scripts/enemy_v2/battlefield/army_difficulty.gd").new()
	match difficulty:
		&"novice":
			value.reaction_seconds = 2.2
			value.player_pressure = 4
		&"hard": value.reaction_seconds = 0.7
	return value
