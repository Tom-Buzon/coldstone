# Enemy V2 — commandement spatial hiérarchique des armées

Statut : **tranche pilote implémentée et mesurée le 1er septembre 2026**. Les fondations spatiales, les fronts en profondeur et la brèche locale sont actives sur Enemy V2 ; la représentation data-oriented complète reste une phase ultérieure. Le runtime V1 n'est pas modifié.

## État réellement livré

La carte Forge `champsDeBataille_V2_Commandement_414` est une copie dédiée du terrain V2. Elle contient 17 phalanges de 24 et un groupe de pression de 6, soit 414 soldats. La carte source n'est pas modifiée.

Cette tranche contient :

- un focus tactique stabilisé avec zone morte et temporisation de handoff ;
- quatre fronts de contact maximum, quatre soutiens et des réserves distribuées en profondeur plutôt qu'un anneau dense ;
- une empreinte orientée par formation sur une grille tactique clairsemée de `3 m` ;
- des corridors exclusifs, au maximum quatre simultanément, avec détour extérieur et ordre de marche versionné ;
- un ordre conservé au moins `900 ms` et une orientation de transit alignée sur la route ;
- une brèche locale `CLOSED → CANDIDATE → CHANNEL → FLANKED → CLOSING`, déclenchée seulement après franchissement confirmé du premier rang ;
- un diagnostic en jeu activé par `v2_command_lab`, montrant groupes, soldats, rôles, LOD, imposteurs, corridors, brèches, conflits d'ancrage et attaques dos à la cible ;
- des probes reproductibles pour 414 acteurs réels et 1 008 soldats stratégiques.

Le laboratoire 414 donne le snapshot initial stable suivant : quatre fronts, quatre soutiens, neuf réserves, un groupe de pression, `216` imposteurs, `198` représentations 3D, zéro conflit d'ancrage, zéro attaque à l'envers et zéro brèche fantôme. Après échauffement graphique, le déplacement réel distribue `208` soldats dans le batch imposteur. Le probe synthétique à 1 008 soldats traite 42 formations en environ `43 ms` pour la construction initiale du plan, puis le coût reste cadencé par groupes.

La passe de stabilité locale sépare désormais le focus stratégique de la menace immédiate. Une formation engagée vise la position réelle du joueur ; les attaquants sont choisis parmi les soldats physiquement les plus proches, doivent pivoter avant leur approche et ne peuvent déclencher le coup qu'à portée et dans leur cône avant. Les ancres de phalanges s'excluent mutuellement et les superpositions exactes sont résolues même lorsqu'un front est temporairement figé par le combat. Le canal d'une brèche confirmée couvre cinq colonnes autour de la pénétration afin de laisser un passage jouable sans dissoudre le reste du mur.

### Mesure graphique de référence

Mesure Compatibility/OpenGL sur une RTX 4060 Laptop, fenêtre de probe non limitée :

| Scénario | Moyenne | p95 | Draw calls | Primitives |
| --- | ---: | ---: | ---: | ---: |
| carte 414 complète | `10,438 ms` | `12,619 ms` | `2 567` | `809 110` |
| animations ennemies coupées après neutralisation de la physique membre | `6,825 ms` | `7,962 ms` | `1 582` | `595 408` |
| mêmes décor et joueur, ennemis masqués | `4,886 ms` | `5,951 ms` | `621` | `306 745` |

Cela correspond à environ 96 FPS en moyenne et 79 FPS au p95 sur cette machine, dans ce scénario automatisé. Ce n'est pas une garantie sur toute configuration, mais cela valide que 414 soldats ne ramènent plus le laboratoire à 5 FPS. Le prochain budget à réduire est maintenant explicite : animations/squelettes 3D proches et près de 1 946 draw calls propres aux ennemis, pas la décision d'armée.

### Limites conservées volontairement

