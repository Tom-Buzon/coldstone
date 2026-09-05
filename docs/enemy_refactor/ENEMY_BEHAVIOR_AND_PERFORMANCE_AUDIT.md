# Système des ennemis — comportement, psychologie collective et audit de performance

> Mise en œuvre du lot sûr : voir `ENEMY_RUNTIME_PERFORMANCE_IMPLEMENTATION_REPORT.md`. Les incohérences psychologiques restent volontairement hors périmètre de cette passe.

> État analysé : code présent dans la copie de travail au 28 août 2026.\
> Portée : ennemis, alliés contrôlés par l'IA, phalanges, ciblage, navigation, engagement, combat, blessures, animation et effets associés.\
> Nature du document : audit en lecture seule. Il ne décrit aucune correction déjà appliquée par cet audit.

## 1. Résumé exécutif

Le système actuel applique déjà plusieurs des bonnes pratiques du conseil générique fourni : les décisions tactiques ne sont plus calculées à chaque frame, les réveils sont désynchronisés, les références principales sont mises en cache, la séparation utilise une grille spatiale et les responsabilités collectives importantes ont été regroupées dans `HopliteBattleCrowdDirector`.

Le nombre brut d'appels par frame reste néanmoins élevé. Cela ne vient pas d'une seule erreur, mais de quatre familles de coûts :

1. des recherches globales subsistent dans les décisions individuelles, surtout pour le choix des cibles ;
2. chaque agent NavMesh vérifie trop souvent des informations globales qui pourraient être partagées ou mises en cache ;
3. les phalanges reconstruisent plusieurs structures temporaires et effectuent encore certains travaux en O(n²) ;
4. des tâches visuelles, anatomiques, de terrain ou d'équipement continuent à tourner par unité alors qu'elles pourraient être cadencées, conditionnées ou mutualisées.

Les trois améliorations à mesurer en premier sont donc :

- un index de cibles maintenu par événements et consultable spatialement, commun à toutes les scènes de bataille ;
- la mise en cache de l'état des cartes de navigation et, pour une phalange, un chemin grossier partagé par cohorte plutôt qu'un `NavigationAgent3D` autonome par soldat ;
- une représentation persistante et typée des cohortes de phalange, supprimant les scans de groupe, les comptages O(n²) et la plupart des duplications de dictionnaires.

Il faut cependant résister à une fausse métrique : diminuer le nombre d'appels n'est pas automatiquement diminuer le temps CPU. Un appel natif à `PhysicsDirectSpaceState3D.intersect_ray()`, un `move_and_slide()`, un tri ou une allocation coûte beaucoup plus qu'un simple accès à un booléen GDScript. Chaque proposition ci-dessous doit donc être validée avec des compteurs d'appels **et** les temps propres/cumulés du profiler.

## 2. Architecture réelle du système

### 2.1 Vue d'ensemble

```text
EnemyFactory + EnemySpawnRequest + EnemyArchetypes
                         |
                         v
             HopliteAthenianEnemy
             CharacterBody3D racine
             - ciblage et intention tactique
             - défense, attaque et dégâts
             - blessures et mort
             - animation/LOD/équipement
             - propriétaire unique de velocity et move_and_slide()
                         |
            +------------+-------------+
            |                          |
            v                          v
EnemyNavigationComponent       BattleCrowdDirector
(RefCounted, donne une          - grille spatiale
intention, ne déplace pas)      - anneaux d'engagement
            |                   - capacité d'attaque
            v                   - phalanges et sorties
NavigationAgent3D optionnel     - nettoyage périodique
```

Le contrôleur `HopliteAthenianEnemy` est commun aux 22 archétypes. Le comportement n'est donc pas réparti entre 22 scripts distincts : il est sélectionné par un profil de données et par des branches de comportement dans le même contrôleur. C'est un avantage pour l'uniformité, mais ce fichier concentre aussi ciblage, mouvement, combat, animation, anatomie et comportements spéciaux. Il constitue à la fois la façade d'intégration et le principal point chaud à surveiller.

La racine `CharacterBody3D` est l'unique propriétaire du mouvement. `EnemyNavigationComponent` calcule une direction souhaitée ; il ne modifie pas directement la position. Cette règle évite les doubles mouvements et les conflits entre navigation, formation et physique.

### 2.2 Fréquences actuelles

| Travail | Fréquence approximative | Remarque |
|---|---:|---|
| `_physics_process()` et mouvement | 60 Hz par défaut | Nécessaire pour la physique, les contacts, les timers courts et `move_and_slide()` |
| Réflexion tactique proche, hors masse | toutes les 0,045 s, ~22 Hz | But, cible et séparation mis en cache entre deux réflexions |
| Réflexion tactique éloignée, hors masse | toutes les 0,085 s, ~12 Hz | Réduction déjà appliquée |
| Réflexion tactique masse proche | toutes les 0,055 s, ~18 Hz | Activée à partir du seuil de masse |
| Réflexion tactique masse intermédiaire | toutes les 0,10 s, 10 Hz | — |
| Réflexion tactique masse lointaine | toutes les 0,18 s, ~5,5 Hz | — |
| Reconstruction de la grille spatiale | toutes les 0,05 s, 20 Hz | Scan du groupe `combatant_ai` |
| Rééquilibrage des anneaux d'engagement | 10 Hz | Par cible |
| Actualisation des phalanges | jusqu'à 20 Hz | Avec cache, mais calculs et allocations encore importants |
| Nettoyage du directeur | toutes les 0,55 s | Participants, baux d'attaque et caches |
| Actualisation LOD ennemie | 0,14 ou 0,20 s | Les valeurs de réglage sont relues par chaque ennemi |
| Pose d'équipement de phalange | chaque frame rendue | Même pour certains LOD très éloignés |
| Navigation locale | chaque tick physique | Destination sémantiquement dédupliquée, mais état de carte revérifié souvent |

Les timers initiaux d'attaque, de réflexion et de LOD sont déjà randomisés. Cette désynchronisation empêche une armée entière de se réveiller exactement sur la même frame.

## 3. Comparaison avec les dix conseils génériques

### 3.1 Ne pas exécuter toute l'IA à chaque frame

**Verdict : d'accord, déjà largement appliqué.**

Les décisions tactiques sont cadencées entre environ 5,5 et 22 Hz suivant la distance et le mode de masse. Leur résultat est conservé entre deux réflexions. Le mouvement, la gravité, les contacts, les fenêtres d'attaque et la progression du chemin restent à 60 Hz, ce qui est sain : les baisser aveuglément rendrait les collisions et le combat irréguliers.

Améliorations encore possibles :

- cadencer ou supprimer les callbacks visuels inutiles au LOD 3 ;
- ne recalculer les corrections anatomiques que lorsqu'un état de membre change ;
- actualiser les surfaces de géants seulement quand leur pose ou leur transform pertinent change ;
- prévoir un niveau de simulation dormant pour les vagues réellement inactives, hors écran et hors combat.

### 3.2 Répartir les mises à jour sur plusieurs frames

**Verdict : d'accord, déjà appliqué partiellement.**

Les timers initiaux sont désynchronisés et plusieurs ponts d'animation utilisent des strides. La grille du directeur possède aussi sa propre cadence. Le reste à gagner se situe moins dans un modulo arbitraire par ennemi que dans un ordonnancement centralisé : une cohorte ou une tranche d'unités peut être traitée par bucket à chaque tick, avec une limite de budget.

Un bucket central est préférable pour les travaux non critiques comme les évaluations de LOD, la sélection opportuniste de cibles lointaines et les vérifications de terrain des archers. Les réactions immédiates — coup reçu, cible morte, collision, sortie de portée au moment de l'impact — doivent rester événementielles ou physiques.

