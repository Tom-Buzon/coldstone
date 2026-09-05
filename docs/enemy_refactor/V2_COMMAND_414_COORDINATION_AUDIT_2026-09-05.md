# V2 — coordination et sensation de champ de bataille

Analyse du 5 septembre 2026. Proposition de direction, pas une modification du gameplay.

## Conclusion

La V2 possède déjà les bonnes fondations de coût : décisions par troupe, slots collectifs, simulation et représentation séparées, imposteurs lointains. Le principal frein est sa doctrine : maintenir quelques formations autour d'une cible et remplacer les contacts successivement. Pour obtenir un immense champ de bataille traversable, faire évoluer cette doctrine vers des fronts persistants et plusieurs manœuvres simultanées, tout en contrôlant séparément les attaques réellement dangereuses.

Le plaisir recherché : le joueur voit une armée organisée, choisit un passage, rompt une ligne, exploite la désorganisation, puis choisit son prochain mouvement. Son action doit laisser une conséquence spatiale perceptible.

## Périmètre et preuves

- Lecture de la carte réellement enregistrée : `champsdebataille_v2_commandement_414.hoplite.json`, dans le répertoire utilisateur Godot. Elle contient 17 phalanges de 24 et une escarmouche de 6 vétérans, soit 414 soldats.
- Route active : `scripts/world_editor/world_runtime.gd:838` → `HopliteV2TroopRuntime.register_group` → `EnemyV2BattleLayoutRuntime` → intentions individuelles. L'analyse porte sur cette V2, pas sur le directeur de foule V1.
- Exécution du probe existant `tools/enemy_v2/hoplite_v2_command_lab_probe.gd` : **PASS**, 4 contacts, 4 soutiens, 9 réserves, focus stable et exclusivité des corridors testée. Journal : `.tmp_tools/command_coordination_audit.log`. Godot émet aussi une erreur de lecture du magasin de certificats ; le probe termine avec le code 0.
- Pas de nouvelle capture de partie ni de benchmark graphique dans cet audit. Les causes structurelles ci-dessous sont visibles dans le code ; leur importance relative dans le ressenti reste à comparer en jeu.
- Les chiffres de performance du README sont des mesures historiques, pas des résultats reproduits ici.

## Ce qui produit le comportement actuel

### 1. Les renforts rejoignent le combat un par un

`enemy_v2_battle_layout_runtime.gd:280` plafonne les formations admises à quatre. Lorsqu'une place se libère, `_select_pending_newcomer` sélectionne un seul entrant ; sa progression suit `outer → orbit → assemble`, puis exige une position précise, une cohésion de 0,62 et 300 ms de stabilité.

Cela ne signifie pas qu'une seule phalange peut combattre : quatre peuvent être admises, et une troupe approchée par le joueur réagit localement. En revanche, la relève stratégique est explicitement séquentielle. Un entrant lent ou bloqué peut retarder la relève des autres secteurs.

Le remède utile est une admission indépendante par front, avec manœuvres compatibles simultanées et reprise après blocage. Augmenter seulement le nombre de contacts ne résout ni les files d'attente ni les détours.

### 2. L'armée conserve une géométrie centrée sur le joueur

`enemy_v2_battle_layout_runtime.gd:582` distribue les contacts selon des angles régulièrement espacés, à 6 m du focus. `_depth_candidates`, ligne 640, place les soutiens à 30 m et les réserves à partir de 74 m, selon quatre axes. Le générateur de la carte reproduit cette disposition.

Le focus amortit cette poursuite : zone morte de 5,5 m, bascule après 450 ms au-delà, repositionnement immédiat à 14 m si la cible est au sol (`enemy_v2_tactical_focus_tracker.gd:31`). C'est utile pour éviter que toute l'armée ne suive les petits mouvements. Mais il ne mémorise ni vitesse, ni direction persistante, ni intention de déplacement ; les destinations restent dépendantes du même centre.

Conséquence probable : attente puis réorganisation globale, plutôt qu'une ligne que le joueur déborde pendant qu'une autre tente de lui couper le passage. Une poursuite plus réactive de tous les groupes risquerait d'aggraver cet effet.

### 3. Les trajets sont géométriques, pas adaptés au terrain

`enemy_v2_formation_traffic_scheduler.gd:17` essaie un trajet direct quand il est admissible, puis deux arcs extérieurs. Le rayon des arcs vaut la plus grande distance départ/arrivée au focus, plus 7 m et une demi-largeur de formation. Un renfort distant peut donc repartir vers l'extérieur avant de revenir.

Ce code ne cherche pas un passage autour d'un obstacle du décor. Le déplacement de l'ancre est planaire ; les soldats de masse rejoignent leurs slots par transformation (`enemy_actor_v2.gd:317`). Une réservation entre troupes n'est donc pas une garantie de franchissabilité du terrain.

Autre limite : l'approche `outer/orbit/assemble` retourne avant `_resolved_assignment` et ne passe pas par le scheduler. L'avance radiale des contacts peut également le contourner. Il reste une exclusion d'ancres, mais pas la même validation d'emprise pour tous les mouvements.

