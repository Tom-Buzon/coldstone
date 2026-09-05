# Audit final distinct — `nathenian2_soldier`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable (`5b4e0cb0f`)**\
**Renderer des probes : `gl_compatibility`, headless**\
**Portée : état courant du worktree; runtime central inspecté en lecture seule, écriture limitée au présent rapport et aux logs dédiés.**

## Verdict synthétique

`nathenian2_soldier` est bien une identité de troupe distincte et non une promotion cachée du miniboss `nathenian2`. L'alias réutilise volontairement le package, le marteau, l'armure, le comportement lourd et les trois attaques de base de la famille, mais remplace explicitement le nom, le rôle, le rang, l'échelle, les PV, les dégâts, la vitesse, le poise et le coût. Sa phase 2 est supprimée par contrat (`phase_threshold=0`, pattern vide), et la factory le construit avec `is_miniboss=false` puisque sa vue typée porte le rang `troop`.

Les probes exactes passent le comportement loin/proche, les trois attaques déclaratives, l'interruption par désarmement, la perte de cible, le sommeil/réveil, les douze zones anatomiques, les dix sections autorisées, l'équipement, la mort atomique et le teardown. Les routes Battle 03 et Forge sont présentes; le roster global passe `22/22`. Les trois captures inspectées montrent une silhouette lourde cohérente, un marteau attaché en vie, une attaque lisible, une mort et une section sans T-pose grossière.

Verdict final : **DONE**. Aucun défaut fonctionnel reproductible propre à l'alias ne subsiste. Les limites honnêtes sont une navigation `DIRECT_STEERING` sans garantie de détour topologique, un donneur UAL1 et des donors externes encore requis, une échelle physique racine uniforme héritée, et un p95 de tick à 23,536 ms dans le court scénario headless de 28 actifs. Aucun donneur ou asset source ne doit être supprimé sans remplacement animé et preuve visuelle équivalente.

## Contrat d'alias et profil canonique

La source de vérité est `scripts/enemy/enemy_archetypes.gd:37-68`. `profile()` part du profil `nathenian2`, en fait une copie profonde, puis applique les substitutions suivantes :

| Champ distinct | `nathenian2_soldier` | `nathenian2` |
|---|---:|---:|
| ID runtime | `nathenian2_soldier` | `nathenian2` |
| nom | `FANTASSIN LOURD ATHENIEN` | `BRISEUR DE LIGNE` |
| rôle / rang | `heavy_infantry` / `troop` | `line_breaker` / `miniboss` |
| échelle | `1.06` | `1.18` |
| PV | `185` | `430` |
| dégâts | `21` | `34` |
| vitesse | `4.05 m/s` | `3.85 m/s` |
| poise | `0.34` | `0.58` |
| phase 2 | aucune, seuil `0` | seuil `0.48`, deux actions |
| coût procédural | `2.15` | `4.20` |

Le reste de l'identité de famille est volontairement partagé : skin `brute`, portée `2.10 m`, aggro `22 m`, marteau à l'échelle `1.16`, comportement `brute`, style `heavy`, windup/recovery de base `0.48/0.52 s`, cooldown `1.30-1.68 s`, armure dégâts x`0.84`, armure section x`0.70`, poids procédural `0.28`, première vague `3` et quatre clés d'animation externes.

`HopliteEnemyArchetypeData` conserve l'ID demandé lors de la normalisation. Le probe typé vérifie explicitement pour cet alias : ID inchangé, rang `troop`, rôle `heavy_infantry`, nom distinct et package dont le fichier commence par `nathenian2-`. Le cache renvoie une ressource typée immuable par ID et des copies profondes aux consommateurs legacy; l'alias ne partage donc pas un objet de configuration mutable avec le miniboss.

Le roster détaillé fournit la preuve compacte attendue :

```text
ENEMY FANTASSIN LOURD ATHENIEN rank=troop weapon=hammer defense=armor
pattern=3/0 donors=4 package=nathenian2-1787346736278.glb
```

