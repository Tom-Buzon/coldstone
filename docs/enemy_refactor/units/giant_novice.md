# Audit final distinct — `giant_novice`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable (`5b4e0cb0f`)**\
**Renderer des probes : `gl_compatibility`, headless**\
**Portée : état courant du worktree; audit central en lecture seule, écriture limitée à ce rapport et aux logs temporaires.**

## Verdict synthétique

`giant_novice` est une unité fonctionnelle et distincte : troupe géante non armée, 280 PV, comportement `brute`, deux attaques ordonnées (`novice_punch`, `novice_swipe`), package segmenté `geant1`, locomotion `LARGE_BODY` et traversal assisté activable depuis la Forge. Les probes exacts passent la factory, les décisions loin/proche, le cycle réel des deux attaques, la perte de cible, le sommeil/réveil, la récupération après blocage, la capsule primitive, les douze zones anatomiques, les dix sections logiques et le teardown.

La preuve géométrique familiale passe aussi le contrat complet du géant escaladable : sol réel, cylindre de torse lisse atteignable depuis quatre directions, absence de facettes de jambes prises pour un sol, collider de tête extrait du mesh réel, stabilisateur au sommet de la tête, seam corps/tête, crawl après perte des deux jambes, hitbox de dégâts encore atteignable et wall-run encore classé comme géant. Ce probe instancie actuellement `giant_standard` à échelle Forge 3, et non le novice; ce n'est pas extrapolé silencieusement : les trois tiers utilisent le même package `geant1`, les mêmes réglages de traversal et les mêmes fonctions partagées, tandis que les probes exacts du novice valident séparément sa sélection `LARGE_BODY`, son profil, son rig et son anatomie.

Verdict : **DONE**. Aucune panne fonctionnelle reproductible propre à `giant_novice` n'est observée. Les réserves restantes sont documentées : steering `LARGE_BODY` sans pathfinding topologique, couverture géométrique familiale plutôt qu'un second probe strictement paramétré par ID, donneurs d'animation encore requis, et budget CPU dépassé à 56 instances actives dans le harness headless. Aucun asset ni donneur ne doit être supprimé sur la base de cet audit.

## Profil canonique et identité

Source de vérité : `scripts/enemy/enemy_archetypes.gd:875-924`, normalisée par `profile()` puis encapsulée dans le Resource typé `HopliteEnemyArchetypeData`. La factory (`scripts/enemy/enemy_factory.gd:13-84`) reste l'unique point de construction et applique profil, package, cible, participation et options avant l'entrée dans l'arbre.

| Champ | Valeur |
|---|---:|
| nom / rôle / rang | `GEANT — NOVICE` / `solo_giant_novice` / `troop` |
| famille validée | `giant_geant1` |
| skin / échelle de profil | `brute` / `1.00` |
| PV / vitesse | `280` / `3.35 m/s` |
| dégâts / portée / aggro | `25` / `2.05 m` / `23 m` |
| arme / bouclier | `unarmed` / aucun |
| comportement / style | `brute` / `giant_novice` |
| windup / recovery | `0.54 s` / `0.52 s` |
| cooldown | `1.32-1.62 s` |
| vitesse d'animation | `0.92` |
| bande préférée | `0-1.95 m` |
| rayon tactique / séparation / approche | `2.25` / `1.80` / `0.82` |
| défense / poise | aucune / `0.38` |
| traversal Forge | hitbox parfaite, `assisted`, rayon x`0.90`, hauteur x`1.00`, sommet marchable |
| procédural | coût `4.20`, poids `0.0`, première vague `99` |
| package résolu | `res://assets/characters/3dgen_demo/geant1-1787584159710.glb` |

Le poids nul et la première vague 99 signifient que le novice n'entre pas dans la sélection aléatoire normale. Il demeure volontairement disponible comme placement explicite Forge/probe. Il n'a ni phase 2 ni phase 3 déclarée : ce rang `troop` reste monophasé; aucune phase de boss n'a été inventée.

## Routes réelles

