# Audit final distinct — `giant_standard`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable (`5b4e0cb0f`)**\
**Renderer des probes : `gl_compatibility`, headless**\
**Portée : état courant du worktree; sources centrales inspectées en lecture seule, écritures limitées au présent rapport et aux logs temporaires.**

## Verdict synthétique

`giant_standard` est fonctionnel et distinct. Le profil canonique le place entre le novice et le vétéran : rang `elite`, 520 PV, 32 dégâts, vitesse 3,65 m/s, poise 0,56 et cycle exact de trois actions `standard_punch -> standard_swipe -> standard_jump`. Il est volontairement non armé et monophasé. Il partage le package final `geant1-1787584159710.glb` avec les deux autres paliers, mais pas leurs valeurs ni leurs patterns.

La factory, l'adaptateur package, le rig 53 os, le retarget, les douze zones anatomiques, les dix sections, les vrais fragments, le crawl après perte des deux jambes, la tête convexe issue du vrai mesh, le sommet marchable et le mouvement `LARGE_BODY` passent leurs probes. Le comportement exact traverse les trois attaques par le vrai scheduler, traite perte de cible, sommeil/réveil et cleanup. Le roster complet passe `22/22`; les captures unitaire, Combat Lab et Forge ne montrent ni T-pose franche ni géant absent.

Verdict final : **DONE**. Aucun défaut fonctionnel concret propre à `giant_standard` n'est reproduit. Les limites sont néanmoins réelles : `LARGE_BODY` offre une récupération locale plutôt qu'un chemin topologique, l'asset source compte environ 80,8 k triangles, le graphe non-masse conserve le donneur UAL1 et le driver sélectif, et les captures sont des instantanés. Aucun donneur, segment, cap ou asset source ne doit être supprimé sur la base de cet audit.

## Profil canonique et différenciation

Source de vérité : `scripts/enemy/enemy_archetypes.gd:926-976`; accès typé/caché par `profile()` et `data()`.

| Champ | Valeur |
|---|---:|
| nom / rôle / rang | `GEANT — STANDARD` / `solo_giant_standard` / `elite` |
| famille | `giant_geant1` |
| skin / échelle de profil | `brute` / `1.00` |
| PV / vitesse | `520` / `3.65 m/s` |
| dégâts / portée / aggro | `32` / `2.20 m` / `26 m` |
| arme / défense | `unarmed` / `none` |
| comportement / style | `brute` / `giant_standard` |
| windup / recovery génériques | `0.46 s` / `0.44 s` |
| cooldown générique | `1.02–1.34 s` |
| vitesse d'animation | `1.02` |
| rayon tactique / séparation / approche | `2.42` / `1.95` / `0.88` |
| poise | `0.56` |
| traversée Forge | `assisted`, rayon x`0.90`, hauteur x`1.00`, sommet marchable |
| procédural | coût `6.40`, poids `0`, première vague `99` |
| package gagnant | `geant1-1787584159710.glb` |

La progression de famille est lisible :

| Palier | PV | Dégâts | Vitesse | Poise | Pattern | Phase 2 |
|---|---:|---:|---:|---:|---:|---:|
| novice | `280` | `25` | `3.35` | `0.38` | `2` actions | non |
| **standard** | **`520`** | **`32`** | **`3.65`** | **`0.56`** | **`3` actions** | **non** |
| vétéran | `860` | `40` | `3.95` | `0.72` | `4 + 3` actions | oui, à `48 %` |

Le standard ne déclare ni `phase_threshold` ni `phase_two_pattern`. Ce n'est pas une perte de comportement historique : la phase est précisément la signature du vétéran. `enemy_phase_contract_probe` n'est donc pas applicable et aucune phase artificielle n'est ajoutée.

## Factory et routes Forge / probes

`HopliteEnemyFactory.spawn_request()` reste la route canonique. Le full roster confirme exactement :

```text
id=giant_standard family=giant_geant1 rig=package_retarget anatomy=12/12
equipment=unarmed action=standard_punch navigation=LARGE_BODY
```

`enemy_factory_route_probe.gd` ne détecte aucune construction runtime parallèle. Le contrat dictionnaire legacy conserve les options géant : `match_perfect_hitbox`, mode de traversée, multiplicateurs de capsule et sommets marchables.

