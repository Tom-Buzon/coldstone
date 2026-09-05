# Forge — colliders configurables et poignées de terrain

## Décisions

### Colliders des assets

Chaque décor peut enregistrer `collision_enabled` et `collision_shape`. Les formes
proposées sont les primitives Godot adaptées aux décors statiques : `box`,
`cylinder`, `capsule` et `sphere`, plus une enveloppe `convex` simplifiée créée
depuis les sommets du mesh. Les primitives sont ajustées aux limites visuelles du
mesh, sans mettre le `CollisionShape3D` à l'échelle. Le convexe est mis en cache par
asset et dimensions afin de ne pas recalculer sa forme pour chaque instance.

Les catégories `shrubs`, `ground_cover` et `stone_paths` sont sans collision par
défaut. Les arbres, vrais rochers, galets `Pebble_*` et objets solides gardent une
collision, modifiable ou désactivable dans la fiche du pinceau puis dans
les propriétés de l'objet placé. Le collider de sélection de la Forge reste séparé :
un asset sans collision de gameplay reste sélectionnable.

### Poignées du terrain

Un terrain sélectionné expose quatre poignées, sur ±X et ±Z. Tirer une poignée
conserve le côté opposé en place. La nouvelle emprise déplace donc le centre de
l'entité de la moitié du déplacement, tandis que l'ancien rectangle de données est
décalé dans la nouvelle carte pour que son relief reste exactement à la même
position monde. Les nouvelles bandes passent par la génération/raccord existante.

Le calcul coûteux des cartes est effectué au relâchement. Pendant le glissement,
seuls le cadre et les poignées prévisualisent la future emprise.

### Pose sur le relief

Les rochers, galets et chemins en pierre reçoivent `align_to_ground: true` dans le
catalogue. À la pose, leur position Y et leur axe vertical sont calculés à partir de
la hauteur et de la normale du terrain, tout en conservant le cap aléatoire du
pinceau. Les autres catégories restent verticales par défaut et l'option est
modifiable dans la fiche du pinceau comme sur l'objet déjà placé.

## Tâches

- [x] Ajouter les valeurs par défaut et l'interface des colliders.
  Skills: `physics-system`, `godot-ui`
- [x] Construire les formes primitives et l'enveloppe convexe depuis le visuel.
  Skills: `physics-system`, `math-essentials`
- [x] Ajouter les poignées X/Z du terrain et l'aperçu de glissement.
  Skills: `input-handling`, `godot-ui`, `math-essentials`
- [x] Étendre un seul côté sans déplacer l'ancien relief.
  Skills: `procedural-generation`, `math-essentials`
- [x] Aligner automatiquement rochers, galets et chemins sur la normale du sol.
  Skills: `math-essentials`, `3d-essentials`
- [x] Mettre à jour l'aide, tester et revoir le code.
  Skills: `godot-debugging`, `godot-testing`, `godot-code-review`
