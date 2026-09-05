# Audit final — `nsbire1`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable, build officiel `5b4e0cb0f`**\
**Portée : état courant du worktree; code runtime central examiné strictement en lecture seule.**

## Synthèse

`nsbire1` est la levée civique fragile du roster de remplacement. Son identité runtime est nette : troupe `levy_harasser`, comportement `coward`, outil agricole à deux mains visuellement porté à droite, aucune défense, 82 PV, vitesse 4,80 m/s et attaque de mêlée à 1,92 m. Elle est créée par la factory unique et apparaît dans le Combat Lab, Battle 03, le procédural et la Forge.

Les contrats de comportement, navigation, rig, équipement, anatomie, section, mort et teardown passent. La validation exacte donne 12 zones localisées dont 10 sectionnables; le roster global donne 22/22 unités valides. Les captures unité/Lab/Forge ont été inspectées et ne montrent ni T-pose ni équipement attaché après section.

## Profil et construction

Source de vérité : `scripts/enemy/enemy_archetypes.gd:535-575`.

| Champ | Valeur |
|---|---:|
| nom / rôle / rang | `LEVEE CIVIQUE` / `levy_harasser` / `troop` |
| skin / échelle | `swordsman` / `0.97` |
| PV / vitesse | `82.0` / `4.80` |
| dégâts / portée / aggro | `13.0` / `1.92` / `18.0` |
| arme / bouclier | `farm_tool` / `false` |
| comportement / style | `coward` / `harvest` |
| windup / recovery | `0.35` / `0.40` |
| cooldown | `1.18–1.58` |
| bande préférée | `1.10–1.80` |
| séparation / approche | `1.60` / `0.88` |
| défense / poise | `none` / `0.02` |
| signatures | source `ual2`, `Farm_Harvest` / `TreeChopping`, chance `0.72` |
| coût / poids procédural | `0.70` / `1.30`, dès la vague 0 |

- `HopliteEnemyArchetypeData` fournit une vue immuable et mise en cache du profil normalisé. Le probe typé confirme les 22 vues, dont `nsbire1`.
- `HopliteEnemyFactory.spawn_request()` configure l’ID, la position, les cibles, l’IA, le mode de masse et le package avant `add_child()`. Le contrôleur applique ensuite le profil avant collision, visuel, anatomie et navigation.
- Le package candidat non horodaté est résolu par `_resolve_package_path()` vers `res://assets/characters/3dgen_demo/nsbire1-1787347581582.glb`. Le fichier existe, pèse 9 993 980 octets et son import active tangentes, LOD, shadow meshes, skins nommées, animations à 30 FPS et suppression des pistes immuables.

## Rig, animations et identité visuelle

- Le package passe `HopliteSpartanCharacterPackage.bind()` : schéma `spartan_ual1_v1`, squelette exact de 53 os, os essentiels présents, dix maillages corporels segmentés et gore caps associés (`spartan_character_package.gd:8-118`).
- Route effective : `package_retarget`. Le personnage visible conserve son squelette auteur; un donneur UAL1 invisible fournit l’`AnimationPlayer` et `HopliteAuthoredPoseBridge` copie la pose sur le rig visible (`athenian_enemy.gd:2952-3035`).
- Les animations d’attaque déclarées sont `Farm_Harvest` et `TreeChopping`; le contrat mécanique reste statique car le profil n’a pas de `combat_pattern`. Le générateur de preuve a produit une pose d’attaque distincte avec l’outil agricole.
- L’outil `AgriculturalWarFork` est construit une fois par instance à partir de primitives et de matériaux mis en cache, attaché à `DEF-hand.R`. La perte du bras/avant-bras droit le transforme en débris physique temporaire.
- Aucun donneur ne peut être déclaré supprimable dans cet audit. Le donneur UAL1 et le bridge sont encore requis par cette route; leur remplacement demanderait une capture visible équivalente, une vérification de toutes les actions et une mesure avant/après dédiée.

## Combat et IA

- `behavior = coward` conserve la bande 1,10–1,80 m, l’approche ralentie et la séparation forte; la levée peut harceler puis privilégier l’éloignement quand son état le demande. Elle ne reçoit ni garde, ni parry, ni armure, ni phase de boss.
- L’attaque utilise le scheduler partagé : acquisition de permission, windup 0,35 s, résolution de mêlée, recovery 0,40 s et cooldown 1,18–1,58 s. La perte de la cible libère le lease; le désarmement pendant le windup interrompt la frappe sans infliger de dégâts.
- Le probe exact a exercé les décisions loin/proche, le début et la résolution d’attaque, le désarmement, la perte de cible, le sommeil/réveil et le nettoyage des groupes.
- `set_ai_participation(false)` retire proprement l’unité de `combatant_ai`, libère cible/lease/navigation et invalide l’index spatial; le réveil restaure l’appartenance et le composant.

