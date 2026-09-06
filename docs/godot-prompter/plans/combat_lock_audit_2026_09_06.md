# Audit des blocages de combat - 6 septembre 2026

## Causes reproduites et corrigees

Deux chemins produisaient exactement le symptome observe : attaques normales,
chargees, A et X indisponibles tandis que spirales et mobilite restaient actives.

1. `skill_input._input` annulait toutes les commandes a chaque evenement quand
   la souris n'etait pas capturee. Un mouvement de souris ou le relachement du
   clic effacait l'appui avant sa consommation par Player. Les spirales utilisent
   un autre chemin et restaient utilisables. La capture est maintenant seulement
   une preference de camera ; les menus restent bloques par la pause du SceneTree.
2. A zero PV, `skill_runtime.tick` annulait les commandes a chaque frame et
   `skill_input` ignorait A/X. Player n'a pourtant aucun etat de mort : mobilite,
   contres et regeneration continuent a zero PV. Suppression de cet etat de mort
   propre aux competences, y compris dans le controleur de camera du Tonnerre.
   Une future implementation de mort devra gerer toutes les commandes ensemble.

Le test `combat_cursor_regression_test.gd` injecte les vrais evenements Godot.
Avant correction : huit echecs en souris visible/confinee, quatre autres a
zero PV, avec spirales toujours fonctionnelles. Apres correction : toutes les
assertions passent en souris capturee, visible, confinee et a zero PV.

## Autres sorties d'etat reparees

- Pause, perte de focus, annulation de roue : annulation des preparations non
  tirees de Tonnerre/Fire Wall et restitution unique de leur jauge.
- Choix d'un autre ultime ou changement d'arme : liberation du Tonnerre arme.
- Ouverture de roue en maintenant le clic : suppression du tir differe ; le
  relachement pendant le choix ne lance pas accidentellement un projectile.
- Contre ou autre attaque remplacant X/une preparation : liberation du verrou
  precedent sans terminer l'animation qui vient de le remplacer.
- X : activation repetee ignoree, recuperation d'un atterrissage sans nouvel
  evenement de contact, annulation en traversal/remplacement de personnage.
- Aura : expiration avant l'acquisition de cible et verification des references
  liberees. Fin d'ultime nettoyee avant les callbacks ; un second nettoyage
  n'efface plus les commandes d'une attaque normale commencee entretemps.
- Minuteur de preparation sans ultime actif : remise a zero.

Les restrictions voulues restent en place : competences verrouillees dans les
parametres, jauge insuffisante, preparation active, roue ouverte et conditions
propres aux mouvements. Les attaques manuelles restent reservees pendant Aura.

## Validation

Godot 4.7, tests de regressions reussis :

- combat_cursor_regression_test (fenetre graphique, vrais evenements souris/clavier)
- skill_lock_lifecycle_test (pause/focus, selection, roue, contre, X, Aura, idempotence)
- ultimate_input_routing_test (fenetre graphique, A/E, refus sans jauge, annulation)
- spiral_combat_recovery_test (quatre spirales haut/bas, charges et reprise normale)
- thunder_explosion_camera_test (impact, demembrement, souffle et retour camera)
- skill_live_flow_test (mouvement Aura et cycle physique de X)
- skill_system_test, skill_revision_test, ultimate_charge_transfer_test

`git diff --check` passe. Les avertissements existants du bac a sable concernant
certificats, sauvegarde de preferences/cache et ressources audio a la fermeture
restent distincts des assertions de combat.

Ces reproductions remplacent le constat precedent d'absence de reproduction
exacte dans player_skill_tree.md. Elles couvrent les chemins identifies et ne
pretendent pas prouver l'absence de tout autre bug dans toutes les scenes.
