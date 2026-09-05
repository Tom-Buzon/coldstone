# Rapport final — audit, unification et optimisation des ennemis

Date : 2026-08-26\
Moteur : Godot 4.7 stable (`5b4e0cb0f`)\
Renderer de validation : `gl_compatibility`\
Verdict : **DONE — 22/22 unités**

## Résumé exécutif

Avant la mission, la phalange ne franchissait pas son gate collectif, plusieurs responsabilités de spawn/targeting/navigation étaient dispersées, les probes crowd/géant étaient rouges et les preuves rendues/performance étaient incomplètes. Après intégration, les 22 identités sont construites par une factory unique, alimentées par des profils typés/cachés, et validées individuellement sur comportement, animation, navigation, équipement, anatomie localisée, démembrement, mort et teardown. Les routes Battle, Combat Lab, procédurales et Forge convergent sur le même runtime. Le seuil historique `mass_battle_mode = 28` est inchangé.

Aucune source GLB/FBX, aucun rig et aucun donneur n'a été supprimé. Le seul chemin où les donneurs ont effectivement été éliminés est la famille `ngeneral`, qui possède une bibliothèque d'animations partagée avec preuve visuelle et fonctionnelle complète. Toutes les autres suppressions restent interdites sans preuve comparative supplémentaire.

## Architecture

```text
profil typé/cache ──> EnemyFactory ──> AthenianEnemy (CharacterBody3D, seul propriétaire du mouvement)
                                         │
                                         ├─ EnemyNavigationComponent (RefCounted : intention/récupération)
                                         │    └─ NavigationAgent3D uniquement pour NAVMESH_GROUND
                                         ├─ BattleCrowdDirector
                                         │    ├─ grille spatiale 20 Hz
                                         │    ├─ cohortes/slots persistants
                                         │    └─ leases FIFO d'attaque
                                         ├─ anatomie 12 zones / conséquences de section
                                         ├─ équipement, garde et rayon physique monde
                                         └─ animation
                                              ├─ direct Mixamo
                                              ├─ package + retarget natif
                                              └─ bibliothèque partagée ngeneral
```

Les frontières importantes sont maintenant explicites :

- une seule construction runtime dans `enemy_factory.gd` et une requête typée `EnemySpawnRequest` ;
- une seule source de vérité de profil, avec copie legacy isolée et cache d'adaptateurs typés ;
- un seul propriétaire de `velocity` et `move_and_slide()` ; le composant de navigation ne retourne qu'une intention ;
- participation IA atomique entre groupes, registre, crowd, destination, cible et lease ;
- mort atomique : l'ennemi quitte immédiatement l'IA/crowd, libère cible/lease/navigation puis désactive les collisions pertinentes ;
- cohortes stables malgré changement de cible, promotion d'un survivant de soutien dans une vacance de première ligne et progression dégradée 2/4 bornée ;
- scheduler à jetons/générations et équité FIFO, commun aux attaques mêlée et projectile ;
- LOD d'animation réel à environ 30/12/0 Hz pour les trois routes, avec restauration du callback et échantillon forcé au réveil ;
- ressources procédurales immuables partagées, durée de vie bornée des projectiles/sang/débris/équipements et ombres/collisions retirées avant libération.

La spécification détaillée est dans `ENEMY_ARCHITECTURE.md`.

## Tableau par unité

`N/A — baseline non capturée` signifie qu'aucune mesure phase 0 propre à cet ID n'existe; une valeur familiale n'est jamais substituée. Les mesures courantes restent publiées dans chaque fiche sans être présentées comme un avant/après.

