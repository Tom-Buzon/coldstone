# Animation Runtime Monitoring Dashboard

## Objectif

Faire du runtime Godot la source de vérité du Workbench Blender pour les 15
personnages 3DGen et leurs familles d'armes. Le dashboard doit distinguer une
animation réellement jouée d'un fallback de foule, d'une source seulement
utilisée pour la preview, d'une animation future ou d'une déclaration
inatteignable.

## Architecture

```text
EnemyArchetypes + ExternalAnimationBank + SharedHopliteLibrary
                         |
            EnemyAnimationRuntimeContract
                 |                    |
          AthenianEnemy          Manifest builder
                                      |
                    animation_workbench_manifest.json
                                      |
                         Blender monitoring dashboard
```

`EnemyAnimationRuntimeContract` possède uniquement les règles stables de
résolution : type de driver, mode détaillé/foule, clip runtime, provenance,
fidélité de preview et accessibilité. Il ne charge aucune scène et ne pilote
aucune animation.

## Données du manifeste

Chaque action expose notamment :

- `runtime_reachable` et `runtime_truth` ;
- `runtime_modes` (`detailed`, `mass`, `lightweight`) ;
- `runtime_source_path` et `runtime_source_clip` ;
- `preview_source_path`, `preview_source_clip` et `preview_fidelity` ;
- `provenance`, `provenance_label` et `provenance_color` ;
- `weapon_family`, `full_body`, `hips_weight` et `start_fraction`.

Le manifeste contient également un index dynamique par arme et un résumé des
incohérences. Les overrides Blender restent séparés et leur priorité actuelle
est conservée.

## Interface Blender

Un panneau `Monitoring runtime` précède l'éditeur existant :

- vue par personnage ou par arme ;
- filtres de provenance, de statut et recherche texte ;
- pastille colorée par provenance ;
- colonnes propriétaire, arme, action, clip runtime et statut ;
- bouton pour ouvrir la ligne dans l'éditeur et lancer la preview disponible ;
- avertissement explicite lorsque la preview est approximative ou impossible.

## Tâches

- [ ] Contrat de résolution runtime partagé.
  Skills: `godot-prompter:animation-system`, `godot-prompter:assets-pipeline`
- [ ] Manifeste enrichi et agrégation par arme.
  Skills: `godot-prompter:animation-system`, `godot-prompter:assets-pipeline`
- [ ] Dashboard et navigation Blender.
  Skills: `3dblender`
- [ ] Probes de cohérence personnages/armes et self-test Blender.
  Skills: `godot-prompter:godot-testing`, `godot-prompter:godot-debugging`
- [ ] Revue finale.
  Skills: `godot-prompter:godot-code-review`
