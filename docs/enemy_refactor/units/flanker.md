# `flanker` — audit final individuel

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Archetype exact :** `flanker`\
**Famille candidate :** `legacy_standard`\
**Moteur / renderer observés :** Godot `4.7.stable.official.5b4e0cb0f`, `gl_compatibility`\
**Portée de cette passe :** audit, inspection visuelle et validation en lecture seule du runtime central. Aucun script, scène, profil, asset ou donneur partagé n'a été modifié; aucun donneur n'a été retiré.

## Verdict exécutif

Le `flanker` est constructible, identifiable et jouable par le contrat commun intégré. La factory canonique lui applique le bon profil; son comportement d'orbite rapide, sa cible, sa faction, son arme, sa mort atomique, son teardown et ses 12 zones anatomiques sont câblés. Les probes ciblé et full roster sont verts. La planche Compatibility existante montre six états distincts sans pose en T évidente. Un benchmark frais en `mass_battle_mode` passe en solo et à 12 unités avec teardown structurel propre.

La réévaluation après intégration conclut **DONE**. Les probes navigation composant et navmesh, LOD animation, stress mixte et équipement authored ont été relancés avec code `0`. Le stress commun instancie les 22 IDs canoniques, donc au moins un `flanker`, dans une foule de 36 unités; il couvre le seuil masse `28`, deux cohortes, une cible mobile puis changée, le sommeil/réveil atomique, quatre sections, quatre morts et le cleanup. La mort appelle désormais `set_ai_participation(false)` et sort atomiquement des groupes, du registry, de la navigation et du scheduler.

Aucune panne fonctionnelle reproductible locale au `flanker` ne demeure. Les absences de baseline historique exacte, de capture visuelle exhaustive par variante et de métriques GPU restent des limites d'observabilité et un backlog futur, pas des raisons de bloquer cet archétype. `combat_lab` et la Forge ne sont pas des routes primaires déclarées pour cet ID : elles sont `N/A`, sans preuve inventée. Le pool conserve ses trois donneurs/GLB puisque leur retrait n'est pas justifié.

## Preuves primaires

| Preuve | Résultat et portée |
|---|---|
| `.tmp_tools/enemy_refactor/flanker_dismemberment_final_abs.log` | `ENEMY_UNIT_DISMEMBERMENT_PROBE PASS id=flanker zones=12 severed=10`, code `0`; un ennemi distinct est instancié et nettoyé par zone |
| `.tmp_tools/enemy_refactor/flanker_full_roster_final_abs.log` | ligne exacte `flanker`: famille `legacy_standard`, rig `direct_mixamo`, anatomie `12/12`, équipement `sword`, action `static`, navigation `DIRECT_STEERING`; fin `PASS: 22/22` |
| `.tmp_tools/enemy_refactor/logs/visual_flanker.log` | rendu Compatibility réel, six acteurs, image `1351 × 760`, PASS |
| `docs/enemy_refactor/visual_evidence/flanker.png` | inspection directe de la planche Idle nu / Jog nu / attaque / impact / mort / section |
| `.tmp_tools/enemy_refactor/flanker_benchmark_1_12_both.log` | quatre scénarios `1/12 × idle/active`, statut PASS, cleanup structurel vrai |
| `.tmp_tools/enemy_refactor/flanker_factory_route_final.log` | toutes les constructions runtime connues passent par la factory canonique |
| `.tmp_tools/enemy_refactor/flanker_faction_targeting_shared.log` | groupes, priorité de cible, claims, représailles, friendly fire et nettoyage partagés : PASS |
| `.tmp_tools/enemy_refactor/flanker_navigation_component_shared.log` | intent, formation, fallback et récupération du composant : PASS; probe partagé, pas trajectoire flanker dédiée |
| `.tmp_tools/enemy_refactor/flanker_attack_scheduler_shared.log` | capacité, FIFO et leases autoritaires : PASS; ordonnanceur partagé, pas distribution statistique flanker dédiée |
| `.tmp_tools/enemy_refactor/flanker_action_state_shared.log` | priorité garde/récupération/wind-up/parade/tactique : PASS |
| `.tmp_tools/enemy_refactor/flanker_animation_lod_shared.log` | cadence réelle et réveil réversible, dont route `direct_mixamo` : PASS sur un guardian représentant le même chemin de code |
| `.tmp_tools/enemy_refactor/flanker_anatomy_shared.log` | section fatale finalise toujours la mort : PASS |
| `.tmp_tools/enemy_refactor/flanker_transient_lifecycle_shared.log` | ressources partagées, TTL borné, retrait collision/ombres : PASS |
| `.tmp_tools/enemy_refactor/flanker_registry_shared.log` | enregistrement, filtres, ordre, liveness et weak teardown : PASS |
| `.tmp_tools/enemy_refactor/flanker_patrol_shared.log` | route de patrouille commune : PASS; le manifest ne déclare pas de patrouille flanker dédiée |
| `.tmp_tools/enemy_refactor/flanker_battle_spawn_shared.log` | contrats de spawn hostile et allié partagés : PASS |
| `.tmp_tools/enemy_refactor/flanker_battle01_startup_fresh.log` | Battle 01 démarre 120 frames et sort `0`; les tableaux source contiennent explicitement `flanker` |
| `.tmp_tools/enemy_refactor/flanker_battle02_startup_fresh.log` | Battle 02 démarre 120 frames et sort `0`; les tableaux source contiennent explicitement `flanker` |
| `.tmp_tools/enemy_refactor/flanker_reeval_navigation_component.log` | rerun frais : intent, formation, fallback et récupération PASS; la clé intégrée `minimum_progress_speed` est celle lue par le composant |
| `.tmp_tools/enemy_refactor/flanker_reeval_navigation_navmesh.log` | rerun frais : vrai chemin, détour, retarget, arrivée et fallback carte vide PASS; preuve de composant partagée, le `flanker` reste en steering direct |
| `.tmp_tools/enemy_refactor/flanker_reeval_animation_lod.log` | rerun frais : cadence shared/native/direct et réveil réversible PASS; la route direct Mixamo teste `12 Hz`, `0 Hz` et l'échantillon de réveil |
| `.tmp_tools/enemy_refactor/flanker_reeval_mixed_stress.log` | rerun frais : PASS 22 familles/36 unités, seuil 28, deux cohortes, cible mobile/changée, wake, 4 sections, 4 morts et cleanup |
| `.tmp_tools/enemy_refactor/flanker_reeval_authored_equipment.log` | rerun frais : équipements authored knight3, masquage et remplacements détachés PASS; preuve transversale, distincte de l'épée procédurale flanker déjà couverte par son probe ciblé |
| `.tmp_tools/enemy_refactor/flanker_reeval_dismemberment.log` | rerun exact post-intégration : `PASS id=flanker zones=12 severed=10` |
| `.tmp_tools/enemy_refactor/flanker_reeval_full_roster.log` | rerun post-intégration : ligne exacte flanker inchangée et `PASS: 22/22`, teardown inclus |