| Unité | Logique | Navigation | Rig | Donneurs retirés | Mesh | Démembrement | Tests | Perf avant | Perf après | Statut |
|---|---|---|---|---|---|---|---|---|---|---|
| `swordsman` | mêlée épée/aspis, 3 variantes | direct | Mixamo direct | aucun, conservés | pool Mixamo | 12/12, 10/10 | exact PASS | phase 0 exacte | finale exacte (`final_metrics.json`) | DONE |
| `guardian` | garde lourde, axe/bash | direct | Mixamo direct | aucun, conservés | pool Mixamo | 12/12, 10/10 | exact PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `spearman` | lance/aspis, phalange legacy | direct | Mixamo direct | aucun, conservés | pool Mixamo | 12/12, 10/10 | exact PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `flanker` | orbite et flanc rapide | direct | Mixamo direct | aucun, conservés | pool Mixamo | 12/12, 10/10 | exact PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `brute` | lourd, axe, poise | direct | Mixamo direct | aucun, conservés | pool Mixamo | 12/12, 10/10 | exact PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `captain` | élite, shield bash | direct | Mixamo direct | aucun, conservés | Knights 1/2/3 authored | 12/12, 10/10 | exact + variantes PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `warlord` | boss, phase II 2 actions | direct | Mixamo direct | aucun, conservés | pool 4 modèles | 12/12, 10/10 | exact + phase PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `boss_colossus` | crush/quake monophasé | LARGE_BODY | package + retarget | aucun, requis | GLB segmenté | 12/12, 10/10 | exact + grand corps PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `boss_bronze` | thrust/sweep miniboss | direct | package + retarget | aucun, requis | GLB/Knights authored | 12/12, 10/10 | exact + variantes PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `nathenian1` | infanterie légère épée/aspis | direct | package léger UAL1 | aucun, requis | GLB segmenté | 12/12, 10/10 | exact + fallback PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `nsbire1` | levée, outil agricole | direct | package léger UAL1 | aucun, requis | GLB segmenté | 12/12, 10/10 | exact + fallback PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `nsbire2` | archer, tir/repli | direct | package + driver | aucun, requis | GLB segmenté | 12/12, 10/10 | exact projectile PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `nathenian2` | marteau, phase II | direct | package + driver | aucun, requis | GLB segmenté | 12/12, 10/10 | exact + phase PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `nathenian2_soldier` | alias troop monophasé distinct | direct | package partagé, profil isolé | aucun, requis | GLB segmenté partagé | 12/12, 10/10 | exact/alias PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `bronze_colossus` | juggernaut, phase II | LARGE_BODY | package + driver | aucun, requis | GLB segmenté | 12/12, 10/10 | exact + phase PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `ncenturion` | garde/signatures gladius | direct | package + driver | aucun, requis | GLB segmenté | 12/12, 10/10 | exact PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `ngeneral` | phalange, 4 actions | NavMesh/formation | bibliothèque partagée | tous donneurs runtime | mesh fusionné, 1 squelette | 12/12, 10/10 | exact + NavMesh/cohorte PASS | phase 0 exacte | finale exacte (`final_metrics.json`) | DONE |
| `ngeneral_veteran` | phalange vétéran | NavMesh/formation | bibliothèque partagée | tous donneurs runtime | mesh fusionné, 1 squelette | 12/12, 10/10 | exact + cohorte PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `giant_novice` | géant, 2 actions | LARGE_BODY | package + retarget | aucun, requis | GLB segmenté | 12/12, 10/10 | exact + traversal PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `giant_standard` | géant, 3 actions | LARGE_BODY | package + retarget | aucun, requis | GLB segmenté | 12/12, 10/10 | exact + traversal PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `giant_veteran` | géant, phase II | LARGE_BODY | package + retarget | aucun, requis | GLB segmenté | 12/12, 10/10 | exact + phase/traversal PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |
| `nfull_armor` | boss, phases II/III | direct | package + driver | aucun, requis | GLB cuirassé segmenté | 12/12, 10/10 | exact + 3 phases PASS | N/A — baseline non capturée | mesure courante dans fiche | DONE |

Chaque ligne possède sa fiche détaillée dans `docs/enemy_refactor/units/`. Le manifest machine-readable `roster_manifest.json` porte également `status: DONE` pour chaque ID.

## Corrections fonctionnelles majeures

