# Optimisation d'exécution des ennemis — rapport d'implémentation

Date : 28 août 2026\
Moteur mesuré : Godot 4.7 stable, headless, `gl_compatibility`

## Résultat

Cette passe réduit les appels et allocations redondants du système ennemi sans modifier sa doctrine de combat. Les priorités de cible, les cadences de réflexion, les permissions d'attaque, la constitution des cohortes, les emplacements de phalange, les promotions de réserve, les arcs d'expulsion, les sorties coordonnées et le propriétaire du mouvement restent inchangés.

Le bénéfice le mieux établi est structurel : les requêtes au `SceneTree`, à `NavigationServer3D` et les calculs collectifs ne sont plus répétés par chaque soldat lorsque la donnée n'a pas changé. Les benchmarks CPU globaux restent bruités et ne permettent pas d'annoncer honnêtement un gain uniforme sur toutes les distributions d'ennemis.

## Modifications appliquées

### Navigation individuelle

Fichier : `scripts/ai/enemy_navigation_component.gd`

- L'état carte/couches du NavMesh est mémorisé pendant 0,50 s quand il est valide.
- Une carte indisponible ou une incompatibilité de couches est retestée rapidement, après 0,12 s.
- Un changement de carte ou de masque de navigation invalide immédiatement le cache.
- Les comparaisons d'arrivée et de changement de destination utilisent des distances au carré.
- `NavigationAgent3D.get_next_path_position()` reste appelé à chaque tick physique actif : le chemin n'est donc pas « figé » par l'optimisation.

Preuve ciblée : six échantillons stables ne produisent plus qu'une seule inspection `NavigationServer3D.map_get_regions()`, soit cinq requêtes natives évitées dans la fenêtre testée.

### Instantanés de groupes gérés par la foule

Fichier : `scripts/ai/battle_crowd_director.gd`

Le gestionnaire maintient désormais des instantanés pour :

- les participants `combatant_ai` ;
- les cibles athéniennes ;
- les cibles spartiates ;
- les membres `phalanx_unit`.

Ces tableaux sont reconstruits lors d'un changement d'appartenance, pas à chaque réflexion individuelle ni à chaque actualisation spatiale. Un contrôle du nombre de membres conserve la compatibilité avec les outils ou scènes qui ajoutent directement un nœud à un groupe sans passer par l'API ennemie.

Conséquences mesurées par les probes :

- une actualisation spatiale due uniquement au déplacement ne relit aucun groupe du `SceneTree` ;
- quinze soldats demandant leur affectation dans la même cohorte déclenchent une seule reconstruction de l'instantané de phalange ;
- des recherches de cible stables réutilisent le même instantané sans nouvelle lecture du groupe.

### Voisinage et pression locale

Fichiers : `scripts/ai/battle_crowd_director.gd`, `scripts/enemy/athenian_enemy.gd`

- Chaque ennemi possède un tableau de voisinage réutilisable ; le gestionnaire le remplit au lieu de retourner un nouveau tableau temporaire.
- La pression autour d'une cible est mémorisée pour la révision courante de la grille spatiale.
- Deux demandes de capacité d'attaque pour la même cible et la même révision ne déclenchent qu'un seul balayage spatial.
- Le nettoyage des files d'attente d'attaque se fait en place au lieu de fabriquer une seconde liste.

La séparation physique reste calculée avec les mêmes rayons, pondérations et règles de faction. Seule la façon d'obtenir les candidats change.

### Construction des phalanges

Fichier : `scripts/ai/battle_crowd_director.gd`

- La signature de cohorte ne construit plus une chaîne de caractères à chaque vérification ; elle compare un tableau trié d'identifiants.
- Les nombres d'alliés et de vétérans proches sont calculés une fois pour toute la cohorte à l'aide de cellules locales de 4,6 m.
- Les affectations individuelles lisent ensuite ces résultats partagés.
- Les distances de regroupement utilisent des distances au carré.

Cette optimisation ne rend pas la phalange dépendante d'un commandant, d'un moral ou d'un ordre externe. Les soldats continuent à former leur cohorte automatiquement et à faible coût selon les règles existantes.

### LOD, squelette et pose d'équipement

Fichier : `scripts/enemy/athenian_enemy.gd`

- Les quatre réglages globaux de LOD sont lus une fois pour l'ensemble des ennemis, avec une actualisation bornée à 250 ms afin de conserver les changements en direct.
- La pose lance/bouclier de phalange suit la cadence du LOD d'animation : chaque frame près du joueur, une frame sur deux en LOD 1, une sur quatre en LOD 2, aucune en LOD 3.
- Les os masqués après démembrement ne sont réappliqués que lorsqu'ils deviennent sales ou lorsque le squelette vient réellement d'être échantillonné.
- Les itérations évitent la construction de `Dictionary.keys()` dans cette boucle.

La pose et le démembrement conservent leur précision près du joueur.

### Archers

Fichier : `scripts/enemy/athenian_enemy.gd`