Le bruit Windows `Failed to read the root certificate store` apparaît avant plusieurs PASS. Les deux démarrages Battle signalent aussi que le Gore HUD ne peut pas sauvegarder ses réglages dans l'environnement headless. Battle 02 a affiché au terminal, après l'arrêt forcé à 120 frames, `2 ObjectDB instances` et `1 resource still in use`; le log se ferme avant ces lignes. Ce run court ne prouve donc pas le teardown complet de Battle 02. Le défaut ressemble à la dette audio/processus déjà documentée dans `CURRENT_STATE.md`, mais son origine n'est pas attribuable au `flanker` avec les données présentes.

## Construction, profil et routes

### Factory et source de vérité

- `scripts/enemy/enemy_factory.gd` est le point de construction unique. `spawn()` convertit l'adaptateur dictionnaire en `EnemySpawnRequest`; `spawn_request()` crée `HopliteAthenianEnemy`, injecte ID, position, cible, faction, mode masse, index et registry avant `add_child()`.
- `scripts/enemy/athenian_enemy.gd` applique le profil dans `_ready()` avant collider, mannequin, anatomie et navigation. Le corps n'est donc pas initialisé avec les valeurs par défaut du swordsman.
- `scripts/enemy/enemy_archetypes.gd` conserve un template unique puis retourne une copie profonde. `EnemyArchetypeData` met en cache une vue typée sans autoriser la mutation du template partagé.
- `flanker` est un ID canonique de `all_ids()`, mais n'appartient pas à `ROSTER_IDS`; il n'est donc pas proposé par `procedural_catalog()`. Aucun spawn procédural moderne n'est revendiqué.
- Le champ de famille `legacy_standard` appartient au manifest/probe. Il ne crée ni seconde classe runtime ni héritage spécifique.

### Profil final

| Propriété | Valeur |
|---|---:|
| nom / skin | `FLANKER` / `flanker` |
| rang | `troop` implicite |
| faction par défaut | `athenian` |
| scale racine | `0,96` |
| points de vie | `80` |
| vitesse | `6,15 m/s` |
| accélération commune | `18 m/s²` |
| dégâts | `12` |
| portée d'attaque | `1,58 m` |
| aggro | `23 m` |
| arme / scale | `sword` / `0,88` |
| bouclier / défense | `false` / `none` |
| comportement | `flank` |
| style | `fast` |
| wind-up / récupération | `0,18 s / 0,18 s` |
| cooldown | `0,66–0,90 s` |
| vitesse d'animation d'attaque | `1,36` |
| bande préférée | `0–1,48 m` |
| rayon d'orbite déclaré | `2,25 m` |
| séparation / approche | `1,0 / 1,0` par défaut |

Aucune duplication contradictoire du profil exact n'a été trouvée. `nsbire2` emploie aussi `skin=&"flanker"`, mais garde son propre ID, profil, package, arme et comportement; il ne constitue pas une seconde définition du `flanker`.

### Routes réellement constatées

**Battle 01.** Route primaire prouvée par le manifest et le code : `flanker` apparaît dans les trois escouades externes, la ligne frontale, les rencontres urbaines A/B/C et la garde finale. Les spawns passent par `EnemySpawnRequest` puis `EnemyFactory.spawn_request()`. Les troupes de la grande bataille sont souvent en `mass_battle_mode`; certaines rencontres urbaines et la garde finale ne le sont pas. Le démarrage frais sort `0`, mais le journal ne trace pas l'ID de chaque instance et ne remplace pas un scénario de combat flanker instrumenté.