- Une section létale finalise toujours `_die()` : aucune branche de démembrement ne laisse un acteur vivant à zéro PV.
- Le décès appelle la même frontière de participation atomique qu'un sommeil volontaire et ne laisse ni membre crowd, ni destination, ni lease.
- La phalange conserve son identité/slots lors des changements de cible, remplace une vacance et avance en mode dégradé si un membre bloque.
- Les attaques partagent des leases FIFO à génération ; cible perdue, désarmement, sommeil, mort et sortie d'arbre les invalident.
- Le chemin `nathenian1/nsbire1` joue maintenant réellement `Sword_Attack` hors mode masse au lieu de résoudre les dégâts en restant visuellement idle.
- Le package `captain/knight3` avec arme/bouclier authored reçoit des ancres de main ; la section cache le mesh authored et produit un remplacement physique détachable.
- Le rayon de requête du bouclier tient compte de l'échelle mondiale héritée.
- Une route possédant une `NavigationRegion3D` sélectionne automatiquement `NAVMESH_GROUND` pour ses unités terrestres non géantes; un vrai `ngeneral` créé par la factory conserve son facing de formation tout en suivant le détour NavigationServer. Couches incompatibles, carte absente et cible inaccessible ont une sortie diagnostiquée/fallback.
- Les géants et colosses utilisent des capsules/primitives, une intention LARGE_BODY ralentie et une récupération anti-blocage bornée ; aucun concave dynamique n'est introduit.
- Les cadavres ont un TTL général configurable de 12 s après leur pose; une gate de 36 morts confirme la libération de 36/36 corps, indépendamment du directeur procédural.
- Le probe procédural reflète l'invariant atomique : pendant l'entrée élite la cible transitoire est nulle mais le joueur stable reste câblé, puis la cible est restaurée au réveil.

## Preuves

- `enemy_full_roster_validation_probe`: PASS 22/22, identité/rig/anatomie/équipement/action/navigation/teardown.
- `enemy_unit_behavior_probe --id=<ID>`: PASS pour 22/22, décisions loin/proche, toutes les actions de phase I, interruption, perte de cible, sleep/wake.
- `enemy_unit_dismemberment_probe --id=<ID>`: PASS pour 22/22, 12 zones et 10 conséquences sectionnables par unité.
- `enemy_phase_contract_probe`: PASS pour les cinq profils à phases; `warlord` prouve sa transition et ses deux actions de phase 2, `nfull_armor` traverse `[2,3]`.
- `enemy_mixamo_variant_matrix_probe`: PASS sur 7 familles, 20 modèles et 240 zones cumulées; override cross-pool rejeté.
- `enemy_navigation_navmesh_probe`: vrai map/path/détour/retarget/arrivée et fallback carte vide.
- `enemy_mixed_stress_probe`: 22 familles, 36 unités, deux cohortes, cible mobile/changée, sleep/wake, 4 sections, 4 morts, cleanup.
- Probes scheduler, cohorte, crowd, registre/factory, factions, combat, archer, phalange, géants, LOD, matériaux, rayon de bouclier et transients : PASS.
- 22 planches individuelles `visual_evidence/<id>.png`, chacune avec 13 états : idle/jog nus, sprint, rotation, garde, attaque, impact déterministe, upper-body, LOD loin, sommeil, réveil, mort et section. Les variantes `captain__knight3` et `boss_bronze__knight3` prouvent aussi l'équipement authored.
- Captures actualisées `lab_full_roster_visual_probe.png` et `forge_full_roster_visual_probe.png`, 22/22 visibles dans les vraies routes; elles distribuent locomotion, garde, impact, attaque, section et mort avec assertions.

Les captures globales prouvent présence/pose, pas la qualité marketing en gros plan. Les planches individuelles et les probes exacts portent la preuve détaillée.

## Avant/après global

Le seuil de 28 n'a pas été abaissé. Tous les scénarios finaux terminent avec zéro référence ennemie live, zéro membre combatant résiduel et teardown structurel PASS.

Le composant de navigation a d'abord ajouté un nœud par IA active. Cette version a été rejetée : après migration du service vers `RefCounted`, `swordsman active 28` revient de 902 à 874 nœuds, exactement la baseline. À 36 swordsmen, les objets passent de 3 558 à 3 529 (−29) et la mémoire statique augmente de 0,6 %. À 36 `ngeneral` actifs, les nœuds restent identiques à la baseline mais les objets montent de 76 et la mémoire de 1,5 %; cette dette est conservée explicitement.

