# Audit final — `captain`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`) et les variantes `knight1/2/3` sont couvertes, dont une capture `captain__knight3.png`. Les routes Lab/Forge rendent les 22 IDs avec six actions distribuées; teardown, TTL et rechargement sont couverts par `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable, build officiel `5b4e0cb0f`**\
**Renderer : `gl_compatibility`**\
**Portée : état courant du worktree; scripts, scènes, profils et ressources centraux examinés en lecture seule.**

## Verdict synthétique

Le contrat fonctionnel de `captain` est prouvé sur l'état courant : factory canonique, profil/rang, faction et cibles, décisions loin/proche, trois attaques via le scheduler et le chemin windup/résolution réels, leases et interruption sans dommage après désarmement, perte de cible, sommeil/réveil, anatomie complète, équipement détachable, mort et teardown. Les probes frais sont verts, notamment la matrice exacte des trois modèles Mixamo (`3 variantes`, `36 zones`), le comportement exact `captain`, le probe de démembrement (`12 zones / 10 entrées sectionnables`) et le full roster (`22/22`).

Le modèle Knight direct Mixamo est l'identité visuelle runtime déclarée de ce profil. `skin=captain` et `captain_role_kit` appartiennent au repli procédural; leur absence lorsqu'une charge `knight1/2/3` réussit n'est donc pas une panne. Les trois variantes ont un squelette, un `AnimationPlayer`, leurs douze zones, leur cycle de trois étapes et leurs équipements détachables. Les vraies routes Combat Lab et WorldRuntime Forge passent aussi à `22/22`; leurs captures Compatibility montrent le capitaine en pose animée, sans T-pose.

Le défaut initial de `knight3` — épée/bouclier authored sans contrat détachable — a été corrigé dans le contrôleur central pendant l'audit. L'état courant résout les meshes authored, crée les ancres main droite/gauche, masque les meshes portés à la section et instancie des remplacements rigides. `enemy_authored_equipment_probe.gd` et la matrice des variantes passent; `enemy_mixed_stress_probe.gd` repasse aussi à 36 unités.

Il ne reste aucune panne fonctionnelle reproductible propre à `captain`. Les limites honnêtes sont probatoires : la planche individuelle ne cadre que `knight1`, le run Battle est un test de démarrage plutôt qu'une capture de combat, et il n'existe pas de baseline CPU/GPU antérieure comparable permettant de revendiquer un gain.

## Construction, profil et variantes

Source de vérité : `scripts/enemy/enemy_archetypes.gd:283-314`. Le profil normalisé exact est :

| Champ | Valeur |
|---|---:|
| nom / rang | `CAPTAIN` / `miniboss` |
| skin / échelle | `captain` / `1.20` |
| PV / vitesse | `460.0` / `5.25 m/s` |
| dégâts / portée / aggro | `34.0` / `2.28 m` / `23.0 m` |
| arme / échelle | `sword` / `1.18` |
| bouclier / échelle | `true` / `1.16` |
| comportement / style | `boss` / `captain` |
| windup / recovery génériques | `0.40 s` / `0.40 s` |
| cooldown générique | `1.18–1.48 s` |
| bande préférée | `0.0–2.10 m` |

Le bouclier sans bloc `defense` explicite est normalisé vers le contrat partagé `shield` : chance 0,30, durée 0,68 s, cooldown 1,55 s, multiplicateurs dégâts/section 0,20/0,12, garde 78, régénération 18 et délai 1,30 s (`enemy_archetypes.gd:57-72`).

`HopliteEnemyFactory.spawn_request()` est l'unique construction runtime : copie des options typées, métadonnée `procedural_archetype`, rang calculé depuis le profil, ajout au parent puis inscription optionnelle au registre (`enemy_factory.gd:48-85`). `_ready()` applique le profil avant collider, visuel, anatomie, navigation et groupes (`athenian_enemy.gd:314-359`). Le fallback de compatibilité historique remappe aussi un `swordsman` muni de `is_miniboss=true` vers `captain` (`:315-318`); `enemy_factory_options_probe` couvre cette surface.

Variantes de bataille :