Dans la Forge, `HopliteWorldRuntime.spawn_enemy_group()` résout l'ID par la factory, transmet toutes les options de traversée et n'active `mass_battle_mode` qu'à `total_count >= 28`. Le seuil mission de 28 est donc inchangé. `world_editor_probe.gd` passe aussi la normalisation/sérialisation de ces propriétés.

La preuve Combat Lab charge la vraie scène `combat_lab.tscn`, ajoute une annexe de validation et instancie les 22 IDs par la factory. La preuve Forge construit un vrai `WorldDocument`, exécute `HopliteWorldRuntime` et exige exactement une instance de chaque ID. Ces deux routes valident présence, squelette et anatomie `12/12`; elles ne remplacent pas les probes de combat spécialisés.

## Combat et IA exacte

Le contrôleur partagé possède acquisition de cible, aggro, état tactique, permission FIFO, windup, résolution et recovery. `enemy_unit_behavior_probe.gd -- --id=giant_standard` exerce les décisions loin/proche puis chaque étape déclarée :

| Action | Slot / clip externe | Windup | Recovery | Cooldown | Particularité |
|---|---|---:|---:|---:|---|
| `standard_punch` | `heavy` / `giant_punch` | `0.44 s` | `0.40 s` | `0.92 s` | dégâts x`1.02`, lunge `2.8` à `62 %` |
| `standard_swipe` | `spin360` / `giant_swipe` | `0.52 s` | `0.48 s` | `1.06 s` | dégâts x`0.94`, portée x`1.18`, arc large `-0.32` |
| `standard_jump` | `air_down` / `giant_jump_attack_alt` | `0.72 s` | `0.64 s` | `1.72 s` | dégâts x`1.32`, lunge `5.2` à `46 %` |

Les trois étapes démarrent et se résolvent par `_begin_ai_attack()` / `_resolve_ai_attack()` avec une permission réelle. La perte de cible annule l'autorité et libère la lease; le sommeil retire le groupe IA et le réveil le restaure. La vérification d'interruption par désarmement est logiquement non applicable à une unité `unarmed`; le probe libère alors explicitement la permission au lieu d'inventer une arme.

`enemy_combat_probe.gd` passe les fenêtres d'attaque et patterns élites communs. Le full roster vérifie que l'identité mécanique ne reçoit ni marteau, ni bouclier, ni défense décorative. Aucun comportement dormant ou placeholder n'est observé.

## Navigation `LARGE_BODY` et progression

Mode exact : `EnemyNavigationComponent.Mode.LARGE_BODY`. Ce choix conserve la locomotion particulière des grands corps : direction directe à `78 %` de la vitesse demandée, sans `NavigationAgent3D` inadapté au volume. Le `CharacterBody3D` reste l'unique propriétaire de `velocity`, gravité et `move_and_slide()`.

Configuration effective : arrivée `0.28 m`, progrès minimal `0.12 m/s`, blocage `1.15 s`, récupération latérale `0.72 s` à `72 %`, trois tentatives maximum. Le probe exact simule un obstacle immobile, observe une seule entrée en récupération, applique ensuite un progrès réel, vérifie l'absence de `navigation_failed`, puis valide arrivée et `clear_destination()`.

Cette récupération est bornée et signalée; elle n'est pas un pathfinding global. Un labyrinthe, une porte étroite ou un cul-de-sac complexe peuvent demander un mode hybride ou un navmesh large-body futur. Ce serait une évolution de design, pas une panne démontrée ici; elle devra préserver rayon, vitesse et sensation de masse.

## Traversée, colliders et crawl

Le corps principal reste une `CapsuleShape3D` primitive; aucune `ConcavePolygonShape3D` dynamique n'est présente et la racine garde une échelle uniforme. En mode Forge assisté :

- le collider interne du `CharacterBody3D` reste actif pour résoudre le sol mais sa couche est masquée au joueur;
- un `AnimatableBody3D` couche 256 expose un cylindre lisse de traversée jusqu'aux épaules;
- la tête possède un second `AnimatableBody3D`, avec `ConvexPolygonShape3D` extrait de `SPARTAN_body_head`;
- `HeadFloor` est l'unique stabilisateur de sommet marchable;
- les Areas anatomiques restent les volumes précis de dégâts.

