# Escorte du joueur indépendante

Mission solo autorisée. Forge : effectifs par famille, puissance séparée de l’armée. Un EscortController de scène possède les ordres G (rejoindre puis combattre), B (anneau protecteur), H (tenir la cible), la sélection par rayon caméra et le retour HUD. Le runtime V2 conserve corps, armes, LOD, dégâts et budgets ; aucun monolithe d’unité ajouté. Protection directionnelle par gardes réellement en place, régénération joueur existante conservée.

1. Composition/migration/UI : godot-brainstorming, godot-ui.
2. Commandement, interruptions, protection : ai-navigation, input-handling.
3. Diagnostic des groupes inactifs, régression et documentation : godot-code-review, godot-debugging.

Statut : terminé. Probes escorte (dont touches physiques et rayon sol, interception réelle et migration), retinue, authoring, Forge, rôles, trafic et crashes : PASS. Intégration avec rendu G puis B sur 1400 images : PASS ; capture de l’anneau inspectée. Documentation unifiée mise à jour. Les avertissements connus du sandbox et de libération de textures à la fermeture Forge restent présents.