La présence résiduelle des multiplicateurs de phase hérités est inerte : `_try_activate_combat_phase()` ne peut transitionner que si `phase_threshold > 0`; ici le seuil vaut zéro et `phase_two_pattern` est vide. L'unité reste donc en `combat_phase=1`.

## Factory et routes de contenu

`HopliteEnemyFactory.spawn_request()` est l'unique point de construction. Il conserve `request.archetype`, résout la vue typée de cet ID, applique `is_miniboss_or_boss()` — faux ici — et affecte le package avant `add_child()`. `_apply_archetype_profile()` réapplique ensuite le rang `troop`; elle ne promeut que les rangs `miniboss` ou `boss`.

Routes vérifiées :

- **Battle 03** : trois fantassins lourds dès la zone 1, renforts lourds aux secondes 4/9/13, support des deux côtés en zone 2 et quatre gardes lourds en zone 3 (`scripts/battle/battle_03_narrative.gd:335`, `:350`, `:389`, `:419`). Le probe de bataille narrative charge la scène réelle et passe.
- **Forge** : `HopliteWorldRuntime.spawn_enemy_group()` résout l'ID de chaque `enemy_group`, puis appelle `EnemyFactory.spawn()` (`scripts/world_editor/world_runtime.gd:293-322`). La preuve Forge fabrique un document réel avec un groupe exact par ID et récupère exactement une unité dans `enemies_by_group`.
- **Combat Lab** : l'alias n'est pas une entrée historique dédiée du showroom principal, ce qui correspond au manifeste `primary_routes=[battle_03, forge]`. La preuve d'intégration ajoute néanmoins les 22 IDs par la vraie factory dans une annexe de la scène Lab réelle; elle ne prétend pas transformer cette annexe en route narrative permanente.

Le seuil du mode masse reste exactement `28` dans la Forge. Aucun chemin parallèle de construction n'a été découvert; `enemy_factory_route_probe` confirme que toutes les constructions runtime convergent sur la factory canonique.

## Combat, comportement et absence de phase

Le comportement `brute` garde l'identité d'un fantassin lourd : état d'approche explicite hors portée, attaque au contact, vitesse d'approche réduite x`0.86`, séparation `0.62` et armure sans garde ni bouclier. Le scheduler partagé contrôle acquisition FIFO, windup, résolution, recovery et libération du lease.

Le probe exact parcourt les trois pas distincts du pattern réel :

| Action | Animation externe | Windup | Recovery | Cooldown | Effet distinctif |
|---|---|---:|---:|---:|---|
| `hammer_overhead` | `axe_down` | 0.62 | 0.58 | 1.08 | dégâts x1.34, portée x1.08 |
| `hammer_shove` | `mutant_punch` | 0.34 | 0.30 | 0.62 | dégâts x0.72, portée x0.86, lunge 4.2 |
| `hammer_sweep` | `mutant_swipe` | 0.50 | 0.50 | 0.98 | dégâts x1.02, portée x1.18, arc large |

`enemy_unit_behavior_probe --id=nathenian2_soldier` passe le choix de but loin/proche, démarre et résout chaque entrée via la vraie permission d'attaque, observe les trois IDs distincts, puis vérifie qu'un désarmement pendant le windup n'inflige aucun dégât. La suppression de la cible libère le lease; `set_ai_participation(false)` efface cible, attaque, mouvement, destination et groupes, puis le réveil restaure le composant sans état figé.

Ce contrat est volontairement plus simple que celui du miniboss : il n'existe ni `hammer_quake`, ni `hammer_rush`, ni signal de phase à préserver pour cet alias. L'absence de phase est une différence de gameplay requise, pas un manque de contenu.

## Navigation et coordination de foule

Mode exact : `EnemyNavigationComponent.Mode.DIRECT_STEERING`. L'unité n'est ni phalange ni grand corps, donc elle ne crée pas de `NavigationAgent3D`. Le composant retourne une intention et le `CharacterBody3D` racine reste l'unique propriétaire de `velocity` et `move_and_slide()`.

