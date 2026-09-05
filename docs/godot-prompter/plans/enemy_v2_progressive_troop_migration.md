# Migration progressive Enemy V2 par familles de troupes

Statut : pilote Hoplite `spear_formation` au gate `CONTRACT_READY`, aucun ennemi de production migré.

## État concret du pilote Hoplite — 1 septembre 2026

- `ngeneral` et `ngeneral_veteran` ont désormais deux définitions V2 distinctes mais partagent exactement le même corps, le même équipement de base et le même donneur d'animations.
- Le corps généré possède 23 os : les 30 phalanges de doigts et leurs groupes ont été retirés hors ligne, sans modifier la source 3DGen.
- Le corps V2 utilise désormais trois géométries explicites partageant ce même squelette : 22 820 triangles de 0 à 20 m, 8 127 triangles de 20 à 55 m, puis 2 560 triangles au-delà. Les trois meshes sont enfants d'un seul `Skeleton3D` animé ; aucun squelette supplémentaire n'est conservé pour les LOD.
- Le donneur unique publie 14 clips validés : locomotion, mort, bouclier, garde et trois attaques de lance, dont le pas appuyé `spear_bayonet_step`. Aucun donneur animé n'est créé par soldat et aucune piste ne cible un doigt.
- Les neuf fragments du package `dismemberedSpartanV2` utilisent les 22 mêmes textures externes. Les fragments totalisent environ 2,18 Mo hors textures ; cinq sont rigides sans squelette et quatre gardent exactement deux os.
- Les fragments physiques du laboratoire ont désormais un matériau sans rebond, un amortissement fort et une mise en sommeil déterministe après contact continu. Leur centre physique est dérivé du contrat 3DGen `pivot + normal + length`, leur impulsion suit l'impact réel de la lame sans biais vertical artificiel, puis un watchdog du collider les ramène au niveau des pieds si une surface Forge invisible les retient en hauteur. Le bouclier utilise un rigid body de débris dédié : chute physique puis mise à plat garantie, et il quitte immédiatement le cache LOD de l'acteur afin d'éviter toute écriture sur une géométrie libérée.
- La défense V2 passe par un `CombatGuardComponent` générique piloté par un `CombatGuardProfile` immuable. Les chances réelles distinguent attaques légères, lourdes, lourdes complètement chargées et Spiral Up/Down ; stun, recul et résistance sont réglables par classe. Le Hoplite et le vétéran sont les deux premiers profils, V1 reste inchangé.
- Les trois attaques de lance ne tournent plus en boucle aveuglément : Bayonet est le gap closer exposé, la poussée torse avance derrière le bouclier et la poussée basse contrôle la très courte portée. Les attaques protégées conservent un déplacement horizontal pendant la frappe.
- Un `EnemyActorV2` shadow compose déjà définition immuable, état mutable, présentation et animation. Il est uniquement accessible par une factory de laboratoire séparée.
- La factory de production continue à produire `HopliteAthenianEnemy` V1. Le routage `CONTRACT_READY` ne sélectionne jamais V2.

Le package n'est pas encore `migration_ready`. La tranche jouable Forge possède désormais masque anatomique persistant, combat, garde et phalange coordonnée. Les gates restant avant activation de production sont surtout : navigation de l'ancre sur navmesh, réduction durable des surfaces matière, tiers de simulation complets et benchmark V1/V2 reproductible en conditions identiques.

## Tranche Phalange V2 jouable — 1 septembre 2026