- Battle 01 instancie trois capitaines de mur, puis un capitaine par rencontre urbaine. Les variantes urbaines reçoivent après spawn `PV ×1,18`, `dégâts ×1,12` et une échelle racine supplémentaire `×1,05` (`battle_01.gd:327-339`, `:406-452`).
- Battle 02 instancie quatre capitaines de cohorte extérieure et deux rencontres de ville supplémentaires via le helper hérité (`battle_02.gd:160-169`, `:221-238`).
- `battle_enemy_spawn_probe` prouve qu'un `captain` reste miniboss/epic même lorsque le helper reçoit `elite=false`.
- Le manifeste actuel déclare Battle 01/02 comme routes principales. Le probe full-roster ouvre la vraie scène Combat Lab puis crée son annexe de mission via `EnemyFactory`; il valide les 22 IDs, dont `captain`, squelette visible et anatomie `12/12`, avant capture Compatibility.
- La Forge liste `EnemyArchetypes.all_ids()` et son runtime peut remapper une troupe marquée `rank=miniboss` vers `captain` avant de passer par la factory (`world_editor.gd:882-886`; `world_runtime.gd:293-329`, `:357-383`). `enemy_lab_forge_full_roster_visual_probe.gd -- --context=forge` construit un vrai `WorldDocument`, le passe au vrai `WorldRuntime`, obtient exactement une unité par ID et valide/capture les 22. La route `captain` Forge n'est plus seulement une inférence statique.

## Faction, cibles, activation et cycle de vie

- Faction par défaut `athenian`; groupes `enemy`, `athenian`, `damageable`, `combatant`, `combatant_ai`, `enemy_ai`, `enemy_miniboss` et `enemy_epic`. La factory accepte aussi `faction=spartan`, auquel cas les groupes et priorités de cibles basculent vers les alliés.
- Le joueur dans la bulle d'aggro reste prioritaire; une cible de représailles valide peut temporairement la remplacer. La sélection adverse tient compte de la distance, du nombre de claims et d'un bonus d'hystérésis pour la cible actuelle (`athenian_enemy.gd:2313-2413`). Le probe factions valide groupes, précédence, représailles, absence de friendly fire et nettoyage des claims.
- Comme `is_miniboss=true`, le capitaine attaque dans les 23 m ou pendant l'alerte, sinon retourne à `ai_home_position` en `boss_idle` (`:761-769`). Les autres soldats peuvent recevoir ce capitaine comme `ai_miniboss` et former garde/interception autour de lui; le capitaine lui-même n'entre pas dans la logique de défense d'un autre capitaine.
- `configure_training_activation()` peut le placer en `training_wait`; vérification espacée de 0,18–0,23 s, puis réveil, purge du but mis en cache, nouveau cooldown et reprise idle (`:2282-2311`). Aucun scénario exact `captain` n'a exercé ce chemin.
- À la mort, leases et claims sont libérés, collisions et anatomie coupées, équipement lâché, traitement physique arrêté et corps rendu statique côté logique. Les modèles Knight n'offrent pas `Death01` dans leur GLB; le chemin constaté est donc le repli de collapse déterministe, visible sur la planche. Le benchmark confirme zéro référence ennemie vivante et zéro orphelin après teardown.

## Décision, garde, attaques et leases

Le comportement `boss` reste une branche du contrôleur partagé, pas une FSM objet distincte. Les états observables sont explicites (`boss_idle`, `boss_attack`, `attack_windup`, `attack_recover`, `pressure_wait`, `guard_broken`, `disarmed`, `dead`) mais la phase 2 documente toujours qu'aucune nouvelle action-FSM autoritaire n'a été intégrée.

Cycle de combat du profil :

| Étape | Clip direct | Windup | Recovery | Cooldown | Dégâts / portée | Mouvement |
|---|---|---:|---:|---:|---:|---:|
| `shield_bash` | `mixamo/axe_kick` | 0,28 s | 0,24 s | 0,52 s | ×0,72 / ×0,92 | lunge 4,8 |
| `cross_cut` | `mixamo/axe_horizontal` | 0,30 s | 0,28 s | 0,68 s | ×1,00 / ×1,00 | standard |
| `command_heavy` | `mixamo/axe_down` | 0,52 s | 0,46 s | 1,10 s | ×1,32 / ×1,08 | standard |

