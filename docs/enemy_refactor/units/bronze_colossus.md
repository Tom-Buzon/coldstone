# Audit final distinct — `bronze_colossus`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable (`5b4e0cb0f`)**\
**Renderer des probes : `gl_compatibility`, headless**\
**Portée : état courant du worktree; audit central en lecture seule, écriture limitée à ce rapport et aux logs temporaires.**

## Verdict synthétique

`bronze_colossus` conserve un contrat propre de miniboss/juggernaut : 780 PV, marteau, armure, locomotion `LARGE_BODY`, quatre actions ordonnées en phase 1 puis deux actions accélérées à 52 % de vie. Les probes exacts passent la factory, les objectifs loin/proche, le vrai scheduler d'attaque, l'interruption par désarmement, la perte de cible, le sommeil/réveil, la phase 2 atomique, la shockwave, la récupération après blocage, les collisions primitives, les douze zones anatomiques, les dix sections logiques et le teardown.

La route d'asset est honnêtement caractérisée : aucun fichier `bronzeColossus.glb` dédié n'est présent, donc le troisième candidat déclaré `bosscolossus.glb` gagne. Ce package est valide (53 os, corps segmenté, caps), le donneur UAL1 reste caché et le driver natif sélectionne seulement les quatre donors d'action nécessaires. Les rendus dédiés, Lab et Forge ne montrent aucune T-pose grossière ni équipement détaché au repos.

Verdict : **DONE**. Aucune panne fonctionnelle reproductible propre à cette unité n'est observée. Les réserves restantes sont mesurées et explicites : silhouette source partagée faute de package dédié, steering `LARGE_BODY` sans pathfinding topologique, donors toujours nécessaires, et budget CPU dépassé à 56 instances actives dans le harness headless. Aucun asset ou donneur ne doit être supprimé sur la base de cet audit.

## Profil canonique et identité

Source de vérité : `scripts/enemy/enemy_archetypes.gd:690-748`, normalisée par `profile()` puis exposée par le Resource immuable `HopliteEnemyArchetypeData`.

| Champ | Valeur |
|---|---:|
| nom / rôle / rang | `BRONZE COLOSSUS` / `siege_juggernaut` / `miniboss` |
| famille validée | `bronze_colossus` |
| skin / échelle | `warlord` / `1.22` |
| PV / vitesse | `780` / `3.45 m/s` |
| dégâts / portée / aggro | `46` / `2.20 m` / `25 m` |
| arme / bouclier | marteau `1.28` / aucun |
| comportement / style | `juggernaut` / `heavy` |
| windup / recovery | `0.54 s` / `0.58 s` |
| cooldown | `1.44-1.82 s` |
| vitesse d'animation | `0.88` |
| bande préférée | `0-2.04 m` |
| rayon tactique / séparation / approche | `2.18` / `0.30` / `0.72` |
| défense | armure, dégâts x`0.70`, section x`0.46` |
| poise | `0.82` |
| signature | UAL2, `TreeChopping` / `Sword_Regular_Combo`, chance `0.72` |
| procédural | coût `6.50`, poids `0.18`, première vague `5` |
| package résolu | `res://assets/characters/3dgen_demo/bosscolossus.glb` |

Le cache de profils ne permet pas à un appelant de muter la source : l'API dictionnaire renvoie une copie profonde et le Resource typé est configuré une seule fois. La factory reste l'unique point de construction et applique profil, rang, package, cible, participation et options avant l'entrée dans l'arbre.

## Routes réelles

- **Combat Lab** : l'annexe de légions possède une zone dédiée `BRONZE COLOSSUS — JUGGERNAUTS` de sept unités (`scripts/main.gd:482-528`) et la patrouille élite mixte en contient une autre (`:547-559`). Le probe Lab ouvre la vraie scène puis ajoute le roster mission via la factory.
- **Battle 03 narrative** : le premier miniboss de la zone 1 est exactement `bronze_colossus` (`scripts/battle/battle_03_narrative.gd:354-360`). Il est classé unité de commandement, donc sa route ne force pas le mode foule léger (`:463-470`).
- **Campagne procédurale** : il est l'élite finale des remparts, sous le titre `LE COLOSSE DU REMPART` (`scripts/campaign/procedural_wave_director.gd:579-593`). Son coût/poids empêchent une apparition trop précoce.
- **Forge** : le probe construit un document `enemy_group` exact pour les 22 IDs, puis `HopliteWorldRuntime` matérialise le groupe et rejoint la factory. La capture ne contourne donc pas le runtime Forge.

Le roster global confirme la ligne exacte :