- **Forge — bibliothèque** : `scripts/world_editor/world_editor.gd:877-883` énumère les trois `giant_ids()` dans `GEANTS ESCALADABLES — SOLO / PETIT GROUPE`. Le bouton du novice crée un `enemy_group` d'une unité avec hitbox parfaite, mode `assisted`, multiplicateurs de capsule et sommet marchable.
- **Forge — runtime** : `scripts/world_editor/world_runtime.gd:293-323` traduit le document en appel factory et conserve `match_perfect_hitbox`, `giant_traversal_mode`, les multiplicateurs et `giant_walkable_tops`. `world_editor_probe.gd` confirme la normalisation/sérialisation de ces propriétés.
- **Forge — preuve visuelle** : `enemy_lab_forge_full_roster_visual_probe.gd -- --context=forge` construit un vrai `HopliteWorldDocument`, le matérialise avec `HopliteWorldRuntime` et obtient une unité pour chacun des 22 IDs. La capture existante montre le novice posé et animé dans ce roster.
- **Combat Lab** : la capture mission ouvre la vraie scène `combat_lab.tscn` puis ajoute une annexe des 22 IDs via la factory. C'est une preuve d'intégration au contexte réel, pas l'affirmation que le Lab historique possédait déjà une station native dédiée au novice.
- **Probes** : c'est la route primaire explicitée dans le manifeste. Les probes exacts utilisent l'ID canonique, sans alias ni substitution.

La ligne du roster global est sans ambiguïté :

```text
id=giant_novice family=giant_geant1 rig=package_retarget
anatomy=12/12 equipment=unarmed action=novice_punch navigation=LARGE_BODY
```

## IA et attaques

Le contrôleur commun conserve des états explicites pour acquisition de cible, approche, attente de permission, windup, recovery, blessure, sommeil et mort. La cible et le droit d'attaque utilisent les services partagés; perte de cible, sommeil et mort libèrent le lease et retirent l'unité de la participation active.

### Cycle exact

| Action | Animation externe | Windup | Recovery | Cooldown | Identité mécanique |
|---|---|---:|---:|---:|---|
| `novice_punch` | `giant_punch` | `0.58 s` | `0.50 s` | `1.28 s` | dégâts x`1.00`, portée x`0.96`, full-body |
| `novice_swipe` | `giant_swipe` | `0.68 s` | `0.62 s` | `1.55 s` | dégâts x`0.86`, portée x`1.10`, arc large `-0.18`, full-body |

`enemy_unit_behavior_probe -- --id=giant_novice` force le scheduler réel à démarrer puis résoudre chaque entrée. Il observe deux étapes distinctes, vérifie un objectif borné loin et proche, détruit la cible puis confirme l'absence d'autorité d'attaque/lease, désactive et réactive la participation, et termine sans membre `combatant_ai` résiduel.

La branche d'interruption par `sword_dropped` n'est volontairement pas applicable à une unité `unarmed`. En revanche, le contrat anatomique commun reste strict : la section du bras ou de l'avant-bras droit rend `_can_ai_attack()` faux et `_refresh_injury_state()` annule immédiatement tout windup. Le probe par zone vérifie bien la section de ces membres sur une instance exacte; un probe futur pourrait joindre ces deux assertions dans le même scénario temporel.

## Navigation `LARGE_BODY`

`scripts/enemy/athenian_enemy.gd:689-706` force explicitement `LARGE_BODY` pour les trois géants, indépendamment de l'échelle de profil. Ce mode est volontairement distinct du `NAVMESH_GROUND` des fantassins : il n'instancie pas de `NavigationAgent3D`, mais fournit une intention directe observable et une récupération bornée.

Le probe exact `enemy_large_body_contract_probe -- --id=giant_novice` valide :

- mode `LARGE_BODY` et absence de faux `NavigationAgent3D`;
- facteur de vitesse `0.78`;
- timeout de blocage `1.15 s`;
- récupération latérale de `0.72 s`;
- une seule émission `recovery_started(1)` après 72 frames immobiles;
- progression de dégagement sans `navigation_failed` prématuré;
- arrivée dans la tolérance, puis `clear_destination()` ramenant l'état à `idle`;
- capsule principale primitive valide, aucune forme concave dynamique et échelle racine uniforme;
- cleanup final.

La limite est fonctionnelle et honnête : ce steering sait avancer, détecter un blocage et tenter un dégagement, mais ne promet pas de trouver un détour topologique dans un labyrinthe. Si les niveaux Forge imposent des obstacles complexes aux géants, il faudra comparer ce mode à un navmesh dédié au grand gabarit sans perdre inertie, spacing et récupération.

## Traversal assisté, sol et collisions

Le profil du novice active par défaut le traversal Forge assisté lorsque `match_perfect_hitbox=true`. Le chemin partagé (`scripts/enemy/athenian_enemy.gd:2528-2855`) conserve :

- une `CapsuleShape3D` primitive sur le `CharacterBody3D` pour résoudre le sol;
- le retrait de cette capsule de la couche de contact joueur;
- un `AnimatableBody3D` indépendant, couche 256, avec cylindre lisse de torse/épaules;
- un second `AnimatableBody3D` dont le `ConvexPolygonShape3D` est extrait du mesh de tête réel;
- un unique `HeadFloor` aligné sur le sommet réel et membre de `enemy_walkable_surface`;
- une mise à jour des formes depuis les centres anatomiques animés;
- un recalcul plus bas, plus court et plus étroit lors du crawl.

