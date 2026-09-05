# Dinosaures de la Forge et ptérodactyle de faune

## Objectif

Importer les trois GLB Sketchfab avec leurs animations. Le vélociraptor et le tyrannosaure deviennent des personnages hostiles plaçables dans la Forge. Leur silhouette animée est couverte par un ensemble de capsules/sphères suivant les os : ces volumes servent à la localisation des coups et au wall-run. La tête et le cou sont des zones de décapitation. Le ptérodactyle reste un agent de faune aérien purement décoratif, sans collision.

## Arbre de scène à l'exécution

```text
HopliteDinosaurEnemy (CharacterBody3D)
├── BodyCollider (CollisionShape3D, déplacement au sol)
├── AnimatedVisual (GLB instancié)
│   └── Skeleton3D + AnimationPlayer importés
├── DinosaurAnatomy (Area3D, couche de dégâts 8)
│   └── capsules/sphères animées par os
└── TraversalSurfaces (Node3D)
    └── AnimatableBody3D par zone (couche wall-run 256)

RuntimeFauna
└── HopliteFaunaAgent: pterodactyl
    └── AnimatedVisual (GLB, boucle de vol, aucune collision)
```

## Responsabilités

- `enemy_archetypes.gd` porte les statistiques, dimensions, chemins de modèles et paramètres de meute/solitaire.
- `enemy_factory.gd` sélectionne le contrôleur dinosaure sans modifier le contrat commun `HopliteAthenianEnemy`.
- `dinosaur_enemy.gd` gère une petite machine d'états (`IDLE`, `HUNT`, `WINDUP`, `ATTACK`, `RECOVERY`, `DEAD`), les clips importés, la poursuite, l'attaque, les zones anatomiques et la mort par décapitation.
- Les vélociraptors d'un même groupe Forge partagent leur cible et se répartissent autour d'elle. Le T-rex n'appelle aucun allié et évite les autres T-rex proches.
- `fauna_settings.gd` déclare le ptérodactyle comme espèce aérienne. `fauna_agent.gd` conserve son comportement léger et choisit sa boucle `Animation` comme vol.
- La bibliothèque d'assets référence le nouveau dossier de faune, avec collisions explicitement désactivées.

## Flux de dégâts et traversée

```text
os animé → zone anatomique → copie physique AnimatableBody3D
                       ├── coup localisé → santé / seuil de section
                       └── raycast wall-run → giant_owner → dinosaure vivant

tête/cou sectionné → zone désactivée → surfaces tête/cou désactivées
                  → signal zone_severed → mort + animation de mort
```

Les surfaces sont convexes et composées, jamais des meshes concaves mobiles. Le collider racine reste volontairement simple pour une locomotion stable ; la forme détaillée appartient aux volumes animés.

## Charge du tyrannosaure

```text
HUNT → WINDUP (direction du joueur verrouillée une fois)
     → ATTACK (charge rectiligne, aucune correction de rotation)
     → RECOVERY (arrêt et orientation figée)
     → HUNT
```

La portée de déclenchement de la charge est supérieure à la portée de morsure. La fenêtre `WINDUP` télégraphie la ligne dangereuse et permet l'esquive ; la fenêtre `RECOVERY` laisse au joueur le temps de contourner le T-rex, d'aborder son dos et d'utiliser ses surfaces de wall-run. Une perte passive d'un wall-run vertical sur une surface dynamique ne reçoit aucune impulsion de saut supplémentaire ; un wall-jump explicitement déclenché par le joueur conserve son impulsion.

## LOD des dinosaures

Les dinosaures consomment les mêmes distances configurables que le LOD global des ennemis de la Forge :

- `LOD0` (proche) : animation à pleine fréquence, anatomie et surfaces de wall-run exactes, physique complète pendant le contact et les attaques.
- `LOD1` (moyen) : animation échantillonnée à la fréquence moyenne, ombres coupées, IA espacée, anatomie conservée mais surfaces de traversal retirées du broadphase.
- `LOD2` (loin) : animation à basse fréquence, anatomie et traversal désactivés, IA fortement espacée et mesh LOD plus agressif.
- `LOD3` (hors portée) : rendu et animation suspendus, IA gelée jusqu'au retour dans la portée de culling.

`DinosaurEnemy` est l'unique autorité de cadence de ses zones animées : `AnatomyHitbox` ne s'auto-évalue pas en parallèle. Près du joueur, une seule mise à jour anatomique suivie d'une synchronisation traversal est effectuée après la locomotion. Les états `WINDUP`, `ATTACK` et `RECOVERY` du T-rex, ainsi que tout contact proche du joueur, conservent toujours la physique pleine fréquence.

## Tâches et compétences

- Audit/import/licences : `assets-pipeline`, `animation-system`.
- Contrôleur et états : `state-machine`, `component-system`, `ai-navigation`.
- Collisions animées et wall-run : `physics-system`, `3d-essentials`.
- Catalogue de faune : `procedural-generation`, `assets-pipeline`.
- Validation : `godot-debugging`, `godot-code-review` et vérifications du projet.
- LOD dinosaure : `godot-optimization`, `animation-system`, `physics-system`, `ai-navigation`, `3d-essentials`.
