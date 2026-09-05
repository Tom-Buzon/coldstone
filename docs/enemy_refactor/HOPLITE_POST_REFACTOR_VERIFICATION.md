# Vérification post-refonte des hoplites

Date : 2026-08-26\
Moteur : Godot 4.7 stable\
Route fonctionnelle autoritaire : Forge (`HopliteWorldRuntime`)

## Verdict

La refonte avait bien créé les briques communes (navigation, cohortes persistantes,
leases FIFO, bibliothèque d'animations partagée), mais plusieurs preuves ne
traversaient pas le vrai contrôleur des hoplites. Le statut `DONE` masquait donc
quatre défauts d'intégration reproductibles dans la Forge.

## Défauts reproduits avant correction

1. La Forge ne créait aucune `NavigationRegion3D`. Les hoplites Forge utilisaient
   `FORMATION_LOCAL` et ne possédaient aucun `NavigationAgent3D`.
2. Le scheduler FIFO passait isolément, mais `_claim_attack_permission()` retirait
   le hoplite de la file avant chaque nouvelle tentative. Le plus ancien demandeur
   perdait donc sa place.
3. Un demandeur passé hors portée restait en tête de file. Après deux attaques,
   la Forge pouvait afficher zéro permission active, plusieurs waiters et plus
   aucune attaque : le symptôme « ils restent là et regardent ».
4. `member_ready` était figé à la sortie de l'assemblage. Un réserviste bloqué qui
   rejoignait ensuite son slot restait définitivement inéligible.

La preuve historique du remplacement téléportait en outre le remplaçant sur son
slot; elle ne mesurait pas son déplacement réel.

## Corrections

- La Forge construit désormais une région de navigation commune à partir de ses
  collisions statiques (layer 1), puis la bake en tâche de fond. La région existe
  avant le spawn afin que les unités terrestres choisissent la navigation commune
  dès `_ready()`.
- La détection de région couvre la fenêtre d'une frame précédant l'upload au
  `NavigationServer3D` grâce au groupe `enemy_navigation_region`.
- Les retries conservent leur place FIFO. Seuls teardown, mort, sommeil ou changement
  de cible annulent explicitement toutes les demandes.
- Le contrôleur suit l'état `attack_permission_waiting` et annule une demande dès
  que le hoplite n'est plus réellement dans sa fenêtre d'attaque. Les bornes
  `can_threaten` sont maintenant identiques aux bornes utilisées pour commencer
  l'attaque, rang arrière compris.
- La garde proactive et l'attaque alternent : une garde automatique ne peut plus
  se rouvrir indéfiniment sans laisser une fenêtre au scheduler. Les réactions à
  une vraie attaque du joueur restent intactes.
- La readiness est recalculée à chaque publication de cohorte. Un membre revenu à
  son slot redevient opérationnel; un promu ne peut pas attaquer avant d'avoir
  physiquement comblé la vacance.

## Résultats Forge avant / après

| Contrat | Avant | Après |
|---|---:|---:|
| Région de navigation Forge | absente | bake valide |
| Hoplites testés avec `NavigationAgent3D` | 0/6 | 6/6 |
| Détour autour d'un obstacle Forge | non disponible | chemin multi-points PASS |
| Retry du plus ancien waiter | perd sa place | ordre conservé |
| Combat prolongé de la phalange | 2 attaques puis blocage | 8 attaques / 5 s simulées |
| File/leases en fin de combat | waiters bloqués, 0 lease | file vide, 0 lease |
| Remplacement du premier rang | téléporté dans l'ancien test | déplacement réel ≤ 0,92 m du slot en 2 s |
| Membre revenu après assemblage dégradé | reste inéligible | `member_ready == true` |

## Non-régression et performance

Les probes de scheduler, cohorte, navigation, foule, comportement, animation,
démembrement, stress 36 unités, Forge et cycle éditeur passent. `ngeneral` et
`ngeneral_veteran` conservent 12/12 zones anatomiques et 10/10 sections.

Le benchmark comparable `ngeneral active 36` a été rejoué trois fois. La médiane
du p95 cadencé est `20,714 ms`, contre `20,715 ms` dans la mesure finale de la
refonte. Les nœuds (`2 562`) et objets (`5 251`) restent identiques dans ce harness;
la mémoire statique varie d'environ `+24 Ko` (`+0,04 %`). Les snapshots moteur
restent diagnostiques et ne justifient aucune revendication de gain CPU causal.

## Probe ajoutée

`tools/forge_hoplite_behavior_regression_probe.gd` couvre dans une même vraie route
Forge : bake/détour NavMesh, présence des agents, FIFO via le contrôleur réel,
combat prolongé, remplacement physique et récupération d'un membre dégradé.