Les coups tournent dans cet ordre et ne frappent qu'après windup. La résolution revérifie la génération de lease, l'arme/bras droit, cible, portée et arc avant d'appliquer les dégâts (`athenian_enemy.gd:1616-1708`, `:1743-1809`). La permission partagée est bornée à la capacité du directeur; expiration et génération obsolète annulent l'attaque. Libération sur interruption, changement de cible, fin de récupération, sortie d'arbre et mort est présente (`:306-311`, `:539-546`, `:1932-1989`, `:3540-3545`). Le probe exact `enemy_unit_behavior_probe.gd -- --id=captain` force les décisions loin/proche, traverse les trois étapes distinctes par `_begin_ai_attack()` puis `_resolve_ai_attack()` avec le vrai directeur, vérifie qu'un désarmement pendant le windup annule sans dommage, que la perte de cible ne conserve aucun lease, puis exerce sommeil/réveil et cleanup.

Le bouclier n'est monitorable que pendant la garde, gagne l'arbitrage des contacts et peut subir guard break. La perte du bras/avant-bras gauche lâche le bouclier; le côté droit lâche l'épée et interdit toute nouvelle attaque. Les probes communs valident garde, rupture, réaction, priorité tactique, équité FIFO et leases générationnels. La matrice exacte confirme aussi l'ordre complet `shield_bash -> cross_cut -> command_heavy` sur chacun des trois Knights. Le groupe reste couvert transversalement par le directeur de foule, `crowd_tactics_probe` et le stress mixte de 36 unités; aucun défaut de coopération/teardown du capitaine n'y est reproduit.

## Navigation, blocage et récupération

Mode exact : `DIRECT_STEERING`. `captain` n'est ni phalange ni grand corps, donc `_build_navigation_component()` ne crée pas de `NavigationAgent3D` (`athenian_enemy.gd:679-696`).

Le composant suit une destination aplatie, considère l'arrivée à 0,28 m, surveille un progrès minimal de 0,12 m/s, détecte le blocage après 0,82 s puis tente des esquives latérales de 0,48 s à 72 % de la vitesse. Après trois échecs, il émet `navigation_failed(recovery_exhausted)`. Le contrôleur réinjecte le but à cadence de décision, ajoute la séparation locale, conserve la gravité à 24 m/s² et applique `move_and_slide()`.

Conséquences :

- le probe du composant valide intention, arrivée, fallback et récupération;
- le probe navmesh valide le composant en mode `NAVMESH_GROUND`, mais ce n'est pas le mode du capitaine et ne doit pas être présenté comme une preuve de pathfinding pour lui;
- `DIRECT_STEERING` ne calcule aucun détour autour d'un grand obstacle. La récupération latérale traite un coincement local, pas un labyrinthe ou un passage dont il faut contourner la topologie;
- aucun test exact `captain` sur obstacle/passage étroit/retour au poste n'existe. Le probe patrouille commun valide le contrat partagé mais pas cette silhouette à échelle 1,20/1,26.

## Rig, clips et LOD animation

La route hostile effective est `direct_mixamo` :

- pool `knight1`, `knight2`, `knight3`, sans réduction spéciale en `mass_battle_mode`; pour ce pool de taille 3, la formule de sélection se réduit en pratique à `guard_index % 3`, car le terme `instance_id * 3` est divisible par 3;
- un `Skeleton3D` principal et un `AnimationPlayer` local par instance;
- aucun `AnimationTree` actif et aucun `HopliteNativeAnimationDriver` sur cette route;
- aucun donneur/retargeter runtime; les animations du catalogue sont dupliquées une fois dans le cache statique puis ajoutées à une bibliothèque locale pour préserver un temps de lecture indépendant;
- les cinq `external_animation_keys` du profil ne sont utilisés que si une route non-Mixamo installe le driver. Ils ne sont pas des donneurs effectivement instanciés pour le capitaine actuel.

Audit statique des GLB sources :

| Modèle | Joints du skin | Meshes / surfaces | Triangles LOD0 source | Matériaux | Taille |
|---|---:|---:|---:|---:|---:|
| `knight1` | 67 (2 skins) | 2 / 2 | 14 660 | 1 | 1 767 476 o |
| `knight2` | 43 (1 skin) | 1 / 1 | 4 531 | 1 | 670 984 o |
| `knight3` | 69 (2 skins) | 4 / 4 | 14 990 | 1 | 1 796 752 o |

