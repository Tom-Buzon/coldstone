# T-Rex charge spacing and traversal stability

## Approved behavior

- New velociraptor placements do not enable giant traversal by default; the Forge checkbox remains available.
- A T-Rex that is too close to prepare a charge backs up along its current facing axis without turning.
- The back-up phase is capped by time and distance so following the T-Rex cannot make it flee indefinitely.
- The T-Rex aligns with a bounded turn rate, locks a charge direction, then keeps that direction through windup and charge.
- The full recovery window preserves the charge facing, even when the player moves behind or in front of the T-Rex.
- Standing or wall-running on animated dinosaur traversal surfaces must not inherit an unbounded launch velocity.

## Implementation tasks

- [x] Change the velociraptor profile and Forge dinosaur payload default while preserving explicit saved values.
  Skills: `godot-prompter:godot-brainstorming`, `godot-prompter:godot-testing`
- [x] Extend the current enum FSM with bounded create-space and alignment states.
  Skills: `godot-prompter:state-machine`, `godot-prompter:ai-navigation`, `godot-prompter:physics-system`
- [x] Synchronize dinosaur traversal bodies with physics and suppress inherited leave velocity only for giant traversal supports.
  Skills: `godot-prompter:physics-system`, `godot-prompter:player-controller`, `godot-prompter:godot-debugging`
- [x] Add regression coverage for defaults, state transitions, facing locks, finite retreat and traversal launch protection.
  Skills: `godot-prompter:godot-testing`
- [x] Run the dinosaur and wall-run probes, then review the modified GDScript.
  Skills: `godot-prompter:godot-code-review`
