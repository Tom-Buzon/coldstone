# Audit final — `boss_bronze`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable**\
**Renderer : `gl_compatibility`, headless pour les probes**\
**Portée : état courant du worktree; runtime central, scènes, profils et ressources inspectés strictement en lecture seule.**

## Verdict synthétique

`boss_bronze` satisfait le contrat fonctionnel de phase 4 dans l'état courant : construction par la factory canonique, profil typé, rang `miniboss`, faction/cible, décisions loin/proche, cycle complet de ses deux attaques, leases, steering direct avec récupération bornée, sommeil/réveil, 12 zones anatomiques, 10 entrées sectionnables, perte de lance, mort atomique, nettoyage des transients et LOD réversible. Les probes frais passent, dont `enemy_unit_behavior_probe.gd -- --id=boss_bronze`, le démembrement exact, le full roster `22/22`, le stress mixte `22 familles / 36 unités` et le benchmark ciblé 1/12.

La route exacte est désormais établie sans ambiguïté : l'ID résout `res://assets/characters/3dgen_demo/bossbronze.glb`; le contrôleur valide ce package UAL1 à 53 os puis installe son retargeting et ses donneurs. Les entrées `knight2`, `knight1`, `knight3` du catalogue Mixamo ne constituent qu'un fallback si le package échoue. La sortie actuelle de `enemy_roster_audit.gd`, qui présente `knight2.glb`, est donc fausse pour la route runtime gagnante.

Verdict final : **DONE**. La relance ciblée charge le vrai package à 53 os puis passe décisions far/close, les deux étapes du pattern via le vrai scheduler/windup/resolve, interruption par désarmement sans dégâts, perte de cible avec lease libéré, sommeil/réveil et cleanup. Les contrats de groupe/obstacle/LOD sont mutualisés et passent dans leurs probes dédiés ainsi que dans le stress mixte. Aucune panne locale reproductible ne subsiste.

Les limites restantes sont des améliorations non bloquantes : l'outil roster décrit mal la route, le graphe de donneurs mérite une mesure instrumentée, le manifeste porte une route `authored` non retrouvée, et l'adéquation visuelle des clips de sword à la lance pourrait recevoir une preuve rapprochée. Le benchmark reste un état courant sans baseline GPU; aucune revendication de gain n'en est tirée.

## Profil canonique, rang et phases

Source de vérité : `scripts/enemy/enemy_archetypes.gd:385`.

| Champ | Valeur |
|---|---:|
| nom / rang | `BRONZE BOSS` / `miniboss` |
| famille de manifeste | `legacy_elite` |
| skin / échelle | `captain` / `1.20` |
| PV / vitesse | `640.0` / `4.45 m/s` |
| dégâts / portée / aggro | `38.0` / `2.92 m` / `25.0 m` |
| arme / échelle | `spear` / `1.12` |
| bouclier | `false` |
| comportement / style | `reach` / `poke` |
| windup / recovery génériques | `0.36 s` / `0.38 s` |
| cooldown générique | `1.06–1.36 s` |
| vitesse d'animation | `1.04` |
| bande préférée | `1.65–2.68 m` |
| clés externes | `vertical_sword`, `sword_slash` |

Aucun seuil `phase2`/`phase3`, multiplicateur de phase ou changement de pattern n'est déclaré. L'unité est explicitement un `miniboss` legacy monophasé; son nom historique ne crée pas un contrat de phases implicite. Le runtime reste donc correctement en phase 1 et le rapport ne lui invente pas de phase absente.

## Construction et route exacte

`HopliteEnemyFactory.spawn_request()` reste le point de construction commun. La requête typée transmet ID, faction, cible, `guard_index`, position, échelle et éventuel chemin de package; le rang est dérivé du profil, puis l'instance est ajoutée au parent et au registre. Le probe `enemy_factory_route_probe.gd` passe sur toutes les routes recensées.

Chaîne réellement prise pour `boss_bronze` :