Les trois imports activent tangentes, génération de LOD, shadow meshes, animation à 30 FPS et suppression des pistes immuables. Le pool mélange néanmoins trois hiérarchies/quantités de joints différentes : aucune compatibilité de rig partagé n'est revendiquée, et aucun donneur ne doit être supprimé sur la seule base de leur apparence proche.

Les boucles idle/run, réaction, taunt et six attaques sont disponibles. Le probe d'animation exact relie l'ouverture `shield_bash` à `mixamo/axe_kick`; la matrice force les trois Knights et traverse leurs trois étapes déclaratives, tandis que le probe de comportement les démarre/résout réellement sur une instance `captain`. Les actions directes sont corps entier; il n'existe donc pas d'action partielle/filtre d'os à valider sur cette route. À distance, l'`AnimationPlayer` passe en évaluation manuelle 12 Hz puis est figé à LOD3; le réveil proche restaure le callback idle et force `advance(0.0)`. Le probe LOD valide la mécanique directe Mixamo sur `guardian`, et le probe de comportement exact confirme que le capitaine quitte/rejoint correctement la participation IA au sommeil/réveil; il ne mesure pas séparément la cadence 12 Hz de chaque Knight.

## Meshes, équipement et rendu

Sur `knight1/2`, l'épée et le bouclier sont procéduraux : deux meshes pour l'épée, deux pour le bouclier, attachés respectivement aux mains droite et gauche. Les facteurs 1,18 et 1,16 viennent du profil. La hitbox du bouclier est un cylindre de rayon 0,48 et d'épaisseur 0,13, désactivé hors garde.

`knight3` contient déjà épée et bouclier skinnés dans ses quatre surfaces source. Le défaut trouvé pendant cet audit a été corrigé dans l'état courant : `_build_mixamo_weapon()` résout désormais les nœuds `*Sword*` et `*Shield*`, conserve les références `authored_weapon_visual`/`authored_shield_visual`, crée `AuthoredWeaponDropAttachment` à la main droite et `AuthoredShieldCollisionAttachment` à la main gauche, puis expose les racines de détachement/collision attendues. `_drop_weapon()` et `_drop_shield()` masquent le mesh authored porté et créent un remplacement procédural sous `RigidBody3D`. Le probe `enemy_authored_equipment_probe.gd`, qui force les indices jusqu'à obtenir `knight3`, vérifie les deux ancres, les deux masquages et les deux remplacements après section : PASS. Les Battles utilisent effectivement cette variante (notamment leurs indices 5/8, `guard_index % 3 == 2`), elle n'est donc plus une exception de lifecycle connue.

Cette preuve dédiée reste plus étroite que le probe anatomique complet : elle sectionne `forearm_r` puis `forearm_l`, mais ne déroule pas les dix entrées sectionnables de `knight3`, et ne couvre pas `knight2` zone par zone.

Sur `knight1/2`, l'équipement ajoute toujours deux meshes pour l'épée et deux pour le bouclier, soit 6 surfaces visibles pour `knight1` et 5 pour `knight2`; `knight3` conserve ses 4 surfaces authored, avant effets/debug. Les matériaux procéduraux ne sont plus créés isolément par unité : le cache les partage selon leurs paramètres immuables, vérifié par `enemy_material_cache_probe.gd` sur deux instances identiques. Ce probe est transversal plutôt que `captain`-only, mais il exerce les mêmes factories de matériaux utilisées ici. En `mass_battle_mode`, les ombres sont coupées; le LOD runtime baisse `lod_bias`, coupe particules/ombres et culle à 90 m par défaut.

Identité rendue : `_build_armor_skin()` contient une branche `captain` (cuirasse bronze claire, casque corinthien à grande crête, épaulières, cnémides, jupe et ceinture), utilisée par le repli procédural. `assets/blenderAseet/14_role_kits/captain_role_kit/` fournit aussi un kit PASS V2_HERO (6 702 triangles LOD0, 384 LOD1, textures packées, quatre attaches). La route nominale réussie ne les instancie pas, car l'identité runtime déclarée est le pool Knight direct Mixamo. Cette séparation nominal/fallback est cohérente avec le contrat actuel et n'est pas un défaut fonctionnel; aucune suppression ou fusion d'asset/donneur n'est justifiée par cet audit.

## Anatomie, démembrement et physique

