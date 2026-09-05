# Audit final distinct — `ncenturion`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable (`5b4e0cb0f`)**\
**Renderer des probes : `gl_compatibility`, headless**\
**Portée : état courant du worktree; sources centrales inspectées en lecture seule, écritures limitées au présent rapport et aux logs temporaires.**

## Verdict synthétique

`ncenturion` conserve son identité de taxiarque/miniboss : glaive et aspis physiques, garde renforcée, déplacement de commandant et cycle déclaré `probe -> bash avec lunge -> combo lourd`. La factory résout le package final `ncenturion-1787350193317.glb`; l'adaptateur valide son squelette visible à 53 os, ses dix segments corporels et ses dix-huit caps, puis conserve le donneur UAL1 et installe le driver natif sélectif requis par les cinq actions externes.

Les preuves fraîches passent le comportement exact loin/proche, les trois étapes distinctes du pattern via le vrai scheduler, l'interruption par désarmement sans dégâts, la perte de cible, le sommeil/réveil, les douze zones anatomiques, les dix sections, le bouclier guard-gated, la mort atomique et le teardown. Le roster complet passe `22/22`; l'animation spécialisée joue bien `centurion_probe -> external:light1`; le stress mixte passe `22 familles / 36 unités` sans changer le seuil de masse de 28. Les captures dédiées, Lab et Forge ne montrent pas de T-pose franche ni d'équipement manquant.

Verdict final : **DONE**. Aucun défaut fonctionnel concret propre à `ncenturion` n'est reproduit. Les limites restantes sont documentées : le mode `DIRECT_STEERING` ne fournit pas de détour topologique, le graphe non-masse conserve plusieurs donneurs invisibles coûteux, le modèle source compte 21 654 triangles, la racine physique est uniformément scalée à 1,18, et la preuve visuelle manque encore d'une séquence rapprochée. Aucun donneur, segment ou asset source ne doit être supprimé sur la base de cet audit.

## Profil canonique et identité

Source de vérité : `scripts/enemy/enemy_archetypes.gd:749-805`; vue typée/cachée par `profile()` et `data()` (`:37`, `:76`).

| Champ | Valeur |
|---|---:|
| nom / rang / famille | `TAXIARQUE` / `miniboss` / `ncenturion` |
| rôle / skin / échelle | `formation_commander` / `captain` / `1.18` |
| PV / vitesse | `570` / `4.50 m/s` |
| dégâts / portée / aggro | `31` / `1.92 m` / `25 m` |
| arme / bouclier | `gladius` x`1.08` / aspis x`1.14` |
| comportement / style | `commander` / `disciplined` |
| windup / recovery génériques | `0.30 s` / `0.34 s` |
| cooldown générique | `0.92–1.20 s` |
| vitesse d'animation | `1.14` |
| bande préférée | `0–1.82 m` |
| rayon tactique / séparation / approche | `2.05` / `1.20` / `0.82` |
| garde | chance `0.50`, durée `0.82 s`, cooldown `1.25 s` |
| réduction en garde | dégâts x`0.12`, section x`0.08` |
| endurance / régénération | `158` / `27`, délai `1.55 s` |
| réaction / poise | `0.085 s` / `0.48` |
| signature | UAL2, `Shield_OneShot` ou `Sword_Regular_Combo`, chance `0.45` |
| procédural | coût `5.00`, poids `0.24`, première vague `4` |
| package gagnant | `ncenturion-1787350193317.glb` |

Aucune `phase_two_pattern`, aucun seuil de phase et aucun multiplicateur de phase ne sont déclarés. L'unité est explicitement un miniboss monophasé, pas un boss à phases. Le probe de phase, qui exige une phase 2, n'est donc pas applicable et aucune phase artificielle n'est inventée.

## Construction, factory et routes de contenu

`HopliteEnemyFactory.spawn_request()` (`scripts/enemy/enemy_factory.gd:49`) est la route canonique. La requête transmet ID, position, participation IA, mode masse, faction, cible, joueur de bataille, groupe de formation et options avant `add_child()`. Le profil typé fixe ensuite le rang et le package; `_ready()` construit collider, visuel, anatomie, équipement, navigation, groupes et registre.

