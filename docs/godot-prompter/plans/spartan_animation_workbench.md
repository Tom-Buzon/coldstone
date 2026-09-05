# Spartan Animation Workbench — plan d'implémentation

Date : 31 août 2026

## Objectif

Fournir un pipeline reproductible permettant de régénérer l'inventaire des
personnages et animations, de les inspecter/éditer dans Blender, puis de publier
les nouvelles correspondances dans le jeu actuel sans bloquer la future
migration EnemyV2.

## Contrat d'architecture

```text
3DGen (mesh + rig)
        |
        v
Spartan manifest generator ----> animation_workbench_manifest.json
        |                                      |
        |                                      v
        |                         Blender Animation Workbench
        |                                      |
        |                                      v
        +---------------------- workbench_overrides.json
                                               |
                                               v
                                  runtime publisher/validator
                                               |
                                               v
                                  runtime_bindings.json
```

- Le manifeste généré est un inventaire, jamais une source éditée à la main.
- Les choix de l'utilisateur vivent dans `workbench_overrides.json`.
- Les projets Blender éditables vivent sous `tools/animation_workbench/projects`
  et sont exclus de l'import Godot.
- Le runtime ne lit que `assets/animations/generated/runtime_bindings.json`.
- La résolution des affectations suit toujours `rig commun < arme < personnage`.
- Les fallbacks codés restent valides lorsque le fichier généré est absent,
  invalide ou ne contient pas la clé demandée.
- 3DGen ne reçoit aucune responsabilité de gameplay ou d'animation Spartan.

## Phases

- [x] **Phase 1 — Contrat et lanceurs** — Créer les trois commandes Windows,
  les dossiers de sources et la documentation.
  Skills: `using-godot-prompter`, `assets-pipeline`, `animation-system`.
- [x] **Phase 2 — Manifeste** — Scanner les archétypes 3DGen, les actions de
  gameplay et toutes les sources d'animation connues.
  Skills: `animation-system`, `gdscript-advanced`.
- [x] **Phase 3 — Workbench Blender** — Naviguer par personnage/action/source,
  charger un modèle, prévisualiser/retargeter un clip, enregistrer un override
  et créer une action Blender.
  Skills: `3dblender`, `animation-system`.
- [x] **Phase 4 — Publication transitoire** — Publier les overrides compatibles
  vers le système de donneurs actuel, avec priorité rig commun, arme, personnage.
  Skills: `animation-system`, `assets-pipeline`.
- [x] **Phase 4.1 — Sécurité d'édition** — Profils virtuels, preview automatique,
  diagnostic des premières frames, projets `.blend`, JSON et autosauvegarde.
  Skills: `godot-brainstorming`, `animation-system`, `assets-pipeline`, `3dblender`.
- [ ] **Phase 5 — Bake EnemyV2 complet** — Générer les bibliothèques 23 os,
  supprimer les donneurs/proxies et migrer les archétypes un par un.
  Skills: `animation-system`, `godot-optimization`, `godot-testing`.

La phase 5 reste volontairement séparée : le Workbench et son manifeste sont
conçus pour l'alimenter sans changer de format de données.
