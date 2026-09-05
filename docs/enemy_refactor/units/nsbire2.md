# Audit final — `nsbire2`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable, build officiel `5b4e0cb0f`**\
**Portée : état courant du worktree; code runtime central examiné strictement en lecture seule.**

## Synthèse

`nsbire2` est l'archer léger du roster de remplacement. Son identité runtime est univoque : troupe `archer_support`, comportement `ranged`, arc sans bouclier, défense d'esquive légère, 48 PV, vitesse 4,55 m/s et portée nominale de 18 m. Il valorise les positions hautes, refuse de marcher dans le vide, accepte une pente continue et retarde son repli de 0,82 s lorsqu'un adversaire atteint sa plateforme.

La factory, le package, le rig, l'opener d'attaque, le projectile, la navigation, l'anatomie, la section, la mort, le sommeil/réveil et le teardown passent leurs contrats. Le probe exact localise 12 zones et en sectionne 10; le roster global valide les 22 identités. Les captures unité, Lab et Forge ont été inspectées : aucune T-pose, arc cohérent dans la main, états lisibles et équipement détaché après section.

## Profil et construction

Source de vérité : `scripts/enemy/enemy_archetypes.gd:577-630`.

| Champ | Valeur |
|---|---:|
| nom / rôle / rang | `ARCHER LEGER` / `archer_support` / `troop` |
| skin / échelle | `flanker` / `0.98` |
| PV / vitesse | `48.0` / `4.55` |
| dégâts / portée / aggro | `12.0` / `18.0` / `26.0` |
| arme / bouclier | `bow` / `false` |
| comportement / style | `ranged` / `archer` |
| livraison | `projectile`, flèche |
| vitesse / gravité / dispersion | `22.0` / `5.2` / `0.022` |
| windup / recovery | `0.58` / `0.32` |
| cooldown | `1.35–1.85` |
| bande préférée | `3.65–13.5` |
| hauteur / délai de repli | `1.0` / `0.82` |
| séparation / approche | `1.45` / `0.96` |
| défense / poise | `dodge` à `10 %` / `0.02` |
| pattern | `archer_draw_release`, `light2`, `external:bow_aim`, projectile |
| coût / poids procédural | `1.10` / `0.72`, dès la vague 1 |

- `HopliteEnemyArchetypeData` expose une vue typée, normalisée et mise en cache du profil. Le probe des données confirme les 22 vues, dont `nsbire2`.
- `HopliteEnemyFactory.spawn_request()` pose ID, position, cible, participation IA, mode de masse et package avant `add_child()` (`enemy_factory.gd:49-82`). Le contrôleur applique ensuite le profil, le collider, le visuel, l'anatomie et la navigation.
- Le package est résolu vers `res://assets/characters/3dgen_demo/nsbire2-1787348495833.glb`. Il existe et pèse 5 179 752 octets. Son import active tangentes, génération des LOD, shadow meshes, skins nommées, animations à 30 FPS et suppression des pistes immuables.
- Le probe de route confirme que toutes les constructions runtime convergent sur la factory canonique; le probe Battle conserve les contrats hostile et helper spartiate.

## Rig, animations et identité visuelle

- Le package passe `HopliteSpartanCharacterPackage.bind()` : schéma 1, rig `spartan_ual1_v1`, squelette exact de 53 os, os essentiels présents, dix maillages corporels segmentés et gore caps associés (`spartan_character_package.gd:6-118`).
- Route effective : `package_retarget`. Le rig visible reste le package auteur. Un donneur UAL1 invisible fournit la locomotion et `HopliteAuthoredPoseBridge` copie sa pose; l'archer actif hors mode de masse ajoute le driver sélectif requis pour `bow_aim` (`athenian_enemy.gd:2956-3038`).
- Le probe d'animation joue l'opener exact `archer_draw_release` sur `external:bow_aim`. Le roster spécialisé confirme que l'ancien clip inadapté `Pistol_Shoot` n'est pas déclaré.
- L'arc procédural `HuntingBow` est attaché à la main gauche. Ses branches sont tournées de 90° autour de Z afin de rester perpendiculaires à l'avant-bras; cette orientation est vérifiée par `enemy_roster_audit.gd`.
- La perte d'un bras ou avant-bras gauche fait tomber l'arc. Le débris emploie une collision boîte dimensionnée pour l'arc, peut dormir et reçoit un lifecycle borné; les ressources visuelles restent partagées.
- Aucun donneur n'est supprimable au terme de cet audit. Le donneur UAL1, le pose bridge et le donneur sélectif `bow_aim` sont encore requis par la route actuelle. Toute suppression demanderait une preuve animée équivalente, les six captures visuelles et une mesure avant/après dédiée.