- L'échantillon de sol directement sous l'archer est réutilisé pendant au plus 60 ms tant qu'il ne s'est pas déplacé de plus de 12 cm horizontalement.
- Le rayon de contrôle vers l'avant reste effectué à chaque déplacement : l'archer conserve donc sa protection contre les chutes et les bords.

### Invalidations de cycle de vie

Fichier : `scripts/enemy/athenian_enemy.gd`

L'entrée dans l'arbre, la sortie et les changements de participation IA invalident les instantanés collectifs. Plusieurs invalidations dans la même frame sont fusionnées par le gestionnaire avant la reconstruction suivante.

## Ce qui n'a pas été modifié

- aucune psychologie, morale, peur ou obéissance au commandant ;
- aucune priorité de cible ni règle de représailles ;
- aucune capacité ou cadence d'attaque ;
- aucune géométrie, rangée, promotion ou tactique de phalange ;
- aucun seuil de bataille de masse (`28`) ;
- aucun changement de propriétaire de `velocity` ou de `move_and_slide()`.

Les incohérences psychologiques identifiées dans l'audit restent donc volontairement hors périmètre.

## Validation fonctionnelle

Les probes suivants passent sur le code final de cette passe :

- navigation directe et récupération ;
- navigation réelle sur NavMesh et cache de carte/couches ;
- cadence spatiale à 20 Hz et invalidation d'appartenance ;
- ciblage par faction et stabilité des instantanés ;
- ordonnanceur/permissions d'attaque et cache de pression ;
- tactiques de foule et coordination d'engagement ;
- optimisation de phalange et récupération de cohorte ;
- anatomie localisée ;
- cadence de LOD d'animation ;
- traversée du géant ;
- comportement individuel du capitaine ;
- stress mixte : 22 familles, 36 unités, deux cohortes, cible mobile, sommeil/réveil, morts et nettoyage.

Le probe général `enemy_combat_probe` conserve un échec isolé sur l'alignement vertical de la surface marchable du crâne du géant blessé (`before=0.773`, `after=5.479`, `visual=-0.540`). Le cache expérimental des blessures a été retiré puis le même échec a été reproduit, ce qui isole ce problème du lot d'optimisation conservé. Le probe dédié `giant_traversal_probe`, y compris son état rampant, passe.

## Mesures CPU

Le point « avant » est une exécution fraîche capturée immédiatement avant la modification. Le point « après » est la médiane de trois processus frais. Les valeurs sont des temps muraux headless et incluent l'ordonnanceur Windows ; elles indiquent une tendance, pas une attribution CPU pure.

| Scénario | Mesure | Avant | Après médian | Écart |
|---|---:|---:|---:|---:|
| 56 actifs réalistes | p50 callbacks | 4,241 ms | 4,470 ms | +5,4 % |
| 56 actifs réalistes | p95 callbacks | 7,242 ms | 6,618 ms | -8,6 % |
| 56 actifs réalistes | moyenne callbacks | 4,725 ms | 4,766 ms | +0,9 % |
| 56 rôles mixtes | p50 callbacks | 5,398 ms | 5,328 ms | -1,3 % |
| 56 rôles mixtes | p95 callbacks | 7,334 ms | 7,955 ms | +8,5 % |
| 56 rôles mixtes | moyenne callbacks | 5,562 ms | 5,448 ms | -2,1 % |
| 36 `ngeneral` actifs | snapshot physique | 7,692 ms | 7,135 ms | -7,2 % |
| 36 `ngeneral` actifs | spawn | 305,093 ms | 296,348 ms | -2,9 % |

Conclusion : aucune régression massive n'apparaît, mais les p50/p95 évoluent dans des directions opposées selon le scénario. Cette campagne courte ne prouve donc pas un gain CPU global uniforme. Elle prouve en revanche les réductions de fréquence d'appels par compteurs et contrats ciblés.

Logs bruts : `.tmp_tools/enemy_refactor/callback_realistic_pre.log`, `.tmp_tools/enemy_refactor/callback_mixed_pre.log`, `.tmp_tools/enemy_refactor/ngeneral_36_pre.log`, puis `callback_{realistic_active,mixed_roles}_post_run{1,2,3}.log` et `ngeneral_36_post_run{1,2,3}.log`.

## Optimisations volontairement reportées

Ces pistes restent intéressantes, mais demandent une preuve comportementale séparée :

1. Un chemin NavMesh partagé par cohorte de phalange. Le gain potentiel est élevé, mais les couloirs étroits et obstacles peuvent changer le comportement.
2. Un sommeil de simulation complet ou une anatomie simplifiée à longue distance. Des projectiles ou événements de bataille pourraient être manqués.
3. Le pooling des projectiles, effets et débris. Chaque type doit disposer d'un contrat de remise à zéro exhaustif.
4. Une migration du ciblage entièrement autoritaire vers le registre. Toutes les routes de spawn ne prouvent pas encore une parité stricte d'ordre des candidats.

## Documents associés

- Audit comportemental et liste complète des pistes : `docs/enemy_refactor/ENEMY_BEHAVIOR_AND_PERFORMANCE_AUDIT.md`
- Plan d'implémentation et invariants : `docs/godot-prompter/plans/enemy_runtime_performance_implementation.md`
