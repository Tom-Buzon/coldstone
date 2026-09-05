# Enemy architecture — implemented contracts and retained boundaries

> Pour la composition et le commandement **V2 actuels**, commencer par [README.md](README.md). Ce document conserve le contexte de sa passe et ne remplace pas les nouveaux contrats.

Status: verified description of the runtime delivered by the enemy unification mission. Items explicitly labelled “target” are not claimed as current nodes or authorities.

## Constraints carried forward

- `AthenianEnemy` remains the compatibility boundary used by the factory and every current spawn route.
- There is exactly one owner of `CharacterBody3D.velocity` and `move_and_slide()`: the enemy root.
- `mass_battle_mode` still activates at 28 living enemies.
- A donor skeleton or animation player is removed only after an equivalent visible, animated result is captured and inspected.
- Dismemberment, localized hit zones, shields, weapon loss, and cohort replacement remain supported.
- No route is allowed to silently bypass combat registration, attack scheduling, or cleanup policy.

## Options considered

### A. Continue patching the monolith

This has the smallest immediate diff, but keeps navigation, cohort state, combat leases, anatomy, animation cadence, and rendering policy coupled in one script. It cannot give each subsystem an independent contract or focused regression test. Rejected as the target architecture.

### B. Compatibility facade with narrow components — selected

Keep the current factory and `AthenianEnemy` public surface while moving decisions into small, typed components. The root remains authoritative for physics and translates component outputs into motion, animation, damage, and lifecycle changes. This permits progressive opt-in by archetype and immediate rollback per component.

### C. Replace the enemy stack with a new resource-driven FSM

This would be clean in isolation, but it would replace too many battle-tested contracts at once and make the 22-unit visual, anatomy, and combat migration impossible to attribute safely. Rejected for this mission.

## Runtime scene and service tree

```text
World / CombatLab / Battle
├── CombatantRegistry                # route/autoload service when installed
├── BattleCrowdDirector              # cohort state + spatial grid + attack scheduler
├── NavigationRegion3D(s)            # owned by the level, when present
└── Enemies
    └── AthenianEnemy                # CharacterBody3D compatibility facade
        ├── NavigationAgent3D        # only for NAVMESH_GROUND routes
        ├── EnemyNavigationComponent # lightweight RefCounted intent/recovery service; never moves the root
        ├── implicit action fields     # wind-up/active/recovery/defense/death in the facade
        ├── AnatomyProfile + hit zones # zones, severing, incapacity, fragments
        ├── ShieldHitbox
        ├── animation driver/player    # route-specific playback and shared LOD cadence
        └── VisualRoot
            ├── VisibleRig
            └── DonorRigs             # transitional only, never visible
```

Services are discovered through the existing groups/autoloads used by each route. There is no `EnemyRuntimeServices`, `NavigationWorld`, `EnemyActionState` or `CorpsePolicy` node in the current tree; those names were design alternatives and are not runtime evidence. Missing optional navigation maps use the explicit direct-steering fallback.

## Ownership rules

| Concern | Authority | Output to the enemy root |
| --- | --- | --- |
| Target discovery | `AthenianEnemy` facade + faction/group queries | valid target handle; registry is liveness/bookkeeping, not targeting authority |
| Tactical/cohort decision | `BattleCrowdDirector` | stable cohort assignment, slot and attack lease |
| Pathing and recovery | `EnemyNavigationComponent` | desired planar direction, speed scale and status |
| Physical movement | `AthenianEnemy` root | velocity and `move_and_slide()` |
| Action transitions | implicit fields/methods in `AthenianEnemy` | locomotion/combat/death state with explicit exit conditions |
| Animation playback | route-specific native/shared/Mixamo driver | animation state and sampled pose |
| Localized damage | anatomy profile + runtime hit zones | wound, sever, incapacity and death consequences |
| Death/corpse lifetime | enemy root + transient policies | disabled participation and bounded cleanup |
| Archetype values | cached typed archetype resources | immutable configuration read by components |

Extracted services communicate through method calls/signals. The compatibility facade still owns implicit combat/action state; this mission did not pretend that a standalone action FSM exists. `ACTION_FSM_DESIGN.md` records the rejected prototype and the retained state contract.

## Navigation component contract

The component is a lightweight `RefCounted` service and computes intent only. It never enters the SceneTree, calls `move_and_slide()`, changes the root transform, or owns combat state. Only `NAVMESH_GROUND` creates a `NavigationAgent3D`, parented directly to the owning `CharacterBody3D`; direct, formation and large-body modes therefore add no scene node per enemy.

Modes:

- `NAVMESH_GROUND`: follow a NavigationServer path when a route provides a usable map.
- `FORMATION_LOCAL`: preserve a cohort slot using local steering and separation.
- `DIRECT_STEERING`: deterministic legacy-compatible fallback.
- `STATIC`: no translational intent.
- `FLYING`: unconstrained three-dimensional intent for future flying archetypes.
- `LARGE_BODY`: wider clearance and slower recovery for giants.
- `RECOVERY_ONLY`: leave locomotion unchanged until a stuck condition is detected.

Minimum API:

```gdscript
configure(owner_body, mode, settings)
set_destination(world_position)
set_formation_anchor(world_position, forward, slot_index, cohort_revision)
clear_destination()
sample_intent(delta) -> NavigationIntent
notify_motion_applied(previous_position, current_position, delta)
```

Signals:

```gdscript
destination_reached
navigation_failed(reason)
stuck_detected(attempt)
recovery_started(attempt)
recovery_finished(success)
```

`NavigationIntent` carries direction, speed scale, facing direction, whether motion is valid, and a diagnostic status. If a navmesh is unavailable, `NAVMESH_GROUND` emits one failure per destination revision and uses the configured fallback. Repath and stuck recovery are time-bounded and deterministic.