Mesures fraîches du probe : géant posé à `y=0.00053`, cylindre debout `hauteur=4.4661`, `rayon=1.0530`, centre `y=2.23358`; aucun faux plancher latéral (`FALSE_FLOOR_COUNT 0`). La coque tête mesure environ `0.879 x 0.988 x 0.917 m`, reste séparée du cylindre sans couture invalide et est reconnue comme `giant_enemy` par le wall-run.

Après perte des deux jambes, le visuel descend de `0.5502 m` et s'incline de `17.95°`; le cylindre devient `hauteur=2.1633`, `rayon=0.86346` et suit le coeur animé. Le torse reste atteignable des quatre directions, la tête suit la pose, le seam reste valide et un raycast dégâts atteint `torso` avec rayon monde `1.02`. Le géant ne devient donc ni invulnérable ni une fausse rampe après crawl.

Le guide physique recommande d'éviter toute mise à l'échelle d'un corps ou d'une shape. Ici l'échelle racine de profil est `1.00` et les dimensions de traversée sont calculées dans les ressources de shape; aucune scale locale non uniforme de collider n'est observée. Les tailles du package sont cependant bien supérieures à une capsule humanoïde, raison pour laquelle le collider couche 256 est séparé et mesuré sur l'anatomie réelle.

## Rig, animations, assets et LOD

Audit statique du package visible :

| Mesure | Valeur |
|---|---:|
| taille fichier | `19 130 652` octets |
| format / générateur | glTF `2.0` / Blender glTF `5.2.39` |
| scènes / nœuds | `1 / 83` |
| skins / joints | `1 / 53` |
| meshes / primitives | `28 / 28` |
| triangles source | `80 833` |
| matériaux / textures / images | `2 / 1 / 1` |
| animations locales | `0` |
| gore | `10` segments corporels / `18` caps corps-membre |

L'adaptateur refuse un package dont le schéma, le rig, le nombre d'os, les os essentiels, les dix meshes ou les dix-huit caps ne correspondent pas. Le `.import` active tangentes, génération LOD, shadow meshes, compression et import animation à 30 Hz.

Le package n'embarque aucune animation. La route runtime conserve donc le donneur caché `UAL1_Standard.glb`, coupe ses `AnimationTree` concurrents et copie sa pose vers le squelette visible via `AuthoredPoseBridge` en rest-space. En non-masse, le rang élite et les trois clés externes installent aussi le driver natif sélectif. Le probe animation confirme :

```text
ANIMATION GEANT — STANDARD visual=retarget opener=standard_punch clip=external:giant_punch
```

`pose_integrity_probe.gd` mesure une hauteur squelettique cohérente de `1.465` dans l'espace du rig, sans échec. La planche rendue complète la preuve numérique et ne montre pas de bind pose.

Le LOD runtime cadence le pose bridge à chaque frame / une frame sur deux / une sur quatre, puis cesse à LOD3. La branche driver natif est couverte par `enemy_animation_lod_probe` : 30 Hz au LOD1, 12 Hz au LOD2, pause au LOD3 et échantillon forcé au réveil. Ce probe emploie un autre package sur la même branche native, pas `giant_standard` lui-même à chaque distance; la réversibilité est donc une preuve d'infrastructure, tandis que l'opener et la pose du géant sont prouvés séparément.

Les donneurs restent nécessaires. Leur suppression exige une bibliothèque bake/retarget complète puis de nouvelles preuves multi-frame Idle/Jog/trois attaques/impact/mort/crawl, sommeil-réveil, Lab, Forge et dix sections. Aucun retrait n'est justifié aujourd'hui.

Les `80 833` triangles dépassent largement l'objectif indicatif de 12 k. La génération LOD est active, mais une retopologie ou fusion aveugle détruirait la segmentation et les caps. Une optimisation asset future doit être mesurée au rendu et conserver les dix branches sectionnables avant d'être acceptée.

## Anatomie, démembrement et lifecycle

Le profil humanoïde partagé fournit douze zones : tête, cou, torse, bassin, deux bras supérieurs, deux avant-bras, deux cuisses et deux tibias. Dix sont sectionnables; torse et bassin ne le sont pas. Cou et tête sont fatals; sectionner une cuisse masque aussi son tibia; perdre une jambe impose une boiterie et perdre les deux impose `crawl`.

