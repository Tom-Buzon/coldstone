# Audit final distinct — `ngeneral_veteran`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable (`5b4e0cb0f`)**\
**Renderer des probes : `gl_compatibility`, headless**\
**Portée : état courant du worktree; sources centrales inspectées en lecture seule, écritures limitées au présent rapport et aux logs temporaires.**

## Verdict synthétique

`ngeneral_veteran` conserve une identité de lancier d'élite réellement distincte du `ngeneral` standard : 235 PV, dory et grand aspis, garde renforcée, quatre thrusts propres, rôle de flanc, placement aux extrémités de chaque rang, bonus de cohésion voisin et réorganisation de cohorte accélérée. Les routes Lab, Battle 03, campagne procédurale et Forge convergent vers la factory canonique et le même profil typé.

La famille hoplite est la branche la plus aboutie de la migration d'animation. Standard et vétéran partagent le rig visible `ngeneral`, la même `AnimationLibrary` v3 immuable et des clips réellement avancés, tout en gardant chacun son `AnimationPlayer`, son `AnimationTree` et son temps local. Aucun squelette UAL1/UAL2, pose bridge ou donneur FBX n'est instancié à l'exécution. Le LOD réduit l'échantillonnage à 30/12 Hz, dort au niveau 3 et force une évaluation au réveil; aucun arbre ne reste définitivement figé.

Les probes exacts passent les quatre attaques déclarées par le vrai scheduler, le désarmement sans dégâts, la perte de cible et de lease, sommeil/réveil, phalange/cohorte dégradée, garde, dory/aspis importés, rayon physique monde, anatomie 12/12, dix sections, mort atomique, lifecycle borné et cleanup. Le stress mixte passe 22 familles et 36 unités sans modifier le seuil de masse 28. Les captures unité, Lab et Forge ne montrent aucune T-pose grossière ni équipement manquant.

Verdict final : **DONE**. Aucun défaut fonctionnel concret propre à `ngeneral_veteran` n'est reproduit. Les limites restantes sont honnêtes : source LOD0 lourde avant LOD/fusion, échelle physique racine uniforme 1,20, métriques GPU absentes, labels des captures globales trop petits et deux défauts de harness décrits plus bas. Aucun asset source ne doit être supprimé sans une nouvelle preuve rendue et fonctionnelle.

## Profil canonique et différenciation du hoplite standard

Source de vérité : `scripts/enemy/enemy_archetypes.gd:806-869`, normalisée par `profile()` puis exposée par `HopliteEnemyArchetypeData`.

| Champ | `ngeneral_veteran` | `ngeneral` standard | Différence jouable |
|---|---:|---:|---|
| nom / rang / rôle | `LANCIER VETERAN` / `elite` / `phalanx_flank_guard` | `LANCIER HOPLITE` / `troop` / `phalanx_core` | élite de flanc, pas simple recolor |
| échelle | `1.20` | `1.00` | silhouette et volumes monde plus grands |
| PV | `235` | `145` | +62 % environ |
| vitesse | `3.82 m/s` | `3.70 m/s` | fermeture/replacement légèrement plus rapide |
| dégâts / portée / aggro | `25 / 2.90 / 25 m` | `18 / 2.72 / 22 m` | pression et perception supérieures |
| dory / aspis | x`1.16` / x`1.18` | x`1.10` / x`1.12` | équipement visuellement et physiquement plus ample |
| comportement / style | `phalanx_veteran` / `spear_veteran` | `phalanx` / `spear_compact` | pattern et rôle tactique distincts |
| windup / recovery génériques | `0.28 / 0.26 s` | `0.32 / 0.34 s` | cadence vétéran plus vive |
| cooldown générique | `0.82–1.12 s` | `1.05–1.38 s` | fréquence d'action supérieure |
| bande préférée | `1.48–2.72 m` | `1.58–2.58 m` | allonge plus permissive |
| formation | 5 colonnes, `1.12 / 1.22 m`, poursuite `8.5 m`, rotation `34°/s` | `1.08 / 1.18 m`, `7.5 m`, `28°/s` | phalange un peu plus ouverte et réactive |
| rôle de formation | `flank_guard` | `line` | vétéran affecté aux extrémités de rang |
| garde | chance `0.78`, durée `0.92`, cooldown `1.05` | `0.62 / 0.82 / 1.30` | garde plus fiable |
| réduction garde | dégâts x`0.09`, section x`0.05` | x`0.14 / 0.08` | plaque plus protectrice |
| endurance / régénération | `168 / 32`, délai `1.05 s` | `112 / 24` | meilleure tenue de mur |
| bonus cohésion | `+0.16` | `+0.12` | régénération accrue près d'un vétéran |
| poise | `0.52` | `0.28` | interruption plus difficile |
| procédural | coût `2.80`, poids `0.42`, vague `3` | `1.55 / 1.15 / 0` | élite plus rare et tardive |

