# Audit final distinct — `nathenian2`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Sa phase déclarée passe le probe exact; teardown, TTL et rechargement sont couverts par `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable (`5b4e0cb0f`)**\
**Renderer des probes : `gl_compatibility`, headless**\
**Portée : état courant du worktree; audit en lecture seule des sources centrales, avec écriture limitée au présent rapport et aux logs temporaires.**

## Verdict synthétique

`nathenian2` conserve correctement son identité de miniboss briseur de ligne : marteau lourd, armure, charge frontale, trois attaques distinctes en phase 1 et transition à 48 % de vie vers deux attaques de phase 2. La factory sélectionne le package final `nathenian2-1787346736278.glb`; le runtime valide son rig à 53 os et ses meshes anatomiques segmentés, puis utilise le donneur UAL1 et le driver de retarget natif sélectif pour les actions spécialisées.

Les probes exactes passent le comportement loin/proche, les trois attaques de phase 1, l'interruption par désarmement, la perte de cible, le sommeil/réveil, la transition atomique de phase 2, les douze zones anatomiques, les dix sections, l'équipement, le teardown, le roster complet `22/22` et l'animation spécialisée `hammer_overhead -> external:axe_down`. Les preuves rendues dédiées, Lab et Forge ne montrent ni pose en T grossière ni équipement détaché de la main hors scénario de section.

Verdict final : **DONE**. Aucun défaut fonctionnel propre à l'unité n'est reproduit. Trois limites honnêtes demeurent : `DIRECT_STEERING` n'est pas un pathfinding topologique autour d'obstacles complexes; le donneur UAL1 et les donors d'actions restent nécessaires tant qu'une bibliothèque bake/retarget complète n'a pas été prouvée visuellement; 56 instances actives homogènes dépassent le budget 16,67 ms dans le harness headless. Aucun donneur ni asset source ne doit être supprimé sur la base de cet audit.

## Profil canonique et identité

Source de vérité : `scripts/enemy/enemy_archetypes.gd:632-689`, normalisée et mise en cache par `profile()`/`data()` (`:37`, `:76`).

| Champ | Valeur |
|---|---:|
| nom / rang / famille | `BRISEUR DE LIGNE` / `miniboss` / `nathenian_heavy` |
| rôle / skin / échelle | `line_breaker` / `brute` / `1.18` |
| PV / vitesse | `430` / `3.85 m/s` |
| dégâts / portée / aggro | `34` / `2.10 m` / `22 m` |
| arme / bouclier | marteau `1.16` / aucun |
| comportement / style | `brute` / `heavy` |
| windup / recovery | `0.48 s` / `0.52 s` |
| cooldown | `1.30-1.68 s` |
| vitesse d'animation | `0.94` |
| bande préférée | `0-1.96 m` |
| rayon tactique / séparation / approche | `2.02` / `0.62` / `0.86` |
| défense | armure, dégâts x`0.84`, section x`0.70` |
| poise | `0.58` |
| procédural | coût `4.20`, poids `0.28`, première vague `3` |
| package gagnant | `nathenian2-1787346736278.glb` |

Le profil distinct `nathenian2_soldier` est un alias de package mais pas de rôle : il devient troupe lourde (185 PV, échelle 1.06) et perd explicitement phase 2 et budget miniboss. Cet alias fait l'objet d'un audit unitaire séparé; il ne doit pas être confondu avec le présent miniboss.

## Factory et routes réelles

`HopliteEnemyFactory.spawn_request()` (`scripts/enemy/enemy_factory.gd:49`) est la route canonique. Elle applique le `EnemySpawnRequest`, le profil typé, le rang miniboss et le package résolu avant `add_child()`. `_ready()` construit ensuite visuel, anatomie, équipement, navigation et participation aux groupes. Le roster global confirme exactement :

```text
id=nathenian2 family=nathenian_heavy rig=package_retarget anatomy=12/12
equipment=hammer action=hammer_overhead navigation=DIRECT_STEERING
```

Routes inspectées :

- **Combat Lab** : showroom statique, groupe combiné actif commandé par `nathenian2`, zone de marteaux et patrouille élite (`scripts/main.gd:303-336`, `:488-496`, `:547`).
- **Forge** : les groupes `enemy_group` du document réel sont matérialisés par `HopliteWorldRuntime` puis la factory; la capture Forge 22/22 utilise cette route réelle.
- **Battle 03** : les troupes lourdes narratives emploient volontairement l'alias `nathenian2_soldier` (`scripts/battle/battle_03_narrative.gd:335`, `:350`, `:389`, `:419`), pas le miniboss nommé. L'asset est partagé, mais les stats et la phase ne le sont pas.
- **Procédural** : le profil est admissible à partir de la vague 3, avec coût/poids bornés; le roster/manifeste le garde comme identité distincte.

