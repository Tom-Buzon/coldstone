# Enemy refactor performance baseline

Updated: 2026-08-25

## Measurement rules

- Record engine build, renderer, display/headless mode, scene, seed, warm-up, sample duration, combatant count, and command for every run.
- Keep raw outputs under `.tmp_tools/enemy_refactor/`; record only summaries and file references here.
- Run comparable scenarios at least three times when timing noise matters; report median and range.
- Separate script/physics/navigation measurements from rendering measurements when headless runs cannot represent draw performance.
- Treat an unexplained material regression as a failed migration gate.

## Baseline environment

| Field | Value |
|---|---|
| Behavior baseline binary | `4.7.2.stable.official.ed1daf0bf`; workspace-local binary later removed externally |
| Reproducible performance binary | `4.7.stable.official.5b4e0cb0f`; `C:/Users/suean/Downloads/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe` |
| Renderer | `gl_compatibility` |
| Physics ticks | no project override; Godot default 60 Hz |
| Target frame budget | Pending existing project requirement; 16.6 ms at 60 FPS is the provisional reference |

## Scenarios

| Scenario | Command/configuration | Metrics | Baseline result | Latest result | Raw log |
|---|---|---|---|---|---|
| Fast contract tier | roster, crowd, archer probes | Exit code, wall time, assertions | PASS; ~1.08–1.37 s/tool wall time | Same | corresponding `*_baseline.log` files |
| Medium contract tier | phalanx equipment, enemy combat | Exit code, wall time, assertions | PASS; ~3.42 s and ~2.30 s | Same | corresponding `*_baseline.log` files |
| Startup `combat_lab` | existing `.tmp_tools/combat_lab_benchmark.json` | setup/load/cleanup | 80.768 / 566.161 / 112.827 ms | Pending reproducible rerun | historical only: command/repetitions absent |
| Canonical enemy 12/56 idle/active | `enemy_performance_benchmark.gd` v2; swordsman, mass mode, seed 13371, 120 warm-up + 120 physics ticks; one scenario/process | spawn wall time; paced tick intervals; objects/nodes/memory; structural teardown | First reproducible foundation baseline | PASS, table below | `enemy_performance_v2_{idle,active}_{12,56}_run{1,2,3}.log` |
| Crowd synthetic 12/18/56 | canonical harness covers 12/56 with crowd director; explicit 18-unit comparison pending | wall frame, objects, memory | Partial | 12/56 captured | foundation logs |
| Phalanx 10/24/28 | deterministic harness pending | director cost/calls, process/physics | Pending | Pending | Pending |
| Anatomy 1/22/56 | deterministic harness pending | update cost, objects, memory, collision pairs | Pending | Pending | Pending |
| Boss/giant | deterministic harness pending | process/physics, active bodies, memory | Pending | Pending | Pending |
| Battles 01/02/03 rendered | repeatable route pending | FPS/frame percentiles, draw calls, VRAM | Pending | Pending | Pending |
| Teardown/reload | three-cycle harness pending | object/memory deltas | Pending | Pending | Pending |

## Optimization ledger

No optimization is claimed until its before/after commands, inputs, and measurements are recorded here.

| Slice | Change tested | Result | Decision/evidence |
|---|---|---|---|
| Action FSM prototype | Per-enemy `RefCounted` resolver, then allocation-free static resolver, called on each active physics tick | Rejected | Active/56 later samples had higher paced p95 values while one object/enemy appeared in the first version; post-rollback samples also showed environmental scheduler elevation, so causality was inconclusive. Since non-regression could not be established and hot-path dispatch was avoidable, runtime integration was fully rolled back. Characterization probe retained; see `enemy_performance_action_state_*` logs. |
| Observational action-latch Pilot A | Scalar enum/latches observed the winning legacy branch without controlling it; no per-enemy FSM object | Rejected | Gameplay/source/object gates passed, but nine paired `steady_clean` runs failed the predeclared dispersion gate: p50-ratio IQR `0.203399` > `0.03`; p95-ratio IQR `0.162106` > `0.05`. The result is inconclusive, not proof that the latch caused a regression. Runtime changes were fully rolled back. |
| Combatant registry Pilot 1/2 | Opt-in factory registration; Pilot 1 used one `WeakRef` per combatant, Pilot 2 uses non-owning instance IDs and script-level contract caching | Production injection rejected; opt-in API retained | Pilot 2 reduced registry-on objects from `4,704` to `4,648` (`4,646` off) and met the median gate, but its fresh nine-pair spawn-ratio IQR `0.070460` exceeded `0.05`. Structural gates passed. Timing is inconclusive, so no production scene is wired and no speed claim is made. |

