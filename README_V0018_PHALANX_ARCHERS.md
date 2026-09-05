# V0.0.18 — Roster athénien, phalange et archers

## Les neuf rôles logiques (huit modèles source)

| Package logique | Rôle de jeu | Équipement | Comportement principal |
| --- | --- | --- | --- |
| `nathenian1` | Infanterie légère à bouclier | Épée + bouclier | Mobilité et garde disciplinée hors phalange |
| `nsbire1` | Levée civique / harceleur fragile | Outil agricole | Frappe prudemment et se replie lorsque sa santé baisse |
| `nsbire2` | Archer léger de soutien | Arc | Cherche une ligne de tir propre, reste punissable au contact |
| `nathenian2` | Briseur de ligne | Marteau lourd | Attaques lentes, balayage et choc contre les groupes compacts |
| `bronze_colossus` | Juggernaut de siège | Marteau colossal | Avance sans se disperser, absorbe les petits impacts, crée des zones de choc |
| `ncenturion` | Taxiarque / commandant de formation | Glaive + bouclier | Protège les positions importantes et tient la ligne de commandement |
| `ngeneral` | Lancier hoplite, cœur de phalange | Dory + grand aspis | Rejoint un emplacement, garde la ligne, attaque depuis les deux premiers rangs |
| `ngeneral_veteran` | Lancier vétéran de flanc | Dory + grand aspis | Tient les extrémités, réorganise plus vite et renforce la cohésion voisine |
| `nfull_armor` | Stratège cuirassé, boss d’ancrage | Grande épée + armure lourde | Boss en trois phases qui empêche le joueur d’ignorer le centre du combat |

`Nathenian1` conserve son rôle d'infanterie légère. Les deux identifiants NGeneral sont des variantes logiques qui partagent volontairement le même modèle 3D.

## Lanciers

Le lancier standard utilise le package visuel NGeneral. Le vétéran utilise le modèle dédié `hopliteClean1`, avec le même rig UAL1 et la même bibliothèque d’animations partagée. Le standard est à l’échelle `1.00` et le vétéran à `1.20`.

Les deux portent uniquement une lance et un bouclier. La perte de la lance ou du bras droit annule les attaques et déclenche un repli défensif ; aucune épée secondaire n’est créée.

La phalange utilise cinq colonnes par défaut. Le directeur de foule calcule un emplacement stable par soldat, place les vétérans sur les extrémités, compacte les emplacements après une perte et fait avancer les rangs arrière. Les états exposés par le contrôleur sont :

- `rassemblement`
- `marche`
- `garde`
- `attaque`
- `poussee`
- `reorganisation`
- `repli`
- `rupture`

Le premier rang garde une lance presque horizontale, le deuxième la relève, et les rangs suivants utilisent une attente haute. Les attaques sont limitées à deux permissions simultanées pour alterner estoc individuel et paire voisine. À l'activation, la cohorte rassemble d'abord 90 % de ses soldats autour d'un ancrage fixe ; cet ancrage avance ensuite à vitesse réduite afin que la ligne ne se défasse pas en approchant du joueur.

Les animations de lance combinent la locomotion existante avec un donneur Mixamo joué sur le haut du corps. La lance procédurale est réorientée chaque frame vers la menace et reçoit une petite translation d’estoc : elle ne suit donc pas visuellement un grand arc d’épée.

Le mur de boucliers reste actif entre les attaques. Sa protection est directionnelle : une attaque de flanc ou arrière contourne toujours l’aspis. La cohorte tourne à environ 28°/s et le vétéran à 34°/s, ce qui laisse au joueur le temps de déborder la ligne. L'aspis est avancé de 16 cm pendant la garde pour garder le poignet derrière la plaque. Un vétéran proche accélère la régénération de garde des lanciers voisins.

## Archer

`Pistol_Shoot` et `Pistol_Idle` ne sont plus utilisés. Le tir détaillé joue `Bow Standing Aim Walk Back.fbx` sur le haut du corps et conserve la locomotion des jambes. L'arc est tourné de 90° dans la main gauche afin que ses branches soient perpendiculaires à l'avant-bras. En foule, l'archer reste neutre plutôt que d'emprunter une attaque de mêlée. Le projectile possède une hampe fine, une petite pointe et des empennages rouges afin de ne plus pouvoir être confondu avec un javelot.

Dans le terrain d'entraînement, les stands d'archers et de NGeneral gardent les couches d'animation détaillées. Devant les deux portails, une patrouille dédiée de quinze NGeneral présente trois rangs de cinq : onze hoplites standards et quatre vétérans placés aux flancs des deux premiers rangs.

Le fichier `Longbow Locomotion Pack.zip` ne contient aucun tir ou relâchement de corde, seulement des déplacements et des rotations. Un véritable clip `bow draw/release` reste donc l’amélioration d’asset prioritaire ; le donneur actuel est une correction cohérente et immédiatement utilisable, pas une animation de décoche complète.

## Limites connues de cette première passe

La fermeture de brèche et la remontée de rang fonctionnent. En revanche, la subdivision d’une grande phalange en plusieurs sous-formations, la détection explicite des rues trop étroites et la déformation pilotée par la navigation devront être traitées dans une passe terrain/navigation dédiée.
