# Arsenal mythique du personnage principal

## Direction retenue

Créer un duo d'équipement original, inspiré par la fantasy épique et la mythologie guerrière sans reproduire un objet existant :

- **Lame d'Égide** : épée longue à silhouette effilée, épine centrale sombre, garde en croissants de bronze et accents runiques cyan. Longueur totale cible : environ 1,75 m, avec un segment de contact jouable de 1,29 m.
- **Égide du Titan** : bouclier vertical légèrement bombé, contour bronze, quatre plaques sombres, oméga central et accents runiques cyan. Dimensions cibles : environ 0,88 × 1,08 m.

Le personnage conserve ses `BoneAttachment3D` existants. Les deux GLB remplacent les visuels générés ou importés actuels, et les marqueurs de lame sont alignés sur la nouvelle géométrie afin que la portée visuelle et la portée de combat restent identiques.

## Contrat d'asset

- Blender en mètres, Godot +Y vers le haut et -Z vers l'avant.
- Pivot de l'épée au centre de la prise, lame le long de +Y dans Godot.
- Pivot du bouclier au centre de la poignée, face du bouclier dans le plan XY de Godot.
- Un seul `MeshInstance3D` par équipement après import.
- Matériaux PBR simples et embarqués dans les GLB, sans textures externes.
- Les fichiers de présentation Blender restent dans `tools/blender/hero_arsenal/output/`.

## Tâches

- [ ] **Créer le générateur Blender déterministe et les deux assets.**\
  Skills: `3dblender`, `3d-essentials`, `assets-pipeline`
- [ ] **Intégrer les GLB aux points d'attache du joueur et aligner le segment de contact.**\
  Skills: `gdscript-patterns`, `3d-essentials`
- [ ] **Ajouter une sonde de régression pour les trois skins du joueur.**\
  Skills: `godot-testing`, `gdscript-patterns`
- [ ] **Valider imports, dimensions, matériaux, attachements et portée.**\
  Skills: `godot-code-review`, `godot-debugging`, `assets-pipeline`
