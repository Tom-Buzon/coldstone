extends RefCounted
## Optional anatomy-dependent ability; the unarmed weapon owns its execution clock.
func available(actor: Node) -> bool:
	return actor.locomotion_factor >= 1.0
func pattern() -> Dictionary:
	return {"id": &"giant_slam", "windup":1.7, "recovery":2.15, "radius":1.05, "dot":-1.0, "damage":1.3, "offset":1.05, "clip_length":3.8, "max_height":1.15}