1. `_resolve_package_path()` normalise l'ID en `bossbronze` et trouve `res://assets/characters/3dgen_demo/bossbronze.glb`;
2. `_load_mannequin()` essaie le package avant le catalogue Mixamo;
3. le validateur accepte le schéma `1`, le rig `spartan_ual1_v1`, les 53 os, les zones segmentées et les caps;
4. le log runtime confirme : `[SPARTAN PACKAGE] Loaded ... bossbronze.glb (53 bones, segmented gore, UAL1 animation donor).`;
5. le résultat de full roster est `rig=package_retarget`, et non `direct_mixamo`.

Le catalogue `mixamo_catalog.gd` déclare bien le fallback `[knight2, knight1, knight3]`. Il ne s'exécute que si le package n'est pas chargé/validé. Le probe `enemy_authored_equipment_probe.gd` sur `knight3` est utile pour ce fallback, mais il ne prouve pas l'équipement de la route effective `boss_bronze`.

Défaut d'outillage : `enemy_roster_audit.gd` affiche actuellement `package=knight2.glb donors=2`. Pour les IDs legacy, il choisit volontairement l'apparence Mixamo même lorsqu'`EnemyArchetypes.package_path()` est non vide. En outre, `donors=2` signifie seulement « deux clés externes déclarées », pas « deux donneurs réellement instanciés ». Cette sortie ne doit pas alimenter le ledger tant qu'elle n'est pas corrigée.

## Routes de contenu

- La Forge expose les 22 IDs via `EnemyArchetypes.all_ids()` et passe par la factory. La capture du vrai `WorldRuntime` Forge prouve les 22 rendus en Compatibility, dont `boss_bronze`, sans T-pose grossière.
- La preuve Lab s'exécute dans le vrai Combat Lab et y ajoute l'annexe de validation 22/22. Elle prouve le rendu de la factory dans ce contexte réel; elle ne prétend pas que chaque ID appartient au roster authored initial du Lab.
- `docs/enemy_refactor/roster_manifest.json` indique `primary_routes: ["forge", "authored"]`. La recherche statique n'a trouvé aucune scène Battle/procédurale ni route authored dédiée qui référence directement `boss_bronze`. C'est une dette de précision du manifeste, pas un échec de la route Forge/Lab prouvée.
- Le full roster et le probe comportement exact complètent ces rendus par construction, comportement et destruction réels de l'ID.

## Faction, cible, activation et mort

- La faction par défaut est `athenian`; les groupes de combat, d'IA et de rang miniboss/epic sont ajoutés depuis le contrat commun. La factory peut explicitement injecter une autre faction.
- La priorité va au joueur dans l'aggro, avec représailles, hystérésis et répartition par claims pour les cibles alternatives. Le probe factions valide groupes, précédence, représailles, absence de friendly fire et nettoyage des claims.
- Avec 25 m d'aggro et le rang miniboss, l'unité s'active à longue portée ou sur alerte. Le probe comportement exact vérifie aussi la sortie/rentrée de participation IA : sommeil sans groupe `combatant_ai`, puis réveil avec groupe et autorité restaurés.
- La mort est atomique côté logique : état mort, retrait des groupes IA, libération du lease et des claims, cible annulée, collisions corps/anatomie désactivées, arrêt navigation/physique active, arrêt de l'arbre d'animation et largage de l'équipement.
- Le corps passe ensuite en rendu de cadavre allégé; il n'est pas automatiquement `queue_free()` par le contrôleur. Le propriétaire de rencontre/monde doit assurer sa suppression finale. Les probes de teardown forcent cette fin de vie; aucune mesure ne couvre une accumulation prolongée de cadavres dans une vraie session.
- Les membres, la lance et les débris rigides peuvent dormir; collision et ombres sont retirées après environ 4 s, puis les transients sont libérés vers 12–14 s. Le probe transient passe.

## Combat solo, groupe et leases

Pattern déclaré :

| Étape | Source d'animation | Windup | Recovery | Cooldown | Dégâts / portée | Mouvement |
|---|---|---:|---:|---:|---:|---:|
| `bronze_thrust` | `external:vertical_sword` | 0,34 s | 0,30 s | 0,66 s | ×1,04 / ×1,10 | lunge 4,5 |
| `bronze_sweep` | `external:sword_slash` | 0,48 s | 0,44 s | 0,94 s | ×1,18 / ×1,12 | arc large, `arc_dot=-0,10` |