Configuration commune observée à `scripts/enemy/athenian_enemy.gd:689-706` : arrivée à `0.28 m`, progrès minimal `0.12 m/s`, blocage à `0.82 s`, récupération latérale `0.48 s` à 72 % de la vitesse. Le probe navigation passe intention, arrivée/formation, fallback et récupération. Le crowd director maintient cibles stables, séparation et permissions; sa grille spatiale est rafraîchie à 20 Hz et invalidée immédiatement lors du sommeil, du réveil ou de la mort.

Limite non bloquante : ce steering avec récupération locale n'assure pas un détour navmesh autour d'un grand obstacle complexe. Les routes actuelles et le stress mixte restent fonctionnels, mais un futur niveau labyrinthique devrait recevoir un probe de détour spécifique avant livraison.

## Rig, animations, assets et LOD

Le package partagé est `res://assets/characters/3dgen_demo/nathenian2-1787346736278.glb` (10 060 384 octets). Son import active tangentes, déduplication des surfaces, named skins, LOD, shadow meshes et animations à 30 FPS avec suppression des pistes immuables.

`HopliteSpartanCharacterPackage.bind()` impose le schéma `spartan_ual1_v1`, un squelette exact de 53 os, les os essentiels, dix meshes corporels segmentés et les caps gore corps/membre associés. La route effective est `package_retarget` : un donneur UAL1 invisible anime le rig visible par le pose bridge, tandis que `HopliteNativeAnimationDriver` charge sélectivement les quatre actions externes. Le log du comportement exact confirme le démarrage du driver natif; le roster 22/22 confirme le rig et l'opener `hammer_overhead`.

`enemy_animation_probe` valide l'opener de cette famille sur le même package (`hammer_overhead -> external:axe_down`), mais agrège l'alias sous l'identité de base; la preuve vraiment exacte de l'alias reste son probe comportemental et sa planche dédiée. Le LOD transverse passe les branches shared/native/direct, leurs cadences et le réveil réversible. Aucun `AnimationTree` n'est gelé définitivement.

Le donneur UAL1 reste requis pour la locomotion et la mort, et les donors externes pour les coups spécialisés. Leur suppression est interdite tant qu'une bibliothèque bake/retarget ne reproduit pas Idle, Jog, les trois attaques, impact, mort, réveil et sections dans les captures unité, Lab et Forge.

## Équipement, physique, anatomie et cycle de vie

Le marteau procédural est attaché à `DEF-hand.R` avec le facteur `1.16`. Aucun bouclier ou hitbox de bouclier n'est créé. Le cache de matériaux partage peau, métal et bois par paramètres immuables; son probe passe.

Le corps principal est un `CharacterBody3D` à capsule primitive; aucun concave dynamique n'est utilisé. Le modèle, le collider et les volumes anatomiques héritent d'une échelle racine uniforme `1.06`. Cette pratique reste une dette par rapport à la recommandation générale de dimensionner les shapes directement, même si les probes physiques actuelles n'exposent aucune divergence et que les volumes monde suivent correctement l'échelle.

Anatomie exacte : tête, cou, torse, bassin, deux bras supérieurs, deux avant-bras, deux cuisses et deux tibias. Le probe crée une instance neuve par zone et conclut `zones=12 severed=10`. Torse et bassin sont localisés mais non sectionnables; les dix autres routes déclenchent la section attendue, tête/cou respectent la fatalité et le bras droit libère le marteau.

La mort est une sortie atomique : libération du lease et de la cible, `dead=true`, retrait de tous les groupes IA, destination effacée, collisions actives coupées, arrêt de la physique, équipement détaché et animation `Death01` non bouclée. Le cadavre devient ensuite render-only; projectiles, sang, membres et armes ont un TTL borné et retirent collisions/ombres avant libération. Les probes anatomie et lifecycle passent tous deux.