Les douze zones communes sont toutes mappées sur chacun des rigs Knight. Le probe unitaire confirme 12 zones testées et 10 entrées sectionnables sur `knight1`; la matrice force ensuite `knight1`, `knight2` et `knight3` et répète les douze zones sur chacun (`36/36`), avec attentes de sectionnabilité et perte d'équipement par côté :

| Zone | Forme | Dégâts | Seuil | Conséquence |
|---|---|---:|---:|---|
| `head` | sphère | ×1,70 | 64 | fatal, tête détachée |
| `neck` | capsule | ×1,85 | 56 | redirige vers tête, fatal |
| `torso` | capsule | ×1,00 | 9999 | non sectionnable |
| `pelvis` | capsule | ×0,95 | 9999 | non sectionnable |
| `upper_arm_l` | capsule | ×0,78 | 78 | lâche le bouclier, neutralise l'avant-bras |
| `forearm_l` | capsule | ×0,75 | 60 | lâche le bouclier |
| `upper_arm_r` | capsule | ×0,78 | 78 | lâche l'épée, neutralise l'avant-bras |
| `forearm_r` | capsule | ×0,75 | 60 | lâche l'épée |
| `thigh_l/r` | capsule | ×0,88 | 94 | neutralise aussi le tibia, boiterie |
| `shin_l/r` | capsule | ×0,84 | 72 | boiterie; deux jambes = crawl |

Physique : `CharacterBody3D`, couche 4, masque monde + joueur si IA active, sans collision ennemi-ennemi; capsule de base 0,39/1,82 m. Les douze zones sont des `Area3D` sphère/capsule sur couche 8 et recalculent leurs dimensions en espace monde. Arme, bouclier et membres détachés deviennent des `RigidBody3D` couche 16/masque monde, peuvent dormir, retirent collisions/ombres après 4 s et sont libérés après 12–14 s.

Limite physique partagée : l'échelle 1,20 est appliquée au `CharacterBody3D` racine et le bouclier porte une échelle locale 1,16; la variante urbaine multiplie à nouveau la racine par 1,05. Cette mise à l'échelle est uniforme et fonctionne dans les probes, mais reste moins robuste que dimensionner directement les shapes. Le défaut concret d'arbitrage a toutefois été corrigé : `HopliteShieldHitbox.zone_radius_from_shape_index()` tient compte de l'échelle héritée, et `enemy_shield_world_radius_probe.gd` confirme que le rayon de requête égale le rayon physique monde et dépasse le rayon local sur une fixture scalée. Le probe est transversal; il ne mesure pas un contact joueur au bord exact d'un capitaine urbain à 1,26.

## Performance — état courant, sans revendication de gain