Le full roster confirme exactement :

```text
id=ncenturion family=ncenturion rig=package_retarget anatomy=12/12
equipment=gladius+shield action=centurion_probe navigation=DIRECT_STEERING
```

Routes inspectées et exercées :

- **Combat Lab** : annexe `NCENTURION — COMMANDANTS`, groupe régulier mixte et patrouille élite (`scripts/main.gd:494`, `:532`, `:547`). Les groupes sont créés par `EnemySpawnRequest` puis `EnemyFactory.spawn_request()` (`:610-653`).
- **Battle 03 narratif** : un taxiarque en zone 1, un par aile de phalange en zone 2 et trois verrouillant l'objectif final en zone 3 (`scripts/battle/battle_03_narrative.gd:373`, `:388`, `:420-422`). Ils restent des unités de commandement et ne sont pas rétrogradés par le mode masse (`:464`).
- **Procédural** : profil de final elite par défaut et légion dédiée; le directeur construit une requête typée et appelle la factory (`scripts/campaign/procedural_wave_director.gd:247`, `:319-323`, `:428-432`). Le probe procédural passe unité ordinaire, miniboss et boss, dont ce package réel.
- **Forge** : `HopliteWorldRuntime` matérialise les entités `enemy_group`, puis appelle la factory; le mode masse s'active seulement à `total_count >= 28` (`scripts/world_editor/world_runtime.gd:278-316`). La capture Forge 22/22 utilise ce vrai document/runtime.

`enemy_factory_route_probe.gd` passe et ne retrouve aucune route de construction parallèle. `battle_enemy_spawn_probe.gd` passe les contrats hostile/helper. Le cache de profil isole les dictionnaires legacy; la résolution de package n'est pas répétée dans une boucle chaude.

## Décision, combat, garde et ordonnancement

Le contrôleur partagé possède la cible, les représailles, l'aggro/hystérésis, les slots tactiques, la permission FIFO, le windup, la résolution et la recovery. Le probe exact produit un objectif borné et un état explicite aussi bien loin que proche, puis traverse les trois actions dans leur ordre déclaratif :

| Action | Clip sélectif | Windup | Recovery | Cooldown | Identité mécanique |
|---|---|---:|---:|---:|---|
| `centurion_probe` | `external:light1` | `0.24 s` | `0.22 s` | `0.54 s` | dégâts x`0.82`, portée x`0.94` |
| `centurion_bash` | `external:dash_attack` | `0.32 s` | `0.34 s` | `0.72 s` | dégâts x`0.76`, lunge `5.6` |
| `centurion_combo` | `external:heavy_release` | `0.46 s` | `0.44 s` | `1.02 s` | dégâts x`1.34`, portée x`1.08` |

Chaque attaque passe par `_begin_ai_attack()`, obtient une permission générationnelle, déclenche le clip synchronisé à `windup + recovery`, puis `_resolve_ai_attack()` revérifie cible, lease, arme, portée et arc avant les dégâts. Le désarmement pendant le windup annule l'action et ne délivre aucun dégât; la perte de cible libère la permission. Les probes `enemy_action_state_probe` et `enemy_combat_probe` passent garde, recovery, windup, parry, guard break et patterns élites.

L'aspis n'intercepte rien lorsqu'il est baissé : son `Area3D` quitte la couche d'arme. Le Combat Lab réel contient exactement sept `ncenturion` parmi ses 21 porteurs de bouclier; `shooting_range_shield_probe` lève puis baisse chaque bouclier et passe `56 unités / 21 shields`, parité du registre et teardown. La réduction de garde et l'endurance sont donc cohérentes avec une surface physique réellement activée, pas un booléen décoratif.

Le scheduler et le crowd director restent les propriétaires transversaux de l'équité de groupe. Le stress mixte passe deux cohortes, cible mobile/changée, sommeil/réveil, quatre morts et quatre sections. Aucun silence ou lease orphelin propre au taxiarque n'est observé.

## Navigation, mouvement et récupération

Mode exact : `EnemyNavigationComponent.Mode.DIRECT_STEERING`. `ncenturion` n'est ni une phalange `ngeneral` ni un grand corps; aucun `NavigationAgent3D` inutile n'est créé.