**Battle 02.** Route primaire prouvée par le manifest et le code : présence dans les quatre cohortes externes, la ligne frontale et les rencontres urbaines. Les flanquants y sont fréquemment en mode masse. Le démarrage frais sort `0`; l'arrêt forcé révèle toutefois le bruit de teardown global indiqué plus haut.

**Combat Lab.** `combat_lab.tscn` est la scène principale du projet, mais ni le manifest ni une recherche de route ne déclarent `flanker` dans le showroom/roster moderne du Lab. La capture `enemy_unit_visual_evidence.gd` est une scène minimale dédiée et ne doit pas être appelée « preuve Combat Lab ».

**Forge.** `world_runtime.gd` accepte de manière générique une propriété `archetype` et la transmet à la factory. Aucun document Forge, manifest ou probe ne prouve cependant une entité `flanker`. Cette capacité générique n'est pas une route flanker existante. Aucun résultat Forge individuel n'est revendiqué.

## Faction, cible, activation et cycle de vie

### Faction et groupes

- Par défaut la factory fournit `faction=&"athenian"`; le flanker entre dans `enemy`, `athenian`, `damageable`, `combatant`, puis `combatant_ai` et `enemy_ai` si l'IA est active.
- La factory peut techniquement injecter `spartan`, auquel cas les groupes deviennent `ally`, `spartan_ally` et `ally_ai`. Les Battles 01/02 ne déclarent pas de flanker spartiate : cette capacité commune n'est pas une route produit prouvée.
- La couche du corps est `4`; le masque mobile est monde `1` + joueur `2`. Les ennemis ne se collisionnent pas physiquement entre eux; l'espacement dépend du steering/crowd grid.

### Choix de cible

- Un ennemi athénien privilégie une représaille active, puis le joueur dans la bulle d'aggro avec hystérésis de `15 %`, puis un allié spartiate valide en minimisant distance + pénalité de claims.
- Une cible morte/invalide est refusée. Le changement de cible libère le lease d'attaque et l'engagement précédent, décrémente ses claims, puis incrémente ceux de la nouvelle cible.
- La représaille dure `3,6 s` et accepte uniquement une source hostile. Le probe partagé valide priorité, claims, représailles et friendly fire. Le stress mixte contient le `flanker` dans le roster canonique et valide, au niveau du contrat commun utilisé par cet ID, une cible mobile et un changement autoritaire de cible dans la même foule.

### Activation et réveil

- `ai_enabled=false` évite les groupes/processus IA; `set_ai_participation(false)` libère cible et lease, annule l'attaque, remet la vélocité plane à zéro et efface destination/caches.
- `configure_training_activation()` peut mettre une unité en `training_wait`; le contrôle est cadencé à environ `0,18–0,23 s`. À l'entrée dans le rayon, les caches sont invalidés, un cooldown de réveil est posé et l'état devient `training_awaken`.
- Le `flanker` n'a pas de route Forge/Lab déclarée utilisant cette activation; seule la mécanique partagée est caractérisée.
- Le stress mixte confirme que `set_ai_participation(false)` retire atomiquement une unité des vues registry/crowd et que `true` la réinscrit; le `flanker` est présent dans cette population canonique de 22 IDs.

### Mort et teardown

- `_die()` libère lease et cible, pose `dead`, appelle `set_ai_participation(false)`, annule l'attaque, retire couches/masques, désactive capsule, colliders spéciaux et anatomie, puis coupe `_physics_process()`. Cette sortie est atomique pour les groupes IA, la registry, la destination de navigation et le scheduler.
- L'épée est libérée en `RigidBody3D`; les flancs sans bouclier ne créent aucun faux bouclier. L'arme garde une phase physique de `4 s`, perd collisions et ombres, puis expire à `12 s`.
- Le `AnimationPlayer` Mixamo est stoppé avant le fallback de chute afin d'éviter un cadavre qui continue son attaque. Après la pose de mort, particules et ombres sont retirées puis `_process()` est coupé.
- `_exit_tree()` relibère défensivement lease et cible même si la scène retire une unité encore vivante.
- Le full roster vérifie un `WeakRef` nul et un stage revenu à sa seule cible après `queue_free()`. Le benchmark vérifie zéro référence ennemie vivante, zéro combatant résiduel et zéro registry résiduelle dans ses quatre scénarios.
- Le stress mixte tue successivement quatre unités au sein d'une foule encore active et vérifie `dead`, `ai_enabled=false`, absence de destination, diminution du registry et du groupe `combatant_ai`, puis zéro référence vivante au teardown.
- Ces preuves couvrent le teardown de l'instance/stage, pas une absence absolue de fuite de ressource process-wide.

## Décision et combat, solo et groupe

### Identité tactique

Le `flanker` garde une identité distincte. Tant que la cible est plus loin que `1,58 × 0,92 = 1,454 m`, il vise `_orbit_position()` à un rayon minimum de `2,25 m` avec un facteur latéral `0,62`; son état est `flank`. À l'intérieur de cette distance, il tient sa position et passe `flank_attack`. `_can_start_attack_at_distance()` interdit encore le départ au-delà de `1,58 × 0,98 = 1,548 m`.

