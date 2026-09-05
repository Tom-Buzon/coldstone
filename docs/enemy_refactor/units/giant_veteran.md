# Audit final distinct — `giant_veteran`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable (`5b4e0cb0f`)**\
**Renderer des probes : `gl_compatibility`, headless**\
**Portée : état courant du worktree; audit central en lecture seule, écriture limitée à ce rapport et aux logs temporaires.**

## Verdict synthétique

`giant_veteran` est une variante fonctionnelle et réellement différenciée du géant standard : 860 PV, vitesse et portée accrues, quatre actions de phase 1, transition à 48 % de vie puis trois actions de rage, multiplicateurs explicites de vitesse/dégâts, locomotion `LARGE_BODY`, traversal assisté et démembrement complet. Les probes exacts passent la factory, les décisions loin/proche, le cycle des quatre attaques initiales, l'interruption anatomique, la perte de cible, le sommeil/réveil, la transition atomique de phase 2, la récupération après blocage, la capsule primitive, les douze zones anatomiques, les dix sections logiques et le teardown.

La preuve géométrique familiale passe aussi le contrat complet du géant escaladable : cylindre de torse lisse, tête extraite du mesh réel, sommet marchable, absence de faux sol sur les jambes, wall-run, crawl après perte des deux jambes et zone de dégâts encore accessible. Ce probe instancie actuellement `giant_standard` à échelle Forge 3, pas le vétéran. Cette portée n'est pas extrapolée silencieusement : les deux variantes partagent le package `geant1`, le profil anatomique, les réglages de traversal et le même code central, tandis que les probes exacts du vétéran couvrent séparément son profil, son mode `LARGE_BODY`, sa capsule, son rig et ses douze zones.

Verdict : **DONE**. Aucune panne fonctionnelle reproductible propre à `giant_veteran` n'est observée. Les limites restantes sont explicites : steering `LARGE_BODY` sans détour topologique, preuve traversal familiale plutôt que paramétrée par ID, donneurs d'animation encore nécessaires, phase 2 vérifiée contractuellement mais pas rendue en séquence vidéo, et coût hors budget à 56 géants actifs. Aucun donneur ni asset source ne doit être supprimé sur la base de cet audit.

## Profil canonique et différenciation vétéran

Source de vérité : `scripts/enemy/enemy_archetypes.gd:978-1038`, normalisée puis exposée par le Resource typé `HopliteEnemyArchetypeData`. `EnemyFactory.spawn_request()` applique profil, package, cible, participation et options avant l'entrée dans l'arbre.

| Champ | Vétéran | Standard | Différence utile |
|---|---:|---:|---|
| rôle / rang | `solo_giant_veteran` / `elite` | `solo_giant_standard` / `elite` | identité dédiée |
| PV | `860` | `520` | +65,4 % de masse de combat |
| vitesse | `3,95 m/s` | `3,65 m/s` | poursuite plus pressante |
| dégâts | `40` | `32` | frappe plus punitive |
| portée / aggro | `2,38 / 30 m` | `2,20 / 26 m` | lecture et engagement élargis |
| cooldown de base | `0,82-1,12 s` | `1,02-1,34 s` | cadence supérieure |
| animation / poise | `1,12 / 0,72` | `1,02 / 0,56` | vétéran plus agressif et stable |
| pattern | `4 + 3` en phase 2 | `3`, monophasé | rage propre au vétéran |

Le profil reste `unarmed`, comportement `brute`, défense `none`, scale `1.00`. Le poids procédural `0.0` et `first_wave=99` excluent volontairement ce géant de la sélection aléatoire normale; il demeure disponible par placement Forge et probes. Son coût procédural déclaré est `9.20`.

## Routes réelles

