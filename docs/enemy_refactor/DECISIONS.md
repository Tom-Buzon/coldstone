# Enemy refactor decision log

## D-001 — Preserve before consolidating

- Date: 2026-08-25
- Status: accepted by task constraints.
- Decision: use characterization-first, incremental extraction; do not mass-rewrite `athenian_enemy.gd`.
- Reason: the primary invariant is absence of gameplay regression.

## D-002 — Canonical ownership boundaries remain provisional during inventory

- Date: 2026-08-25
- Status: provisional.
- Decision: validate entity root, typed archetype data, explicit FSM, shared perception/targeting, single motion owner, common combat/defense/animation/health interfaces, shared tactical coordination, and one factory/registry against existing contracts before implementing them.
- Reason: architecture must absorb real behavior rather than force existing archetypes into an invented abstraction.

## D-003 — User worktree changes are out of scope

- Date: 2026-08-25
- Status: accepted.
- Decision: preserve current modifications in `README_WORLD_EDITOR.md`, `assets/environment/stylized_nature/README.md`, `scripts/world_editor/world_editor_help.gd`, `scripts/world_editor/world_terrain_foliage.gd`, and `tools/world_terrain_probe.gd`; do not touch them during this refactor unless a future proven dependency requires explicit coordination.
- Reason: these changes predate or appeared independently of the refactor and belong to the user.

## D-004 — First migration slice is Battle 01 factory routing

- Date: 2026-08-25
- Status: implemented and validated.
- Decision: characterize and migrate the two direct constructors in `battle_01.gd`; Battles 02 and 03 inherit the same helpers and will thereby share the factory without touching AI behavior.
- Reason: it removes the only active runtime factory bypass while keeping the existing combatant root and behavior intact.
- Required compatibility: hostile spawns retain player targeting and optional forced `is_miniboss`; Spartan spawns retain `battle_player = player` with no initial `ai_player`, names, formation index, mass mode, groups, and signal wiring.
- Evidence: dedicated legacy/factory spawn probe, five targeted probes, narrative and wave probes, three battle startups, root diff inspection, and independent review all passed.

## D-005 — Spawn requests are typed and ephemeral

- Date: 2026-08-25
- Status: implemented and validated.
- Decision: `HopliteEnemySpawnRequest` is a `RefCounted` runtime value carrying typed construction inputs and explicit override-presence flags. `HopliteEnemyFactory.spawn_request()` is the sole construction point; the existing dictionary `spawn()` method is retained only as a compatibility adapter.
- Reason: spawn context contains live `Node3D` references and is not authored, shared configuration. A `Resource` would imply serialization/Inspector ownership and could accidentally retain scene nodes; Resources remain reserved for immutable authored archetype data.
- Required compatibility: an absent target override inherits `target`, while an explicitly supplied `null` remains `null`; explicit names (including empty names), battle-player overrides, package overrides, and troop promotion keep legacy behavior; profile-ranked minibosses and bosses cannot be demoted by a false override during `_ready()`.
- Evidence: legacy baseline and typed-adapter option probes, Battle helper probe, five behavior probes, narrative and wave probes, three battle startups, and the factory route guard pass on Godot 4.7.

## D-006 — Typed archetype data is initially a derived, non-shared view

- Date: 2026-08-25
- Status: implemented pilot and validated.
- Decision: `HopliteEnemyArchetypeData` exposes typed core identity/combat/procedural fields and a deep-copied legacy snapshot. `HopliteEnemyArchetypes.profile()` remains the sole authored source during migration; the factory is the first consumer of typed rank/package data.
- Reason: moving all profile keys and all consumers in one rewrite would violate the characterization-first constraint. A derived view permits one field group and consumer at a time without duplicating authored values.
- Safety: configuration is one-shot; views are not cached or shared because GDScript privacy is conventional and external code could still mutate underscore-prefixed backing fields. Cache only after the representation is safely shareable or callers receive isolated values.
- Removal condition: delete `legacy_profile()` and dictionary `profile()` only when controller, campaign, Forge and tools use typed fields and every archetype/alias/save path is covered.
- Evidence: exact 22-ID/order check, uniqueness, field parity, alias, unknown fallback, package prefixes, top-level and nested copy isolation, roster, factory, Battle and combat probes all pass; independent review verdict PASS.

## D-007 — Performance claims use a reproducible foundation baseline

