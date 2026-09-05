# theWolf — boss et laboratoire Forge

## Objectif

Créer un boss quadrupède à partir du `Wolf.gltf` de Quaternius, disponible
directement dans les personnages de la Forge sous deux difficultés :

- `THE WOLF — MID` : deux phases lisibles et rapides ;
- `THE WOLF — VETERAN` : trois phases, chaînes d’attaques plus longues et
  accélération supplémentaire.

Le combat doit valoriser la vitesse du joueur, le double saut et le wall-run,
sans demander de nouvelle animation Blender pour la première version.

La mobilité concernée est celle du joueur. Les mouvements du loup servent à
créer des trajectoires et des fenêtres, pas à remplacer ce contrat.

## Architecture retenue

Le boss reste compatible avec `HopliteEnemyFactory` et les groupes ennemis de
la Forge en héritant du contrat `HopliteAthenianEnemy`, mais il remplace
entièrement la présentation et la physique humanoïdes par son propre contrôleur.
Une FSM enum légère possède cinq états : introduction, chasse, télégraphe,
attaque et récupération. La phase de combat reste une préoccupation séparée.

```text
theWolf (HopliteWolfBoss / CharacterBody3D)
├── BodyCollider (capsule primitive)
├── AnimatedVisual (Wolf.gltf)
├── WolfBossHitbox (Area3D)
│   ├── Torso
│   ├── Head
│   └── Flanks
├── BossOrnaments (cornes/cristaux légers)
├── AuraRing + PhaseLight
└── BossReadout (Label3D + barre de vie)
```

## Phases et identité du combat

### Phase I — La Traque

- poursuite circulaire très mobile ;
- morsure en dash avec ligne télégraphiée ;
- bond vertical avec zone d’atterrissage, esquivable par double saut.

### Rupture de mobilité — mécanique centrale

- les coups ordinaires au sol infligent des dégâts réduits à l’armure lunaire ;
- dash, slide, attaque aérienne et frappe de wall-run remplissent une jauge ;
- un vrai second saut ou une frappe au sortir d’un wall-run apporte un bonus
  important à cette jauge ;
- à la rupture, le loup s’effondre quelques secondes et son cœur lunaire subit
  environ deux fois les dégâts normaux.

Le boss reste théoriquement battable au sol, mais la maîtrise de la mobilité
réduit très fortement la durée et le danger du combat. L’émotion recherchée est
celle d’un accès mérité au point faible, sans reproduire l’escalade du géant.

### Phase II — Lune sanglante

- transition avec hurlement, changement d’aura et onde non dommageable ;
- dash doublé et récupération plus courte ;
- onde lunaire au sol que le joueur doit franchir par saut ou wall-run.

### Phase III Veteran — Fenrir déchaîné

- transition violette/blanche très visible ;
- chaîne de trois ruées ;
- bond puis double onde, cadence et dégâts augmentés.

## Laboratoire Forge

Un monde sauvegardé `Laboratoire de theWolf` comporte deux ailes indépendantes :

- aile gauche : boss Mid, déclenché à l’entrée ;
- aile droite : boss Veteran, déclenché à l’entrée ;
- murs continus de 6 à 8 mètres pour le wall-run ;
- piliers, plateformes et différences de hauteur pour les doubles sauts ;
- éclairage nocturne rouge/violet et décor lisible ;
- zone centrale de choix pour éviter d’activer les deux combats ensemble.

## Tâches et compétences

- [x] Ajouter les profils Mid/Veteran et la route spécialisée de fabrique.
  Compétences : `godot-brainstorming`, `component-system`.
- [x] Implémenter la FSM, les phases, attaques, dégâts et télégraphes.
  Compétences : `state-machine`, `ai-navigation`, `physics-system`.
- [x] Exploiter les animations du loup et ajouter l’identité visuelle du boss.
  Compétences : `animation-system`, `3d-essentials`.
- [x] Exposer les deux variantes dans la Forge et générer le laboratoire.
  Compétences : `godot-brainstorming`, `3d-essentials`.
- [x] Ajouter les probes et mesurer la charge du boss.
  Compétences : `godot-debugging`, `godot-optimization`, `godot-code-review`.

## Validation réalisée

- `the_wolf_boss_probe.gd` : modèle, animations, multiplicateurs de dégâts,
  rupture de mobilité, mouvement IA et impossibilité de sauter une phase ;
- `enemy_phase_contract_probe.gd` : deux phases Mid et trois phases Veteran ;
- `the_wolf_forge_room_probe.gd` : présence dans Personnages et Modèles 3D,
  validation du monde, apparition séparée des deux variantes et géométrie mobilité ;
- `enemy_factory_registry_probe.gd` et `world_editor_probe.gd` : régressions
  générales de fabrique et de Forge ;
- analyse Godot complète du projet et capture Compatibility sans erreur.

La charge permanente est limitée à un `_physics_process` par boss actif. Le
modèle est chargé via le cache glTF partagé ; les télégraphes sont temporaires,
les lumières n’ont pas d’ombres et aucun système de particules continu n’est
créé.