Le comportement `reach` recule sous 1,65 m, avance au-delà de 2,68 m et maintient la bande intermédiaire. Une attaque est en outre refusée sous `0,74 × preferred_min`, soit environ **1,22 m**. Ce garde-fou est cohérent avec l'identité d'une arme d'allonge; la récupération bornée commune traite les blocages locaux.

Le contrôleur partagé revérifie après windup génération de lease, cible, bras/arme, portée et arc avant d'appliquer les dégâts. Les leases sont libérés sur fin de récupération, interruption, changement/perte de cible, mort et sortie d'arbre. `attack_scheduler_probe.gd` valide capacité, FIFO, expiration et générations; `enemy_action_state_probe.gd` valide les priorités windup/recovery/parry; `enemy_combat_probe.gd` valide les mécanismes élites communs.

La preuve exacte manquante lors du premier passage existe désormais : `enemy_unit_behavior_probe.gd -- --id=boss_bronze` instancie la route factory réelle, produit les décisions far/close, parcourt les deux étapes distinctes du pattern par `_begin_ai_attack()` puis `_resolve_ai_attack()`, et exige que chacune démarre et se résolve. Elle vérifie ensuite qu'un désarmement pendant le windup annule l'action sans délivrer de dégâts, que la perte de cible retire autorité et lease, puis que le teardown ne laisse aucun membre IA.

La coopération de groupe n'est pas réimplémentée par profil : le scheduler générationnel, ses limites/FIFO/expirations, les claims de cibles et le stress à deux cohortes sont les contrats autoritaires communs. Leurs probes passent. L'ensemble exact + mutualisé couvre donc le cycle solo/groupe sans exiger un doublon de test par ID.

## Navigation, blocage et retour

Mode exact : `EnemyNavigationComponent.Mode.DIRECT_STEERING`. `boss_bronze` n'est ni une phalange ni un grand ID configuré pour le navmesh.

Le composant partagé utilise une arrivée à 0,28 m, détecte un progrès insuffisant pendant 0,82 s puis tente une récupération latérale de 0,48 s à 72 % de la vitesse. La gravité et `move_and_slide()` restent portées par le `CharacterBody3D`.

- `enemy_navigation_component_probe.gd` passe intention, obstacles communs, fallback et récupération bornée du composant utilisé.
- `enemy_navigation_navmesh_probe.gd` passe chemin réel, détour, retarget, arrivée et fallback de carte vide, mais exerce `NAVMESH_GROUND`, pas le mode exact du boss.
- `DIRECT_STEERING` ne garantit volontairement aucun détour topologique. C'est l'identité du mode choisi pour ce profil, pas une panne locale; son contrat est l'esquive et la récupération locales bornées.
- Le probe comportement exact couvre les décisions loin/proche, la perte de cible et la bascule sommeil/réveil; le stress mixte couvre mouvement, cible mobile/changée et réveil en cohorte. Avec le probe composant, aucune divergence `boss_bronze` n'est reproduite.

## Rig, package, donneurs et clips

Le GLB visible contient un `Skeleton3D` à 53 os et aucune animation authored. La route package construit donc :

- le squelette visible du package;
- un donneur caché `UAL1_Standard.glb` et son pont de pose;
- un `HopliteNativeAnimationDriver` parce que le rang est miniboss et que des clés externes existent;
- les donneurs cachés UAL2 de locomotion et de combat, un `AnimationTree` natif et leurs ponts;
- un donneur Mixamo et un proxy de squelette pour chacune des deux clés externes uniques.

Le graphe exact est plus coûteux qu'un squelette partagé unique. L'inspection de construction conduit à huit `Skeleton3D` potentiels par instance complète (un visible, trois donneurs UAL, deux sources externes et deux proxies), cinq `AnimationPlayer` et un `AnimationTree`; ce compte est structurel, pas une télémétrie runtime instrumentée. Il doit être mesuré avant toute décision d'optimisation.

