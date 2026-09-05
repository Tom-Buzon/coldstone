# Forge — textures variées sans répétition carrée

## Objectif

Supprimer la lecture en carrelage régulier des matériaux de la Forge et fournir
des variantes cohérentes pour les sols, chemins, bâtiments, fortifications,
temples et ruines, sans augmenter fortement le coût GPU ou mémoire.

## Décisions

- Conserver la projection triplanaire en coordonnées monde : elle évite les UV
  étirés sur les objets procéduraux et les meshes aux orientations variées.
- Casser la grille avec une déformation continue des coordonnées et une variation
  chromatique à grande échelle. Cette approche conserve le nombre actuel de
  lectures de texture, contrairement au texture bombing multi-échantillons.
- Rendre l'intensité configurable par matériau afin de préserver les motifs
  architecturaux réguliers tout en variant davantage les sols naturels.
- Ajouter huit albedos carrés importés à 1024 px, sans éclairage directionnel ni
  élément central, conçus pour être raccordables et couvrant les lacunes du catalogue.
- Charger les textures importées via `ResourceLoader` pour bénéficier de la
  compression GPU et des mipmaps. Garder le chargement d'image manuel uniquement
  comme compatibilité pour les anciennes sources placées sous `_source/.gdignore`.

## Tâches

- [x] Ajouter les paramètres anti-répétition aux shaders surface et terrain.
  Skills : `shader-basics`, `3d-essentials`, `godot-optimization`
- [x] Propager les réglages du catalogue aux matériaux mis en cache.
  Skills : `assets-pipeline`, `gdscript-advanced`
- [x] Générer et intégrer huit textures raccordables couvrant les principaux usages.
  Skills : `imagegen`, `assets-pipeline`
- [x] Exposer les variantes dans les catégories existantes de la Forge.
  Skills : `godot-brainstorming`, `3d-essentials`
- [x] Ajouter une régression sur le catalogue, les chemins et les paramètres shader.
  Skills : `godot-debugging`, `godot-testing`, `godot-code-review`
- [x] Vérifier l'import, la compilation headless et le rendu de contrôle.
  Skills : `godot-debugging`, `godot-code-review`