- `EnemyV2TroopRuntime` est installé une fois par monde V2 et possède les décisions collectives ; il ne remplace ni n'appelle le `BattleCrowdDirector` V1. Son service de données `EnemyV2BattleLayoutRuntime` reprend uniquement le principe utile de l'ancien système : secteurs angulaires stables par cible, sans dépendance au monolithe.
- Une phalange Forge contient exactement 24 membres en 8 × 3. Les slots et les identités standard/vétéran restent stables après le spawn.
- La cohésion, l'ancre, l'orientation et les permissions d'attaque sont évaluées à 8 Hz proche ou 2 Hz lointain, avec un déphasage par troupe. Aucun membre ne recherche une cible ou des voisins dans sa boucle physique.
- Seul le premier rang peut recevoir une permission, avec trois attaques simultanées au maximum. La durée du lease couvre l'attaque et sa récupération afin que le plafond ne soit pas contourné.
- Les phalanges partageant une cible reçoivent de vrais secteurs militaires dynamiques : une face, deux faces opposées, un triangle ou un carré selon les groupes réellement à portée, jusqu'à quatre lignes de contact. Les priorités sont réévaluées toutes les 350 ms avec hystérésis ; une troupe proche remplace un ancien focus devenu lointain. Les identités ne fusionnent jamais et un demi-tour conserve les positions mondiales des soldats.
- Les escouades compactes de six membres ou moins utilisent un anneau de contact indépendant et peuvent attaquer en même temps que les phalanges. Les futurs groupes à distance gardent leur propre rôle/anneau derrière la même interface.
- Après une perte, les survivants reforment les rangs et une nouvelle première ligne est promue. À quatre membres ou 25 % de l'effectif initial, le groupe devient un reliquat compact sans créer six IA autonomes.
- Le root `EnemyActorV2` possède `velocity` et `move_and_slide()` pour la route formation. Son exécution passe de 60 Hz à 30/15 Hz avec les LOD et s'arrête au tier masqué ; le duel laboratoire conserve provisoirement sa route isolée.
- La carte `champsDeBataille_V2_150` utilise maintenant sept cerveaux collectifs : six phalanges (144 membres) et une escouade compacte de six vétérans. Les 150 soldats passent donc par la même cadence bornée, sans se superposer sur une destination individuelle commune.
- La transparence caméra suit les acteurs V2 en mode transform par un cache géométrique à 20 Hz ; elle ne réactive aucun des colliders individuels désactivés par le budget de foule.
- Les boucliers levés des vraies phalanges V2 exposent la couche Shield Run existante ; les duels et escouades compactes ne deviennent pas artificiellement des murs de traversal.
- Le contrat est couvert par les probes Forge, combat, démembrement, LOD et `hoplite_v2_battlefield_150_probe.gd`.

## Audit de coût V2 — 1 septembre 2026

Le probe reproductible `res://tools/enemy_v2/hoplite_v2_performance_probe.gd` a été exécuté avec une caméra active, VSync désactivée, renderer Compatibility et une RTX 4060 Laptop. Il mesure le laboratoire visuel sans combat, navigation ni gestionnaire de foule :

| Scénario | LOD | Draw calls moyens | Primitives moyennes | Frame moyenne | p95 |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 proche | 0 | 16 | 24 746 | 0,99 ms | 1,48 ms |
| 24 proches superposés | 0 | 384 | 593 904 | 4,72 ms | 5,39 ms |
| 60 proches superposés | 0 | 960 | 1 484 760 | 12,21 ms | 14,37 ms |
| 60 proches en grille | 0 | 960 | 1 242 821 | 11,72 ms | 13,80 ms |
| 60 lointains | 2 | 840 | 191 400 | 3,76 ms | 5,18 ms |

Conclusions attribuables :

- Le choix des LOD est correct : les 60 personnages placés près de la référence restent tous au LOD0 ; les 60 placés à 52 m passent tous au LOD2. Forcer artificiellement un LOD lointain sur des soldats proches masquerait le coût au lieu de respecter le contrat visuel.
- Les LOD géométriques produisent un gain réel (environ 78 % de primitives en moins et 69 % de temps de frame en moins entre ces deux scènes de 60 unités), mais ne corrigent pas le nombre de matériaux.
- Chaque acteur proche coûte actuellement 16 draw calls : 10 surfaces pour le corps, 3 pour l'aspis et 3 pour la dory. Le LOD2 conserve encore 8 surfaces de corps, donc 14 draw calls par acteur lointain.
- Les Resources lourdes sont mises en cache et partagées, mais 60 représentations créent encore 60 squelettes, 60 `AnimationPlayer`, 1 803 Nodes et 840 `MeshInstance3D`. Les 9 gore caps du corps existent comme Nodes masqués ; les trois corps LOD existent simultanément sous le squelette même si une seule plage est rendue.
- Puisque la phalange Forge V2 n'installe ni combat, ni anatomie, ni collider de locomotion, le ralentissement observé dans ce cas vient d'abord du rendu/skinning et du nombre d'instances, pas d'une IA inexistante.

La direction d'architecture reste valide (données partagées, composants séparés, un squelette par représentation, LOD explicites et V1 isolé), mais le pilote n'est pas encore une cible de performance. Les priorités avant un stress test jouable sont désormais mesurées :

