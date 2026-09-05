# Enemy migration matrix — historique, non autoritaire

> Cette matrice conserve la photographie de migration. Les verdicts courants sont dans `ORCHESTRATION_LEDGER.md`, `REGRESSION_MATRIX.md` et les rapports unitaires; toute mention ancienne d'une preuve à six états est remplacée par les planches finales à treize états.

Updated: 2026-08-25

Status values: `discovered`, `characterized`, `pilot`, `migrated`, `validated`, `retired`, `blocked`.

## Archetypes

All rows currently share `HopliteAthenianEnemy`; the future canonical path means typed archetype data plus canonical components/strategies created by `HopliteEnemyFactory`.

| Archetype | Family/role | Existing data path | Primary runtime consumers | Status | Validation evidence |
|---|---|---|---|---|---|
| `swordsman` | legacy standard | dictionary profile | Battles 01/02 | characterized | roster + enemy combat baseline PASS |
| `guardian` | legacy shield standard | dictionary profile | Battles 01/02, Spartan allies | characterized | roster + enemy combat baseline PASS |
| `spearman` | legacy phalanx standard | dictionary profile | Battles 01/02, Spartan allies | characterized | roster + phalanx equipment baseline PASS |
| `flanker` | legacy mobile standard | dictionary profile | Battles 01/02 | characterized | roster baseline PASS |
| `brute` | legacy heavy standard | dictionary profile | Battles 01/02 | characterized | roster baseline PASS |
| `captain` | legacy miniboss | dictionary profile | Battles 01/02 | characterized | roster + enemy combat baseline PASS |
| `warlord` | legacy boss | dictionary profile | Battle 01 | characterized | roster + enemy combat baseline PASS |
| `boss_colossus` | legacy miniboss | dictionary profile | authored/Forge | characterized | roster baseline PASS |
| `boss_bronze` | legacy miniboss | dictionary profile | authored/Forge | characterized | roster baseline PASS |
| `nathenian1` | current infantry | dictionary profile | lab/narrative/procedural/Forge | characterized | roster baseline PASS |
| `nsbire1` | current light infantry | dictionary profile | lab/narrative/procedural/Forge | characterized | roster baseline PASS |
| `nsbire2` | archer | ranged profile/strategy in monolith | lab/narrative/procedural/Forge | characterized | roster + archer baseline PASS |
| `nathenian2` | line-breaker miniboss | dictionary profile | lab/narrative/Forge | characterized | roster + enemy combat baseline PASS |
| `nathenian2_soldier` | heavy infantry alias | normalized alias of `nathenian2` | narrative/Forge | characterized | roster baseline PASS; alias contract recorded |
| `bronze_colossus` | current miniboss | dictionary profile | lab/narrative/procedural/Forge | characterized | roster + enemy combat baseline PASS |
| `ncenturion` | current miniboss | dictionary profile | lab/narrative/procedural/Forge | characterized | roster + enemy combat baseline PASS |
| `ngeneral` | phalanx standard | formation profile/strategy | lab/narrative/Forge | characterized | roster + crowd + equipment baseline PASS |
| `ngeneral_veteran` | phalanx elite | formation profile/strategy | lab/narrative/procedural/Forge | characterized | roster + crowd + equipment baseline PASS |
| `giant_novice` | giant troop | giant profile/specialized monolith path | Forge/probes | characterized | roster baseline PASS; traversal baseline pending |
| `giant_standard` | giant elite | giant profile/specialized monolith path | Forge/probes | characterized | roster baseline PASS; traversal baseline pending |
| `giant_veteran` | giant elite | giant profile/specialized monolith path | Forge/probes | characterized | roster baseline PASS; traversal baseline pending |
| `nfull_armor` | current boss | phase/armor profile | lab/narrative/procedural/Forge | characterized | roster + enemy combat baseline PASS |

Spartan allies reuse the same archetype rows with `faction = &"spartan"`; faction/target semantics are tracked separately below.

## Combat scenes and spawn paths