- LOD3 masque et désactive les acteurs, mais leurs nœuds/squelettes restent en mémoire pour une réhydratation sûre ; la déshydratation data-oriented n'est pas encore livrée.
- Les corridors actuels conviennent au terrain ouvert du laboratoire. Le raccord à `NavigationServer3D` pour les obstacles topologiques reste à faire.
- Les phalanges ont les contrats communs nécessaires aux futurs archers, breakers et miniboss, mais ces rôles ne sont pas encore branchés.
- Les lignes partagent des axes et des ordres stables ; la cadence visuelle synchronisée d'une avancée par pas reste une amélioration de présentation.

## Décision

L'armée ne doit plus poursuivre la position instantanée du joueur ni essayer de ranger toutes ses formations sur des anneaux autour de lui. Elle doit occuper le terrain au moyen de **fronts stables**, de lignes de soutien, de réserves et de corridors réservés.

Une phalange tient ou déplace une ligne. Les petites unités attaquent le joueur. Les archers contrôlent une zone. Les réserves renforcent un front. L'armée choisit quelle formation remplit chaque fonction, mais ne pilote jamais un soldat.

Le système 1 / 2 / 3 / 4 phalanges reste une règle de **contact admis** :

- une phalange forme le front principal ;
- deux peuvent former un front et un contre-front, uniquement si le second possède une route sûre vers l'arrière ; sinon il prend un flanc oblique ;
- trois ferment un triangle de zones ;
- quatre ferment un carré de zones ;
- les formations supplémentaires restent distribuées en profondeur, dans de vrais blocs de soutien et de réserve. Elles ne prolongent pas un cercle autour du joueur.

Cette décision résout ensemble les croisements, les changements d'ordre incessants, les soldats qui présentent leur dos, l'ouverture trop précoce des phalanges et la disparition pratique du LOD imposteur.

## Audit du runtime avant cette tranche

Le découpage V2 existant est une bonne fondation : `EnemyV2BattleLayoutRuntime` raisonne par groupe, `HopliteV2TroopRuntime` possède les slots et les permissions d'attaque, et `EnemyActorV2` exécute les intentions. Les défauts viennent principalement du modèle spatial encore utilisé entre ces couches.

### Causes vérifiées

1. `EnemyV2BattleLayoutRuntime` place les quatre contacts à `5 m`, mais toutes les autres phalanges sur un anneau de soutien à `11,5 m`. Même une formation créée très loin reçoit donc finalement l'ordre de rejoindre le voisinage immédiat du joueur.
2. Le plan est reconstruit toutes les `350 ms` à partir de la position réelle du joueur. Les destinations restent ainsi centrées sur une cible extrêmement mobile au lieu d'être attachées à une zone tactique stable.
3. L'arrivée extérieure évite le centre par trois phases (`outer`, `orbit`, `assemble`), mais elle ne réserve ni l'empreinte de la troupe ni l'espace parcouru. Deux routes peuvent donc être individuellement plausibles tout en étant incompatibles ensemble.
4. Pendant une marche, l'ordre stratégique fournit à la fois une destination et une orientation. La phalange peut être orientée vers la cible alors que sa route l'oblige à se déplacer latéralement, puis changer brutalement d'axe lors du prochain ordre.
5. L'intrusion actuelle est une boîte orientée centrée sur toute la phalange, agrandie de `0,90 m` latéralement et `1,05 m` en profondeur. Entrer en contact avec la première ligne suffit facilement à être considéré comme « à l'intérieur ».
6. Tant que cette boîte est occupée, `_intrusion_slot_position()` redistribue immédiatement toute la troupe en deux ailes autour du joueur. Il n'existe ni franchissement de la première ligne, ni colonne de brèche locale, ni état candidat.
7. L'imposteur V2 est bien installé : au profil Performance actuellement sauvegardé, les seuils sont `10 / 26 / 65 m` et le batch tourne à `4 Hz`. Mais seuls les acteurs V2 contrôlés par une troupe rejoignent ce batch, et les formations lointaines reçoivent actuellement l'ordre de revenir à `11,5 m`. L'imposteur n'est donc souvent visible que pendant une transition brève.
8. Le fichier jouable `champsdebataille_v2_150.hoplite.json` contient actuellement **419 soldats**, répartis en 17 phalanges de 24, 5 duels V2 et une garde de 6. Son nom ne décrit plus son contenu réel ; ce n'est plus un scénario reproductible de 150 soldats.