Les donneurs ne doivent pas être supprimés : le package n'a aucun clip local et aucune bibliothèque baked de remplacement, avec rendu comparatif, n'a été fournie. Leur proximité visuelle ou leur nom ne prouve pas l'identité des rigs.

Le probe animation confirme l'ouverture exacte : `BRONZE BOSS visual=retarget opener=bronze_thrust clip=external:vertical_sword`. Le probe comportement parcourt aussi les deux actions distinctes. La capture prouve idle, jog, attaque, impact, mort et section sans T-pose évidente. Une séquence rapprochée de la même instance améliorerait la preuve esthétique, mais l'état courant ne présente aucune panne d'animation reproductible.

## LOD, sommeil et réveil

Distances partagées : 16 / 38 / 90 m, niveaux 0/1/2/3.

- LOD0 : animation complète, ombres actives selon le mode de bataille.
- LOD1 : cadence réduite à environ 30 Hz et `lod_bias=0,55`.
- LOD2 : cadence environ 12 Hz, `lod_bias=0,22`, ombres coupées.
- LOD3 : arbre/lecteurs figés et géométrie au-delà de la coupure 90 m.
- Au réveil, `force_simulation_sample()` réactive temporairement les composants, échantillonne immédiatement, puis restaure l'état de pause pour éviter une pose périmée.

`enemy_animation_lod_probe.gd` passe les routes shared/native/direct et le réveil réversible; sa branche native exerce le même driver lourd package/retarget que `boss_bronze`, y compris désactivation LOD3 puis `force_simulation_sample()` au retour. Le probe comportement exact complète cette preuve par la bascule de participation IA sleep/wake de l'ID lui-même. Le contrat de wake est couvert.

## Package, meshes et rendu

Audit statique de `assets/characters/3dgen_demo/bossbronze.glb` :

| Mesure | Valeur |
|---|---:|
| taille GLB | 13 302 720 octets |
| nœuds / skins / joints | 83 / 1 / 53 |
| meshes / primitives | 28 / 28 |
| surfaces corporelles segmentées | 10 |
| caps gore cachés | 18, soit 2 par cible de section hors cou |
| triangles corps LOD0 | 20 000 |
| triangles caps | 1 656 |
| triangles totaux source | 21 656 |
| matériaux | 2 |
| textures | 2 PNG, 2 048 × 2 048 |

L'import active tangentes, shadow meshes et `meshes/generate_lods=true`. Le corps conserve dix surfaces visibles afin que les membres puissent être masqués/détachés; aucune fusion ne doit être imposée sans test de skinning et de démembrement. Le runtime n'appelle pas `optimize_body_meshes()` sur cette branche package.

Les deux textures source pèsent environ 7,01 MB et 2,91 MB et sont importées avec `compress/mode=0`, mipmaps actives et `vram_texture=false`. Pour un asset 3D répété, ce mode lossless est une dette probable de mémoire/bande passante; seul un profilage VRAM/GPU peut quantifier le gain d'un format VRAM compressé.

La capture globale 22/22 prouve la présence du modèle en Compatibility et l'absence de pose en T grossière. Elle est trop distante pour contrôler coutures, caps, ombres, clipping de lance ou LOD généré. Aucun relevé de draw calls ou de batching ne complète cette inspection.

## Lance et adéquation animation

La route package construit une lance procédurale sous la main droite : fût, pointe et talon, longueur source d'environ 2,05 m avant les échelles `weapon_scale=1,12` et racine `1,20`. Il n'y a pas de bouclier.

La section du bras ou de l'avant-bras droit déclenche le largage de la lance. Le probe exact de démembrement passe cette association et la planche montre le membre droit séparé avec l'arme libérée.

Les deux actions utilisent des donneurs de **sword**, tandis que `_update_phalanx_equipment_pose()` contient une correction explicite d'orientation/visée de lance réservée aux unités de phalange. `boss_bronze` a `behavior=reach` et ne reçoit donc pas cette correction. Le cycle mécanique passe et la planche rend une attaque lisible avec lance en main; aucune panne locale n'est reproduite. Une validation rapprochée main-pointe/frame de contact reste une amélioration de qualité d'asset, pas un blocage fonctionnel.

