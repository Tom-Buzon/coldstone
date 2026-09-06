# Arbre de compétences et puissance du joueur

Architecture : Player → SkillRuntime (états/cooldowns) → SkillProfile Resource
(choix/équilibrage). Settings → SkillTreePanel → Profile.changed → Runtime.
Les effets temporaires sont des nodes dans le monde ; le HUD écoute le runtime.
Préserver les collisions et recalculer les directions à partir des entrées actuelles.

- Profil persistant, prérequis et branche Dev masquable (ability-system, resource-pattern, save-load).
- Interface dans Settings, sélection d'ultime et HUD (godot-ui, hud-system).
- Portes d'activation dans les mouvements/attaques existants ; réglages de saut,
  dash, glissade, wall run, santé, aim assist (player-controller, input-handling).
- Javelot secondaire ; projectile balayé, lame horizontale, impact de chute
  (physics-system, animation-system, ability-system).
- Aura, feu/brûlure/peur, tonnerre, Ares avec destruction de boucliers et
  ondes de mort (ability-system, ai-navigation, particles-vfx).
- Tests du profil, des effets, des transitions et de l'intégration ; lancement
  du laboratoire (godot-debugging, godot-code-review).

Décisions : pas de monnaie/XP inventée ; déblocages libres depuis Settings.
Pack existant actif par défaut, nouvelles compétences désactivées ; bouton
d'activation générale pour les essais. Javelot secondaire à la place d'un arc.
Un ultime sélectionné à la fois, jauge commune 0–100 ; commandes remappables.
Dev visible seulement si hoplite/development/skill_tuning est activé.

## Utilisation

Dans Paramètres → Compétences, cocher les capacités individuellement ou utiliser
« Tout débloquer ». Ce bouton conserve les valeurs d'équilibrage. « Pack de base »
restaure les compétences et les valeurs par défaut. Les enfants restent mémorisés
mais deviennent inactifs tant qu'un prérequis est décoché.

L'onglet « Dev · équilibrage » expose les hauteurs de saut 1, 2 et 3+, le nombre
total de sauts, vitesse/accélération, distances et charges de dash/glissade,
réactivité directionnelle, courses murales, santé/régénération, assistance par
contexte, dégâts et paramètres des nouvelles capacités. Ses boutons permettent
de remplir la jauge d'ultime et de restaurer santé/mobilité pour les essais.
Le désactiver dans Project Settings avec `hoplite/development/skill_tuning=false`
retire ce panneau ; le profil conserve ses valeurs. Le profil est enregistré
dans `user://hoplite_skills_v1.cfg` à la fermeture des paramètres.

| Commande par défaut | Action |
| --- | --- |
| E bref / Y manette | Basculer épée / javelot |
| E maintenu / Y maintenu | Ramasser l’objet visé à portée (0,42 s), sans changer d’arme |
| Attaque légère / lourde | Lancer le javelot ; la charge lourde augmente ses dégâts |
| F maintenu / clic stick gauche | Lame horizontale pendant dash ou spirale |
| X / croix directionnelle bas | Frappe tellurique en l'air |
| A bref (AZERTY) / croix directionnelle haut | Activer l’ultime sélectionné, à 100 % de jauge |
| A maintenu / croix directionnelle haut maintenue | Roue après 0,24 s : souris/stick droit, relâcher pour sélectionner, Échap pour annuler |
| T / croix directionnelle droite | Choisir le prochain ultime débloqué |

Ces commandes sont remappables dans le menu des contrôles. Le HUD affiche l'arme,
la jauge, l'ultime et sa durée/charge ; le viseur apparaît pour le javelot/tonnerre.

## Comportements intégrés

- Le saut de sortie d'un géant/bouclier peut réinitialiser sauts et chaîne murale,
  et renforcer l'assistance jusqu'au prochain atterrissage.
- La lame horizontale suit la direction réelle du déplacement. Une activation
  dans les 150 premières millisecondes de dash/spirale double ses dégâts.
- La frappe tellurique utilise le sommet atteint avant l'impact : dégâts de base
  + dégâts par mètre, hauteur plafonnée et répulsion croissante.
- Aura : cible à portée de mobilité, préférence vers la direction commandée,
  rapprochement par dash puis frappes automatiques précises. Elle franchit une
  garde sans supprimer durablement le bouclier.
- Fire Wall : direction fixée à la fin de la charge, mur longitudinal arrêté
  par le décor, dégâts périodiques et brûlure résiduelle. Les ennemis évitent
  la barrière, y compris les soldats de formation sans corps physique.
- Tonnerre : projectile rapide et localisé, collision balayée et destruction
  de bouclier ; aucune explosion globale.
- Ares : frappes manuelles, charge lourde accélérée, forte répulsion, destruction
  des boucliers et ondes à chaque mort attribuée au joueur.