`enemy_unit_dismemberment_probe.gd -- --id=giant_standard` instancie une unité fraîche par zone, applique un impact localisé et passe `zones=12 severed=10`. Pour chaque section, le vrai mesh/cap est actualisé et un enfant détaché est observé. `spartan_character_package.gd` masque la branche correspondante dans le mesh fusionné ou segmenté, révèle le cap corps et construit le fragment à partir du même package; le proxy n'est qu'un fallback d'échec.

La mort létale est atomique : lease libérée, participation IA coupée, groupes/registre nettoyés, destination annulée, collisions désactivées et runtime de corpse retiré après `Death01`. `enemy_anatomy_regression_probe` valide qu'une section létale finalise toujours `_die()`; `enemy_transient_lifecycle_probe` valide ressources partagées, TTL bornés et retrait collisions/ombres.

`giant_traversal_probe` imprime à la sortie un avertissement de deux objets et une ressource encore référencés après avoir chargé la scène Lab complète; il passe néanmoins son contrat. Ce signal n'est pas reproduit par les probes exacts ni par le benchmark, qui terminent avec zéro référence ennemie, zéro combatant et zéro orphelin. Il est donc classé comme limite du harnais Lab chargé, à surveiller, et non comme fuite propre au géant démontrée.

## Performance — photographie actuelle