## Anatomie, démembrement et physique

Le profil commun fournit 12 zones et 10 entrées sectionnables :

| Zone | Forme | Dégâts | Multiplicateur de section | Seuil | Conséquence |
|---|---|---:|---:|---:|---|
| `head` | sphère r=0,25 | ×1,70 | ×1,00 | 64 | fatal, tête |
| `neck` | capsule r=0,15 | ×1,85 | ×1,35 | 56 | fatal, redirige vers tête |
| `torso` | capsule r=0,34 | ×1,00 | ×0,35 | non | non sectionnable |
| `pelvis` | capsule r=0,30 | ×0,95 | ×0,30 | non | non sectionnable |
| `upper_arm_l/r` | capsule r=0,16 | ×0,78 | ×1,00 | 78 | avant-bras lié; côté droit lâche la lance |
| `forearm_l/r` | capsule r=0,14 | ×0,75 | ×1,10 | 60 | côté droit lâche la lance |
| `thigh_l/r` | capsule r=0,21 | ×0,88 | ×0,82 | 94 | tibia lié, boiterie |
| `shin_l/r` | capsule r=0,18 | ×0,84 | ×1,05 | 72 | boiterie; deux jambes = crawl |

Le manifeste GLB contient les dix segments skinnés et les 18 caps attendus. `enemy_unit_dismemberment_probe.gd -- --id=boss_bronze` passe `zones=12 severed=10`, avec route package réelle, fatalités, membres détachés et teardown.

Physique : `CharacterBody3D`, capsule principale rayon 0,39 / hauteur 1,82 à y=0,91, couche ennemie 4, masque monde + joueur et pas de collision ennemi-ennemi. Les zones anatomiques sont des `Area3D` couche 8. Membres/lance détachés passent en `RigidBody3D` couche 16, masque monde et sommeil autorisé; aucune collision concave dynamique n'est utilisée.

Dette : l'échelle 1,20 est appliquée au `CharacterBody3D` racine et affecte implicitement le collider. Cette mise à l'échelle uniforme passe les probes, mais il reste préférable de dimensionner explicitement les shapes physiques. Aucun test ne mesure ici largeur réelle, hauteur, step/sol, portée anatomique ou marge dans un passage étroit à cette échelle.

## Performance — état courant sans revendication de gain

