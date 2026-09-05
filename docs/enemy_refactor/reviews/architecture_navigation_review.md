# Contre-revue autoritaire — architecture, IA, navigation et foule

Date : 2026-08-26\
État audité : worktree courant après les corrections de contre-revue.\
Périmètre : factory, données typées, participation, scheduler, cohortes, grille spatiale, navigation, modes formation/`LARGE_BODY`, mort/teardown et architecture documentée.\
Méthode : inspection indépendante des chemins d'exécution puis probes Godot `4.7.stable.official.5b4e0cb0f`. Aucun runtime n'a été modifié par cette revue.

## Verdict final

**DONE**

Tous les anciens `BLOCKER`/`MAJOR` du périmètre sont fermés sur l'état final : promotion de cohorte avant tout renfort, quorum dégradé 2/4 floor-based, révision de membership, sélection automatique d'un vrai NavMesh par une route factory, retarget borné, layers/fallback explicites, scheduler FIFO robuste à la mort et à la désactivation, suspension/réveil physique atomique, et documentation débarrassée des autorités fictives.

Aucun P0, P1 ou P2 actif n'est retenu. Deux P3 de preuve/documentation sont signalés; ils ne remettent pas en cause les contrats runtime démontrés.

## Findings actifs

### P0

Aucun.

### P1

Aucun.

### P2

Aucun.

### P3 — La borne « trou comblé < 2 s » est simulée par téléportation dans la probe de cohorte

Fichier : `tools/hoplite_cohort_recovery_probe.gd:56-91`

Le probe démontre correctement que la mort d'un frontliner publie en moins de 0,2 s la promotion d'un **survivant existant**, avant la création de tout renfort. Pour la seconde borne, il place directement ce survivant sur la position assignée puis compare sa distance; il ne simule pas la vitesse réelle pendant deux secondes.

Reproduction : dans `_probe_stable_target_and_vacancy()`, suivre `promoted.global_position = promoted_target`. La logique de sélection et la vacance sont prouvées; la durée physique exacte reste une dette de scénario. Une future probe devrait intégrer l'intention/vitesse réelle dans une boucle bornée à 2 s.

### P3 — L'ordre d'intégration parle encore d'opt-in NavMesh alors que le runtime auto-sélectionne

Fichiers :

- `docs/enemy_refactor/ENEMY_ARCHITECTURE.md:193-198`
- `scripts/enemy/athenian_enemy.gd:694-731`

L'étape progressive 4 demande de conserver `NAVMESH_GROUND` pour un opt-in explicite. Le runtime final choisit automatiquement ce mode pour une unité terrestre non `LARGE_BODY` dès qu'une région compatible existe, sauf override. Cette ligne historique devrait être alignée sur la priorité réelle `override → LARGE_BODY → région compatible → FORMATION_LOCAL/DIRECT_STEERING`.

## Réévaluation autoritaire des anciens findings

### Factory unique et données typées — DONE

- `enemy_factory_route_probe.gd` confirme que les constructions runtime passent par `HopliteEnemyFactory`; Forge conserve un adaptateur dictionnaire vers cette même factory.
- `EnemySpawnRequest` transporte avant `_ready()` les options de faction, cible, registre, animation, `navigation_mode_override` et `navigation_layers`.
- Les 22 archétypes canoniques, alias et vues de ressources mises en cache restent la source déclarée des profils.

### Promotion sans nouvel acteur et stabilité des slots — DONE

`_reconcile_phalanx_slots()` détecte le slot du membre disparu, choisit le survivant d'un rang plus profond au score rang/colonne minimal, le place dans la vacance exacte et libère son ancien slot arrière. Le probe tue d'abord un membre de première ligne, retrouve le survivant promu avant d'ajouter le renfort, puis vérifie que le renfort prend le slot de soutien libéré sans déplacer les autres survivants.

### Quorum dégradé floor-based — DONE

Après le timeout de 3,5 s, le seuil est `max(2, floor(total * 0.60))`. Le probe place exactement deux soldats sur quatre à leur staging et deux réservistes loin de la formation; il obtient `cohort_formed == true`, `degraded == true` et exactement deux `member_ready`.

### Révision de membership — DONE

Les instance IDs triés produisent une signature stable. Toute modification incrémente `membership_revision`, publiée comme `cohort_revision`; `AthenianEnemy` la transmet à `set_formation_anchor()`. Un join/death devient donc une modification sémantique, tandis qu'un changement de cible ne renumérote pas une cohorte explicitement identifiée.

### Auto-sélection d'un vrai NavMesh par la factory — DONE

`AthenianEnemy._build_navigation_component()` applique : override typé, `LARGE_BODY`, région de navigation compatible, puis formation/direct. `enemy_navigation_navmesh_probe.gd` construit une vraie `NavigationRegion3D`, attend son upload, spawne un `ngeneral` par `HopliteEnemyFactory`, puis confirme `NAVMESH_GROUND` et un `NavigationAgent3D` directement enfant du body.

La même probe observe un chemin d'au moins trois points autour d'un trou central, un détour latéral, un retarget significatif, une arrivée unique dans la tolérance et aucun échec sur la map utilisable.