### 3.3 Mettre en cache les références

**Verdict : d'accord, bonne couverture locale, lacunes collectives.**

Le joueur, le joueur de bataille, les racines visuelles, le squelette, le pilote d'animation et le composant de navigation sont généralement conservés. Les chargements réalisés dans `_ready()` ne sont pas le principal problème en régime stable.

Les recherches encore coûteuses sont surtout :

- les scans de groupes pour trouver des cibles adverses ;
- la reconstruction de la liste `combatant_ai` par le directeur ;
- les scans des membres `phalanx_unit` lors d'une reconstruction de cohorte ;
- la découverte répétée d'enfants géométriques/particules lors de transitions de LOD ;
- certaines références de service et valeurs `ProjectSettings` relues périodiquement par chaque unité.

### 3.4 Remplacer les scans globaux par des structures spatiales

**Verdict : d'accord, amélioration majeure encore disponible.**

La séparation locale ne fait plus un scan N×N global : le directeur maintient une grille de cellules de 3 m et interroge les cellules voisines. En revanche, le choix des cibles reste largement un scan de faction : un allié parcourt les ennemis et un ennemi, après avoir considéré le joueur, parcourt les alliés spartiates. Pour deux armées nombreuses, le coût redevient proche de N×M à chaque cycle de réflexion.

La solution recommandée est un index de participants maintenu par inscription/désinscription, subdivisé par faction et par cellule. Une unité demanderait d'abord les adversaires dans un rayon local ; un scan plus large ne servirait que de repli si aucun candidat local n'existe. La vengeance, l'hystérésis de cible et la pénalité de cible déjà très réclamée doivent être conservées, car elles constituent une partie utile de la psychologie actuelle.

Le `CombatantRegistry` existant ne peut pas être promu silencieusement en autorité globale : il n'est actuellement branché que dans le Combat Lab et des écarts historiques de participation entre routes de scène ont conduit le ciblage à rester basé sur les groupes. Il faut d'abord rendre son installation et ses règles de présence identiques dans toutes les scènes.

### 3.5 Éviter les accès à l'arbre et la réflexion dynamique dans les boucles chaudes

**Verdict : d'accord.**

Les accès directs sont déjà nombreux, mais il reste beaucoup de `has_method()`, `call()` et `is_instance_valid()` autour d'objets typés simplement `Node`. Ils offrent de la souplesse aux différentes scènes, mais coûtent cher lorsqu'ils sont répétés par unité et par tick.

Les gains les plus sûrs seraient :

- typer le directeur et ses principales APIs ;
- mettre en cache les capacités d'une cible lors du changement de cible au lieu de les redécouvrir à chaque usage ;
- remplacer les contrats de hot path par des méthodes directes ou des interfaces clairement délimitées ;
- garder les signaux pour les événements rares, pas pour transmettre le mouvement à chaque frame.

### 3.6 Utiliser le typage GDScript

**Verdict : d'accord, partiellement appliqué.**

Les fonctions et variables principales sont déjà typées. Les coûts restants viennent surtout des `Dictionary`, `Array` non typés et valeurs `Variant` utilisés comme états temporaires : but tactique, assignation de phalange, données de participant, baux, descripteurs de cohorte.

Il serait pertinent d'introduire de petites classes `RefCounted` typées ou des structures persistantes pour ces états. Il ne serait pas pertinent d'ajouter plusieurs nouveaux `Node` avec leurs propres callbacks à chaque ennemi : cela augmenterait précisément le nombre d'appels que l'on cherche à réduire.

### 3.7 Réduire les allocations temporaires

**Verdict : d'accord, axe prioritaire.**

Exemples actuels :

- la requête de voisins crée un tableau, puis l'ennemi le recopie avec `assign()` ;
- les scans de groupes créent des tableaux de candidats ;
- les phalanges emploient `duplicate(true)`, `keys()`, `slice()`, `map()`, tris avec lambdas et signatures textuelles ;
- la file d'attente des attaques est recopiée/validée et utilise `pop_front()` ;
- plusieurs VFX créent à la volée nœud, mesh et matériau ;
- chaque projectile est instancié séparément.

Des buffers réutilisables, des collections persistantes invalidées par version, une file avec index de tête, des pools de projectiles/VFX et des meshes/matériaux partagés réduiraient la pression du ramasse-miettes. Les matériaux animés individuellement devront toutefois conserver un état par instance ou utiliser des paramètres de shader par instance.

### 3.8 Utiliser les distances au carré

**Verdict : d'accord pour les seuils simples, déjà appliqué à plusieurs endroits.**

Il reste des `length()`/`distance_to()` répétés dans la séparation, l'arrivée de navigation, l'aggro et certaines validations de portée. Une comparaison au carré évite la racine carrée lorsqu'on teste uniquement un seuil.

Cette substitution ne doit pas modifier un score où la distance réelle participe à une somme avec d'autres grandeurs, ni une normalisation où la longueur sera de toute façon nécessaire. Il faut aussi préserver exactement les hystérésis de portée et d'aggro.

### 3.9 Espacer les raycasts de perception

**Verdict : conseil générique peu applicable à la perception actuelle, mais très pertinent pour les archers.**

Les ennemis ne lancent pas un raycast de visibilité générale à chaque frame. Ils peuvent donc détecter une cible à travers un mur en fonction de la distance et du groupe ; le problème actuel n'est pas un excès de raycasts de perception, mais l'absence d'une perception avec occlusion si le game design en souhaite une.

En revanche, l'archer recherche périodiquement une hauteur avec environ 16 échantillons de sol, auxquels peuvent s'ajouter les échantillons de chemin. Sa contrainte de mouvement sur terrain sûr peut encore lancer jusqu'à deux raycasts de sol par tick physique. À 24 archers, cette seconde partie peut théoriquement atteindre 2 880 raycasts par seconde avant même le reste du jeu.

Les tests de voie de projectile juste avant l'engagement et au moment du lâcher sont justifiés : ils empêchent de tirer à travers un allié ou un obstacle qui vient de bouger. Il vaut mieux conserver cette revalidation temporelle et optimiser la recherche de terrain : cache spatial de hauteur, données NavMesh, échantillonnage cadencé par groupe, ou résultats réutilisés tant que l'archer n'a pas quitté la cellule.

### 3.10 Centraliser ce qui est collectif

**Verdict : d'accord, architecture déjà engagée dans cette direction.**

Le directeur centralise déjà la grille, les anneaux autour des cibles, les baux d'attaque, les phalanges, les sorties coordonnées et une partie du nettoyage. Les prochains candidats naturels sont :

- l'index de cibles par faction ;
- l'état utilisable des cartes NavMesh ;
- le chemin grossier d'une cohorte de phalange ;
- le cache de pression autour d'une cible ;
- les requêtes de terrain des archers ;
- les métriques et budgets de simulation.

Le directeur doit rester attaché à la scène de bataille, pas devenir automatiquement un autoload mondial. Cela évite les fuites d'état entre le laboratoire, la forge et une vraie bataille. La psychologie individuelle — vengeance, peur, phase de boss, défense, blessure — doit rester dans l'unité ou son état local.

## 4. Liste priorisée des améliorations possibles

Le niveau de priorité ci-dessous exprime un **potentiel à mesurer**, pas une promesse de gain déjà démontrée.

### P1 — coûts structurels à profiler en premier

#### 4.1 Mettre en cache l'état de navigation de la carte

`EnemyNavigationComponent.sample_intent()` vérifie l'état de la carte à chaque tick. La vérification interroge `NavigationServer3D.map_get_regions()` puis parcourt les régions et leurs couches. Cette information est globale à une carte mais son coût est payé par agent.