Le mouvement est rapide (`6,15 m/s`) et aucune valeur de vitesse/timing n'a été changée pendant cet audit. L'identité agressive et latérale est donc conservée sur le papier et visible dans le code, mais aucune trajectoire chronométrée ne mesure le rayon/angle réel sous collisions et séparation.

### Attaque

- Le profil n'a pas de `combat_pattern`; le full roster étiquette correctement son contrat `static`. Cela signifie « paramètres statiques », pas « unité qui n'attaque pas ».
- `attack_style=fast` choisit un slot léger, puis la route Mixamo joue une attaque parmi `flying_knee`, `axe_kick` et `mutant_swipe`.
- Le contact mécanique est piloté par le timer de wind-up, pas par un marker ou une Call Method track. À résolution, le lease est revalidé, puis portée et arc frontal (`dot >= 0,10`) sont vérifiés avant l'application des `12` dégâts.
- L'animation d'attaque est ajustée vers une durée dérivée de wind-up + récupération + `0,58 s`; elle n'est pas l'horloge autoritaire du hit.
- La planche montre une pose d'attaque lisible, mais le probe visuel coupe la physique immédiatement après `_begin_ai_attack()`. Il ne prouve donc ni hit, ni exactitude de frame, ni recovery.
- Les trois clips sont acrobatiques/axe/mutant alors que l'équipement est une épée. Ils donnent une gestuelle vive compatible avec le rôle, mais la cohérence fine lame-contact n'est pas prouvée en gros plan.

### Solo et groupe

- Sans crowd director, l'attaque est autorisée localement. Avec director, le flanker demande un lease; la capacité commune vaut `3` et la FIFO évite qu'un combattant continuellement éligible soit oublié.
- Un lease expiré est revalidé avant le hit. Refus ou expiration place l'unité en `pressure_wait`; mort, retrait, changement de cible, désarmement et fin de récupération libèrent la permission.
- Le crowd director fournit des slots d'engagement persistants; huit combattants occupent le premier anneau puis les autres attendent sur des anneaux plus larges. La séparation utilise la grille spatiale plutôt que des collisions alliées.
- `ATTACK_SCHEDULER_PROBE` prouve la capacité/FIFO/autorité en isolation, le benchmark fait tourner 12 flankers actifs et le stress mixte place le `flanker` parmi 36 unités, avec deux cohortes, cible mobile/changée et grille spatiale restant sous le seuil de rebuild. Ensemble, ces preuves ferment le contrat fonctionnel solo/groupe partagé. Elles ne constituent pas une mesure cinématique du rayon d'orbite ni une statistique de répartition des hits; ces raffinements restent du backlog d'observabilité.

### Blessures et désarmement

- Perdre le bras ou l'avant-bras droit fait tomber l'épée; `_can_ai_attack()` devient faux et une attaque pending est annulée.
- Une jambe perdue limite la vitesse à `1,85 m/s`; deux jambes à `0,72 m/s`, abaissent/inclinent le visuel et réduisent la capsule.
- Une perte du bras gauche n'entraîne aucun équipement puisque le profil n'a pas de bouclier. Elle conserve cependant la conséquence anatomique et le proxy détaché.

## Navigation et mouvement

### Mode exact

Le mode validé pour `flanker` est `HopliteEnemyNavigationComponent.Mode.DIRECT_STEERING`. Aucun `NavigationAgent3D`, navmesh, layer de navigation, RVO ou signal `velocity_computed` n'est créé dans ce mode. Cela est cohérent avec le design actuel des Battles 01/02, mais ne constitue pas du pathfinding.

Le composant ne déplace jamais le corps. Il fournit direction, facing, speed scale et statut; `AthenianEnemy` reste l'unique propriétaire de `velocity`, applique séparément la gravité `24 m/s²`, accélère à `18 m/s²`, appelle `move_and_slide()`, puis notifie le progrès réellement obtenu.

### Destination, arrivée, blocage et récupération

- arrivée à `0,28 m` avec signal `destination_reached` une fois par révision ;
- une mise à jour de cible inférieure à `3 m` change la destination exacte sans réinitialiser la révision/récupération ;
- décision tactique cadencée à `0,045/0,085 s` hors masse selon distance, puis `0,055/0,10/0,18 s` en masse ;
- blocage déclaré après `0,82 s` sans progrès suffisant ;
- récupération latérale alternée pendant `0,48 s` à `72 %` de la vitesse ;
- échec `recovery_exhausted` après trois tentatives par défaut ;
- patrouille commune : prochain point à moins de `0,85 m`, puis reprise au point le plus proche après interruption.

### Limites et validation intégrée

- Le steering direct ne contourne pas un mur, une porte fermée ou un grand obstacle. La récupération latérale peut dégager un contact local, pas calculer un chemin alternatif.
- Le composant sait émettre `navigation_failed`, mais les Battles ne démontrent pas une réponse tactique spécifique du flanker après `recovery_exhausted`.
- Le réglage transmis est désormais `minimum_progress_speed=0.12`, exactement la clé lue par `notify_motion_applied()`. Le rerun du composant valide récupération et progression lente; le probe navmesh valide en plus vrai détour, retarget, arrivée et fallback stable. L'ancien défaut de nom de clé est donc retiré.
- Aucun throttling `NavigationAgent.target_position` n'est pertinent en `DIRECT_STEERING`, puisqu'il n'existe pas d'agent.
- `reset_physics_interpolation()` n'est pas appelé au spawn/téléport; `project.godot` n'active pas explicitement l'interpolation, ce qui réduit l'impact actuel mais laisse le contrat non explicite.

