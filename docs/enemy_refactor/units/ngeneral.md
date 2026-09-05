# Audit unitaire — `ngeneral`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact, le probe de démembrement strict et le probe NavMesh réel passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par `REGRESSION_MATRIX.md`.

Statut final : **DONE**\
Date : 2026-08-26\
Famille : `hoplite_ngeneral`\
Routes prioritaires : Combat Lab, Battle 03 narrative, Forge

## Décision synthétique

`ngeneral` respecte le contrat fonctionnel de la mission : identité exacte, quatre attaques déclaratives parcourues, décision loin/proche, interruption par désarmement, perte de cible, sommeil/réveil, phalange stable puis dégradée, dory/aspis physiques, animation partagée sans donneur runtime, LOD réversible, anatomie `12/12` avec `10` sections, mort atomique et teardown sans survivant. Les preuves rendues ne montrent pas de T-pose grossière.

Le statut `DONE` ne vaut pas revendication de gain global de performance. La mesure finale garde un p95 cadencé autour de `20.70 ms` et un cleanup parfait, mais les temps de spawn et les instantanés diagnostiques restent des limites honnêtes. Le composant de navigation est désormais un service `RefCounted`; il n'ajoute plus un nœud par unité, ce que confirme la parité structurelle finale.

## Profil canonique et identité

Source de vérité : `scripts/enemy/enemy_archetypes.gd`, entrée `ngeneral`.

| Champ | Valeur |
|---|---:|
| nom / rang / famille | `LANCIER HOPLITE` / `troop` / `hoplite_ngeneral` |
| rôle / comportement | `phalanx_core` / `phalanx` |
| skin / échelle | `spearman` / `1.00` |
| PV / vitesse | `145` / `3.70 m/s` |
| dégâts / portée / aggro | `18` / `2.72 m` / `22 m` |
| arme / bouclier | dory `1.10` / aspis `1.12` |
| style | `spear_compact` |
| windup / recovery | `0.32 s` / `0.34 s` |
| cooldown | `1.05–1.38 s` |
| bande préférée | `1.58–2.58 m` |
| formation | `5` colonnes, espacement `1.08`, rang `1.18`, poursuite `7.5 m` |
| cohésion | rayon `4.4`, bonus garde vétéran `0.12` |
| garde | chance `0.62`, durée `0.82`, cooldown `1.30`, dégâts ×`0.14`, section ×`0.08` |
| endurance / régénération | `112` / `24` |
| poise | `0.28` |
| package gagnant | `ngeneral-1787351044165.glb` |

Le pattern exact contient quatre pas distincts : `hoplite_torso_thrust`, `hoplite_high_thrust`, `hoplite_low_thrust` et `hoplite_shield_push`. Le probe comportemental ne se contente pas de l'opener : il traverse le tableau complet par le scheduler réel, démarre puis résout chaque windup et vérifie que les quatre identifiants ont été observés.

## Factory, routes et lifecycle

`HopliteEnemyFactory.spawn_request()` reste l'entrée canonique. Le profil typé est appliqué avant la construction du package, de l'anatomie, de l'équipement et du composant de navigation; l'activation IA rejoint ensuite registre, foule et groupes de combat de façon cohérente.

- **Combat Lab** : `scripts/main.gd` place la famille dans la galerie et la patrouille de phalange; les captures galerie/portail montrent respectivement les lignes espacées et la formation dense réelle.
- **Battle 03 narrative** : `battle_03_narrative.gd` assemble deux cohortes séparées de douze unités. Le probe frais compte exactement `16 ngeneral + 8 ngeneral_veteran`, répartis `12/12` entre les deux groupes.
- **Forge** : le document `enemy_group` est matérialisé par le vrai `HopliteWorldRuntime`. La preuve Forge historique couvre un solo et une phalange mixte; le correctif de duel empêche le hoplite isolé de rester éternellement en rassemblement.
- **Preuve globale 22/22** : les captures Lab/Forge de roster complet utilisent la factory ou le vrai runtime. Elles prouvent l'instanciation et l'absence de T-pose grossière, pas la qualité fine du comportement individuel.

La perte de cible libère claim et lease. `set_ai_participation(false)` retire l'unité de `combatant_ai`, du registre et de la foule; le réveil restaure participation et pose. `_die()` exécute la même sortie atomique avant de neutraliser collisions, anatomie, équipement et animation. Les probes exact, mixte et benchmark finissent avec zéro combattant, zéro `WeakRef` ennemie et zéro orphelin.