### Registry spawn-cost gate

Version 3 of `enemy_performance_benchmark.gd` accepts `--registry=off|on`. Registry creation occurs before the spawn timer; explicit factory registration is inside it. Every run asserts 56 entries when enabled, zero enemy/registry live references after teardown, and the existing combatant-group cleanup contract.

Exploratory command, one fresh process per side and alternating `AB`/`BA` for nine pairs:

```powershell
& 'C:\Users\suean\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tools/enemy_performance_benchmark.gd --log-file <absolute-run-log> -- --counts=56 --mode=idle --warmup=0 --frames=1 --registry=<off|on>
```

| Exploratory pair | Registry-off spawn, ms | Registry-on spawn, ms | B/A |
|---|---:|---:|---:|
| 01 | 721.903 | 783.062 | 1.084719 |
| 02 | 743.453 | 791.904 | 1.065170 |
| 03 | 760.455 | 786.023 | 1.033622 |
| 04 | 935.429 | 801.477 | 0.856802 |
| 05 | 750.097 | 793.530 | 1.057903 |
| 06 | 788.122 | 965.512 | 1.225079 |
| 07 | 787.216 | 795.806 | 1.010912 |
| 08 | 735.884 | 795.704 | 1.081290 |
| 09 | 708.931 | 872.214 | 1.230323 |

Nearest-rank ratio median `1.065170`, Q1 `1.033622`, Q3 `1.084719`, IQR `0.051097`. All sides passed teardown; registry-on recorded exactly 56 entries and a stable expected object snapshot of `4,704`, versus `4,646` off. These runs calibrated the gate and are not an acceptance set because thresholds were not written before capture.

The next optimized candidate is accepted for controlled-scene injection only if a fresh nine-pair set has median B/A spawn time at most `1.03`, ratio IQR at most `0.05`, registry-on object delta at most `2`, exactly 56 registered entries, and complete structural teardown in every run. Failure or inconclusive evidence leaves all production requests registry-null. Raw exploratory logs: `.tmp_tools/enemy_refactor/enemy_registry_spawn_v3_pair_{01..09}_{A,B}.log`.

Pilot 2 replaced per-combatant `WeakRef` objects with non-owning ObjectDB instance IDs and cached contract introspection once per script. The predeclared acceptance set produced:

| Acceptance pair | Registry-off spawn, ms | Registry-on spawn, ms | B/A |
|---|---:|---:|---:|
| 01 | 947.390 | 838.064 | 0.884603 |
| 02 | 770.575 | 976.684 | 1.267474 |
| 03 | 715.822 | 720.325 | 1.006291 |
| 04 | 709.608 | 718.000 | 1.011826 |
| 05 | 702.561 | 890.120 | 1.266965 |
| 06 | 803.865 | 756.731 | 0.941366 |
| 07 | 759.305 | 757.495 | 0.997616 |
| 08 | 761.007 | 754.044 | 0.990850 |
| 09 | 789.536 | 740.870 | 0.938361 |

Nearest-rank ratio median `0.997616` (PASS ≤ `1.03`), Q1 `0.941366`, Q3 `1.011826`, IQR `0.070460` (**FAIL** > `0.05`). Every A/B side passed structural cleanup; every B side registered 56 entries, held exactly `4,648` objects during the snapshot (+2), and released its registry reference. The distribution cannot attribute a speed change and rejects controlled-scene injection. Raw acceptance logs: `.tmp_tools/enemy_refactor/enemy_registry_spawn_v3_optimized_pair_{01..09}_{A,B}.log`.

Audit limit: the thresholds were written in this work session before the optimized runs, but these documentation files and raw logs are untracked worktree artifacts. Their internal content and timestamps are coherent, yet the repository cannot independently provide a commit/hash proof of that ordering. The failed gate is therefore still applied conservatively; no production integration depends on accepting the chronology claim.

### Predeclared isolated registry-operation gate

The full-spawn pairs above are dominated by asset/controller construction and could not resolve the incremental registry cost. Before implementing or running the isolated acceptance harness, the next design is fixed as follows:

- pre-create 56 disabled synthetic combatant Nodes in one SceneTree before any timed region; all share one Script and expose the exact typed `faction`, `ai_enabled`, `died(combatant: Node)` and liveness contract used by the real registry;
- analyze 100 cold samples per fresh process after five fixed sacrificial samples. Smoke instrumentation showed one delayed engine-object allocation after the first sample, while Nodes, orphans, connections and WeakRefs were already clean; five sacrificial samples move the strict object-window baseline past that lazy initialization. Each cold sample still creates and adds a fresh registry outside the timer, so its register-56 region includes exactly one Script introspection plus 55 cache hits; unregister-56 is timed separately, then the registry is freed before the next sample;
- pair each cold region with control A, a timed traversal of the same 56 Nodes that reads instance ID/faction/AI into a checksum. Alternate A/B order per sample and the initial order across 15 fresh processes. Use `net_us = max(0, B_us - A_us)` rather than an unstable ratio against a near-zero control;
- use a fixed seeded unregister permutation prepared before the campaign. No `await`, print, assertion, snapshot or harness allocation belongs inside a timed region;
- retain a persistent, preheated registry only for diagnostic warm register/unregister samples; cold metrics remain authoritative because `_validated_scripts` is a cache per registry instance and manual unregister intentionally leaves callbacks connected to that same registry;
- require exactly 56 successful registrations/unregistrations per sample, exact ordered snapshot after registration, exactly one cached Script, zero entries plus exactly 112 retained callbacks after unregister, baseline connection counts after registry free, no Node/object/orphan growth across either post-sacrifice measured window, and all fixture/registry WeakRef checks to clear. After complete fixture teardown, Node/orphan counts must return exactly to their pre-fixture values; global Object count is published diagnostically because engine caches may initialize during the run and is not treated as process-wide leak proof;
- accept only if all 15 processes pass structurally, control p95 is at most `0.050 ms` and at most 10% of cold-register p50 (otherwise the campaign is inconclusive), cold register-56 nearest-rank median p50 net is at most `0.500 ms`, median p95 net is at most `0.833 ms`, and across-process p50-net IQR is at most `0.200 ms`;
- additionally require cold unregister-56 median p95 **raw** at most `0.833 ms`, and warm register-56 and unregister-56 median p95 **raw** at most `0.500 ms` each. Net subtraction is authoritative only for cold register, where control p95 must remain at most 10% of cold-register raw p50; unregister net values are diagnostic because control traversal is not negligible relative to unregister.

At 60 Hz, `0.833 ms` is 5% of one frame. Each log must publish its 100 raw samples, benchmark/registry SHA-256, run index and enforced odd-AB/even-BA initial order so the campaign can be independently recalculated and cannot silently mix sources. Passing this isolated gate does not by itself authorize global registry authority, and unregister timing does not represent full SceneTree `tree_exiting` dispatch. A pass only reopens one controlled consumer migration followed by its functional suite and a fresh full-scene observation. Any structural failure or inconclusive distribution keeps D-016's production NO-GO in force. As with the earlier untracked artifacts, timestamps/content can document but not cryptographically prove that this gate predates its future logs.

The fixed campaign produced 15/15 PASS logs with one source-hash pair and 100 raw values in every required array:

| Metric across 15 fresh processes | Q1 | Median | Q3 | Gate | Result |
|---|---:|---:|---:|---:|---|
| Cold register-56 net p50 | 318 us | 324 us | 337 us | median ≤ 500 us | PASS |
| Cold register-56 net p95 | 370 us | 380 us | 403 us | median ≤ 833 us | PASS |
| Cold unregister-56 raw p95 | 47 us | 48 us | 50 us | median ≤ 833 us | PASS |
| Warm register-56 raw p95 | 148 us | 152 us | 155 us | median ≤ 500 us | PASS |
| Warm unregister-56 raw p95 | 40 us | 41 us | 42 us | median ≤ 500 us | PASS |

Cold-register p50 IQR is `19 us` (PASS ≤ `200 us`). Per-process control p95 is `16–21 us`, at most `6.00%` of cold-register raw p50 (both control gates PASS). All 15 processes have empty failures/issues, exact run index/order, stable post-sacrifice Node/Object/orphan windows, 112 callbacks after unregister, baseline callbacks after registry free, and complete fixture WeakRef/Node/orphan teardown. Raw logs: `.tmp_tools/enemy_refactor/enemy_registry_operation_v1_run{01..15}.log`. Independent recalculation reproduced all results.

This PASS authorized only the `combat_lab` consumer in D-018. Its real 99-enemy full-scene probe and adjacent suites pass; no performance improvement is claimed, and no other scene or gameplay owner is authorized by this result.

### Callback-region elapsed-time instrumentation and Pilot A result