Commande :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_performance_benchmark.gd -- --counts=1,56 --mode=both --warmup=30 --frames=60 --archetype=captain --registry=on
```

| Mode | Unités | Spawn ms | Nœuds | Objets | Mémoire statique | Corps actifs | Tick p95 / max | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 1 | 250,062 | 39 | 1 640 | 68,6 MB | 0 | 20,703 / 20,743 ms | PASS |
| idle | 56 | 923,568 | 1 708 | 4 562 | 131,3 MB | 0 | 20,708 / 20,775 ms | PASS |
| actif | 1 | 256,533 | 40 | 1 643 | 69,3 MB | 1 | 20,708 / 20,715 ms | PASS |
| actif | 56 | 1 016,114 | 1 764 | 4 675 | 132,2 MB | 56 | 20,700 / 24,255 ms | PASS |

Le scénario 56 capitaines est un stress structurel artificiel; les Battles n'en placent que quelques-uns. Il révèle le coût structurel du pool de trois modèles, tandis que le probe du cache garantit maintenant le partage des matériaux procéduraux à paramètres identiques. Les instantanés process/physics sont diagnostiques et le p95 headless reflète aussi la cadence Windows. La baseline de mission ne contient aucun run antérieur comparable `captain 1/56`; aucun gain avant/après ne peut donc être revendiqué. Draw calls, VRAM, coûts GPU, efficacité réelle du batching, temps de démembrement répété et coût rendu des trois variantes restent non mesurés.

## Preuve visuelle inspectée

Fichier : `docs/enemy_refactor/visual_evidence/captain.png` (1 352 × 760, inspecté en résolution originale).

- `IDLE NU` et `JOG NU` cachent volontairement l'équipement; poses, appui au sol et mouvement des jambes sont distincts, sans pose en T évidente.
- `ATTAQUE` montre un coup engagé avec l'épée attachée; l'état diffère nettement du jog.
- `IMPACT` montre une réaction et le bouclier; `MORT` montre un corps au sol et l'équipement lâché; `SECTION` produit sang et perte du bras droit/épée.
- La planche crée six acteurs indépendants mais, avec `guard_index=0`, ils choisissent tous `knight1`. Elle compare donc un seul modèle sans couvrir les variantes `knight2/3`; elle ne constitue toutefois pas la séquence temporelle d'une même instance.
- Les grands disques de bouclier et les acteurs voisins se recouvrent au centre/droite, masquant les mains, le bord de l'aspis et une partie de `SECTION`. Les libellés sont partiellement cachés.
- Aucune crête transversale, laurier ou gorgerin ne relie ce rendu au `captain_role_kit`, ce qui est attendu sur la route nominale : la silhouette Knight est l'identité runtime déclarée et le kit appartient au fallback.
- La capture ne couvre ni rotation, ni locomotion sous action partielle (non applicable à ces clips corps entier), ni rendu Battle/Forge, ni les trois modèles Knight séparément.

Preuves complémentaires inspectées en résolution originale : `lab_full_roster_visual_probe.png` et `forge_full_roster_visual_probe.png` (1 600 × 900, Compatibility). La première ouvre la vraie scène Combat Lab et place l'annexe factory des 22 IDs; la seconde provient d'un vrai `WorldDocument` construit par `WorldRuntime`. Les deux montrent le roster animé sans T-pose visible et incluent `captain`. Leur cadrage large prouve surtout présence/pose globale : il ne remplace pas les gros plans de la planche individuelle ni la matrice headless des trois variantes.

## Tests exécutés

| Test | Résultat | Portée réelle |
|---|---|---|
| `enemy_unit_dismemberment_probe.gd -- --id=captain` | PASS, `zones=12 severed=10` | exact capitaine/`knight1`, zones, fatalités, équipement, teardown séquentiel |
| `enemy_authored_equipment_probe.gd` | PASS | `knight3`: résolution épée/bouclier authored, ancres droite/gauche, masquage et remplacements rigides après sections des deux avant-bras |
| `enemy_mixamo_variant_matrix_probe.gd -- --id=captain` | PASS, `variants=3 zones=36` | force `knight1/2/3`; squelettes/players, `12/12` chacun, équipement par côté, cycle des 3 étapes et rejet cross-pool |
| `enemy_unit_behavior_probe.gd -- --id=captain` | PASS | décisions loin/proche; 3 attaques via scheduler/windup/résolution; désarmement sans dommage; perte cible/lease; sleep/wake; cleanup |
| `enemy_full_roster_validation_probe.gd` | PASS, `22/22` | ligne exacte `captain`: `direct_mixamo`, `12/12`, sword+shield, `shield_bash`, `DIRECT_STEERING`, teardown |
| `enemy_animation_probe.gd` | PASS | exact ouverture `shield_bash -> mixamo/axe_kick` |
| `battle_enemy_spawn_probe.gd` | PASS | exact rang/groupes du captain via helper Battle |
| `enemy_archetype_data_probe.gd` | PASS | vue typée égale au profil normalisé, 22 IDs |
| `enemy_factory_route_probe.gd` | PASS | toutes les constructions passent par la factory |
| `enemy_factory_options_probe.gd` | PASS | compatibilité options/miniboss |
| `enemy_faction_targeting_probe.gd` | PASS | groupes, cibles, claims, représailles, friendly fire, live-free |
| `attack_scheduler_probe.gd` | PASS | capacité, FIFO, expiration et générations de leases; synthétique |
| `enemy_action_state_probe.gd` | PASS | priorités garde/recovery/windup/parry; transversal |
| `enemy_combat_probe.gd` | PASS | garde, guard break, parry, patterns élites; pas un cycle captain exact |
| `crowd_tactics_probe.gd` | PASS | anneaux, réserves, budget et expulsion; transversal |
| `enemy_navigation_component_probe.gd` | PASS | intention, formation, fallback, récupération; composant |
| `enemy_navigation_navmesh_probe.gd` | PASS | navmesh réel; non applicable au mode exact DIRECT_STEERING |
| `enemy_patrol_probe.gd` | PASS | patrouille partagée; non ciblée Captain |
| `enemy_animation_lod_probe.gd` | PASS | réveil réversible des trois routes; direct Mixamo exercé sur Guardian |
| `enemy_transient_lifecycle_probe.gd` | PASS | TTL, collisions/ombres retirées; transversal |
| `enemy_mixed_stress_probe.gd` (`36` unités) | PASS | 22 familles, deux cohortes, cible mobile/changée, réveil, 4 sections, 4 morts et cleanup; transversal, pas un cycle captain exact |
| `enemy_lab_forge_full_roster_visual_probe.gd`, contextes `lab` et `forge` | PASS, `22/22` chacun | vraies scènes/routes; squelette visible, anatomie 12/12, captures Compatibility inspectées sans T-pose |
| `enemy_material_cache_probe.gd` | PASS | armes/armures procédurales partagées selon paramètres immuables; transversal |
| `enemy_shield_world_radius_probe.gd` | PASS | rayon de requête égal au rayon physique après échelle héritée; transversal |
| benchmark ciblé 1/56 idle/actif | PASS | état courant CPU/structure/teardown, pas avant/après |
| démarrage runtime `battle_01.tscn`, `battle_02.tscn`, 180 frames | code 0 | startup seulement; aucune preuve de combat/render captain |

Journaux : `.tmp_tools/enemy_refactor/captain_*.log`. Tous les runs headless émettent le bruit environnemental Windows `Failed to read the root certificate store`. Les démarrages Battle émettent aussi l'impossibilité de sauvegarder les réglages HUD dans le sandbox et les deux instances audio déjà documentées à l'arrêt; aucun de ces messages ne prouve une fuite du capitaine.

## Défauts partagés à remonter à l'orchestrateur

1. Les commentaires de `battle_01.gd:329` et `battle_02.gd:160` affirment encore que seuls les capitaines paient un rig/donneur UAL2 complet. L'implémentation actuelle les route vers `direct_mixamo`, sans driver ni donneur. Cette documentation est factuellement obsolète.
2. `enemy_roster_audit.gd` affiche `donors=5` pour `captain`, mais compte les cinq clés déclarées, pas les donneurs instanciés. Ce libellé confond catalogue potentiel et coût runtime réel.
3. Le générateur de la planche individuelle compare six instances `knight1`, pas six états temporels d'une même instance ni les trois variantes. La matrice headless couvre désormais les variantes, mais la dette de présentation reste commune aux planches multi-modèles.
4. Les `CharacterBody3D` et hitboxes restent uniformément scalés au lieu de redimensionner leurs shapes. Le rayon d'arbitrage du bouclier est maintenant correct et probé; le choix de transformation reste une dette de robustesse, pas une panne reproduite.

Les défauts partagés antérieurs sur les matériaux par instance, le rayon de bouclier et l'absence de preuve Forge sont fermés respectivement par `enemy_material_cache_probe`, `enemy_shield_world_radius_probe` et le full-roster visuel Lab/Forge.

## Limites non bloquantes et suivi recommandé

- Rendre une planche individuelle par Knight, avec cadrage sans chevauchement, améliorerait la lisibilité visuelle; les captures full-roster restent trop larges pour inspecter les mains et les bords d'équipement.
- Ajouter une capture de combat Battle 01/02 compléterait les démarrages headless et les vraies routes Lab/Forge. Son absence ne révèle pas de panne actuelle.
- Mesurer une baseline comparable avant/après, les draw calls, la VRAM et le coût GPU permettrait de parler de gain; le benchmark présent ne prouve que l'état courant et le teardown.
- Un scénario obstacle/étroiture propre au capitaine renforcerait la preuve de récupération. `DIRECT_STEERING` ne promet pas de détour topologique; si ce besoin devient fonctionnel, il faudra choisir `NAVMESH_GROUND` plutôt que le déduire des probes actuels.
- La cadence LOD 12 Hz n'est pas chronométrée séparément sur les trois Knights, même si la mécanique direct Mixamo partagée et le sommeil/réveil exact du capitaine sont verts.
- Conserver les sources Knight, les clips et le `captain_role_kit` de fallback : aucune preuve ne justifie de supprimer un donneur ou un asset.