## Phalange, cohorte, navigation et récupération

Mode exact : `NAVMESH_GROUND` lorsqu'une `NavigationRegion3D` compatible existe sur la route, sinon `FORMATION_LOCAL`. Sur NavMesh, un `NavigationAgent3D` enfant calcule le détour tandis que l'ancre de cohorte conserve l'orientation de formation; sans carte, le service `RefCounted` consomme directement l'ancre du `BattleCrowdDirector` et le `CharacterBody3D` applique l'intention avec `move_and_slide()`.

Le directeur conserve une cible stable par cohorte, calcule une seule formation par groupe et par révision, garde les slots stables, remplit les vacances et autorise une assemblée dégradée plutôt que de bloquer toute la ligne. Les états explicites couvrent duel, rassemblement, marche, garde, poussée, attaque, repli, réorganisation, rupture et arc d'expulsion. Les trois boucliers centraux de l'arc peuvent forcer `hoplite_shield_push` tout en restant soumis au scheduler FIFO partagé.

La récupération surveille la vitesse de progrès et déclenche une impulsion latérale bornée lorsque le corps ne progresse plus. Le probe composant couvre destination, ancre de formation, fallback et recovery; le probe cohorte couvre cible stable, vacance et assemblée dégradée. Le probe de foule couvre ring de contact, réserves, budget d'attaque et expulsion d'une intrusion. La grille spatiale est rafraîchie à `20 Hz` et invalidée immédiatement lors d'un changement de membres.

Limite honnête : `FORMATION_LOCAL` ne garantit pas un détour topologique autour d'obstacles complexes. Le pathfinding navmesh est validé transversalement sur les profils `NAVMESH_GROUND`, pas sur `ngeneral`; la cohorte repose ici sur la récupération locale voulue par son identité de phalange.

## Rig, bibliothèque partagée, animation et LOD

Inventaire du package canonique brut :

| Mesure | Valeur |
|---|---:|
| taille | `6 794 932` octets |
| générateur | `Khronos glTF Blender I/O v5.2.39` |
| nœuds / meshes / primitives | `83 / 28 / 28` |
| triangles source | `31 652` |
| matériaux / textures / images | `2 / 1 / 1` |
| skins / joints | `1 / 53` |
| animations locales | `0` |

L'import active tangentes, LOD automatiques, shadow meshes, skins nommés, lumière statique et bake animation à `30 FPS`. Le package visible reste le squelette canonique à 53 os. À l'exécution, `SharedHopliteAnimationDriver` crée un `AnimationPlayer` et un `AnimationTree` propres à l'instance mais attache la même ressource `hoplite_animation_library_v3.res` (`332 925` octets). Il n'instancie aucun UAL1, UAL2, FBX, pose bridge ou squelette donneur. Le probe structurel exige exactement un squelette, un lecteur et un arbre par hoplite.

La bibliothèque v3 partage `Idle`, `Jog_Fwd`, `Sprint`, `Death01` et les actions compatibles. Les actions de lance/bouclier sont des clips UAL2 déjà bakés sur le rig canonique, avec surcouche filtrée sur le haut du corps. La locomotion des tibias continue sous la garde; l'attaque de lance fait évoluer le haut du corps. Mesures fraîches du probe : mouvement `Sprint=2.2695 rad`, tibia en timeline `1.1484 rad`, tibia sous garde `1.3754 rad`, action `spear_thrust=1.6920 rad`.

LOD d'animation : évaluation normale proche, environ `30 Hz` au LOD1, `12 Hz` au LOD2 et pause au LOD3. Le réveil force un échantillon et réactive l'arbre; il n'existe donc pas de gel permanent par désactivation distante. Les soldats conservent leurs temps de lecture indépendants malgré la bibliothèque partagée.

La fusion runtime des dix zones corporelles produit un seul `ArrayMesh` skinné et une seule surface, partagé entre standard et vétéran. Les poids, le `Skin` à 53 binds, les indices LOD et l'identité anatomique sont préservés. Le source brut reste très au-dessus de l'objectif indicatif `12 k` triangles; aucun gain de triangles proche n'est revendiqué et aucun asset ne doit être supprimé ou décimé sans preuve comparative de skinning, silhouette, caps et section.

## Équipement, rendu et physique

