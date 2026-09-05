# Audit final — `brute`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Archétype exact :** `brute`\
**Famille d'audit :** `legacy_heavy`\
**Portée :** audit individuel de l'état courant; scripts, scènes, profils et ressources centraux examinés en lecture seule.

## Verdict

Le `brute` satisfait le contrat runtime actuellement déclaré : construction par la factory canonique, profil unique et stable, cible/faction communes, comportement lourd agressif, locomotion `DIRECT_STEERING`, axe attachée puis libérée, rig Mixamo direct animé, anatomie `12/12`, dix zones sectionnables, mort et teardown structurel propres. Le probe ciblé termine en code `0` avec `zones=12 severed=10`; le full roster valide l'identité `brute` parmi `22/22`; la planche rendue couvre idle nu, jog nu, attaque, impact, mort et section.

Ce verdict ne prétend pas que le brute possède un pathfinding navmesh, une bibliothèque canonique de famille, une géométrie optimisée sous 12 000 triangles, ni une mesure avant/après comparable. Les trois modèles du pool n'ont pas la même taille de rig (`81`, `64`, `66` joints) et aucune suppression de source/donneur n'est autorisée tant qu'une validation explicite par variante n'existe pas.

## Preuves primaires

| Preuve | Résultat |
|---|---|
| `.tmp_tools/enemy_refactor/logs/dismember_brute_final.log` | `ENEMY_UNIT_DISMEMBERMENT_PROBE PASS id=brute zones=12 severed=10`, exit `0` |
| `.tmp_tools/enemy_refactor/logs/full_roster_final.log` | `brute`: `legacy_heavy`, `direct_mixamo`, anatomie `12/12`, `axe`, action `static`, `DIRECT_STEERING`; fin `PASS: 22/22` |
| `.tmp_tools/enemy_refactor/logs/visual_brute.log` | six acteurs rendus; `PASS`, image `1351 x 760` |
| `docs/enemy_refactor/visual_evidence/brute.png` | inspection directe effectuée avec `view_image` |
| `.tmp_tools/enemy_refactor/logs/brute_performance_final.log` | benchmark v3 ciblé, 1/12 unités, idle/active, registry on, quatre scénarios PASS et teardown propre |
| `.tmp_tools/enemy_refactor/logs/navigation_component_final.log` | intention, arrivée, fallback et récupération bornée : PASS |
| `.tmp_tools/enemy_refactor/logs/navigation_navmesh_final.log` | contrat navmesh partagé : PASS; ce résultat ne transforme pas le mode exact du brute en navmesh |
| `.tmp_tools/enemy_refactor/logs/action_state_final.log` | priorité garde/récupération/wind-up/parade/tactique : PASS |
| `.tmp_tools/enemy_refactor/logs/combat_final.log` | défense/patterns du contrôleur partagé : PASS |
| `.tmp_tools/enemy_refactor/logs/faction_targeting_final.log` | groupes, priorité de cible, claims, représailles et friendly fire : PASS |
| `.tmp_tools/enemy_refactor/logs/transient_lifecycle_final.log` | ressources partagées, TTL borné, retrait collision/ombres : PASS |
| `.tmp_tools/enemy_refactor/logs/factory_route_final.log` | toutes les constructions runtime passent par la factory : PASS |
| `.tmp_tools/enemy_refactor/logs/patrol_final.log` | contrat de patrouille partagé : PASS |
| `.tmp_tools/enemy_refactor/logs/crowd_tactics_final.log` | anneau de contact, réserves et budget d'attaque : PASS |

Le message Windows headless `Failed to read the root certificate store` est présent dans les logs. Il précède les PASS, n'est lié à aucun accès TLS du test et n'altère pas les codes de sortie.

## Construction, profil, routes et cycle de vie

### Source de vérité et factory