## Rig, animations, donneurs et LOD

### Pool de corps

Le `flanker` n'a pas un package unique. `MixamoCatalog.appearance()` choisit selon `guard_index`, instance et mode masse :

| Modèle | Pool | GLB | Nœuds JSON | Meshes / surfaces | Triangles LOD0* | Matériaux | Skins / joints |
|---|---|---:|---:|---:|---:|---:|---:|
| `smallsbir4` | normal + masse | 2 977 500 o | 72 | `2 / 2` | `13 280` | 2 | `2 × 69` |
| `kamikaze1` | normal + masse | 2 302 920 o | 67 | `1 / 2` | `12 380` | 2 | `1 × 65` |
| `smallsbir1` | normal seulement | 2 036 892 o | 101 | `1 / 2` | `15 022` | 2 | `1 × 99` |

\* Somme des accessors d'indices GLB divisée par trois; elle n'inclut pas l'épée procédurale, les proxies, les shadow meshes ni les LOD générés par Godot.

Les trois rigs partagent le noyau Mixamo (`Hips`, `Spine`, `Spine1/2`, `Neck`, `Head`, épaules, bras, avant-bras, mains, cuisses, jambes, pieds). Les comptes de joints différents prouvent cependant que la compatibilité familiale complète ne doit pas être supposée. `smallsbir4` contient en outre deux skins de 69 joints. Le full roster confirme un squelette non vide, un player animé et les deux mains sur l'instance choisie, mais ne compte pas tous les `Skeleton3D` runtime de chaque variante.

### Route d'animation

- Le modèle choisi est instancié directement; `_find_skeleton()` et `_find_best_animation_player()` sélectionnent le rig/player du mannequin.
- Les `AnimationTree` importés sont désactivés. Il n'existe pas d'`ai_animation_driver`, de retargeter ou de squelette proxy persistant sur cette route.
- `install_personality()` crée une `AnimationLibrary` locale sur chaque `AnimationPlayer`, mais les objets `Animation` dupliqués sont mis en cache statiquement et partagés entre instances.
- Les scènes FBX sources sont chargées une fois par clip, instanciées temporairement pour extraire l'animation, puis libérées immédiatement. Ce ne sont pas des donneurs invisibles persistants dans la scène.
- Clips demandés : `axe_block_idle` (idle), `run` (locomotion), `hit_react`, `battlecry`, puis `flying_knee`, `axe_kick`, `mutant_swipe`. Imports à `30 FPS`, trimming actif et pistes immuables supprimées. Les pistes de translation des hips sont retirées afin que le CharacterBody reste autoritaire.
- Aucun donneur n'a été retiré : les FBX sources restent nécessaires au cache et aucune bibliothèque canonique flanker versionnée ne les remplace.

### LOD et sommeil animation

- seuils par défaut : proche `16 m`, loin `38 m`, cull `90 m` ; `lod_bias` `1,0 / 0,55 / 0,22` ; culling avec marge `3 m` et sans fade transparent, compatible avec le renderer Compatibility ;
- ombres conservées seulement au LOD0 normal; coupées en masse et à distance ;
- le player direct passe en sampling manuel à distance : environ `30 Hz` au LOD1, `12 Hz` au LOD2, `0 Hz` au LOD3 ;
- le réveil LOD0 restaure le callback idle, appelle `advance(0.0)` et force un échantillon ;
- le rerun du probe LOD valide effectivement cette route de code sur `guardian`, autre utilisateur direct Mixamo : quatre pas à 60 Hz sans échantillon puis le cinquième à LOD2 (`12 Hz`), aucun échantillon à LOD3 (`0 Hz`), retour au callback idle et échantillon forcé au réveil. Le `flanker` emprunte la même branche `uses_mixamo_visual` sans driver natif; la planche ne montre simplement pas proche-lointain-proche.

## Meshes, matériaux, rendu et ombres

- Les trois GLB utilisent deux surfaces/matériaux chacun. Les matériaux ont une texture albedo; le matériau principal fournit une normal map. Aucun ne fournit de texture ORM/occlusion.
- `kamikaze1` et `smallsbir1` ont une deuxième matière `alphaMode=BLEND`; `smallsbir4` reste opaque. L'alpha blend ajoute tri/overdraw potentiel et mérite une mesure GPU, surtout dans les groupes non-masse mélangeant trois modèles.
- Les imports activent tangentes, LOD automatiques, shadow meshes, named skins et animation. Aucun nombre de triangles des LOD générés n'est exposé par les probes actuels.
- Les modèles sont entre `12,4 k` et `15,0 k` triangles au LOD0. Conformément à la mission, aucun remplacement automatique par un modèle « 12k » et aucune fusion hasardeuse n'est proposé.
- Une fusion des variantes serait dangereuse sans preuve de skin et de zone : topologies, skins et joints diffèrent; le démembrement actuel masque une chaîne d'os et crée un proxy procédural. Les meshes sources sont conservés.
- Le corps proche normal conserve ses ombres; toute géométrie les perd en mode masse ou dès LOD1. Les cadavres retirent définitivement leurs ombres après stabilisation.
- La planche Compatibility montre une silhouette lisible, des matériaux correctement éclairés et des ombres au sol. Elle n'est ni un compteur de draw calls ni une preuve de VRAM.