Le harness non cadencé à 56 ennemis donne les budgets de clôture p50/p95 : `2 720/4 702 µs` (steady), `10 435/14 254 µs` (realistic), `11 029/14 694 µs` (mixed). Les anciennes références utilisaient une version/configuration différente du harness : leurs pourcentages sont retirés et aucun gain CPU causal n'est revendiqué. Les temps de spawn et plusieurs snapshots lents ont augmenté et restent publiés dans `PERFORMANCE.md`/`final_metrics.json`.

La gate de stabilité 5 × 36 atteint exactement `1 596` objets après chacun des quatre cycles post-préchauffage, zéro référence/groupe résiduel et un span mémoire de `2 436 B`.

Mesures rendues actuelles en action, sans baseline GPU comparable : Forge 377 draw calls / 672 430 primitives / 637,7 MB vidéo; Lab complet 1 171 / 1 021 459 / 1,565 GB. Elles servent de budget futur, pas de pourcentage de gain.

Le tableau suivant distingue systématiquement absence de mesure et zéro variation. Le scénario comparable chiffré est `swordsman active 36`; `ngeneral active 36` est ajouté lorsqu'il possède sa propre baseline. Les compteurs jamais capturés en phase 0 restent `N/A`.

| Compteur demandé | Avant comparable | Après | Écart |
|---|---:|---:|---:|
| CPU process, swordsman actif 36* | `4.694 ms` | `5.514 ms` | `+17.5 %` |
| Physique, swordsman actif 36* | `6.880 ms` | `9.999 ms` | `+45.3 %` |
| Frame time/p95 cadencé, swordsman actif 36* | `20.715 ms` | `20.719 ms` | `+0.02 %` |
| FPS rendu comparable | N/A — headless initial | N/A — pas de paire rendue | N/A |
| IA/callback région 56 | N/A — harness v2 absent | p95 `4.702/14.254/14.694 ms` | N/A |
| NavigationServer | N/A — absente de la baseline | probe réel PASS, CPU non isolé | N/A |
| Animation/formation CPU isolés | N/A — non capturés | intégrés au callback courant | N/A |
| Draw calls | N/A — non capturés | Forge `377`, Lab `1171` | N/A |
| Nœuds, swordsman actif 36 | `1122` | `1122` | `0.0 %` |
| Nœuds, ngeneral actif 36 | `2562` | `2562` | `0.0 %` |
| Objets, swordsman actif 36 | `3558` | `3529` | `−0.8 %` |
| Objets, ngeneral actif 36 | `5175` | `5251` | `+1.5 %` |
| Squelettes/os par ngeneral | N/A — détail non capturé | `1 / 53` | N/A |
| AnimationPlayers/Trees par ngeneral | N/A — détail non capturé | `1 / 1` | N/A |
| Donneurs/retargeters par ngeneral | N/A — détail non capturé | `0 / 0` | N/A |
| Meshes/surfaces/triangles globaux | N/A — non capturés | primitives Forge `672430`, Lab `1021459` | N/A |
| Collisions/hitboxes | N/A — détail non capturé | primitives uniquement, anatomie `12/12` | N/A |
| Mémoire statique, swordsman actif 36 | `101403959 B` | `102048358 B` | `+0.6 %` |
| Mémoire statique, ngeneral actif 36 | `67404461 B` | `68434080 B` | `+1.5 %` |
| VRAM | N/A — non capturée | Forge `637740090 B`, Lab `1564909673 B` | N/A |
| Spawn, swordsman actif 36 | `587.715 ms` | `743.102 ms` | `+26.4 %` |
| Spawn, ngeneral actif 36 | `266.736 ms` | `381.639 ms` | `+43.1 %` |
| Mort/nettoyage répété | N/A — cycle absent | 5×36, objets post-warm `1596`, span `0` | N/A |

\* Instantanés Godot à rafraîchissement lent; ils sont publiés comme diagnostics, pas comme attribution CPU causale. Les hausses mesurées ne sont pas maquillées en optimisation.