- `scripts/enemy/enemy_archetypes.gd` contient l'unique profil `brute`. `profile()` renvoie une copie profonde; `data()` fournit la vue typée mise en cache.
- `scripts/enemy/enemy_factory.gd` convertit les appels historiques en `HopliteEnemySpawnRequest`, instancie un seul `HopliteAthenianEnemy`, injecte identité, position, cibles, faction, mode de masse et registre, puis ajoute le nœud à l'arbre.
- `_ready()` applique le profil avant capsule, visuel, anatomie et navigation. Le full roster vérifie aussi la métadonnée `procedural_archetype=brute`, les groupes `combatant/enemy`, la santé initiale et le teardown séquentiel.
- L'audit de roster initial et le run courant donnent exactement la même ligne : `rank=troop weapon=axe defense=none pattern=0/0 donors=0 package=bossmonster1.glb`. Aucun changement de profil propre au brute n'est intervenu pendant cette passe.

### Profil effectif

| Champ | Valeur |
|---|---:|
| nom / skin | `BRUTE` / `brute` |
| rang | `troop` |
| couleur de fallback | `Color(0.025, 0.18, 0.72)` |
| échelle du corps | `1.12` |
| santé | `310` |
| vitesse | `3.65 m/s` |
| dégâts | `29` |
| portée / aggro | `1.96 m` / `19 m` |
| arme / échelle | `axe` / `1.20` |
| bouclier / défense | non / `none` |
| comportement / style | `brute` / `heavy` |
| wind-up / récupération | `0.44 s` / `0.48 s` |
| cooldown | `1.38–1.72 s` |
| vitesse d'animation d'attaque | `0.92` |
| bande préférée | `0–1.86 m` |

### Routes réellement applicables

- Le manifest déclare seulement `battle_01` et `battle_02`.
- Battle 01 emploie `brute` dans les gardes, rencontres urbaines et garde finale; Battle 02 l'emploie dans les lignes de garde, cohortes de masse, ville et renforts finaux. Ces appels convergent sur les helpers de Battle 01 puis sur la factory.
- `enemy_factory_route_probe` prouve la convergence générale. `battle_enemy_spawn_probe` prouve les helpers Battle 01, mais ses fixtures exactes sont `guardian` hostile et `spearman` allié : il ne constitue donc pas à lui seul un combat Battle automatisé du brute.
- `brute` n'appartient pas à `ROSTER_IDS`, donc n'est pas proposé par `procedural_catalog()`. Le manifest et les recherches runtime ne le déclarent ni au Combat Lab ni dans la Forge. Aucune preuve Lab/Forge non applicable n'est attribuée artificiellement à cette unité.

### Faction, cible, activation, mort et nettoyage

- La faction hostile par défaut inscrit le brute dans `enemy`, `athenian`, `damageable`, `combatant`, puis `combatant_ai/enemy_ai` si l'IA est active. La factory sait techniquement injecter une autre faction, mais aucune route brute spartiate n'est déclarée.
- `battle_player` reste la référence humaine stable; `ai_player` est la cible immédiate. Le contrôleur privilégie représailles valides, joueur local puis adversaires de faction, avec hystérésis de distance et pénalité de claims.
- Les changements de cible, la mort et `_exit_tree()` libèrent le claim et tout lease d'attaque. `enemy_faction_targeting_probe` et le full roster couvrent ce contrat partagé.
- À la mort : permissions et cible sont libérées, vélocité/attaque annulées, couches et masques du corps mis à zéro, capsule et anatomie désactivées, physique IA arrêtée, axe lâchée, animation de mort ou fallback jouée, puis cadences et ombres du cadavre retirées. Le cadavre rendu reste jusqu'au nettoyage de l'encounter/scène; le contrôleur ne lui attribue pas de TTL propre.
- Les débris d'axe restent physiques `4 s`, deviennent ensuite sans collision/ombres et expirent à `12 s`; les membres proxies expirent à `14 s` après `4 s` physiques. Le probe de cycle de vie partagé valide ce contrat.

## Décision et combat solo/groupe