- **Factory** : l'ID exact résout `geant1-1787584159710.glb`; la validation 22/22 confirme famille `giant_geant1`, rig `package_retarget`, anatomie `12/12`, équipement `unarmed`, opener `veteran_punch` et navigation `LARGE_BODY`.
- **Forge — bibliothèque** : `world_editor.gd` énumère les trois `giant_ids()` dans la catégorie des géants escaladables. Le bouton crée une unité avec hitbox parfaite, mode `assisted`, capsule `0.90/1.00` et sommet marchable.
- **Forge — runtime** : `world_runtime.gd` transmet ces propriétés au SpawnRequest puis à la factory. `world_editor_probe.gd` passe avec `entities=28`, `mobs=311`.
- **Forge — preuve visuelle** : la capture 22/22 est produite par un vrai `HopliteWorldDocument` matérialisé par `HopliteWorldRuntime`.
- **Combat Lab** : la preuve mission ouvre la vraie scène `combat_lab.tscn` et lui ajoute l'annexe des 22 IDs par factory. Elle valide le contexte et la présence, sans prétendre à une station historique dédiée au vétéran.
- **Campagnes/procédural** : aucune sélection aléatoire normale, conformément à `procedural_weight=0.0`. Ce n'est pas une route manquante mais un choix de roster explicite.

## IA, combat et phase 2

Le contrôleur commun conserve acquisition de cible, approche, attente de permission, windup, recovery, blessure, sommeil et mort. La perte de cible, le sommeil, l'incapacité et la mort retirent l'autorité d'attaque et libèrent le lease partagé.

### Phase 1

| Action | Clip externe | Windup | Recovery | Cooldown | Identité mécanique |
|---|---|---:|---:|---:|---|
| `veteran_punch` | `giant_punch` | `0,36 s` | `0,32 s` | `0,68 s` | dégâts x`1,06`, portée x`1,02`, lunge `3,4` |
| `veteran_swipe` | `giant_swipe` | `0,44 s` | `0,38 s` | `0,80 s` | portée x`1,24`, arc `-0,46` |
| `veteran_roar` | `giant_roar` | `0,62 s` | `0,30 s` | `1,25 s` | télégraphe sans dégâts |
| `veteran_jump_crush` | `giant_jump_attack` | `0,68 s` | `0,64 s` | `1,52 s` | dégâts x`1,34`, shockwave `3,25 m`, lunge `5,8` |

`enemy_unit_behavior_probe -- --id=giant_veteran` démarre et résout les quatre entrées via le scheduler réel, vérifie les objectifs bornés loin/proche, l'interruption sans dégât, la cible détruite sans lease résiduel, le sommeil/réveil et le nettoyage.

### Phase 2 — rage à 48 %

La transition est atomique : le windup de phase 1 est annulé, le curseur repart à zéro, le cooldown est remis à zéro, la vitesse passe à x`1,10`, les dégâts à x`1,12`, et un unique signal `combat_phase_changed(..., 2)` est émis. Le probe exact observe `transitions=[2]` et le pattern runtime déclaré dans l'ordre :

1. `veteran_rage_swipe` — windup/recovery `0,32/0,30 s`, cooldown `0,56 s`, portée x`1,28`, arc `-0,58`;
2. `veteran_rage_jump` — `0,54/0,50 s`, cooldown `1,06 s`, dégâts x`1,46`, shockwave `3,65 m`, lunge `6,4`;
3. `veteran_flex` — télégraphe sans dégâts, `0,46/0,24 s`, cooldown `0,90 s`.

Il n'existe aucune phase 3 déclarée; le probe confirme `phase3_actions=0`. Les timings, dégâts et vitesses n'ont pas été ralentis pour la performance.

## Navigation `LARGE_BODY`

Le vétéran sélectionne explicitement le mode commun `LARGE_BODY`, distinct du `NAVMESH_GROUND` des fantassins. Ce mode n'instancie volontairement pas de `NavigationAgent3D`; il produit une intention directe et expose des diagnostics/récupérations communs.

Le probe exact `enemy_large_body_contract_probe -- --id=giant_veteran` valide :

- mode `LARGE_BODY`, aucun faux NavigationAgent et facteur de vitesse `0.78`;
- timeout de blocage `1,15 s` puis récupération latérale bornée `0,72 s`;
- une seule première tentative de recovery après obstruction simulée;
- progrès de dégagement sans `navigation_failed` prématuré;
- arrivée dans la tolérance et retour à l'état `idle` après clear;
- capsule principale primitive, aucune forme concave dynamique, échelle racine uniforme;
- nettoyage final.