- Les démembrements et réponses parfaites attribués au joueur rechargent la
  jauge si leurs compétences sont actives.

Les attaques contextuelles utilisent les animations et balayages déjà présents.
Le javelot est une seconde arme disponible après déblocage, sans ramassage au sol.
Les nouveaux effets réutilisent le retour d'impact existant ; le mur emploie
trois plans animés partageant un matériau et 80 particules de braise.

## Validation et limites

Tests dédiés : `tests/skill_system_test.gd` (profil, sauvegarde, prérequis,
désactivation, changements de direction, dégâts, brûlure, peur, projectile),
`tests/skill_enemy_integration_test.gd` (vrais acteurs V2, géants, boucliers,
formations et ondes de mort). Les scripts `skill_ui_preview.gd` et
`skill_effect_preview.gd` produisent des captures avec le rendu Compatibility.

Revue : profil séparé des états temporaires ; suppression des effets à la
désactivation ; projectiles balayés ; dégâts de zone bloqués par le décor ;
registre de flammes nettoyé à la destruction ; HUD actualisé à 10 Hz ; dégâts
de feu à 5 Hz ; huit ondes de mort traitées au maximum par tick.

Il reste à juger le ressenti en partie réelle et à équilibrer les valeurs : les
tests automatisés ne prouvent ni le plaisir de jeu ni les performances d'une
bataille complète avec toutes les capacités. Les projectiles interrogent encore
le groupe des ennemis pour les soldats sans collision ; les effets utilisent
des visuels procéduraux et des animations existantes, sans animations dédiées.
Les tests sous sandbox peuvent signaler les certificats Windows, le cache GPU,
l'écriture de réglages utilisateur existants et des ressources audio au shutdown.

Validation du 6 septembre 2026, Godot 4.7 : tests système et intégration réussis,
captures UI/effet rendues et inspectées, probe de stabilité tactique réussi,
laboratoire `combat_lab.tscn` exécuté pendant 180 frames (sortie 0),
`git diff --check` sans erreur. Les probes de garde et de réconciliation du
combat mural ont également réussi pendant l'implémentation.

## Révision : commandes fiables et signatures cinématiques

- `SkillInput` mémorise les appuis/relâchements reçus par événement. Un appui
  bref entre deux ticks physiques ne disparaît plus. Les sélections et la jauge
  sont indépendantes ; un refus affiche sa raison. Un lancement pendant un
  franchissement peut patienter jusqu’à 0,65 s, sans dépenser la jauge avant
  acceptation. Un maintien sur A ne lance jamais l’ultime au relâchement.
- A utilise la position physique QWERTY Q, étiquetée A dans le menu AZERTY du
  projet : aucun conflit avec la position Q de déplacement. Les anciennes
  affectations par défaut R/V migrent vers A/E ; les remappages personnalisés
  sont conservés. T reste disponible comme raccourci secondaire.
- F possède désormais une lame d’énergie visible en préparation et une traînée
  pendant dash/spirale. Un message explique si la capacité est verrouillée.
- Aura : cible stable réévaluée à 11 Hz, préférence directionnelle, ruées à
  34 m/s réglables, alternance dash/glissade/petit saut, frappes lourdes à 150 %
  des dégâts Aura après 65 ms d’anticipation. La physique conserve les collisions
  et limite la vitesse à la distance restante. Halo doré, étincelles ascendantes,
  traînées persistantes et traits de vitesse à l’écran.
- X : hauteur mondiale de caméra conservée, regard vers le joueur en chute,
  ralenti 32 %, accent d’impact 12 % puis retour du cadrage sur 0,9 s avec
  smoothstep. Trois ondes concentriques et débris accompagnent l’impact.
- Fire Wall : halo orangé pendant la charge, resserrement progressif du champ
  de vision, ligne de rupture au déclenchement puis mur de feu persistant.
- Tonnerre : anticipation de 0,28 s, halo cyan, projectile et tracé électrique
  persistant au contact, accent de caméra. La direction est prise au lancement.
- Ares : halo rouge, cadrage resserré, accents aux impacts et ondes rouges aux
  morts. Le joueur reste le seul à déclencher les attaques.

`CombatFeedback` reste le seul écrivain du ralenti et des offsets/FOV de la
caméra. `SkillCinematic` lui transmet sa contribution ; `Player` conserve le
SpringArm et ses collisions. Les choix de roue ne tournent pas la caméra. Une
pause ou perte de focus annule les commandes maintenues et les demandes différées.
Les effets temporaires sont plafonnés à 96 géométries et six gerbes de débris.