| Scene/tool | Existing spawn path | Families | Canonical factory path | Status | Validation required/evidence |
|---|---|---|---|---|---|
| `combat_lab.tscn` / `main.gd` | typed request/factory | current roster, phalanx, elites/boss | direct typed request | validated | startup PASS; shooting annex PASS with 56 units and the authored 21 shield units; roster/crowd/archer/combat/equipment PASS |
| `battle_01.tscn` / `battle_01.gd` | former direct constructors | legacy families + Spartan allies | factory with explicit target semantics | validated | spawn probe before/after + scene startup PASS |
| `battle_02.tscn` / inherited helpers | inherited Battle 01 helpers | legacy families + allies | inherited typed factory helpers | validated | typed spawn probe + scene startup PASS; full ally survival/quest automation still needed |
| `battle_03_narrative.tscn` / inherited helpers | inherited Battle 01 helpers | current roster/phalanx/boss | inherited factory helpers | validated | spawn + narrative + 88/46/51 wave + startup PASS |
| `procedural_campaign.tscn` / wave director | typed request/factory | current procedural roster/bosses | direct typed request | validated | real ordinary/miniboss/boss spawn, parent/targets/options/groups/metadata/signals PASS; staged campaign planning PASS |
| Forge runtime/preview | `world_runtime.gd` factory | all IDs including giants | preserve and adapt final API | characterized | Forge probe excluded while user file is modified |
| Forge event waves/reserves | delegates to world runtime | saved enemy groups | preserve indirect factory route | discovered | old `.hoplite.json` compatibility inventory needed |
| Unit/integration probes | mixed direct `.new()` and factory | targeted internals | factory or documented low-level exception | discovered | decide per probe before legacy retirement |

## Behavior implementations

| Responsibility | Existing owner(s) | Canonical owner | Adapter/removal condition | Status | Validation evidence |
|---|---|---|---|---|---|
| Entity root | `HopliteAthenianEnemy` | common combatant root | retain class/public facade during extraction | characterized | public surface inventoried |
| Archetype data | normalized profile dictionaries + derived typed view | typed immutable Resource/registry | `profile()` and `legacy_profile()` remain until controller, campaign, Forge and tools migrate | pilot | exact 22 IDs, alias, fallback, package and deep-copy probe PASS |
| FSM | tactical `ai_state` label plus timer/flag branch priority | explicit event/dirty-transition FSM | facade must preserve diagnostic labels/timing; per-tick resolver and observational-latch Pilot A both rejected and rolled back | characterized | legacy action characterization retained; no runtime FSM |
| Perception/targeting | entity groups + `hoplite_ai_claims` | shared targeting component/service | preserve target/faction rules, distinct/explicit-null target semantics and claims during migration | characterized | real Athenian/Spartan faction-targeting probe PASS; live-free claim leak fixed; registry/query boundary documented |
| Locomotion | entity steering/separation/scans | one motion owner consuming intentions | procedural external writes need runtime-control adapter | characterized | archer baseline PASS; scene/navigation gaps remain |
| Combat/defense | entity + hit/shield/anatomy interfaces | common interface plus strategies | retain public hit methods/signals | characterized | enemy combat baseline PASS |
| Crowd/formations | crowd director + entity fields/metadata | shared coordinator | duck-typed engagement fallback removed only at zero consumers | characterized | crowd + equipment baseline PASS |
| Animation | driver, Mixamo, Spartan pose bridge | common semantic animation interface | preserve all three presentation strategies | characterized | animation/pose baseline pending current run |
| Health/anatomy/gore | entity health + anatomy/shield + gore helpers | common health/anatomy interface | retain localized hit/sever/death facade | characterized | enemy combat PASS; pose/giant pending |
| Factory/registry | typed request + dictionary adapter; SceneTree groups; scene registry with explicit opt-in factory injection | single factory and scene-scoped combatant registry | dictionary adapter retires after all callers and save/schema compatibility migrate; registry authority expands only after consumer-specific parity gates | pilot: `combat_lab` only | synthetic/real factory probes PASS; noisy spawn gate rejected; isolated-operation gate and 99-enemy lab parity/teardown PASS; no gameplay query consumer |
| Performance LOD | entity timers + mass animation mode | canonical simulation/visual LOD policy | preserve current thresholds until benchmarked | characterized | deterministic 12/56 idle/active foundation baseline captured in three runs |

## External dependents

| Dependent system | Contract used | Existing provider | Canonical provider | Status | Validation |
|---|---|---|---|---|---|
| Player combat/movement | enemy groups, hit methods, aim/dead/sever, giant surfaces | enemy public facade | unchanged facade backed by components | characterized | combat/wall-run probes |
| Battle counters/quests | `died`, groups, role counters | enemy facade + battle scripts | unchanged facade | characterized | spawn/narrative/wave PASS; Battle 02 full automation gap |
| Procedural progression | spawn/phase/zone signals, public fields | wave director + enemy facade | factory/registry + unchanged campaign signals | validated for spawn path | real three-rank spawn/signals PASS; staged campaign planning PASS |
| UI/audio/feedback | five signals, combat debug, groups | enemy facade | animation/combat/health adapters through facade | characterized | combat/feedback probes |
| Forge saves | archetype IDs, group schema, direct AI fields | JSON + world runtime | versioned spawn request/schema | discovered | user saves not inspected |
| Crowd director | groups, metadata, duck-typed methods | combatant and director | registry/coordinator | characterized | crowd baseline PASS |
