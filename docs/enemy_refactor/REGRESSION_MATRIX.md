# Enemy refactor regression matrix

Updated: 2026-08-26

## Final authoritative gate

| Gate | Final evidence | Result |
|---|---|---|
| Canonical roster/factory | 22 IDs through the sole factory, typed profile cache and explicit alias | PASS 22/22 |
| Exact behavior per ID | far/close decision, every phase-I action, disarm interruption, target loss, sleep/wake, cleanup | PASS 22/22 |
| Declared phases | warlord, nathenian2, bronze_colossus, giant_veteran and nfull_armor transitions/patterns | PASS 5/5 |
| Anatomy/dismemberment | 12 runtime zones and 10 severable consequences per unit | PASS 22/22 |
| Animation variants | all seven direct-Mixamo pools, 20 variants and 240 cumulative mapped zones | PASS 7/7 families |
| Animation LOD | shared/native/direct sampling at 30/12/0 Hz plus immediate LOD0 wake | PASS |
| Navigation | direct, formation, LARGE_BODY recovery and real NavigationServer detour/retarget/arrival | PASS |
| Crowd/cohort/scheduler | 20 Hz grid, stable slots, degraded advance, FIFO leases, death/disable release | PASS |
| Lifecycle | projectiles, blood, limbs, equipment, corpses and registry/group teardown | PASS |
| Mixed stress | 22 families / 36 units, threshold 28, two cohorts, moving target, sleep/wake, sections/deaths | PASS |
| Rendered routes | individual thirteen-state PNGs plus actual Lab and Forge 22/22 captures with six distributed runtime states | PASS |
| Corpse mass TTL | 36 factory-spawned deaths, bounded corpse TTL, `36/36` WeakRefs released | PASS |
| Reload stability | 5 cycles × 36 active enemies; groups/WeakRefs return to zero, post-warm object span `0` | PASS |
| Procedural/Battle/Forge | typed spawn, atomic elite entrance target, Battle routes, WorldDocument runtime | PASS |
| Performance | exact structural matrix, callback region, render diagnostics; all cleanup true | PASS with documented timing limits |

The detailed table below is the earlier characterization ledger. Any “pending” wording in it is superseded by the final gate above and retained only for audit history.

| Area | Behaviors that must remain stable | Characterization/probe | Baseline (Godot 4.7.2) | Latest | Evidence/status |
|---|---|---|---|---|---|
| Archetypes and appearance | 22 IDs, alias, stats, packages, equipment | `enemy_roster_audit`; equipment/pose probes | PASS, 22 coherent | Same | Raw roster/equipment logs captured |
| Typed archetype adapter | Exact IDs/order, alias, unknown fallback, typed core values, package resolution, isolated legacy copy | `enemy_archetype_data_probe` | N/A | PASS, 22 views | Derived from the single normalized profile source; no authored duplication |
| Animation and reactions | Three presentation strategies, specialized openers, poses, hits/deaths | `enemy_animation_probe`, `pose_integrity_probe` | Historical PASS | PASS: 14 openers, 13 pose fixtures | Mechanical/clip sync, Mixamo/retarget strategies, giant packages and grounded standing heights characterized |
| Archer locomotion | Preserve height, climb, edge lock, delayed retreat | `archer_high_ground_probe` | PASS | Same | Raw log captured |
| Offense | Light/heavy/special/projectile, patterns and attack delivery | `enemy_combat_probe`, `combat_attack_probe` | Enemy combat PASS | PASS | Clip motion, aim assist, shield recoil/feedback and cinematic resolution pass current high-cost probe |
| Defense | Shield front/rear, parry, guard break, armor | `enemy_combat_probe` | PASS | Same | Raw log captured |
| Action-state priority | Guard break > recovery(non-pending) > wind-up > parry > tactical; blocked/invalid parry fallthrough | `enemy_action_state_probe` | PASS legacy | Same after two rejected prototype rollbacks | Legacy action control restored; later `_exit_tree()` claim cleanup is outside the physics/action path; no runtime FSM |
| Tactics | Engagement rings, reserves, attack budgets, phalanx intrusion/expulsion | `crowd_tactics_probe` | PASS | Same | Raw log captured |
| Phalanx equipment | Imported dory/aspis, attachments, shield hitbox | `phalanx_equipment_probe` | PASS | Same | Raw log captured |
| Bosses and giants | Patterns/phases, giant floor/head/crawl/wall-run | enemy combat + `giant_traversal_probe` + `wall_run_probe` | Patterns PASS | PASS current probes | Smooth torso, real head mesh, floor, crawl seam, wall-run classification and legless damage path pass |
| Factions/allies | Spartan groups, stable player ref, distinct/explicit-null targets, player/retaliation/opponent priority, claims, dead filtering, friendly fire | `enemy_faction_targeting_probe`; Battle spawn probe; Battles 01/02 | Legacy helper PASS | PASS with real factory instances | Groups, selection, claim increments/releases, death/hold/live-free cleanup, same-faction hits and player→Spartan filtering protected; full Battle 02 ally-survival automation still pending |
| Damage/anatomy/gore | Localized hit, sever, detached limbs, collision/body zones | enemy combat + pose + giant probes | Partial PASS | PASS for current enemy/giant paths | Giant leg-sever crawl anatomy resolves a zone and damage; broader per-zone detached-limb matrix remains pending |
| Spawning | Lab, Battles 01–03, procedural, Forge, probes | roster + spawn + option parity + route guard + narrative/procedural/lab probes | Battle direct bypass characterized | Typed request and compatibility adapter PASS | Battles, lab and procedural callers are typed; Forge remains a documented adapter consumer; every runtime construction reaches the sole factory construction point |
| Registry/factory pilot | Idempotent ordered registration, faction/living/AI filters, death retained until exit, weak teardown, explicit post-ready injection | `enemy_combatant_registry_probe`; `enemy_factory_registry_probe`; `enemy_registry_operation_benchmark`; shooting-range probe | N/A | PASS; `combat_lab` bookkeeping only | Synthetic/real factory gates, 15-process isolated cost gate and exact 99-enemy lab parity/teardown pass; crowd/perception are not wired |
| Registry/crowd parity | Spawn-time `combatant_ai` membership vs dynamic AI property; faction set/order | `enemy_registry_crowd_parity_probe` | Group semantics characterized | PASS with expected divergence | Blocks dynamic-AI registry filter in crowd; living faction snapshots only establish candidate-source parity, not targeting authority |
| Procedural deployment | Soldier/miniboss/boss creation, target/options, legion metadata/groups, rank signals, active registry, elite entrance | `procedural_enemy_spawn_probe`; `procedural_campaign_probe` | Previous planning probe did not reach `_spawn_spec()` | PASS with real instances | Also fixed invalid 3D sigil alpha tween exposed by the new branch coverage |
| Laboratory roster | Eight seven-unit zones, physical shield hitboxes only on shield families | `shooting_range_shield_probe`; scene startup | Historical probe expected 14 despite three shield families | PASS: 56 units, 21 shields | `nathenian1`, `ncenturion`, and `ngeneral` contribute seven shields each |
| External systems | Quests, counters, phase/progression signals and public facade | narrative/wave/procedural probes + API inventory | API inventoried; runtime tier pending | Procedural spawn/signals PASS; remaining partial | Battle 02 full automation gap remains |
| Performance | Frame/physics, memory, objects, teardown, later draw calls/LOD | `enemy_performance_benchmark` + future rendered route | Existing startup sample non-reproducible | Foundation PASS | Three 12/56 idle/active runs; rendered metrics still pending |

