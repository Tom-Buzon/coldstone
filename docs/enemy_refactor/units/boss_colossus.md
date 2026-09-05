# Audit final — `boss_colossus`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Archétype exact :** `boss_colossus`\
**Famille déclarée par le manifest :** `legacy_boss`\
**Famille runtime observée :** `package_retarget` / rang `miniboss`\
**Portée :** audit individuel de l'état courant; runtime, profils, scènes, assets et probes centraux examinés en lecture seule.

## Verdict

Le Colosse est constructible par la factory canonique et possède un socle fonctionnel réel : profil unique, marteau, faction/cibles partagées, deux attaques lourdes, rig visible UAL1 à 53 os piloté par donneur, anatomie `12/12`, dix zones sectionnables, mort atomique et teardown structurel. Le probe exact de démembrement termine en code `0` avec `zones=12 severed=10`; le full roster passe `22/22`; l'ouverture animée exacte `colossus_crush -> external:axe_down` est vérifiée; la planche existante montre six états distincts sans pose en T évidente. Un benchmark ciblé à 1 et 12 unités passe ses quatre scénarios et nettoie toutes les références suivies.

Le statut final est **DONE**. Deux gates individuelles ajoutées au runtime de validation ferment les incertitudes qui empêchaient auparavant ce verdict :

1. `enemy_large_body_contract_probe -- --id=boss_colossus` passe sur l'instance exacte. Il entérine `LARGE_BODY` comme steering direct volontaire sans `NavigationAgent3D`, vitesse bornée `0.78`, blocage simulé, récupération à `1.15 s / 0.72 s`, progrès sans `navigation_failed`, arrivée et clear de destination. Il valide aussi capsule primitive, absence de forme concave et échelle uniforme.
2. `enemy_unit_behavior_probe -- --id=boss_colossus` passe toutes les décisions et actions réelles : far/close, les deux pas distincts `colossus_crush` et `colossus_quake`, résolution via le scheduler réel, interruption par désarmement sans dégâts, perte de cible sans lease résiduel, sommeil/réveil et cleanup.

Le rang `miniboss`, le comportement `brute` et le profil monophasé sont désormais traités comme le contrat historique explicite, pas comme une fonctionnalité de boss manquante. Le probe de contrat vérifie qu'une santé à 25 % reste en phase 1 et qu'aucune phase non déclarée n'a été introduite. La route visuelle `bosscolossus.glb` à 53 os et son donneur UAL1 invisible sont également admis par la mission; le donneur reste nécessaire et n'a pas été supprimé.

Les limites restantes sont des dettes ou des non-applicabilités documentées, pas des pannes concrètes : le benchmark est orienté mode de masse et ne fournit pas de métriques GPU/avant-après; le Lab full roster emploie une annexe statique; aucune route Battle/campaign/procédurale n'est déclarée pour ce miniboss. Elles ne contredisent pas le contrat effectif Forge/package validé.

Aucun donneur, GLB, mesh, texture, matériau ou source n'a été supprimé. Le seul livrable de cet audit est ce rapport; les logs frais restent dans `.tmp_tools/enemy_refactor/boss_colossus_audit/`.

## Preuves primaires