1. atlasser/fusionner les matériaux pour viser une surface de corps et une surface par équipement, sur les trois LOD ;
2. ne pas instancier les gore caps masqués et les représentations inutiles dans les tiers de foule ; les matérialiser uniquement lors d'une coupe ou d'une transition qui en a besoin ;
3. ajouter `TroopRuntime` + `SimulationBudgetDirector` afin de cadencer animation, décisions, perception et physique par troupe/tier au lieu d'un callback autonome complet par unité ;
4. comparer V1 et V2 avec la même caméra, la même formation et les mêmes états de combat avant toute activation de production.

## Décision

Le jeu garde `HopliteAthenianEnemy` et `BattleCrowdDirector` comme implémentations V1 fonctionnelles pendant toute la migration. Enemy V2 est construit en parallèle uniquement pour le roster provenant de 3DGen, puis activé famille par famille derrière un routage central explicite.

Les anciens modèles Mixamo étaient des supports de test. Ils restent utilisables en V1 mais ne définissent plus implicitement les rôles du roster moderne et ne font pas partie du chantier V2. Les loups, dinosaures et autres créatures sont également hors périmètre ; ils auront leur propre chantier si nécessaire.

Cette approche est préférée à :

- continuer à agrandir le monolithe, qui ne permet pas d'isoler les coûts et responsabilités ;
- remplacer tout le roster en une fois, qui mélangerait les régressions d'IA, de combat, de rig, d'animation, de LOD et de démembrement ;
- créer une classe par modèle, qui dupliquerait le comportement au lieu de composer données et capacités.

Le changement de génération est volontairement protégé par deux clés : une famille doit être marquée `MIGRATED` dans le catalogue, puis la factory doit posséder un constructeur V2 compatible. En l'absence de constructeur, elle refuse la création au lieu de revenir silencieusement vers une mauvaise implémentation.

## Garanties de migration

- Tous les appels actuels continuent à créer V1.
- Un nouvel archétype inconnu reste V1 et porte une provenance `unclassified` ainsi qu'une route `not_eligible`.
- Seule une provenance explicite `3dgen` rend un archétype éligible à la migration.
- Une famille entière se migre ou se restaure par une seule décision centrale.
- Les identifiants d'archétypes, factions, signaux de mort, sauvegardes Forge et contrats de foule restent stables.
- Une famille n'est activée en V2 qu'après parité fonctionnelle, visuelle, anatomique et performance.
- Les benchmarks sont comparés à population, caméra, animation et scénario identiques.

## Provenance installée

Autorité : `res://scripts/enemy/enemy_archetypes.gd`.

| Provenance | Contenu | Quantité | Politique V2 |
| --- | --- | ---: | --- |
| `3dgen` | roster actuel et deux IDs historiques résolus vers 3DGen | 15 | éligible |
| `mixamo` | premiers modèles téléchargés pour les tests | 7 | exclu, V1 conservé |
| `other` | The Wolf, vélociraptor, tyrannosaure et imports spécialisés | 4 | exclu, chantier séparé |
| `unclassified` | nouvel ID sans déclaration explicite | 0 attendu | exclu par sécurité |

La provenance reste vraie après migration : un modèle peut être d'origine `3dgen` tout en utilisant la représentation runtime `modular_v2`. Ces deux axes ne doivent jamais être fusionnés.

Dans la Forge, la bibliothèque Personnages présente quatre sections : Enemy V2, 3DGen, Mixamo — anciens tests, et Autres — créatures/imports spéciaux. La section Enemy V2 peut exposer des entrées de laboratoire avec des identifiants dédiés (`enemy_v2_*`) avant la migration de production. Ces entrées passent par la factory shadow V2 et ne modifient jamais le routage V1. Le Hoplite standard, le vétéran au même skin et le preset `Phalange V2 Lab` de 48 unités sont le premier banc d'essai de ce type.

## Routage V2 installé

Autorité : `res://scripts/enemy/enemy_runtime_migration.gd`.

