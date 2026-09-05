# Bibliothèque Blender V2

Bundle runtime importé en une seule passe après validation de la production externe.

- 92 assets répartis dans 14 catégories.
- 398 fichiers GLB : LOD, collisions, occluders, pièces articulées et variantes destructibles.
- `asset_manifest.json` dans chaque dossier d’asset.
- `library_audit.json` à la racine : audit autoritaire des 92 sources Blender.
- Échelle : 1 unité = 1 mètre.
- Axe vertical dans Godot : Y ; face avant : -Z.
- Standard : `V2_HERO`.

Validation Godot 4.7 du 25 août 2026 : 398/398 GLB importés, chargés et instanciés,
92/92 scènes `LOD0` présentes et 16 984 `MeshInstance3D` détectés. Le détail machine-lisible
est conservé dans `import_validation.json`.

Godot a extrait 295 images JPEG embarquées dans les GLB. Elles sont conservées dans ce bundle :
ce sont les sources de texture utilisées par l’importeur Godot, avec leurs fichiers `.import`,
et non les rendus de production Blender.

Dans la Forge, cette bibliothèque apparaît sous **Objets 3D > BLENDER — PRODUCTION V2**.
Elle reste séparée du catalogue historique et conserve ses 14 familles physiques. Les 92 images
du dossier `thumbnails/` servent uniquement aux aperçus de la Forge.

Les sources `.blend`, sauvegardes et rendus de production restent archivés hors du projet dans
`C:\Users\suean\Downloads\blenderAseet\_production_v2`. Cela évite que Godot importe à la fois
les sources Blender et leurs exports glTF.

Le fichier principal d’un asset est `<asset>_LOD0.glb`. Les fichiers contenant `LOD1`, `LOD2`,
`collision`, `occluder`, `intact`, `fractured` ou le nom d’une pièce mobile sont des variantes
techniques destinées aux systèmes de rendu, collision, destruction ou articulation.
