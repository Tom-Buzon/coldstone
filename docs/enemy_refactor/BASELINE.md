# Baseline mission — audit complet des ennemis

Date de capture : 2026-08-26\
Projet : Godot `4.7.stable.official.5b4e0cb0f`\
Renderer : `gl_compatibility`\
Scène principale : `res://combat_lab.tscn`

## Protection du worktree

Le worktree était déjà fortement modifié avant cette mission. Les modifications préexistantes, notamment dans `athenian_enemy.gd`, `battle_crowd_director.gd`, `enemy_factory.gd`, les scripts Forge, les ressources d'animation et les probes, sont conservées. Aucun reset, checkout destructif ou écrasement n'est autorisé.

Le travail déjà présent sous `docs/enemy_refactor/` constitue une fondation à prolonger. Les journaux historiques sont conservés sous `.tmp_tools/enemy_refactor/`.

## Mesure de charge fraîche

Commande :

```powershell
& 'C:\Users\suean\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tools/enemy_performance_benchmark.gd --log-file '.tmp_tools/enemy_refactor/mission_baseline_counts_1_5_15_28_36_both.log' -- --counts=1,5,15,28,36 --mode=both --warmup=120 --frames=120
```

Le harness emploie `mass_battle_mode = true` sans modifier le seuil de 28. Les instantanés FPS/process/physics sont des moniteurs Godot à rafraîchissement lent et ne constituent pas seuls une preuve de gain ; spawn, compteurs structurels, mémoire, tick wall-time et teardown sont les mesures comparables principales.

| Mode | Unités | Spawn ms | Process ms* | Physics ms* | Nœuds | Objets | Mémoire statique | Corps actifs | Tick p95 ms | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 1 | 279.767 | 0.227 | 0.429 | 37 | 1 632 | 85 591 030 | 0 | 20.707 | PASS |
| idle | 5 | 300.998 | 0.508 | 1.135 | 161 | 1 852 | 87 354 246 | 0 | 20.706 | PASS |
| idle | 15 | 392.733 | 1.374 | 1.268 | 471 | 2 402 | 91 795 496 | 0 | 20.709 | PASS |
| idle | 28 | 512.665 | 2.380 | 2.251 | 874 | 3 117 | 97 587 567 | 0 | 20.702 | PASS |
| idle | 36 | 590.141 | 2.654 | 2.188 | 1 122 | 3 557 | 101 140 671 | 0 | 20.713 | PASS |
| active | 1 | 249.627 | 0.291 | 0.815 | 37 | 1 633 | 85 993 102 | 1 | 20.708 | PASS |
| active | 5 | 292.579 | 0.695 | 1.495 | 161 | 1 853 | 87 756 578 | 5 | 20.703 | PASS |
| active | 15 | 373.885 | 1.837 | 3.172 | 471 | 2 403 | 92 154 720 | 15 | 20.699 | PASS |
| active | 28 | 502.941 | 3.171 | 5.243 | 874 | 3 118 | 97 874 987 | 28 | 20.706 | PASS |
| active | 36 | 587.715 | 4.694 | 6.880 | 1 122 | 3 558 | 101 403 959 | 36 | 20.715 | PASS |

\* instantanés diagnostiques seulement.

### Baseline hoplite `ngeneral`

Une seconde exécution comparable cible la famille prioritaire avec `--archetype=ngeneral`. Le journal frais confirme à chaque instance `[HOPLITE SHARED ANIMATION] READY library_v=3` et l'absence de donneurs runtime.

| Mode | Unités | Spawn ms | Process ms* | Physics ms* | Nœuds | Objets | Ressources | Mémoire statique | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 15 | 244.661 | 1.492 | 2.412 | 1 071 | 3 095 | 96 | 57 548 788 | PASS |
| idle | 28 | 243.568 | 1.781 | 4.482 | 1 994 | 4 382 | 96 | 63 484 969 | PASS |
| idle | 36 | 286.261 | 2.501 | 3.550 | 2 562 | 5 174 | 96 | 67 078 837 | PASS |
| active | 15 | 143.701 | 1.195 | 4.748 | 1 071 | 3 096 | 96 | 58 191 168 | PASS |
| active | 28 | 225.957 | 2.107 | 7.988 | 1 994 | 4 383 | 96 | 63 883 553 | PASS |
| active | 36 | 266.736 | 2.745 | 9.711 | 2 562 | 5 175 | 96 | 67 404 461 | PASS |

## Probes fraîches — état initial

Verts : action priority, factory route, typed archetypes (22), factory options, registry, factory/registry lifecycle, registry/crowd characterization, factions/targeting, Battle spawn, archer high ground, phalanx equipment, animation openers (14), pose integrity, giant traversal, hoplite rig audit, hoplite structural optimization, patrol, procedural spawn, Combat Lab 56 unités/21 boucliers.

Rouges préexistants au début de cette mission :

- `enemy_roster_audit.gd` : la phalange assemblée n'entre pas en avance collective ; l'ancre commune lente ne progresse pas.
- `crowd_tactics_probe.gd` : intrusion derrière la ligne sans réponse de cohorte, arc d'expulsion non sélectionné et rangs pressing/support non distincts.
- `enemy_combat_probe.gd` : collider de tête du géant non généré depuis le mesh réel, fallback sphérique générique.

Le bruit `Failed to read the root certificate store` est environnemental et n'altère pas les codes de sortie.

## Couverture restant à capturer avant comparaison finale

- scène mixte multi-familles et bataille réelle instrumentée ;
- Forge instrumentée sans écraser les modifications utilisateur ;
- sommeil puis réveil, proche-lointain-proche ;
- mort et démembrement répétés avec temps de nettoyage ;
- métriques rendues : draw calls, VRAM, meshes/surfaces, triangles, matériaux, ombres ;
- compteurs détaillés de rigs, os, lecteurs, arbres, donneurs, retargeters, hitboxes et formes par unité.

Ces manques sont des travaux de baseline en cours, pas des résultats validés.