Configuration commune (`scripts/enemy/athenian_enemy.gd:689-706`) : arrivée à `0.28 m`, progrès minimal `0.12 m/s`, blocage après `0.82 s`, récupération latérale pendant `0.48 s` à `72 %` de la vitesse. Le composant donne une intention; le `CharacterBody3D` reste seul propriétaire de `velocity`, de la gravité et de `move_and_slide()`, puis lui notifie le mouvement réellement appliqué.

`enemy_navigation_component_probe.gd` passe intention, formation, fallback et récupération. Le comportement exact couvre destination loin/proche, perte de cible et sommeil/réveil; le stress couvre mouvement collectif et retarget. La grille spatiale de foule est partagée et rafraîchie à cadence bornée.

Limite assumée : `DIRECT_STEERING` ne calcule pas de chemin global autour d'un mur ou dans un passage complexe. Il fournit séparation et récupération locale avec reason codes, mais pas la garantie topologique de `NAVMESH_GROUND`. Une migration future devra comparer le rayon monde du taxiarque, les passages étroits et sa vitesse inchangée avant d'adopter un navmesh.

## Rig, retarget, assets et LOD

Audit statique frais de `assets/characters/3dgen_demo/ncenturion-1787350193317.glb` :

| Mesure | Valeur |
|---|---:|
| taille | `10 145 008` octets |
| format / générateur | glTF `2.0` / Blender glTF `5.2.39` |
| scènes / nœuds | `1 / 83` |
| skins / joints | `1 / 53` |
| meshes / primitives | `28 / 28` |
| triangles source | `21 654` |
| matériaux / textures / images | `2 / 1 / 1` |
| animations locales | `0` |
| gore | `10` segments corporels, `18` caps corps/membre |

La route runtime est explicite :

1. le package visible fournit le squelette et les meshes, mais aucune animation;
2. un donneur caché `UAL1_Standard.glb` fournit locomotion et `Death01` via `AuthoredPoseBridge` en rest-space;
3. parce que le rang est `miniboss` et cinq clés externes sont déclarées, le mode non-masse installe `HopliteNativeAnimationDriver`;
4. le driver conserve ses donneurs UAL2 mouvement/combat et charge sélectivement `light1`, `dash_attack`, `heavy_release`, `block_idle`, `block_impact`;
5. en mode masse, la branche économique garde le package + UAL1 et n'alloue pas le driver spécialisé.

Le probe animation imprime :

```text
ANIMATION TAXIARQUE visual=retarget opener=centurion_probe clip=external:light1
```

Il exige également que la durée jouée corresponde au contrat mécanique à 0,10 s près. Cette preuve est complétée par le rendu; aucune conclusion n'est tirée de simples quaternions.

L'import active `meshes/generate_lods=true`, shadow meshes et compression. Le LOD runtime utilise biais `1.0 / 0.55 / 0.22`, coupe les ombres au-delà du proche et borne les particules. `enemy_animation_lod_probe` exerce précisément `ncenturion` pour la branche native : 30 Hz au LOD1, 12 Hz au LOD2, pause au LOD3 et échantillon forcé au réveil. L'`AnimationTree` peut donc être temporairement inactif au LOD3, mais il est explicitement réactivé/évalué au retour; il n'est pas gelé définitivement.

Les donneurs restent requis. Leur retrait demanderait une bibliothèque bake/retarget complète, puis de nouvelles preuves multi-frame Idle/Jog/garde/trois attaques/impact/mort, sommeil-réveil, Lab, Forge et démembrement. Aucune suppression n'est autorisée aujourd'hui.

## Meshes, équipement et physique

Le package ne contient pas les animations ni une route d'équipement jouable autonome. Le runtime attache un gladius procédural à `DEF-hand.R` à l'échelle `1.08` et un aspis procédural à `DEF-hand.L` à l'échelle `1.14`. Les matériaux procéduraux sont mis en cache par paramètres immuables; le probe de cache passe le helper partagé. Le probe de rayon monde, complété par le Lab exact des porteurs, confirme que l'arbitrage de contact utilise le rayon réellement hérité et non le rayon local `0.48`.