Le batch actuel retire le rendu 3D, les animations et la physique actives au LOD3, mais conserve encore les nœuds et le squelette en mémoire pour permettre un retour instantané. C'est une transition utile, pas encore la représentation data-oriented finale.

## Invariants non négociables

1. Une seule autorité possède l'ordre stratégique d'une formation.
2. Une seule autorité possède son ancre et son orientation tactiques.
3. Une seule autorité possède sa réservation spatiale et son corridor.
4. Une formation ne reçoit pas un nouvel ordre à chaque mouvement du joueur.
5. Une formation en contact ne marche jamais de côté ou dos au joueur pour satisfaire un nouvel objectif lointain.
6. Deux empreintes ou corridors de phalanges ne peuvent pas être réservés au même endroit et au même moment.
7. Un contact frontal normal ne déclenche jamais une scission.
8. Une brèche reste un état interne d'une formation unique ; elle ne crée pas deux nouvelles formations pour l'armée.
9. Le gameplay logique d'une formation survit à tout changement de LOD.
10. Aucun soldat de formation ne calcule un chemin vers le joueur.
11. Aucun signal par soldat n'est émis à haute fréquence : les intentions de slots sont écrites dans des données mises en cache.
12. V1 reste inchangé et le nouveau commandement est activable uniquement pour les groupes Enemy V2.

## Architecture cible

### Arbre de scène

```text
WorldRuntime (Node3D)
├── EnemyV2BattlefieldRuntime (Node)
│   ├── TacticalFocusTracker (Node)
│   ├── ArmyDirector (Node)
│   │   ├── EngagementDirector (Node)
│   │   └── FormationTrafficScheduler (Node)
│   ├── TacticalOccupancyRuntime (Node)
│   ├── FormationRepresentationDirector (Node)
│   │   ├── Far3DBatch (MultiMeshInstance3D)
│   │   └── ImpostorBatch (MultiMeshInstance3D)
│   └── BattlefieldDebugOverlay (CanvasLayer, développement uniquement)
└── EnemyV2Groups (Node3D)
    ├── PhalanxController_001 (Node)
    │   ├── FormationBreachController (Node)
    │   └── EnemyActorV2 × N (CharacterBody3D au tier proche)
    └── FormationController_... (Node)
```

Les contrôleurs peuvent rester créés par `WorldRuntime`, comme aujourd'hui. L'arbre exprime les responsabilités ; il n'impose pas un gros singleton global ni un retour au monolithe.

### Responsabilités

| Élément | Possède | Ne possède jamais |
| --- | --- | --- |
| `TacticalFocusTracker` | position tactique stabilisée, zone courante, prédiction d'atterrissage, temporisations de handoff | positions de troupes |
| `ArmyDirector` | fronts actifs, rôles, priorités, ordres stables, profondeur soutien/réserve | slots ou soldats |
| `EngagementDirector` | admission aux zones de contact, remplacement et passage de relais | chemins ou mouvement |
| `TacticalOccupancyRuntime` | cellules occupées, empreintes, zones interdites | décisions tactiques |
| `FormationTrafficScheduler` | corridors temporels, priorités, attente et reroutage | vitesse des soldats |
| `FormationController` | ancre, orientation, cohésion, état collectif, slots, budget d'attaque | stratégie de l'armée |
| `FormationBreachController` | franchissement local, colonne de brèche, sous-sections temporaires | nouvelle formation d'armée |
| `FormationRepresentationDirector` | tier visuel/simulation, hydratation et déshydratation budgétées | décision tactique |
| `EnemyActorV2` proche | `velocity`, `move_and_slide()`, combat et présentation individuels | choix du secteur ou du chemin de troupe |

## Données et propriété

Les réglages éditables restent des `Resource` immuables et partagés. Les états de bataille mutables deviennent des `RefCounted` typés, jamais des Resources partagées mutées par accident.

### Resources partagés