- Le comportement `brute` choisit `brute_charge` au-delà de `1.96 m` et `brute_attack` dans la portée. Il n'impose aucune distance minimale : une cible trop proche n'entraîne pas l'état d'observation infini constaté historiquement sur certaines lances.
- Le style `heavy` sélectionne le slot mécanique lourd. Comme `combat_pattern` est vide, l'action est qualifiée `static` : les dégâts/timings viennent du profil commun, tandis que la présentation choisit un clip du pool direct Mixamo.
- Le pool d'attaque est `mutant_swipe`, `mutant_punch`, `axe_combo`; idle `axe_block_idle`, déplacement `run`, réaction `hit_react`, taunt `mutant_roar`. Les translations des hips sont retirées des clips importés, laissant le `CharacterBody3D` propriétaire de la locomotion.
- `_begin_ai_attack()` revalide cible et capacité anatomique, réserve un lease partagé, stoppe la translation pendant le wind-up et émet `attack_started`. `_resolve_ai_attack()` revalide le lease, l'arme/bras droit, la portée et l'arc avant d'appliquer les dégâts, puis entre dans une récupération bornée.
- La perte du bras ou avant-bras droit lâche l'axe et rend `_can_ai_attack()` faux; une attaque en cours est annulée. Une jambe perdue plafonne la vitesse à `1.85 m/s`; deux jambes à `0.72 m/s`, avec collider raccourci et présentation crawl.
- En groupe, le crowd director fournit anneau/slot, séparation et capacité d'attaque. Un lease expiré est invalidé localement; mort, interruption et sortie libèrent le lease. `crowd_tactics_probe` couvre le budget partagé, et le benchmark actif avec 12 brutes exerce le contrôleur en groupe, mais ne compte pas la rotation individuelle des coups par archétype.

## Navigation, blocage et récupération

- Mode exact : `HopliteEnemyNavigationComponent.Mode.DIRECT_STEERING`. Aucun `NavigationAgent3D` n'est créé pour le brute.
- À chaque tick, le contrôleur fournit la destination tactique; le composant renvoie direction plane, facteur de vitesse et statut. Le corps applique accélération, gravité commune et un seul `move_and_slide()`.
- Distance d'arrivée `0.28 m`; progrès minimum `0.12 m/s`; blocage après `0.82 s`; récupération latérale `0.48 s` à `72 %` de la vitesse; trois tentatives maximum puis `navigation_failed(recovery_exhausted)`.
- Le drift modéré d'une cible ne remet pas indéfiniment le compteur de blocage à zéro. Le probe partagé valide récupération, destination mouvante, progression lente et fallback explicite.
- Limite : ce mode ne calcule pas de détour autour d'un obstacle complexe et ne prouve pas un passage étroit propre au volume lourd. Le probe navmesh vert valide le composant commun en `NAVMESH_GROUND`, pas la configuration du brute. Une future migration de mode serait un changement de navigation à mesurer dans Battles 01/02, pas un renommage documentaire.

## Rig, clips, donneurs et LOD animation

### Route runtime

- Route normale : `direct_mixamo`. Le corps réellement affiché est choisi dans `bossmonster1`, `bossmonster2`, `bossmonster3`; en `mass_battle_mode`, seul `bossmonster1` est retenu.
- Chaque instance conserve le `Skeleton3D` et l'`AnimationPlayer` de son modèle. Il n'y a pas d'`AnimationTree` ni de retargeter persistant pour le brute.
- `install_personality()` charge les scènes FBX à la première utilisation, duplique les ressources `Animation`, libère immédiatement leurs nœuds source, puis réutilise un cache statique. Ainsi `donors=0` signifie zéro donneur **instancié persistant**, pas autorisation de supprimer les FBX sources.
- Les clips sont corps entier; il n'existe pas de surcouche partielle nécessitant un masque d'os. Aucun donneur ou clip source n'a été supprimé pendant cet audit.

### Inventaire GLB source

