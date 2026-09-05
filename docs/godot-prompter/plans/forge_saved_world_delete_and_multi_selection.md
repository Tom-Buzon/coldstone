# Forge — suppression de sauvegarde et multi-sélection

## Architecture retenue

- Le fichier `*.hoplite.json` reste l'unique source d'autorité d'un portail de monde sauvegardé. La suppression enlève le fichier principal, son `.bak` et son éventuel `.tmp`; le hub reconstruit donc automatiquement la liste sans ce portail.
- `selected_ids` devient la sélection autoritaire de la Forge. `selected_id` reste l'élément primaire pour préserver les inspecteurs spécialisés existants.
- Les groupes d'édition sont persistés dans le document sous `editor_groups` avec un identifiant stable, un nom, un type `object` ou `enemy` et une liste d'identifiants d'entités. Ils n'ajoutent aucun nœud au runtime de jeu. Les groupes `enemy` deviennent toutefois des références composites utilisables par les systèmes de combat.
- Une transformation multi-objet déplace tous les membres par le même delta. Rotation et mise à l'échelle agissent en revanche sur le pivot local de chaque membre : elles modifient son orientation ou son échelle sans jamais modifier sa position. Les propriétés communes de collision sont appliquées à tous les décors sélectionnés.

## Flux

1. Ctrl + clic ajoute ou retire une entité de `selected_ids`; un clic simple remplace la sélection. Alt+glisser déplace horizontalement et Maj+glisser verticalement, car Ctrl est désormais réservé à la multi-sélection.
2. Le marqueur et le gizmo utilisent les limites agrégées de toutes les entités sélectionnées.
3. La Forge capture un snapshot de chaque transform avant une manipulation, puis applique le delta à tous les membres dans une seule entrée d'historique.
4. Le panneau Scène ouvre un dialogue de nommage à la création, distingue visuellement groupes d'objets et d'ennemis, puis permet de sélectionner, renommer, compléter, alléger ou supprimer le groupe. « Mettre à jour » remplace exactement sa composition par la sélection courante.
5. La normalisation du document élimine automatiquement les références d'entités absentes et les groupes vides.
6. La fiche d'un membre affiche ses groupes en tête et permet de sélectionner tout le groupe. Les références de troupe résolvent un groupe `enemy` vers tous ses membres pour les morts, protections, apparitions, retraits et arrêts de vagues.

## Tâches et compétences

- [x] Suppression sûre des sauvegardes et nettoyage de portail — `save-load`, `godot-ui`
- [x] Modèle de sélection et interactions Ctrl — `input-handling`, `component-system`
- [x] Transformations, colliders et groupes persistants — `component-system`, `save-load`, `godot-ui`
- [x] Validation headless et revue — `godot-debugging`, `godot-code-review`