Limite fonctionnelle : ce steering détecte le blocage et tente un dégagement, mais ne promet pas un détour topologique dans un labyrinthe. Si de futurs mondes Forge imposent des passages complexes, un navmesh dédié au grand rayon devra être mesuré contre cette locomotion sans en sacrifier la masse ni la cadence.

## Traversal, crawl et physique

Avec `match_perfect_hitbox=true`, le chemin assisté conserve une capsule primitive pour le sol interne, un `AnimatableBody3D` sur la couche 256 avec cylindre lisse du torse/épaules, un hull convexe dérivé du vrai mesh de tête, et un unique `HeadFloor` aligné sur le sommet réel.

Le probe familial `giant_traversal_probe.gd` passe : torse atteint depuis quatre directions, normales compatibles wall-run, tête classée `giant_enemy`, aucun facet de jambe considéré comme sol, sommet à moins de 6 cm du mesh, seam corps/tête bornée, puis crawl après section des deux cuisses. Mesures principales : hull tête `(0.879, 0.988, 0.917)`, `false floor count=0`, cylindre crawl `height=2.163`, `radius=0.863`, zone de dégâts torse encore atteignable avec rayon `1.02`.

Le crawl exact découle du contrat anatomique partagé : une jambe force la boiterie; deux jambes passent la vitesse à `0.72`, abaissent/inclinent le visuel, raccourcissent la capsule et recalculent le traversal. La géométrie du probe utilise `giant_standard` x3; le démembrement et le collider principal du vétéran sont, eux, validés sur son ID exact.

## Package, rig, animations et LOD

Package gagnant : `res://assets/characters/3dgen_demo/geant1-1787584159710.glb`.

- taille : `19 130 652` octets;
- SHA-256 : `B4AA088487AE945FA3CE0CDD5008A33D96AAB053CD7DAA500153D6CBA305CD16`;
- import glTF `scene`, tangentes, LOD et shadow meshes générés, named skins, animations à 30 FPS, tracks immuables retirées;
- squelette visuel segmenté validé à 53 os;
- donneur UAL1 caché conservé pour locomotion/mort et bridge rest-space;
- driver natif spécialisé pour les cinq clés externes `giant_punch`, `giant_swipe`, `giant_roar`, `giant_jump_attack`, `giant_flex`.

Le roster affiche `pattern=4/3 donors=5 package=geant1`; ce compteur `donors=5` décrit les cinq catégories externes demandées, pas cinq squelettes visibles simultanés. Le probe animation confirme l'opener réel :

```text
ANIMATION GEANT — VETERAN visual=retarget opener=veteran_punch clip=external:giant_punch
```

Le LOD commun passe les routes shared/native/direct : cadence réduite aux niveaux intermédiaires, sommeil lointain et réveil réversible, sans désactivation définitive d'un AnimationTree. La capture six états prouve visuellement que le mesh est piloté et non figé. L'UAL1, les clips externes et le package segmenté restent requis; aucune suppression n'est autorisée avant un remplacement multi-frame prouvé dans unité, Lab et Forge.

## Anatomie, démembrement et lifecycle

L'instance exacte construit douze hitboxes depuis le profil humanoïde sur le squelette du package. Le probe applique une section localisée à une instance fraîche par zone et obtient `zones=12 severed=10`.

| Zones | Contrat |
|---|---|
| tête / cou | section létale; la mort passe toujours par `_die()` |
| torse / bassin | dégâts localisés, non sectionnables |
| bras/avant-bras L/R | membres détachés; côté droit annule windup et capacité d'attaque |
| cuisses/tibias L/R | boiterie; perte bilatérale déclenche le crawl |

La mort est atomique : cible, attaque/lease, navigation, participation IA, groupes/registry/crowd et collisions sont retirés. Le probe transient passe TTL projectile/sang/débris/équipement, ressources partagées, retrait des collisions/ombres puis expiration; sa vérification de rayon monde pour fragment de géant utilise la famille à grande échelle. Les dix fragments exacts du vétéran sont couverts par le probe par zone.