Les données de profil sont immuables dans le cache typé; l'API dictionnaire renvoie une copie profonde. Aucun chargement de package n'est effectué dans une boucle chaude : la factory et le cache glTF runtime centralisent la résolution.

## IA, cible, attaques et phase 2

Le contrôleur commun gère cible, représailles, slot d'engagement, permission FIFO, windup, résolution, recovery et libération du lease. Pour `behavior=brute`, l'état est explicitement `brute_charge` hors portée et `brute_attack` dans la portée. Si l'unité attend un anneau d'engagement, l'état devient un rôle de foule explicite; la perte de cible et le sommeil libèrent immédiatement permission et membership IA.

Phase 1, parcourue intégralement par le probe comportement exact :

| Action | Animation sélective | Windup | Recovery | Cooldown | Identité mécanique |
|---|---|---:|---:|---:|---|
| `hammer_overhead` | `axe_down` | 0.62 | 0.58 | 1.08 | dégâts x1.34, portée x1.08 |
| `hammer_shove` | `mutant_punch` | 0.34 | 0.30 | 0.62 | dégâts x0.72, portée x0.86, lunge 4.2 |
| `hammer_sweep` | `mutant_swipe` | 0.50 | 0.50 | 0.98 | dégâts x1.02, portée x1.18, arc large |

À `health/max_health <= 0.48`, `_try_activate_combat_phase()` (`scripts/enemy/athenian_enemy.gd:3431`) appelle une transition unique et atomique : annulation du vieux windup, remise du curseur, vitesse x1.10, dégâts x1.14, cooldowns divisés par 1.10, signal `combat_phase_changed(2)`. La phase 2 sélectionne ensuite exactement :

- `hammer_quake` : `axe_down`, shockwave rayon 3.25, windup 0.72, recovery 0.64;
- `hammer_rush` : `axe_combo`, windup/recovery 0.42, dégâts x1.18, lunge 5.8.

Le probe de phase confirme `transitions=[2]`, deux actions déclarées/récupérées dans le même ordre et aucun faux passage en phase 3. Le probe comportement exact traverse les trois attaques de phase 1 via le vrai scheduler et la vraie résolution; le désarmement interrompt le windup sans infliger de dégâts.

## Navigation, foule et récupération

Mode exact : `EnemyNavigationComponent.Mode.DIRECT_STEERING`. Le corps n'instancie donc pas de `NavigationAgent3D` inutile. Le composant reçoit une destination tactique, retourne direction/vitesse/facing, puis le `CharacterBody3D` applique accélération et `move_and_slide()` avant de notifier le progrès réel.

Configuration commune vérifiée à `scripts/enemy/athenian_enemy.gd:689-706` : arrivée 0.28 m, progrès minimal 0.12 m/s, timeout de blocage 0.82 s, recovery latéral 0.48 s à 72 % de la vitesse. Le probe composant passe intention, formation, fallback et recovery; le probe comportement exact passe objectifs loin/proche et sortie propre après perte de cible.

Limite : le steering direct avec séparation/récupération locale ne garantit pas un détour topologique dans un labyrinthe ou derrière un obstacle complexe. Ce n'est pas un silence de FSM — les états et la récupération restent observables — mais une capacité moindre que `NAVMESH_GROUND`. Une migration future vers navmesh devra conserver vitesse, masse et spacing puis recevoir un probe de détour propre à cette unité.

## Rig, retarget, assets et LOD

Le package principal pèse 10 060 384 octets et est importé en glTF avec tangentes, named skins, shadow meshes, génération de LOD et animations à 30 FPS. L'adaptateur `HopliteSpartanCharacterPackage` impose le schéma `spartan_ual1_v1`, 53 os essentiels, dix meshes corporels segmentés et dix-huit caps gore (corps + membre pour neuf cibles normalisées).

Runtime observé : un squelette visible à 53 os, package segmenté, donneur caché `UAL1_Standard.glb` (6 671 104 octets), `AuthoredPoseBridge` en rest-space et `HopliteNativeAnimationDriver` spécialisé. Les quatre clés externes déclarées (`axe_down`, `mutant_punch`, `mutant_swipe`, `axe_combo`) sont résolues sélectivement par `external_animation_bank.gd`, sans charger une banque complète sur chaque soldat.

Le probe animation spécialisé démarre réellement l'opener et imprime :

```text
ANIMATION BRISEUR DE LIGNE visual=retarget opener=hammer_overhead clip=external:axe_down
```