| Famille de migration | Archétypes actuels | Première difficulté spécifique | État initial |
| --- | --- | --- | --- |
| `light_melee` | nathenian1, nsbire1 | mêlée, bouclier, mobilité | V1 uniquement |
| `spear_formation` | ngeneral, ngeneral_veteran | portée et cohésion de phalange | contrat V2 prêt, production V1 |
| `ranged` | nsbire2 | projectile et positionnement | V1 uniquement |
| `heavy_melee` | nathenian2, nathenian2_soldier, bronze_colossus, boss_colossus, boss_bronze | poise, gros impacts, variantes | V1 uniquement |
| `command` | ncenturion | ordres et profil élite | V1 uniquement |
| `boss_humanoid` | nfull_armor | phases et attaques spéciales | V1 uniquement |
| `giant_humanoid` | giant_novice, giant_standard, giant_veteran | navigation large body et collisions | V1 uniquement |

Les familles servent au déploiement technique. Les profils tactiques et les packs d'animations restent des données composables : une famille de migration n'est pas une nouvelle hiérarchie de classes.

## Architecture cible

```text
World / Battle / Forge runtime
├── EnemyFactory                         # seul point de création
├── CombatantRegistry                    # identité/liveness communs V1/V2
├── TroopRuntime                         # intention tactique + représentation distante
│   ├── BattleLayoutRuntime              # secteurs réservés entre groupes/armes
│   ├── TroopProfile                     # formation, cadence, budget, règles de distance
│   ├── SpatialIndexService              # voisinage partagé
│   ├── EngagementScheduler              # autorisations d'attaque
│   └── SimulationBudgetDirector          # choix du tier avec hystérésis
└── Enemy representation
    ├── Legacy V1: HopliteAthenianEnemy  # inchangé pendant la migration
    └── Modular V2: EnemyActorV2         # acteur proche composant ses capacités
        ├── MovementComponent
        ├── CombatComponent
        ├── GuardComponent + GuardProfile
        ├── HealthAnatomyComponent
        ├── PresentationComponent
        └── AnimationComponent
```

Le root `CharacterBody3D` reste l'unique propriétaire de `velocity` et `move_and_slide()`. Les composants proposent des intentions ; ils ne déplacent jamais le root directement.

## Propriété des données et des états

### Définitions partagées, immuables

Un `EnemyDefinition` composera progressivement de petits Resources :

- `VisualProfile` : mesh source, LOD 3D, imposteur, équipements et matériaux ;
- `AnimationProfile` : squelette cible et références vers les packs commun, arme et spécial ;
- `CombatProfile` : points de vie, dégâts, portée, garde, timings et capacités ;
- `BehaviorProfile` : perception et choix d'actions individuels ;
- `AnatomyProfile` : zones, fragments préfabriqués, ancres et conséquences ;
- `SimulationProfile` : distances, cadences et éligibilité aux représentations lointaines.

Ces Resources sont partagés et ne sont jamais mutés par une unité.

### État mutable par unité

`EnemyRuntimeState` est l'autorité logique persistante : identité, faction, vie, capacités perdues, cible, ordre de troupe et transform. Les Nodes de représentation reflètent cet état mais ne le possèdent pas. Cela permet de dématérialiser un acteur lointain puis de le recréer sans ressusciter un membre coupé ou oublier sa vie.

Les quatre axes restent indépendants :

1. cycle de vie : vivant, incapacité, mort, nettoyé ;
2. action : locomotion, préparation, actif, récupération, défense ;
3. intention tactique de troupe : tenir, avancer, charger, se replier ;
4. niveau de simulation : détail physique et visuel selon distance/budget.

## Niveaux de simulation cibles

| Tier | Représentation | IA/physique | Animation | Démembrement |
| --- | --- | --- | --- | --- |
| `FULL` | mesh 3D proche | complète | échantillonnage complet | interaction complète |
| `NEAR_CROWD` | mesh 3D LOD | décisions cadencées | cadence réduite | état conservé, effets complets à l'impact |
| `FORMATION` | membres 3D groupés | ordre de troupe, steering simplifié | poses/actions discrètes | état logique conservé |
| `FAR_3D` | mesh très bas coût | transform piloté par troupe | animation très basse fréquence ou vertex bake | pas de calcul anatomique continu |
| `IMPOSTOR` | Sprite3D/billboard atlas | état agrégé de troupe | frames pré-rendues | état logique seulement |
| `DORMANT` | aucune représentation | simulation stratégique rare | aucune | état logique seulement |

Le passage en 2D n'utilise pas un SVG. Il utilise un atlas raster pré-rendu (couleur + alpha, éventuellement normales/profondeur) de plusieurs directions et actions. Il arrive après stabilisation de V2 3D, pas pendant la première migration.

