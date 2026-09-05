# Forge — dimensions, couches de terrain et végétation

## Décisions

- Le terrain reste un `StaticBody3D` heightfield unique par chapitre.
- `width` et `depth` définissent sa taille physique en mètres, indépendamment de `resolution`.
- Changer la résolution rééchantillonne les hauteurs et les cartes peintes au lieu d'effacer le travail.
- Le matériau du terrain mélange une base globale et toute la palette locale au moyen de splat maps RGBA et d'un `Texture2DArray` partagé.
- Les poids peints de chaque matériau sont sérialisés avec le terrain ; le shader retient les contributions dominantes par pixel sans imposer une limite globale de trois textures au terrain.
- La végétation utilise des `MultiMeshInstance3D` sans collision, répartis de façon déterministe à partir d'une carte de densité.
- Une sélection du Stylized Nature MegaKit de Quaternius est importée sous licence CC0 ; les modèles sont recolorés/échelonnés dans Godot si nécessaire.
- Le sol herbeux utilise une nouvelle texture méditerranéenne générée pour le projet, distincte des atlas de feuillage du pack.

## Arbre runtime

```text
Terrain (StaticBody3D)
├── TerrainMesh (MeshInstance3D / ArrayMesh / UV de splat map)
├── TerrainCollision (CollisionShape3D / HeightMapShape3D)
└── TerrainFoliage (Node3D)
    ├── GrassShort (MultiMeshInstance3D)
    ├── GrassTall (MultiMeshInstance3D)
    └── AccentPlants (MultiMeshInstance3D)
```

## Données sérialisées

- `width`, `depth` : dimensions physiques.
- `heights` : hauteur par sommet.
- `material` : matériau de base.
- `material_palette` : identifiants de tous les matériaux disponibles pour ce terrain.
- `material_weights` : un poids par matériau et par sommet ; les anciens triplets sont migrés automatiquement.
- `foliage_density` : densité peinte par sommet.
- `foliage_preset`, `foliage_seed`, `foliage_amount` : rendu déterministe.

## Tâches et skills

- [x] Dimensions et rééchantillonnage — `using-godot-prompter`, `procedural-generation`, `3d-essentials`.
- [x] Shader et peinture locale — `3d-essentials`, `godot-ui`, `gdscript-patterns`.
- [x] Végétation MultiMesh — `3d-essentials`, `assets-pipeline`, `procedural-generation`.
- [x] Texture méditerranéenne — `imagegen`, `assets-pipeline`.
- [x] Documentation et validation — `godot-testing`, `godot-debugging`, `godot-code-review`.