### Composant `RefCounted`, agent, layers, path pending et fallback — DONE

- Le service est un `RefCounted` et ne déplace jamais le root; seul `NAVMESH_GROUND` crée un agent.
- L'agent reçoit rayon, hauteur et `navigation_layers` depuis les settings.
- Une map vide émet une fois `navmesh_unavailable`, puis retourne un fallback direct valide.
- Une région présente seulement sur une couche incompatible émet une fois `navigation_layers_mismatch`, puis retourne le fallback.
- Une direction vide vers une cible non atteignable accumule un `path_pending_timeout` de 0,35 s, émet `target_unreachable`, puis bascule en fallback.
- `_update_destination()` est l'unique porte de retarget. Un drift inférieur à `path_retarget_distance` ne réécrit plus la cible de l'agent, y compris après `sample_intent()`; la nouvelle assertion post-sample le verrouille.

### Scheduler FIFO, mort et désactivation — DONE

Le scheduler rejette objet invalide, acteur mort, cible morte et acteur portant `ai_enabled == false`. `cancel_attack_requests(attacker)` retire atomiquement cet ID de toutes les permissions et de toutes les files. `_release_attack_permission()` appelle cette invalidation même quand l'ennemi n'a pas encore obtenu de lease locale, ce qui ferme le cas du waiter désactivé.

`attack_scheduler_probe.gd` couvre capacité, ordre FIFO, expiration, génération, release obsolète, mort, waiter désactivé, rejet de lease directe au désactivé et promotion immédiate du demandeur valide suivant, sans attendre le cleanup périodique.

### Participation physique suspendue/réveillée — DONE

`set_ai_participation(false)` libère scheduler/cible, vide la navigation et les caches, retire les groupes AI, invalide la grille/registre et appelle `set_physics_process(false)`. Le chemin `true` restaure physique, groupes, cible stable et composant. `_ready()` suspend aussi une instance factory créée initialement inactive.

Les preuves durcies sont :

- `enemy_factory_options_probe.gd` : inactive à la création, réveil physique, nouvelle suspension;
- `procedural_enemy_spawn_probe.gd` : miniboss/boss suspendus pendant l'entrée puis réveillés;
- `enemy_mixed_stress_probe.gd` : flip dynamique avec parité registre/groupes et `is_physics_processing()` restauré.

### Grille spatiale 20 Hz — DONE

`crowd_spatial_cadence_probe.gd` confirme le snapshot initial, le refresh de mouvement toutes les 0,05 s et l'invalidation immédiate de membership. Le stress 36 conserve deux cohortes, cible dynamique, réveil et cleanup sans reconstruction par membre/par frame.

### Formation et `LARGE_BODY` — DONE

Les phalanges gardent le slot local et le facing de cohorte, tout en pouvant recevoir un coarse path NavMesh. `boss_colossus` reste en `LARGE_BODY`, sans agent inutile, avec speed scale `0.78`, recovery bornée, collider primitif et teardown valide.

### Mort et teardown — DONE

La mort place d'abord l'état létal puis appelle la frontière de participation : leases/files, cible, groupes AI/cohorte, destination et physique sortent immédiatement du runtime actif. Le sever létal finalise toujours la mort. Les probes registre, stress, procedural et grande taille ne conservent pas de référence forte après teardown.

### Architecture sans classes fictives — DONE

`ENEMY_ARCHITECTURE.md` déclare explicitement qu'il n'existe pas de `EnemyRuntimeServices`, `NavigationWorld`, `EnemyActionState` ni `CorpsePolicy` au runtime. Les autorités courantes sont correctement attribuées : ciblage au facade/groupes, registre au bookkeeping opt-in, action aux champs implicites du facade, navigation au service `RefCounted`, déplacement au root, et cohorte/scheduler au `BattleCrowdDirector`. `ACTION_FSM_DESIGN.md` marque la FSM comme prototype rejeté et futur design, pas comme composant installé.

## Probes exécutés sur l'état final

Tous ont terminé avec code `0` et `PASS` :

- `attack_scheduler_probe.gd`
- `enemy_navigation_navmesh_probe.gd`
- `enemy_navigation_component_probe.gd`
- `enemy_factory_options_probe.gd`
- `enemy_factory_route_probe.gd`
- `procedural_enemy_spawn_probe.gd`
- `enemy_registry_crowd_parity_probe.gd`
- `enemy_mixed_stress_probe.gd` — 22 familles / 36 unités
- `hoplite_cohort_recovery_probe.gd`
- `crowd_spatial_cadence_probe.gd`
- `enemy_large_body_contract_probe.gd`

L'avertissement Windows `Failed to read the root certificate store` apparaît sans erreur projet ni code de sortie non nul. `git diff --check` sur les scripts/probes du périmètre ne rapporte aucune erreur d'espacement, seulement les avertissements LF/CRLF du worktree Windows.

## Conclusion

Le périmètre architecture/navigation/foule est **DONE**. Les deux P3 restants portent sur la force d'une preuve temporelle et une ligne historique de documentation; ils ne décrivent pas de régression runtime active.