- `FormationDefinition` : type, largeur, profondeur, rangs, vitesses, capacité de contact, rôles autorisés ;
- `FormationMovementProfile` : vitesse de marche, vitesse de pivot, marges, cadence, contraintes de corridor ;
- `FormationBreachProfile` : profondeurs d'entrée/sortie, durée de confirmation, largeur maximale du canal, coût de cohésion ;
- `TacticalRoleProfile` : contact, soutien, réserve, pression, tir, breaker ;
- `BattlefieldCommandProfile` : taille des cellules, hystérésis du focus, délais d'ordres, capacités par front ;
- `FormationLodProfile` : seuils et représentations disponibles.

### États mutables typés

- `FormationState` : identifiant, effectif, ancre, orientation, cohésion, statut, pertes et ordre courant ;
- `FormationOrder` : identifiant/révision, rôle, pose cible, politique d'orientation, chemin, réservation, date minimale de révision ;
- `FormationFootprint` : polygone/rectangle orienté, marge et cellules couvertes ;
- `CorridorReservation` : propriétaire, cellules, priorité, fenêtre temporelle et expiration ;
- `EngagementFrame` : origine stabilisée, axes avant/droite, fronts et zones de contact ;
- `MemberState` : vie, disponibilité, place logique, état anatomique persistant.

L'ordre est un contrat complet, pas un simple `anchor_goal` recalculé. Une formation refuse une révision avant `min_hold_until`, sauf ordre d'urgence explicite : destruction, obstacle invalide, véritable brèche, sortie de zone ou handoff confirmé.

## Le repère tactique stable

Le système conserve trois positions distinctes :

- `raw_player_position` pour le combat local ;
- `predicted_landing_position` pour anticiper sans agir trop tôt ;
- `tactical_focus` pour l'armée.

Le `tactical_focus` ne suit pas chaque frame. Il change quand le joueur :

- reste au sol dans une nouvelle zone pendant une durée configurable ;
- dépasse une limite de secteur avec une marge d'hystérésis ;
- ou s'éloigne suffisamment pour rendre le front courant invalide.

Un saut, dash ou wall-run ne provoque donc aucune réorganisation globale. Les soldats proches peuvent réagir immédiatement ; la phalange concernée réagit ensuite ; l'armée attend la confirmation d'un changement de zone.

Quand le joueur quitte un secteur, l'ancien front ne le poursuit pas indéfiniment : l'`EngagementDirector` effectue un **handoff**. Une formation déjà correctement placée dans la nouvelle zone intercepte, tandis que l'ancienne se désengage, se reforme puis retourne en soutien.

## Des fronts, pas un cercle

Un `EngagementFrame` contient jusqu'à quatre fronts orientés. Chaque front est une bande de terrain composée de :

```text
RESERVE RANG 2   [P]   [P]   [P]
RESERVE RANG 1   [P]   [P]   [P]
SOUTIEN          [P]   [P]
CONTACT          [P]        zone joueur
```

Les formations d'une même ligne partagent :

- un axe de front ;
- une profondeur commune ;
- un rythme de marche ;
- des espacements latéraux calculés à partir de leurs empreintes réelles.

Le front peut avancer par pas synchronisés : marche parallèle de quelques mètres, arrêt, fermeture des rangs, puis nouveau pas. Ce mouvement collectif produit l'impression d'une ligne militaire orchestrée, contrairement à plusieurs groupes convergeant individuellement vers un point.

Les formations au-delà des quatre contacts sont distribuées dans les rangs de profondeur par empaquetage spatial stable. Elles restent attachées à une zone du champ de bataille et ne suivent pas le joueur à `11,5 m`. Une grande partie peut donc rester naturellement en LOD2/LOD3.

## Occupation et trafic des formations

### Grille tactique

Une grille clairsemée de cellules d'environ `3 m` complète le NavMesh. Elle ne remplace pas la navigation du sol ; elle représente l'occupation militaire :

- libre ;
- empreinte de formation ;
- corridor de marche ;
- zone de contact du joueur ;
- voie de fantassins ;
- zone de tir ;
- obstacle ou terrain interdit.