## Combat, projectile et visée

- Le pattern possède une seule étape déclarative : windup 0,68 s, recovery 0,34 s, cooldown 1,42 s, multiplicateur de dégâts 1,0 et livraison projectile. Le scheduler partagé accorde une permission FIFO exactement comme pour la mêlée; l'archer ne contourne pas la capacité de foule.
- Le probe comportement exact force l'étape à travers acquisition, windup et résolution réels. Le désarmement pendant le windup termine l'attaque en état `disarmed` sans dégât; la perte de cible libère le lease.
- `_spawn_ai_projectile()` part de l'attache d'arc, vise `get_combat_aim_point()` lorsqu'il existe, anticipe une cible `CharacterBody3D` selon sa vitesse et compense la chute par `0.5 * gravity * travel_time²` (`athenian_enemy.gd:2030-2057`). Le masque est factionnel.
- `HopliteEnemyProjectile` est un `Node3D` cinématique léger : un rayon balayé par tick physique, aucune `RigidBody3D` ni `Area3D`, exclusion du tireur, gravité, orientation sur la vélocité et TTL de 4 s (`enemy_projectile.gd:4-100`). Le probe lifecycle confirme le partage des meshes/matériaux, la réutilisation de la requête physique, l'absence d'ombres et la libération au TTL.
- La vérification de ligne de tir est effectuée avant l'émission. Le probe exact résout l'attaque dans un monde dégagé; le probe transverse de projectile valide ensuite son lifecycle. Il n'existe toutefois pas encore de probe unique combinant `nsbire2`, collision réelle d'une flèche et cible mobile située sur un autre niveau : c'est une lacune de couverture, pas une panne observée.

## IA de hauteur, navigation et foule

- Le probe `archer_high_ground_probe` passe les quatre contrats caractérisés : conservation d'une plateforme haute, acceptation d'une pente continue, suppression de la vélocité vers un bord sans sol et conservation de la fenêtre punitive de 0,82 s avant le repli.
- Quand le comportement est `ranged`, `_ai_goal()` rafraîchit la conscience de hauteur y compris en suivi de commandant (`athenian_enemy.gd:708-714`). Une plateforme occupée devient une préférence tactique; un recul ou une séparation ne peut pas l'attirer dans le vide.
- Mode exact : `DIRECT_STEERING`. `nsbire2` n'est ni phalange ni grand corps. Le composant reçoit arrivée à 0,28 m, progrès minimal 0,12 m/s, détection de blocage à 0,82 s, récupération latérale de 0,48 s et échelle de récupération 0,72 (`athenian_enemy.gd:689-706`).
- Le composant produit une intention seulement; le `CharacterBody3D` racine reste l'unique propriétaire de `velocity` et `move_and_slide()`. Le probe navigation transverse passe intention, formation, fallback navmesh et récupération.
- `set_ai_participation(false)` libère cible et permission, annule attaque et destination, retire les groupes et invalide l'index spatial. Le réveil reconstruit le composant et rétablit les groupes; le probe exact confirme la parité.
- Le crowd director fournit cible stable, séparation locale et leases FIFO. Son index spatial est actualisé à 20 Hz. Le steering direct ne garantit cependant pas un chemin global autour d'un obstacle complexe comme le ferait un navmesh; les routes actuelles conservent cette limite qualitative.

## Anatomie, collisions et cycle de vie

Le profil humain partagé expose douze zones (`scripts/enemy/anatomy_profile.gd:8-76`) :

