# Composer une bataille dans la Forge

## Créer ou modifier une rencontre

1. Dans **Personnages** ou **Événements**, placer **CHAMP DE BATAILLE** sur un sol praticable.
2. Régler ses dimensions, sa position et sa rotation horizontale.
3. Choisir **Deux armées + joueur** ou **Armée contre joueur**, la difficulté et le début immédiat ou à l’entrée du joueur.
4. Régler les effectifs de chaque camp et l’échelle des géants. Il n’y a plus de template de stratégie : le commandement est adaptatif.
5. Cliquer **Peupler / actualiser le déploiement**. Agrandir la zone si les formations ne tiennent pas. Les positions verrouillées sont conservées.
6. Ajuster le départ joueur, lancer **F6**, sauvegarder avec **Ctrl+S**.

Les effectifs et les dimensions du déploiement sont appliqués par **Peupler**. Les paramètres de commandement s’appliquent au prochain test. Une zone ne crée pas de sol ni de passage dans les murs. Sa capacité est une mesure d’espace, pas une garantie de FPS.

**Personnages → Ouvrir l’exemple : deux armées** fournit 169 unités : 48 hoplites, 24 fantassins et 12 archers par camp, plus un géant ennemi à échelle 3. Les alliés sont bleus.

## Comment l’armée décide

L’objectif des troupes régulières est de vaincre l’armée adverse. Les groupes évaluent leurs effectifs encore valides, leur santé, leur puissance, les forces proches et les adversaires déjà engagés. Ils peuvent fixer un front, déborder lorsque la situation le permet, exploiter une formation affaiblie ou un groupe détruit, renforcer un secteur menacé, contenir une poussée ou repositionner leurs archers.

Ces missions sont recalculées pendant la bataille. Elles ne sont plus des templates sélectionnables. Les anciens champs de doctrine sont retirés au chargement, sans supprimer les populations ni les placements.

**Mobilisation maximale vers le joueur (%)** est un plafond : 50 % des groupes réguliers par défaut, dans un rayon de 22 m. La mobilisation diminue si les troupes sont nécessaires contre l’armée opposée. Le contact proche reste prioritaire. En mode armée contre joueur, les ennemis réguliers poursuivent le joueur.

Novice : décisions plus lentes et pression de frappe réduite. Difficile : réactions plus rapides. Les attaques entre soldats V2 ne consomment pas les plafonds tactiques réservés au joueur ; chaque arme conserve portée, récupération et conditions de tir.

## Géants et gardes

Les géants ennemis conservent leur rôle de miniboss défensif. Le joueur les alerte dans le périmètre orange, réglable dans la Forge. Ils ne prennent pas spontanément les alliés pour cible. Les gardes participent au combat d’armée ; une alerte proche du joueur ou la mort de leur géant reprend la priorité. La vengeance reste une poursuite du joueur.

Régler **Groupes de garde par géant**, le périmètre et la distance de garde. Dans un groupe ennemi, **Défend le géant** permet une affectation automatique, manuelle ou aucune. Une affectation explicite peut dépasser le nombre automatique configuré.

## Troupe élite indépendante : G / H

La section **ESCORTE DU JOUEUR — INDÉPENDANTE** conserve ses effectifs par type, sa puissance et ses réglages distincts des alliés principaux, avec 24 unités maximum. Zéro partout la désactive. Elle utilise les mêmes formations, cibles et commandant allié que l’armée normale, avec ses bonus propres. Elle ne suit plus le joueur en cercle.

- Au départ : combat autonome avec les alliés.
- **G** : viser le sol, rejoindre ce point puis reprendre le combat autonome.
- **H** : viser le sol, rejoindre et tenir une ligne défensive orientée selon la vue. Regarder à ses pieds permet de placer cette ligne à proximité. Les soldats combattent les adversaires proches sans suivre le joueur.
- **B** : désactivé. Le mur circulaire et l’interception automatique des dégâts du joueur ont été retirés.

Le réticule central vise un sol à moins de 100 m. Un anneau bleu marque uniquement le point d’ordre, pas une formation circulaire. Une visée invalide conserve l’ordre précédent. Les attaques en préparation sont interrompues par un nouvel ordre ; les projectiles déjà tirés et les étourdissements restent valides.

**Ouvrir l’exemple : garde rapprochée** propose six fantassins élites contre 170 ennemis. Puissance 4 : dégâts ×4 et dégâts/sever reçus ÷4. Les anciennes cartes `bodyguard` conservent leurs soldats élites après migration.

## Groupes hors bataille

Un groupe V2 peut choisir son camp et son **Commandement** : une zone, ou **Autonome (hors bataille)** avec un ordre local. Les groupes V1 ne sont pas importés implicitement. La carte 414 conserve ses fronts historiques tant que ses groupes ne sont pas rattachés à une zone V2.

Contrats techniques : [V2_COMPOSITION_AND_ARMIES.md](V2_COMPOSITION_AND_ARMIES.md).


## Boss programmés et victoire

Sélectionner la zone de bataille → **Boss et renforts → Ajouter un boss / miniboss**. Le nouveau personnage est sélectionné : le déplacer avec les poignées pour fixer son point d’apparition. Les boutons de la zone permettent de retrouver chaque boss. **Peupler / actualiser** conserve ces boss.

- Types compatibles : géant (taille 3 par défaut), champion hoplite, fantassin ou archer. Nom, taille et puissance sont réglables ; ce sont les corps/armes V2, pas les anciens boss monolithiques.
- Apparition : début de bataille, pourcentage de pertes ennemies (25 % par défaut), mort d’une cible/troupe choisie sur la carte, délai depuis l’activation de la bataille, entrée du joueur dans une zone de déclenchement choisie sur la carte.
- Une cible de mort désigne **toute la troupe sélectionnée**, ou toutes les troupes d’un groupe d’éditeur. Pour cibler un personnage précis, utiliser une troupe d’une unité, notamment un autre boss. Les références absentes et les cycles de dépendance sont refusés.
- Le pourcentage utilise l’effectif ennemi initial prévu dans la zone, sans les boss programmés ni leurs gardes. Il faut donc peupler la bataille avant d’utiliser ce déclencheur.
- Garde personnelle : nombre d’hoplites, fantassins et archers (0–48 chacun), puissance propre. Ces renforts suivent le budget de création progressive et sont compris dans le compteur de population de la Forge. Le chef garde les règles d’alerte de la bataille ; après sa mort, sa garde poursuit le joueur.
- **Présentation cinématique** optionnelle : caméra sur le boss pendant deux secondes, bandes noires et nom. La simulation est suspendue pendant la présentation ; la caméra et la simulation sont restaurées à la fin ou à la fermeture du test. Plusieurs présentations sont mises en file.
- La victoire exige la mort de tous les ennemis prévus de cette bataille, boss et gardes compris. Un boss attendant encore un timer ou une zone bloque donc volontairement la victoire. Le message et le départ des alliés après un délai (4 s par défaut) se règlent sur la zone. Désactiver « Retirer les alliés » pour les conserver. Seuls les alliés rattachés à cette bataille partent, escorte incluse.

Une suppression scénarisée de troupe ne compte pas comme une mort. Les conditions utilisant des cibles hors de la portion de test nécessitent de tester également la portion contenant ces cibles.