`enemy_action_cpu_benchmark.gd` adds a begin marker at physics priority `-1000` and an end marker at `+1000`. The elapsed monotonic wall interval excludes the paced wait between ticks but includes OS preemption/stalls and every physics callback between those priorities. It is neither thread CPU time nor an attribution to the FSM alone. Version 2 removes the crowd director from `steady_clean`, records sample-start/end/after object counts, weak-checks auxiliary nodes, and stores the controller SHA-256.

Command, one scenario per fresh process and three runs before Pilot A:

```powershell
& 'C:\Users\suean\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tools/enemy_action_cpu_benchmark.gd --log-file <absolute-run-log> -- --scenario=<steady_clean|realistic_active|mixed_roles> --count=56 --warmup=120 --frames=240
```

| Preliminary v1 scenario, 56 enemies | Callback-region p50 median (range), µs | p95 / p99 median, µs | Spawn median, ms | During objects | Structural teardown |
|---|---:|---:|---:|---:|---|
| `steady_clean` | 3,296 (3,260–3,347) | 10,616 / 15,481 | 795.815 | 4,647 | PASS: 0 combatants, 0 live refs |
| `realistic_active` | 13,828 (11,610–14,066) | 18,735 / 21,428 | 772.112 | 4,647 | PASS: 0 combatants, 0 live refs |
| `mixed_roles` | 13,210 (12,984–13,997) | 17,807 / 19,156 | 2,028.181 | 5,325 | PASS: 0 combatants, 0 live refs |

Raw logs: `.tmp_tools/enemy_refactor/enemy_action_cpu_before_{steady_clean,realistic_active,mixed_roles}_56_run{1,2,3}.log`.

These version-1 runs validated bracketing and exposed the noise floor, but are not an authoritative before baseline: `steady_clean` still included the allocating crowd director, teardown evidence was incomplete, and the original label incorrectly called elapsed time CPU time. Realistic p50 varied by roughly 21% across three runs and stable p95 by roughly 20%, far above the intended regression thresholds.

Authoritative use requires nine fresh A/B pairs per scenario alternating `AB`/`BA`. For each pair compute B/A p50 and p95 ratios; publish all nine values, median and nearest-rank Q1/Q3/IQR (the same percentile convention as the harness `_percentile()`). Acceptance requires median ratios no greater than `1.03`/`1.05` and IQR no greater than `0.03`/`0.05`, plus functional/source/object gates. Any inconclusive distribution rejects integration. No performance improvement or pre-pilot baseline is claimed from the preliminary logs.

Pilot A was then measured with the legacy controller as A (`b64fe3138c9754a2ddc72a412106ec3f9ff925937ff4c6704610ecce61b37d9b`) and the observational-latch controller as B (`4c5eaad93b85a4e8c706ead6de164d9f1cbd7feb796bbe1f67d1d3c662976bb8`). The measurement sources were identical in all runs: benchmark `d60a7923d2a8a8f06efcee865b3d0f18a02b198f0abf9301ded718a304f4ac75`, begin marker `111c9fcb0a63d2b484da6d19f6a5c9913e2121b36dba93ff1e8ee05b701ffecf`, end marker `11e1ec63311b3253e76bfb1365d410d5a6c7cca1b4136a35a22c033abb25e879`.

| Pair/order | A p50 / B p50, µs | B/A p50 | A p95 / B p95, µs | B/A p95 |
|---|---:|---:|---:|---:|
| 01 / AB | 2,388 / 3,076 | 1.288107 | 8,353 / 10,846 | 1.298456 |
| 02 / BA | 1,594 / 1,940 | 1.217064 | 6,145 / 7,264 | 1.182099 |
| 03 / AB | 1,640 / 1,645 | 1.003049 | 6,349 / 6,425 | 1.011970 |
| 04 / BA | 1,551 / 1,552 | 1.000645 | 6,052 / 6,173 | 1.019993 |
| 05 / AB | 1,626 / 1,649 | 1.014145 | 6,062 / 6,299 | 1.039096 |
| 06 / BA | 1,610 / 1,632 | 1.013665 | 6,137 / 6,442 | 1.049699 |
| 07 / AB | 1,637 / 1,681 | 1.026878 | 6,320 / 6,444 | 1.019620 |
| 08 / BA | 1,534 / 1,678 | 1.093872 | 6,200 / 6,489 | 1.046613 |
| 09 / AB | 1,866 / 2,689 | 1.441050 | 6,835 / 10,803 | 1.580541 |
| Median | — | 1.026878 | — | 1.046613 |
| Q1 / Q3 / IQR | — | 1.013665 / 1.217064 / **0.203399** | — | 1.019993 / 1.182099 / **0.162106** |

