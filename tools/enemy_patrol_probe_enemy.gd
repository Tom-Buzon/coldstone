extends HopliteAthenianEnemy


func _ready() -> void:
	# The patrol decision test needs the real controller state but not the visual,
	# anatomy or animation package built by the production _ready().
	pass