Amélioration possible : conserver un état par RID de carte et par masque de couches, invalidé lors d'un changement de carte/région ou actualisé à basse fréquence. L'appel à `get_next_path_position()` doit, lui, rester dans le tick physique lorsque l'agent NavMesh est actif, conformément au fonctionnement attendu de `NavigationAgent3D`.

Mesures : nombre d'appels `map_get_regions`, temps dans `sample_intent`, nombre d'agents actifs et coût avec 12/36/56 unités NavMesh.

#### 4.2 Partager le chemin grossier d'une phalange

Lorsque le NavMesh est disponible, chaque soldat de phalange reçoit actuellement son propre agent. Pourtant, la cohorte poursuit un même ancrage et chaque membre possède déjà une place locale stable.

Amélioration possible : un leader ou un objet de cohorte calcule le chemin grossier ; les membres suivent leurs offsets par `FORMATION_LOCAL`, avec récupération locale s'ils se coincent. Les membres isolés ou les ruptures de formation peuvent reprendre temporairement un agent individuel.

Risque : un seul chemin ne suffit pas si la formation est plus large qu'un corridor, si les soldats se trouvent de part et d'autre d'un obstacle ou si l'ancrage traverse une zone trop étroite. Tester largeur de corridor, portes, demi-tour, pertes et reformation avant adoption.

#### 4.3 Construire un index spatial de cibles par faction

Remplacer les scans `get_nodes_in_group("enemy")` et `get_nodes_in_group("spartan_ally")` répétés par une collection scène-scopée, maintenue lors de l'apparition, la désactivation, la mort et la sortie d'arbre. L'index peut réutiliser la grille spatiale existante.

Conserver l'ordre psychologique : vengeance récente, joueur pour les hostiles, cible précédente avec hystérésis, candidats locaux, puis éventuel repli global. Le résultat ne doit pas faire changer une unité de cible à chaque actualisation.

#### 4.4 Supprimer les calculs O(n²) lors des reconstructions de phalange

Le directeur reconstruit la liste des candidats de phalange, puis calcule les voisins de chaque candidat en reparcourant la cohorte. Il produit aussi une signature via tableau, `map()` et concaténation de chaînes. Ces coûts croissent rapidement avec la taille de la cohorte.

Amélioration possible :

- maintenir les membres par événement ;
- conserver un numéro de version de cohorte plutôt qu'une signature textuelle ;
- calculer les proximités avec la grille, ou une seule boucle de paires qui alimente tous les compteurs ;
- conserver les slots dans un état de cohorte typé et ne recalculer que lors d'un changement de version, de cible, de phase ou d'ancrage significatif.

#### 4.5 Mettre en cache la pression locale par cible

Chaque demande de bail d'attaque peut recalculer `local_pressure()` dans un rayon de 10 m. Avec des cellules de 3 m, cela inspecte potentiellement jusqu'à 81 cellules, puis ce coût se répète lorsqu'une unité refusée réessaie.

Amélioration possible : calculer la pression une fois par cible et par version de grille, ou au plus à 20 Hz. La capacité de 2 attaquants, portée à 3 lorsque la pression atteint 10, ne nécessite pas une précision à chaque appel.

#### 4.6 Réduire et mutualiser les raycasts de terrain des archers

Séparer trois besoins : recherche de hauteur tactique, validation du sol au déplacement et validation de la voie du projectile. Les deux premiers peuvent exploiter un cache de cellule et une cadence basse ; le troisième doit rester proche du tir.

Mesures : raycasts par seconde et par archer, temps physique, taux de réutilisation du cache, nombre de destinations rejetées, incidents de chute ou de blocage.

### P2 — réduction des callbacks, allocations et appels dynamiques

#### 4.7 Fournir les voisins sans allocation ni double copie

La grille retourne un nouveau tableau, puis l'ennemi l'assigne dans un autre tableau typé. Le directeur pourrait remplir un buffer fourni par l'appelant, retourner une vue réutilisable, ou calculer directement le vecteur de séparation. La dernière option réduit aussi les appels de propriétés sur les voisins.

#### 4.8 Maintenir la liste des participants plutôt que rescanner un groupe à 20 Hz

Le directeur peut enregistrer/désenregistrer les combattants à leur activation, mort et sortie d'arbre. Une vérification périodique lente peut rester comme filet de sécurité en développement. Cela réduit le scan du groupe et rend les règles de présence explicites.

#### 4.9 Remplacer les dictionnaires chauds par des états typés persistants

Candidats principaux : but tactique, participant d'engagement, slot de phalange, état de cohorte, bail d'attaque et résultat de navigation. Une classe `RefCounted` ou un petit objet typé évite les clés de chaîne, les `Variant`, les duplications profondes et certaines vérifications dynamiques.

Le changement doit être progressif : le dictionnaire d'un profil d'archétype hétérogène et construit une seule fois est beaucoup moins urgent qu'un dictionnaire recréé à 20 Hz.

#### 4.10 Typer le directeur et mettre en cache les capacités de cible

Transformer les appels chauds `has_method()`/`call()` en appels directs lorsque la scène garantit le type. Lorsqu'une cible change, calculer une fois si elle expose une anatomie, un bouclier, une voie d'attaque, des signaux télégraphiques ou une API de dégâts. Invalider ce cache à la mort/au changement de cible.

#### 4.11 Appliquer le LOD à la pose d'équipement de phalange

La pose bouclier/lance de phalange est actualisée à chaque frame rendue, y compris pour des unités dont l'animation est fortement réduite ou arrêtée. La mettre au même stride que le pont de pose, ou la figer tant que l'état de phalange n'a pas changé, réduirait un coût linéaire simple.

#### 4.12 Rendre les blessures événementielles

Conserver un bitmask ou des booléens dérivés lors de la perte d'un membre : jambes perdues, bras dominant perdu, bouclier disponible, os à masquer. Éviter de parcourir `hidden_bones.keys()` et de relire les dictionnaires anatomiques chaque frame. Une correction visuelle basse fréquence peut rester si une animation externe risque de rétablir la pose.

#### 4.13 Mettre en pool projectiles et VFX transitoires

Réutiliser flèches, télégraphes, halos, ondes de choc et effets de gore. Partager les meshes et matériaux immuables. Préallouer une petite capacité par type, la faire croître avec une limite, et garantir la remise à zéro complète de l'objet au retour au pool.

Le sang statique et plusieurs caches de ressources existent déjà ; il faut étendre le principe aux créations encore présentes dans les attaques.

#### 4.14 Optimiser les surfaces et colliders des géants

Le calcul du sommet marchable d'un géant parcourt ses points de coque à chaque tick physique. Pré-calculer les extrêmes locaux et ne refaire le calcul monde que lorsque le transform ou la pose le demande. Les mises à jour des colliders assistés peuvent également être conditionnées à un changement d'état.

### P3 — niveaux de simulation et coûts de rendu/physique

#### 4.15 Introduire un LOD de simulation explicite

Pour une vague inactive, très lointaine, hors champ et sans cible : arrêter temporairement la réflexion, la navigation, l'anatomie précise et éventuellement le mouvement physique. Réactiver sur proximité, événement de bataille ou entrée dans une zone d'intérêt.

Ce niveau est plus risqué que le LOD d'animation : une unité endormie ne doit pas manquer une attaque, traverser le sol ou ignorer un ordre de formation. Il doit être piloté par une règle de gameplay explicite, pas uniquement par la caméra.

#### 4.16 Employer une hurtbox grossière à grande distance

Chaque unité possède une anatomie détaillée de 12 zones, dont 10 sectionnables. Pour les ennemis trop éloignés pour être frappés, désactiver le monitoring détaillé et utiliser une forme grossière peut réduire le coût de broadphase. Réactiver avant l'entrée dans une portée d'attaque ou de projectile.

