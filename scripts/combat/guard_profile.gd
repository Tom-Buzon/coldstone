extends Resource
class_name CombatGuardProfile

## Shared, immutable tuning for any combatant able to raise a guard. Runtime
## state belongs to CombatGuardComponent, never to this shared Resource.

@export_group("Break chances")
@export_range(0.0, 1.0, 0.01) var light_break_chance: float = 0.08
@export_range(0.0, 1.0, 0.01) var heavy_break_chance: float = 0.30
@export_range(0.0, 1.0, 0.01) var spiral_up_break_chance: float = 0.72
@export_range(0.0, 1.0, 0.01) var spiral_down_break_chance: float = 0.78
@export_range(0.0, 1.0, 0.01) var fallback_break_chance: float = 0.12
@export_range(0.5, 2.0, 0.01) var fully_charged_threshold: float = 0.98

@export_group("Defender")
## Values above 1.0 reduce every non-guaranteed break chance.
@export_range(0.1, 4.0, 0.05) var break_resistance: float = 1.0
@export_range(0.05, 3.0, 0.05) var stun_seconds: float = 0.75
@export_range(0.0, 2.0, 0.05) var step_back_distance: float = 0.55
@export_range(0.05, 1.0, 0.01) var block_reaction_seconds: float = 0.30
