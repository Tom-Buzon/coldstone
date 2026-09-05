# Adaptive armies and normal escort

User-authorized replacement of fixed army doctrines; solo implementation.

1. Measure 415 enemies against 240 allies, with/without six escorts. Skills: godot-optimization, godot-debugging.
2. Add a pure group-level situation evaluator and tactical planner: effective strength, local pressure, weak front sectors, flanks, reinforcements, stable commitments. Commander owns execution; no per-soldier army scan. Skills: godot-brainstorming, ai-navigation.
3. Reuse normal formations for independent elite troops; default autonomous army combat, G assault point, H defensive line. Remove B and circular shield simulation. Skills: input-handling, ai-navigation.
4. Remove selectable doctrines from Forge and migrate old properties; retain difficulty/composition/giant guards. Update documentation. Skills: input-handling.
5. Check behavior under advantage/disadvantage/breach, orders, migration, and full stress runtime. Measure CPU/frame limits separately from rendering. Skills: godot-code-review, godot-optimization.

Implemented: group snapshots/planner, removal of selectable doctrines, normal shared allied runtime for elite troops, G/H and retired B, migration and Forge guidance. Removed repeated legacy front computation and circular per-enemy interception. Reduced target searches, duplicate footprint work, player-budget scans, and ranged broad-phase work. Player warning visuals no longer trigger for NPC duels.

Validated with adaptive_army, attack_budget, fronts, authoring, escort, retinue, crash-regression and full battlefield probes. Stress performance results are observational: concurrent Godot/editor runs and changing outline code prevent a controlled before/after FPS conclusion. No 60 FPS guarantee is claimed.
