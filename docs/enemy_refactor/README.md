# Système ennemi — point d’entrée

État du 5 septembre 2026, après la passe solo de commandement adaptatif et de troupe élite sans cercle.

- **Architecture V2 actuelle et contrats :** [V2_COMPOSITION_AND_ARMIES.md](V2_COMPOSITION_AND_ARMIES.md).
- **Utilisation dans la Forge :** [FORGE_BATTLEFIELDS_V2.md](FORGE_BATTLEFIELDS_V2.md), également accessible dans l’aide F1.
- **Détails archers/fantassins :** [ENEMY_V2_ROLE_COMPONENTS.md](ENEMY_V2_ROLE_COMPONENTS.md).
- **Suivi global de la migration V1 :** [MIGRATION_MATRIX.md](MIGRATION_MATRIX.md). Les identités de production V1 ne basculent pas implicitement.

Les rapports datés et les anciennes photographies sont des preuves historiques de leurs passes, pas une spécification de la nouvelle architecture. En cas de contradiction pour V2, utiliser les contrats ci-dessus puis vérifier le code et ses probes. La carte `champsdebataille_v2_commandement_414` reste le scénario de compatibilité des anciens fronts ; le nouvel exemple de commandement est `bataille_v2_deux_armees`.

À chaque changement : mettre à jour le contrat ou le guide concerné, ainsi que les probes qui vérifient un comportement observable. Conserver les mesures avec leur scénario et leurs limites. Ne pas multiplier les comptes rendus présentés comme autoritaires. Les définitions de sous-agents restent à concevoir ultérieurement ; cette passe a été réalisée sans délégation.