La grille n'est jamais reconstruite intégralement par frame. Chaque formation mémorise les cellules de son empreinte et seules les cellules modifiées par un nouvel ordre sont libérées/réservées.

### Corridor

Avant de marcher, une formation demande un chemin d'ancre. Sur terrain ouvert, le planificateur utilise la grille. Avec de vrais obstacles topologiques, il effectue une requête `NavigationServer3D` pour l'ancre de formation, puis élargit la polyligne de la moitié de sa largeur plus une marge.

Le corridor est le volume balayé par l'empreinte, y compris les pivots. Il est réservé avant le mouvement. En cas de conflit, le scheduler choisit selon :

1. urgence tactique ;
2. rôle ;
3. formation déjà engagée dans le corridor ;
4. coût de détour ;
5. ancienneté de la demande.

Le perdant reçoit `WAIT`, `YIELD` ou une route alternative. Il ne tente jamais de traverser en espérant que les soldats s'évitent localement.

### Marche et orientation

L'ordre déclare une seule politique d'orientation :

- `FACE_ROUTE` pendant le transit ;
- `FACE_FIXED_AXIS` pour une marche parallèle de front ;
- `FACE_THREAT` seulement en déploiement/contact.

Une phalange en transit regarde la tangente de sa route. Arrivée dans sa zone de préparation, elle s'arrête, pivote sur place, referme ses rangs puis entre en contact. Elle ne pivote pas continuellement vers le joueur tout en essayant de contourner d'autres troupes.

Un demi-tour valide conserve les places mondiales des membres, comme le correctif V2 actuel, mais il devient une transition explicite de déploiement et non une conséquence immédiate d'un objectif qui a changé de côté.

## Machine d'état d'une formation

La complexité justifie une machine hiérarchique :

```text
RESERVE
├── HOLD
└── READY

MANEUVER
├── REQUEST_CORRIDOR
├── MARCH
├── STAGE
└── DEPLOY

ENGAGED
├── HOLD_LINE
├── PRESS
├── BREACH_CANDIDATE
├── CHANNEL_OPEN
└── FLANKED

RECOVERY
├── CLOSE_CHANNEL
├── REFORM
└── DISENGAGE
```

Chaque transition possède `enter`, `exit`, une durée minimale et une cause enregistrée. Deux états parallèles ne peuvent pas écrire la même ancre ou la même orientation.

## Pénétration correcte d'une phalange

Le contact n'est pas une intrusion. La détection doit utiliser les plans réels des rangs dans le repère local de la phalange.

Pour le joueur, on calcule :

- `lateral = to_player dot right` ;
- `depth = to_player dot forward` ;
- le plan du premier rang ;
- le plan arrière ;
- la hauteur des pieds et l'état au sol.

Le déroulement est :

1. `HOLD_LINE` : le joueur est devant le plan du premier rang ; la ligne reste complètement fermée, même au contact des boucliers.
2. `BREACH_CANDIDATE` : le joueur franchit réellement le plan du premier rang d'une profondeur minimale, dans la largeur de la formation. Une courte confirmation et une hystérésis évitent les oscillations.
3. Si le joueur est en l'air, la phalange suit localement la menace mais n'ouvre pas toute sa ligne. La confirmation attend l'atterrissage ou un franchissement vertical incontestable.
4. `CHANNEL_OPEN` : seule la colonne la plus proche du point de passage et au maximum une colonne adjacente s'écartent. Le reste de la phalange continue d'être un mur affrontable.
5. Si le joueur progresse entre le premier et le dernier rang, le canal peut s'élargir graduellement. La formation reste une seule entité et conserve toute son empreinte dans la grille.
6. Si le joueur ressort derrière le dernier rang et y reste, la formation devient `FLANKED`. Elle effectue une réaction locale ou un demi-tour ordonné, tandis que l'armée prépare éventuellement un handoff.
7. Quand le canal est libre, `CLOSE_CHANNEL` puis `REFORM` ramènent les mêmes membres dans leurs slots sans échange de côtés.