Le profil ne déclare aucune signature probabiliste ni phase 2 : `signature_source=none`, liste vide, chance zéro, aucun `phase_two_pattern`. L'identité provient donc de son cycle déterministe, de sa garde et de son rôle de cohorte. Aucune phase artificielle n'est inventée.

## Factory et routes réelles

`HopliteEnemyFactory.spawn_request()` est le point canonique. La requête typée transmet ID, cible, participation IA, groupe de formation, index, faction, mode masse et options avant `add_child()`. `_ready()` applique ensuite le profil avant collider, visuel, anatomie, équipement, navigation, groupes et registre.

Le full roster confirme exactement :

```text
id=ngeneral_veteran family=hoplite_ngeneral rig=shared_library
anatomy=12/12 equipment=spear+shield action=veteran_riposte navigation=FORMATION_LOCAL
```

Routes inspectées et exercées :

- **Combat Lab** : listes d'élites et phalanges mixtes dans `scripts/main.gd:519-568`, construites via `EnemySpawnRequest` puis la factory. `shooting_range_shield_probe` ouvre le vrai Lab, trouve 56 unités et 21 boucliers guard-gated, puis valide registre et teardown. La capture roster ajoute l'annexe mission dans la vraie scène.
- **Battle 03 narratif** : `scripts/battle/battle_03_narrative.gd:448` choisit explicitement `ngeneral_veteran` pour les positions vétérans; `narrative_battle_probe` passe deux phalanges de douze soldats et leurs déclencheurs.
- **Procédural** : le directeur route `final_elite` vers `ngeneral_veteran` (`procedural_wave_director.gd:605`) et transmet le mode masse dans la requête typée. Les probes de spawn et de campagne passent unités ordinaires, miniboss/boss, légions étagées, surge de 20 et fin élite.
- **Forge** : `HopliteWorldRuntime` matérialise les `enemy_group` par la factory, place les vétérans aux extrémités de chaque rang de phalange (`world_runtime.gd:752-809`) et n'active la masse qu'à `total_count >= 28` (`:316`). `world_editor_flow_probe` passe le document/runtime; la capture Forge 22/22 utilise ce chemin réel.

`enemy_factory_route_probe` ne retrouve aucune construction runtime parallèle. Le seuil de foule reste exactement `28`.

## Combat, signatures d'action et garde

Le probe comportement exact force les quatre entrées déclaratives dans leur ordre, chacune par `_begin_ai_attack()` puis `_resolve_ai_attack()` avec une vraie permission générationnelle :

| Action | Clip partagé | Windup | Recovery | Cooldown | Identité mécanique |
|---|---|---:|---:|---:|---|
| `veteran_riposte` | `spear_thrust` | `0.22 s` | `0.22 s` | `0.62 s` | dégâts x`1.08`, portée x`1.04`, départ 0.16 |
| `veteran_low_thrust` | `spear_thrust_low` | `0.24 s` | `0.25 s` | `0.70 s` | dégâts x`1.02`, visée basse `-0.20`, départ 0.20 |
| `veteran_delayed_thrust` | `spear_thrust` | `0.52 s` | `0.24 s` | `0.88 s` | feinte lente, dégâts x`1.28`, portée x`1.08` |
| `veteran_shield_push` | `shield_bash` | `0.22 s` | `0.30 s` | `0.92 s` | dégâts x`0.62`, portée x`0.74`, lunge `3.0` |

Le désarmement pendant le windup annule l'attaque avant livraison de dégâts. La suppression de la cible produit un objectif non offensif et libère la permission. Sommeil puis réveil restaurent décision, animation et participation. `enemy_action_state_probe` complète cette preuve par garde, recovery, windup, parry et priorité tactique.

L'aspis n'est pas un booléen décoratif : son `Area3D` n'entre sur la couche de garde qu'une fois levé. `shooting_range_shield_probe` lève puis baisse chaque aspis du vrai Lab. `enemy_shield_world_radius_probe` confirme que les requêtes de contact multiplient le rayon local par l'échelle globale héritée; à l'échelle 1,20 et shield scale 1,18, aucune hypothèse de rayon local n'est utilisée comme rayon monde.

