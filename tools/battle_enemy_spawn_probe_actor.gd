extends "res://scripts/battle/battle_01.gd"

# The probe exercises Battle 01's inherited spawn helpers without constructing
# the authored battlefield, UI, player, or full encounter roster.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