## Baseline raw logs

- `.tmp_tools/enemy_refactor/enemy_roster_audit_baseline.log`
- `.tmp_tools/enemy_refactor/crowd_tactics_probe_baseline.log`
- `.tmp_tools/enemy_refactor/archer_high_ground_probe_baseline.log`
- `.tmp_tools/enemy_refactor/phalanx_equipment_probe_baseline.log`
- `.tmp_tools/enemy_refactor/enemy_combat_probe_baseline.log`
- `.tmp_tools/enemy_refactor/battle_enemy_spawn_probe_legacy_baseline.log`
- `.tmp_tools/enemy_refactor/battle_enemy_spawn_probe_factory_final.log`
- `.tmp_tools/enemy_refactor/narrative_battle_post_factory.log`
- `.tmp_tools/enemy_refactor/last_flame_wave_post_factory.log`
- `.tmp_tools/enemy_refactor/enemy_factory_options_legacy_baseline.log`
- `.tmp_tools/enemy_refactor/enemy_factory_options_typed_request.log`
- `.tmp_tools/enemy_refactor/battle_enemy_spawn_typed_request.log`
- `.tmp_tools/enemy_refactor/enemy_factory_route_probe.log`
- `.tmp_tools/enemy_refactor/enemy_roster_audit_typed_request.log`
- `.tmp_tools/enemy_refactor/crowd_tactics_probe_typed_request.log`
- `.tmp_tools/enemy_refactor/archer_high_ground_probe_typed_request.log`
- `.tmp_tools/enemy_refactor/phalanx_equipment_probe_typed_request.log`
- `.tmp_tools/enemy_refactor/enemy_combat_probe_typed_request.log`
- `.tmp_tools/enemy_refactor/enemy_archetype_data_probe_final.log`
- `.tmp_tools/enemy_refactor/enemy_action_state_legacy_baseline.log`
- `.tmp_tools/enemy_refactor/enemy_action_state_characterization_final.log`
- `.tmp_tools/enemy_refactor/enemy_performance_v2_idle_12_run{1,2,3}.log`
- `.tmp_tools/enemy_refactor/enemy_performance_v2_idle_56_run{1,2,3}.log`
- `.tmp_tools/enemy_refactor/enemy_performance_v2_active_12_run{1,2,3}.log`
- `.tmp_tools/enemy_refactor/enemy_performance_v2_active_56_run{1,2,3}.log`
- `.tmp_tools/enemy_refactor/narrative_battle_probe_typed_request.log`
- `.tmp_tools/enemy_refactor/last_flame_wave_probe_typed_request.log`
- `.tmp_tools/enemy_refactor/procedural_enemy_spawn_probe.log`
- `.tmp_tools/enemy_refactor/shooting_range_shield_probe.log`
- `.tmp_tools/enemy_refactor/combat_lab_typed_spawn_startup.log`
- `.tmp_tools/enemy_refactor/enemy_factory_route_probe_after_consumers.log`
- `.tmp_tools/enemy_refactor/enemy_roster_after_consumers.log`
- `.tmp_tools/enemy_refactor/enemy_archetype_data_after_consumers.log`
- `.tmp_tools/enemy_refactor/procedural_campaign_typed_spawn.log`
- `.tmp_tools/enemy_refactor/enemy_factory_options_after_consumers.log`
- `.tmp_tools/enemy_refactor/enemy_action_cpu_before_steady_clean_56_run{1,2,3}.log`
- `.tmp_tools/enemy_refactor/enemy_action_cpu_before_realistic_active_56_run{1,2,3}.log`
- `.tmp_tools/enemy_refactor/enemy_action_cpu_before_mixed_roles_56_run{1,2,3}.log`
- `.tmp_tools/enemy_refactor/enemy_action_callback_region_v2_pair_steady_clean_56_pair{01..09}_{A,B}.log`
- `.tmp_tools/enemy_refactor/enemy_action_callback_region_v2_pilot_a_{steady_clean,realistic_active,mixed_roles}_56_smoke.log`
- `.tmp_tools/enemy_refactor/enemy_action_state_pilot_a.log`
- `.tmp_tools/enemy_refactor/enemy_{combat,factory_route}_pilot_a.log`
- `.tmp_tools/enemy_refactor/{crowd_tactics,archer_high_ground,phalanx_equipment,battle_enemy_spawn}_pilot_a.log`
- `.tmp_tools/enemy_refactor/enemy_faction_targeting_probe_live_free_red.log`
- `.tmp_tools/enemy_refactor/enemy_faction_targeting_probe_final.log`
- `.tmp_tools/enemy_refactor/{enemy_action_state,crowd_tactics,enemy_combat,procedural_enemy_spawn,enemy_factory_route}_after_claim_cleanup.log`
- `.tmp_tools/enemy_refactor/enemy_combatant_registry_probe.log`
- `.tmp_tools/enemy_refactor/enemy_combatant_registry_probe_final.log`
- `.tmp_tools/enemy_refactor/enemy_factory_registry_probe.log`
- `.tmp_tools/enemy_refactor/{enemy_factory_options,enemy_factory_route,battle_enemy_spawn,enemy_faction_targeting}_after_registry.log`
- `.tmp_tools/enemy_refactor/enemy_registry_spawn_v3_pair_{01..09}_{A,B}.log`
- `.tmp_tools/enemy_refactor/enemy_registry_spawn_v3_optimized_pair_{01..09}_{A,B}.log`
- `.tmp_tools/enemy_refactor/enemy_registry_operation_v1_run{01..15}.log`
- `.tmp_tools/enemy_refactor/combat_lab_registry_consumer_{red,green}.log`
- `.tmp_tools/enemy_refactor/lab_registry_{registry,factory_registry,factory_options,factory_route,faction_targeting,battle_spawn,procedural_spawn,atmosphere_panel,global_settings}.log`
- `.tmp_tools/enemy_refactor/combat_lab_registry_startup.log`
- `.tmp_tools/enemy_refactor/characterization_{enemy_animation,pose_integrity,giant_traversal,wall_run,combat_attack}.log`
- `.tmp_tools/enemy_refactor/enemy_registry_crowd_parity.log`
- `.tmp_tools/enemy_refactor/final_{registry,factory_registry,factory_options,factory_route,faction_targeting,action_state,battle_spawn,procedural_spawn}.log`
- `.tmp_tools/enemy_refactor/final_combat_lab_startup.log`