| Modèle | Taille | Nœuds | Meshes/surfaces | Triangles LOD0 | Skins/joints | Animations | Matériaux/textures |
|---|---:|---:|---:|---:|---:|---:|---:|
| `bossmonster1.glb` | 1 629 328 o | 83 | `1/1` | `12 626` | `1/81` | 1 | `1/2` |
| `bossmonster2.glb` | 1 555 676 o | 66 | `1/1` | `13 910` | `1/64` | 1 | `1/3` |
| `bossmonster3.glb` | 2 031 204 o | 68 | `1/1` | `9 620` | `1/66` | 1 | `1/2` |

Ces compteurs proviennent directement des chunks JSON glTF. Les hiérarchies et nombres de joints diffèrent : la compatibilité des trois rigs ne doit pas être supposée sur leur seule silhouette. Les probes courants valident les mains, le skeleton et les 12 zones pour les instances traversées, sans journaliser explicitement quel modèle a servi à chaque zone.

### Import, rendu et veille/réveil

- Les trois GLB ont `generate_lods=true`, shadow meshes, tangentes et skins nommés. Les FBX d'action sont importés à `30 FPS`, trimming actif, pistes immuables retirées et LOD/shadow meshes générés.
- Le LOD de rendu utilise par défaut `near=16 m`, `far=38 m`, `cull=90 m`; il ajuste `lod_bias`, visibilité, ombres et particules. En masse, les ombres du visual root sont coupées.
- Pour l'AnimationPlayer direct, LOD1 passe en échantillonnage manuel ~`30 Hz`, LOD2 ~`12 Hz`, LOD3 suspend l'avance; le retour LOD0 restaure le mode idle et force `advance(0.0)`. La logique de réveil est explicite dans le contrôleur.
- `enemy_animation_lod_probe` passe pour les pilotes shared/native, mais n'instancie pas de brute direct Mixamo. Le réveil direct est donc une conformité de code examinée, pas une preuve dynamique propre au brute.

## Meshes, équipement et rendu

- Chaque variante possède un mesh corporel monobloc, une surface et un matériau. La section visuelle réduit la chaîne de bones à `0.001`; le membre détaché est un proxy procédural, pas un fragment de la géométrie originale.
- L'axe est créée procéduralement et attachée au bone de main droite résolu. Le full roster vérifie arme, attachment et main; la section droite vérifie sa libération.
- Le modèle de masse `bossmonster1` dépasse légèrement 12 000 triangles et `bossmonster2` davantage. Conformément à la mission, aucun remplacement arbitraire par un modèle « 12k » ni aucune fusion risquée n'a été effectué. `bossmonster3` est plus léger, mais n'est pas une substitution prouvée pour les deux autres rigs.
- Les imports disposent de LOD, mais le benchmark headless ne mesure ni draw calls, ni VRAM, ni triangles réellement sélectionnés à distance. Les textures embarquées ne font pas l'objet d'une preuve de mipmaps/compression détaillée dans ce rapport.
- La planche Compatibility rend correctement le skinning, les ombres, l'axe et les états principaux. Elle ne remplace pas une passe GPU Battle 01/02.

## Anatomie et démembrement — 12 zones

Le composant crée une `Area3D` anatomique sur la couche combat avec une primitive par zone. Le probe ciblé instancie une unité indépendante pour chaque zone, applique un sever hit massif, vérifie état/fatalité, proxy et perte d'équipement.