| Preuve | Résultat et portée réelle |
|---|---|
| `.tmp_tools/enemy_refactor/boss_colossus_audit/dismember.log` | PASS exact : `id=boss_colossus zones=12 severed=10`; package 53 os, gore segmenté, donneur UAL1 |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/full_roster.log` | PASS `22/22`; ligne exacte : `legacy_boss`, `package_retarget`, `12/12`, `hammer`, `colossus_crush`, `LARGE_BODY` |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/animation.log` | PASS; ouverture exacte `colossus_crush -> external:axe_down` |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/large_body_contract_reeval.log` | PASS exact : `LARGE_BODY`, récupération bornée, collider primitif, crush+quake, monophasé déclaré, cleanup |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/unit_behavior_reeval.log` | PASS exact : far/close, toutes les attaques, interruption, perte de cible, sommeil/réveil et cleanup |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/benchmark_1_12_both.log` | benchmark v3 exact, quatre scénarios PASS, teardown propre; tous en `mass_battle_mode=true` |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/mixed_stress.log` | PASS `22 familles/36 unités`; le Colosse est présent et nettoyé, mais n'est pas l'acteur des changements de cible, sections ou morts instrumentés |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/animation_lod.log` | PASS partagé des trois routes shared/native/direct et réveil réversible; représentant natif différent du Colosse |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/navigation_component.log` | PASS du composant : intention, arrivée, fallback et récupération bornée; pas de parcours obstacle exact |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/navigation_navmesh.log` | PASS du mode `NAVMESH_GROUND`; **non applicable** au mode exact `LARGE_BODY` |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/giant_traversal.log` | PASS du `giant_standard`; **non applicable** : `boss_colossus` n'appartient pas à `GIANT_IDS` |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/combat.log` | PASS du contrôleur partagé; ne déroule pas les deux attaques du Colosse |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/action_state.log` | PASS des priorités partagées garde/recovery/wind-up/parade/tactique; fixture non-Colosse |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/attack_scheduler.log` | PASS synthétique des capacités, files, expirations et générations de leases |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/faction_targeting.log` | PASS partagé : groupes, précédence des cibles, claims, représailles et friendly fire |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/transient.log` | PASS partagé : ressources transitoires, TTL, retrait collision/ombres |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/anatomy_regression.log` | PASS partagé : section létale et finalisation de mort cohérentes |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/factory_route.log` | PASS : les constructions runtime convergent sur la factory |
| `.tmp_tools/enemy_refactor/boss_colossus_audit/authored_equipment.log` | PASS du `knight3`; **non applicable** au marteau procédural du Colosse |
| `docs/enemy_refactor/visual_evidence/boss_colossus.png` | image `1351 x 760` inspectée en résolution originale |
| `.tmp_tools/enemy_refactor/logs/visual_boss_colossus.log` | capture Compatibility existante PASS, six acteurs indépendants |
| `.tmp_tools/enemy_refactor/logs/lab_full_roster_visual_idle.log` et `forge_full_roster_visual_idle.log` | preuves communes PASS : vrai Lab et vrai runtime Forge, 22 unités, squelette et anatomie, images sans pose en T; le Lab ajoute une annexe statique et les deux contextes gèlent l'IA |

Le message Windows headless `Failed to read the root certificate store` précède les résultats frais. Il n'est lié à aucun accès TLS des probes et ne change pas leurs codes de sortie. Les avertissements de sauvegarde de préférences HUD dans le sandbox ne constituent pas non plus un échec fonctionnel.

## Construction, identité, profil et routes

### Source de vérité et factory

- `scripts/enemy/enemy_archetypes.gd:354-383` contient l'unique profil `boss_colossus`. `profile()` retourne une copie profonde et la vue typée est mise en cache.
- `scripts/enemy/enemy_factory.gd:48-85` reste le point de construction canonique : il injecte ID, position, cibles, faction, options IA/masse, package et registre avant d'ajouter l'ennemi à l'arbre.
- `_ready()` applique le profil avant corps, visuel, anatomie, navigation et groupes. En faction hostile, l'unité rejoint `enemy`, `athenian`, `damageable`, `combatant`, puis `combatant_ai/enemy_ai` si l'IA participe. Son rang ajoute les marqueurs miniboss/epic.
- `_resolve_package_path()` normalise l'ID et trouve `assets/characters/3dgen_demo/bosscolossus.glb` même si le profil ne fournit pas de `package_candidates` explicites.
- Le full roster confirme identité, profil, rig, anatomie, équipement, action d'ouverture, mode de navigation et teardown. Il ne simule pas un combat.

### Profil effectif

| Champ | Valeur |
|---|---:|
| nom / skin | `COLOSSUS` / `warlord` |
| rang | `miniboss` |
| échelle racine | `1.20` |
| santé | `720` |
| vitesse | `3.85 m/s` |
| dégâts de base | `44` |
| portée / aggro | `2.12 m` / `24 m` |
| arme / échelle | `hammer` / `1.24` |
| bouclier / défense | non / `none` |
| comportement / style | `brute` / `heavy` |
| wind-up / récupération de base | `0.48 s` / `0.52 s` |
| cooldown de base | `1.32–1.66 s` |
| vitesse d'animation d'attaque | `0.90` |
| bande préférée | `0–2.02 m` |

### Pattern et contrat monophasé

| Étape | Animation | Mécanique |
|---|---|---|
| `colossus_crush` | `external/mixamo:axe_down` | wind-up `0.66 s`, recovery `0.62 s`, cooldown `1.22 s`, dégâts `x1.42`, portée `x1.10` |
| `colossus_quake` | `external/mixamo:mutant_punch` | shockwave rayon `3.4 m`, wind-up `0.82 s`, recovery `0.72 s`, cooldown `1.55 s`, dégâts `x0.78` |