## Navigation et foule

- Mode exact : `DIRECT_STEERING`. `nsbire1` n’est ni phalange, ni géant; `_build_navigation_component()` choisit donc le mode direct avec arrivée à 0,28 m, progrès minimal 0,12 m/s, détection de blocage à 0,82 s et récupération latérale de 0,48 s (`athenian_enemy.gd:689-707`).
- Le composant calcule uniquement une intention; le `CharacterBody3D` racine reste l’unique propriétaire de `velocity` et `move_and_slide()`. Aucun `NavigationAgent3D` n’est créé en mode direct.
- Le crowd director apporte anneau d’engagement, séparation locale, cible stable et permissions FIFO. Son index spatial est actualisé à 20 Hz au lieu d’être reconstruit chaque frame.
- Le probe navigation transverse passe intention directe, arrivée, formation, fallback navmesh et récupération de blocage. La navigation directe ne remplace toutefois pas un pathfinding navmesh autour de grands obstacles complexes; c’est une limite qualitative non bloquante des routes actuelles.

## Anatomie, collisions et cycle de vie

Le profil humain partagé fournit douze zones (`scripts/enemy/anatomy_profile.gd:7-77`) :

| Zones | État |
|---|---|
| tête, cou | sectionnables et fatales; le cou redirige vers la tête |
| torse, bassin | localisés, non sectionnables |
| bras/avant-bras gauche et droit | sectionnables; côté droit lâche l’outil |
| cuisses/tibias gauche et droit | sectionnables; perte bilatérale dégrade la locomotion |

- Résultat exact : `zones=12 severed=10`. Chaque zone enregistre le dégât localisé; chaque section autorisée marque l’état, produit un fragment/équipement détaché et respecte la fatalité attendue.
- Le corps est un `CharacterBody3D` à capsule primitive; les volumes anatomiques sont des sphères/capsules, jamais des concaves dynamiques. L’unité n’a pas de shield hitbox puisqu’elle n’a pas de bouclier.
- La mort coupe atomiquement l’IA, les groupes tactiques, la navigation, le lease et l’enregistrement avant la présentation de cadavre.
- Le cycle de vie transverse des projectiles, sang, membres et armes est borné : collision et ombres sont retirées avant libération. Le probe dédié passe partage de ressources, TTL et retrait des coûteux états physiques.

## Routes vérifiées

- Combat Lab : roster statique, escouade mixte, annexe `NSBIRE I — LEVEE PAYSANNE` et patrouilles (`scripts/main.gd:303-332`, `:488-532`).
- Battle 03 : levées aléatoires de zone 1, front de zone 2 et pression de zone 3 (`scripts/battle/battle_03_narrative.gd:347`, `:383`, `:407`).
- Procédural : entrée de donjon, gardes de boss, renforts et légions; toutes convergent sur `EnemyFactory.spawn_request()` (`procedural_wave_director.gd:229-323`, `:415`, `:586-615`).
- Forge : `world_runtime.gd` utilise l’adaptateur `EnemyFactory.spawn()` pour les entités et groupes de monde (`world_runtime.gd:314`, `:370`).

## Performance structurelle ciblée

Commande : `--counts=1,28 --mode=both --warmup=30 --frames=60 --archetype=nsbire1 --registry=on`. Le seuil de masse de 28 reste inchangé et chaque scénario utilise `mass_battle_mode=true`.

| Scénario | Spawn | Nœuds / objets pendant | Mémoire statique pendant | Physique diagnostic | Nettoyage |
|---|---:|---:|---:|---:|---|
| 1 inactif | 149,351 ms | 88 / 1 771 | 62 143 813 o | 0,367 ms | PASS |
| 28 inactifs | 384,158 ms | 2 275 / 4 552 | 78 099 299 o | 3,101 ms | PASS |
| 1 actif | 211,277 ms | 89 / 1 774 | 63 050 053 o | 0,863 ms | PASS |
| 28 actifs | 545,591 ms | 2 303 / 4 609 | 78 432 735 o | 7,306 ms | PASS |

Pour 28 actifs, l’intervalle de tick physique mesuré donne p95 24,844 ms et maximum 29,238 ms sur ce run court. Les 28 références ennemies, le registry et tous les groupes reviennent à zéro; aucun nœud orphelin n’est relevé. Ces mesures headless sont diagnostiques et ne constituent pas un benchmark GPU ni une comparaison statistique avant/après.