Every run passed the harness assertions, kept its sampling object count stable at `4,646`, and released all enemy and auxiliary weak references. The functional probes also passed after correcting death lifecycle observation. Both medians were within their limits, but both ratio IQRs exceeded the predeclared limits by a wide margin. Therefore the gate is **inconclusive and rejects Pilot A**. This distribution cannot establish whether the candidate changed cost; no causal regression or optimization claim is made. Because the first required scenario already rejected integration, the nine-pair campaign was not continued for `realistic_active` or `mixed_roles`.

Raw paired logs: `.tmp_tools/enemy_refactor/enemy_action_callback_region_v2_pair_steady_clean_56_pair{01..09}_{A,B}.log`. Pilot smoke and functional evidence remains under `enemy_action_callback_region_v2_pilot_a_*`, `enemy_action_state_pilot_a.log`, `enemy_combat_pilot_a.log`, `crowd_tactics_pilot_a.log`, `archer_high_ground_pilot_a.log`, `phalanx_equipment_pilot_a.log`, `battle_enemy_spawn_pilot_a.log`, and `enemy_factory_route_pilot_a.log`. The runtime controller is again exact A; only the design, characterization probe and measurement harness remain.

### Canonical foundation baseline

Each of the four commands is run in a separate process and repeated three times with distinct `--log-file` values, so every spawn measurement is the first scenario in its process:

```powershell
& 'C:\Users\suean\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tools/enemy_performance_benchmark.gd --log-file <absolute-run-log> -- --counts=<12-or-56> --mode=<idle-or-active>
```

Godot's headless `TIME_PROCESS`, `TIME_PHYSICS_PROCESS`, and `TIME_FPS` monitors refresh more slowly than the physics sampling loop. Version 2 records one explicitly diagnostic snapshot instead of pretending those values are independent per-frame samples. `physics_tick_interval_wall_ms` is also cadence-limited: it can reveal missed/late ticks in like-for-like runs but does not measure CPU headroom. The primary directly comparable cost is `spawn_wall_ms`; structural snapshots and teardown are invariant checks.

| Scenario | Spawn median (range), ms | Tick interval p95 / p99 median, ms | Worst interval across 3 runs, ms | During snapshot | Structural teardown |
|---|---:|---:|---:|---|---|
| 12 idle | 348.708 (347.639–365.128) | 20.705 / 20.736 | 21.095 | 378 nodes; 2,226 objects; 89,335,967 B static | PASS: 0 combatants, 0 live refs; 0 orphans snapshot |
| 56 idle | 755.942 (714.973–855.176) | 20.701 / 20.706 | 21.001 | 1,742 nodes; 4,646 objects; 108,893,843 B static | PASS: 0 combatants, 0 live refs; 0 orphans snapshot |
| 12 active | 345.411 (339.020–379.238) | 20.696 / 20.710 | 20.746 | 378 nodes; 2,227 objects; 89,414,639 B static; 12 active physics objects | PASS: 0 combatants, 0 live refs; 0 orphans snapshot |
| 56 active | 754.117 (707.391–893.493) | 20.717 / 21.803 | 24.128 | 1,742 nodes; 4,647 objects; 108,561,639–109,243,343 B static; 56 active physics objects | PASS: 0 combatants, 0 live refs; 0 orphans snapshot |

This is the baseline for subsequent component/FSM/registry/LOD work, not a comparison against pre-refactor HEAD. No performance improvement is claimed for the factory or typed-data slices because this deterministic harness did not exist before them. The earlier `enemy_performance_foundation_run{1,2,3}.log` version-1 matrix runs are retained as instrumentation history only: scenario order mixed cold/warm caches, the warm-up was too short for engine monitors, and their timing aggregates are not comparable baselines.

## Current limitations

- No GUT/gdUnit suite or CI runner exists; validation uses `SceneTree` probes.
- The initial phase-0 capture did not include a NavigationServer workload, so no before/after NavigationServer CPU percentage is claimed. The final runtime does include `NAVMESH_GROUND` with `NavigationAgent3D`; its real detour, retarget, arrival, layer mismatch and empty-map fallback are validated functionally by `enemy_navigation_navmesh_probe.gd`.
- Headless runs do not represent rendered FPS, draw calls, or VRAM.
- The harness is physics-tick paced at 60 Hz, so tick intervals represent pacing/scheduler jitter as well as workload; they detect late ticks but do not expose CPU headroom.
- WeakRefs and combatant groups prove structural scene teardown, not absence of every delayed resource/object leak. Resource and memory snapshots are diagnostic and may legitimately remain cached.
- Existing historical logs mostly used Godot 4.7 rather than 4.7.2 and are evidence of past behavior, not comparable timing baselines.
- The 2.73 GB historical immortality log must not be reproduced until verbosity and log size are bounded.