Le contrôleur sait techniquement activer les phases 2 et 3 (`athenian_enemy.gd:3429-3448`), mais cette entrée de rang `miniboss` déclare intentionnellement un contrat monophasé : aucun `phase_threshold`, `phase_two_pattern`, `phase_three_threshold` ou `phase_three_pattern`. Les valeurs normalisées restent à zéro/tableaux vides et le pattern à deux pas tourne entièrement en phase 1.

Le probe exact de grand corps vérifie ce contrat de façon négative et positive : rang `miniboss`, comportement `brute`, liste exacte `[colossus_crush, colossus_quake]`, quake `shockwave` de rayon au moins `3.4`, puis santé forcée à 25 % sans transition hors phase 1. L'absence de phase supplémentaire est donc une caractéristique déclarée, pas une perte fonctionnelle.

### Routes réellement applicables

- `EnemyArchetypes.all_ids()` inclut `boss_colossus`; la palette Forge itère ce catalogue et `WorldRuntime.spawn_enemy_group()` passe par la factory. La capture commune full roster prouve la construction statique dans le vrai runtime Forge.
- `boss_colossus` n'appartient pas à `ROSTER_IDS`; `procedural_catalog()` ne peut donc pas le tirer. Il n'appartient pas non plus à `GIANT_IDS`.
- Le Combat Lab de base (`scripts/main.gd`) utilise ses zones de roster de remplacement et ne contient pas le Colosse. Le probe visuel commun ouvre la vraie scène Lab, puis ajoute une annexe `MissionFullRosterAnnex`; cette preuve démontre la compatibilité de scène, pas une route Lab authorée.
- La recherche des scripts Battle/campaign ne trouve aucun spawn exact. Le manifest `primary_routes=["forge","authored"]` et la matrice `authored/Forge` ne donnent pas le nom d'une scène de combat authorée; `authored` correspond au minimum au package GLB dédié. La seule route de jeu exacte démontrée est la Forge. Battle, campaign et procédural sont non applicables à l'état courant.
- Les captures Lab/Forge figent ou désactivent l'IA pour composer le roster. Elles ne prouvent ni patrouille, ni poursuite, ni attaque, ni mort dans ces contextes.

## Cibles, activation, solo/groupe et cycle de vie

### Sélection et changement de cible

Le contrôleur partagé privilégie une représaille valide, puis le joueur humain stable dans la portée d'aggro, puis les adversaires de faction. Une hystérésis de distance évite les bascules rapides; les claims réduisent la concentration d'un groupe sur une cible. Un changement de cible libère claim, engagement et permission d'attaque avant de réenregistrer la nouvelle cible.

Ces contrats sont couverts par le probe partagé de faction/ciblage. Le probe de comportement exact ajoute la décision far/close puis supprime la cible : le Colosse ne conserve ni autorité d'attaque ni lease. Le mixed stress confirme en plus sa coexistence et son nettoyage dans un groupe de 36 unités. Le scénario exact ne mesure pas séparément l'hystérésis multi-cible ou une représaille, mais aucun défaut n'est observé dans le contrat commun validé.

### Leases et combat solo/groupe

- Avant la résolution d'une attaque, le Colosse doit obtenir une permission du crowd director. Le scheduler utilise capacité, ordre FIFO, TTL et génération; le contrôleur revalide l'autorité au moment de toucher.
- En l'absence de profil de phalange, la capacité de contact reste celle du groupe partagé, typiquement trois attaquants. Une interruption, une cible changée, la désactivation IA, la mort ou `_exit_tree()` libère le lease.
- `colossus_quake` construit un télégraphe puis applique une onde à falloff dans le rayon déclaré. Le probe de contrat vérifie explicitement son type `shockwave` et son rayon `3.4`; le probe de comportement parcourt puis résout ce pas par le scheduler réel, après `colossus_crush`.
- L'unité n'a ni bouclier ni défense; une preuve de garde/parade n'est pas applicable. Le profil ne déclare pas non plus de poise spécifique, donc les valeurs communes s'appliquent.
- Le marteau n'est pas une arme désarmable séparée par une mécanique de garde. Il se détache lors des sections droites prévues et à la mort. Le probe exact valide le drop, pas une interaction de désarmement volontaire en plein combat.