La brèche mémorise la colonne de passage, pas la position instantanée du joueur. Elle ne reconstruit donc pas deux ailes tournant sans cesse autour de lui.

La cohésion devient une vraie ressource : une brèche, une attaque lourde, une perte du premier rang ou un demi-tour sous pression la réduisent. Sous certains seuils, la phalange élargit ses trous, se replie ou devient un petit bataillon, au lieu de conserver artificiellement une géométrie parfaite.

## Rôles futurs

### Petits bataillons et soldats isolés

Ils utilisent le rôle `PRESSURE/HERDER`. Ils peuvent agir pendant que quatre phalanges occupent les contacts, mais empruntent des voies étroites explicitement réservées entre les empreintes. Ils ne traversent jamais un mur de boucliers.

Leur objectif de placement inclut un vecteur de poussée vers une phalange active. Ils réduisent l'espace du joueur sans tous converger vers la même coordonnée. Leur combat reste limité par des slots de mêlée et des permissions d'attaque.

### Archers

Ils occupent une bande de soutien protégée. Leur ordre réserve une zone de tir et un corridor de ligne de vue. Ils ne participent pas aux quatre contacts et ne se déplacent pas pour compléter un cercle.

### Miniboss et unités de rupture

Un rôle `BREAKER/DUELIST` peut demander une voie spéciale. Les phalanges voisines maintiennent ou ouvrent temporairement un passage réservé ; le boss ne traverse pas quarante alliés. Le corridor reste compatible avec le même scheduler.

## LOD et représentation data-oriented

Le niveau de simulation doit être choisi **par formation**, avec éventuellement une exception locale pour les quelques membres au contact. Cela évite qu'une moitié de phalange soit en 3D et l'autre en imposteurs.

| Tier | Représentation | Simulation |
| --- | --- | --- |
| `FULL` | vrais `EnemyActorV2` | combat, collisions, garde, démembrement |
| `NEAR_CROWD` | acteurs 3D LOD | slots et actions cadencés, physique réduite |
| `FORMATION_3D` | low mesh/VAT ou poses 3D batchées | état collectif et transforms de slots |
| `IMPOSTOR` | atlas directionnel dans un `MultiMesh` | ancre, slots et état agrégé à basse fréquence |
| `DORMANT` | aucune représentation | rare mise à jour stratégique |

La première migration conserve les acteurs masqués comme aujourd'hui, afin de sécuriser le retour au combat. La seconde déplace vie, pertes, anatomie, slots et transform dans `FormationState`/`MemberState`, puis détruit ou met en pool les acteurs lointains. Le retour proche réhydrate uniquement le budget autorisé par frame.

L'imposteur actuel à quatre frames et vue frontale reste un prototype valide. La cible est un atlas de plusieurs directions et de quelques états lisibles : marche, garde, contact, perturbé. Il n'est pas nécessaire de produire une animation unique par soldat.

### Pourquoi l'imposteur est peu visible dans le laboratoire actuel

- le profil Performance est bien chargé (`10 / 26 / 65 m`) ;
- les groupes contrôlés par une troupe peuvent bien atteindre le batch partagé ;
- mais toutes les formations de soutien sont rappelées vers `11,5 m` du joueur ;
- les cinq duels V2 de la carte ne sont pas éligibles au batch de troupe ;
- aucune vue de diagnostic ne montre le nombre d'imposteurs actifs ou le tier de chaque groupe.

Le nouveau laboratoire doit garder plusieurs réserves à plus de `65 m`, afin que le LOD3 soit un état durable et mesurable, pas une image fugitive pendant l'approche.

## Cadences et budget

| Niveau | Cadence cible | Travail autorisé |
| --- | ---: | --- |
| combat local | physique/60 Hz | mouvement et interactions des rares acteurs FULL |
| slots proches | 20–30 Hz | suivi O(1) d'une intention mise en cache |
| formation engagée | 8–10 Hz | cohésion, brèche, attaques, slots |
| formation distante | 1–2 Hz | progression d'ordre et état agrégé |
| engagement | 2–4 Hz | admissions, handoffs, rôles |
| plan d'armée | 0,5–1 Hz ou événement | fronts et profondeur |
| occupation/corridor | à l'émission d'un ordre | cellules modifiées uniquement |
| imposteurs | 2–4 Hz | transforms batchés |

