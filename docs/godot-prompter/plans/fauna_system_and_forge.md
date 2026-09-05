# Faune Quaternius — conception et plan d’implémentation

## Objectif

Ajouter une faune 3D légère, réglable en jeu espèce par espèce, issue du pack
CC0 `Ultimate Animated Animal Pack` et de l’aigle du petit `Animal Pack Vol.2`.
Les mêmes modèles doivent apparaître automatiquement dans le catalogue 3D de
la Forge avec une animation d’attente ou de vol déjà active.

## Architecture retenue

Une simulation légère pilotée par un gestionnaire est préférable à un
`NavigationAgent3D` et un corps physique par animal. Les animaux n’ont donc ni
collision gameplay, ni ombres, ni évitement RVO. Les animaux terrestres
rééchantillonnent le sol à 10 Hz pendant leur déplacement ; les comportements
sont évalués à cadence réduite et décalée entre les instances.

```text
CurrentScene (Node3D)
└── RuntimeFauna (HopliteFaunaManager, Node3D)
    ├── Cow_001 (HopliteFaunaAgent, Node3D)
    │   └── Quaternius glTF (Skeleton3D + MeshInstance3D + AnimationPlayer)
    ├── Fox_001 (HopliteFaunaAgent, Node3D)
    │   └── Quaternius glTF
    └── Eagle_001 (HopliteFaunaAgent, Node3D)
        └── Quaternius GLB

Player
└── PlayerPresentation
    └── PlayerSettings (CanvasLayer)
        └── TabContainer
            └── FAUNE
                ├── Réglages globaux
                └── Une ligne par espèce : actif, quantité, comportement
```

## Responsabilités

| Élément | Responsabilité |
|---|---|
| `fauna_settings.gd` | Catalogue des espèces, valeurs par défaut, validation et clés de sauvegarde |
| `fauna_manager.gd` | Budget total, spawn progressif, redistribution, culling et échantillonnage du sol |
| `fauna_agent.gd` | Déplacement lissé, comportement local et sélection automatique des animations |
| `audio_settings.gd` | Onglet de réglages en jeu et sauvegarde dans le ConfigFile global |
| `asset_library_room.gd` | Découverte automatique des glTF/GLB de faune dans la bibliothèque de la Forge |
| `world_runtime.gd` | Lecture automatique de l’animation Idle/Flying sur une faune placée comme prop |

## Flux de données

```text
Ouverture des paramètres
  -> lecture user://hoplite_global_settings_v1.cfg
  -> l’onglet FAUNE reflète les valeurs validées

Modification d’une espèce
  -> sauvegarde ConfigFile
  -> FaunaManager.reload_fauna_settings(values)
  -> calcul équitable des cibles sous le budget global
  -> retrait immédiat des excédents + ajout progressif des manquants
  -> agents existants reçoivent le nouveau comportement sans réimport

Bouton « nouvelle répartition »
  -> nouvelle graine
  -> suppression des agents courants
  -> respawn progressif autour du joueur
```

## Garde-fous de performance

- Budget global dur de 64 animaux, plafond par défaut à 20 (19 animaux demandés par le préréglage initial).
- Un seul nouveau modèle instancié par intervalle de spawn.
- Aucune ombre ni collision pour la faune procédurale.
- Logique comportementale à 4 Hz par défaut, décalée par agent.
- Animation et logique suspendues hors distance de simulation.
- Aucun `NavigationAgent3D` pour les oiseaux ; déplacement aérien direct.
- Graine dédiée pour une répartition reproductible.

## Tâches et compétences GodotPrompter

- [x] Importer les sources CC0 et préserver les clips glTF/GLB.
  Compétences : `assets-pipeline`, `animation-system`.
- [x] Implémenter catalogue, gestionnaire et agents légers.
  Compétences : `resource-pattern`, `component-system`, `ai-navigation`, `procedural-generation`, `godot-optimization`.
- [x] Ajouter l’onglet FAUNE aux paramètres en jeu.
  Compétence : `godot-ui`.
- [x] Exposer les modèles dans la Forge avec animation automatique.
  Compétences : `assets-pipeline`, `animation-system`.
- [x] Valider l’import, les comportements et les garde-fous.
  Compétences : `godot-debugging`, `godot-code-review`, `godot-optimization`.

## Validation réalisée

- `fauna_system_probe.gd` : 13/13 modèles instanciables, animations attendues, catalogue Forge, population et onglet FAUNE validés.
- Démarrage headless complet de la scène principale sans erreur d’intégration liée à la faune.
- `fauna_performance_probe.gd` : physique réelle mesurée à environ 0,82 ms pour le préréglage initial de 19 animaux et 3,01 ms au plafond extrême de 64 animaux sur la machine de validation headless.

## Correctif locomotion, relief et eau

Diagnostic : les clips glTF/GLB `Idle`, `Walk`, `Gallop` et `Flying` sont tous
importés en `LOOP_NONE`. À la fin du clip, Godot vide `current_animation`, ce qui
empêchait l’ancien rappel conditionnel de les relancer. De plus, le déplacement
horizontal ne rééchantillonnait le terrain qu’à la destination.

Architecture corrective retenue :

- [x] Forcer uniquement les clips cycliques utilisés par la faune en
  `Animation.LOOP_LINEAR`, avec fondu court lors des changements d’état.
  Compétence : `animation-system`.
- [x] Déplacer les agents terrestres dans `_physics_process()` et reprojeter
  leur hauteur à cadence limitée, tout en vérifiant chaque pas horizontal.
  Compétences : `physics-system`, `ai-navigation`, `godot-optimization`.
- [x] Ajouter un composant géométrique `HopliteFaunaWaterBlocker` aux nappes
  d’eau de la Forge. Il ne crée aucune collision physique et permet de rejeter
  les cibles ou pas qui entrent dans l’eau ; l’aigle peut naturellement la
  survoler.
  Compétences : `component-system`, `physics-system`.
- [x] Corriger l’axe avant particulier de l’aigle du petit pack afin qu’il
  regarde dans le sens du vol.
  Compétence : `animation-system`.
- [x] Ajouter une scène de test avec pente, eau et aigle, puis rejouer les probes de
  faune, Paramètres et Forge.
  Compétences : `godot-debugging`, `godot-code-review`.

Validation du correctif :

- `fauna_terrain_water_probe.gd` : boucle des animations, suivi de pente,
  refus de l’eau, passage surélevé et orientation de vol de l’aigle validés.
- `fauna_system_probe.gd` : 13 espèces, imports, Forge, population et onglet
  FAUNE validés après correction.
- `world_editor_probe.gd` : intégration de la Forge validée.