Commande :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_performance_benchmark.gd -- --counts=1,12 --mode=both --warmup=30 --frames=60 --archetype=boss_bronze --registry=on --seed=13371
```

| Mode | Unités | Spawn ms | Nœuds | Objets | Ressources | Mémoire statique | Corps actifs | Tick p95 / max | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 1 | 273,507 | 86 | 1 769 | 150 | 75,23 MiB | 0 | 20,700 / 20,722 ms | PASS |
| idle | 12 | 379,653 | 955 | 2 880 | 150 | 81,17 MiB | 0 | 20,698 / 20,707 ms | PASS |
| actif | 1 | 337,677 | 87 | 1 772 | 150 | 75,55 MiB | 1 | 20,705 / 20,745 ms | PASS |
| actif | 12 | 490,785 | 967 | 2 905 | 150 | 81,32 MiB | 12 | 20,700 / 20,708 ms | PASS |

Les instantanés process/physics/FPS du script sont explicitement des diagnostics à rafraîchissement lent, pas des gates; l'échantillon `process=338,543 ms` du cas actif 1 est contaminé par ce mode d'échantillonnage et n'est pas interprété comme un coût par frame. Le cache de ressources explique aussi qu'ajouter 11 unités après le premier chargement ne duplique pas toute la mémoire source.

Il n'existe aucune baseline antérieure strictement comparable : aucun gain avant/après n'est revendiqué. Le mode headless Compatibility ne mesure ni draw calls, ni VRAM, ni coût GPU, ni stalls de compilation, et le scénario ne répète pas sections/morts/transients. Un groupe de 12 boss est un stress structurel, pas une densité de gameplay validée.

## Preuves visuelles inspectées

Fichier principal : `docs/enemy_refactor/visual_evidence/boss_bronze.png` (1 352 × 760, inspection en résolution originale).

- Six acteurs distincts : `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`.
- Silhouette package noire/bronze cohérente et posée au sol; aucune T-pose évidente.
- Idle et jog cachent volontairement l'équipement. Ils ne prouvent donc pas l'attache ni l'orientation de repos de la lance.
- Attaque : lance présente, geste distinct, mais pointe fortement projetée vers caméra/sol et arme traversant la scène. Sans vidéo/frame d'impact, l'alignement exact reste indécidable.
- Impact : réaction corporelle visible. Mort : corps horizontal. Section : membre droit et sang visibles, lance libérée; l'image ne mesure pas TTL, sommeil ou collision.
- La planche juxtapose six instances, pas six états consécutifs de la même instance. Elle ne prouve ni transitions, ni retour idle, ni sweep complet, ni réveil LOD, ni combat de groupe.
- Aucune rotation 360°, vue rapprochée des mains/caps, vue collider ou scène authored n'est fournie.

Les captures `lab_full_roster_visual_probe.png` et `forge_full_roster_visual_probe.png` ont également été inspectées. Elles montrent les 22 IDs en grille sous Compatibility, avec `boss_bronze` présent et sans T-pose grossière. Leur cadrage global est trop distant pour valider les détails de cette unité. Les captures existantes n'ont pas été régénérées afin de respecter la lecture seule du runtime et des preuves centrales.

## Tests exécutés

| Test | Résultat | Portée réelle |
|---|---|---|
| `enemy_unit_behavior_probe.gd -- --id=boss_bronze` | PASS exact | factory/package réel, décisions far/close, deux attaques scheduler/windup/resolve, désarmement sans dégâts, perte cible/lease, sleep/wake, cleanup |
| `enemy_unit_dismemberment_probe.gd -- --id=boss_bronze` | PASS, `zones=12 severed=10` | exact, package, zones, caps, lance, fatalités et teardown |
| `enemy_full_roster_validation_probe.gd` | PASS, `22/22` | ligne exacte : `legacy_elite`, `package_retarget`, `12/12`, spear, `bronze_thrust`, `DIRECT_STEERING`, teardown |
| `enemy_factory_route_probe.gd` | PASS | toutes les routes recensées passent par la factory |
| `enemy_faction_targeting_probe.gd` | PASS | groupes, cibles, claims, représailles, friendly fire et cleanup; transversal |
| `attack_scheduler_probe.gd` | PASS | capacité, FIFO, expiration, leases générationnels; synthétique |
| `enemy_action_state_probe.gd` | PASS | garde/recovery/windup/parry/priorités; transversal |
| `enemy_combat_probe.gd` | PASS | garde, break, parry et patterns élites; complète le probe comportement exact |
| `enemy_animation_probe.gd` | PASS | exact : `bronze_thrust -> external:vertical_sword` |
| `enemy_animation_lod_probe.gd` | PASS | routes native/shared/direct, cadence et réveil; même driver natif package/retarget |
| `enemy_navigation_component_probe.gd` | PASS | intention, obstacles communs, fallback et récupération bornée; composant exact du mode |
| `enemy_navigation_navmesh_probe.gd` | PASS | vrai path/détour/retarget/arrivée; mode différent du boss |
| `enemy_transient_lifecycle_probe.gd` | PASS | ressources bornées, TTL, retrait collisions/ombres; transversal |
| `enemy_mixed_stress_probe.gd` | PASS, `22/36` | 22 familles, 36 unités, deux cohortes, cible mobile/changée, wake, 4 sections, 4 morts et cleanup |
| `enemy_authored_equipment_probe.gd` | PASS | `knight3` fallback uniquement; pas la route package effective |
| `enemy_roster_audit.gd` | PASS technique, sortie trompeuse | affiche `knight2` et deux clés comme donneurs malgré la route package gagnante |
| benchmark ciblé 1/12 idle/actif | PASS | CPU/structure/mémoire/teardown actuels; pas de baseline ni GPU |
| captures Lab et Forge réelles | PASS, `22/22` | vrai contexte Lab + vrai `WorldRuntime` Forge, présence/rendu Compatibility sans T-pose grossière |
| LOD shared/native/direct existant | PASS | contrat natif package/retarget et réveil forcé; sleep/wake exact aussi couvert par behavior probe |
| mort atomique existante | PASS | état/collisions/leases/cible/animation; accumulation de corps non mesurée |

Journaux frais : `.tmp_tools/enemy_refactor/boss_bronze_*.log`. Les runs Godot émettent le bruit environnemental Windows `Failed to read the root certificate store`, sans échec fonctionnel. Deux lancements initialement parallèles ont aussi rencontré un conflit sur le journal global `user://`; ils ont été relancés séquentiellement avec des fichiers uniques et ne constituent pas un défaut de l'unité.

