# Enemy faction, targeting and registry design

Updated: 2026-08-25

## Characterized runtime contract

`enemy_faction_targeting_probe.gd` protects the current behavior without adding a runtime service:

- faction is configured before `_ready()`; Athenians enter `enemy`, `athenian`, `combatant` and `damageable`, while Spartans enter `ally`, `spartan_ally`, `combatant` and `damageable`; only actors whose AI is enabled at `_ready()` also enter `combatant_ai` plus `enemy_ai` or `ally_ai`;
- a target with no explicit overrides initializes both `ai_player` and stable `battle_player`; an explicit-null AI override remains null, and distinct non-null AI/battle overrides each win over the default target;
- a hostile Athenian prefers an active retaliation target, then a valid local human within aggro, then scans `spartan_ally`; a Spartan scans `enemy`;
- candidates are filtered for validity/death and aggro distance, then scored by flat distance, `hoplite_ai_claims` penalty and current-target stability bonus;
- changing target releases crowd engagement/attack permission and decrements the old target claim before incrementing the new target claim;
- same-faction `receive_ai_hit()` is rejected, player hits on Spartans are rejected by `can_receive_hit_from()`, and retaliation ignores friendly sources;
- death and hold-position call `_set_combat_target(null)`; D-013 adds the same ownership cleanup on live tree exit, including crowd attack permission and target claim release.

Projectile collision masks are also faction-specific: Spartans target world/player-enemy layer `4`, Athenians target world/player layer `2`. This remains covered by existing combat/projectile probes rather than the new selection probe.

## Existing discovery and ownership

There is no single live-combatant registry today:

| Need | Current source | Lifetime semantics |
|---|---|---|
| General combatant discovery | SceneTree `combatant` group | Includes living and dead nodes until freed |
| AI/crowd discovery | `combatant_ai`, `enemy_ai`, `ally_ai`, faction and `phalanx_unit` groups | Membership follows `set_ai_participation()` dynamically and is removed atomically on death |
| Per-enemy opponents | `enemy` or `spartan_ally` group scan | Recomputed only when the legacy target refresh runs |
| Engagement cleanup | crowd director scans `combatant_ai` and `player` | Builds a living-ID snapshot and removes stale slots |
| Procedural encounter membership | `procedural_wave_director.active_enemies` | Explicit spawn/death/tree-exit ownership; encounter-local, not global |
| Forge enemy groups | `world_runtime.enemies_by_group` | Forge/save-local grouping; liveness filtered when read; user-modified runtime remains out of the current migration slice |
| Battle counters and cleanup | faction groups plus `died` signals | Scene-specific objectives and corpse policies |

The campaign `active_enemies` dictionary is an encounter ledger and must not be silently replaced by a global registry: it encodes wave completion, boss identity, corpse delay and zone cleanup.

## Minimal canonical boundary

The first registry candidate should be a scene-scoped, event-maintained service outside `_physics_process()`. It should:

1. index combatants by instance ID and faction after the factory has configured and added them;
2. distinguish `registered`, `living`, and `AI-enabled` membership instead of treating SceneTree group presence as liveness;
3. remove entries on `tree_exiting` and update liveness from the existing `died` signal;
4. return typed snapshots for faction/opponent queries, with no ownership of nodes and no polling loop;
5. preserve all existing groups and campaign/battle ledgers as compatibility facades during migration;
6. make registration idempotent so scene-authored or probe-only construction can be adapted without duplicates.

The targeting boundary should consume candidate snapshots but retain the existing decision order and claim accounting. It must not own movement, attack permission, crowd engagement, retaliation timers or `ai_state`. Candidate queries may run only on the existing target/think cadence; no registry lookup, allocation or signal emission is permitted on an otherwise stable physics tick.

## Standalone registry pilot

`HopliteCombatantRegistry` now exists as a scene Node. It stores only non-owning ObjectDB instance IDs, preserves registration order, rejects duplicate/invalid registrations, tracks liveness from `died`, removes on `tree_exiting`, and exposes detached snapshots filtered by faction, liveness and AI-enabled state. Contract introspection is cached once per script. It has no `_process()`/`_physics_process()`, no autoload, and no crowd/enemy/gameplay query consumer. D-018 gives only `combat_lab` a scene-owned bookkeeping instance.