## Physique

- Corps mobile : `CharacterBody3D` + `CapsuleShape3D`, rayon local `0,39`, hauteur `1,82`, centre Y `0,91`.
- Aucune forme concave n'est utilisée sur le corps mobile. Les volumes anatomiques sont sphère/capsules dans une `Area3D` monitorable; ils ne produisent pas de réponse physique.
- Couches : corps `4`, masque monde/joueur `1|2`; anatomie `8` sans masque; débris `16` contre monde `1`. Les alliés ne se heurtent pas physiquement.
- Épée détachée : `RigidBody3D` + `BoxShape3D(0,10 × 1,15 × 0,08)`, sommeil autorisé, impulsion centrale bornée, collision active `4 s`, vie `12 s`.
- Membres détachés : `RigidBody3D` avec sphère tête ou capsule membre, sommeil autorisé, collision active `4 s`, vie `14 s`, meshes et matériaux mis en cache.
- La racine entière porte un scale uniforme `0,96`; la capsule et l'anatomie héritent donc d'un scale de parent même si leur `CollisionShape3D.scale` local reste `Vector3.ONE`. Cela s'écarte de la recommandation Godot de dimensionner directement les shapes. Aucun défaut observé ne lui est attribué dans les probes.
- `project.godot` ne verrouille ni moteur 3D ni interpolation. L'exécution est Godot 4.7, mais le dépôt ne prouve pas explicitement Jolt ou physics interpolation.

## Anatomie et démembrement — 12 zones

Le profil commun construit une seule `Area3D` avec 12 primitives. Le probe ciblé parcourt les zones une par une, sur une instance neuve, force un sever hit, contrôle dommage/section/fatalité/détachement/équipement, puis vide le stage avant la zone suivante.

| Zone | Forme / rayon local | Dégâts × | Sever × / seuil | Résultat testé | Conséquence flanker |
|---|---|---:|---:|---|---|
| `head` | sphère `0,25` | `1,70` | `1,00 / 64` | section | fatale, tête proxy détachée |
| `neck` | capsule `0,15` | `1,85` | `1,35 / 56` | section vers `head` | fatale, tête proxy détachée |
| `torso` | capsule `0,34` | `1,00` | `0,35 / 9999` | non sectionnable | dommage localisé, survie au chip du probe |
| `pelvis` | capsule `0,30` | `0,95` | `0,30 / 9999` | non sectionnable | dommage localisé, survie au chip du probe |
| `upper_arm_l` | capsule `0,16` | `0,78` | `1,00 / 78` | section | désactive aussi `forearm_l`; aucun bouclier à perdre |
| `forearm_l` | capsule `0,14` | `0,75` | `1,10 / 60` | section | membre proxy; aucun équipement gauche |
| `upper_arm_r` | capsule `0,16` | `0,78` | `1,00 / 78` | section | désactive `forearm_r`, lâche l'épée, désarme |
| `forearm_r` | capsule `0,14` | `0,75` | `1,10 / 60` | section | lâche l'épée, désarme |
| `thigh_l` | capsule `0,21` | `0,88` | `0,82 / 94` | section | désactive `shin_l`, vitesse limp/crawl |
| `shin_l` | capsule `0,18` | `0,84` | `1,05 / 72` | section | vitesse limp/crawl |
| `thigh_r` | capsule `0,21` | `0,88` | `0,82 / 94` | section | désactive `shin_r`, vitesse limp/crawl |
| `shin_r` | capsule `0,18` | `0,84` | `1,05 / 72` | section | vitesse limp/crawl |

Résultat agrégé : `12/12` zones endommagées, `10/12` sections, `2/12` non sectionnables conformes. La perte de tête/cou tue; une section de membre seule ne tue pas. Sur les rigs monoblocs, la chaîne d'os est réduite à `0,001` et le morceau détaché est un proxy procédural, pas la géométrie skinnée originale. La planche prouve visuellement une section du bras droit et une libération, mais pas la fidélité rapprochée des dix proxies sur les trois variantes.

## Performance ciblée

Commande :

```powershell
& 'C:\Users\suean\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path . --log-file 'C:\Users\suean\Downloads\hoplite_ual_native_lab_v2\.tmp_tools\enemy_refactor\flanker_benchmark_1_12_both.log' --script res://tools/enemy_performance_benchmark.gd -- --archetype=flanker --counts=1,12 --mode=both --warmup=90 --frames=120 --seed=13371
```

Le harness force `mass_battle_mode=true`, même pour une unité. Les snapshots `FPS/process/physics` sont à rafraîchissement lent et diagnostiques; les valeurs les plus solides sont spawn, compteurs structurels, mémoire au scénario et teardown.

