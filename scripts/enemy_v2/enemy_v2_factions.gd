extends RefCounted
## Relationship rules independent of visual skin and weapon.
static func team(node: Node) -> StringName:
	if node == null or not is_instance_valid(node): return &"none"
	if node.has_meta("v2_faction"): return StringName(node.get_meta("v2_faction"))
	if node is HopliteEnemyActorV2: return node.faction
	if node.is_in_group("player") or node is HopliteUALNativePlayer: return &"spartan"
	# Legacy actors expose faction. Unknown test targets remain hostile.
	for field: Dictionary in node.get_property_list():
		if field.name == "faction": return StringName(node.get("faction"))
	return &"unknown"
static func hostile(a: Node, b: Node) -> bool:
	return is_instance_valid(a) and is_instance_valid(b) and a != b and team(a) != team(b)
