# Forge — bibliothèque naturelle et peinture de végétation

## Décision

Le pack Quaternius devient une source commune pour deux usages distincts :

- des objets 3D individuels, classés dans la bibliothèque de la Forge ;
- des couches de végétation peintes sur le terrain et rendues avec `MultiMeshInstance3D`.

Les fichiers sources sont rangés physiquement par famille (`trees`, `shrubs`, `ground_cover`, `rocks`, `stone_paths`) et le catalogue expose la même hiérarchie sous forme de dossiers repliables. Les anciens chemins sont migrés lors du chargement des documents.

## Arbre de responsabilités

```text
HopliteWorldEditor
├── Bibliothèque 3D (FoldableContainer par catégorie)
└── Outils Terrain
    ├── choix du type local de végétation
    ├── rayon / force visibles à côté du pinceau
    └── peinture locale dans les cartes du terrain

HopliteWorldTerrain
└── données persistantes : densité + type local par cellule

HopliteWorldTerrainFoliage
└── TerrainFoliage
    └── MultiMeshInstance3D par variante réellement utilisée
```

## Flux de données

1. Le catalogue scanne les racines puis attribue une sous-catégorie stable à chaque modèle.
2. La bibliothèque affiche les sous-catégories sans charger les scènes 3D dans l'interface.
3. Le pinceau écrit la densité et le mélange choisi dans les cartes du terrain.
4. La reconstruction échantillonne ces cartes, groupe les transforms par variante et crée au plus un `MultiMeshInstance3D` par mesh utilisé.
5. L'édition utilise un budget réduit ; le test utilise le budget runtime, sans créer un nœud par brin.

## Tâches

- [x] Importer et ranger les 68 modèles glTF et leurs textures.
  Skills: `assets-pipeline`, `3d-essentials`
- [x] Ajouter les métadonnées et dossiers repliables à la bibliothèque.
  Skills: `godot-ui`, `assets-pipeline`
- [x] Ajouter les types locaux et les contrôles ergonomiques du pinceau.
  Skills: `godot-ui`, `3d-essentials`
- [x] Corriger la reconstruction/persistance et valider les MultiMesh runtime.
  Skills: `godot-debugging`, `godot-optimization`, `godot-testing`
- [x] Revoir le code et documenter l'utilisation.
  Skills: `godot-code-review`