Tester très soigneusement les tirs rapides et les projectiles lancés depuis loin : l'anatomie doit être réactivée assez tôt pour ne pas perdre d'impact.

#### 4.17 Lisser les vagues d'apparition

Le chargement de ressources dans `_ready()` n'est pas un coût par frame stable, mais une vague entière peut provoquer un pic de construction : scènes, skeletons, matériaux, anatomy, navigation et caches. Précharger les archétypes attendus, construire par budget ou réutiliser des unités désactivées peut lisser ce pic.

#### 4.18 Mettre en cache les réglages LOD et les listes visuelles

Lire les valeurs `ProjectSettings` une fois par scène ou dans un objet de configuration. Mettre en cache les géométries et particules enfants au `_ready()` au lieu de les rechercher lors des transitions. Ce ne sont pas les gains les plus importants, mais ils sont simples à vérifier.

### P4 — micro-optimisations après profilage

- utiliser les distances au carré pour les seuils sans normalisation ;
- éviter les appels de setter/deferred lorsque la valeur n'a pas changé ;
- remplacer les chaînes de clés chaudes par `StringName` ou, mieux, des champs typés ;
- éviter `pop_front()` sur une file fréquemment sollicitée ;
- conserver les résultats de tri tant que la version de collection ne change pas ;
- ne pas dupliquer profondément un dictionnaire qui ne sera pas muté ;
- pré-calculer les constantes géométriques et tables d'angles des anneaux ;
- envisager GDExtension uniquement si le profiler prouve qu'une boucle pure et stable reste dominante après les corrections d'architecture. Passer tôt en C++ ne supprimerait ni les scans globaux, ni les allocations, ni les appels serveur répétés.

## 5. Comportement commun à tous les combattants IA

### 5.1 Création et identité

`EnemyFactory` est le point de construction. Il applique un `EnemySpawnRequest` et le profil canonique avant la préparation du collider, du visuel et de la navigation. Cela empêche un premier tick avec des valeurs par défaut incohérentes.

Les unités athéniennes hostiles rejoignent notamment `enemy` et `athenian`. Les unités spartiates rejoignent `ally` et `spartan_ally`. Tous les combattants actifs sont `damageable` et `combatant`; ceux contrôlés par l'IA participent à `combatant_ai`, puis à `enemy_ai` ou `ally_ai`. Les hoplites de ligne appartiennent aussi à `phalanx_unit`.

Le seuil de mode de masse est actuellement 28 unités. Il modifie surtout la cadence de réflexion et certaines dépenses d'animation, sans créer une IA distincte.

### 5.2 Activation

Une unité normale commence immédiatement sa vie tactique. Une unité d'entraînement peut rester dormante et vérifier son activation toutes les 0,18 à 0,23 s. Le réveil doit venir d'une condition de proximité ou d'engagement, évitant de simuler pleinement un adversaire encore décoratif.

Les timers initiaux sont déphasés : cooldown d'attaque, réflexion et LOD ne démarrent pas tous à zéro. C'est une bonne protection contre les pics synchronisés.

### 5.3 Choix et conservation d'une cible

Pour un hostile, l'ordre général est :

1. répondre à l'agresseur récent pendant environ 3,6 s ;
2. choisir le joueur humain s'il est dans la zone d'aggro ;
3. conserver la cible actuelle grâce à une hystérésis d'environ 15 % ;
4. sinon évaluer les alliés spartiates disponibles.

Pour un allié spartiate, la recherche porte sur les ennemis. En l'absence d'adversaire pertinent, l'allié suit son commandant humain avec un offset de formation.

Le score de cible combine distance, stabilité et pénalité de réclamation. Une cible déjà entourée devient donc moins attirante, ce qui répartit partiellement l'armée. Lors d'un changement de cible, l'unité libère son ancien bail d'attaque et son inscription d'engagement.

Il n'existe pas de perception générale par ligne de vue, bruit ou mémoire sensorielle. Une cible peut être détectée derrière un obstacle si elle respecte les règles de groupe et de distance. La navigation pourra contourner l'obstacle seulement si un NavMesh compatible est disponible.

### 5.4 Règle de capitaine et commandement local hérité

Lorsqu'une unité non miniboss est associée à un capitaine vivant, elle peut défendre ce capitaine. Si le joueur menace la zone du chef, l'unité intercepte ; sinon elle tient l'un des cinq offsets de garde autour de lui. Cette relation dépend de l'identité miniboss/capitaine transmise au spawn, pas du simple champ textuel `formation_role`.

Cela crée une distinction importante : le Taxiarch `ncenturion` porte un rôle de commandant de formation dans ses données, mais ce rôle ne lui donne pas automatiquement le commandement technique d'une phalange. La défense de capitaine et la phalange collective sont deux systèmes différents.

### 5.5 Intention tactique

À chaque cycle de réflexion, l'unité produit un but mis en cache. Les grandes familles sont :

- **agressive** : avance directe, attaque dès que les conditions sont réunies ;
- **guardian** : tient une ligne de bouclier, avec priorité à la défense d'un chef si cette tâche est active ;
- **reach** : recule si trop proche, avance si trop loin, tient sa bande optimale ;
- **flank** : orbite autour de la cible avant d'entrer pour frapper ;
- **ranged** : cherche portée et hauteur, vise, puis recule après un délai si elle est fixée au corps à corps ;
- **coward** : combat dans sa bande tant qu'il n'est pas effrayé, puis fuit ;
- **brute** : charge et recherche le choc ;
- **commander** : se repositionne s'il est trop proche, puis tient ou attaque ;
- **juggernaut** : avance et écrase ;
- **boss / phase_boss** : sélectionne les patterns et phases spéciales ;
- **phalanx** : délègue la place et l'état collectif au directeur.

Une branche `duelist` existe également dans le contrôleur mais aucun des 22 profils canoniques actuels ne semble l'utiliser. Elle correspond à un combattant qui tourne à rayon tactique avant de frapper.

### 5.6 Mouvement, séparation et collisions

La vitesse souhaitée est convertie en mouvement avec une accélération commune d'environ 18 et une gravité d'environ 24. La racine exécute `move_and_slide()` à la cadence physique.

Les ennemis ne reposent pas sur des collisions physiques mutuelles fortes pour se pousser. La séparation calculée par la grille est donc l'outil principal contre les superpositions. Son état peut dater de 50 ms ; à haute vitesse ou dans un goulet, une légère interpénétration visuelle reste possible.

L'allié sans cible proche suit le joueur dans une formation approximative de sept colonnes. Les unités à distance ajoutent un biais de hauteur à leur position souhaitée.

Une patrouille optionnelle peut être interrompue par le combat. Après la perte de la cible, l'unité retourne vers le waypoint pertinent plutôt que de continuer à errer.

### 5.7 Navigation et pathfinding

Le composant choisit un des modes suivants :

| Mode | Usage |
|---|---|
| `NAVMESH_GROUND` | Navigation normale si une région et des couches compatibles existent |
| `FORMATION_LOCAL` | Suivi local de slot lorsque la phalange ne dispose pas d'un NavMesh utilisable |
| `DIRECT_STEERING` | Direction directe vers le but, sans contournement topologique |
| `STATIC` | Pas de locomotion tactique |
| `FLYING` | Intention adaptée à un déplacement aérien |
| `LARGE_BODY` | Géants et grands corps, avec paramètres plus prudents |
| `RECOVERY_ONLY` | Mouvement de récupération sans suivi de chemin normal |

Ordre de sélection : override explicite, grand corps, NavMesh compatible, phalange locale, puis steering direct. Une phalange utilise donc aussi un agent individuel si le NavMesh est disponible.

