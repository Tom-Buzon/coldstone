# Forge — anti-répétition PBR et stabilité temporelle

## Diagnostic

- Les matériaux PBR raccordables contournaient le second échantillon
  anti-répétition quand `mirror_repeat` était désactivé.
- Les anciennes textures 3D, y compris l'herbe et les cartes PBR, étaient
  importées sans mipmaps ni compression GPU.
- Les cartes normales PBR n'étaient pas marquées comme cartes normales.
- L'herbe albedo contient beaucoup de détails fins : sans mipmaps, ils deviennent
  des pixels instables lorsque la caméra se déplace.

## Décisions

- Conserver les chemins et UID des textures PBR existantes afin que les mondes
  sauvegardés restent compatibles.
- Remplacer la source `brown_mud_leaves_01`, incompatible sur de grandes
  surfaces à cause de ses amas macroscopiques, sous ses trois noms historiques.
  Sa normale et sa rugosité sont dérivées du nouvel albédo pour garantir
  l'alignement PBR.
- Mélanger deux projections décorélées pour toutes les textures répétables, avec
  les mêmes coordonnées et le même masque sur les trois cartes PBR.
- Échantillonner seulement les axes triplanaires dont le poids est visible. Sur
  les sols et murs plans, cela compense le second échantillon et réduit souvent
  le coût par rapport au shader précédent.
- Activer compression VRAM et mipmaps sur toutes les textures Poly Haven et sur
  l'herbe, puis déclarer correctement les cartes normales.
- Désactiver le relief dérivé de l'herbe : sa microstructure doit venir des
  mipmaps, pas de dérivées écran instables.

## Tâches

- [x] Corriger l'import des textures 3D existantes.
  Skills : `assets-pipeline`, `godot-optimization`
- [x] Étendre le mélange anti-répétition aux cartes PBR synchronisées.
  Skills : `shader-basics`, `3d-essentials`
- [x] Réduire les lectures triplanaires aux axes réellement visibles.
  Skills : `shader-basics`, `godot-optimization`
- [x] Stabiliser l'herbe et ajouter les régressions d'import/shader.
  Skills : `godot-debugging`, `godot-code-review`
- [x] Vérifier sur le renderer Compatibility réel et dans la Forge.
  Skills : `godot-debugging`, `godot-code-review`