| Zone | Forme/rayon | Dégâts x | Sever x / seuil | Section et conséquence |
|---|---|---:|---:|---|
| `head` | sphère `0.25` | `1.70` | `1.00 / 64` | oui, fatale; tête proxy |
| `neck` | capsule `0.15` | `1.85` | `1.35 / 56` | oui vers `head`, fatale |
| `torso` | capsule `0.34` | `1.00` | `0.35 / 9999` | non; dégâts localisés |
| `pelvis` | capsule `0.30` | `0.95` | `0.30 / 9999` | non; dégâts localisés |
| `upper_arm_l` | capsule `0.16` | `0.78` | `1.00 / 78` | oui; désactive aussi `forearm_l` |
| `forearm_l` | capsule `0.14` | `0.75` | `1.10 / 60` | oui |
| `upper_arm_r` | capsule `0.16` | `0.78` | `1.00 / 78` | oui; désactive `forearm_r`, lâche l'axe, désarme |
| `forearm_r` | capsule `0.14` | `0.75` | `1.10 / 60` | oui; lâche l'axe, désarme |
| `thigh_l` | capsule `0.21` | `0.88` | `0.82 / 94` | oui; désactive `shin_l`, limp/crawl |
| `shin_l` | capsule `0.18` | `0.84` | `1.05 / 72` | oui; limp/crawl |
| `thigh_r` | capsule `0.21` | `0.88` | `0.82 / 94` | oui; désactive `shin_r`, limp/crawl |
| `shin_r` | capsule `0.18` | `0.84` | `1.05 / 72` | oui; limp/crawl |

Le tracking anatomique s'endort hors combat. Il suit à chaque tick ou `30 ms` en masse durant contact/attaque, puis à `45/65 ms`, `120/200 ms`, ou se désactive loin de toute interaction. Mort appelle `anatomy.shutdown()`.

## Physique

- Corps : `CharacterBody3D`, couche `4`, masque `1|2` avec IA (`1` sans IA), gravité/mouvement gérés dans `_physics_process()` et `move_and_slide()`.
- Collider principal local : capsule primitive `radius=0.39`, `height=1.82`, centre Y `0.91`; aucun concave mobile. À l'échelle racine `1.12`, le volume mondial nominal devient environ `0.437 m` de rayon et `2.038 m` de hauteur.
- Anatomie : douze sphères/capsules `Area3D`; débris : `RigidBody3D` couche `16`, masque monde `1`, sphère/capsule primitive, `can_sleep=true`, impulsion bornée et TTL.
- Les ennemis ne se collisionnent pas physiquement entre eux; la séparation spatiale tient lieu d'espacement. Cela réduit le broadphase, mais exige que le steering commun reste actif.
- Réserve de conformité : le `CharacterBody3D` complet est mis à l'échelle à `1.12`; la `CollisionShape3D` n'a pas de scale local, mais hérite celle du parent. Cette approche s'écarte de la recommandation Godot consistant à dimensionner la shape elle-même.
- `project.godot` ne verrouille explicitement ni moteur physique 3D ni interpolation; aucune garantie de configuration Jolt/interpolation n'est donc revendiquée.

## Performance ciblée

Commande : `enemy_performance_benchmark.gd -- --counts=1,12 --mode=both --warmup=60 --frames=60 --archetype=brute --registry=on`.

| Scénario | Spawn | Nœuds | Objets | Mémoire statique | process* | physics* | corps actifs | teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| 1 idle | `203.155 ms` | 33 | 1 626 | 68 324 778 o | `0.254 ms` | `0.407 ms` | 0 | propre |
| 12 idle | `264.047 ms` | 319 | 2 154 | 71 765 705 o | `1.296 ms` | `2.215 ms` | 0 | propre |
| 1 active | `226.909 ms` | 34 | 1 629 | 68 461 526 o | `0.280 ms` | `1.027 ms` | 1 | propre |
| 12 active | `364.077 ms` | 331 | 2 179 | 71 920 245 o | `1.912 ms` | `5.079 ms` | 12 | propre |

`*` Les métriques process/physics sont des snapshots engine à rafraîchissement lent, pas des séries indépendantes. Le p95 des ticks reste voisin de `20.7 ms` alors que le budget théorique est `16.67 ms`; le harness attend des physics frames et ce compteur ne doit pas être présenté comme une régression GPU/CPU autonome. Les scénarios d'un même processus partagent aussi un cache réchauffé.

La baseline mission mesure le swordsman générique et les hoplites, pas un brute dans les mêmes conditions. Elle ne peut donc pas servir de « avant » numérique honnête. La seule comparaison propre est qualitative/structurelle : ligne de roster brute inchangée, seuil `mass_battle_mode=28` inchangé, aucun changement de vitesse/timing/rig lors de cet audit. Aucun gain avant/après n'est revendiqué.

