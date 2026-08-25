# V0.0.19 — La Dernière Flamme

## Accès

Depuis le stand de tir, franchir le portail bleu situé derrière les deux portails de campagne :

`LA DERNIERE FLAMME — RECIT`

La scène peut aussi être lancée directement :

`res://battle_03_narrative.tscn`

## Intention

Cette mission courte doit opposer un guerrier spartiate seul à une Athènes immédiatement reconnaissable : voie sacrée, catapultes abandonnées, marbre blanc, frises bleues, statues d'Athéna, cyprès, temples, phalange de bronze et sanctuaire rougeoyant.

Le récit suit la piste du capitaine Théron à travers trois actes de plus en plus massifs :

1. **La voie des cendres** — 88 ennemis planifiés : huit soldats du premier bataillon sont déjà visibles sur la route au chargement, avant tout déclencheur. Les douze autres arrivent avec le premier acte, puis viennent le second bataillon de 20 fantassins, 10 archers, 30 sbires répartis sur 15 secondes, six Nathenian2 en version soldat et deux miniboss consécutifs. Le premier miniboss attend la fin des 15 secondes ; la mort du second ouvre immédiatement la porte, sans exiger le nettoyage des survivants.
2. **Le mur de bronze** — 46 ennemis : deux phalanges de 12 placées à gauche et à droite de la fontaine. Chacune est couverte par un centurion, un Nathenian2 soldat et trois archers ; six fantassins et six sbires tiennent l'avant. La porte du sanctuaire s'ouvre dès la mort des 24 hoplites des deux phalanges, conformément à l'objectif affiché ; les 22 soutiens restants ne bloquent plus la progression.
3. **Le dernier serment d'Athènes** — huit sbires de pression puis une armée de 43 unités : grande phalange de 28 lanciers, huit archers, quatre Nathenian2 soldats et trois centurions. Le flux initial de fantassins a été supprimé.

Les quatre brasiers du sanctuaire restent éteints jusqu'à la mort des trois centurions. Ils s'allument alors ensemble et Théron apparaît au centre. Les centurions, miniboss et boss utilisent leur IA complète même lorsque les soldats ordinaires passent en mode bataille de masse.

Les combats accordent 3 PV par victime et déclenchent des annonces à 5, 10 et 20 éliminations. Les deux fins d'acte rendent davantage de santé afin de préserver la montée héroïque sans supprimer le danger frontal de la phalange. Le ciel, l'ambiance lunaire et la brume ont été relevés dans les trois zones afin que les silhouettes et les attaques restent lisibles sans perdre la nuit bleue et le contraste des brasiers.

## Paramètres globaux

Le même menu `PARAMETRES DE COMBAT` est disponible dans le stand, les batailles narratives et la campagne procédurale avec `²` ou `Options / Menu` :

- **Caméra** : position et distance.
- **Son** : master, musique, SFX, piste musicale et volume individuel de chaque famille de SFX.
- **Affichage** : HUD de combat, feedback, objectifs, narration, gore et LOD ennemi configurable.
- **Atmosphère** : lumière principale, hauteur, ambiance, exposition, brasiers, flammes, fumée et brume, avec dix templates allant du jour méditerranéen à Athènes en flammes.
- **Jouabilité** : périphérique automatique/MNK/manette, liste complète des commandes et remapping séparé des deux périphériques.

Les réglages sont sauvegardés dans `user://hoplite_global_settings_v1.cfg`. Une parade ou esquive parfaite conserve les contres contextuels : dash avec `Maj` / `Rond`, contre rapproché avec `Clic droit` / `R2`.

Le LOD propose les profils Qualité, Équilibré, Performance et Personnalisé. Il pilote le seuil de décimation automatique du viewport, le niveau de détail des meshes ennemis, la fréquence des animations, les ombres, les particules et la distance d'occultation. Il peut être désactivé sans désactiver l'IA ni les collisions.

## Patrouille de démonstration

La cohorte devant les portails patrouille en permanence en formation de trois rangs. Hors de sa zone d'activation, elle regarde sa direction de marche et ne suit pas le joueur du regard. À moins de 31 mètres, elle abandonne sa route, se rassemble immédiatement, pivote progressivement puis avance déjà formée vers le joueur.

## Validation

- `tools/narrative_battle_probe.gd` vérifie les huit ennemis présents au départ, les 5 déclencheurs, les 13 familles d'assets, la lumière et les deux phalanges.
- `tools/last_flame_wave_probe.gd` vérifie les totaux 88 / 46 / 51, les compositions runtime des zones 2 et 3, l'ouverture de la première porte avec des soldats survivants et celle du sanctuaire dès la destruction des deux phalanges.
- `tools/global_settings_probe.gd` vérifie les cinq onglets, les dix templates d'atmosphère, les 16 actions remappables et le LOD configurable dans les quatre familles de scènes.
- `tools/narrative_battle_thumbnailer.gd` et `tools/global_settings_thumbnailer.gd` produisent les vues de contrôle dans `docs/last_flame/` et `docs/global_settings/`.