Validation : `skill_revision_test.gd` couvre sélection après charge pour les
quatre ultimes, appui bref, roue, sélection verrouillée, ramassage unique,
annulation, cadrage/ralenti restaurés et état visible de F. Le test
`skill_live_flow_test.gd` utilise les vrais ticks physiques et ennemis V2 :
ruée mesurée à 34 m/s, trois cibles endommagées, impact réel sur sol et caméra
revenue à la normale. Captures Compatibility dans `skill_cinematic_preview.gd`.
Ces contrôles établissent le fonctionnement ; le jugement du ressenti reste
un essai de jeu, notamment dans les combats denses et les terrains irréguliers.

## R�vision : javelot charg�, transferts Aura et r�cup�ration des commandes

Les quatre JPEG fournis dans `assets/HUD` sont utilis�s dans le HUD et la roue.
Le javelot grandit de 1,7 � 4,8 m et inflige de 25 � 100 % des d�g�ts configur�s ;
la dur�e de charge maximale est r�glable (2 s par d�faut). Le projectile reste
balay� pour les collisions et limite sa tra�n�e au premier contact.

Aura choisit dash au-del� de 3,2 m, glissade � partir de 1,8 m, sinon saut.
Apr�s un impact accept�, une autre cible vivante est pr�f�r�e imm�diatement ;
l'ancienne reste disponible si elle est seule. La cam�ra alterne ses angles
et sa hauteur selon le mouvement, puis rel�che le cadrage progressivement.

Un appui A sans jauge ne laisse aucune activation diff�r�e. Les rel�chements
perdus sont r�concili�s avec l'�tat r�el des touches ; les �tats de charge
manuelle sont nettoy�s lors de l'ouverture de roue et avant un changement d'arme.

`ultimate_charge_transfer_test.gd` couvre les refus r�p�t�s, le d�blocage des
commandes, les charges faible/maximale et leur projectile, l'annulation E,
les transferts entre ennemis survivants et la r�cup�ration de cam�ra.
`ultimate_javelin_preview.gd` rend les logos et trois �tats du javelot.

Validation finale : tests syst�me, ennemis V2 et charge/transfert r�ussis.
`ultimate_input_routing_test.gd` injecte les vraies touches physiques A/E
dans la fen�tre Godot : huit refus cons�cutifs, changements d'arme, lancement
avec jauge pleine et annulation du javelot r�ussis. Captures finales inspect�es ;
`git diff --check` sans erreur de whitespace.

## Tonnerre : explosion et suivi de camera (revision septembre 2026)

Scene : SkillCinematic -> ThunderCamera -> Camera3D temporaire. Le projectile
communique son impact au controleur ; la disparition sans impact, le timeout,
la sortie de scene rendent toujours la camera au joueur. Le passage a zero PV
ne definit pas une mort dans le Player actuel (voir audit des blocages).
CombatFeedback conserve l'ecriture unique du ralenti.

Vol a 180-260 m/s, ralenti 22 %, suivi derriere le javelot. Impact : arcs
radiaux, sphere et colonne electriques, montee pendant 0,9 s vers un cadrage
plongeant ; retour en 1,1 s vers le rig vivant du joueur. Les rayons de camera
restent contraints par le decor. Les effets electriques persistent pendant
la montee et restent dans le plafond de 96 geometries transitoires.

Degats directs par defaut 1300 (ancien defaut 650 migre, reglages personnalises
conserves), explosion a 65 % dans 7 m a pleine charge. Rayon et ratio sont
reglables. Une cible directement touchee ne recoit pas une deuxieme dose de
l'explosion. Le decor bloque le souffle. L'anatomie est interrogee par segment
contre les capsules/spheres des os sans reactiver les hitboxes distantes ;
les petites zones prioritaires resolvent les chevauchements du torse geant.
Le contact transmet sa vraie zone et une puissance de section suffisante
pour tete/bras ; le souffle reste un impact au torse.

Recuperation du combat : une attaque finie remplace desormais l'etat de charge
du driver. Les relachements perdus du bouton lourd et les charges/poses de
garde orphelines sont reconcilies avant les entrees du joueur. Les refus de
light sont journalises avec les etats utiles, au maximum une fois / 2 s,
pour identifier un autre blocage si le cas exact du joueur persiste.

Validation : spiral_combat_recovery_test (quatre spirales haut/bas, reprise
light, interruption de charge), combat_attack_probe (0 echec, quatre
executions descendantes et impact physique), thunder_explosion_camera_test
(tete et bras de geant hors LOD, degats radiaux, vol/impact/retour et projectile
disparu), skill_live_flow_test (Aura et X), thunder_cinema_preview (captures
vol, explosion, vue plongeante et retour). Ces tests ne reproduisent pas
encore avec certitude la sequence exacte du blocage signale par le joueur.

## Audit suivant : blocages reproduits et corriges

Voir [combat_lock_audit_2026_09_06.md](combat_lock_audit_2026_09_06.md) :
deux reproductions exactes (capture souris et zero PV), corrections des sorties
de preparation et de X, et tests de non-regression. Ce resultat remplace la
limite de reproduction indiquee dans la revision precedente.