Il compare également la durée du clip à la somme windup + recovery (tolérance 0.10 s). La planche rendue confirme visuellement la pose produite; le test ne se contente donc pas de variations de quaternions.

Le probe LOD commun passe les trois branches `shared/native/direct`, leurs cadences et le réveil réversible. Pour ce driver natif, la distance réduit la fréquence d'évaluation, puis le réveil force une reprise; aucun `AnimationTree` n'est désactivé définitivement. Le donneur UAL1 et les donors externes restent indispensables à locomotion/mort/actions dans cette route : **suppression interdite sans bibliothèque bake complète et nouvelles preuves Idle/Jog/actions/mort/section**.

## Équipement, collisions et anatomie

Le runtime crée un marteau procédural attaché à `DEF-hand.R`, à l'échelle profil 1.16. Aucun bouclier ou défense `shield` parasite n'est créé; la réduction d'armure est appliquée par le contrat `armor`. Les matériaux procéduraux de peau/arme sont partagés par paramètres immuables; le probe de cache passe.

Corps principal : `CharacterBody3D`, couche ennemi 4, masque monde + joueur, sans collisions ennemi-ennemi. La forme est une `CapsuleShape3D` primitive (rayon local 0.39, hauteur locale 1.82, centrée à 0.91), uniformément héritée par l'échelle de personnage; aucun concave dynamique n'est employé. Les zones anatomiques sont des `Area3D`; les membres/armes lâchés sont des `RigidBody3D` à collision bornée puis retirée par lifecycle.

Les douze zones sont présentes : tête, cou, torse, bassin, deux bras supérieurs, deux avant-bras, deux cuisses et deux tibias. Le probe exact applique un événement de section à chaque zone sur une instance neuve : `zones=12`, `severed=10`. Torse et bassin restent non sectionnables; cou/tête respectent la fatalité; avant-bras/bras droit libèrent le marteau; les jambes produisent les états de boiterie/crawl communs. La mort atomique (`scripts/enemy/athenian_enemy.gd:3557`) libère cible, lease, navigation et groupe IA, désactive les collisions actives et borne les transients. Le probe lifecycle passe ressources partagées, TTL, retrait collisions/ombres et cleanup.

## Performance — photographie actuelle