Commande fraîche :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_performance_benchmark.gd -- --counts=1,28 --mode=both --warmup=30 --frames=60 --seed=13371 --archetype=giant_standard --registry=on
```

Le harness force `mass_battle_mode=true`, tourne à 60 ticks/s et mesure spawn, structure, snapshots moteur et intervalles cadencés. Les valeurs `TIME_PROCESS` / `TIME_PHYSICS_PROCESS` sont des snapshots à rafraîchissement lent; le `process=284.808 ms` du scénario 28 idle est manifestement contaminé par le scénario précédent et n'est pas une frame indépendante.

| Mode | Unités | Spawn | Process / physics snapshot | Nœuds / objets | Mémoire statique | Corps actifs | Tick p95 / p99 / max | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 1 | `49.467 ms` | `0.507 / 0.695 ms` | `81 / 1 757` | `53 771 549 o` | `0` | `20.707 / 20.716 / 20.716 ms` | PASS |
| idle | 28 | `273.915 ms` | `284.808* / 3.018 ms` | `2 079 / 4 214` | `66 902 155 o` | `0` | `22.988 / 24.575 / 24.575 ms` | PASS |
| actif | 1 | `79.390 ms` | `0.497 / 0.937 ms` | `82 / 1 760` | `54 609 769 o` | `1` | `20.701 / 20.733 / 20.733 ms` | PASS |
| actif | 28 | `435.657 ms` | `10.007 / 6.832 ms` | `2 107 / 4 271` | `67 235 707 o` | `28` | **`21.828 / 22.771 / 22.771 ms`** | PASS structurel |

À 28 actifs, le p95 cadencé dépasse 16,67 ms; cela reste une limite honnête. Le run court mesure la branche économique de masse, pas le graphe non-masse complet, ni GPU, VRAM, draw calls ou qualité visuelle. Aucune baseline phase 0 strictement comparable propre à `giant_standard` n'existe : aucun pourcentage de gain n'est inventé. Le résultat solide est le teardown : `combatants_after=0`, `live_enemy_refs=0`, `orphan_node_count=0` pour les quatre scénarios.

## Preuves visuelles inspectées

`docs/enemy_refactor/visual_evidence/giant_standard.png` (1 351 x 760) présente six états : `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`. Idle et jog ont des appuis distincts; attaque et impact changent nettement la silhouette; le corps mort est horizontal; la section montre un membre séparé et la gerbe correspondante. Aucune T-pose à bras horizontaux n'est visible.

Limites : les personnages occupent une petite part de la planche et une image ne prouve ni timing de contact, ni boucle complète, ni transition/réveil. Le comportement exact, le probe animation et la pose fournissent les preuves complémentaires; une future planche rapprochée devrait isoler les trois attaques et le crawl.

`docs/enemy_refactor/lab_full_roster_visual_probe.png` montre le roster complet au-dessus de la vraie scène Combat Lab. `docs/enemy_refactor/forge_full_roster_visual_probe.png` montre le même ID via le vrai runtime Forge. `giant_standard` est visible avec la même morphologie massive que sa famille, sans équipement fantôme ni T-pose grossière. Les labels et unités restent petits : ces captures prouvent route et présence, pas la finesse de chaque articulation.

## Tests exécutés

| Test | Résultat | Portée / réserve |
|---|---|---|
| `enemy_unit_dismemberment_probe.gd -- --id=giant_standard` | PASS `12/10` | exact, zones, fatalités, vrais fragments |
| `enemy_unit_behavior_probe.gd -- --id=giant_standard` | PASS | far/close, 3 actions, cible perdue, sleep/wake, cleanup |
| `enemy_large_body_contract_probe.gd -- --id=giant_standard` | PASS | mode, récupération bornée, capsule primitive, cleanup |
| `giant_traversal_probe.gd` | PASS | sol, torse, tête réelle, top, seam, wall-run, crawl, dégâts |
| `enemy_full_roster_validation_probe.gd` | PASS `22/22` | famille, rig, anatomie, équipement, opener, navigation |
| `enemy_roster_audit.gd` | PASS `22/22` | standard `elite`, pattern `3/0`, 3 clés, package présent |
| `enemy_animation_probe.gd` | PASS `14/14` | opener exact et clip externe |
| `pose_integrity_probe.gd` | PASS | `giant_standard` sans incohérence de squelette |
| `enemy_animation_lod_probe.gd` | PASS | infrastructure native/shared/direct et réveil réversible |
| `enemy_combat_probe.gd` | PASS | patterns élites et invariants communs |
| `enemy_anatomy_regression_probe.gd` | PASS | section létale -> mort définitive |
| `enemy_transient_lifecycle_probe.gd` | PASS | ressources, TTL, collisions et ombres |
| `enemy_factory_options_probe.gd` | PASS | options géant conservées par l'adaptateur legacy |
| `enemy_factory_route_probe.gd` | PASS | construction runtime canonique |
| `world_editor_probe.gd` | PASS | document/Forge et propriétés géant sérialisées |
| `enemy_performance_benchmark.gd` | PASS structurel `1/28` idle/actif | p95 actif documenté |

Logs frais : `.tmp_tools/enemy_refactor/giant_standard/*.log`. Le bruit Windows `Failed to read the root certificate store` n'affecte aucun résultat. L'avertissement d'écriture `GORE HUD` survient dans les harnais qui chargent le Lab sous sandbox et ne touche ni construction, combat ni teardown du géant.

Tests non applicables : matrice Mixamo (le géant utilise `package_retarget`) et contrat phase 2 (le standard est déclaré monophasé).

## Revue Godot 4.7

### Critique

Aucune panne critique propre à `giant_standard` n'est reproduite.

### Améliorations / dette honnête

- Profiler le graphe non-masse complet et le rendu réel Lab/Forge avant toute revendication de gain ou suppression de donneur.
- Produire des LOD/une retopologie du package de 80,8 k triangles dans une passe asset séparée, avec validation des dix segments et dix-huit caps.
- Ajouter une épreuve obstacle/couloir/pente dédiée aux grands corps avant d'envisager un mode hybride au-delà de la récupération locale.
- Ajouter une preuve multi-frame rapprochée des trois attaques, de la frame de contact, du retour idle, du crawl et du réveil LOD exact de cet ID.
- Suivre l'avertissement ObjectDB du harnais `giant_traversal_probe`, même si les probes de lifecycle et de benchmark ne reproduisent aucune référence ennemie orpheline.
- Conserver le package visible, UAL1 et les assets d'animations externes tant qu'une alternative bake/retarget n'a pas la parité visuelle et fonctionnelle.

### Points solides

- Palier standard clairement distinct par statistiques, cadence et pattern.
- Factory unique; options Forge et seuil 28 préservés.
- `LARGE_BODY` explicite, sans agent navmesh inutile, avec récupération et reason code bornés.
- Traversée lisse séparée des hitboxes précis; vraie coque de tête et sommet unique.
- Crawl cohérent après deux sections de jambes et zones de dégâts encore atteignables.
- Anatomie intégrale, vrais fragments, mort et transients bornés.
- LOD réversible; aucun `AnimationTree` figé définitivement au réveil.

---

Revu contre les checklists Godot 4.3+ / 4.7 de navigation, animation, physique, assets, 3D, testing, debugging et code review.
