# Forge — colliders convexes précis et économiques

## Décision

Le mode sérialisé `convex` devient un mode de collision optimisé à deux niveaux :

1. utiliser en priorité le fichier compagnon `*_collision.glb`, dont chaque mesh léger devient une pièce `ConvexPolygonShape3D` du même `StaticBody3D` ;
2. conserver une enveloppe convexe automatique unique pour les assets simples sans proxy dédié.

Les points sont transformés dans le repère du prop avant de créer les formes. L'échelle de l'entité est intégrée au visuel, aux primitives ou aux sommets du proxy : le `StaticBody3D` et ses `CollisionShape3D` restent à l'identité. Les tableaux de formes sont partagés par le cache asset/hauteur/décalage/échelle et les proxies authorés sont limités à 16 pièces, budget supérieur au maximum actuel du catalogue (15).

## Tâches

- [x] Détecter les fichiers compagnons de collision et en faire le défaut des assets concernés.
  Skills: `godot-brainstorming`, `physics-system`
- [x] Construire plusieurs convexes authorés dans un seul corps statique, avec repli automatique.
  Skills: `physics-system`, `math-essentials`, `godot-optimization`
- [x] Ajouter les régressions sur une arcade, une porte fortifiée, son passage et le cache partagé.
  Skills: `godot-debugging`, `godot-testing`
- [x] Vérifier le parsing, les probes Forge et la revue Godot.
  Skills: `godot-code-review`, `godot-optimization`
