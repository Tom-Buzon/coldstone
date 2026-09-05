# Enemy action FSM — transition and performance design

Updated: 2026-08-25

## Scope

This FSM is deliberately narrower than `ai_state`. It owns only the execution priority already present in `_physics_process()`:

`guard break → recovery when no attack is pending → attack wind-up → eligible parry counter → tactical`.

It does not own movement, tactical labels/goals, animation, health, targeting, formation work, or attack delivery. `athenian_enemy.gd` remains the sole motion owner and `ai_state` remains the compatibility diagnostic facade.

## Mutation inventory

| Concern | Start/change points | Existing deadline/consumption point | Fidelity constraint |
|---|---|---|---|
| Guard break | spiral smash; physical shield depletion; defended anatomy hit depletion | `guard_break_timer` crosses zero in `_update_defense()` | Absolute priority; recovery still counts down underneath it |
| Recovery | invalid pending attack; resolved attack; spiral stagger; guard break; injury cancellation | `ai_attack_recovery_timer` crosses zero before priority routing | Applies only when `ai_attack_pending == false` |
| Wind-up | `_begin_ai_attack()`; cancelled by invalid attack, stagger, guard break, phase, death or disabling injury | wind-up crosses zero and calls `_resolve_ai_attack()` | Pending wind-up outranks simultaneous recovery; guard break freezes wind-up |
| Parry counter | successful parry contact | consumed after defense/guard gates open | Invalid/out-of-range counter is consumed and falls through to tactical in the same tick without a false parry state |
| Tactical | cache invalidation from patrol/training/retaliation plus scheduled think refresh | sampled by the existing `ai_think_timer` | Cached separation still drives spacing during guard/recovery; this is not converted to an event-only scheduler |

No runtime script outside the combatant writes these action fields. Characterization probes do write them directly and must explicitly synchronize any future authoritative state during tests.

## Progressive design

### Current status — no runtime FSM

Pilot A was implemented only as an observational scalar latch and passed the targeted gameplay/source/object gates after death lifecycle observation was corrected. Its first authoritative performance scenario was nevertheless inconclusive: nine alternating A/B pairs met the median limits but failed both predeclared ratio-IQR limits. Per D-011, the candidate was rejected and fully rolled back to exact legacy controller SHA-256 `b64fe3138c9754a2ddc72a412106ec3f9ff925937ff4c6704610ecce61b37d9b` at the gate. Later user-owned patrol edits and D-013 `_exit_tree()` claim cleanup are separate, non-action-path changes. No enum, latch, signal, component or action FSM is authoritative at runtime.

The design below remains a future reference, not an implementation status. Any later attempt starts from the legacy controller and must establish a quieter or more discriminating gate before runtime authority changes.

### Pilot A — observational branch latch

- Add one enum field directly to the combatant; no per-enemy `Node`, `Resource`, `RefCounted`, `Callable`, state dictionary, or string.
- Keep the legacy if-chain and every return in place.
- Latch the enum only at the branch that actually wins. Stable ticks perform at most one enum comparison and no GDScript method call or signal emission.
- Latch parry only after target/range/capability validation. Invalid parry goes directly to tactical.
- Record exact transition traces in the action-state probe. The enum is observational and cannot yet influence gameplay.

This was intended to prove complete state observation with the smallest possible behavior surface. The measured Pilot A was rejected under the performance gate, so the bullet list describes a candidate pattern, not code currently present in the controller.

### Pilot B — dirty reconciliation

- Centralize all discrete writes behind semantic operations and mark an integer reason mask.
- Reconcile only after a discrete mutation or a timer crossing zero; do not mark dirty for ordinary timer decrements.
- Keep temporal progression inline in the existing physics callback.
- Only after every writer is covered may a `match` on the enum replace the priority if-chain.

### Final action API

Atomically own operations such as guard-break entry, attack begin/cancel/resolve, parry queue/consume, injury suspension and death. This step is intentionally deferred until Pilots A and B prove no stale state and no regression.

## Functional gate

- Exact transition tick at `< delta`, `== delta`, and `> delta` boundaries.
- Guard break over simultaneous recovery and pending wind-up.
- Pending wind-up over recovery.
- Parry blocked by defense, valid in range, invalid out of range with same-tick tactical fallthrough.
- Attack cancellation for invalid capability, phase transition, sever/disarm and death.
- No duplicate transitions on stable ticks and no recursive transition loop.
- No change to attack signals, damage/projectiles, permission release, timers, movement, animation, `ai_state`, or cached tactical work.

## Performance gate

`enemy_action_cpu_benchmark.gd` places a begin marker at physics priority `-1000` and an end marker at `+1000`. Enemy callbacks retain priority `0`. Two `Time.get_ticks_usec()` reads bracket elapsed wall time in that callback-priority region; samples are written into a preallocated `PackedInt64Array`. This avoids presenting paced 60 Hz tick intervals as callback work, but it is not thread CPU time: OS preemption and stalls remain in every sample. The region contains the complete enemy callbacks, and in realistic/mixed scenarios also the crowd director at priority `40`; it cannot attribute cost to the FSM alone.

Run each scenario in a fresh process and alternate A/B order. Initial scenarios are:

- `steady_clean`: cached inert tactical goal, no transition event and no crowd director;
- `realistic_active`: normal active swordsman crowd;
- `mixed_roles`: swordsman, guardian, spearman, archer and captain cycle.

Before authoritative integration, add deterministic deadline and event-burst drivers through the semantic API. Require:

- no new FSM object per enemy and no object-count growth during the steady sampling window; auxiliary nodes and enemies must all fail their `WeakRef` checks after teardown;
- a separate source guard over the candidate fast-path diff must prove no `.new()`, `Callable`, dynamic `.call()`, group/node lookup, dictionary/array creation, string construction, or signal emission on a stable tick; the elapsed-region harness does not prove allocation attribution;
- nine fresh A/B pairs per scenario, alternating `AB` and `BA`, using the exact controller and measurement-source SHA-256 values plus command recorded in JSON;
- compute the B/A ratio per pair for p50 and p95, then report all nine ratios, their median and nearest-rank Q1/Q3/IQR (matching the harness `_percentile()` convention); accept only when median p50 is at most `1.03`, median p95 at most `1.05`, p50-ratio IQR at most `0.03`, and p95-ratio IQR at most `0.05`;
- any functional divergence, object growth, forbidden source construct, threshold breach, or noisier ratio distribution is an inconclusive/failed gate and rejects integration.

The first three unpaired runs per scenario exposed useful noise characteristics but are instrumentation history, not an authoritative before baseline. Authoritative A/B evidence starts only with version 2 and the paired rule above.

The existing v2 12/56 benchmark remains the spawn, structural teardown and paced-diagnostic gate. Both harnesses are required because they measure different contracts.