`ngeneral` utilise les assets importés `dory_spear.glb` et `aspis_shield.glb`. Le probe exact vérifie dory sous la main droite, aspis sous la main gauche, volumes plausibles et `HopliteShieldHitbox` réellement enfant du bouclier. Un guardian non phalange ne reçoit pas ces assets, ce qui protège l'identité de famille.

Le corps principal est un `CharacterBody3D` à collider primitif; les zones anatomiques sont des `Area3D`. Membres et équipement détachés deviennent des `RigidBody3D` bornés dans le temps, avec sommeil autorisé, collision et ombres retirées avant libération. Le rayon monde du bouclier est calculé par le même contrat partagé et tient compte de l'échelle héritée; le probe de rayon exerce cette méthode sur un bouclier physiquement surdimensionné. Le cache de matériaux procéduraux passe transversalement, mais n'est pas présenté comme preuve propre aux surfaces importées de `ngeneral`.

Limites de validation : aucune mesure GPU/VRAM/draw calls n'a été prise par le benchmark headless; les captures ne prouvent pas non plus le passage dans des ouvertures étroites, des marches ou le comportement Jolt sous empilement extrême.

## Anatomie, démembrement et mort

Les douze zones requises sont présentes : tête, cou, torse, bassin, deux bras supérieurs, deux avant-bras, deux cuisses et deux tibias. Dix sont sectionnables; torse et bassin restent non sectionnables. Les sections du bras droit lâchent la dory, celles du bras gauche lâchent l'aspis; les jambes appliquent boiterie/crawl et la tête/cou sont fatals.

La branche fusionnée masque la zone par identifiant anatomique et produit un `SpartanDetachedLimb` avec la même surface fusionnée, au lieu de restaurer les dix meshes source. Le probe exact passe `zones=12 severed=10`, équipement, fatalités et teardown. À la mort, le driver/arbre est arrêté avant `Death01`, puis le cadavre devient render-only; aucune `AnimationTree` active ne continue de combattre la pose de mort.

## Performance — photographie finale post-revue

Commande autoritaire : `enemy_performance_benchmark.gd -- --counts=15,28,36 --mode=both --warmup=120 --frames=120 --archetype=ngeneral`. Godot 4.7 stable, `gl_compatibility`, seed `13371`; seuil de masse conservé à **28**.

| Mode | N | Spawn | Process* | Physics* | Nœuds | Objets | Mémoire statique | p95 cadencé | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 15 | `238.594 ms` | `1.224 ms` | `3.330 ms` | `1071` | `3099` | `58,251,003 B` | `20.729 ms` | PASS |
| idle | 28 | `306.989 ms` | `1.857 ms` | `4.603 ms` | `1994` | `4386` | `64,198,080 B` | `20.711 ms` | PASS |
| idle | 36 | `384.306 ms` | `2.533 ms` | `5.426 ms` | `2562` | `5178` | `67,798,668 B` | `20.706 ms` | PASS |
| actif | 15 | `151.965 ms` | `1.332 ms` | `6.217 ms` | `1071` | `3130` | `59,085,935 B` | `20.698 ms` | PASS |
| actif | 28 | `278.682 ms` | `2.404 ms` | `11.817 ms` | `1994` | `4443` | `64,861,308 B` | `20.708 ms` | PASS |
| actif | 36 | `381.639 ms` | `3.345 ms` | `13.463 ms` | `2562` | `5251` | `68,434,080 B` | `20.715 ms` | PASS |

\* `TIME_PROCESS`/`TIME_PHYSICS_PROCESS` sont des instantanés Godot à rafraîchissement lent; le p95 inclut le pacing Windows. La preuve robuste est structurelle : actif et idle gardent exactement `1071/1994/2562` nœuds, donc aucun nœud de navigation par acteur; tous les scénarios reviennent à zéro combattant/WeakRef. Il n'existe pas de baseline phase 0 unitaire strictement comparable pour les nouveaux chemins NavMesh, donc aucun pourcentage CPU propre à `ngeneral` n'est inventé.

## Preuves visuelles inspectées