The repeated Windows root-certificate-store error is environment noise and did not affect probe exit codes. The final laboratory startup exits zero, but a separate `--verbose --quit-after 3` diagnostic identifies its process-shutdown warning as one playback object and one resource for `res://audio/track/Ripped Crown Run.mp3`; no enemy or registry object is named. This audio-lifecycle debt is outside the enemy slice and prevents claiming complete process-wide leak freedom. Thumbnail/capture probes and Forge probes touching the user-modified world tooling are excluded from this refactor baseline.

The earlier `enemy_performance_foundation_run{1,2,3}.log` files are version-1 instrumentation experiments, not regression baselines; see `PERFORMANCE.md` for the review findings and v2 measurement contract.

The `enemy_performance_action_state_*` files document a rejected FSM prototype and its rollback. Scheduler load varied across the later runs, so they do not prove causality; the prototype was rejected because the gate could not establish non-regression and it added avoidable hot-path dispatch/allocation risk.

The `enemy_action_callback_region_v2_pair_*` files document the later observational-latch Pilot A. Functional and structural gates passed, but the nine paired steady-run ratio distributions failed both declared IQR limits. This is recorded as inconclusive and rejected, not as proof of a candidate-caused slowdown; the controller was restored exactly and the legacy action characterization passes after rollback.
