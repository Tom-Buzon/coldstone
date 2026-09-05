# Composition V2 et commandement des armées

État actuel : 2026-09-05. Point d’entrée documentaire : [README.md](README.md).

## Tronc commun → arme → capacité spécifique

`enemy_actor_v2.gd` conserve identité, faction, santé/anatomie, LOD, équipement et interface de formation. Il instancie `definition.weapon_script`. `enemy_v2_combat_core.gd` fournit le cycle de combat, la garde et les primitives de mouvement, sans importer la lance.

| Module | Responsabilité |
| --- | --- |
| `weapons/spear_v2_weapon.gd` | Attaques de lance et mouvement associé |
| `enemy_v2_role_combat.gd` | Exécution commune des sorties locales des armes légères |
| `weapons/sword_v2_weapon.gd` | Sortie courte, frappe d’épée, récupération, perte du bouclier |
| `weapons/bow_v2_weapon.gd` | Distance de tir, retrait borné, visée verrouillée, flèche balistique |
| `weapons/giant_unarmed_v2_weapon.gd` | Coups de poing/balayages et exécution des attaques engagées |
| `abilities/giant_slam.gd` | Capacité facultative : disponibilité selon les jambes, zone, délai, dégâts et saut d’esquive |

Les anciens noms `*_combat_component.gd` sont des adaptateurs de compatibilité sans logique d’arme. Le géant conserve son adaptateur de présentation/anatomie à 53 os, nécessaire à son corps distinct ; son arme hérite du même socle de combat. Le rôle tactique ne choisit pas le script de combat dans l’acteur.

Les définitions des archers et fantassins composent explicitement le corps hoplite à 23 os avec leur arme. Elles ne dupliquent plus la définition d’un lancier. Ajouter une arme n’exige pas d’ajouter une branche à l’acteur. Une nouvelle capacité spécifique doit rester optionnelle dans la définition et exposer son contrat à l’arme concernée.

## Animations composées hors exécution

Les sources restent bakées par les outils existants de retargeting. `tools/enemy_v2/build_composed_animation_packs.gd` répartit ensuite ces ressources déjà bakées dans `assets/animations/enemy_v2/packs/` :

- Hoplite : `hoplite_common` + `hoplite_spear`, `hoplite_sword` ou `hoplite_bow`.
- Géant : `giant_common` + `giant_unarmed` + `giant_slam`.

`definition.animation_pack_paths` est ordonné. L’AnimationLibrary composée est mise en cache par combinaison de packs, et les animations sont partagées. Les doublons de clips sont refusés. Il n’y a ni donneur vivant ni retargeting à l’exécution. Le champ historique `animation_library_path` sert uniquement de repli pour les définitions sans packs. Après modification d’un bake source, régénérer les packs puis les atlas d’imposteurs concernés.

## Commandement adaptatif

- `battlefield_runtime.gd` possède activation, registre des camps, index spatial et ciblage réparti entre frames.
- `army_situation.gd` construit des résumés de groupes : effectif, santé restante, puissance pondérée par rôle, engagement et dimensions.
- `adaptive_army_planner.gd` prend uniquement ces résumés. Il répartit la pression, exploite les groupes affaiblis et les ouvertures mémorisées après destruction, déborde en supériorité, renforce les secteurs menacés et repositionne les archers. Les missions de manœuvre ont une courte persistance ; une urgence ou une cible détruite peut les invalider.
- `army_commander.gd` applique difficulté, limites de zone, mobilisation joueur, ordres manuels et exceptions des miniboss, puis publie `command_assignment`.
- `hoplite_v2_troop_runtime.gd` exécute les formations et permissions. La circulation partagée garde ses contrôles de terrain et d’occupation. Un ordre explicite évite désormais le recalcul du directeur de fronts historique. Le point abstrait d’armée n’est plus traité comme un intrus physique dans une phalange.
- Les armes conservent leurs propres portées, récupération et engagement. Les combattants proches peuvent quitter légèrement leur place pour rejoindre un duel NPC ; H conserve sa ligne.

Les armées partagent circulation et réservations d’attaque. La cible individuelle privilégie le groupe adverse assigné, mais le combat immédiat reste possible. Les charges de ciblage sont actualisées lors des changements pour limiter la concentration de tous les soldats sur une seule cible.

Les anciens templates ne sont plus sélectionnables ni exécutés. Leurs clés sont retirées à la normalisation, après migration du vieux `bodyguard`. La difficulté règle le délai de décision (2,2 / 1,1 / 0,7 s) et la pression joueur (4 / 6 / 6), sans changer les armes.

Le plafond de mobilisation joueur reste configurable (50 %, rayon 22 m par défaut), modulé par le rapport de force. Les géants ennemis conservent leur rôle défensif contre le joueur ; les gardes peuvent participer au combat normal hors alerte proche. La vengeance garde la priorité après la mort du propriétaire.

## Troupes élites

`player_escort.gd` ne simule plus de soldats : il enregistre la sélection élite, ses bonus et les entrées G/H. Les unités sont inscrites au même exécuteur et commandant que les alliés, tout en gardant des effectifs et une puissance configurés séparément. G donne une destination puis libère le groupe à l’arrivée ; H publie une ligne défensive fixe orientée selon la vue. Le mode initial est autonome.