Chaque transition utilise deux distances (entrée/sortie), un délai minimal et un budget par frame afin d'éviter le clignotement et les pics quand une troupe entière change de tier.

## Contrat 3dGen -> Godot

Un package humanoïde V2 doit être versionné et validable automatiquement :

```text
enemy_package/
├── body.glb                    # corps skinné unique, squelette UAL ennemi sans doigts
├── fragments/
│   ├── head.glb
│   ├── arm_l.glb
│   ├── arm_r.glb
│   ├── forearm_l.glb
│   ├── forearm_r.glb
│   ├── leg_l.glb
│   ├── leg_r.glb
│   ├── lower_leg_l.glb
│   └── lower_leg_r.glb
└── manifest.json               # schema, rig, os, surfaces, fragments, ancres
```

- Le corps principal n'est plus découpé en dix SkinnedMeshInstance3D runtime.
- Les fragments sont produits hors ligne et chargés une fois comme ressources partagées.
- Tête, avant-bras, main ou bas de jambe deviennent des meshes rigides sans squelette.
- Un bras ou une jambe entière peut garder uniquement les deux os nécessaires à son articulation si la silhouette le justifie ; sinon un fragment rigide est préféré.
- Le manifest doit déclarer `schema_version`, `rig_id`, liste d'os, version du modèle, fragments disponibles, pivot, transform d'ancrage et compatibilité LOD.
- L'import Godot refuse un package incomplet ou présentant des influences vers des os supprimés.

Les meshes existants seront convertis par un outil hors ligne idempotent vers un dossier généré séparé. Les sources GLB ne sont ni écrasées ni supprimées pendant la migration.

## Animation cible

- Un seul squelette canonique humanoïde ennemi, sans doigts, porte les clips compatibles.
- Les animations sont bakées hors ligne vers ce squelette ; aucun donneur animé n'est instancié par ennemi.
- Les clips sont séparés en packs chargeables : `common`, `sword_shield`, `spear`, `bow`, `heavy`, puis `special_<family|boss>`.
- Un ennemi ne charge que la bibliothèque commune, son pack d'arme et son éventuel pack spécial.
- Les noms sémantiques (`locomotion`, `light_attack`, `heavy_attack`, `block`, `death`, etc.) sont résolus par profil ; le gameplay ne connaît pas le nom brut du clip.
- Les os des doigts et leurs tracks sont supprimés pendant la génération. Les poids résiduels sont remappés vers `hand_l`/`hand_r`, puis normalisés.
- Le joueur garde son propre contrat et ses animations de doigts si nécessaire ; il n'est pas inclus dans le rig ennemi allégé.

Avant de rebaker tout le catalogue, un benchmark contrôlé compare 53 et 23 os sur le même mesh, les mêmes clips, le même nombre d'ennemis et les mêmes LOD. Le rebake massif n'est autorisé qu'avec un gain mesuré ou parce que le nouveau contrat simplifie suffisamment le runtime.

## Démembrement persistant

Le démembrement V2 est un état persistant, pas seulement un effet visuel. La première tranche Hoplite le conserve dans `HealthComponent` + `DismembermentComponent`; son déplacement final dans le `EnemyRuntimeState` générique reste prévu avant la migration d'une seconde famille :

```text
impact localisé
  -> AnatomyComponent valide le seuil
  -> RuntimeState marque le segment absent et applique la perte de capacité
  -> PresentationComponent masque/remplace la région du corps
  -> GoreDirector demande le fragment préchargé au pool
  -> fragment rigide ou bi-os reçoit l'impulsion
  -> changement de tier conserve le masque anatomique
```

Le fragment ne recrée jamais un corps complet. Le pilote Hoplite lance déjà les fragments 3DGen individuels, masque la chaîne d'os, désactive les hitboxes enfants et retire l'équipement du bras concerné. Le pool partagé par package et le budget global de fragments restent à connecter avant activation de masse.

## Compatibilité avec la foule

V1 et V2 exposent pendant la transition la même façade minimale :

- `is_dead_for_combat()` ;
- `is_ai_participating_for_combat()` ;
- `crowd_participant_descriptor()` ;
- `set_ai_participation()` ;
- `receive_ai_hit()` ;
- signal `died`.

