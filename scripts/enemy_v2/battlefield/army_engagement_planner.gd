extends RefCounted
## Bounded group-level allocation: preserve army combat while a subset pressures the player.
var pursuing: Dictionary = {}
func choose_player_groups(groups: Dictionary, position: Vector3, fraction: float, radius: float, all_player: bool) -> void:
	var candidates: Array[StringName] = []
	for id: StringName in groups:
		if all_player or (groups[id].anchor as Vector3).distance_to(position)<=radius: candidates.append(id)
	candidates.sort_custom(func(a: StringName,b: StringName) -> bool:
		return (groups[a].anchor as Vector3).distance_to(position)-(6.0 if pursuing.has(a) else 0.0) < (groups[b].anchor as Vector3).distance_to(position)-(6.0 if pursuing.has(b) else 0.0))
	var quota := candidates.size() if all_player else ceili(groups.size()*clampf(fraction,0,1))
	pursuing.clear()
	for i in range(mini(quota,candidates.size())): pursuing[candidates[i]] = true

func opponent_for(group: Dictionary, opponents: Array[Dictionary], loads: Dictionary) -> Dictionary:
	var chosen: Dictionary = {}
	var best := INF
	for index in range(opponents.size()):
		var opponent: Dictionary = opponents[index]
		var score := (group.anchor as Vector3).distance_squared_to(opponent.anchor)+float(loads.get(index,0))*100.0
		if score<best: best = score; chosen = opponent; chosen = chosen.duplicate(); chosen.assignment_index = index
	if not chosen.is_empty(): loads[chosen.assignment_index] = int(loads.get(chosen.assignment_index,0))+1
	return chosen

func firing_position(id: StringName, desired: Vector3, target: Vector3, right: Vector3, runtime: Node) -> Vector3:
	if runtime.is_fire_lane_clear(id,desired,target): return desired
	for offset: float in [6.0,-6.0,12.0,-12.0,18.0,-18.0]:
		var candidate := desired+right*offset
		if candidate.distance_to(target)>32.0: continue
		if runtime.is_fire_lane_clear(id,candidate,target): return candidate
	return desired