- `visual_evidence/ngeneral.png` : treize états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`); silhouette, dory et aspis lisibles, pose d'attaque distincte, aucune T-pose grossière.
- `hoplite_combat_lab_gallery_probe.png` : ligne de sept hoplites dans la vraie galerie, espacements et équipements visibles.
- `hoplite_combat_lab_portal_probe.png` : patrouille dense de quinze, rangs et mélange standard/vétéran visibles; chevauchement visuel important au portail.
- `forge_hoplite_animation_probe.png` : solo et phalange créés par le vrai runtime; cadrage distant et exposition forte, donc preuve de présence plutôt que preuve de détail.
- `lab_full_roster_visual_probe.png` et `forge_full_roster_visual_probe.png` : présence `22/22`, tailles cohérentes et absence de T-pose grossière. Les personnages et labels sont trop petits pour valider mains, caps ou timing.

Réserves de qualité : la planche unitaire est une juxtaposition d'instances, pas une séquence temporelle; le membre sectionné est projeté très loin à droite et la mort est très dynamique. Le gros plan `hoplite_visual_pose_probe.png` est sombre et ne remplace pas les mesures de mouvement du squelette. Les preuves fonctionnelles complètent donc les captures, sans leur faire dire davantage.

## Tests frais exécutés

| Probe | Résultat | Portée |
|---|---|---|
| `enemy_unit_dismemberment_probe --id=ngeneral` | PASS `12/10` | exact, sections, fatalités, équipement, teardown |
| `enemy_unit_behavior_probe --id=ngeneral` | PASS | loin/proche, 4 attaques, désarmement, cible, sommeil/réveil, cleanup |
| `enemy_full_roster_validation_probe` | PASS `22/22` | ligne exacte : shared library, `12/12`, spear+shield, pattern, `FORMATION_LOCAL` |
| `phalanx_equipment_probe` | PASS | dory/aspis importés, mains et hitbox physique |
| `hoplite_phalanx_optimization_probe` | PASS | rig/bibliothèque partagés, un arbre par instance, corps fusionné, formation, anatomie, ombres |
| `hoplite_cohort_recovery_probe` | PASS | cible stable, vacance, assemblée dégradée |
| `crowd_tactics_probe` | PASS | contact, réserves, scheduler, arc d'expulsion |
| `crowd_spatial_cadence_probe` | PASS | snapshot initial, 20 Hz, invalidation membres |
| `enemy_registry_crowd_parity_probe` | PASS | parité groupes/registre initiale et dynamique |
| `hoplite_animation_rig_audit` | PASS diagnostic | rig canonique 53 os et sources inventoriées |
| `enemy_animation_probe` | PASS | opener exact `external:spear_thrust` |
| `enemy_animation_lod_probe` | PASS | cadences shared/native/direct et réveil réversible |
| `enemy_transient_lifecycle_probe` | PASS | ressources partagées, TTL, retrait collisions/ombres |
| `enemy_shield_world_radius_probe` | PASS transversal | méthode de rayon monde sous échelle héritée |
| `enemy_material_cache_probe` | PASS transversal | cache immuable des matériaux procéduraux |
| `narrative_battle_probe` | PASS | vraie Battle 03, deux cohortes `12/12`, composition exacte |
| `enemy_mixed_stress_probe` | PASS `22 familles / 36 unités` | seuil 28, deux cohortes, cible mobile/changée, wake, sections, morts, cleanup |
| benchmark `15/28/36`, idle/actif | PASS structurel | comparaison ci-dessus; aucun gain global revendiqué |

Journaux frais : `.tmp_tools/enemy_refactor/ngeneral_audit/`. Le bruit Windows `Failed to read the root certificate store` et les avertissements de création `user://.tmp_tools` n'altèrent pas les sorties PASS. `narrative_battle_probe` signale à la fermeture deux objets et une ressource encore référencés après avoir quitté tôt la scène complète; les probes exacts, stress et benchmark dédiés passent tous leur teardown. Cette divergence de harness reste documentée et ne constitue pas une fuite reproduite de `ngeneral`.

## Critères de sortie et backlog

**DONE** pour le contrat unitaire fonctionnel, architectural, visuel minimal, anatomique et lifecycle. Aucun asset ou donneur n'a été supprimé pendant cet audit.

Backlog explicite :

- profiler le coût actif NavigationServer/formation avec une région CPU non cadencée et en scène réelle;
- produire des métriques GPU, VRAM et draw calls en Compatibility;
- étudier un LOD géométrique proche sous `12 k` triangles sans casser weights, silhouette, caps, shader de zones ni membre détaché;
- améliorer le cadrage/exposition Forge et la composition du membre sectionné;
- ne remplacer les actions UAL2 visuellement sûres par les clips Mixamo historiques qu'après un bake retargeté et une preuve visuelle comparative complète.