## Limites et dettes non bloquantes à remonter

1. `enemy_roster_audit.gd` annonce le fallback `knight2` comme package courant et appelle « donors » le nombre de clés externes. Il doit rapporter séparément route résolue, fallback disponible, clés externes et instances runtime.
2. Le manifeste déclare une route primaire `authored` non retrouvée. Forge et le vrai contexte Lab sont prouvés; il faut seulement aligner la documentation de contenu avec les routes réellement maintenues.
3. Le nom historique contient « boss », mais le contrat explicite `miniboss` monophasé est cohérent et fonctionnel. Ne pas ajouter artificiellement des phases pour satisfaire le nom.
4. Le package animé cumule squelette visible, donneur UAL1, deux donneurs UAL2 et deux paires source/proxy externes. C'est une dette CPU/mémoire potentielle; aucun donneur ne doit être supprimé sans remplacement baked et comparaison rendue.
5. Les deux textures 2K lossless non-VRAM et les dix surfaces visibles sont coûteuses pour un asset répété. Les surfaces sont aussi le mécanisme de démembrement : fusion/compression exigent des preuves fonctionnelles et visuelles.
6. Les clips de sword appliqués à la lance sont mécaniquement fonctionnels et lisibles dans la preuve actuelle. Une capture rapprochée des deux contacts pourrait améliorer la qualité d'asset sans conditionner DONE.
7. `DIRECT_STEERING` n'offre volontairement pas de détour topologique. Son contrat de récupération locale bornée est couvert; employer un mode navmesh serait un changement de design, pas une correction de panne.
8. L'échelle 1,20 du `CharacterBody3D` n'est pas remplacée par des dimensions de shapes explicites. Les probes ne reproduisent aucun défaut, mais une mesure collider/portée monde améliorerait la robustesse physique.
9. Les planches globales sont distantes et la planche unité emploie six acteurs séparés en cachant la lance en idle/jog. Elles suffisent au contrôle de lisibilité/T-pose demandé, pas à une revue cinématique fine.
10. Les probes de teardown détruisent les instances, alors que les cadavres réels attendent le cleanup de leur propriétaire. Le coût d'une accumulation de corps reste un sujet de profilage partagé.
11. La preuve authored `knight3` est valide mais ne doit pas être attribuée à la route effective package.

## Suites recommandées, non bloquantes

1. corriger l'outil d'audit de route afin que le ledger distingue package gagnant, fallback Mixamo, clés externes et donneurs réellement construits;
2. aligner la route `authored` du manifeste avec le contenu réellement maintenu;
3. rendre, lors d'une passe qualité d'asset, une même instance en rotation avec lance visible au repos et les deux frames de contact;
4. instrumenter par instance squelettes/os, lecteurs, arbres, meshes/surfaces, matériaux, draw calls et VRAM, puis établir une baseline comparable;
5. tester une texture VRAM compressée et toute réduction de donneurs/surfaces avec comparaison visuelle, animation, LOD, wake et démembrement. Ne supprimer aucun donneur avant cette preuve;
6. conserver `rank=miniboss` et l'absence de phases comme contrat tant qu'une évolution de design explicite ne les remplace pas.

**Conclusion : DONE.** Les critères fonctionnels sont verts sur la route package réelle et aucune panne locale reproductible ne justifie un blocage.