Paramètres importants : arrivée à environ 0,28 m, réinitialisation de destination autour de 3 m, retarget de chemin vers 0,35 m, détection de blocage après environ 0,82 s — 1,15 s pour un grand corps — et récupération pendant 0,48 s — 0,72 s pour un grand corps. Le mode grand corps applique aussi une vitesse réduite à environ 78 % pendant la navigation prudente.

L'évitement RVO de `NavigationAgent3D` est volontairement désactivé : la racine ne consomme pas `velocity_computed`, et activer l'évitement sans intégrer son résultat donnerait un faux sentiment de sécurité. La séparation de foule sert d'évitement local.

Conséquence psychologique : avec NavMesh, une unité sait contourner la topologie ; en steering direct, elle veut simplement aller vers son but et ne possède qu'une récupération locale si elle reste coincée. Les mêmes soldats peuvent donc paraître plus ou moins intelligents suivant la scène où ils sont placés.

### 5.8 Engagement autour d'une cible

Le `CrowdEngagementCoordinator` organise les participants autour de chaque cible :

- anneau de contact à environ 1,78 m ;
- anneaux de réserve espacés d'environ 1,18 m ;
- six places par anneau dans les réglages actuels ;
- tolérance d'environ 0,90 m et hystérésis de 0,45 m ;
- rotation de base de 7,5 degrés/s, ralentie à 35 % au contact ;
- sens alterné et variations entre anneaux ;
- les tireurs commencent au minimum au deuxième anneau et respectent leur portée préférée ;
- les boss/miniboss disposent d'une poche intérieure d'environ 1,05 m, non rotative.

Le rééquilibrage se fait à 10 Hz. L'anneau évite que tous les combattants demandent exactement le centre de la cible et décide si un combattant de mêlée est suffisamment placé pour attaquer.

### 5.9 Autorisation d'attaquer

Même correctement placé, un combattant doit obtenir un bail d'attaque :

- capacité normale : 2 attaquants simultanés ;
- capacité dense : 3 si la pression locale atteint au moins 10 combattants dans environ 10 m ;
- phalange : capacité plafonnée à 2 ;
- durée maximale d'un bail : environ 2,15 s ;
- file d'attente FIFO bornée pour les demandes refusées.

Tous les tirs et attaques de mêlée utilisent ce même mécanisme. C'est lisible pour le joueur, mais cela signifie aussi qu'un archer distant peut occuper une autorisation qui retarde momentanément une attaque de mêlée. Ce choix mérite d'être validé comme doctrine de combat, ou séparé en budgets mêlée/projectile si l'armée paraît trop passive.

### 5.10 Pipeline d'attaque

Le déroulement commun est :

1. cible valide et cooldown terminé ;
2. portée, orientation et contraintes du profil vérifiées ;
3. place d'engagement prête pour la mêlée ;
4. bail d'attaque obtenu ;
5. choix d'une attaque dans le pattern de l'archétype ;
6. télégraphe et windup ;
7. revalidation de la portée, de l'arc et, pour un projectile, de la voie ;
8. application du dégât ou création du projectile ;
9. recovery, cooldown et libération du bail.

Les attaques à distance ne dépendent pas de la même notion de contact prêt que la mêlée, mais elles restent soumises au budget global. Une sortie de phalange exige réellement l'arrivée des soldats à leur position avancée avant d'autoriser la frappe.

### 5.11 Défense

La défense combine, suivant le profil : bouclier, garde, esquive, armure, parade et poise.

Le bouclier n'est pas une réduction omnidirectionnelle : il dépend de la frontalité. La garde possède endurance, récupération, délai après impact et état brisé. Plusieurs profils peuvent réagir de façon proactive à un télégraphe d'attaque. L'armure multiplie le dommage reçu et la probabilité/force de sectionnement ; le poise réduit l'interruption.

### 5.12 Anatomie et blessures

L'anatomie comprend 12 zones et 10 zones sectionnables. Effets structurants :

- tête ou cou : issue fatale ;
- bras/avant-bras droit : perte ou incapacité de l'arme principale ;
- bras gauche : perte du bouclier, ou du maintien de l'arc suivant l'équipement ;
- une jambe : boiterie et vitesse autour de 1,85 m/s ;
- deux jambes : déplacement rampant autour de 0,72 m/s ;
- membre sectionné : os masqué, objet éventuel lâché et VFX de gore.

Les blessures modifient donc réellement la psychologie visible : portée, confiance défensive et mobilité changent. En revanche, il n'existe pas encore de morale collective qui réagirait au nombre de camarades mutilés ou morts.

### 5.13 Mort et retraite de la simulation

La mort est traitée comme une transition atomique : la cible et les baux sont libérés, l'unité cesse de participer aux groupes tactiques, la physique offensive et l'anatomie sont désactivées, l'équipement peut tomber, l'animation de mort se joue, puis les traitements inutiles sont retirés. Le cadavre reste environ 12 s avant nettoyage.

Cette séquence évite qu'un mort continue à occuper un slot, une autorisation d'attaque ou une place de phalange.

### 5.14 Animation et LOD

Les niveaux éloignés réduisent progressivement le pilotage d'animation : environ 30 Hz, puis 12 Hz, puis arrêt du pilotage au LOD 3. Le suivi anatomique est lui aussi modulé par la distance et le contact. Les ombres peuvent être supprimées au loin.

Des travaux annexes ne suivent pas encore entièrement cette politique, notamment la pose d'équipement de phalange et certaines corrections de blessure. C'est une incohérence de performance plus qu'une incohérence de gameplay.

## 6. Gestionnaire de foule : doctrine collective

### 6.1 Grille spatiale

Le directeur reconstruit toutes les 50 ms une grille de cellules de 3 m à partir des membres de `combatant_ai`. Elle sert à la séparation et à la pression locale. Une requête de voisinage inspecte les neuf cellules immédiatement adjacentes pour les interactions courtes.

La grille est une bonne base pour centraliser également le ciblage local, les proximités de cohorte et certains caches de terrain. Aujourd'hui ces usages ne sont pas encore unifiés.

### 6.2 Anneaux d'engagement

Les anneaux donnent à l'armée une courtoisie de combat : peu d'unités entrent au contact, les autres attendent en réserve et l'ensemble tourne lentement. Sans ce système, toutes les unités convergeraient vers un même point.

La répartition par distance avec hystérésis limite les changements de rang. Les boss ne se voient pas bloqués en réserve : leur poche intérieure leur garantit une présence directe, tandis que le scheduler limite encore le nombre de frappes simultanées.

### 6.3 Scheduler d'attaques

Le scheduler est un metteur en scène, pas une simulation de communication militaire. Il assure la lisibilité des attaques et évite une rafale impossible à esquiver. La FIFO apporte une notion d'équité, mais ne tient pas compte d'une priorité tactique avancée : blessé, vétéran, opportunité de dos, urgence de protéger un chef, mêlée contre projectile.

Une évolution possible serait de conserver la limite globale mais d'ajouter de petites classes de priorité. Ce changement modifierait fortement le ressenti et ne doit pas être présenté comme une simple optimisation.

### 6.4 Phalange : constitution et stabilité

Une cohorte est identifiée par faction et `formation_group`. Le changement de cible ne doit pas réordonner arbitrairement la cohorte.

La formation standard utilise cinq colonnes, avec environ 1,08 m latéral et 1,18 m entre rangs. Les vétérans utilisent environ 1,12/1,22 m et sont préférentiellement placés sur les extrémités de rang, jusqu'à deux vétérans par rang.