### 4. Les réservations peuvent transformer une protection en attente prolongée

`enemy_v2_tactical_occupancy_runtime.gd:42` réserve toutes les cellules d'un trajet, sans créneaux temporels ni libération progressive de la partie parcourue. Maximum : quatre corridors. `touch_corridor` prolonge leur durée de vie tant que la troupe publie son état, même si elle ne progresse plus.

La priorité est enregistrée et autorise certains trajets directs ; elle n'organise pas une file équitable ni une préemption dans l'occupation. Le code ne fournit pas de protocole de recul ou de cession de passage.

Dans `_resolved_assignment`, une replanification libère le corridor précédent avant d'obtenir le suivant. Si la demande échoue, l'ancien ordre peut rester utilisé sans sa réservation. À traiter lors de la révision du trafic : remplacement atomique ou état d'attente explicite.

Les blocages permanents sont ici un risque identifié dans le code, pas une fréquence mesurée en partie.

### 5. Une interaction locale immobilise la formation entière

`hoplite_v2_troop_runtime.gd:236` met la troupe en ENGAGE dès qu'un membre est engagé ou que le joueur approche un membre à 5,25 m. L'ancre avance uniquement en ADVANCE. Une cohésion inférieure à 0,65 impose également l'assemblage ou la récupération.

Ces protections gardent les rangs propres, mais favorisent des alternances arrêt/reformation. Les rotations changent directement l'orientation des slots ; la conservation des places traite le demi-tour marqué, pas une vitesse angulaire générale de formation.

Prévoir une vitesse de rotation de l'ancre, une progression ralentie selon la cohésion, et la possibilité de laisser quelques défenseurs au contact pendant que le reste tient son ordre. Une rupture majeure doit toutefois rester visible et arrêter réellement la troupe.

### 6. La brèche existe, mais reste surtout locale

La machine CLOSED/CANDIDATE/CHANNEL/FLANKED/CLOSING et l'ouverture des colonnes autour du passage sont une bonne base. Le commandement reçoit `intrusion`, principalement utilisé pour l'orientation et la réactivité de l'ordre. Il n'attribue pas de réponse complémentaire aux voisins : couvrir un flanc, conserver une ouverture, reculer ou déplacer une réserve.

Les pertes reconstruisent les slots (`hoplite_v2_troop_runtime.gd:418`). L'emprise stratégique conserve toutefois sa largeur/profondeur d'enregistrement. Autre décalage : le layout classe les survivants comme escarmouche dès 25 % de l'effectif initial, donc 6 sur 24 ; la compaction locale utilise le seuil absolu de 4. Les niveaux peuvent ainsi diverger sur ce qu'est une formation encore constituée.

### 7. La pression est limitée par troupe, pas orchestrée entre types

Chaque troupe distribue jusqu'à trois permissions d'attaque, par défaut, pendant 1,85 s (`hoplite_v2_troop_runtime.gd:367`). Les conditions de portée et d'orientation limitent ensuite les attaques effectives. Il n'y a pas ici de budget commun conciliant coup de lance, salve et attaque de géant.

La branche stratégique `ranged` existe, mais lui donner ce rôle ne crée pas une IA d'archer : le runtime et le profil d'exécution restent orientés hoplite. Les futures unités doivent partager un contrat de commandement, pas toutes hériter des règles de rang et de lance.

## Direction recommandée

Trois options sont possibles :

| Option | Gain | Limite |
|---|---|---|
| Ajuster rayons, vitesses et délais | Amélioration rapide | Conserve la structure de relève et d'encerclement |
| Ajouter des fronts et ordres collectifs au-dessus de la V2 | Trajectoires complémentaires, bataille persistante, coût par troupe | Demande de revoir admission et trafic |
| Généraliser une IA autonome par soldat | Forte variété individuelle | Coût et coordination plus difficiles à maîtriser |

**Recommandation : deuxième option**, en conservant composants, rendu, animations, slots et LOD existants.

### Fronts persistants et réaction au mouvement

Définir plusieurs lignes ou zones dans le monde. Chacune possède une direction, des groupes affectés, une pression désirée et des passages utilisables. Le joueur influence ces fronts localement ; il ne déplace pas automatiquement toute leur géométrie.

Le commandement affecte des tâches : tenir une ligne, avancer, couvrir un flanc, intercepter, soutenir, se replier, se reformer. Le choix considère temps de trajet, orientation, encombrement, cohésion et coût d'abandon de l'ordre courant. Une courte anticipation du déplacement aide l'interception ; elle doit être limitée, retardée et abandonnée si le joueur change de direction. Les unités ne doivent pas viser parfaitement le futur point d'atterrissage.

Plusieurs troupes peuvent manœuvrer en même temps, même si peu d'entre elles ont l'autorisation d'attaquer. Les réserves peuvent rejoindre une ligne de préparation, relever une troupe affaiblie ou protéger un passage avant qu'une formation entière ne soit détruite.