## Preuves visuelles inspectées

- `docs/enemy_refactor/visual_evidence/nsbire1.png` : six états `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`. Silhouette au sol, poses distinctes, outil lisible, arme tombée et membre sectionné visibles; pas de T-pose.
- `docs/enemy_refactor/lab_full_roster_visual_probe.png` : l’unité est présente dans le roster complet sur la scène réelle du Lab et reste cohérente avec l’échelle des autres fantassins.
- `docs/enemy_refactor/forge_full_roster_visual_probe.png` : l’unité est présente dans le document Forge réel; aucune divergence de rig ou de pose n’est visible.

## Tests exécutés

| Test | Résultat |
|---|---|
| `enemy_unit_dismemberment_probe.gd -- --id=nsbire1` | PASS — 12 zones, 10 sections |
| `enemy_unit_behavior_probe.gd -- --id=nsbire1` | PASS — loin/proche, attaque, désarmement, cible perdue, sleep/wake, cleanup |
| `enemy_full_roster_validation_probe.gd` | PASS — 22/22; `package_retarget`, `farm_tool`, `static`, `DIRECT_STEERING` |
| `enemy_archetype_data_probe.gd` | PASS — 22 vues typées conformes |
| `enemy_navigation_component_probe.gd` | PASS — intention, formation, fallback, récupération |
| `enemy_transient_lifecycle_probe.gd` | PASS — ressources partagées, TTL, collisions/ombres retirées |
| `enemy_performance_benchmark.gd` ciblé | PASS — 1/28, idle/active, registry, teardown |

Logs principaux : `C:\Users\suean\AppData\Local\Temp\hoplite_nsbire1_full_roster.log`, `C:\Users\suean\AppData\Local\Temp\hoplite_nsbire1_performance_structural_final.log` et les logs `hoplite_nsbire1_enemy_*` associés. Le message Windows `Failed to read the root certificate store` est du bruit d’environnement; tous les runs retenus sortent avec code 0. Une première exécution du roster a subi un crash natif pendant une concurrence d’instances Godot; la relance isolée avec audio factice a passé 22/22 et constitue la preuve retenue.

## Limites et risques résiduels non bloquants

1. **Donneur encore requis** — chaque package `nsbire1` garde un donneur UAL1 invisible et un pose bridge. Leur coût est réel; aucune suppression n’est autorisée sans preuve visuelle animée équivalente et mesure avant/après.
2. **Attaque mécanique statique** — l’absence de `combat_pattern` dédié limite la variété mécanique; les signatures agricoles sont probabilistes. Le contrat actuel est néanmoins reproductible, lisible et fonctionnel.
3. **Steering direct** — récupération latérale et séparation gèrent les blocages locaux, mais aucun navmesh ne garantit le contournement d’obstacles complexes.
4. **Échelle du corps** — l’échelle racine uniforme `0.97` reste faible et les volumes suivent l’échelle monde, mais le guide physique préfère dimensionner directement les shapes plutôt que scaler un corps physique.
5. **Coût structurel du package** — 28 unités conservent 2 303 nœuds et 4 609 objets actifs dans le scénario de masse ciblé. Les cadences/ombres/TTL bornent le coût, mais une migration vers la bibliothèque partagée serait une optimisation future à prouver.
6. **Mesure headless courte** — elle valide structure et teardown, pas draw calls, VRAM ou FPS rendu en combat réel.

## Verdict

**DONE.** `nsbire1` conserve son identité de levée fragile, ses statistiques, sa tactique de harcèlement/couardise, son package 53 os, ses animations, son outil agricole, ses 12 zones et ses 10 sections. Les routes Lab, Battle 03, procédural et Forge convergent sur la factory; les tests unitaires et transverses passent, les trois preuves visuelles sont acceptables et le teardown est propre à 1 comme à 28 unités.

Aucun défaut fonctionnel concret et reproductible ne justifie `BLOCKED`. Le donneur UAL1 reste explicitement non supprimable sans preuve équivalente; les limites de variété d’attaque, de navigation directe et de coût structurel sont documentées comme dettes non bloquantes.

### Clôture post-audit du fallback léger

Le probe ajouté après cette fiche, `enemy_package_attack_fallback_probe --id=nsbire1`, valide explicitement la route non-masse du package réel : aucun driver lourd, `Sword_Attack` UAL1 effectivement joué en one-shot, verrou visuel actif, résolution, sleep/wake et teardown propres. La planche `nsbire1.png` a été régénérée puis inspectée après le correctif ; sa colonne ATTAQUE montre un geste distinct. Le donneur UAL1 demeure requis.