## Performance — mesure structurelle ciblée

Commande fraîche :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --audio-driver Dummy --rendering-method gl_compatibility --script res://tools/enemy_performance_benchmark.gd -- --counts=1,28 --mode=both --warmup=30 --frames=60 --archetype=nathenian2_soldier --registry=on
```

Tous les scénarios utilisent le mode masse et le registre. Les valeurs `process/physics` sont des snapshots diagnostiques lents; les intervalles de tick sont la mesure temporelle du harness.

| Mode | Unités | Spawn ms | Process / physics snapshot ms | Nœuds | Objets | Mémoire statique | Corps actifs | Tick p95 / p99 / max ms | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 1 | 151.365 | 0.466 / 0.484 | 88 | 1 772 | 62 253 819 o | 0 | 20.698 / 20.699 / 20.699 | PASS |
| idle | 28 | 380.539 | 390.895 / 3.319 | 2 275 | 4 553 | 78 474 301 o | 0 | 20.692 / 22.448 / 22.448 | PASS |
| actif | 1 | 211.089 | 0.547 / 1.095 | 89 | 1 775 | 63 162 571 o | 1 | 20.718 / 20.765 / 20.765 | PASS |
| actif | 28 | 567.560 | 10.435 / 7.449 | 2 303 | 4 610 | 78 807 705 o | 28 | **23.536 / 27.109 / 27.109** | PASS structurel |

Les 28 références ennemies, le registre et les groupes reviennent à zéro; aucune référence vivante ni nœud orphelin ne subsiste. Le snapshot `process=390.895 ms` du scénario idle 28 est manifestement une lecture lente ponctuelle et le harness lui-même la marque diagnostique; il ne doit pas être interprété comme un coût par frame. Le p95 actif dépasse toutefois le budget 16,67 ms et reste une dette mesurée. Il n'existe pas de baseline phase 0 strictement comparable pour cet alias; aucun pourcentage de gain ou de régression n'est revendiqué. Le run headless ne mesure ni GPU, VRAM, draw calls ni qualité visuelle LOD.

## Preuves visuelles inspectées

- `docs/enemy_refactor/visual_evidence/nathenian2_soldier.png` (1 351 x 760) : six états `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`. La silhouette claire est cohérente et au sol; la pose d'attaque au marteau diffère nettement des états nus, la mort est horizontale et la section montre un bras séparé. Aucune T-pose grossière n'est visible. Limites : idle/jog restent proches sur un instantané, le marteau et les débris masquent partiellement l'impact, et le membre sectionné est projeté loin à droite.
- `docs/enemy_refactor/lab_full_roster_visual_probe.png` (1 600 x 900) : les 22 IDs sont présents dans une annexe de la vraie scène Combat Lab. L'alias est construit et posé sans défaut grossier, mais personnages et labels sont trop petits pour juger précisément les attaches.
- `docs/enemy_refactor/forge_full_roster_visual_probe.png` (1 600 x 900) : le vrai document et `HopliteWorldRuntime` créent un groupe par ID. L'alias est présent sur le sol Forge; l'éclairage très clair réduit le contraste et la capture prouve l'intégration, pas la qualité fine.

Ces images prouvent présence, pose et séparation visuelle. Les transitions, dégâts, scheduler, phase absente et cleanup sont couverts par les probes exécutables, pas déduits d'un seul frame.

## Tests exécutés

| Test | Résultat | Portée / réserve |
|---|---|---|
| `enemy_unit_dismemberment_probe.gd -- --id=nathenian2_soldier` | PASS `zones=12 severed=10` | exact, fatalités, marteau, teardown |
| `enemy_unit_behavior_probe.gd -- --id=nathenian2_soldier` | PASS | exact, loin/proche, 3 attaques, désarmement, cible perdue, sleep/wake, cleanup |
| `enemy_full_roster_validation_probe.gd` | PASS `22/22` | `package_retarget`, marteau, `hammer_overhead`, `DIRECT_STEERING` |
| `enemy_roster_audit.gd` | PASS `22/22` | alias exact `troop`, pattern `3/0`, quatre donors, package partagé |
| `enemy_archetype_data_probe.gd` | PASS | ID/rang/rôle/nom/package de l'alias explicitement vérifiés |
| `enemy_archetype_cache_probe.gd` | PASS | 22 ressources typées immuables, copies legacy isolées |
| `enemy_factory_route_probe.gd` / options | PASS | route unique et compatibilité dictionnaire |
| `narrative_battle_probe.gd` | PASS | scène Battle 03 réelle, démarrage et cohortes narratives |
| `enemy_animation_probe.gd` | PASS `14/14` | opener spécialisé de la famille sur le package partagé |
| `enemy_animation_lod_probe.gd` | PASS | shared/native/direct, cadence et réveil réversible |
| `enemy_navigation_component_probe.gd` | PASS | intention, formation, fallback, récupération |
| `enemy_anatomy_regression_probe.gd` | PASS | une section létale finalise toujours la mort |
| `enemy_transient_lifecycle_probe.gd` | PASS | ressources partagées, TTL, retrait collision/ombres |
| `enemy_material_cache_probe.gd` | PASS | matériaux peau/arme partagés par paramètres immuables |
| `enemy_mixed_stress_probe.gd` | PASS `22 familles / 36 unités` | seuil 28, deux cohortes, cible mobile/changée, wake, 4 sections, 4 morts, cleanup |
| benchmark ciblé `1/28`, idle/actif | PASS structure/cleanup | p95 actif 28 à `23.536 ms`; pas de baseline alias |

Les journaux frais sont sous `.tmp_tools/enemy_refactor/logs/nathenian2_soldier_*.log`. Une première exécution du démembrement a crashé avant le chargement du probe sur l'ouverture concurrente du journal Godot `user://`; la relance isolée avec `--log-file` workspace passe. Le bruit Windows `Failed to read the root certificate store` et l'impossibilité d'écrire `user://.tmp_tools/enemy_refactor` n'affectent pas les résultats, tous les runs retenus terminant avec code 0.