Le probe `giant_traversal_probe.gd` est vert et mesure notamment :

```text
matched=0 walkable=1 body_disabled=false floor_layer=0 on_floor=true
traversal_layer=256
head hull size=(0.878866, 0.987590, 0.917194)
false floor count=0
crawl cylinder height=2.163300 radius=0.863460
crawl damage zone=torso radius=1.02
```

Il atteint le torse depuis avant, arrière, gauche et droite avec des normales compatibles wall-run; la tête est touchée par son hull réel et classée `giant_enemy`; le sommet marchable suit le maximum du mesh à moins de 6 cm. Après section des deux cuisses, le cylindre suit le noyau incliné, couvre le bassin, s'arrête aux épaules, garde une seam tête/corps bornée, reste sur le sol et laisse encore la zone de dégâts torse accessible.

Portée exacte de cette preuve : le fixture géométrique instancie `giant_standard` à `external_scale_multiplier=3.0`. Les garanties communes sont fortes parce que novice/standard/vétéran partagent le package `geant1`, les mêmes options (`assisted`, `0.90`, `1.00`, tops actifs), le même profil anatomique et les mêmes fonctions. Néanmoins, un futur paramètre `--id` sur ce probe supprimerait cette dernière réserve de couverture et permettrait une matrice des trois tiers.

## Package, rig, animations et LOD

Le package gagnant est `geant1-1787584159710.glb` :

- taille : `19 130 652` octets;
- SHA-256 : `B4AA088487AE945FA3CE0CDD5008A33D96AAB053CD7DAA500153D6CBA305CD16`;
- import glTF `scene`, tangentes assurées, LOD générés, shadow meshes générés, named skins, animations importées à 30 FPS et tracks immuables retirées.

L'adaptateur valide un squelette de 53 os, les meshes corporels segmentés et leurs caps. Un donneur UAL1 caché alimente locomotion/mort via `HopliteAuthoredPoseBridge` en rest-space; le driver natif charge les deux actions externes requises. Le roster déclare `donors=2`, qui correspond aux deux clés spécialisées du pattern, et le probe animation démarre réellement :

```text
ANIMATION GEANT — NOVICE visual=retarget opener=novice_punch clip=external:giant_punch
```

L'image six états confirme que `Idle`, `Jog_Fwd`, attaque, impact, mort et section produisent des silhouettes différentes et cohérentes. Le LOD commun passe ses routes shared/native/direct : action forcée échantillonnée, réduction de cadence aux niveaux intermédiaires, sommeil lointain et réveil réversible. Pour ce novice, le même `HopliteNativeAnimationDriver` est sélectionné par ses `external_animation_keys`; le probe LOD n'est toutefois pas une matrice par ID et cette portée est conservée comme réserve de test.

Le donneur caché reste nécessaire. Aucune suppression d'UAL1, des clips externes ou du package segmenté n'est autorisée sans un remplaçant complet et des preuves multi-frame équivalentes dans unité, Lab et Forge.

## Anatomie et démembrement

`_finish_mannequin_setup()` configure `HopliteAnatomyHitbox` à partir du profil humanoïde partagé; la factory exacte obtient douze zones runtime sur le squelette du package. Le probe crée une instance fraîche pour chaque zone et applique un `HitEvent` localisé de section.

| Zones | Forme / rayon source | Dégâts | Section | Effet |
|---|---|---:|---:|---|
| tête | sphère `0.25` | x`1.70` | seuil `64` | fatale |
| cou | capsule `0.15` | x`1.85` | seuil `56`, cible tête | fatale |
| torse | capsule `0.34` | x`1.00` | non | zone centrale persistante |
| bassin | capsule `0.30` | x`0.95` | non | zone centrale persistante |
| bras supérieurs L/R | capsule `0.16` | x`0.78` | seuil `78` | membre détaché; bras droit désarme les poings |
| avant-bras L/R | capsule `0.14` | x`0.75` | seuil `60` | membre détaché; avant-bras droit désarme les poings |
| cuisses L/R | capsule `0.21` | x`0.88` | seuil `94` | boiterie; deux côtés perdus = crawl |
| tibias L/R | capsule `0.18` | x`0.84` | seuil `72` | boiterie; deux côtés perdus = crawl |

Résultat exact : `zones=12 severed=10`. Torse et bassin encaissent le coup local sans section; tête/cou déclenchent la mort; chaque membre sectionnable marque son état et produit une preuve détachée. Une jambe limite la vitesse à la boiterie; deux jambes passent à `ai_crawl_speed=0.72`, raccourcissent le collider de corps et recalculent le traversal assisté.