## Actions entreprises

- Fichiers créés : profils/requêtes typés, registre, navigation `RefCounted`, bibliothèque hoplite partagée, lifecycle des débris, probes, métriques, 22 fiches et contre-revues.
- Fichiers runtime principaux modifiés : factory/archetypes/ennemi, crowd director, drivers/retarget, packages, hitboxes/équipement/gore, routes Battle/procédurales/Lab/Forge.
- Composants ajoutés : navigation commune avec NavMesh/fallback/récupération, grille/cohortes/slots, scheduler FIFO à génération, cache de profils, participation atomique et TTL bornés.
- Systèmes remplacés : navigation-node pilote rejetée au profit du service `RefCounted`; targeting dispersé adapté au registre; branche hoplite donneur remplacée par bibliothèque partagée là où la parité est prouvée.
- Tests ajoutés : roster 22/22, comportement/démembrement par ID, cinq phases, variantes, NavMesh réel, cohortes, scheduler, lifecycle/cadavres, stress 36, reload 5×36, Lab/Forge et benchmarks.
- Ressources générées/versionnées : bibliothèque hoplite v3, 22 planches treize états, variantes Knight3 et captures Lab/Forge.
- Correctifs fonctionnels : réveil physique, invalidation scheduler au disable, throttling de retarget, promotion de cohorte, impact déterministe, attaque package visible, phases, collisions primitives et teardown.
- Optimisations : zéro nœud de navigation hors véritable agent, cadence crowd 20 Hz, LOD animation 30/12/0 Hz, caches immuables, cleanup/ombres/collisions bornés.

## Risques et dette restante

- Le steering direct/LARGE_BODY offre une récupération locale, pas un détour topologique garanti; le détour topologique dépend de la présence d'une région de navigation valide dans la route.
- Plusieurs packages conservent un donneur UAL1 caché et/ou des sources externes sélectives. Ils sont fonctionnels mais coûteux; aucune suppression n'est autorisée sans nouvelle preuve rendue et mesure comparative.
- Les géants homogènes à 56 actifs et certains packages lourds dépassent le budget 16,67 ms dans leurs benchmarks ciblés. Le seuil de gameplay demeure 28; les chiffres détaillés restent dans les fiches.
- Les timings `TIME_PROCESS`/`TIME_PHYSICS_PROCESS` et intervalles paced sont sensibles au rafraîchissement/scheduler. Les données sont conservées mais ne servent pas seules à attribuer une régression.
- Les preuves globales Lab/Forge restent des vues d'ensemble et les planches sont composées de plusieurs instances; une validation marketing/cinématique demanderait encore des vidéos/gros plans.
- Le vieux `forge_hoplite_animation_probe` peut boucler sur un joueur sorti de l'arbre en headless. La route actuelle est couverte par `world_editor_flow_probe` et la capture Forge 22/22; ce harness historique n'est pas une gate finale.
- Le warning Windows de magasin de certificats et certains warnings de lifecycle audio/UI sont externes aux ennemis et n'affectent pas les codes de sortie retenus.

## Livrables

- `BASELINE.md` et `baseline_metrics.json` : état initial reproductible.
- `ENEMY_ARCHITECTURE.md` : architecture et contrats d'ownership.
- `roster_manifest.json` et `ORCHESTRATION_LEDGER.md` : roster/statuts.
- `REGRESSION_MATRIX.md` : gate final et historique détaillé.
- `PERFORMANCE.md` et `final_metrics.json` : mesures, limites et logs sources.
- `units/*.md` : 22 audits distincts.
- `visual_evidence/*.png`, captures Lab et Forge : preuves rendues.
- `reviews/*.md` : contre-revues indépendantes finales.

## Conclusion

La mission est clôturable : **22/22 unités DONE**, zéro blocage fonctionnel connu dans le périmètre ennemi, aucune suppression de donneur non prouvée, seuil 28 conservé, preuves visuelles et par-zone complètes, architecture unifiée et teardown propre. Les dettes de performance et de qualité de preuve encore ouvertes sont quantifiées et ne sont pas transformées en gains artificiels.