| Mode | Nombre | Spawn ms | Process ms* | Physics ms* | Nœuds | Objets | Mémoire statique | Corps actifs | Tick p95 ms | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 1 | `312,928` | `0,325` | `0,364` | 31 | 1 624 | 85 892 701 | 0 | `20,705` | PASS |
| idle | 12 | `807,684` | `1,334` | `1,717` | 308 | 2 138 | 139 816 801 | 0 | `20,706` | PASS |
| active | 1 | `394,423` | `0,388` | `0,920` | 33 | 1 632 | 85 096 017 | 1 | `20,703` | PASS |
| active | 12 | `900,348` | `1,859` | `4,270` | 327 | 2 177 | 140 014 777 | 12 | `20,701` | PASS |

\* Moniteurs diagnostiques, pas gates de régression. Le p95 voisin de `20,7 ms` reflète la cadence du wait `physics_frame` dans ce harness headless; environ 49–50 échantillons dépassent nominalement `16,67 ms` dans chaque scénario, y compris le solo. Ce n'est pas une preuve d'un hotspot flanker isolé.

Points positifs mesurés : zéro orphan pendant les snapshots, zéro WeakRef ennemi après teardown, groupe `combatant` revenu à zéro, objets/nœuds revenus au plancher du process, ressources partagées après warm-up.

Le stress frais complète cette caractérisation avec une foule mixte de 36 unités en mode masse, tous les 22 IDs canoniques présents, cible mobile/changée, quatre sections, quatre morts atomiques et cleanup. Il ne remplace pas une foule exclusivement flanker ni une mesure GPU.

Limites futures : aucune mesure non-masse, aucun draw call/VRAM/GPU, aucun profil Self-time et aucune répartition forcée des trois variantes. Les variantes de modèle changent aussi les triangles et textures entre runs normaux. Ces limites n'accompagnent aucune panne fonctionnelle reproductible.

## Avant / après

`BASELINE.md` ne contient pas de scénario `--archetype=flanker`. Les lignes globales `1/5/15/28/36` utilisent la valeur par défaut du benchmark (`swordsman`). Elles emploient aussi `120` frames de warm-up contre `90` ici. Une comparaison numérique serait donc confondue par l'archétype, le cache de ressources, la variante de modèle et les conditions de run.

À titre de caractérisation seulement, le baseline global `1 active` indique `37` nœuds, `1 633` objets, `85 993 102` octets et `249,627 ms` de spawn, tandis que le `flanker 1 active` frais indique `33`, `1 632`, `85 096 017` et `394,423 ms`. Ces nombres ne constituent ni un gain ni une régression flanker. Aucun pourcentage avant/après n'est publié.

Aucune implémentation propre au flanker n'a été effectuée dans cette passe : l'« après » est l'état courant audité. L'absence de baseline rétrospective exacte est explicitement déclarée; le benchmark frais ci-dessus devient le point de référence flanker pour toute future modification, sans prétendre reconstruire un delta historique.

## Inspection visuelle Compatibility

La capture a été rendue avec OpenGL `3.3`, GPU NVIDIA RTX 4060 Laptop, renderer Compatibility. Inspection directe :

- `IDLE NU` et `JOG NU` cachent volontairement l'épée; le torse, les bras et les jambes sont visibles et aucune pose en T n'est évidente ;
- le jog est distinct de l'idle, avec levée de genou et transfert de poids lisibles ;
- l'attaque adopte une pose basse/agressive, cohérente avec un flanqueur rapide ;
- l'impact est clairement différent de l'attaque et replie le corps ;
- la mort est couchée et ne reste pas debout ;
- la section du bras droit est visible sur le dernier acteur, avec proxy/épée libéré et sang dans la planche ;
- les six acteurs peuvent provenir de variantes différentes : la planche prouve la route du pool, pas une séquence temporelle d'un seul corps ;
- la distance de caméra ne permet pas de qualifier l'alignement fin de l'épée, le contact de lame, les matières alpha ou la coupe en gros plan.

Limites visuelles futures : sprint, rotation, passage LOD0→3→0, sommeil/réveil, locomotion pendant une action partielle, chaque variante forcée et chaque zone sectionnée. La cadence LOD et le réveil sont toutefois couverts mécaniquement par le probe direct Mixamo frais. Le flanker n'a ni garde ni bouclier; ces poses sont `N/A` pour son profil et ne sont pas remplacées artificiellement.

## Revue Godot

### Critiques / bloquants de validation

Aucun défaut critique ou bloquant reproductible local au `flanker` après intégration. La clé `minimum_progress_speed` est cohérente et ses probes composant/navmesh sont verts; la cadence directe Mixamo est réellement contrôlée; la mort quitte atomiquement les consommateurs IA; le stress mixte et le cleanup sont verts.

### Améliorations et risques