## Mort et lifecycle

`scripts/enemy/athenian_enemy.gd:3557` finalise la mort de manière atomique : attaque et permission libérées, cible vidée, participation IA désactivée, destination effacée, groupes/registry/crowd synchronisés et collisions actives retirées. L'anatomy regression confirme qu'une section létale termine toujours `_die()` plutôt que de laisser un acteur partiellement mort.

Les membres détachés et débris utilisent des ressources partagées et un lifecycle en deux temps : retrait collision/ombres/simulation, puis expiration. Le probe transient vérifie aussi TTL projectile, sang sans ombre, équipement borné, fragments de géant avec rayon de collision en unités monde et cadavre render-only. Sa partie géant à grande échelle instancie `giant_standard`, donc la garantie dimensionnelle est familiale; le démembrement exact du novice couvre en complément ses dix fragments.

## Performance — photographie actuelle

Commande fraîche :

```powershell
Godot_v4.7-stable_win64.exe --headless --path . --script res://tools/enemy_performance_benchmark.gd -- --counts=1,12,56 --mode=both --warmup=120 --frames=120 --seed=13371 --archetype=giant_novice
```

Le harness utilise `mass_battle_mode=true`, registry désactivé et 60 ticks/s. Les temps engine sont des snapshots diagnostiques; p95/p99 décrit l'intervalle mural cadencé. Le test est structurel et headless, sans coût GPU/VRAM réel.

| Mode | Unités | Spawn ms | Process / physics snapshot ms | Nœuds | Objets | Mémoire statique | Corps actifs | Tick p95 / p99 / max ms | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| idle | 1 | 50.519 | 0.572 / 0.535 | 80 | 1 755 | 53 764 509 o | 0 | 20.702 / 20.724 / 20.763 | PASS |
| idle | 12 | 212.464 | 4.370 / 1.913 | 894 | 2 756 | 59 048 491 o | 0 | 20.714 / 20.899 / 21.031 | PASS |
| idle | 56 | 808.979 | 18.135 / 2.561 | 4 150 | 6 760 | 79 879 191 o | 0 | 25.465 / 32.072 / 32.208 | PASS |
| actif | 1 | 75.342 | 0.510 / 0.963 | 81 | 1 758 | 55 335 033 o | 1 | 20.706 / 20.722 / 20.725 | PASS |
| actif | 12 | 215.156 | 4.954 / 3.892 | 906 | 2 781 | 60 413 803 o | 12 | 20.706 / 21.067 / 21.091 | PASS |
| actif | 56 | 773.390 | 25.818 / 12.499 | 4 206 | 6 873 | 80 883 119 o | 56 | **35.443 / 36.379 / 36.513** | PASS structurel |

Le seuil de foule `28` n'a pas été modifié. Les six scénarios nettoient tous les WeakRefs et groupes de combat. À 56 actifs, `process + physics = 38.317 ms` et p95 atteint 35.443 ms : cette densité est hors budget 60 Hz sur ce poste/headless. À 12 actifs, le snapshot combiné est 8.846 ms, mais l'intervalle mural reste dominé par le cadencement Windows autour de 20.7 ms; il ne faut pas convertir ce chiffre en FPS indépendant. Aucune baseline phase 0 strictement comparable propre à `giant_novice` n'existe, donc aucun pourcentage de gain n'est revendiqué.

## Preuves visuelles inspectées

`docs/enemy_refactor/visual_evidence/giant_novice.png` (1 351 × 760) présente six états : `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`. La silhouette musculeuse et voûtée est cohérente; le jog avance les membres, le punch ferme le torse, l'impact se tasse, la mort tombe au sol et la section montre le moignon ainsi qu'un fragment détaché. Aucune pose n'est une T-pose grossière. Le fragment sectionné est projeté très loin sur la droite de la composition, ce qui prouve le détachement mais diminue sa lisibilité artistique.

`docs/enemy_refactor/lab_full_roster_visual_probe.png` et `docs/enemy_refactor/forge_full_roster_visual_probe.png` (1 600 × 900) montrent aussi le novice parmi les 22/22, posé sans T-pose ni équipement parasite. Le Lab utilise la vraie scène avec annexe haute; Forge utilise un vrai document/runtime. Les labels sont petits et l'éclairage Forge très chaud : ces vues prouvent l'intégration contextuelle et la présence, pas une validation fine de texture ou d'animation continue.

## Tests exécutés