Le probe exact démontre le cycle individuel à deux attaques, l'interruption et la perte de lease; les probes scheduler/combat/action-state et mixed stress couvrent la capacité, la file, les générations et la coexistence en groupe. Ensemble, ils satisfont le contrat solo/groupe déclaré. Un test de distribution radiale multi-cible au centimètre près resterait un approfondissement utile, pas une gate fonctionnelle en échec.

### Activation, sommeil et réveil

Le contrôleur possède une activation différée d'entraînement et un LOD de process : cadence de décision réduite, animation en évaluation manuelle, puis sommeil/cull lointain; le réveil restaure process, animation et destination. Le probe LOD partagé est vert pour les familles shared, native et direct. Le probe de comportement exact désactive ensuite réactive le Colosse et vérifie la divergence des groupes `combatant_ai` au sommeil puis leur restauration au réveil. Le sampling de chaque niveau reste couvert par le représentant natif commun.

### Mort atomique et nettoyage

À la mort, le runtime libère cible et permission, marque `dead`, coupe la participation IA, met couche/masque à zéro, désactive capsule et zones d'anatomie, arrête la locomotion et le driver, lâche le marteau, puis joue `Death01` du donneur ou le collapse de secours. La finalisation de mort atomique empêche une section létale de laisser un adversaire actif. Le cadavre réduit ensuite cadence, particules et ombres après stabilisation; le nettoyage de l'encounter/scène retire le nœud.

Le démembrement exact prouve les fatalités tête/cou et le drop de marteau. La preuve centrale de mort atomique couvre la finalisation commune; full roster, comportement exact, mixed stress et benchmark prouvent un teardown structurel sans référence ennemie persistante. Une mort ordinaire et une section létale convergent donc sur le même chemin atomique. Les cas artificiels de double mort ou de décès pendant le choc resteraient des tests supplémentaires, sans panne actuelle observée.

Les proxies de membre et d'arme ont des durées bornées. Le marteau détaché utilise un `RigidBody3D` couche `16`, masque `1`, une boîte `0.68 x 1.42 x 0.34`, dort si possible, perd collision/ombres vers `4 s` et expire vers `12 s`. Cette mécanique est inspectée dans le code et couverte par le probe transitoire partagé, pas chronométrée sur un marteau exact.

## Navigation, obstacles et physique

### Mode réel `LARGE_BODY`

`athenian_enemy.gd:696-703` force `LARGE_BODY` pour l'ID `boss_colossus`, indépendamment de l'échelle. Le composant applique :

- steering horizontal direct vers la destination;
- multiplicateur de vitesse `0.78`;
- arrivée à `0.28 m`;
- vitesse de progrès minimale `0.12 m/s`;
- timeout de blocage `1.15 s`;
- récupération latérale alternée `0.72 s`, avec trois tentatives par défaut.

Dans `enemy_navigation_component.gd`, seul `NAVMESH_GROUND` crée un `NavigationAgent3D`. L'absence d'agent dans `LARGE_BODY` est volontaire : ce miniboss utilise un déplacement direct à gabarit primitif et une récupération bornée, sans prétendre au contrat de pathfinding des fantassins navmesh ni au traversal escaladable des géants.

Le nouveau probe exact ne se contente pas d'inspecter le mode. Il assigne une destination, obtient une intention `moving` à vitesse `0.78`, simule 72 frames sans progrès, vérifie une unique entrée en récupération tentative 1 après le timeout `1.15 s`, applique un déplacement latéral, poursuit 50 frames sans `navigation_failed`, puis valide `arrived` et enfin `idle` après clear. Il confirme aussi explicitement l'absence du nœud `NavigationAgent`, conformément au contrat.

Le probe navmesh reste non applicable et le probe giant traversal concerne `giant_standard`; `boss_colossus` n'appartient pas à `GIANT_IDS`. Cette distinction est désormais une frontière de design testée, pas un défaut. Le test simule un blocage/recovery plutôt qu'une carte de couloirs authorée; aucune panne concrète de progression n'est reproduite.

### Corps, collider, gravité et contact

Le corps est un `CharacterBody3D` soumis à une gravité de `24` et déplacé par `move_and_slide()`. Sa capsule locale commune mesure environ rayon `0.39`, hauteur `1.82`; l'échelle uniforme `1.20` donne environ rayon `0.468`, hauteur `2.184` dans le monde. Le Colosse utilise couche `4`, masque `1|2`; les ennemis ne se bloquent pas physiquement entre eux et la séparation de foule corrige les chevauchements par steering.