| Zones | État |
|---|---|
| tête, cou | sectionnables et fatales; le cou redirige vers la tête |
| torse, bassin | localisés, non sectionnables |
| bras/avant-bras gauche et droit | sectionnables; le côté gauche ou droit pertinent provoque la perte de l'arc |
| cuisses/tibias gauche et droit | sectionnables; la perte bilatérale dégrade la locomotion |

- Résultat exact : `zones=12 severed=10`. Toutes les zones enregistrent les dégâts localisés; les dix sections permises appliquent visibilité, caps, fragment et fatalité attendue.
- Le corps est une capsule primitive sur `CharacterBody3D`. Les volumes anatomiques emploient sphères/capsules; aucune forme concave dynamique n'est créée. Il n'existe pas de hitbox de bouclier pour cette unité.
- La section d'un bras porteur appelle `_drop_weapon()`; l'arc porté devient invisible et une copie physique temporaire est créée avec ressources partagées (`athenian_enemy.gd:4215-4265`).
- La mort coupe atomiquement IA, groupes, navigation, lease et registry avant la présentation du cadavre. Projectiles, sang, fragments et équipement détaché ont des TTL et retirent collision/ombres avant libération.

## Routes vérifiées

- Combat Lab : roster principal, ligne dédiée de trois archers, escouade mixte, annexe `NSBIRE II — ARCHERS` et groupe élite (`scripts/main.gd:303-332`, `:491-547`).
- Battle 03 : dix archers en zone 1, archers latéraux en zone 2 et huit archers de la phalange finale (`battle_03_narrative.gd:333`, `:391`, `:416`).
- Procédural : trois compositions de légion incluent `nsbire2`; chaque demande passe par `EnemySpawnRequest` puis `EnemyFactory.spawn_request()` (`procedural_wave_director.gd:314-323`, `:587-616`).
- Forge : les entités et groupes choisissent leur archétype puis appellent `EnemyFactory.spawn()` (`world_runtime.gd:310-370`).

## Performance structurelle ciblée

Commande : `--counts=1,28 --mode=both --warmup=30 --frames=60 --archetype=nsbire2 --registry=on`. Le seuil de masse de 28 est inchangé et chaque scénario utilise `mass_battle_mode=true`.

| Scénario | Spawn | Nœuds / objets pendant | Mémoire statique pendant | Physique diagnostic | Nettoyage |
|---|---:|---:|---:|---:|---|
| 1 inactif | 67,682 ms | 87 / 1 769 | 45 304 869 o | 0,747 ms | PASS |
| 28 inactifs | 301,412 ms | 2 247 / 4 496 | 59 286 411 o | 2,188 ms | PASS |
| 1 actif | 86,970 ms | 88 / 1 772 | 46 212 677 o | 0,811 ms | PASS |
| 28 actifs | 474,882 ms | 2 275 / 4 553 | 59 628 779 o | 7,891 ms | PASS |

Pour 28 actifs, l'intervalle physique mesuré donne p95 23,102 ms et maximum 25,955 ms sur ce run court. Les 28 références ennemies, le registry et tous les groupes reviennent à zéro; aucun nœud orphelin n'est relevé. Ces chiffres headless sont diagnostiques : ils ne constituent ni un benchmark GPU ni une comparaison statistique avant/après.

## Preuves visuelles inspectées

- `docs/enemy_refactor/visual_evidence/nsbire2.png` : six états `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`. Poses distinctes, arc lisible, mort au sol, arc et membre séparés après section; aucune T-pose.
- `docs/enemy_refactor/lab_full_roster_visual_probe.png` : `nsbire2` est présent dans le roster complet posé sur la scène réelle du Lab; silhouette et échelle restent cohérentes avec l'infanterie légère.
- `docs/enemy_refactor/forge_full_roster_visual_probe.png` : l'unité est présente dans le document Forge réel; aucune divergence visible de rig, d'échelle ou d'équipement.

## Tests exécutés