| Test | Résultat | Portée / réserve |
|---|---|---|
| `enemy_unit_dismemberment_probe.gd -- --id=giant_novice` | PASS `zones=12 severed=10` | exact, fatalités, fragments et teardown |
| `enemy_unit_behavior_probe.gd -- --id=giant_novice` | PASS | exact, loin/proche, deux attaques, perte cible, sleep/wake, cleanup; interruption armée N/A |
| `enemy_large_body_contract_probe.gd -- --id=giant_novice` | PASS | exact, recovery bornée, capsule primitive, arrivée/clear |
| `enemy_full_roster_validation_probe.gd` | PASS `22/22` | exact : famille, rig, 12/12, unarmed, opener et navigation |
| `enemy_roster_audit.gd` | PASS `22/22` | exact : `pattern=2/0 donors=2 package=geant1` |
| `enemy_animation_probe.gd` | PASS `14/14` | exact opener `novice_punch -> giant_punch` |
| `giant_traversal_probe.gd` | PASS | famille `geant1`, sol/tête/walkable/wall-run/crawl; fixture `giant_standard` x3 |
| `enemy_combat_probe.gd` | PASS | combat commun et traversal Forge assisté |
| `enemy_anatomy_regression_probe.gd` | PASS | mort létale atomique |
| `enemy_animation_lod_probe.gd` | PASS | routes communes shared/native/direct, cadence et réveil |
| `enemy_transient_lifecycle_probe.gd` | PASS | TTL, ressources partagées, retrait collisions/ombres, fragment géant x3 |
| `enemy_action_state_probe.gd` | PASS | priorités windup/recovery/parry/tactique communes |
| `wall_run_probe.gd` | PASS | classification joueur, surfaces ennemies, angles et sortie |
| `world_editor_probe.gd` | PASS `entities=28 mobs=311` | propriétés des trois géants conservées par le document |
| `enemy_performance_benchmark.gd` | PASS structurel `1/12/56`, idle/actif | limite CPU à 56 actifs documentée |

Tous les logs sont dans `.tmp_tools/enemy_refactor/giant_novice_audit/`; la relance de comportement faisant foi est `behavior_exact_final.log`. L'avertissement Windows `Failed to read the root certificate store` apparaît au démarrage mais n'affecte aucune scène et tous les probes applicables terminent avec code 0. Un premier lancement via le petit shim console a été interrompu extérieurement pendant une corrélation de processus concurrents; il a été relancé avec le binaire principal et un `--log-file` isolé, puis le même probe a passé. Cette interruption de coordination n'est pas attribuée à l'unité.

## Revue Godot 4.7

### Critique

Aucune panne critique propre à `giant_novice` n'est reproduite.

### Améliorations / dette honnête

- Paramétrer `giant_traversal_probe.gd` par `--id` et exécuter les trois tiers pour fermer la dernière extrapolation familiale.
- Ajouter un probe exact qui sectionne le bras droit pendant le windup d'un géant non armé et confirme zéro dégât, afin de joindre dynamiquement les deux contrats déjà verts séparément.
- Si la Forge crée des parcours à détours complexes, comparer `LARGE_BODY` à un navmesh de grand rayon; le steering actuel ne garantit pas le contournement topologique.
- Capturer une séquence multi-frame dans la vraie Forge avec `match_perfect_hitbox=true`, escalade joueur et transition debout→crawl; les images actuelles sont des preuves statiques.
- Conserver `geant1`, UAL1 et les deux donneurs d'action jusqu'à remplacement complet prouvé. Ne pas retirer un donneur parce qu'une capture unique semble correcte.
- Mesurer en fenêtre Forward+/Compatibility les draw calls, surfaces, VRAM et qualité des LOD; le benchmark headless ne couvre pas ces coûts.
- Éviter les batailles de 56 géants actifs : la mesure dépasse nettement le budget CPU. Le seuil global 28 reste inchangé et ne constitue pas une recommandation de densité pour cette famille lourde.

### Points solides

- Profil distinct et monophasé cohérent avec un novice, sans comportement de boss inventé.
- Factory unique, Resource typé et route Forge sérialisée.
- Package dédié présent, rig 53 os validé, anatomie segmentée et caps préservés.
- Deux attaques distinctes réellement démarrées/résolues avec animation externe.
- Navigation `LARGE_BODY`, recovery et cleanup observables.
- Traversal assisté construit avec primitives lisses et tête dérivée du mesh réel.
- Crawl, dégâts localisés, section et lifecycle bornés.
- LOD animation réversible et teardown sans référence vivante.

---

Revu contre les checklists Godot 4.3+ / 4.7 de navigation, animation, physique, assets, 3D, testing, debugging et code review.