Le probe exact valide que la forme principale est une `CapsuleShape3D` de dimensions positives, que l'échelle globale est uniforme et qu'aucun descendant dynamique n'utilise de `ConcavePolygonShape3D`. C'est le contrat physique retenu pour cette silhouette. Des scènes dédiées de pente, marche ou couloir pourraient enrichir la couverture, mais la capsule primitive, le blocage simulé, la récupération et l'arrivée sont verts.

## Rig, squelettes, donneur, clips et LOD

### Package et chaîne d'animation

Le GLB `assets/characters/3dgen_demo/bosscolossus.glb` contient un skin `SPARTAN_Skeleton` à 53 joints et aucune animation intégrée. L'adaptateur le reconnaît comme schéma `spartan_ual1_v1`, trouve les dix meshes corporels et dix-huit caps de gore, puis instancie un donneur caché `UAL1_Standard.glb` nommé `SpartanUALAnimationDonor`. Un bridge copie la pose du donneur vers le squelette visible. Comme le profil requiert les clés externes du pattern, un driver natif spécial pilote les actions lorsque l'IA est active hors mode de masse.

Le système n'est donc pas « un seul squelette » au runtime : il y a un squelette visible de 53 os et au moins le squelette invisible du donneur. Le donneur est fonctionnel et nécessaire à locomotion/mort; il ne doit pas être supprimé sans remplacement et sans validation complète des clips.

Le probe exact d'animation prouve l'ouverture `colossus_crush` et son clip `external:axe_down`. Le probe de comportement traverse ensuite les deux IDs distincts, y compris `colossus_quake`, via le vrai wind-up/scheduler/resolve, et valide l'interruption par désarmement sans dommage. Le mapping déclaratif du second pas reste `external/mixamo:mutant_punch`. Les actions lourdes natives sont traitées plein corps; aucune exigence de masque haut/bas n'est revendiquée pour ce profil.

### LOD et réveil

Le LOD partagé réduit fréquence d'évaluation, ombres et effets, puis culle loin. Le probe commun valide les routes shared/native/direct ainsi qu'un sommeil/réveil réversible. Le probe exact de comportement ajoute la désactivation/réactivation du Colosse et la restauration de son appartenance `combatant_ai`. Le benchmark Colosse force le mode de masse et ne mesure pas le driver spécialisé, mais aucune panne de réveil n'est observée. Une instrumentation de coût du donneur à chaque niveau serait une amélioration performance, pas un défaut fonctionnel.

## Meshes, rendu, assets et marteau

### Inventaire source

Inspection directe du GLB source :

| Élément | Valeur |
|---|---:|
| taille du GLB | `13 057 576` octets |
| nœuds | `83` |
| meshes / primitives-surfaces source | `28 / 28` |
| sommets cumulés source | `62 584` |
| triangles LOD0 cumulés | `21 656` |
| matériaux | `2` |
| textures/images | `2` |
| skins / joints | `1 / 53` |
| animations intégrées | `0` |
| corps / caps gore | `10 / 18` |

Ces compteurs décrivent le source, caps inclus, et ne sont pas des draw calls mesurés. Les caps restent cachés jusqu'à la section. Contrairement à certaines routes hoplites partagées, la route package générique du Colosse n'appelle pas `optimize_body_meshes()`; les parties corporelles restent segmentées afin de préserver le démembrement. Toute fusion future doit prouver séparément les dix sections et leurs caps.

L'import Godot génère LOD et shadow meshes, tangentes et skins nommés. Cependant aucune mesure n'extrait les triangles de chaque LOD, la distance de bascule, les draw calls runtime ou le coût des shadow meshes.

Les deux textures PNG pèsent respectivement `6 759 324` et `2 918 292` octets. Leurs sidecars utilisent `compress/mode=0`, `vram_texture=false`, mipmaps actifs. C'est une dette probable de taille/distribution et de bande passante, pas une régression quantifiée. Une conversion de compression ne peut être approuvée sans comparaison visuelle peau/sang/métal et mesure GPU.

### Marteau

`_make_hammer()` fabrique un équipement procédural composé de plusieurs primitives : manche, collier, tête et faces, avec matériaux bois/bronze/fer créés par instance. Cette stratégie augmente objets, surfaces et matériaux uniques, et limite le batching. Le marteau est attaché à la main droite, échelle `1.24`; les sections `right_upper_arm` et `right_forearm` entraînent sa séparation. Le probe exact de démembrement valide bien l'évidence de drop d'équipement.

