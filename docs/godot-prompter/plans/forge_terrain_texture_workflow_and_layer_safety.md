# Forge — flux Terrain/Textures et palette de peinture

## Décisions

- `Terrain` conserve son pinceau de modelage : Monter, Creuser, Lisser et Aplanir, avec rayon et force.
- `Terrain` conserve aussi la végétation `MultiMesh` et le choix de la texture globale appliquée en un clic à tout le heightfield.
- `Textures & matériaux` possède directement le pinceau local : texture active, rayon, force, peinture et retour progressif à la base.
- Choisir une texture depuis cet onglet le garde ouvert et équipe le pinceau terrain automatiquement.
- La peinture n'utilise plus trois couches globales recyclables. Chaque matériau du catalogue possède son propre poids par sommet.
- Le shader regroupe ces poids dans des splat maps RGBA, partage les albedos dans un `Texture2DArray` et mélange les contributions dominantes par pixel.
- Ajouter une texture ne peut donc plus supprimer la même couche sur une autre partie du terrain.
- Les documents existants à trois canaux sont migrés vers la palette complète lors de leur normalisation.

## Flux de données

```text
Terrain > texture globale
  -> properties.material
  -> base_layer_index du shader
  -> poids locaux inchangés

Textures > choix d'un matériau
  -> activation du mode terrain/paint
  -> clic-glisse dans la vue
  -> properties.material_palette + properties.material_weights
  -> splat maps RGBA reconstruites pour le shader
```

## Tâches et skills

- [x] Réorganisation de l'interface — `using-godot-prompter`, `godot-brainstorming`, `godot-ui`.
- [x] Texture globale et pinceaux séparés — `3d-essentials`, `gdscript-patterns`.
- [x] Palette complète, splat maps et tableau de textures — `shader-basics`, `assets-pipeline`.
- [x] Diagnostic du recyclage destructif — `godot-debugging`.
- [x] Probes de migration et de flux Forge — `godot-testing`.
- [x] Validation finale — `godot-code-review`.