## Revue Godot 4.7

### Critique

Aucune panne critique propre à `nathenian2_soldier` n'est reproduite.

### Améliorations / dette honnête

- Ajouter un probe négatif explicite qui frappe sous le seuil historique de 48 % et confirme l'absence d'émission `combat_phase_changed` pour l'alias; le contrat actuel est déjà protégé par les données `rank=troop`, `pattern=3/0` et `phase_threshold=0`, mais ce test rendrait l'intention encore plus lisible.
- Mesurer une bataille GPU réelle Lab/Forge avec draw calls, VRAM, nombre de surfaces et qualité des LOD; le headless ne couvre pas ces compteurs.
- Comparer `DIRECT_STEERING` à `NAVMESH_GROUND` seulement si de futurs niveaux exigent des détours complexes, sans altérer masse, vitesse ou espacement.
- À l'occasion d'une migration physique dédiée, remplacer l'échelle du `CharacterBody3D` par des dimensions de capsule/volumes déjà calculées à taille finale, puis refaire les douze probes de zones.
- Ne retirer UAL1 ou les donors externes qu'après un bake complet et des preuves animées multi-frame unité/Lab/Forge.

### Points solides

- Alias typé distinct et immutable, avec package partagé sans partage mutable de stats.
- Rang troupe et absence de phase cohérents de la source à la factory et au runtime.
- Trois attaques lourdes conservées et parcourues intégralement par le vrai scheduler.
- Navigation, LOD, sommeil/réveil et mort ont des sorties explicites et réversibles.
- Collisions dynamiques primitives, anatomie 12/12, sections 10/10 et teardown sans référence vivante.

---

Revu contre les checklists Godot 4.3+ / 4.7 de navigation, animation, physique, assets, 3D, testing, debugging et code review.