- Le `DIRECT_STEERING` ne sait pas contourner un obstacle complexe. C'est une limite fonctionnelle connue; garder ce mode seulement si les routes Battle garantissent des espaces ouverts ou si l'échec explicite est consommé tactiquement.
- Le corps `CharacterBody3D` est uniformément scalé à `0,96`; préférer à terme des dimensions de shapes calculées directement si une refonte physique est mesurée et couverte.
- Les clips `flying_knee/axe_kick/mutant_swipe` ne sont pas des coups d'épée exacts et le hit est timer-driven. Une future correction doit conserver la vitesse `0,18 s` ou justifier toute variation, puis produire une preuve visuelle et mécanique synchronisée.
- Deux variantes utilisent un matériau alpha blend; mesurer overdraw/draw calls avant de convertir en alpha scissor/hash.
- Le pool à trois topologies empêche d'affirmer une seule famille de rig canonique. Aucun donneur ou modèle ne doit être retiré avant une preuve par variante.
- Les couches physiques numériques ne sont pas nommées dans `project.godot`, ce qui rend leur audit éditeur plus difficile.

### Points positifs

- Factory et profil précèdent correctement toute construction dépendante.
- Un seul root possède la vélocité et `move_and_slide()`.
- La gravité verticale est conservée séparément du steering horizontal.
- Les recherches de géométrie LOD n'ont lieu qu'au changement de niveau, pas chaque frame.
- Les animations directes deviennent manuelles à distance et se réveillent explicitement.
- Les FBX sources ne persistent pas comme donneurs de scène; les animations extraites sont mises en cache.
- Les hitboxes anatomiques dorment hors interaction et se réveillent avec des cadences adaptées.
- Mort, retrait vivant, désarmement et changement de cible libèrent les leases.
- Débris et cadavres ont un cycle de vie borné et perdent collision/ombres.
- `set_ai_participation(false)` fournit un point unique et testé pour retirer atomiquement une unité endormie ou morte des groupes, du registry, de la cible et de la navigation.

## Matrice de validation

| Contrat | État | Preuve / manque |
|---|---|---|
| factory / profil / ID | PASS | full roster + factory route |
| faction / cible / claims | PASS partagé applicable | faction-targeting + stress mixte avec roster canonique, cible mobile/changée |
| Battle 01 / Battle 02 | PASS démarrage + source | code 0, routes explicites; pas combat exact instrumenté |
| Combat Lab | N/A | aucune route flanker déclarée; capture minimale distincte du Lab |
| Forge | N/A | factory générique seulement, aucune entité flanker déclarée |
| solo fonctionnel | PASS | benchmark actif 1 + full roster + code tactique et scheduler |
| groupe fonctionnel | PASS partagé applicable | benchmark 12 + scheduler + stress 22 IDs/36 unités |
| navigation | PASS | `DIRECT_STEERING` exact + composant frais; navmesh frais valide l'autre mode/fallback partagé |
| attaque | PASS contrat | profil/timers/portée/arc + scheduler/action probes; synchronisation lame fine non revendiquée |
| mort | PASS ciblé/visuel/partagé | fatal sever + planche + teardown + quatre morts atomiques sous stress |
| démembrement | PASS mécanique | 12 zones, 10 sections; variantes non forcées |
| perte d'épée | PASS mécanique | bras droit contrôlé par probe |
| perte de bouclier | N/A | `shield=false` |
| sommeil/réveil IA | PASS partagé applicable | stress mixte, retrait/restauration atomiques registry/crowd |
| sommeil/réveil animation | PASS partagé applicable | direct Mixamo réel à 12 Hz/0 Hz/wake |
| rendu Compatibility | PASS limité | six états, pas variantes/LOD complets |
| performance solo/groupe | PASS caractérisation | 1 et 12 flanker + stress mixte 36; GPU/non-masse futurs |
| avant/après propre | N/A historique + baseline courante | aucun ancien flanker comparable; run frais conservé comme référence future |
| revue indépendante | PASS | audit distinct réévalué après intégration et reruns frais |

## Backlog futur non bloquant

1. Ajouter, si une régression tactique apparaît, un probe cinématique flanker dédié mesurant rayon/évolution angulaire de l'orbite, proximité extrême, hit après wind-up et distribution statistique des leases.
2. Forcer successivement `smallsbir4`, `kamikaze1` et `smallsbir1` pour produire une matrice runtime complète des `Skeleton3D`, skins, players et dix proxies sectionnés. Ne retirer aucun donneur avant cette preuve.
3. Étendre la planche par variante avec sprint, rotation, attaque jusqu'au contact, proche-lointain-proche et réveil. Conserver une passe corps nu et une passe équipée.
4. Capturer à l'avenir une paire baseline/après flanker strictement comparable, masse et non-masse, avec draw calls, VRAM, triangles LOD, ombres, spawn et coût de sections/morts répétées.
5. Si Combat Lab ou Forge acquiert ultérieurement une route `flanker` explicite, ajouter alors la preuve correspondante; leur absence actuelle reste `N/A`.

## Conclusion

Le `flanker` ne présente aucun échec dans les probes exécutés : factory, identité, rig sélectionné, équipement, anatomie, sections, navigation, scheduler, cadence LOD, mort atomique, lifecycle, benchmark et stress mixte sortent tous en code `0`. Son comportement de flanc rapide et ses valeurs de gameplay sont conservés, et aucun donneur n'a été supprimé.

Les preuves individuelles exactes et les garanties communes sont distinguées sans inventer de route. Les limites restantes concernent la profondeur d'instrumentation et la comparaison historique, pas une panne locale reproductible. Le verdict final réévalué est donc **DONE**.
