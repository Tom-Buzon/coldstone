# Tranche EnemyV2 — phalange hoplite coordonnée

## But

Faire de `PHALANGE V2` une troupe de 24 hoplites (8 colonnes × 3 rangs) réellement coordonnée et combattante, sans réintroduire le monolithe V1 ni une IA complète exécutée par soldat à chaque frame.

## Contrat d'architecture

- `HopliteV2PhalanxRuntime` possède les décisions collectives : cible, ancre, orientation, état de troupe, cohésion, slots et permissions d'attaque.
- Une phalange publie des intentions déjà résolues à ses membres à cadence limitée et déphasée entre troupes.
- Les slots restent stables entre événements. Une mort déclenche une seule reformation du groupe : les survivants comblent les trous et une nouvelle première ligne peut continuer à recevoir des permissions d'attaque.
- `HopliteEnemyActorV2` reste l'unique propriétaire de `velocity` et de `move_and_slide()` en mode formation.
- La boucle physique d'un membre ne fait que suivre une intention mise en cache, appliquer la gravité et interpoler son orientation. Elle ne recherche aucune cible et ne parcourt aucune foule.
- Le combat individuel est piloté par permissions : seuls quelques hoplites du rang exposé peuvent engager simultanément. Les autres maintiennent la garde et la cohésion.
- L'IA de duel V2 reste disponible séparément. Le runtime V1 et son directeur de foule ne sont pas modifiés.

## États de troupe de cette tranche

1. `ASSEMBLE` : rejoindre les slots et lever la garde.
2. `ADVANCE` : déplacer l'ancre commune vers la cible sans casser les rangs.
3. `ENGAGE` : tenir la ligne à portée de lance et distribuer un petit budget d'attaques au premier rang.
4. `RECOVER` : reformer brièvement la ligne quand la cohésion chute.
5. `HOLD` : tenir un secteur de soutien sans traverser une autre troupe ni consommer le budget d'attaque de la ligne de contact.

`EnemyV2BattleLayoutRuntime` réserve les secteurs de plusieurs troupes autour d'une même cible. De zéro à quatre phalanges réellement éligibles occupent la ligne de contact : une face, deux faces opposées, un triangle ou un carré. Les autres gardent des blocs de soutien ; les petits groupes et futurs archers utilisent des anneaux/rôles distincts derrière la même interface.

## Cadences et budget

- Décision collective proche : 8 Hz maximum par phalange.
- Décision collective lointaine : 2 Hz maximum par phalange.
- Mesure de cohésion et choix des attaquants : pendant le tick collectif uniquement.
- Exécution physique : par membre actif, O(1), sans allocation ni requête de groupe.
- Nombre d'attaquants simultanés : borné par profil, indépendamment de l'effectif total.
- Les cadences sont déphasées par identifiant de groupe pour éviter les pointes CPU synchronisées sur la carte à 150 soldats.
- Les phalanges partageant une cible reçoivent des secteurs tactiques stables, calculés au niveau stratégique, afin qu'elles ne convergent pas vers le même point et ne fusionnent jamais leurs membres.
- L'éligibilité et les priorités de contact sont réévaluées toutes les 350 ms par cible, avec hystérésis. Une troupe réellement proche peut remplacer un ancien focus devenu lointain sans déclencher une IA par soldat.
- Un demi-tour proche de 180° miroir les coordonnées locales des slots : la position mondiale de chaque soldat est conservée pendant qu'il tourne sur lui-même.

## Forge et scénario de référence

- `PHALANGE V2` crée exactement 24 unités, 18 standards + 6 vétérans, en 8 × 3.
- Le preset active explicitement `v2_troop_mode = "hoplite_phalanx"` et le combat V2.
- `champsDeBataille_V2_150` reste le scénario honnête : 6 phalanges × 24 + une escouade compacte de 6 vétérans, soit sept cerveaux collectifs et zéro vétéran autonome empilé sur le joueur.
- Les groupes V2 en formation reçoivent un coordinateur enfant du holder ; les autres ennemis continuent leur route actuelle.

## Critères de validation

- Les 24 slots sont uniques, centrés et espacés selon les propriétés Forge.
- Les vétérans restent sur les bords des rangs conformément au placement existant.
- Une phalange n'exécute qu'un seul tick de décision partagé ; les membres n'ont pas de boucle d'IA de duel autonome.
- Aucun membre hors premier rang ne reçoit de permission d'attaque tant que la ligne tient.
- Le nombre de permissions simultanées ne dépasse jamais le budget du profil.
- Une perte de membre ne casse ni le runtime ni les slots survivants.
- Le preset et la carte de 150 unités activent le nouveau mode sans changer la route de production V1.

## Compétences Godot appliquées

- `godot-brainstorming` : séparation troupe / acteur et frontière de responsabilité.
- `ai-navigation` : cible et mouvement proposés par une couche de décision, jamais par plusieurs propriétaires concurrents.
- `component-system` : contrat public étroit entre coordinateur, acteur et combat.
- `state-machine` : états collectifs explicites et transitions centralisées.
- `godot-optimization` : cadences limitées, travail déphasé, données mises en cache et budget d'attaque borné.
- `godot-testing` : sondes de contrat et scénario d'intégration Forge.

## État livré

Implémenté et validé le 1 septembre 2026. Le scénario sauvegardé contient 150 soldats : 144 membres sous six cerveaux de phalange et six vétérans sous un cerveau d'escarmouche. Le niveau stratégique réassemble dynamiquement jusqu'à quatre phalanges autour de la cible et laisse l'escouade compacte fermer directement au contact en parallèle ; les pertes reforment la première ligne. Les boucliers V2 levés retrouvent aussi le contrat Shield Run. Les sondes Forge, champ de bataille, placement 1/2/3/4, combat, démembrement, transparence caméra, Shield Run et LOD passent. La navigation navmesh de l'ancre et le rendu lointain MultiMesh/imposteur restent dans la tranche suivante.