B, la contrainte circulaire appliquée au déplacement de chaque ennemi et l’intercepteur de dégâts du joueur sont retirés. Il n’y a plus de scan de toute l’escorte par chaque ennemi en mouvement.

## Budgets et limites

- Index spatial reconstruit à 5 Hz ; jusqu’à 24 acquisitions par frame avec seuil de 2 ms. Une reconstruction ou décision commencée peut dépasser ce seuil.
- Planification sur les groupes, non sur toutes les paires de soldats. Les résumés locaux sont calculés à cadence réduite.
- Réservations NPC sans plafond tactique de coups par cible/formation/global. Le joueur conserve ses plafonds. Les réservations joueur sont indexées séparément, pour éviter de parcourir les duels NPC à chaque demande.
- Nettoyage partagé des réservations une fois par frame ; vérification de l’engagement uniquement pour les acteurs morts ou les réservations expirées.
- Empreinte spatiale inchangée réutilisée ; visibilité de tir identique réutilisée dans la même frame. Contrôles de terrain et de tir conservés.
- Les duels ciblant une unité V2 ne déclenchent pas de télégraphe destiné au joueur ni son contour visuel. Les signaux d’attaque, animations et dégâts restent actifs ; les attaques visant le joueur conservent leurs avertissements.
- 40 projectiles simultanés. Les géants n’ont toujours pas les meshes LOD des hoplites.
- Aucune garantie que chaque soldat frappe en permanence : déplacements, portée, visibilité, congestion et rôle défensif des miniboss restent des contraintes physiques ou de gameplay. Ce planificateur est heuristique ; il ne fait pas de recherche stratégique exhaustive.

## Validation

`adaptive_army_probe.gd` couvre supériorité/débordement, brèche, infériorité/renfort, retrait des archers et disparition de cible. `player_escort_probe.gd` couvre la simulation commune, la puissance distincte, G/H, B désactivé et la migration des anciens effectifs. Les probes de pression, de miniboss et d’authoring complètent les scénarios.

`battlefield_v2_runtime_probe.gd -- --stress` compose 415 ennemis (150 hoplites, 200 fantassins, 60 archers, 5 géants), 240 alliés et 6 élites ; `--no-escort` retire les élites. Les mesures headless couvrent simulation et orchestration, pas le coût GPU ni le ressenti à la souris. Les pertes pendant le chargement peuvent réduire légèrement l’effectif vivant au début de la fenêtre mesurée.

Dernière validation de cette passe : probes de planification, de garde G/H, d’authoring, de miniboss, de pression joueur et de régression de crash passés. Le scénario de 176 unités avec six élites autonomes produit bien des combats (1 200 frames). Sur le stress de 661 unités, 209 réservations NPC simultanées et 23 groupes ayant attaqué ont été observés sur une fenêtre de 600 frames ; des groupes restent en déplacement ou contraints, et les géants hors alerte restent défensifs.

Les temps de frame observés ont varié fortement pendant cette passe : plusieurs processus Godot, dont une session de jeu lancée depuis l’éditeur, tournaient simultanément, et le système de contours a changé pendant la mesure. Ces essais valident le fonctionnement sous charge mais ne constituent pas un benchmark FPS avant/après isolé. Les suppressions de travail redondant sont effectives ; une cible de 60 FPS pour cette population n’est pas validée.


### Cycle de rencontre et boss programmés

`battlefield_encounter.gd` est un service enfant du monde de test, distinct de `battlefield_runtime.gd` et des commandants. Il suit les morts par signaux, évalue les conditions à 5 Hz, et soumet boss/gardes à `WorldRuntime.queue_encounter_group` (budget de spawn existant). Aucun parcours de soldats par image n’est ajouté. `boss_presentation.gd` possède la caméra temporaire et restaure l’état à sa sortie ; `boss_encounter_validation.gd` valide les références et détecte les cycles.

Contrat Forge : entité `enemy_group`, `battlefield_boss=true`, `spawn_condition=battlefield`, `count=1`. Les paramètres `boss_spawn_condition`, `boss_loss_percent`, `spawn_delay`, `spawn_dead_group`, `spawn_trigger`, `boss_cinematic`, `encounter_power`, `boss_guard_{phalanx,infantry,archer}` et `boss_guard_power` sont persistants. Le runtime crée des gardes avec `guard_of=<group_id du boss>` et `boss_budget_owner=<id de l’entité boss>`. Le budget de population inclut ces gardes avant leur apparition. Le gestionnaire d’événements générique ne doit pas créer ces entités lui-même.

La propriété `is_champion` permet à la retinue d’identifier également les champions non géants. Les gardes explicitement créés sont affectés à leur chef ; ces boss ne réquisitionnent pas les groupes ordinaires via l’affectation automatique. Les réglages de puissance restent sur chaque acteur, sans modifier la définition partagée.

Vérifications : `battlefield_boss_probe.gd` (conditions, spawn unique, budget, gardes, puissance, caméra, victoire) et `battlefield_boss_forge_probe.gd` (inspecteurs, conservation au repeuplement, validation).