- Date: 2026-08-25
- Status: implemented.
- Decision: use `enemy_performance_benchmark.gd` v2 with deterministic seed, canonical typed factory spawns, 12/56 idle/active scenarios, 120 warm-up and 120 sampled physics ticks. Run each scenario in a fresh process three times to avoid cold/warm cache contamination and preserve raw JSON logs.
- Reason: the historical startup JSON lacked a command and repetitions and cannot support before/after optimization claims.
- Limitation: this baseline was introduced after the first two foundation slices, so it is the comparison point for future work; no retrospective improvement claim is made. Headless engine process/FPS monitors are slow-refresh diagnostic snapshots only. Physics-tick wall intervals are paced and detect lateness, not CPU headroom. WeakRef/group teardown is structural evidence, not a complete leak proof.

## D-008 — Reject the per-tick action-FSM resolver prototype

- Date: 2026-08-25
- Status: rejected and fully rolled back.
- Decision: keep the new action-state characterization probe, but remove the runtime `EnemyActionStateMachine` prototype and restore `athenian_enemy.gd` byte-for-diff to its prior logic.
- Reason: the prototype preserved gameplay and passed independent review after a parry-fallthrough fix, but introduced a GDScript resolver call in every active enemy physics tick (and initially one `RefCounted` per enemy). Later active/56 tick-interval samples were elevated; rollback samples proved the environment was also noisy, so the measurements did not establish causality. The anti-regression gate requires positive evidence of no material regression, not merely absence of a proven cause.
- Follow-up constraint: the next FSM design must update state from existing mutation/transition points or a dirty flag, avoid per-tick dynamic dispatch, keep `ai_state` as the compatibility diagnostic label, and be benchmarked in an isolated A/B prototype before touching the controller.
- Evidence: action-state probe covers priority, `recovery + pending`, defense-blocked parry and invalid-parry tactical fallthrough; controller diff is empty after rollback; `enemy_combat`, crowd, archer, phalanx and Battle spawn probes pass.

## D-009 — Migrate clean laboratory and procedural consumers to typed requests

- Date: 2026-08-25
- Status: implemented and validated.
- Decision: replace dictionary option maps in `main.gd` and `procedural_wave_director.gd` with explicit `HopliteEnemySpawnRequest` values while preserving the dictionary adapter for Forge and compatibility probes.
- Reason: these callers were clean, bounded consumers of the already validated request contract. `world_runtime.gd` is deliberately excluded because it is concurrently user-modified; it still routes through the sole factory construction point.
- Required compatibility: configuration stays pre-`add_child`; lab commander/member/package/name semantics remain identical; procedural RNG call order, formation/jitter position, targets, AI/mass/guard/name, groups, metadata, active registry, and rank signals remain identical.
- Evidence: laboratory startup and 56-unit/21-shield probe PASS; real procedural soldier/miniboss/boss probe PASS; route, roster, typed archetype and staged campaign probes PASS; three independent reviews returned PASS.

## D-010 — Repair the procedural elite sigil alpha tween

- Date: 2026-08-25
- Status: implemented and validated.
- Decision: tween `StandardMaterial3D.albedo_color:a` instead of nonexistent `MeshInstance3D.modulate:a` during miniboss and boss entrances.
- Reason: the new real-spawn probe exposed a Godot runtime error in both elite branches. The intended fade belongs to the transparent material, while scale and callback timing remain unchanged.
- Evidence: the same ordinary/miniboss/boss probe advances through the complete tween, verifies sigil cleanup and AI/physics restoration, then proves enemy teardown with `WeakRef`; it passes with no tween-property error and only the known Windows certificate-store warning.

## D-011 — Reject observational action-latch Pilot A after the paired gate

- Date: 2026-08-25
- Status: rejected and fully rolled back.
- Decision: retain the action-state mutation inventory, legacy characterization and callback-region harness, but remove Pilot A's observational enum/latches/signals and its source probe. The legacy controller is authoritative; no action FSM currently runs in `HopliteAthenianEnemy`.
- Functional evidence: the candidate did not control legacy flow and passed action priority, combat, crowd, archer, phalanx, Battle spawn and route probes after an independent review found and prompted correction of stale death observation.
- Performance evidence: nine fresh `steady_clean` A/B pairs alternated `AB`/`BA` with exact controller hashes A `b64fe3138c9754a2ddc72a412106ec3f9ff925937ff4c6704610ecce61b37d9b` and B `4c5eaad93b85a4e8c706ead6de164d9f1cbd7feb796bbe1f67d1d3c662976bb8`. Median B/A ratios (`1.026878` p50, `1.046613` p95) met their limits, but ratio IQRs (`0.203399`, `0.162106`) failed limits (`0.03`, `0.05`). Object counts were stable and teardown passed in every run.
- Interpretation: the elapsed-region distribution is too noisy to establish non-regression or causality. Under the predeclared rule, inconclusive evidence rejects integration; it does not prove the latch itself caused a slowdown. Remaining scenarios were not run after the first required scenario failed the dispersion gate.
- Rollback evidence at the D-011 gate: `git diff --exit-code -- scripts/enemy/athenian_enemy.gd` succeeded and the restored controller SHA-256 was `b64fe3138c9754a2ddc72a412106ec3f9ff925937ff4c6704610ecce61b37d9b`; the retained legacy action characterization passed. Later user-owned patrol edits and D-013 lifecycle cleanup are separate from the rejected FSM.