## Inspection visuelle

La planche `brute.png` montre une silhouette lourde cohérente : créature bossmonster massive, posture tassée, axe visible et palette chair/armure rouge. `IDLE NU` et `JOG NU` cachent volontairement l'axe; les deux poses sont au sol, non-T, avec inclinaison et membres actifs. `ATTAQUE` montre un geste de corps entier lisible avec axe. `IMPACT` différencie clairement la réaction. `MORT` place le corps au sol et sépare l'axe. `SECTION` montre la perte du bras droit et du sang.

Limites de la composition : le proxy/morceau est projeté loin vers le bord droit, donc sa qualité de géométrie/coupe n'est pas validable en gros plan; des particules rouges sont hors plateforme; les six colonnes sont six instances et non six temps d'un même modèle, ce qui ne prouve pas la continuité d'une variante unique.

## Limites finales et actions futures exactes

1. **Variantes de rig non qualifiées séparément.** Ajouter au full-roster/visual probe un override de `model_id`, puis exécuter idle, run, trois attaques, réaction, mort, réveil LOD et 12 zones pour `bossmonster1/2/3`, en journalisant skeleton/joints/mesh. Ne supprimer aucune source FBX/GLB avant cette preuve.
2. **Pas de test de combat brute statistique.** Ajouter un probe qui compte wind-up, hit reçu, recovery, leases et rotation équitable pour 1 puis 12 brutes, y compris cible trop proche, cible perdue, changement de cible, bras droit sectionné et mort pendant un lease.
3. **Obstacle complexe non couvert par le mode exact.** Construire un scénario Battle avec obstacle et passage calibré au rayon mondial ~`0.437 m`; valider arrivée ou `navigation_failed` borné. Si le détour est requis, comparer `NAVMESH_GROUND` à l'identique sans modifier `3.65 m/s`.
4. **LOD direct Mixamo seulement audité par code.** Étendre `enemy_animation_lod_probe` au brute et vérifier les compteurs `30/12/0 Hz`, puis réveil LOD0 avec pose rendue.
5. **Pas de baseline brute comparable ni métriques GPU.** Rejouer exactement le même binaire/scène/seed avant et après un futur correctif, en processus frais, avec draw calls, VRAM, surfaces/triangles et captures Battle 01/02.
6. **Cadavres de bataille sans TTL local.** Vérifier la politique de nettoyage de chaque encounter Battle 01/02 sous mort en masse; si l'intention est un TTL, l'implémenter centralement avec un test, pas dans ce rapport d'unité.

## Conclusion

**DONE pour le contrat actuel.** Toutes les gates autoritaires disponibles sont vertes : construction/factory, identité, rig actif, axe, navigation déclarée, anatomie `12/12`, démembrement `10/12`, mort, débris bornés, teardown et benchmark ciblé. Aucun défaut propre reproductible ne justifie une modification centrale depuis cet agent.

Les limites ci-dessus interdisent toutefois trois extrapolations : déclarer les trois rigs interchangeables, annoncer un pathfinding navmesh, ou revendiquer un gain avant/après. Elles sont des travaux de couverture et d'optimisation futurs, avec actions exactes, et les sources donneuses doivent rester intactes.

### Clôture transversale post-audit

La première et la quatrième limite ont depuis été fermées : `enemy_mixamo_variant_matrix_probe --id=brute` valide séparément `bossmonster1/2/3` et leurs 36 zones cumulées, tandis que `enemy_animation_lod_probe` valide le chemin direct Mixamo à 30/12/0 Hz avec réveil LOD0. `enemy_unit_behavior_probe --id=brute` parcourt aussi chaque action réelle et les transitions interruption/perte de cible/sleep-wake. Le mode direct avec récupération bornée demeure son contrat volontaire ; aucune source donneuse n'a été supprimée.