Au rassemblement, l'ancrage initial correspond au centre de la cohorte. La marche normale demande environ 90 % d'unités prêtes. Après 3,5 s, une formation bloquée peut accepter un plancher dégradé de 60 %, avec au moins deux soldats, pour ne pas rester paralysée.

Les slots sont stables. Lorsqu'un soldat de première ligne meurt, un survivant plus profond est promu dans sa place exacte ; un nouveau venu prend l'arrière. Cela donne une mémoire collective convaincante et empêche la formation de vibrer à chaque actualisation.

### 6.5 Orientation, demi-tour et pertes

Une fois formée, la phalange verrouille son axe latéral. Si la menace passe derrière avec un écart supérieur à environ 120 degrés, elle effectue un about-face en échangeant les rôles avant/arrière tout en conservant les places monde. Elle ne fait donc pas tourner instantanément tous les slots à travers les soldats.

Le comportement en cas de perte cherche d'abord à remplir une vacance. La reformation générale n'est pas la première réponse, ce qui conserve une ligne lisible mais peut produire une pression forte sur quelques survivants.

### 6.6 Ligne pénétrée et arc d'expulsion

Pour une seule cohorte pénétrée, la formation peut ouvrir un arc d'environ 136 degrés pendant une transition de 1,35 s, puis maintenir la réponse autour de 5,6 s. Les trois boucliers centraux peuvent pousser l'intrus. L'objectif psychologique est clair : la ligne ne se dissout pas ; elle enveloppe puis expulse.

### 6.7 Coordination de plusieurs cohortes

Des cohortes proches dans environ 6,5 m se répartissent les secteurs :

- deux cohortes couvrent environ 180 degrés ;
- trois couvrent environ 280 degrés ;
- quatre peuvent former une couverture complète de 360 degrés ;
- le rayon collectif est multiplié approximativement par deux ;
- les soutiens se placent plus loin, autour de 2,65 m.

Cette coordination est produite par le directeur, pas par un commandant visible. Si le joueur s'attend à ce que la mort d'un Taxiarch désorganise la phalange, ce lien n'existe pas aujourd'hui.

### 6.8 Sorties coordonnées

Une sortie choisit trois hoplites de première ligne. Séquence : avance pendant environ 0,9 s, frappe pendant 1,35 s, retour pendant 0,9 s, repos autour de 0,85 s. La frappe n'est pas déclenchée sur un simple timer : l'arrivée physique à la position de sortie est requise.

L'ancrage collectif avance autour de 1,65 m/s et tourne à environ 28 degrés/s. Un hoplite isolé abandonne la logique de grand bloc et passe en duel fonctionnel.

### 6.9 États individuels de phalange

Les unités peuvent afficher ou exploiter les états : duel, rassemblement, marche, garde, poussée, attaque, repli, réorganisation, rupture, arc d'expulsion, arc coordonné et sortie coordonnée. Ces états pilotent l'intention, la pose d'équipement et l'autorisation de frapper.

## 7. Comportement individuel des 22 unités

Les chiffres suivants proviennent des profils actuels. Ils servent à comprendre la personnalité relative, pas à documenter toutes les constantes secondaires.

| ID | Rôle comportemental | PV | Vitesse | Dégât | Portée | Équipement |
|---|---|---:|---:|---:|---:|---|
| `swordsman` | agressif standard | 105 | 4,90 | 14 | 1,72 | épée + bouclier |
| `guardian` | gardien lourd | 160 | 4,00 | 16 | 1,78 | hache + grand bouclier |
| `spearman` | contrôle de portée | 115 | 4,25 | 19 | 2,62 | lance + bouclier |
| `flanker` | contournement rapide | 80 | 6,15 | 12 | 1,58 | lame, sans bouclier |
| `brute` | choc lourd | 310 | 3,65 | 29 | 1,96 | hache, sans bouclier |
| `captain` | miniboss/chef | 460 | 5,25 | 34 | 2,28 | épée + bouclier |
| `warlord` | boss de mêlée | 980 | 4,85 | 46 | 2,48 | hache + bouclier |
| `boss_colossus` | miniboss écraseur | 720 | 3,85 | 44 | 2,12 | marteau |
| `boss_bronze` | miniboss à allonge | 640 | 4,45 | 38 | 2,92 | lance |
| `nathenian1` | infanterie disciplinée | 128 | 4,65 | 15 | 1,75 | arme + bouclier |
| `nsbire1` | levée lâche | 82 | 4,80 | 13 | 1,92 | outil agricole |
| `nsbire2` | archer | 48 | 4,55 | 12 | jusqu'à 18 | arc |
| `nathenian2` | miniboss briseur de ligne | 430 | 3,85 | 34 | 2,10 | marteau |
| `nathenian2_soldier` | fantassin lourd | 185 | 4,05 | 21 | 2,10 | marteau |
| `bronze_colossus` | juggernaut miniboss | 780 | 3,45 | 46 | 2,20 | marteau |
| `ncenturion` | Taxiarch commandant | 570 | 4,50 | 31 | 1,92 | gladius + bouclier |
| `ngeneral` | noyau de phalange | 145 | 3,70 | 18 | 2,72 | lance + bouclier |
| `ngeneral_veteran` | garde de flanc phalange | 235 | 3,82 | 25 | 2,90 | lance + bouclier |
| `giant_novice` | géant simple | 280 | 3,35 | 25 | 2,05 | poings |
| `giant_standard` | géant confirmé | 520 | 3,65 | 32 | 2,20 | poings |
| `giant_veteran` | géant élite à phases | 860 | 3,95 | 40 | 2,38 | poings |
| `nfull_armor` | boss ancre à trois phases | 2200 | 4,45 | 52 | 2,55 | grande épée |

### 7.1 `swordsman`

Fantassin de référence. Il réduit directement la distance, accepte le contact proche et utilise un mélange d'attaques légères. Son bouclier lui donne une défense frontale, mais il ne possède ni bande de portée, ni orbite, ni phase spéciale. Il sert de base pour mesurer le coût et la lisibilité d'une IA standard.

### 7.2 `guardian`

Plus lent, plus robuste et muni d'un grand bouclier. Sa personnalité est celle d'un teneur de ligne. Lorsque la tâche de défense d'un chef est active, cette personnalité s'exprime réellement par l'interception et la garde d'une position ; sans chef à défendre, il rejoint cependant les mêmes anneaux généraux et son comportement diffère surtout par sa défense et sa vitesse.

### 7.3 `spearman`

Il cherche une bande entre environ 1,55 et 2,42 m, recule si la cible entre sous sa pointe et avance si elle sort de portée. Son allonge de 2,62 m et son bouclier en font un contrôleur prudent plutôt qu'un simple agressif. Un espace trop encombré peut empêcher cette psychologie de s'exprimer, car la séparation et les anneaux décident aussi de sa place.

### 7.4 `flanker`

Unité légère très rapide. Tant qu'elle n'est pas assez proche pour frapper, elle orbite autour de la cible à environ 2,25 m avec une vitesse angulaire d'environ 0,62. Elle entre ensuite pour une attaque courte et rapide. Elle n'a pas de bouclier et compense donc par la mobilité ; si l'anneau ou le scheduler l'attend trop longtemps, elle peut sembler tourner sans initiative.

### 7.5 `brute`

Unité de choc lente et résistante, sans bouclier. Elle avance directement, charge et cherche un impact lourd de hache. Sa psychologie est volontairement peu subtile : beaucoup de PV, dégâts élevés et faible besoin de conserver une bande.

### 7.6 `captain`

Miniboss mobile et agressif, avec une poche intérieure d'engagement qui lui évite d'attendre derrière ses propres soldats. Son pattern comprend notamment coup de bouclier, coupe croisée et attaque de commandement lourde. D'autres unités peuvent recevoir la tâche de le protéger, ce qui lui donne une présence de chef plus réelle que le simple champ de rôle.