Avec 1 000 soldats en phalanges de 24, le niveau armée traite environ 42 formations et non 1 000 IA. Les traitements restent déphasés. Les conteneurs du hot path sont typés et réutilisés ; aucune recherche de groupe, construction de Dictionary ou allocation de chemin n'a lieu par soldat et par frame.

## Signaux et appels

Les signaux servent aux événements rares. Les données de mouvement fréquentes utilisent des méthodes directes sur des références explicitement injectées.

| Émetteur | Signal | Récepteur | Usage |
| --- | --- | --- | --- |
| `TacticalFocusTracker` | `tactical_zone_changed(frame)` | `ArmyDirector` | recalcul d'un plan après stabilité |
| `ArmyDirector` | `formation_order_issued(id, order)` | `FormationController` | nouvel ordre versionné |
| `FormationTrafficScheduler` | `corridor_granted(id, token)` | `FormationController` | autorisation de marche |
| `FormationController` | `status_changed(id, status)` | `ArmyDirector` | arrivée, blocage, destruction, reformation |
| `FormationBreachController` | `breach_started(id, info)` | `EngagementDirector` | geler l'empreinte et empêcher une admission dans le canal |
| `FormationBreachController` | `breach_resolved(id)` | `EngagementDirector` | libérer la contrainte locale |
| `FormationRepresentationDirector` | `tier_changed(id, tier)` | outils/présentation | hydratation budgétée et diagnostic |

Il n'existe pas de `soldier_slot_changed` émis 1 000 fois. Le contrôleur remplit un tableau d'intentions stable que les acteurs lisent.

## Flux de données

### Marche normale

```text
position joueur
→ TacticalFocusTracker (stabilisation)
→ ArmyDirector (front/rôle)
→ EngagementDirector (admission)
→ TrafficScheduler (chemin + corridor)
→ FormationOrder versionné
→ FormationController (ancre/orientation/slots)
→ EnemyActorV2 proche ou batch lointain
```

### Brèche

```text
position locale du joueur
→ FormationBreachController
→ BREACH_CANDIDATE
→ confirmation derrière le premier rang
→ ouverture des seules colonnes concernées
→ statut agrégé envoyé à l'EngagementDirector
→ empreinte globale conservée
→ fermeture et reformation
```

### Changement de zone

```text
jump/dash : réaction locale seulement
→ atterrissage stable dans une autre zone
→ handoff confirmé
→ nouveau front intercepte
→ ancien front se désengage
→ réservations mises à jour sans poursuite générale
```

## Migration progressive

### Phase 0 — laboratoire et observabilité

- figer une copie de référence de la carte ;
- afficher la population réelle, le nombre de formations et le profil LOD actif ;
- afficher par couleur rôle, état, tier, empreinte, corridor et objectif ;
- afficher `impostor_batch.active_count`, acteurs FULL, squelettes actifs, draw calls, temps de décision et conflits de réservation ;
- permettre de forcer le tier d'une formation sélectionnée ;
- conserver des réserves de test à `80`, `120` et `180 m`.

### Phase 1 — contrats typés sans changement visuel

- introduire `FormationState`, `FormationOrder`, `FormationFootprint` et les profils Resources ;
- adapter l'inscription actuelle de `WorldRuntime` ;
- garder `EnemyV2BattleLayoutRuntime` derrière un adaptateur de compatibilité ;
- couvrir les propriétaires uniques par des probes.

### Phase 2 — focus stable, fronts et profondeur

- installer `TacticalFocusTracker` et les handoffs ;
- remplacer l'anneau de soutien par des bandes contact/soutien/réserve ;
- synchroniser les avances parallèles ;
- conserver les ordres avec durée minimale et hystérésis.

### Phase 3 — empreintes et trafic

- ajouter la grille clairsemée ;
- réserver empreintes et corridors ;
- brancher une requête de chemin par formation lorsqu'un obstacle l'exige ;
- interdire toute admission dont la route n'est pas accordée.