Le probe `authored_equipment` ne couvre que l'épée/bouclier de `knight3`; il ne doit pas être cité comme preuve du marteau. Il manque une validation exacte de l'arc de frappe par rapport au contact mécanique, de l'absence de clipping sur toutes les rotations, du proxy physique détaché et des collisions du marteau avec sol/mur.

## Anatomie et démembrement

Le package expose dix meshes corporels segmentés; le profil d'anatomie commun crée douze zones de collision. Dix zones logiques sont sectionnables : tête, cou et huit segments de membres. Le cou redirige vers le mesh de tête, ce qui donne neuf chemins de mesh sectionné distincts; les dix-huit caps source correspondent à deux caps pour chacun de ces neuf chemins.

| Zone logique | Forme / rayon | Multiplicateur dégâts | Multiplicateur section | Seuil | Effet |
|---|---:|---:|---:|---:|---|
| `head` | sphère `0.25` | `1.70` | `1.00` | `64` | section, létale |
| `neck` | capsule `0.15` | `1.85` | `1.35` | `56` | redirige tête, létale |
| `torso` | capsule `0.34` | `1.00` | — | — | non sectionnable |
| `pelvis` | capsule `0.30` | `0.92` | — | — | non sectionnable |
| `left_upper_arm` | capsule `0.16` | `0.78` | `1.00` | `78` | section |
| `right_upper_arm` | capsule `0.16` | `0.78` | `1.00` | `78` | section + marteau |
| `left_forearm` | capsule `0.14` | `0.75` | `1.10` | `60` | section |
| `right_forearm` | capsule `0.14` | `0.75` | `1.10` | `60` | section + marteau |
| `left_thigh` | capsule `0.21` | `0.88` | `0.82` | `94` | section |
| `right_thigh` | capsule `0.21` | `0.88` | `0.82` | `94` | section |
| `left_shin` | capsule `0.18` | `0.84` | `1.05` | `72` | section |
| `right_shin` | capsule `0.18` | `0.84` | `1.05` | `72` | section |

Le run ciblé frais recrée une instance par zone, applique le dommage localisé, vérifie le mismatch de fatalité attendu, l'évidence du membre/proxy/cap et le drop d'équipement, puis termine `PASS id=boss_colossus zones=12 severed=10`. C'est la preuve individuelle la plus forte de l'audit.

Limites : pas de chaîne de plusieurs sections sur un même Colosse, pas de section pendant `colossus_quake`, pas de section simultanée à une mort ordinaire, pas de stress à plusieurs Colosses avec débris, et pas de validation longue de réutilisation/libération des matériaux de caps.

## Performance ciblée

Commande exécutée avec Godot `4.7-stable`, headless, renderer `gl_compatibility`, seed `13371`, registre actif, warmup `90`, mesure `120` frames : `enemy_performance_benchmark.gd -- --archetype=boss_colossus --counts=1,12 --mode=both --warmup=90 --frames=120 --seed=13371 --registry=on`.

| Scénario | Spawn | Nœuds / objets | Mémoire statique pendant | Corps actifs | Tick p95 / max | Teardown |
|---|---:|---:|---:|---:|---:|---|
| idle ×1 | `247.020 ms` | `88 / 1 774` | `78 930 318` o | `0` | `20.700 / 20.737 ms` | propre |
| idle ×12 | `482.980 ms` | `979 / 2 940` | `85 642 620` o | `0` | `20.712 / 21.081 ms` | propre |
| actif ×1 | `306.892 ms` | `89 / 1 777` | `79 304 726` o | `1` | `20.716 / 20.781 ms` | propre |
| actif ×12 | `430.389 ms` | `991 / 2 965` | `85 775 748` o | `12` | `20.704 / 20.916 ms` | propre |

Chaque scénario finit avec `combatants_after=0`, `live_enemy_refs=0`, `orphan_node_count=0` et aucune référence registre vivante. Le statut JSON est `PASS`.

Interprétation stricte :