## Performance — photographie actuelle

Commande :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_performance_benchmark.gd -- --counts=1,12,56 --mode=both --warmup=120 --frames=120 --seed=13371 --archetype=giant_veteran
```

Le harness conserve `mass_battle_mode=true`, le seuil global à 28, registry désactivé et 60 ticks/s. Les temps engine sont des snapshots diagnostiques; p95/p99 mesure l'intervalle mural cadencé. Le mode headless ne mesure ni draw calls ni VRAM.

| Mode | Unités | Spawn ms | Process / physics ms | Nœuds | Objets | Mémoire statique | Corps actifs | Tick p95 / p99 / max ms | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| idle | 1 | 52.656 | 0.602 / 0.580 | 80 | 1 755 | 53 778 257 o | 0 | 20.699 / 20.751 / 20.757 | PASS |
| idle | 12 | 206.126 | 4.477 / 1.631 | 894 | 2 756 | 59 133 907 o | 0 | 20.718 / 20.817 / 20.847 | PASS |
| idle | 56 | 801.704 | 17.242 / 2.439 | 4 150 | 6 760 | 80 251 359 o | 0 | 25.549 / 33.752 / 34.134 | PASS |
| actif | 1 | 60.926 | 0.694 / 0.916 | 81 | 1 758 | 55 348 781 o | 1 | 20.701 / 20.715 / 20.716 | PASS |
| actif | 12 | 212.739 | 6.465 / 4.580 | 906 | 2 781 | 60 497 155 o | 12 | 20.705 / 20.725 / 20.979 | PASS |
| actif | 56 | 804.284 | 25.589 / 12.686 | 4 206 | 6 873 | 81 201 163 o | 56 | **33.863 / 37.533 / 38.348** | PASS structurel |

À 56 actifs, `process + physics = 38.275 ms` : cette densité est hors budget 60 Hz. À 12 actifs, le snapshot combiné est `11.045 ms`, mais l'intervalle mural Windows reste cadencé autour de 20,7 ms; il ne doit pas être converti en FPS indépendant. Les six scénarios libèrent tous leurs WeakRefs et groupes de combat.

Il n'existe aucune baseline phase 0 strictement comparable propre à `giant_veteran`; l'état initial mesurait l'archétype par défaut et la famille hoplite. Le tableau ci-dessus constitue donc la photographie **après** et aucun pourcentage de gain unitaire n'est inventé. La comparaison familiale courante avec `giant_novice` est proche et cohérente, mais n'est pas un avant/après.

## Preuves visuelles inspectées

- `docs/enemy_refactor/visual_evidence/giant_veteran.png` (1 351 × 760) : `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`. Les six silhouettes sont distinctes; le jog lève nettement une jambe, la mort est au sol, la section montre le moignon/fragment. Aucun T-pose grossier ni équipement parasite.
- `docs/enemy_refactor/lab_full_roster_visual_probe.png` : vétéran présent dans le roster 22/22 sur l'annexe de la vraie scène Lab, posé et animé.
- `docs/enemy_refactor/forge_full_roster_visual_probe.png` : vétéran présent dans le vrai document/runtime Forge. L'éclairage est très chaud et les labels petits; cette vue prouve intégration et présence, pas une inspection fine de texture.

Une image statique ne remplace pas une vidéo de la transition de rage. Le probe de phase couvre les données, l'ordre, les multiplicateurs et l'atomicité; une capture multi-frame phase 1→2 resterait une amélioration de preuve visuelle.

## Tests exécutés

| Test | Résultat | Portée / réserve |
|---|---|---|
| `enemy_unit_dismemberment_probe.gd -- --id=giant_veteran` | PASS `zones=12 severed=10` | exact, fatalités, fragments, teardown |
| `enemy_unit_behavior_probe.gd -- --id=giant_veteran` | PASS | exact, loin/proche, quatre attaques, interruption, cible perdue, sleep/wake, cleanup |
| `enemy_phase_contract_probe.gd -- --id=giant_veteran` | PASS `transitions=[2] actions=3/0` | exact, transition atomique, multiplicateurs, ordre phase 2 |
| `enemy_large_body_contract_probe.gd -- --id=giant_veteran` | PASS | exact, recovery bornée, capsule primitive, arrivée/clear |
| `enemy_full_roster_validation_probe.gd` | PASS `22/22` | exact : famille, rig, 12/12, unarmed, opener, navigation |
| `enemy_roster_audit.gd` | PASS `22/22` | exact : `pattern=4/3 donors=5 package=geant1` |
| `enemy_animation_probe.gd` | PASS `14/14` | exact opener `veteran_punch -> giant_punch` |
| `giant_traversal_probe.gd` | PASS | famille `geant1`, tête/sol/wall-run/crawl; fixture standard x3 |
| `enemy_combat_probe.gd` | PASS | combat commun et traversal Forge assisté |
| `enemy_anatomy_regression_probe.gd` | PASS | mort létale atomique |
| `enemy_animation_lod_probe.gd` | PASS | shared/native/direct, cadence et réveil réversible |
| `enemy_transient_lifecycle_probe.gd` | PASS | TTL, ressources partagées, collisions/ombres retirées |
| `enemy_action_state_probe.gd` | PASS | priorités windup/recovery/parry/tactique |
| `wall_run_probe.gd` | PASS | classification des surfaces de géant et sorties |
| `world_editor_probe.gd` | PASS `entities=28 mobs=311` | sérialisation des propriétés de traversal |
| `enemy_performance_benchmark.gd` | PASS structurel `1/12/56`, idle/actif | limite CPU à 56 actifs documentée |

Les logs sont sous `.tmp_tools/enemy_refactor/giant_veteran_audit/`. L'avertissement Windows `Failed to read the root certificate store` est environnemental et n'altère aucun code de sortie. `giant_traversal_probe` et `wall_run_probe` signalent quelques ObjectDB/resources encore référencés à la fermeture de leur scène complète; leurs assertions métier passent, et le benchmark exact ainsi que les probes unitaires confirment séparément le teardown du vétéran. Cette dette de harness n'est pas masquée.

## Revue Godot 4.7

### Critique

Aucune panne critique propre à `giant_veteran` n'est reproduite.

### Améliorations / dette honnête

- Paramétrer `giant_traversal_probe.gd` par `--id` et exécuter les trois tiers pour supprimer l'extrapolation familiale.
- Étendre le probe de phase afin de démarrer/résoudre chaque action de rage après transition, puis rendre une séquence multi-frame phase 1→2.
- Comparer le steering `LARGE_BODY` à un navmesh grand gabarit si les parcours Forge exigent des détours complexes.
- Capturer une vraie séquence Forge avec escalade joueur et transition debout→crawl.
- Conserver `geant1`, UAL1 et les cinq clips externes jusqu'à remplacement complet prouvé; aucun donneur n'est supprimable aujourd'hui.
- Mesurer dans une fenêtre Compatibility/Forward+ draw calls, surfaces, triangles, matériaux, VRAM et qualité LOD; le headless ne couvre pas le GPU.
- Éviter des batailles de 56 géants actifs : la mesure dépasse nettement le budget CPU. Le seuil global 28 reste inchangé et ne recommande pas une telle densité pour cette famille lourde.
- Nettoyer les références résiduelles propres aux harness `giant_traversal`/`wall_run` lors d'une passe de tests, sans les confondre avec une fuite de l'instance exacte, dont les WeakRefs et groupes sont propres.

### Points solides

- Profil vétéran distinct, phase 2 déclarative et transition atomique prouvée.
- Factory unique, Resource typé et route Forge sérialisée.
- Package dédié présent, rig 53 os, anatomie segmentée et caps préservés.
- Quatre attaques initiales réellement démarrées/résolues, trois actions de rage ordonnées.
- Navigation `LARGE_BODY`, récupération et cleanup observables.
- Traversal assisté avec primitives lisses et tête dérivée du mesh réel.
- Crawl, dégâts localisés, section et lifecycle bornés.
- LOD animation réversible et aucune T-pose observée.

---

Revu contre les checklists Godot 4.3+ / 4.7 de navigation, animation, physique, assets, 3D, testing, debugging et code review.