Corps principal : `CharacterBody3D`, couche 4, masque monde + joueur, sans collision ennemi-ennemi. La forme est une `CapsuleShape3D` primitive de rayon local `0.39` et hauteur locale `1.82`, centrée à `0.91`; avec l'échelle uniforme `1.18`, son encombrement théorique monde est environ `0.460 m` de rayon et `2.148 m` de hauteur. Aucune concave dynamique n'est utilisée.

La racine `CharacterBody3D` et ses shapes sont toutefois scalées uniformément par le profil. La checklist physique Godot recommande de dimensionner les shapes plutôt que scaler un corps : aucun défaut n'est reproduit avec cette échelle uniforme et le rayon de bouclier a son correctif monde, mais cela reste une dette de robustesse à tester sur marches, pentes, contacts Jolt et passages étroits.

Les zones anatomiques sont des `Area3D` couche 8. Les membres et équipements lâchés deviennent des `RigidBody3D` couche 16, masque monde, avec primitives, sommeil autorisé et lifecycle borné. Le probe transient confirme ressources partagées, retrait de collision/ombres puis libération.

Les 21 654 triangles dépassent l'objectif indicatif de 12 k, mais une réduction aveugle détruirait la segmentation et les caps. La génération LOD est active; une éventuelle retopologie ou fusion doit être une passe asset séparée, mesurée et suivie des dix preuves de section.

## Anatomie, démembrement et mort atomique

Le profil humanoïde partagé expose exactement douze zones :

| Zone | Forme | Dégâts | Section | Seuil | Conséquence |
|---|---|---:|---:|---:|---|
| `head` | sphère r=`0.25` | x`1.70` | x`1.00` | `64` | section fatale |
| `neck` | capsule r=`0.15` | x`1.85` | x`1.35` | `56` | redirige tête, fatal |
| `torso` | capsule r=`0.34` | x`1.00` | x`0.35` | — | non sectionnable |
| `pelvis` | capsule r=`0.30` | x`0.95` | x`0.30` | — | non sectionnable |
| bras supérieurs L/R | capsule r=`0.16` | x`0.78` | x`1.00` | `78` | descendants masqués; droite lâche glaive, gauche aspis |
| avant-bras L/R | capsule r=`0.14` | x`0.75` | x`1.10` | `60` | équipement du côté lâché |
| cuisses L/R | capsule r=`0.21` | x`0.88` | x`0.82` | `94` | tibia lié, boiterie |
| tibias L/R | capsule r=`0.18` | x`0.84` | x`1.05` | `72` | boiterie; deux jambes = crawl |

`enemy_unit_dismemberment_probe.gd -- --id=ncenturion` instancie une unité neuve par zone et passe `zones=12 severed=10`. Les vrais meshes segmentés sont masqués, les caps correspondants révélés et un `SpartanDetachedLimb` est créé; le proxy ne sert qu'en fallback d'échec. La perte du bras droit lâche le glaive, celle du bras gauche l'aspis, et tête/cou finalisent correctement la mort.

La mort (`scripts/enemy/athenian_enemy.gd:3557`) est atomique côté gameplay : lease et cible libérés, `dead=true`, `set_ai_participation(false)`, retrait des groupes IA et du registre vivant, destination annulée, collisions corps/anatomie coupées, physique active arrêtée, équipement lâché et driver fermé. `Death01` UAL1 joue ensuite, puis le cadavre devient un prop de rendu allégé. Le contrôleur ne `queue_free()` pas immédiatement le cadavre; le propriétaire de rencontre reste responsable de sa suppression finale. Les probes exacts et le benchmark terminent avec zéro référence vivante, combattant ou orphelin.

## Performance — photographie actuelle