```text
id=bronze_colossus family=bronze_colossus rig=package_retarget
anatomy=12/12 equipment=hammer action=colossus_roar navigation=LARGE_BODY
```

## IA, attaques et phase 2

Le contrôleur commun conserve des états explicites pour la charge du juggernaut, l'attente de permission, le windup, le recovery, le désarmement, le sommeil et la mort. La cible passe par la sélection partagée et la permission d'attaque FIFO; perte de cible, désarmement, sommeil et mort relâchent le lease au lieu de laisser une attaque fantôme.

### Phase 1 — cycle exact de quatre actions

| Action | Animation externe | Windup | Recovery | Cooldown | Identité mécanique |
|---|---|---:|---:|---:|---|
| `colossus_roar` | `mutant_roar` | 0.92 | 0.22 | 0.34 | télégraphe sans dégâts |
| `colossus_charge` | `axe_combo` | 0.62 | 0.62 | 1.08 | dégâts x1.26, portée x1.12, lunge 6.2 |
| `colossus_quake` | `axe_down` | 0.88 | 0.78 | 1.42 | shockwave radiale 3.8 m, dégâts x0.88 |
| `colossus_sweep` | `mutant_swipe` | 0.58 | 0.60 | 1.10 | dégâts x1.08, portée x1.22, arc large -0.42 |

Le probe comportement exact parcourt les quatre entrées par `_begin_ai_attack()` et `_resolve_ai_attack()`, avec permission réelle, puis confirme leur résolution et le retour. Le roar suit volontairement la branche `telegraph`; la quake construit son disque d'annonce, libère l'onde puis applique un falloff radial dans le rayon déclaré.

### Transition et phase 2

À `health/max_health <= 0.52`, `_try_activate_combat_phase()` effectue une transition unique et atomique : phase `2`, vitesse x`1.08`, dégâts x`1.16`, vitesse d'animation x`1.08`, cooldowns divisés par `1.08`, annulation du windup précédent, curseur remis à zéro et signal `combat_phase_changed(2)` émis une seule fois.

Le pattern devient exactement :

- `colossus_double_quake` : `axe_down`, shockwave 4.4 m, windup 0.72, recovery 0.46, cooldown 0.70, dégâts x0.94;
- `colossus_frenzy` : `mutant_swipe`, windup 0.42, recovery 0.44, cooldown 0.72, dégâts x1.18, portée x1.28, arc -0.55.

Le probe de phase confirme `transitions=[2]`, l'application unique des multiplicateurs et l'ordre exact des deux actions runtime. Aucune phase 3 n'est déclarée ni inventée.

## Navigation `LARGE_BODY`, collisions et récupération

`athenian_enemy.gd:689-706` force explicitement `LARGE_BODY` pour `bronze_colossus`. Ce mode n'instancie pas de `NavigationAgent3D`; il préserve un steering direct de grand corps avec :

- facteur de vitesse borné à `0.78`;
- tolérance d'arrivée `0.28 m`;
- progrès minimal `0.12 m/s`;
- détection de blocage après `1.15 s`;
- récupération latérale bornée à `0.72 s`, vitesse x`0.72`.

Le probe exact simule 72 frames sans déplacement, observe une seule entrée en récupération, applique un progrès dans la direction de dégagement, confirme l'absence de `navigation_failed`, puis vérifie arrivée et `clear_destination()`. C'est un contrat volontairement distinct du `NAVMESH_GROUND` des fantassins : il produit mouvement et recovery observables mais ne promet pas un détour topologique autour d'un labyrinthe.

Le corps dynamique reste un `CharacterBody3D` avec `CapsuleShape3D` primitive locale (rayon 0.39, hauteur 1.82) et échelle racine uniforme 1.22. Les descendants ne contiennent aucune `ConcavePolygonShape3D` dynamique. Les ennemis ne se collisionnent pas physiquement entre eux; la séparation tactique remplit ce rôle à moindre coût.

## Package, rig, retarget, LOD et équipement

Le résolveur essaie `bronzeColossus.glb`, puis `BronzeColossus.glb`, puis `bosscolossus.glb`. Seul le dernier existe : 13 057 576 octets, SHA-256 `A0FF35E63CD15DA211A2EF22CC7D4966ED35BA53A8AE299E0A3ED15F31AE8686`. Son import glTF conserve tangentes, named skins, shadow meshes, LOD générés et animations à 30 FPS.