## Mission final — isolated post-refactor measurements (2026-08-26)

The authoritative final logs use the same Godot build, renderer, seed, counts, scenario order, 120-frame warm-up and 120-frame sample as `BASELINE.md`. All 16 scenarios pass structural teardown and preserve the mass-battle threshold at 28. Raw values are also serialized in `final_metrics.json`.

### Structural comparison

| Representative scenario | Baseline nodes → final | Baseline objects → final | Baseline static memory → final | Interpretation |
|---|---:|---:|---:|---|
| swordsman idle 36 | 1,122 → 1,122 | 3,557 → 3,456 | 101,140,671 → 101,523,242 B | node parity; 101 fewer objects; +0.4% static memory |
| swordsman active 28 | 874 → 874 | 3,118 → 3,097 | 97,874,987 → 98,554,858 B | node parity after RefCounted navigation; 21 fewer objects; +0.7% memory |
| swordsman active 36 | 1,122 → 1,122 | 3,558 → 3,529 | 101,403,959 → 102,048,358 B | node parity; 29 fewer objects; +0.6% memory |
| ngeneral idle 36 | 2,562 → 2,562 | 5,174 → 5,178 | 67,078,837 → 67,798,668 B | shared rig unchanged; +4 objects; +1.1% memory |
| ngeneral active 36 | 2,562 → 2,562 | 5,175 → 5,251 | 67,404,461 → 68,434,080 B | no node growth; +76 objects; +1.5% memory |

The first navigation implementation added one SceneTree node per active enemy (`902` nodes at active 28 versus the baseline `874`). The accepted implementation keeps intent/recovery as a `RefCounted` service and creates a node only for a real `NavigationAgent3D`; the final count returns exactly to `874` while the real-navmesh detour probe remains green.

Spawn wall times and slow-refresh `TIME_PROCESS`/`TIME_PHYSICS_PROCESS` snapshots vary upward in many final scenarios (for example swordsman active 28 spawn `502.941 → 592.552 ms`). They are reported, not hidden, and do **not** establish a speed gain. Their single-run ordering, warmed cache state and slow monitor refresh make causal attribution invalid.

### 56-enemy callback-region snapshot — no comparable baseline

| Scenario | Current p50 | Current p95 | Stable objects during sample | Teardown |
|---|---:|---:|---|---|
| `steady_clean` | 2,720 µs | 4,702 µs | yes | PASS |
| `realistic_active` | 10,435 µs | 14,254 µs | yes | PASS |
| `mixed_roles` | 11,029 µs | 14,694 µs | yes | PASS |

The earlier reference values came from version 1 of the harness, including a different `steady_clean` configuration and incomplete teardown. They are not comparable with the version-2 final harness; all previously published percentage gains are withdrawn. These current values are budgets for future same-hash A/B runs, not evidence of a CPU improvement.

### Five-cycle reload stability

Five consecutive loads/unloads of 36 active swordsmen pass with zero enemy `WeakRef`, zero combatant member and return to the baseline node count after every cycle. After the first cache-warming cycle, object count is exactly `1,596` in all four remaining snapshots (span `0`); static-memory span is `2,436 B`, below the declared `4 MiB` tolerance. This proves a post-warm plateau for the tested route, not a process-wide proof for every engine cache.

### Rendered 22-unit snapshots

| Context | Draw calls | Objects rendered | Primitives | Video memory | Texture / buffer memory |
|---|---:|---:|---:|---:|---:|
| Forge runtime, six action classes | 377 | 378 | 672,430 | 637,740,090 B | 514,318,670 / 123,421,420 B |
| Combat Lab + roster annex, six action classes | 1,171 | 764 | 1,021,459 | 1,564,909,673 B | 1,172,347,511 / 392,562,162 B |

These are current rendered diagnostics captured with `gl_compatibility`; there is no equivalent pre-refactor GPU snapshot, so no GPU percentage improvement is claimed. The Lab figure includes the real full laboratory plus the 22-unit annex and is intentionally not compared to the lighter Forge fixture.