| Test | Résultat |
|---|---|
| `enemy_unit_dismemberment_probe.gd -- --id=nsbire2` | PASS — 12 zones, 10 sections |
| `enemy_unit_behavior_probe.gd -- --id=nsbire2` | PASS — loin/proche, projectile, interruption, cible perdue, sleep/wake, cleanup |
| `enemy_full_roster_validation_probe.gd` | PASS — 22/22; `package_retarget`, arc, `archer_draw_release`, `DIRECT_STEERING` |
| `archer_high_ground_probe.gd` | PASS — maintien, pente, verrou de bord, repli retardé |
| `enemy_roster_audit.gd` | PASS — profil projectile, `bow_aim`, arc à 90°, aucun `Pistol_Shoot` |
| `enemy_animation_probe.gd` | PASS — opener `external:bow_aim` |
| `enemy_transient_lifecycle_probe.gd` | PASS — ressources partagées, requête réutilisée, TTL, pas d'ombres |
| `enemy_navigation_component_probe.gd` | PASS — intention, formation, fallback, récupération |
| `enemy_archetype_data_probe.gd` | PASS — 22 vues typées conformes |
| `battle_enemy_spawn_probe.gd` | PASS — contrats Battle hostile/helper |
| `enemy_factory_route_probe.gd` | PASS — routes de création canoniques |
| `enemy_combat_probe.gd` | PASS — contrats combat transverses |
| `enemy_performance_benchmark.gd` ciblé | PASS — 1/28, idle/active, registry, teardown |

Logs : `.tmp_tools/enemy_refactor/logs/nsbire2_*.log`. Le message Windows `Failed to read the root certificate store` est du bruit d'environnement; tous les runs retenus sortent avec code 0.

Le probe global `combat_attack_probe.gd` a été rejoué après correction : `radial_hit=true`, `failures=0`, code 0. Ce scénario joueur reste transversal et n'est pas la preuve principale de l'archer, mais il n'existe plus de rouge global à exclure.

## Limites et risques résiduels non bloquants

1. **Donneurs encore requis** — le package visible conserve le donneur UAL1, le pose bridge et, hors masse, le driver sélectif `bow_aim`. Aucune suppression n'est autorisée sans preuve animée et mesure avant/après.
2. **Couverture balistique dissociée** — le comportement exact prouve la résolution projectile, le probe hauteur prouve le terrain et le lifecycle prouve la flèche; aucun scénario unique ne mesure encore l'impact réel sur une cible mobile élevée.
3. **Steering direct** — arrivée et récupération locale sont testées, mais aucun navmesh n'assure le contournement global d'obstacles complexes.
4. **Mode de masse simplifié** — à 28 unités, le driver détaillé sélectif n'est pas créé; la route économique UAL1 est intentionnelle et les captures de roster restent cohérentes, mais la fidélité de `bow_aim` en foule n'a pas une capture isolée dédiée.
5. **Échelle physique** — l'échelle racine uniforme 0,98 reste faible et les volumes suivent le monde, mais le guide physique préfère dimensionner les shapes plutôt que scaler un corps.
6. **Mesure headless courte** — le run prouve structure et teardown, pas draw calls, VRAM ou FPS rendu en combat réel.
7. **Combat joueur transversal** — `combat_attack_probe` passe désormais, y compris le hit radial; la couverture propre à l'archer reste portée par ses probes projectile/hauteur/lifecycle.

## Verdict

**DONE.** `nsbire2` conserve son identité d'archer léger, son profil fragile, sa bande de tir, sa préférence de hauteur, son repli retardé, son package 53 os, son animation d'arc, son projectile compensé par gravité, ses 12 zones et ses 10 sections. Les routes Lab, Battle 03, procédural et Forge convergent sur la factory; les preuves unitaires et transverses propres à l'archer passent, les trois captures visuelles sont acceptables et le teardown est propre à 1 comme à 28 unités.

Aucun défaut fonctionnel concret et reproductible propre à `nsbire2` ne justifie `BLOCKED`. Les donneurs restent explicitement non supprimables; la couverture balistique dissociée, le steering direct, la simplification du driver en masse et le coût structurel sont documentés comme dettes non bloquantes.
