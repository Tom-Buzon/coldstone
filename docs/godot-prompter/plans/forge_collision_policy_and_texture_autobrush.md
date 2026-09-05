# Forge — politique de collision et pinceau de texture automatique

## Décisions

- Les galets `Pebble_*` reçoivent un collider de gameplay par défaut.
- Tous les éléments de `stylized_nature/stone_paths` sont non bloquants par défaut.
- Une migration de document applique une seule fois cette nouvelle politique aux
  éléments déjà posés. La case de collision reste ensuite librement modifiable.
- Choisir un matériau conserve le comportement direct sur une surface sélectionnée.
  Dans les autres cas, si le chapitre contient un terrain, la Forge le sélectionne
  et équipe immédiatement le pinceau de texture locale.
- La peinture ne remplace pas la texture de base : elle alimente les couches de
  mélange locales déjà sérialisées par le terrain.

## Tâches

- [x] Centraliser les catégories galet/route et leurs valeurs de collision.
  Skills: `physics-system`, `assets-pipeline`
- [x] Migrer les documents existants sans bloquer les choix manuels futurs.
  Skills: `resource-pattern`, `save-load`
- [x] Équiper automatiquement le pinceau de texture sur le terrain du chapitre.
  Skills: `godot-ui`, `procedural-generation`
- [x] Mettre à jour le tutoriel intégré et le wiki de la Forge.
  Skills: `godot-ui`
- [x] Ajouter les régressions document, runtime, couches terrain et flux éditeur.
  Skills: `godot-debugging`, `godot-testing`, `godot-code-review`
