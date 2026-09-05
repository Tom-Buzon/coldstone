# Armée V2 : fronts et armes combinées

Demande approuvée le 5 septembre 2026. Conserver les laboratoires historiques ; activer la doctrine de fronts sur la carte de commandement et les nouvelles créations Forge.

- Commandement commun : capacités, fronts persistants, réaction retardée aux brèches, interception limitée, menace partagée. Responsable principal. Skills : godot-brainstorming, resource-pattern, state-machine, ai-navigation.
- Trafic : emprises, terrain, réservations atomiques et progressives, reprise après blocage. Agent formation_traffic. Skills : ai-navigation, godot-optimization, godot-debugging.
- Archers et fantassins : composants V2, corps hoplite, équipements et combat propres. Agent ranged_infantry. Skills : component-system, animation-system, ai-navigation, assets-pipeline.
- Géants : adaptateur V2 et combat de miniboss, échelle Forge 3. Agent giant. Skills : component-system, animation-system, physics-system.
- Intégration Forge et carte : responsable principal. Population mixte, zones initiales, réglages exposés.
- Validation : probes ciblés, intégration réelle, régressions historiques et benchmark. Skills : godot-code-review, godot-debugging, godot-optimization.

Flux : Forge → définition/type → acteur et composants → troupe → commandement/front → trafic → intention locale. Les rapports de progression, perte et brèche remontent au commandement. Les permissions offensives passent par un budget commun par cible. Chaque unité conserve son exécuteur propre ; aucun branchement vers le monolithe V1 pour ces nouveaux types.