### Phase 4 — exécution militaire de la phalange

- séparer transit, préparation, pivot, contact et désengagement ;
- appliquer les politiques d'orientation ;
- maintenir les lignes parallèles et les slots sans croisement.

### Phase 5 — vraie mécanique de brèche

- retirer la boîte d'intrusion actuelle ;
- détecter le franchissement du premier rang ;
- ouvrir un canal local progressif ;
- conserver une seule formation et une seule empreinte ;
- intégrer cohésion, fermeture et état `FLANKED`.

### Phase 6 — représentation de formation

- déplacer les données persistantes hors des acteurs ;
- choisir le tier par formation ;
- budgéter hydratation/déshydratation ;
- étendre l'atlas directionnel ;
- valider qu'une réserve LOD3 ne réactive aucun squelette ou combat individuel.

### Phase 7 — autres armes et rôles

- intégrer `PRESSURE/HERDER` ;
- ajouter archers et corridors de tir ;
- ajouter `BREAKER/DUELIST` ;
- réutiliser occupation, trafic, ordres et LOD sans dupliquer le directeur.

Chaque phase est protégée par un drapeau V2 et garde l'ancien `EnemyV2BattleLayoutRuntime` comme fallback jusqu'à validation. Aucun archétype V1 n'entre dans ce système.

## Laboratoire de validation

Le scénario de référence doit être distinct de la carte de travail à 419 soldats ou posséder un manifeste qui ignore explicitement les groupes expérimentaux.

| Scénario | Résultat obligatoire |
| --- | --- |
| frontal 10 s | aucune ouverture de phalange |
| passage de 0,3 m derrière les boucliers | toujours aucune brèche |
| franchissement confirmé du premier rang | canal local, pas deux demi-armées |
| saut au-dessus puis retour devant | aucune réorganisation d'armée |
| atterrissage durable derrière | réaction locale puis handoff temporisé |
| 1 / 2 / 3 / 4 contacts | front / opposition ou flanc / triangle / carré lisibles |
| arrivée d'une cinquième troupe | contourne, se prépare, attend son corridor, ne traverse personne |
| déplacement rapide vers une autre troupe | la plus pertinente intercepte ; l'ancienne ne chasse pas à travers la carte |
| demi-tour | chaque membre tourne sur place, sans échange gauche/droite |
| 8, 20 et 42 formations | au plus quatre contacts ; réserves en profondeur ; aucun corridor superposé |
| LOD3 | plusieurs groupes durablement imposteurs, compteur non nul et retour sans perte d'état |
| 1 008 soldats synthétiques | coût du commandement borné par 42 groupes, sans boucle par soldat |

### Critères de lisibilité

- aucune formation en contact ne présente son dos au joueur ;
- une formation en transit montre clairement qu'elle marche vers une zone de préparation ;
- les lignes voisines avancent parallèlement avec une cadence commune ;
- une brèche reste locale, ouvre un passage réellement praticable et ne détruit pas l'identité du mur ;
- les réserves forment de vrais blocs visibles au loin au lieu d'un anneau dense ;
- les petites unités utilisent les ouvertures sans se superposer aux phalanges.

## Ordre recommandé de la prochaine implémentation

La prochaine passe ne doit pas commencer par une nouvelle IA de soldat ni par un atlas supplémentaire. Elle doit livrer ensemble :

1. le diagnostic visuel du laboratoire et un scénario reproductible ;
2. les quatre types de données `FormationState`, `FormationOrder`, `FormationFootprint`, `CorridorReservation` ;
3. le `TacticalFocusTracker` ;
4. les fronts et réserves qui remplacent l'anneau à `11,5 m` ;
5. un premier corridor réservé entre une réserve et une zone de préparation.

Ensuite seulement, la détection de brèche et la machine de mouvement seront remplacées sur une phalange pilote. Cette tranche suffit déjà à vérifier le ressenti militaire, l'absence de croisements et l'activation durable des imposteurs avant d'étendre le chantier.
