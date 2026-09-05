# Contact dynamique, arcs fixes et sorties des phalanges

## Décision d'architecture

Le `HopliteBattleCrowdDirector` reste la façade commune. Le
`HopliteCrowdEngagementCoordinator` possède la sélection des combattants
individuels au contact. Les formations de phalanges restent entièrement
extérieures à ce système et conservent leurs propres cohortes.

L'ordre d'arrivée est supprimé. À cadence limitée, les combattants individuels
sont classés par distance réelle au joueur avec une petite hystérésis spatiale.
Les places angulaires sont attribuées au plus près de l'angle actuel de chaque
soldat pour éviter les croisements inutiles. Seul un membre affecté au cercle de
contact et réellement arrivé près de sa place peut attaquer.

Les phalanges ne consomment jamais la rotation ni la capacité des anneaux
individuels. Le premier cercle normal reste donc complet même si les phalanges
occupent visuellement 180°, 280° ou 360° à un rayon plus éloigné. Quand
plusieurs cohortes sont proches, un secteur angulaire fixe est calculé une fois
pour la composition présente puis conservé tant que cette composition ne change
pas. Le centre de bataille peut se translater avec le joueur, mais les cohortes
ne tournent pas autour de lui.

Le passage ligne/arc conserve l'identité latérale des colonnes : un soldat placé
à droite de sa ligne reste du même côté de son secteur courbe. Les coordonnées
ne sont jamais renumérotées pour fabriquer l'arc, ce qui évite les croisements et
les regroupements en boule.

À deux phalanges ou plus, le mur reste volontairement hors de portée immédiate.
Le directeur déclenche donc des sorties globales de trois membres du premier
rang. Une sortie suit quatre phases explicites (`advance`, `strike`, `return`,
`rest`) ; seuls les membres en phase `strike`, réellement arrivés au rayon
d'attaque, peuvent menacer le joueur. Les autres hoplites gardent leur secteur.

## Plan d'implémentation

- [x] Remplacer l'ordre d'arrivée par un rééquilibrage spatial cadencé et stable.
  Skills: `godot-prompter:ai-navigation`, `godot-prompter:godot-optimization`
- [x] Conditionner l'attaque à l'appartenance au cercle de contact et à l'arrivée
  physique sur la place attribuée.
  Skills: `godot-prompter:ai-navigation`, `godot-prompter:godot-debugging`
- [x] Figer les secteurs des phalanges et doubler le rayon multi-cohortes.
  Skills: `godot-prompter:godot-brainstorming`, `godot-prompter:ai-navigation`
- [x] Passer les valeurs par défaut à 180° pour deux phalanges et 280° pour
  trois, sans réduire le cercle de contact des unités ordinaires.
  Skills: `godot-prompter:math-essentials`, `godot-prompter:ai-navigation`
- [x] Préserver le côté de chaque colonne pendant la transition ligne/arc.
  Skills: `godot-prompter:math-essentials`, `godot-prompter:godot-debugging`
- [x] Ajouter les sorties offensives centralisées de trois hoplites avec retour
  au slot avant la vague suivante.
  Skills: `godot-prompter:state-machine`, `godot-prompter:ai-navigation`
- [x] Ajouter une description visible sous chaque réglage de foule.
  Skills: `godot-prompter:godot-ui`
- [x] Ajouter les sondes de remplacement dynamique, d'interdiction d'attaque en
  réserve et d'absence de rotation des phalanges.
  Skills: `godot-prompter:godot-testing`
- [x] Rejouer les scénarios Forge, stress et performance puis effectuer la revue
  finale.
  Skills: `godot-prompter:godot-optimization`, `godot-prompter:godot-code-review`

## Validation de cette passe

- Le probe de coordination vérifie six places ordinaires actives avec trois puis
  quatre phalanges, la continuité gauche/droite et une sortie de trois membres.
- Le probe Forge instancie les vrais `ngeneral`, force deux cohortes au contact
  et vérifie que les trois positions avancées produisent trois objectifs
  d'attaque valides à 2,25 m.
- Les probes de tactique, remplacement de cohorte, planification FIFO, états de
  combat, stress mixte (36 unités) et performance (56 IA actives) restent verts.