## Phalange, cohorte, foule et récupération

`EnemyNavigationComponent.Mode.FORMATION_LOCAL` est forcé pour les deux comportements de phalange. Le composant retourne une intention et un reason code; `CharacterBody3D` reste seul propriétaire de la vitesse, de la gravité et de `move_and_slide()`, puis lui notifie le déplacement réellement appliqué.

Configuration commune : arrivée `0.28 m`, progrès minimal `0.12 m/s`, blocage `0.82 s`, récupération latérale `0.48 s` à 72 % de vitesse. Le mode local suit le slot/facing de cohorte et non un `NavigationAgent3D`; ce contrat est volontaire pour préserver une ligne compacte. Il ne promet pas un détour topologique individuel dans un labyrinthe.

Le directeur de foule :

- sépare les vétérans des réguliers et réserve jusqu'à deux extrémités par rang aux vétérans;
- conserve les slots survivants lors d'une mort/vacance et attribue seulement les places libres;
- assemble 90 % des membres, puis autorise après timeout une formation dégradée bornée;
- avance un seul anchor partagé au lieu de recalculer un objectif indépendant par soldat;
- accélère le timer de réorganisation de x`1.35` si un vétéran survit;
- compte les vétérans proches afin d'appliquer le bonus de régénération de garde;
- gère l'intrusion par un arc temporaire d'expulsion, puis réassemble la ligne;
- reconstruit sa grille spatiale à 20 Hz, avec invalidation immédiate des changements d'appartenance.

`hoplite_phalanx_optimization_probe` passe une construction de formation pour 15 soldats, locomotion gardée, suivi anatomique endormi/réveillé et politique d'ombres. `hoplite_cohort_recovery_probe` passe cible stable, vacance et assemblage dégradé. Les probes foule passent anneau de contact, réserves, budget d'attaque, intrusion/expulsion et cadence spatiale. Le stress mixte passe deux cohortes, cible mobile puis remplacée, wake, quatre sections, quatre morts et cleanup.

## Rig canonique, bibliothèque partagée et LOD

Asset canonique : `assets/characters/3dgen_demo/ngeneral-1787351044165.glb`. Audit statique frais :

| Mesure source | Valeur |
|---|---:|
| taille / SHA-256 | `6 794 932` octets / `43FBC335EF4E12BF021E4C56D9DBB023D896A41B5ED5437910769999D701D1C4` |
| glTF / générateur | `2.0` / Blender glTF `5.2.39` |
| scènes / nœuds | `1 / 83` |
| skins / joints | `1 / 53` |
| meshes / primitives | `28 / 28` |
| triangles LOD0 cumulés | `31 652` |
| matériaux / textures / images | `2 / 1 / 1` |
| animations locales | `0` |
| corps / caps gore | `10 / 18` |

L'import active tangentes, LOD générés, shadow meshes, compression permise, skins nommés et bake animation 30 FPS. Le nombre source dépasse l'objectif indicatif 12 k; il ne doit pas déclencher une suppression aveugle, car les dix zones et dix-huit caps sont nécessaires au gore.

La route runtime est différente des packages génériques :

1. le rig visible canonique est instancié une seule fois par unité;
2. `hoplite_animation_library_v3.res` est attachée à son `AnimationPlayer` local;
3. un `HopliteSharedAnimationDriver` construit un `AnimationTree` local avec locomotion complète et action filtrée sur le haut du corps;
4. les deux variantes référencent la même `AnimationLibrary`, mais conservent des temps et états indépendants;
5. le corps fusionné `ArrayMesh` est partagé, garde les indices LOD et encode les zones anatomiques par couleur de sommet;
6. aucun descendant nommé `UAL1`, `UAL2`, `Donor`, aucun pose bridge et aucun squelette invisible ne subsiste dans cette branche.

Mappage sémantique v3 : `spear_thrust` et `shield_bash -> ual2_shield_one_shot`, `spear_thrust_low` et `block_impact -> ual2_sword_block`, `block_idle -> ual2_idle_shield`. Ce sont des clips compatibles bakés et validés, pas des donneurs runtime.

Le probe d'optimisation mesure `Sprint=2.2695`, déplacement tibia `1.1484`, locomotion sous garde `1.3754` et action spear `1.6920`; le mesh suit donc effectivement le rig. Le probe spécialisé imprime :