`enemy_combatant_registry_probe.gd` validates the service with synthetic combatants: contract/type/signal rejection, idempotence, re-registration ordering, independent snapshots, dynamic faction/AI filters, death callback reconnection, explicit liveness refresh, death remaining registered but not living, tree-exit signals and zero retained strong references.

The factory gate is also complete but remains opt-in: a typed spawn request may inject one registry already inside the same SceneTree. The factory validates it before construction and registers only after `add_child()`/`_ready()`. It never discovers a registry through the global group. Only `main.gd` laboratory requests inject one; other requests inject nothing. A refusing registry removes the ready combatant from the tree/groups immediately, then frees it deferred. `enemy_factory_registry_probe.gd` protects this path with real combatants.

D-016 rejected production-scene injection from the noisy full-spawn evidence. D-017 later passed a stricter isolated-operation gate and D-018 migrated only `combat_lab`; this does not make the registry authoritative discovery. Battle, procedural, Forge, crowd and perception remain registry-null.

## Incremental migration gates

1. **Complete:** standalone registry plus unit probe with synthetic combatants; no gameplay query consumer.
2. **Complete:** optional factory injection plus real-instance lifecycle and invalid-service probes.
3. **Complete for one scene:** isolated-operation gate PASS and exact 99-enemy `combat_lab` parity/teardown PASS.
4. **Pending independent contract slice:** characterize one read-only crowd/perception result-parity pilot before any authority change.
5. **Blocked behind step 4:** retire a repeated group scan only after identical target/claim results and scene-specific performance evidence.

### Predeclared read-only crowd parity characterization

Before any crowd/perception query can consume the registry, a real-factory probe must establish two separate contracts:

- immediately after `_ready()`, living AI-enabled registry snapshots must contain the same combatants as the `combatant_ai` group, while living `athenian`/`spartan` snapshots must match the `enemy`/`spartan_ally` faction groups;
- after runtime participation flips through `set_ai_participation()`, group and registry liveness/AI filters remain equivalent on the next invalidated crowd-grid tick. Direct mutation of the public field is unsupported because it bypasses the atomic boundary.

This parity does not by itself authorize replacing targeting/crowd scans: player union, priority, distance, claim and tie ordering remain distinct contracts.

The real-factory probe passes exactly this contract, including set and positional-order parity. Independent review confirms two additional boundaries: crowd cleanup unions `player` IDs and therefore cannot consume a combatant-only snapshot directly; targeting faction snapshots are candidate-source equivalent only when filtered by liveness but not AI, and do not yet prove player/retaliation precedence, distance/claim scoring, strict tie order, generic group-only nodes or cleanup ownership. See D-019.

## Open fidelity risks

- D-013 now protects living `queue_free()` release of both target claim and crowd attack permission. Future registry teardown must remain idempotent with that entity-owned cleanup rather than becoming a second claim owner.
- Generic non-`HopliteAthenianEnemy` attackers are classified by groups, while typed enemies are classified by `faction`; both paths must remain supported.
- Dead combatants remain in broad compatibility/faction groups where scene objectives need corpses, but leave AI/crowd groups atomically. A registry still exposes liveness separately.
- `battle_player` is a stable human reference while `ai_player` is the immediate combat target. Collapsing them would break Spartan behavior and threat/LOD references.
- `hoplite_ai_claims` is metadata on the target, shared by all attackers. Replacing it requires atomic release on target switch, death, hold-position and tree exit without changing tie-breaking.
- Candidate ties keep the first SceneTree-group result because comparison uses strict `<`; a registry must preserve insertion order or explicitly characterize a new deterministic order before it becomes a consumer.
- Spartan projectiles use collision mask `1 | 4`: a friendly body on layer `4` may absorb a projectile even though friendly damage is rejected. Preserve this physical behavior unless a separately approved combat change replaces it.