- le harness force `mass_battle_mode=true` dans les quatre scénarios. Hors mode de masse, `athenian_enemy.gd:3022` construit le driver spécialisé; ce coût est absent ici. Le scénario actif ×1 n'est donc pas représentatif d'un vrai miniboss solo complet;
- les intervalles muraux alternent autour du pacing headless (`p50 ≈ 13.8 ms`, `p95 ≈ 20.7 ms`) et comptent `49–50/120` échantillons au-dessus de `16.67 ms`. Ils ne constituent pas une gate FPS CPU/GPU;
- le premier scénario charge les ressources à froid, les suivants réutilisent le cache. Les temps de spawn ne sont pas directement comparables entre lignes;
- aucune baseline pré-changement exacte n'existe. Aucun gain avant/après n'est revendiqué;
- aucune métrique de rendu GPU, draw calls, VRAM, animation native hors masse, onde de choc, mort, sections ou débris n'est disponible.

Le PASS démontre surtout la stabilité structurelle et le nettoyage du chemin de masse, pas l'atteinte d'un budget de production.

## Inspection visuelle

`docs/enemy_refactor/visual_evidence/boss_colossus.png` mesure `1351 x 760` et présente six colonnes clairement lisibles : `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`.

Constats positifs :

- aucune pose en T évidente;
- idle et jog montrent des poses distinctes des bras/jambes;
- l'attaque lit comme un coup lourd accroupi au marteau;
- l'impact est distinct de l'attaque;
- la mort montre le corps au sol et le marteau projeté;
- la section montre membre droit et marteau détachés.

Limites de la preuve :

- il s'agit de six instances indépendantes, pas d'une séquence temporelle d'un même Colosse;
- une masse gore rouge est rognée à droite et des débris se superposent visuellement entre colonnes;
- aucune rotation 360°, vue rapprochée/lointaine, LOD/réveil, clip `mutant_punch`, télégraphe/onde, navigation ou combat en contexte n'est visible;
- idle/jog masquent volontairement l'équipement; la planche ne valide pas la tenue du marteau pendant locomotion;
- les captures full roster Lab/Forge communes confirment l'absence de pose en T dans ces scènes, mais l'IA y est figée et le Lab utilise une annexe injectée.

La planche écarte une rupture visuelle grossière. Les probes exacts de comportement et de grand corps complètent ses limites pour le gameplay, le réveil et la récupération; aucune anomalie visuelle fonctionnelle n'empêche le verdict.

## Écarts non bloquants et recommandations

Aucun défaut fonctionnel rouge propre à `boss_colossus` ne subsiste dans les contrats déclarés. Les points suivants restent des améliorations mesurables ou des frontières de portée :

- conserver le squelette donneur invisible tant qu'aucun remplacement n'a validé locomotion, les deux attaques, impact, mort, LOD et wake;
- mesurer puis éventuellement optimiser le package source (`13.1 MB`), ses 28 primitives source et deux PNG volumineux non VRAM-compressés;
- mutualiser les matériaux procéduraux du marteau si une mesure confirme un coût de batching;
- compléter le benchmark par un run solo hors `mass_battle_mode`, des métriques GPU/draw calls/VRAM et un avant/après réellement comparable;
- ajouter, si le level design l'exige, une scène de couloir/pente authorée en complément du blocage simulé déjà vert;
- mesurer le falloff du quake sur plusieurs cibles et le proxy physique du marteau au sol, bien que les pas, le rayon déclaratif, l'interruption et le drop soient déjà validés;
- recadrer la planche visuelle pour éviter débris rognés/superposés et ajouter une rotation 360°/LOD si une preuve marketing est demandée;
- clarifier dans le manifest que la route jouable démontrée est la Forge et que `authored` désigne le package dédié, ou nommer une éventuelle scène authorée future;
- ne pas appliquer le PASS de `giant_traversal` au Colosse : son contrat `LARGE_BODY` distinct est couvert par son propre probe.

## Décision finale

**DONE.** La factory, l'identité `miniboss/brute`, le profil monophasé explicite, la route Forge/package, le rig UAL1 à donneur conservé, le cycle crush/quake, l'interruption, les cibles et leases, le sommeil/réveil, la navigation `LARGE_BODY` et sa récupération bornée, la capsule primitive, la mort/cleanup, l'anatomie `12/12`, les dix zones logiques sectionnables et le marteau sont tous reliés à des preuves exactes ou à des contrats communs verts dont la portée est explicitée. Le benchmark structurel et les preuves visuelles ne montrent aucune panne. Les réserves restantes concernent l'optimisation, l'extension de couverture ou des routes non applicables, pas une régression fonctionnelle concrète.