```text
ANIMATION LANCIER VETERAN visual=retarget opener=veteran_riposte clip=external:spear_thrust
```

LOD animation : continu au niveau 0, 30 Hz au niveau 1, 12 Hz au niveau 2, pause au niveau 3. `force_simulation_sample()` active temporairement l'arbre, l'évalue, puis le remet en sommeil si nécessaire. Le probe exact passe cadence et réveil réversible. Aucune optimisation ne laisse un `AnimationTree` définitivement inactif.

## Dory, aspis, matériaux et physique

Les deux équipements ne sont pas des proxies génériques dans cette branche :

- `dory_spear.glb`, mesh `SM_Dory_Spear`, attaché à `DEF-hand.R`;
- `aspis_shield.glb`, mesh `SM_Aspis_Shield`, attaché à `DEF-hand.L`;
- le probe exige une dory couvrant au moins `-0.88 .. +1.78 m` dans son espace importé et un aspis supérieur à `0.90 x 0.90 m`;
- le hitbox de garde reste enfant de la racine d'aspis et suit sa pose explicite;
- la garde vétéran hausse le bouclier de `0.08 m` supplémentaires;
- la perte bras/avant-bras droit lâche la dory; côté gauche, l'aspis.

Les matériaux procéduraux auxiliaires sont cachés par paramètres immuables. `enemy_material_cache_probe` passe l'identité partagée des ressources; l'équipement importé conserve ses propres matériaux.

Corps principal : `CharacterBody3D`, couche ennemie 4, masque monde + joueur, pas de collision ennemi-ennemi. Le collider est une `CapsuleShape3D` primitive locale rayon `0.39`, hauteur `1.82`, centrée à `0.91`; l'échelle racine uniforme `1.20` donne environ `0.468 m` de rayon et `2.184 m` de hauteur monde. Aucune concave dynamique n'est utilisée.

La checklist physique recommande cependant de dimensionner directement les shapes au lieu de scaler un corps. L'échelle est uniforme et les anatomies/rayons monde la compensent; aucun défaut n'est reproduit, mais pentes, marches, interpolation et passages étroits méritent un probe Jolt dédié avant une refonte de collider.

## Anatomie, démembrement, mort et lifecycle

Le profil humanoïde expose douze zones : tête, cou, torse, bassin, deux bras supérieurs, deux avant-bras, deux cuisses et deux tibias. Tête/cou sont létaux; torse/bassin ne se sectionnent pas; les huit zones de membres et la tête produisent dix résultats sectionnables en comptant les deux routes létales tête/cou vers le segment tête.

| Zone | Forme / rayon | Dégâts | Section / seuil | Conséquence |
|---|---|---:|---:|---|
| `head` | sphère `0.25` | x`1.70` | x`1.00 / 64` | fatal, tête détachée |
| `neck` | capsule `0.15` | x`1.85` | x`1.35 / 56` | redirige tête, fatal |
| `torso` | capsule `0.34` | x`1.00` | x`0.35 / —` | dégâts localisés |
| `pelvis` | capsule `0.30` | x`0.95` | x`0.30 / —` | dégâts localisés |
| bras supérieurs L/R | capsule `0.16` | x`0.78` | x`1.00 / 78` | descendant masqué, équipement côté lâché |
| avant-bras L/R | capsule `0.14` | x`0.75` | x`1.10 / 60` | équipement côté lâché |
| cuisses L/R | capsule `0.21` | x`0.88` | x`0.82 / 94` | tibia lié, boiterie |
| tibias L/R | capsule `0.18` | x`0.84` | x`1.05 / 72` | boiterie; deux jambes = crawl |

`enemy_unit_dismemberment_probe.gd -- --id=ngeneral_veteran` instancie une unité fraîche par zone et passe `zones=12 severed=10`. Les zones sont des `Area3D` primitives suivant les os. La fusion corporelle masque la zone par shader, révèle le cap approprié et crée le fragment physique; elle ne retire pas la segmentation logique.

La mort est atomique côté gameplay : permission/cible libérées, `dead=true`, `set_ai_participation(false)`, retrait du crowd/registry/groupes, destination annulée, attaques/physique/collisions/anatomie arrêtées, équipement lâché et driver fermé. Le cadavre garde une pose de mort puis devient render-only allégé; l'encounter reste propriétaire de sa suppression finale. Sang, membres et équipements détachés ont des TTL bornés, retirent collisions/ombres puis sont libérés. Le probe lifecycle passe ressources partagées et teardown.

## Performance — photographie exacte actuelle