## D-012 — Characterize faction/targeting before introducing a registry

- Date: 2026-08-25
- Status: characterization implemented; runtime registry not yet implemented.
- Decision: protect current faction groups, target override semantics, player/retaliation/opponent priority, claim scoring/release, dead-target exclusion and friendly-fire rules with `enemy_faction_targeting_probe.gd`. Define a scene-scoped event-maintained registry boundary separately; do not add registry work to the enemy physics loop.
- Reason: SceneTree groups currently serve several different meanings, while the procedural `active_enemies` dictionary is an encounter ledger with progression semantics. Replacing either without separating registration, liveness and encounter ownership would create silent regressions.
- Evidence: the new probe passes through the canonical typed factory with real Athenian/Spartan instances, explicit-null and distinct non-null target overrides, AI-disabled group semantics, exact claim increments/decrements, friendly/opposing hits, death/hold release and WeakRef teardown. `TARGETING_REGISTRY_DESIGN.md` records consumers, boundaries and open lifecycle risks.

## D-013 — Release tactical claims when a living combatant exits the tree

- Date: 2026-08-25
- Status: implemented and validated.
- Decision: add an `_exit_tree()` lifecycle hook that uses the existing `_release_attack_permission()` and `_set_combat_target(null)` paths. It performs no stable-tick work and does not introduce a registry or FSM.
- Reason: the red faction-targeting lifecycle test proved that procedural/world cleanup can `queue_free()` a living combatant without `_die()`, leaving `hoplite_ai_claims` stale on a surviving target. Death and hold-position already released the same ownership correctly.
- Compatibility: cleanup is idempotent after death/hold because the existing release paths tolerate no active permission/target. SceneTree faction groups and corpse lifetime semantics are unchanged.
- Evidence: `enemy_faction_targeting_probe_live_free_red.log` fails only on the leaked live-free claim before the hook; `enemy_faction_targeting_probe_final.log` passes afterward, including attack-permission removal from the crowd director, distinct target overrides, AI-disabled groups, opposing/friendly hits and WeakRef teardown. Action, crowd, combat, procedural real-spawn and factory-route probes also pass; independent review verdict PASS.
- Worktree boundary: concurrent patrol-resume changes in `athenian_enemy.gd` are user-owned and were preserved; D-013 contributes only the `_exit_tree()` callback.

## D-014 — Registry begins as a consumer-free scene service

- Date: 2026-08-25
- Status: standalone pilot implemented; gameplay integration pending independent gate.
- Decision: introduce `HopliteCombatantRegistry` as an ordinary scene-scoped `Node`, not an Autoload. It is event-maintained, preserves registration order, stores non-owning ObjectDB instance IDs, distinguishes registered/living/AI-enabled views and does not poll.
- Reason: a lightweight isolated service can prove lifecycle and query semantics without changing any enemy, factory, crowd, campaign, battle or Forge behavior. Non-owning ObjectDB instance IDs prevent the registry from becoming an accidental combatant owner.
- Boundary: the pilot does not own target claims, permissions, movement, encounter ledgers or SceneTree compatibility groups. It currently has no gameplay consumer.
- Evidence: `enemy_combatant_registry_probe.gd` passes contract rejection, idempotence, ordered snapshots, faction/AI filters, death-vs-tree-exit semantics, unregister/re-register, signal counts and zero retained references.

## D-015 — Factory registration is explicit typed injection