Le directeur de foule actuel continue donc de fonctionner. Sa décomposition vient après le premier acteur V2 validé : spatial index, engagement scheduler, troop coordinator, puis simulation budget director. Cette séparation rendra les profils par troupe et distance plus simples à contrôler, sans exiger une réécriture simultanée des formations.

## Ordre d'exécution

- [x] **Fondation : provenance, catalogue de routage, Forge et garde V1.** Séparer 3DGen, Mixamo et autres imports ; limiter V2 aux quinze entrées 3DGen ; exposer le diagnostic et empêcher un basculement sans constructeur.\
  Skills: `using-godot-prompter`, `godot-brainstorming`, `assets-pipeline`, `resource-pattern`, `godot-ui`, `godot-testing`.

- [ ] **Mesures de référence.** Figer les scénarios 1/12/28/56 unités, coûts CPU/GPU, mémoire, draw calls, objets, squelettes, pics de spawn et de démembrement.\
  Skills: `godot-optimization`, `godot-testing`, `3d-essentials`.

- [ ] **Matrice des rôles du roster 3DGen.** Définir les rôles réellement nécessaires, puis attribuer chaque responsabilité aux treize personnages 3DGen sans considérer qu'un ancien archétype Mixamo la remplit déjà. Vérifier les compositions utilisées par les batailles, la campagne et la Forge.\
  Skills: `godot-brainstorming`, `resource-pattern`, `state-machine`, `ai-navigation`, `godot-testing`.

- [x] **Contrats de données Hoplite V2.** Créer la définition partagée, l'état runtime mutable séparé et l'adaptateur en lecture depuis les profils V1. Aucun changement de gameplay.\
  Skills: `resource-pattern`, `component-system`, `gdscript-advanced`, `godot-testing`.

- [x] **Préparation et validation du package Hoplite V2.** Vérifier rig, os, poids, fragments, pivots, textures partagées et manifest ; publier dans un répertoire généré sans toucher aux sources. Le validateur générique pour les prochaines familles reste à extraire.\
  Skills: `assets-pipeline`, `addon-development`, `animation-system`, `godot-testing`.

- [x] **LOD 3D explicites du Hoplite.** Publier 22k/8k/2,5k sans doigts ni animations embarquées, réutiliser les textures canoniques, valider leur rest pose et leur donneur, puis les monter sous un seul squelette avec transitions natives de visibilité. Le LOD 2,5k reste réservé au très lointain.\
  Skills: `3d-essentials`, `assets-pipeline`, `animation-system`, `component-system`, `godot-testing`.

- [x] **Bake automatique Hoplite.** Inventorier les actions réellement consommées, supprimer les tracks de doigts et publier le donneur 23 os avec rapport de couverture. La séparation générique en packs commun/arme/spécial viendra avec la seconde famille.\
  Skills: `animation-system`, `assets-pipeline`, `gdscript-advanced`, `godot-testing`.

- [ ] **Socle EnemyActorV2.** Le mannequin Hoplite shadow, la présentation et l'animation sont installés hors factory de production. Restent le contrat combatant, le mouvement, le combat, l'anatomie visible et l'IA avant validation de ce gate.\
  Skills: `scene-organization`, `component-system`, `state-machine`, `ai-navigation`, `physics-system`, `animation-system`, `godot-testing`.

- [ ] **Pilote `spear_formation`.** Convertir d'abord `ngeneral`, exécuter V1 et V2 côte à côte avec les mêmes entrées, valider une phalange complète, puis activer `ngeneral_veteran` sur le même skin avec son profil de gameplay distinct.\
  Skills: `component-system`, `state-machine`, `ai-navigation`, `physics-system`, `animation-system`, `godot-optimization`, `godot-testing`.

  - [x] Banc Forge isolé : personnages Hoplite/Vétéran V2, choix d'animation sémantique et phalange animée de 48 unités ; affichage/LOD/animation uniquement, sans prétendre à la parité IA, combat ou démembrement.
  - [x] Tranche combat rapproché du Duel : sélection contextuelle des trois attaques de lance, déplacement pendant les frappes protégées, bouclier/collider ancrés ensemble et garde probabiliste générique avec stun/recul configurables.
  - [x] Tranche phalange jouable : preset 24 en 8 × 3, slots persistants, cohésion, ancre collective, premier rang combattant, budget de trois attaques et couloirs inter-phalanges ; V1 reste isolé.