Commande fraîche :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_performance_benchmark.gd -- --counts=1,28 --mode=both --warmup=30 --frames=60 --seed=13371 --archetype=ngeneral_veteran --registry=on
```

Le harness force `mass_battle_mode=true`, conserve le seuil 28, tourne à 60 ticks/s et valide structure + cleanup. Les moniteurs `process/physics` sont des snapshots à rafraîchissement lent, non des frames indépendantes; le p95 de l'intervalle mur (~20,7 ms) reflète également le pacing 60 Hz du harness et n'est pas un benchmark CPU pur.

| Mode | Unités | Spawn | Snapshot process / physics | Nœuds / objets | Mémoire statique | Corps actifs | Tick p95 / p99 / max | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 1 | `147.642 ms` | `0.276 / 0.577 ms` | `78 / 1 715` | `51 852 448 o` | `0` | `20.702 / 20.718 / 20.718 ms` | PASS |
| idle | 28 | `231.588 ms` | `233.946* / 4.013 ms` | `1 995 / 4 388` | `64 171 423 o` | `0` | `20.702 / 21.062 / 21.062 ms` | PASS |
| actif | 1 | `66.679 ms` | `0.637 / 1.086 ms` | `79 / 1 718` | `52 567 112 o` | `1` | `20.705 / 20.709 / 20.709 ms` | PASS |
| actif | 28 | `317.068 ms` | `320.570* / 12.127 ms` | `2 023 / 4 445` | `64 598 891 o` | `28` | `20.703 / 21.006 / 21.006 ms` | PASS structurel |

`*` Valeurs explicitement diagnostiques et contaminables par le scénario précédent; elles ne servent pas de gate. Les quatre scénarios terminent avec zéro combattant, WeakRef vivant ou orphelin; le registre contient exactement 1/28 références pendant le run puis zéro après.

Cette photo prouve surtout l'économie structurelle de la bibliothèque partagée : 28 vétérans n'instancient pas 28 piles de donneurs. Elle ne mesure ni GPU, VRAM, draw calls, surfaces réellement visibles ni coût d'un combat Battle 03 complet. Aucune amélioration en pourcentage n'est revendiquée sans baseline strictement comparable de cette famille.

## Preuves visuelles inspectées

`docs/enemy_refactor/visual_evidence/ngeneral_veteran.png` (1 351 x 760) montre `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`. Idle/jog ont bras et jambes fléchis, l'attaque montre la dory haute et l'aspis porté, l'impact reste posé, la mort est couchée et la section montre membre séparé, cap et équipement au sol. Aucune T-pose franche ni aspis détaché au repos.

`lab_full_roster_visual_probe.png` et `forge_full_roster_visual_probe.png` (1 600 x 900) ont été inspectées en résolution originale. Le Lab utilise la vraie scène plus l'annexe mission; Forge le vrai document/runtime. Les 22 identités sont visibles, équipées et posées. Les labels sont petits, certaines silhouettes se chevauchent et Forge est très chaud/surexposé : ces images prouvent intégration et absence de T-pose grossière, pas coutures, tangence, texture, LOD précis ou clipping rapproché.

## Tests exécutés

| Test | Résultat | Portée / réserve |
|---|---|---|
| `enemy_unit_dismemberment_probe -- --id=ngeneral_veteran` | PASS `12 / 10` | chaque zone, équipement, fatalités, teardown |
| `enemy_unit_behavior_probe -- --id=ngeneral_veteran` | PASS | loin/proche, 4 attaques, interruption, target-loss, sleep/wake, cleanup |
| `enemy_full_roster_validation_probe` | PASS `22/22` | famille, shared rig, anatomie, équipement, opener, navigation |
| `hoplite_phalanx_optimization_probe` | PASS | bibliothèque partagée, mouvements mesurés, corps fusionné, formation cache, tracking/ombres |
| `hoplite_cohort_recovery_probe` | PASS | cible stable, vacance, assemblage dégradé |
| `crowd_tactics_probe` | PASS | contact, réserves, budget attaque, intrusion/expulsion |
| `crowd_spatial_cadence_probe` | PASS | snapshot initial, grille 20 Hz, invalidation immédiate |
| `hoplite_animation_rig_audit` | PASS structurel | rig 53 os, meshes/caps, pistes sources |
| `enemy_animation_probe` | PASS `14/14` | opener vétéran joue `spear_thrust` et durée synchronisée |
| `enemy_animation_lod_probe` | PASS | shared/native/direct, cadence et réveil réversible |
| `phalanx_equipment_probe` | PASS | dory/aspis importés, mains et dimensions |
| `enemy_material_cache_probe` | PASS | ressources immuables partagées |
| `enemy_shield_world_radius_probe` | PASS | rayon de requête égal au rayon physique monde |
| `enemy_action_state_probe` | PASS | garde, recovery, windup, parry, priorité |
| `enemy_transient_lifecycle_probe` | PASS | ressources partagées, TTL, collisions/ombres retirées |
| `enemy_mixed_stress_probe` | PASS `22 familles / 36 unités` | seuil 28, 2 cohortes, retarget, wake, sections, morts, cleanup |
| `shooting_range_shield_probe` | PASS `56 / 21 shields` | vrai Lab, guard gate, registry, teardown |
| `enemy_factory_route_probe` | PASS | construction canonique unique |
| `narrative_battle_probe` | PASS | Battle 03, deux phalanges de 12 |
| `procedural_enemy_spawn_probe` / `procedural_campaign_probe` | PASS | factory procédurale et progression de campagne |
| `world_editor_flow_probe` | PASS `WORLD_EDITOR_FLOW_OK` | document/runtime Forge, composition mixte |
| `enemy_performance_benchmark` | PASS structurel | 1/28 idle/actif, registre et cleanup |

Logs : `.tmp_tools/enemy_refactor/ngeneral_veteran_audit/`. L'avertissement Windows de certificat racine et l'échec d'écriture des préférences Gore HUD dans le sandbox sont sans incidence sur les assertions. Les probes de scènes complètes signalent quelques ressources/objets au shutdown du harness, tandis que leurs contrats de registre/ennemi sont verts; ce bruit n'est pas attribué à l'unité.

## Revue Godot 4.7

### Critique

Aucune panne critique propre à `ngeneral_veteran` n'est reproduite.

### Améliorations / dette honnête

- `enemy_roster_audit.gd` imprime `donors=5` pour les hoplites, mais il compte les cinq clés externes déclarées. La branche shared_library instancie explicitement zéro donneur. Renommer ce champ `external_keys` ou rapporter séparément ressources bake et instances runtime.
- `forge_hoplite_animation_probe.gd`, ancien harness interactif, échoue en headless avant sa propre assertion : le joueur de fixture appelle `_build_camera()`/`_build_weapons()` alors que leurs parents ne sont pas dans l'arbre, puis boucle sur une caméra invalide. Ce défaut d'outillage ne reproduit pas une panne ennemie; `world_editor_flow_probe` et la capture Forge 22/22 actuelle passent. Corriger ou retirer ce probe avant de le remettre dans une suite CI.
- Garder la bibliothèque v3 et tous ses assets sources tant qu'une nouvelle version n'a pas les mêmes preuves multi-frame, LOD/wake, quatre attaques, garde/impact, Lab, Battle, Forge et dix sections. « Zéro donneur runtime » n'autorise pas à supprimer les ressources ayant servi au bake.
- Mesurer GPU/VRAM/draw calls, nombre de surfaces réellement rendues, ombres et sélection des LOD dans une vraie fenêtre; le headless ne couvre pas ces coûts.
- Réduire les 31 652 triangles source seulement par retopologie/LOD prouvés. Préserver shader de zone, dix segments logiques, dix-huit caps, Skin et fragments.
- Remplacer à terme l'échelle du `CharacterBody3D` par des dimensions de collider/équipement explicites, après tests Jolt de pentes, marches, passages et interpolation.
- Produire une planche rapprochée dédiée au vétéran : plusieurs instants de chaque thrust, garde/impact, mains/dory/aspis, transition LOD3→0 et comparaison standard/vétéran.

### Points solides

- Profil typé, rôle de flanc, garde et quatre attaques réellement distincts du standard.
- Factory unique et quatre routes de contenu exercées.
- Bibliothèque immuable partagée, lecture indépendante, un seul squelette visible et zéro donneur runtime.
- Placement vétéran aux ailes, réorganisation/cohésion, fallback solitaire et cohorte dégradée bornés.
- Dory/aspis importés, garde physique et rayon monde corrects.
- Démembrement intégral conservé malgré la fusion du corps; lifecycle et mort atomiques.
- LOD animation réversible, seuil de masse 28 inchangé et teardown sans référence ennemie vivante.

---

Revu contre les checklists Godot 4.3+ / 4.7 de navigation, animation, physique, assets, 3D, composants, testing, debugging et code review.