- Date: 2026-08-25
- Status: optional factory integration implemented; no production scene/crowd/perception consumer.
- Decision: add an optional typed `combatant_registry` reference to `HopliteEnemySpawnRequest`. `spawn_request()` validates that the service is already inside the same SceneTree before construction, calls `parent.add_child(enemy)` first, then registers the ready combatant. No group lookup or Autoload is used.
- Compatibility: requests with no registry follow the previous path exactly. The dictionary adapter does not gain an implicit registry option. If an explicitly injected registry cannot accept the ready combatant, the factory queues that combatant for deletion and returns null.
- Reason: explicit injection makes scene ownership unambiguous and prevents nested scenes or multiple registry groups from silently choosing the wrong service.
- Evidence: `enemy_factory_registry_probe.gd` passes real Athenian/Spartan order, faction/living/AI filters, untracked control, invalid out-of-tree rejection before construction, death retention, live/dead tree exit and weak teardown. Standalone registry, factory options, route, Battle spawn and faction-targeting probes also pass.

## D-016 — Do not inject the registry into a production scene yet

- Date: 2026-08-25
- Status: production integration rejected by the declared performance gate; opt-in factory API retained.
- Decision: keep every current production spawn request `combatant_registry = null`. Retain the standalone service, explicit factory path and probes as a gated foundation, but do not add it to `combat_lab`, Battles, procedural campaign, crowd or perception.
- Evidence: Pilot 1 exploratory pairs exposed `WeakRef` object growth and median spawn ratio `1.065170`. Pilot 2 removed per-unit objects and passed median/object/registration/teardown gates, but its predeclared nine-pair acceptance IQR was `0.070460` against `0.05`; therefore timing evidence is inconclusive.
- Interpretation: median `0.997616` is not evidence of an optimization because the distribution is too broad. Rejecting scene injection follows the written gate and does not imply the registry caused a regression.
- Follow-up: use a more discriminating isolated registration-cost design or a quieter environment before reopening production injection. Do not weaken the recorded gate after seeing the result.

## D-017 — Isolated registry operations reopen one controlled consumer

- Date: 2026-08-25
- Status: isolated gate PASS; global authority still forbidden.
- Decision: accept the registry's isolated registration cost as bounded enough to migrate exactly one controlled scene, followed by its full functional/structural suite and independent review. This does not overturn D-016's refusal to infer causality from noisy full-spawn ratios and does not authorize Battles, procedural campaign, crowd, perception or global discovery.
- Evidence: 15 fresh processes, odd-AB/even-BA, 100 analyzed cold samples each after five sacrifices. All logs share benchmark SHA-256 `6ee7c2b669bd69dbcd5f6c7e3445579d5ca44ea41e18a0435add0b8abe9f0874` and registry SHA-256 `40a2337f5a9b3d5c7c503751e509ead53755042a3b56ef49dc899ded15ad8016`. Cold register-56 net p50 Q1/median/Q3 is `318/324/337 us` (IQR `19 us`); median p95 is `380 us`. Cold unregister raw p95 median is `48 us`; warm register/unregister raw p95 medians are `152/41 us`. Every structure, cache, order, callback, object-window and teardown assertion passes. Independent raw-sample recalculation verdict PASS.
- Boundary: absolute costs are used; near-zero ratios are forbidden. The unregister measurement is not presented as complete SceneTree teardown cost, and process-global Object count remains diagnostic.

## D-018 — `combat_lab` is the first and only controlled scene consumer

- Date: 2026-08-25
- Status: implemented, validated and independently reviewed.
- Decision: create one scene-owned `TrainingCombatantRegistry` before the laboratory spawns and explicitly inject it into every `main.gd` request. The registry remains bookkeeping-only: enemy groups, crowd permissions, targeting, encounter ledgers and all gameplay discovery remain authoritative in their existing owners.
- Evidence: the strengthened laboratory probe first failed only because zero registry existed, then passed with exact parity between the complete 99-enemy group and registry snapshot, preserved 56-unit/21-shield annex behavior, and released the registry/group on scene teardown. Factory, registry, options, route, faction, Battle, procedural, atmosphere, global-settings and full startup checks pass. Independent review reports no P0–P3 finding.
- Boundary: no Battle, procedural, Forge, crowd, perception or enemy controller requests a registry yet; no implicit group lookup is allowed. The known `Ripped Crown Run.mp3` shutdown objects remain separate audio-lifecycle debt.

## D-019 — Dynamic `ai_enabled` is not equivalent to `combatant_ai` membership

- Date: 2026-08-25
- Status: superseded by the atomic participation boundary.
- Decision: all runtime enable/disable transitions use `set_ai_participation()`, which changes AI groups, registry liveness, crowd-grid membership, target, navigation and lease together. Direct field mutation after `_ready()` is unsupported.
- Evidence: `enemy_registry_crowd_parity_probe` now requires dynamic group/registry parity through the setter, including teardown and grid invalidation.
- Consequence: registry replacement of targeting remains out of scope until player union, priority/distance/claim/tie and generic-node parity are independently proven.