L'adaptateur de package valide le squelette UAL1 de 53 os, les dix meshes corporels segmentés et les caps gore. Un donneur caché `UAL1_Standard.glb` fournit locomotion/mort via `AuthoredPoseBridge` en rest-space; le `HopliteNativeAnimationDriver` fournit ensuite les actions spécialisées et charge sélectivement `mutant_roar`, `axe_combo`, `axe_down` et `mutant_swipe`. Le probe animation démarre réellement :

```text
ANIMATION BRONZE COLOSSUS visual=retarget opener=colossus_roar clip=external:mutant_roar
```

Le probe LOD commun passe les routes shared/native/direct, les cadences réduites et le réveil réversible. Le driver n'est pas gelé définitivement : une action force un sample, LOD1/2 réduisent l'évaluation, LOD3 dort, LOD0 reprend.

Le marteau procédural est attaché à `DEF-hand.R` via `BoneAttachment3D`, échelle 1.28. Aucun bouclier ni hitbox de garde parasite n'est créé. La section du bras/avant-bras droit appelle `_drop_weapon()`; la mort libère aussi le marteau comme rigid body borné. Les matériaux procéduraux sont partagés par paramètres immuables.

La silhouette source est donc partagée avec le package historique de colosse, tandis que stats, taille, armure, équipement et pattern définissent l'identité Bronze. Créer un package visuel dédié serait une amélioration artistique valide, pas un correctif nécessaire au contrat actuel.

## Anatomie, démembrement, mort et lifecycle

Les douze zones runtime sont présentes : tête, cou, torse, bassin, deux bras supérieurs, deux avant-bras, deux cuisses et deux tibias. Le probe exact instancie une unité neuve par zone et applique un `HitEvent` de section : `zones=12`, `severed=10`. Torse et bassin restent non sectionnables; tête/cou respectent la fatalité; bras droit libère le marteau; pertes de jambes déclenchent boiterie/crawl.

La mort est atomique : permission et cible relâchées, `set_ai_participation(false)`, retrait des groupes/registry/crowd, destination effacée, collisions et anatomie arrêtées, physique désactivée. Après la chute `Death01`, le cadavre devient render-only; collisions, particules et ombres dynamiques sont retirées. Les membres, arme, sang, télégraphes et shockwaves ont tous un lifecycle borné. Le probe lifecycle commun passe ressources partagées, TTL, retrait collision/ombres et cleanup.

## Performance — photographie actuelle