Commande fraîche :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_performance_benchmark.gd -- --counts=1,28 --mode=both --warmup=30 --frames=60 --seed=13371 --archetype=ncenturion --registry=on
```

Le harness force `mass_battle_mode=true`, conserve le seuil 28, tourne à 60 ticks/s et mesure structure + intervalles de ticks. Les snapshots `process/physics` sont des moniteurs à rafraîchissement lent; notamment le `process=399.302 ms` du scénario 28 idle est contaminé par l'activité précédente et ne constitue pas une frame indépendante.

| Mode | Unités | Spawn | Process / physics snapshot | Nœuds / objets | Mémoire statique | Corps actifs | Tick p95 / p99 / max | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 1 | `148.473 ms` | `0.517 / 0.370 ms` | `91 / 1 775` | `62 207 351 o` | `0` | `20.704 / 20.740 / 20.740 ms` | PASS |
| idle | 28 | `389.063 ms` | `399.302* / 2.705 ms` | `2 359 / 4 637` | `79 382 981 o` | `0` | `20.686 / 24.974 / 24.974 ms` | PASS |
| actif | 1 | `200.809 ms` | `0.542 / 1.103 ms` | `92 / 1 778` | `63 115 823 o` | `1` | `20.699 / 20.729 / 20.729 ms` | PASS |
| actif | 28 | `580.796 ms` | `10.301 / 8.717 ms` | `2 387 / 4 694` | `79 716 633 o` | `28` | **`23.635 / 24.605 / 24.605 ms`** | PASS structurel |

À 28 actifs, le p95 dépasse le budget 16,67 ms; cette limite est conservée, même si le gate du harness porte principalement sur structure et cleanup. Les 28 instances, le registre, les groupes et toutes les références reviennent à zéro.

Cette mesure couvre la branche économique de masse, pas le graphe spécialisé non-masse. Une instance non-masse conserve package visible, UAL1, driver UAL2 mouvement/combat et cinq donneurs externes sélectifs; son coût structurel doit recevoir un benchmark instrumenté séparé avant toute revendication de gain. Aucune baseline phase 0 strictement comparable propre à `ncenturion` n'existe; les baselines `swordsman`/`ngeneral` ont d'autres rigs et profils. Aucun pourcentage avant/après n'est donc inventé. Le headless ne mesure ni GPU, VRAM, draw calls ni qualité visuelle du LOD.

## Preuves visuelles inspectées

`docs/enemy_refactor/visual_evidence/ncenturion.png` (1 351 x 760) montre `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`. L'armure argent/bleu reste cohérente, les pieds/jambes changent entre idle et jog, l'attaque et l'impact ont des silhouettes distinctes, le corps mort est horizontal, et la section montre membre, glaive/aspis et cap. Aucune T-pose franche à deux bras horizontaux n'apparaît.

Limites visibles : le bras droit nu reste assez écarté dans idle/jog; les colonnes attaque/impact se chevauchent et le bouclier masque le torse; la planche est un instantané, pas une séquence. Elle ne prouve donc pas à elle seule transition, frame de contact, retour idle ou réveil. Le probe animation prouve le clip exact et sa durée, tandis que behavior/LOD prouvent mécanique et reprise. Un rendu futur rapproché devrait isoler les trois attaques et les attaches des mains.

`docs/enemy_refactor/lab_full_roster_visual_probe.png` (1 600 x 900) montre le roster complet dans la vraie scène Combat Lab, avec `ncenturion` parmi les porteurs d'aspis. `docs/enemy_refactor/forge_full_roster_visual_probe.png` (1 600 x 900) montre le même ID via le vrai `HopliteWorldRuntime`. Aucun équipement manquant, échelle incohérente ni T-pose grossière n'est visible. Les personnages et labels restent petits; ces captures prouvent présence/route/construction, pas la qualité fine de chaque articulation.

## Tests exécutés

| Test | Résultat | Portée / réserve |
|---|---|---|
| `enemy_unit_dismemberment_probe.gd -- --id=ncenturion` | PASS `12/10` | exact, fatalités, glaive/aspis, vrais fragments, teardown |
| `enemy_unit_behavior_probe.gd -- --id=ncenturion` | PASS | exact, far/close, 3 attaques, interruption, cible perdue, sleep/wake, cleanup |
| `enemy_full_roster_validation_probe.gd` | PASS `22/22` | ligne exacte famille/rig/anatomie/équipement/action/navigation |
| `enemy_roster_audit.gd` | PASS `22/22` | rang miniboss, pattern `3/0`, cinq clés externes, package présent |
| `enemy_animation_probe.gd` | PASS `14/14` | opener exact `centurion_probe -> external:light1`, durée synchronisée |
| `enemy_animation_lod_probe.gd` | PASS | branche native `ncenturion`, cadence et réveil réversible |
| `shooting_range_shield_probe.gd` | PASS `56/21` | Lab réel; sept taxiarques, surface guard-gated et teardown |
| `enemy_shield_world_radius_probe.gd` | PASS | helper partagé; rayon de requête égal à l'échelle physique héritée |
| `enemy_material_cache_probe.gd` | PASS | helper partagé; matériaux procéduraux immuables réutilisés |
| `enemy_combat_probe.gd` | PASS | garde, rupture, parry et patterns élites |
| `enemy_action_state_probe.gd` | PASS | garde/recovery/windup/parry/priorité tactique |
| `enemy_navigation_component_probe.gd` | PASS | intention, formation, fallback et recovery |
| `enemy_anatomy_regression_probe.gd` | PASS | section létale finalise toujours la mort |
| `enemy_transient_lifecycle_probe.gd` | PASS | ressources partagées, TTL, retrait collision/ombres |
| `enemy_factory_route_probe.gd` | PASS | routes canoniques |
| `battle_enemy_spawn_probe.gd` | PASS | contrats Battle hostile/helper |
| `procedural_enemy_spawn_probe.gd` | PASS | ordinaire/miniboss/boss, package réel et cleanup |
| `enemy_mixed_stress_probe.gd` | PASS `22/36` | seuil 28, deux cohortes, retarget, wake, morts/sections, cleanup |
| `enemy_performance_benchmark.gd` | PASS structurel `1/28` idle/actif | limite p95 active documentée |

Logs : `.tmp_tools/enemy_refactor/logs/ncenturion_*.log`. `Failed to read the root certificate store` est un bruit Windows reproductible sans incidence sur les scènes; tous les probes applicables retenus terminent avec code `0`.

Tests non applicables : `enemy_phase_contract_probe` exige une phase 2 absente du profil monophasé; `enemy_mixamo_variant_matrix_probe` cible les familles `direct_mixamo`, alors que la route gagnante est le package authored `package_retarget`.

## Revue Godot 4.7

### Critique

Aucune panne critique propre à `ncenturion` n'est reproduite.

### Améliorations / dette honnête

- Instrumenter le graphe non-masse (squelettes, `AnimationPlayer`, `AnimationTree`, donneurs externes, mémoire et coût CPU) puis comparer avant toute suppression ou migration.
- Produire une bibliothèque bake/retarget canonique de la famille seulement après preuves visuelles multi-frame; conserver UAL1, UAL2 et les cinq donors jusque-là.
- Comparer `DIRECT_STEERING` à `NAVMESH_GROUND` sur obstacle, passage étroit et retour au poste, sans modifier vitesse, accélération ou bande de combat.
- Remplacer à terme le scaling du `CharacterBody3D` par des dimensions de shapes/visuel explicites si une migration peut conserver rig, attaches et rayons monde; valider alors Jolt et interpolation.
- Retopologiser ou générer de vrais LOD asset lors d'une passe séparée; ne pas fusionner les dix segments ni retirer les caps pour atteindre arbitrairement 12 k triangles.
- Regénérer une planche rapprochée sans chevauchement, avec les trois attaques, mains/aspis, garde/impact et plusieurs frames de sommeil-réveil.
- Prendre une baseline propre à cette famille et une mesure GPU Lab/Forge avant de publier un pourcentage de gain, des draw calls ou de la VRAM.

### Points solides

- Profil typé, pattern de trois attaques et garde cohérents avec le rôle de commandant.
- Factory unique et routes Battle/Procédural/Lab/Forge explicites.
- Permissions, interruption, perte de cible, sommeil et mort ont des sorties atomiques.
- Collider principal primitif, bouclier réellement guard-gated et rayon monde corrigé.
- Démembrement intégral préservé sur les vrais segments; transients bornés.
- LOD animation natif réversible; aucun arbre figé définitivement après retour à proximité.

---

Revu contre les checklists Godot 4.3+ / 4.7 de navigation, animation, physique, assets, 3D, testing, debugging et code review.
