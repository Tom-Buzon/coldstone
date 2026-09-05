# Camera occlusion and combat-action reconciliation

## Goal

Keep the current camera readability and combat behavior while removing the main avoidable CPU/allocation costs and the stale Spiral Down state that can permanently reject wall attachment.

## Decisions

- `HopliteNativeAnimationDriver.attack_queue` remains the only buffered-combat queue.
- Every accepted attack carries immutable action metadata (`request_id`, slot, context, spiral direction and blocked capabilities).
- The animation driver emits action start, finish and cancellation signals. `player.gd` derives spiral movement state from the active action metadata instead of maintaining a parallel queue and guessing transitions from clip progress.
- Interrupted Spiral Down actions restore collision state immediately. A normally completed aerial Spiral Down may keep its impact-pending state until ground impact, preserving the existing move.
- Wall attachment checks the active action's explicit `wall_attach` capability block. Every rejection updates `wall_run_debug_reason`.
- Camera occlusion keeps the same 20 Hz scans, nine-ray corridor, overlap probe, opacity and material restoration. It caches per-visual AABBs, collider-to-visual resolution, and reusable physics query objects to remove repeated tree searches and query construction.

## Validation

- Existing camera occlusion readability test.
- Existing wall-run and combat probes.
- New regression probe: four low spirals, heavy-charge interruption/cancel, then no stale wall-attach block.
- Headless parse/runtime checks and Godot-specific code review.

## Deferred by design

- A dedicated `PlayerCombatActionController` state machine.
- Spatial partitioning of every render-only visual in very large scenes; this would change update semantics and needs profiler evidence plus scene-specific classification.
- Reducing the number of wall-run rays; that changes detection tolerance and must be tuned as a gameplay change.