Commande fraîche :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_performance_benchmark.gd -- --counts=1,12,56 --mode=both --warmup=120 --frames=120 --seed=13371 --archetype=bronze_colossus
```

Le harness utilise `mass_battle_mode=true`, registry désactivé et 60 ticks/s. Il mesure donc le contrôleur, la physique, l'anatomie et la route UAL1 légère, pas le coût GPU ni celui de drivers spécialisés complets. Les snapshots `process/physics` sont diagnostiques; p95/p99 décrit l'intervalle de tick cadencé.

| Mode | Unités | Spawn ms | Process / physics snapshot ms | Nœuds | Objets | Mémoire statique | Corps actifs | Tick p95 / p99 / max ms | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 1 | 242.929 | 0.773 / 0.473 | 87 | 1 772 | 78 943 602 o | 0 | 20.706 / 20.734 / 20.754 | PASS |
| idle | 12 | 457.538 | 4.845 / 1.661 | 978 | 2 905 | 85 576 140 o | 0 | 20.700 / 20.704 / 21.024 | PASS |
| idle | 56 | 1 083.316 | 19.129 / 2.500 | 4 542 | 7 437 | 111 671 176 o | 0 | 20.385 / 31.072 / 33.605 | PASS |
| actif | 1 | 320.873 | 0.831 / 0.928 | 88 | 1 775 | 80 717 426 o | 1 | 20.707 / 20.737 / 20.764 | PASS |
| actif | 12 | 436.537 | 6.089 / 5.228 | 990 | 2 930 | 87 075 700 o | 12 | 20.703 / 20.778 / 21.088 | PASS |
| actif | 56 | 1 093.692 | 26.938 / 11.899 | 4 598 | 7 550 | 112 673 596 o | 56 | **28.709 / 34.593 / 38.065** | PASS structurel |

Le seuil de foule `28` n'a pas été modifié. Le teardown est parfait dans les six scénarios : zéro combattant, WeakRef vivant ou orphelin après cleanup. À 56 actifs, le p95 dépasse toutefois 16.67 ms et le snapshot process+physics atteint 38.837 ms : cette densité est hors budget sur ce poste/headless. Aucune baseline phase 0 strictement comparable propre à `bronze_colossus` n'existe; aucun gain chiffré n'est revendiqué.

## Preuves visuelles inspectées

`docs/enemy_refactor/visual_evidence/bronze_colossus.png` (1 351 x 760) montre `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`. La masse voûtée, la flexion des genoux et le port du marteau restent lisibles; l'attaque et l'impact ne sont pas une T-pose; la mort est horizontale; la section montre un moignon coloré, un membre séparé et l'équipement lâché. Le marteau très large occupe fortement le premier plan, mais son échelle correspond au profil et il reste attaché hors mort/section.

`lab_full_roster_visual_probe.png` et `forge_full_roster_visual_probe.png` (1 600 x 900) ont aussi été inspectées en résolution originale. Le Lab utilise la vraie scène plus l'annexe mission; Forge utilise le vrai document/runtime. Dans les deux, `bronze_colossus` est présent, posé et équipé au sein des 22/22 sans T-pose grossière. Les labels sont petits et l'éclairage Forge est très chaud : ces vues prouvent l'intégration de contexte, pas la qualité fine des textures ou des attaches.

## Tests exécutés

| Test | Résultat | Portée / réserve |
|---|---|---|
| `enemy_unit_dismemberment_probe.gd -- --id=bronze_colossus` | PASS `zones=12 severed=10` | exact, fatalités, marteau, teardown |
| `enemy_unit_behavior_probe.gd -- --id=bronze_colossus` | PASS | loin/proche, 4 attaques, interruption, perte cible, sleep/wake, cleanup |
| `enemy_phase_contract_probe.gd -- --id=bronze_colossus` | PASS `transitions=[2] actions=2/0` | transition atomique, multiplicateurs et ordre phase 2 |
| `enemy_large_body_contract_probe.gd -- --id=bronze_colossus` | PASS | profil exact, shockwave 3.8, recovery, capsule, arrivée/clear |
| `enemy_full_roster_validation_probe.gd` | PASS `22/22` | identité/famille/rig/anatomie/équipement/action/navigation |
| `enemy_roster_audit.gd` | PASS `22/22` | `pattern=4/2`, quatre donors, package présent |
| `enemy_animation_probe.gd` | PASS `14/14` | opener exact `colossus_roar -> mutant_roar` |
| `enemy_navigation_component_probe.gd` | PASS | intentions, formation, fallback et recovery communs |
| `enemy_animation_lod_probe.gd` | PASS | shared/native/direct, cadence et réveil réversible |
| `enemy_transient_lifecycle_probe.gd` | PASS | ressources partagées, TTL, collisions/ombres retirées |
| `enemy_material_cache_probe.gd` | PASS | matériaux procéduraux partagés |
| `enemy_performance_benchmark.gd` | PASS structurel `1/12/56`, idle/actif | limite CPU à 56 actifs documentée |

Tous les logs sont dans `.tmp_tools/enemy_refactor/bronze_colossus_audit/`. L'avertissement Windows `Failed to read the root certificate store` apparaît au démarrage mais ne touche pas la scène, et chaque probe applicable termine avec code 0.

## Revue Godot 4.7

### Critique

Aucune panne critique propre à `bronze_colossus` n'est reproduite.

### Améliorations / dette honnête

- Créer un package `bronzeColossus.glb` artistiquement distinct si l'identité visuelle doit diverger davantage; conserver le fallback jusqu'à validation rig/anatomie/animations/section complète du nouvel asset.
- Ajouter un parcours Battle 03 instrumenté qui force et résout les deux actions de phase 2 au contact réel du joueur, au-delà du contrat exact de sélection déjà vert.
- Si les niveaux futurs exigent des détours complexes, comparer le steering `LARGE_BODY` à une navigation topologique de grand gabarit sans perdre vitesse, inertie, spacing ni recovery.
- Produire une bibliothèque bake complète de locomotion, mort et six actions avant toute tentative de retrait UAL1/UAL2/donors; fournir ensuite des preuves multi-frame Lab, Battle et Forge.
- Mesurer GPU, VRAM, draw calls, surfaces et qualité des LOD dans une vraie fenêtre; le headless ne couvre pas ces compteurs.
- Ne pas extrapoler un pourcentage de gain sans baseline de cette même famille, mêmes options et même build.

### Points solides

- Profil distinct, rang, phase et pattern cohérents avec l'identité de siège.
- Factory unique et route d'asset/fallback explicitement observable.
- Scheduler, phase et mort possèdent des sorties atomiques.
- Collisions dynamiques primitives et récupération LARGE_BODY bornée.
- Anatomie segmentée et équipement détachable préservés.
- LOD animation réversible et teardown sans référence vivante.

---

Revu contre les checklists Godot 4.3+ / 4.7 de navigation, animation, physique, assets, 3D, testing, debugging et code review.
