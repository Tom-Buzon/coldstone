extends RefCounted
## Per-actor encounter tuning. Never mutate a shared unit definition.
var power := 1.0
var speed := 1.0
var intercept_reach := 5.5
var sortie_seconds := 1.4
func configure(elite_power: float) -> void:
	intercept_reach = 10.0
	sortie_seconds = 2.5
	power = clampf(elite_power,1.0,8.0)
	speed = 1.0 if power == 1.0 else 1.35
func incoming(hit: Variant) -> Variant:
	if hit == null or power == 1.0: return hit
	var copy: Variant = hit.clone()
	copy.damage /= power
	copy.sever_damage /= power
	return copy