## Cohort contract

- Cohort identity is stable: `faction + formation_group + cohort_sequence`; it does not contain the current target ID.
- Membership has a revision number. Target changes do not reorder slots.
- A vacancy is filled from the nearest eligible support rank without rebuilding every slot.
- Blocked or incapacitated members stop counting toward readiness after a grace period.
- Formation advance has both a quorum and a timeout/degraded path. Its floor-based degraded quorum lets two operational soldiers out of four advance when two reserves remain blocked.
- The first rank, pressing rank, and support rank expose distinct offsets and desired behaviours.
- Cache lifetime is one physics frame; callers and probes must not expect same-frame transform mutations to invalidate a frame cache.

Expected flow:

```text
facade target refresh
  → cohort decision and persistent slot
  → navigation destination / formation anchor
  → root applies locomotion
  → animation driver samples the resulting action
  → attack scheduler grants a bounded lease
  → combat resolves a hit
```

## Attack scheduling contract

An attack lease contains `holder_id`, `target_id`, `generation`, `granted_at`, and `expires_at`. Release, expiry, death, disable, or target revision invalidates both the scheduler entry and the holder's local token. Waiting candidates use bounded FIFO fairness within priority bands; projectile and melee attacks both request capacity. A local boolean is not an authority.

## Participation and lifecycle

Participation changes are atomic:

```text
spawn
  → configure typed profile
  → register targetable/combatant/AI membership
  → activate components
  → alive gameplay
  → wounded or severed
  → optional incapacity
  → death
  → release lease + leave cohort + unregister
  → disable AI, hitboxes and expensive processing
  → corpse policy / bounded fragments and drops
  → cleanup
```

Changing `ai_enabled` after `_ready()` updates groups, the registry liveness view, director spatial membership, navigation destination, attack lease and animation cadence together. Death calls the same participation boundary after setting the lethal state; a corpse cannot remain in `combatant_ai` for even one physics tick.

Anatomy consequence flow:

```text
localized hit
  → zone damage and sever threshold
  → visual/anatomy mutation
  → capability loss or incapacity
  → if health is lethal, death is always finalized
  → cohort vacancy notification
  → deterministic slot replacement
```

The lethal-health invariant outranks the early return used by a sever animation: no limb-severing hit may leave a living actor at zero health.

## Animation and rig migration

- The visible rig is the animation-output authority.
- Animation LOD controls actual sampling/update cadence, not only parameter writes.
- Near enemies update at their normal driver cadence; progressively distant enemies sample at 30 Hz, 12 Hz, then 0 Hz beyond culling. Shared/native `AnimationTree` drivers and direct Mixamo `AnimationPlayer` routes obey the same policy. Returning to LOD0 restores the original callback mode and forces an immediate sample, so no pose can remain frozen after wake.
- A sleeping corpse does not advance an animation tree.
- Authored skinned equipment remains permissible only when it has a hand-space drop anchor. Severing hides the authored mesh and emits a detachable replacement; `knight3` is the reference compatibility route.
- Donor rigs remain transitional. Removal requires: bone/rest compatibility proof, bind-pose proof, action matrix screenshots, and a before/after node/object/performance comparison.
- The working hoplite shared-library v3 path is the reference implementation, not a license to share incompatible rigs blindly.

## Data model and caches

- The public catalog maps all 22 canonical IDs and explicit aliases to cached typed resources.
- Resource construction happens once per profile revision, not on every lookup.
- Runtime caches have declared scope and invalidation:
  - 20 Hz spatial-neighbour snapshots, invalidated on participation changes;
  - per-physics-frame phalanx assignment cache;
  - membership-revision cohort cache;
  - bounded mesh/shape compatibility cache;
  - per-visible-rig animation compatibility result;
  - route-lifetime registry and scheduler state.
- Every static cache used by a reloadable scene exposes `clear_cache()` for probes and editor iteration.

## Rendering and object budgets

The first optimization target is update frequency and allocation, followed by donor-node removal only where visually proven. Corpse fragments, blood emitters, dropped weapons, projectiles, unique materials, and shadows all have explicit route-level budgets. The Forge must select the intended asset LOD instead of defaulting to LOD0, and representative rendered captures are required before claiming GPU/render gains.

## Progressive integration order

1. Lock baseline data and reproduce current regressions.
2. Correct tests that violate the documented one-frame cache lifetime.
3. Add anatomy invariants, then fix lethal sever finalization.
4. Add the shared navigation component; use formation-local hoplites and LARGE_BODY giants while retaining direct steering for the remaining audited roster. Terrestrial non-giants auto-select NAVMESH_GROUND when their route exposes a compatible `NavigationRegion3D`, with explicit override still available.
5. Stabilize cohort identity, vacancy replacement, degraded advance and fair leases.
6. Make AI participation atomic across every route.
7. Apply real animation sampling LOD and bounded corpse/gore/drop policies.
8. Migrate rigs from lowest-risk compatible families to the largest donor stacks, retaining before/after visual proof.
9. Run the 22-ID functional, visual, anatomy, navigation, and performance matrix.

Each step must be independently reversible and must leave the unique factory route intact.

## Required verification layers

- Unit-style probes for navigation intent, stuck/repath timing, lease expiry/fairness, lethal sever and cache invalidation.
- Scenario probes for obstacles, narrow corridors, high ground, target death, formation vacancy and mass battle.
- Per-archetype matrix for spawn, rig, movement, attacks, hit zones, sever/death and cleanup.
- Rendered action captures for locomotion, attack, hit, block, death and severing where supported.
- Separate-process performance runs at 1, 5, 15, 28, 36 and 56 units, plus rendered Forge/Lab captures.