### Le joueur doit pouvoir créer et exploiter le désordre

Exemple de séquence souhaitée :

1. Une phalange tient l'axe devant le joueur ; une seconde avance sur un axe voisin.
2. Le joueur traverse la première. Les colonnes touchées s'écartent ; les survivants mettent un temps lisible à se réorienter.
3. La deuxième protège son propre flanc avec retard, sans tourner instantanément toute l'armée.
4. Le passage reste exploitable. Le joueur peut enchaîner vers un soutien, un groupe désorganisé ou un géant.
5. Plus loin, les réserves continuent leur manœuvre : le paysage militaire demeure actif.

Introduire une désorganisation locale liée aux impacts, pertes et ruptures : recul bref, garde abaissée, reformation lente. Éviter de reboucher immédiatement chaque trou. Les délais doivent préserver une fenêtre d'exploitation perceptible, à régler en jeu selon la vitesse réelle du personnage.

### Un contrat commun, des comportements distincts

| Unité | Fonction spatiale | Récompense du mouvement du joueur |
|---|---|---|
| Phalange | Tenir un front, avancer avec inertie, couvrir un axe | Déborder, traverser, exploiter une rupture |
| Fantassins | Occuper les interstices, poursuivre brièvement, se disperser | Traversées rapides, chaînes de coups et projections |
| Archers | Choisir portée, ligne de tir et position de repli | Esquiver une salve annoncée, atteindre l'arrière-ligne |
| Géant | Menacer une zone large avec engagement lent et annoncé | Contourner, exploiter une récupération, utiliser la verticalité |

Le contrat d'ordre devrait décrire objectif, destination/zone, trajet, orientation, priorité, durée d'engagement et conditions d'interruption. Le contrat de capacité décrit taille, vitesse, rotation, portée et fonctions possibles. Les particularités restent dans l'exécuteur du type. Le géant peut être une troupe d'un seul membre.

La lisibilité réclame un budget de menace local partagé : mêlée, projectile et attaque de zone ne peuvent pas remplir indépendamment tout l'espace disponible. Il doit gérer les attaques déjà engagées et laisser des sorties praticables. La densité visuelle reste indépendante de ce budget.

### Trafic de formation et coût

- Chercher les routes au niveau de l'ancre, avec largeur et profondeur actualisées ; valider le terrain par zones praticables ou navigation collective.
- Commencer par direct, détour local, puis route plus large. Noter les candidats par temps de trajet et gêne occasionnée, pas seulement longueur géométrique.
- Réserver un horizon limité et relâcher les segments dépassés. Détecter le manque de progression et ordonner attente, cession ou détour.
- Utiliser la même validation pour approche, avance de contact et soutien ; vérifier aussi l'emprise pendant la rotation.
- Garder des décisions collectives espacées et déphasées, des requêtes de chemin mises en cache et un voisinage spatial borné. Le rendu et les collisions fines restent concentrés près du joueur.
- Maintenir une grande profondeur d'armée pour les imposteurs, tout en laissant ces réserves avoir une tâche et une progression visibles.

## Première tranche conseillée

Sur une variante isolée de la carte, conserver les 414 soldats et le profil LOD. Remplacer la relève unique par deux manœuvres simultanées sur des fronts distincts, avec destinations stables dans le monde. Ajouter une réaction de flanc et une fenêtre de désorganisation après brèche. Traiter le maintien d'un ordre sans corridor et la détection de non-progression avant d'augmenter les mouvements concurrents.

Cette tranche permet de juger le gain de sensation avec les phalanges seules. Les archers et géants viendront ensuite éprouver le contrat commun et le budget de menace ; leur ajout ne doit pas être nécessaire pour rendre la coordination actuelle intéressante.

Skills d'implémentation concernés : `godot-brainstorming`, `ai-navigation`, `state-machine`, `resource-pattern`, `godot-optimization`, puis `godot-code-review` et les checks du projet. Aucun de ces changements n'est implémenté par cet audit.

## Comparaison à effectuer avant généralisation

Rejouer les mêmes séquences : joueur immobile, traversée rectiligne, zigzag, demi-tour après brèche, déplacement aérien, destruction rapide d'une phalange, passage entre deux groupes et obstacle étroit.

Mesurer : temps sans progression par troupe et motif, nombre de fronts actifs, durée des détours, révisions d'ordres, délai de réaction, durée d'ouverture après brèche, chevauchements d'emprises, attaques simultanées et ouvertures praticables. Ajouter frame time moyen/p95/p99, coût tactique, distribution LOD et nombre d'acteurs en physique individuelle.

Les tests actuels restent utiles pour les invariants techniques. Les assertions exactes « quatre contacts/quatre soutiens/neuf réserves » décrivent le scénario historique : la variante doit tester ses propres invariants. Un PASS de cette répartition ne prouve ni l'efficacité des trajectoires ni le plaisir de jeu.
