# Forge — dimensions, couches de terrain et végétation

## Décisions

- Le terrain reste un `StaticBody3D` heightfield unique par chapitre.
- `width` et `depth` définissent sa taille physique en mètres, indépendamment de `resolution`.
- Changer la résolution rééchantillonne les hauteurs et les cartes peintes au lieu d'effacer le travail.
- Le matériau du terrain mélange une base et trois couches locales par couleurs de sommets.
- Les poids peints sont sérialisés avec le terrain ; le maillage et le shader sont reconstruits depuis ces données.
- La végétation utilise des `MultiMeshInstance3D` sans collision, répartis de façon déterministe à partir d'une carte de densité.
- Une sélection du Stylized Nature MegaKit de Quaternius est importée sous licence CC0 ; les modèles sont recolorés/échelonnés dans Godot si nécessaire.
- Le sol herbeux utilise une nouvelle texture méditerranéenne générée pour le projet, distincte des atlas de feuillage du pack.

## Arbre runtime

```text
Terrain (StaticBody3D)
├── TerrainMesh (MeshInstance3D / ArrayMesh / vertex colors)
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
- `paint_layers` : trois identifiants de matériaux locaux.
- `material_weights` : trois poids par sommet.
- `foliage_density` : densité peinte par sommet.
- `foliage_preset`, `foliage_seed`, `foliage_amount` : rendu déterministe.

## Tâches et skills

- [x] Dimensions et rééchantillonnage — `using-godot-prompter`, `procedural-generation`, `3d-essentials`.
- [x] Shader et peinture locale — `3d-essentials`, `godot-ui`, `gdscript-patterns`.
- [x] Végétation MultiMesh — `3d-essentials`, `assets-pipeline`, `procedural-generation`.
- [x] Texture méditerranéenne — `imagegen`, `assets-pipeline`.
- [x] Documentation et validation — `godot-testing`, `godot-debugging`, `godot-code-review`.