Commande fraîche :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_performance_benchmark.gd -- --counts=1,12,56 --mode=both --warmup=120 --frames=120 --seed=13371 --archetype=nathenian2
```

Tous les scénarios emploient `mass_battle_mode=true`, registry désactivé, 60 ticks/s. `process`/`physics` ci-dessous sont des snapshots diagnostiques lents; le tick p95/p99 est la mesure temporelle comparable du harness.

| Mode | Unités | Spawn ms | Process / physics snapshot ms | Nœuds | Objets | Mémoire statique | Corps actifs | Tick p95 / p99 / max ms | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 1 | 148.248 | 0.671 / 0.422 | 87 | 1 770 | 62 253 531 o | 0 | 20.726 / 20.965 / 20.982 | PASS |
| idle | 12 | 329.958 | 4.237 / 1.615 | 978 | 2 903 | 68 874 213 o | 0 | 20.704 / 20.957 / 21.236 | PASS |
| idle | 56 | 943.065 | 19.353 / 2.453 | 4 542 | 7 435 | 94 922 257 o | 0 | 21.571 / 33.757 / 36.737 | PASS |
| actif | 1 | 200.167 | 0.782 / 1.039 | 88 | 1 773 | 64 028 359 o | 1 | 20.703 / 20.714 / 20.716 | PASS |
| actif | 12 | 342.720 | 6.375 / 4.684 | 990 | 2 928 | 70 404 757 o | 12 | 20.703 / 20.710 / 20.711 | PASS |
| actif | 56 | 988.375 | 31.418 / 19.577 | 4 598 | 7 548 | 94 347 305 o | 56 | **38.307 / 49.064 / 50.152** | PASS structurel |

Le seuil `mass_battle_mode=28` n'a pas été modifié. À 56 actifs, le teardown reste parfait (zéro combattant, live ref ou orphelin), mais le p95 dépasse nettement 16.67 ms : c'est une limite mesurée, pas masquée. Aucune baseline phase 0 strictement comparable propre à `nathenian2` n'existe; les baselines `swordsman`/`ngeneral` utilisent d'autres rigs. Aucun pourcentage de gain n'est donc revendiqué. Le headless ne mesure ni GPU, VRAM, draw calls ni qualité réelle des LOD.

## Preuves visuelles inspectées

`docs/enemy_refactor/visual_evidence/nathenian2.png` (1 351 x 760) montre `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`. Les silhouettes ont bassin, genoux, bras et tête dans des poses cohérentes; l'attaque porte le marteau au-dessus du corps, l'impact est lisible, la mort est horizontale, et la section montre un bras séparé avec sang. Aucune pose en T grossière n'est visible.

Limites de la planche : instantané plutôt que séquence; l'arme surdimensionnée masque une partie du corps dans certaines colonnes; les particules et le membre sectionné sont éloignés à droite. Elle prouve pose/présence/section, mais pas à elle seule les transitions ou le contact mécanique — couverts par les probes behavior, animation et phase.

Les captures `lab_full_roster_visual_probe.png` et `forge_full_roster_visual_probe.png` (1 600 x 900) ont été inspectées en résolution originale. Elles montrent le roster complet dans la vraie scène Lab et via le vrai `HopliteWorldRuntime` Forge. `nathenian2` y est construit, équipé et animé sans T-pose grossière. Les personnages et labels sont petits; ces captures prouvent l'intégration de contexte, pas la qualité fine des attaches.

## Tests exécutés

| Test | Résultat | Portée / réserve |
|---|---|---|
| `enemy_unit_dismemberment_probe.gd -- --id=nathenian2` | PASS `zones=12 severed=10` | exact, fatalités, marteau, teardown |
| `enemy_unit_behavior_probe.gd -- --id=nathenian2` | PASS | loin/proche, 3 attaques, interruption, perte cible, sleep/wake, cleanup |
| `enemy_phase_contract_probe.gd -- --id=nathenian2` | PASS `transitions=[2]`, actions `2/0` | transition atomique, multiplicateurs et ordre exacts |
| `enemy_full_roster_validation_probe.gd` | PASS `22/22` | identité/famille/rig/anatomie/équipement/action/navigation exacts |
| `enemy_roster_audit.gd` | PASS `22/22` | profil miniboss, pattern `3/2`, quatre donors, package présent |
| `enemy_animation_probe.gd` | PASS `14/14` | opener exact `hammer_overhead -> external:axe_down`, synchronisation mécanique |
| `enemy_navigation_component_probe.gd` | PASS | intention, formation, fallback, recovery |
| `enemy_animation_lod_probe.gd` | PASS | shared/native/direct, cadence et réveil réversible |
| `enemy_transient_lifecycle_probe.gd` | PASS | ressources partagées, TTL, retrait collision/ombres |
| `enemy_material_cache_probe.gd` | PASS | matériaux procéduraux partagés |
| `enemy_performance_benchmark.gd` | PASS structurel `1/12/56`, idle/actif | limite CPU à 56 actifs documentée |

Le probe `enemy_package_attack_fallback_probe.gd -- --id=nathenian2` a été lancé comme contrôle négatif et sort rouge, car il exige explicitement un package léger **sans** driver spécialisé. `nathenian2` possède correctement `HopliteNativeAnimationDriver`; ce probe est conçu pour `nathenian1` et n'est pas applicable ici. Le test pertinent `enemy_animation_probe.gd` vérifie la branche retarget réelle et passe.

Les diagnostics Windows `Failed to read the root certificate store` et `Could not create directory: user://.tmp_tools/enemy_refactor` apparaissent au démarrage de certains runs, sans toucher la scène ni le résultat; les logs demandés sont néanmoins écrits et chaque probe applicable termine avec code 0.

## Revue Godot 4.7

### Critique

Aucune panne critique propre à `nathenian2` n'est reproduite.

### Améliorations / dette honnête

- Mesurer une bataille Lab/Forge GPU réelle avec draw calls, VRAM, surfaces et qualité LOD; le headless ne couvre pas ces compteurs.
- Si l'unité doit franchir des environnements fortement occlus, comparer `DIRECT_STEERING` à `NAVMESH_GROUND` sans modifier vitesse, portée ou sensation de masse.
- Produire un bake hors runtime des quatre actions et de locomotion/mort, puis ne retirer UAL1/donors qu'après preuves visuelles multi-frame, sommeil/réveil, Lab, Forge et section zone par zone.
- Réduire éventuellement la densité source lors d'une passe asset séparée; ne pas fusionner/supprimer les segments anatomiques pour atteindre arbitrairement 12 k triangles.
- Reprendre une baseline strictement comparable de cette même famille avant de revendiquer tout gain chiffré futur.

### Points solides

- Profil de phase distinct, typé et cohérent avec le rang miniboss.
- Factory unique, caches ressources et sélection de donors sélective.
- États, permissions et transitions de phase possèdent des sorties explicites.
- Collisions dynamiques primitives; anatomie et démembrement préservés intégralement.
- LOD animation réversible et teardown sans références vivantes.

---

Revu contre les checklists Godot 4.3+ / 4.7 de navigation, animation, physique, assets, 3D, testing, debugging et code review.