- [ ] **Démembrement V2.** Intégrer fragments préfabriqués, état anatomique persistant, pools et budgets ; comparer chaque zone avec V1.\
  Skills: `physics-system`, `component-system`, `resource-pattern`, `godot-optimization`, `godot-testing`.

  - [x] Tranche Duel Hoplite : seuils anatomiques, neuf définitions de fragments, masque osseux persistant, hitboxes liées, perte lance/bouclier, impulsion et mort par section de tête.
  - [x] Stabilisation laboratoire : rebond nul, amortissement linéaire/angulaire et sommeil après atterrissage validé sur un fragment 3DGen réel.
  - [ ] Tranche masse : masque GPU exact `TEXCOORD_2.x`, comparaison visuelle des neuf coupes, pool partagé et budget global.

- [ ] **Factory générique et activation pilote.** Ajouter une API retournant le contrat combatant commun, installer le constructeur V2 et basculer `light_melee` derrière le catalogue. Garder le rollback V1 pendant au moins une campagne complète validée.\
  Skills: `dependency-injection`, `component-system`, `scene-organization`, `godot-testing`.

- [ ] **TroopRuntime et simulation tiers.** Extraire progressivement tactique, index spatial, engagements et budgets, puis activer `NEAR_CROWD`, `FORMATION`, `FAR_3D` avec hystérésis.\
  Skills: `ai-navigation`, `component-system`, `state-machine`, `godot-optimization`, `multithreading`, `godot-testing`.

  - [x] Première tranche `FORMATION` Hoplite : décisions partagées à cadence bornée, slots/cohésion/couloirs/attaques et physique membre 60/30/15/0 Hz selon le LOD.
  - [x] Coordination multi-troupes : secteurs stratégiques stables, ligne/soutien/escarmouche, reformation après pertes et promotion d'une nouvelle première ligne.
  - [ ] Rendu de masse lointain : conserver les acteurs interactifs proches ; utiliser MultiMesh seulement pour une représentation `FAR_3D` rigide, imposteur ou animation vertex-bakée, avec promotion vers un vrai acteur avant interaction.
  - [ ] Généraliser les profils de troupe, ajouter navigation d'ancre, index spatial, hystérésis complète et tiers `FAR_3D`/`IMPOSTOR`.

- [ ] **Migration des autres familles 3DGen.** Après le pilote Hoplite : light melee, ranged, heavy melee, command, boss humanoid, puis giant humanoid. Mixamo, loups et dinosaures restent hors scope. Chaque ligne peut revenir à V1 seule.\
  Skills: `component-system`, `state-machine`, `ai-navigation`, `physics-system`, `animation-system`, `godot-optimization`, `godot-testing`.

- [ ] **Imposteurs distants.** Générer des atlas raster multi-direction/action, assurer le fondu et la cohérence tactique, puis mesurer le gain dans les scènes de bataille.\
  Skills: `3d-essentials`, `2d-essentials`, `animation-system`, `shader-basics`, `godot-optimization`, `godot-testing`.

- [ ] **Retrait V1 et nettoyage documentaire.** Supprimer une branche V1 seulement lorsque tous ses consommateurs et sauvegardes sont migrés. Déplacer les documents historiques dans une archive indexée, puis publier une documentation autoritaire unique.\
  Skills: `godot-code-review`, `godot-testing`, `godot-optimization`.

## Gate obligatoire par famille

Une famille passe à `MIGRATED` seulement si :

- tous ses archétypes spawnent par la factory et gardent identité/faction/cibles ;
- déplacement, attaques, défenses, projectiles, phases et formations ont la parité attendue ;
- tous les clips requis sont couverts sans donneur runtime ;
- chaque zone anatomique et chaque incapacité restent persistantes à travers les tiers ;
- les captures proches et lointaines sont acceptées ;
- les sauvegardes Forge actuelles chargent encore ;
- les tests unitaires, scénarios mixtes et stress passent ;
- les métriques ne régressent pas, et le gain attendu est attribuable ;
- le rollback vers V1 est testé avant activation par défaut.

## Documentation

`docs/enemy_refactor/` reste une archive de preuves et de décisions du système V1 tant que ses références n'ont pas été classées. Aucun README n'est supprimé pendant la phase de fondation. À la fin de chaque famille, la matrice courante est mise à jour ; le nettoyage destructif n'arrive qu'après inventaire des liens et validation de l'utilisateur.