### 7.7 `warlord`

Boss de mêlée à grande endurance. Il alterne balayage, exécution et ruée. À environ 55 % de PV, il entre en seconde phase : vitesse multipliée approximativement par 1,12 et dégâts par 1,18, avec balayages de rage et combos. Son comportement collectif reste celui d'un boss bénéficiant d'un accès intérieur, pas celui d'un commandant qui donne des ordres aux cohortes.

### 7.8 `boss_colossus`

Miniboss brute au marteau, sans bouclier. Il recherche le choc à courte portée et possède un écrasement avec onde de zone d'environ 3,4 m. Il doit créer de l'espace par menace de zone plutôt que par vitesse ou finesse.

### 7.9 `boss_bronze`

Miniboss à lance, qui conserve une bande d'environ 1,65 à 2,68 m. Ses deux intentions principales sont l'estoc et le balayage. Contrairement au spearman standard, il n'a pas de bouclier mais compense par sa masse, ses PV et son allonge.

### 7.10 `nathenian1`

Infanterie athénienne disciplinée à bouclier léger : 128 PV, garde plus fiable que le swordsman, approche mesurée et séparation légèrement renforcée. Elle tient une ligne sans être une véritable unité de phalange. C'est un gardien intermédiaire, plus mobile que le `guardian` lourd.

### 7.11 `nsbire1`

Levée avec outil agricole et presque aucune défense. Elle combat dans une bande d'environ 1,10 à 1,80 m, mais fuit lorsqu'elle passe sous 32 % de PV ou après un coup, pendant une durée aléatoire d'environ 1,25 à 2,15 s. Sa séparation élevée renforce l'image d'une troupe peu disciplinée qui refuse la masse compacte.

### 7.12 `nsbire2`

Archer fragile : 48 PV, portée maximale autour de 18 m, vitesse de projectile 22 m/s, gravité 5,2 et légère dispersion. Il préfère environ 3,65 à 13,5 m, commence sur un anneau de réserve, recherche une hauteur locale et ne recule qu'après environ 0,82 s de fixation au corps à corps. Il possède environ 10 % d'esquive.

Sa « recherche de hauteur » est un heuristique de raycasts locaux, pas une planification tactique globale du relief. Il ne sait pas identifier à l'avance une colline accessible par NavMesh de la même manière qu'un planificateur de couverture.

### 7.13 `nathenian2`

Miniboss briseur de ligne au marteau : armure solide, poise élevé et trois attaques lourdes. À environ 48 % de PV, il gagne approximativement 10 % de vitesse et 14 % de dégâts, et accède à des réponses de type onde/ruée. Il doit désorganiser le front plus que poursuivre une cible avec précision.

### 7.14 `nathenian2_soldier`

Transformation du package `nathenian2` en soldat lourd ordinaire : rang normal, échelle réduite, 185 PV, 21 dégâts, vitesse 4,05, poise plus bas et aucune phase. Il conserve cependant une grande partie de l'identité marteau/briseur de ligne, y compris sa famille de combat et ses signatures. À vérifier volontairement : un soldat déclaré ordinaire peut encore paraître psychologiquement très proche du miniboss dont il dérive.

### 7.15 `bronze_colossus`

Juggernaut miniboss : extrêmement blindé, poise très élevé, lent et massif. Il dispose de rugissement, charge, onde et balayage. Sa seconde phase autour de 52 % de PV augmente légèrement vitesse et dégâts. Il avance pour écraser plutôt que pour garder une distance tactique.

### 7.16 `ncenturion`

Taxiarch très robuste au gladius et bouclier, avec garde forte et patterns de probe, bash et combo. Son mode `commander` le fait se repositionner lorsqu'il est trop proche, puis tenir ou attaquer, notamment lorsqu'il défend un chef.

Point doctrinal important : malgré le rôle `formation_commander`, il n'est pas le cerveau technique des `ngeneral`. Sa mort ne dissout pas automatiquement une phalange, ne change pas ses slots et ne réduit pas sa coordination multi-cohorte.

### 7.17 `ngeneral`

Hoplite standard, cœur de la phalange. Sa lance et son bouclier, son allonge de 2,72 m et sa garde élevée sont subordonnés aux états collectifs : rassemblement, marche, garde, poussée, sortie et reformation. Son pattern comprend attaques haute, basse, torse et poussée.

Isolé, il passe en duel et reste fonctionnel. En groupe, il accepte de ne pas attaquer tant que son slot, la sortie ou le bail collectif ne l'autorisent pas : sa discipline prime sur l'agressivité individuelle.

### 7.18 `ngeneral_veteran`

Hoplite élite placé prioritairement sur les flancs de rang. Il possède plus de PV, d'allonge, de poise et une garde beaucoup plus forte. Son pattern inclut riposte, attaque basse, attaque retardée et poussée. La position de bord lui donne le rôle implicite de protéger les extrémités, sans logique individuelle distincte de poursuite.

### 7.19 `giant_novice`

Géant simple aux poings, sans défense formelle. Il utilise punch et swipe, avec poise modéré. Le mode `LARGE_BODY`, le collider assisté et le dessus marchable traitent sa taille comme une contrainte physique spéciale. Il ne possède ni phase ni commandement.

### 7.20 `giant_standard`

Version confirmée : davantage de PV, dégâts et poise, avec punch, swipe et saut. Sa navigation conserve les mêmes limites de grand corps ; le saut élargit sa réponse lorsque la simple poursuite est insuffisante.

### 7.21 `giant_veteran`

Géant élite avec rugissement, saut et onde de choc. À environ 48 % de PV, il gagne près de 10 % de vitesse et 12 % de dégâts et déverrouille ses réponses de rage. Il reste un combattant solo : aucun effet de peur ou de moral n'est actuellement appliqué aux petits soldats proches de son rugissement, sauf effet explicitement codé par l'attaque.

### 7.22 `nfull_armor`

Boss ancre en armure complète, 2 200 PV et grande épée. Phase 1 : cleave, sweep et leap. Vers 68 % de PV, phase 2 avec vitesse ×1,16 et dégâts ×1,15, ruée, tempête et onde ; pendant certaines fenêtres de cooldown, il peut tourner autour de la cible. Vers 32 %, phase 3 avec nouvelle hausse de vitesse/dégâts, frenzy, crown/storm/quake/exécution.

Sa troisième phase rend aussi son multiplicateur de dégâts d'armure moins protecteur — il passe vers 0,78 au lieu de 0,60 — ce qui le rend plus vulnérable malgré son agressivité. C'est cohérent avec une armure brisée ou une posture désespérée, mais peut sembler contradictoire si ce changement n'est pas visible à l'écran.

## 8. Questions de cohérence sur la « psychologie de l'armée »

Ces points ne sont pas nécessairement des bugs. Ce sont des décisions actuellement implicites à confirmer.

