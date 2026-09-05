# Enemy refactor — master plan

Updated: 2026-08-25

## Goal

Replace all runtime enemy/ally combatant paths with one GDScript architecture while preserving every observable gameplay contract and maintaining or improving measured performance.

## Non-negotiable gates

- Characterize before changing.
- Preserve public methods, signals, scene paths, exported properties, NodePaths, factions, combat behavior, equipment, animation, anatomy, gore, formations, bosses, giants, quests, and progression unless an explicit decision records user approval.
- Keep exactly one owner of `velocity`, physical rotation, and `move_and_slide()` per combatant.
- Search scripts, scenes, resources, and tools before retiring any path.
- Do not advance a migration slice while its targeted validation is failing.
- Require root-agent diff inspection and an independent review for every significant slice.

## Phases

### Phase 0 — Inventory and baseline (foundation gate passed; discovery remains continuous)

Skills: `using-godot-prompter`, `godot-brainstorming`, `godot-testing`, `godot-optimization`.

- Map archetypes, scenes, spawn paths, runtime dependencies, public contracts, probes, and benchmarks.
- Run existing relevant checks without changing runtime behavior.
- Record reproducible baseline commands and measurements.

Exit gate: the migration and regression matrices cover every discovered path; baseline failures are distinguished from refactor regressions.

### Phase 1 — Contracts and characterization tests (foundation gate passed; family coverage continues)

Skills: `godot-testing`, `gdscript-advanced`, plus the domain skills for each protected behavior.

- Convert observed behavior and public dependencies into executable tests.
- Freeze the canonical entity, combat, defense, health/anatomy, animation, targeting, locomotion, and spawn contracts.

Exit gate: the first migration candidate is protected by passing characterization tests.

### Phase 2 — Canonical foundation (active)

Skills: `component-system`, `scene-organization`, `state-machine`, `ai-navigation`, `physics-system`, `gdscript-advanced`.

- Introduce typed archetype data and minimal canonical interfaces/components.
- Introduce the single factory and combatant registry behind compatibility-preserving entry points.
- Migrate one representative standard combatant without rewriting its behavior.

Exit gate: old and canonical paths are behaviorally equivalent for the pilot consumer.

### Phase 3 — Progressive family migration

Skills: the Phase 2 skills plus each family-specific domain skill.

- Migrate standard soldiers, archers, phalanges, elites, bosses/minibosses, allies, and giants one family at a time.
- Migrate narrative, procedural, laboratory, and test spawns after their archetypes are protected.

Exit gate: all rows in `MIGRATION_MATRIX.md` use the canonical runtime path and pass their validations.

### Phase 4 — Tactical and performance unification

Skills: `ai-navigation`, `physics-system`, `godot-optimization`, `gdscript-advanced`.

- Unify target claims, attack budgets, formation work, navigation recovery, and simulation levels.
- Measure each optimization against the Phase 0 baseline.

Exit gate: no material benchmark regression; improvements have reproducible evidence.

### Phase 5 — Legacy retirement

Skills: `scene-organization`, `component-system`, `godot-code-review`.

- Prove zero live references before removal.
- Add checks preventing future spawns from bypassing the canonical factory.

Exit gate: one source of truth per responsibility and no active parallel runtime system.

### Phase 6 — Global validation

Skills: `godot-code-review`, `godot-optimization`, and `godot-debugging` for any failure.

- Replay all probes, scenes, archetypes, integration checks, and benchmarks.
- Audit every migration and regression row.

Exit gate: every final success criterion in the request is evidenced in the tracking documents.

## Slice workflow

For every slice: characterize; protect with a test; specify the contract; implement minimally; migrate one consumer; validate and compare; obtain independent review; migrate remaining consumers; prove zero references before cleanup; rerun global checks; update all tracking documents.
