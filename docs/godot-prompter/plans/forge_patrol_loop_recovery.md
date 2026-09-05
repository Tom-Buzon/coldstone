# Forge — boucle et reprise des patrouilles

## Diagnostic

La Forge sérialise correctement les marqueurs ordonnés et le runtime les transmet
aux ennemis. En revanche, `configure_demo_patrol()` ne conserve actuellement que
ces marqueurs. La position de départ n'appartient donc pas à la route et aucune
transition explicite ne recale l'index quand une cible de combat est abandonnée.

## Décision

Conserver le contrôleur de déplacement direct existant, moins coûteux qu'un
`NavigationAgent3D` par soldat dans les grandes batailles. Chaque ennemi possède sa
propre boucle : points tracés dans l'ordre, puis sa position initiale comme dernier
point. Une route contenant un seul marqueur devient donc naturellement
`départ -> marqueur -> départ -> ...`.

La transition combat vers patrouille détecte la perte de la cible. Elle choisit le
point de boucle le plus proche, réinitialise la décision mise en cache et reprend le
trajet sans rester sur l'ancien objectif de poursuite. L'index continue ensuite
normalement dans l'ordre de la boucle.

## Tâches

- [x] Ajouter les régressions de boucle et de reprise.
  Skills: `godot-testing`, `godot-debugging`
- [x] Construire une route par ennemi incluant son point initial.
  Skills: `ai-navigation`, `math-essentials`
- [x] Détecter la sortie du combat et recaler la patrouille.
  Skills: `ai-navigation`, `state-machine`
- [x] Mettre à jour l'aide intégrée et le tutoriel.
  Skills: `godot-ui`
- [x] Valider et revoir le code.
  Skills: `godot-testing`, `godot-code-review`