1. **Le commandement est surtout invisible.** Les phalanges se coordonnent grâce au directeur même sans capitaine ni Taxiarch vivant. Faut-il que certains ordres, sorties ou formations dépendent d'un commandant visible ?
2. **Le rôle `formation_commander` n'a pas d'autorité de phalange.** `ncenturion` se comporte comme un combattant commandant, mais ne construit ni ne maintient les slots des hoplites.
3. **La ligne du gardien est contextuelle.** Sans chef à défendre, le `guardian` est surtout un lourd défensif dans les anneaux généraux, pas un soldat qui cherche spontanément un goulet ou protège un allié fragile.
4. **La détection traverse les murs.** Il n'y a pas de perception par ligne de vue générale. Est-ce une abstraction acceptée ou l'armée doit-elle avoir une mémoire/perception limitée ?
5. **La navigation change l'intelligence apparente selon la scène.** Sans NavMesh compatible, le steering direct ne planifie pas autour des obstacles.
6. **Les archers partagent le budget d'attaque de mêlée.** Cela améliore la lisibilité globale, mais peut rendre les premières lignes artificiellement passives.
7. **Il n'existe presque pas de morale.** Seul `nsbire1` fuit explicitement. La mort du chef, l'encerclement, les pertes de cohorte, un géant ou les mutilations ne font pas paniquer les autres unités.
8. **La vengeance est individuelle et courte.** L'agresseur récent est prioritaire environ 3,6 s ; il n'y a ni transmission d'information, ni mémoire de menace collective.
9. **La phalange est très disciplinée sans communication visible.** About-face, remplissage des trous et coordination sectorielle arrivent par le directeur, indépendamment du champ de vision ou d'un délai de messager.
10. **Un hoplite isolé reste pleinement compétent.** Le passage en duel empêche une unité cassée de devenir inutile. Faut-il néanmoins une perte de confiance ou de défense hors formation ?
11. **`nathenian2_soldier` conserve l'identité du miniboss.** Ses chiffres sont réduits, mais sa famille d'attaques reste celle d'un briseur de ligne.
12. **Le boss en armure devient plus vulnérable en phase 3.** Ce choix a besoin d'un langage visuel clair pour être compris.
13. **Six slots par anneau sont la valeur actuelle.** Certains commentaires ou documents historiques parlent encore de huit. La valeur runtime doit être la référence et les documents anciens risquent d'induire en erreur.
14. **La séparation remplace la collision entre soldats.** Une cohorte ne se pousse pas physiquement de façon réaliste ; elle suit une correction mathématique mise à jour à 20 Hz.
15. **Aucune peur des attaques de zone.** Hors logique spécifique d'évitement/attaque, les soldats ne lisent pas nécessairement une onde ou un géant comme une raison collective de rompre les rangs.
16. **L'ordre de bataille n'a pas de priorité par rôle.** Le scheduler assure surtout équité et lisibilité, pas une doctrine où vétérans, flanqueurs ou protecteurs passent avant les levées.

## 9. Plan de mesure recommandé

Avant toute correction, enregistrer une baseline reproductible pour cinq scènes :

| Scénario | But |
|---|---|
| 56 alliés contre 56 ennemis | Exposer le ciblage N×M, les changements de cible et la pression du scheduler |
| 24 hoplites en une puis plusieurs cohortes | Mesurer reconstruction, O(n²), slots, pertes, demi-tour et sortie |
| 12 puis 24 archers sur terrain irrégulier | Compter raycasts de hauteur/sol/voie et coût physique |
| 36 ennemis NavMesh | Compter `map_get_regions`, `get_next_path_position` et temps du composant |
| 1 puis 5 géants | Isoler collider assisté, dessus marchable, anatomie et VFX lourds |

Compteurs à ajouter ou relever :

- cycles de réflexion par seconde et par LOD ;
- scans de groupes et nombre de candidats parcourus ;
- requêtes de voisins, éléments retournés et allocations ;
- reconstructions de cohorte, taille, paires testées, duplications et tris ;
- demandes/refus de bail, cellules inspectées par `local_pressure()` ;
- appels `map_get_regions()` et changements réels d'état de carte ;
- raycasts par catégorie ;
- instances de projectiles/VFX créées et récupérées ;
- temps propre/cumulé de `_physics_process`, `_process`, réflexion, ciblage, navigation, directeur et animation ;
- frame médiane, p95 et p99, accompagnées du nombre d'unités réellement actives.

Les métriques existantes donnent des repères, pas une preuve de gain global : environ 10,435 ms p50 / 14,254 ms p95 pour la région réaliste à 56 callbacks actifs, et environ 11,029 / 14,694 ms dans le scénario mixte. Un snapshot de 36 `ngeneral` actifs autour de 13,463 ms est plus coûteux que 36 `swordsman` autour de 9,999 ms. Les captures sont headless et certaines p95 Windows contiennent du bruit ; elles ne remplacent pas un avant/après identique.

Pour chaque amélioration : même seed, même positions, même build, warm-up identique, plusieurs runs, médiane des runs et validation du comportement. Une baisse de temps accompagnée d'une phalange moins réactive ou de projectiles perdus n'est pas une optimisation réussie.

## 10. Ordre d'investigation conseillé

1. Instrumenter sans changer le comportement.
2. Mesurer séparément ciblage, navigation, phalange, archers et géants.
3. Corriger d'abord les appels serveur/scans globaux et O(n²), pas les micro-accès GDScript.
4. Rejouer les tests de comportement après chaque changement de structure.
5. Traiter ensuite allocations, appels dynamiques et callbacks visuels.
6. N'introduire un LOD de simulation ou un chemin partagé de cohorte qu'avec des scènes de non-régression dédiées.
7. Reprofiler le rendu réel : les captures existantes signalent environ 377 draw calls dans la Forge et 1 171 dans le Lab, mais elles ne constituent pas un comparatif avant/après.

## 11. Sources principales dans le projet

- [`scripts/enemy/athenian_enemy.gd`](../../scripts/enemy/athenian_enemy.gd) — contrôleur commun, ciblage, mouvement, combat, blessures, phases et LOD.
- [`scripts/ai/battle_crowd_director.gd`](../../scripts/ai/battle_crowd_director.gd) — grille, phalanges, sorties, pression et baux d'attaque.
- [`scripts/ai/crowd_engagement_coordinator.gd`](../../scripts/ai/crowd_engagement_coordinator.gd) — anneaux et slots d'engagement.
- [`scripts/ai/crowd_management_settings.gd`](../../scripts/ai/crowd_management_settings.gd) — rayons, cadences, capacités et paramètres de formation.
- [`scripts/ai/enemy_navigation_component.gd`](../../scripts/ai/enemy_navigation_component.gd) — modes de navigation et récupération.
- [`scripts/enemy/enemy_archetypes.gd`](../../scripts/enemy/enemy_archetypes.gd) — profils canoniques des 22 unités.
- [`scripts/enemy/enemy_archetype_data.gd`](../../scripts/enemy/enemy_archetype_data.gd) — vue typée des données d'archétype.
- [`scripts/enemy/enemy_factory.gd`](../../scripts/enemy/enemy_factory.gd) et [`enemy_spawn_request.gd`](../../scripts/enemy/enemy_spawn_request.gd) — construction et requête de spawn.
- [`scripts/enemy/combatant_registry.gd`](../../scripts/enemy/combatant_registry.gd) — registre actuel, encore limité à certaines routes de scène.
- [`docs/enemy_refactor/final_metrics.json`](final_metrics.json) — mesures disponibles au moment de l'audit.

## Conclusion

La refonte a déjà éliminé plusieurs anti-patterns classiques : réflexion à chaque frame, séparation globale N², déplacements concurrents, réveils synchronisés et absence de coordination. Le prochain palier ne viendra probablement pas d'une réduction uniforme de la fréquence de toute l'IA, mais de la suppression de travaux répétés dont l'information est collective : adversaires disponibles, état NavMesh, pression, membres et chemin de cohorte.

Sur le plan psychologique, l'armée est disciplinée, lisible et très structurée autour des anneaux, des baux et de la phalange. Elle est en revanche peu sensorielle et peu émotionnelle : pas de ligne de vue générale, très peu de morale, commandement collectif invisible et faible conséquence de la mort d'un chef. Ces choix peuvent être parfaitement adaptés à un jeu d'action lisible ; ils doivent simplement être assumés comme doctrine plutôt que confondus avec des limitations techniques.
