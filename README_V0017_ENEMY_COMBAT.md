# PROJECT HOPLITE — V0.0.17 Combat des ennemis

État de référence : 22 août 2026.

## Pipeline d'animation

- Le joueur conserve sa banque complète de 18 donneurs Mixamo retargetés par le
  `SkeletonProfileHumanoid` et le `RetargetModifier3D` natif de Godot.
- Les soldats ordinaires réutilisent uniquement leur donneur UAL1 léger. Ils ne
  créent plus deux scènes UAL2 cachées par unité.
- Les miniboss et boss des nouveaux packages chargent seulement les 2 à 6 clips
  Mixamo nécessaires à leur pattern. Le transfert passe par le même proxy
  humanoïde natif validé que le joueur.
- Les capitaines et warlords historiques, déjà montés sur des rigs Mixamo,
  jouent directement le clip nommé par leur étape de pattern.
- La durée de chaque clip d'élite est synchronisée avec son
  `windup + recovery`; le dégât mécanique ne termine donc plus longtemps avant
  ou après le mouvement visible.

## Défense au bouclier

Les ennemis équipés d'un bouclier réagissent au signal de début d'attaque du
joueur. La réaction dépend de la distance, de l'angle, du type d'attaque et du
profil de l'ennemi. À courte portée, un porteur ouvre désormais une vraie phase
de garde lisible avant de pouvoir attaquer.

Chaque aspis équipé possède aussi sa propre `Area3D`, attachée à la main gauche.
Le balayage réel de la lame arbitre bouclier et anatomie comme un seul combattant :
si la lame rencontre le disque, elle s'y arrête et ne peut plus toucher le corps
pendant le même coup.

- la garde ne protège que l'avant ;
- un Light consomme 24, 29 ou 38 points de garde ;
- une Heavy consomme 62 à 132 points selon sa charge ;
- la spirale consomme 52 points avant bonus de mouvement ;
- un blocage réduit dégâts et dégâts de section, produit métal/étincelles et
  repousse le joueur ;
- à zéro garde, le contact devient `guard_break`, une partie du coup traverse et
  l'ennemi reste vulnérable pendant 0,48 à 0,92 seconde ;
- perdre le bras gauche fait tomber le bouclier et annule immédiatement la garde ;
- une parade réussie ferme sa fenêtre et prépare un contre rapide.

Ce montage est actif dans le stand de tir : ses 56 unités comprennent 14
porteurs de bouclier physique (`Nathenian I` et `Ncenturion`). Leur IA reste en
activation locale jusqu'à ce que le joueur entre dans leur zone de 13,5 mètres.

## Roster et patterns

| Ennemi | Identité de combat |
|---|---|
| Swordsman / Nathenian I | pression de base, garde frontale et endurance de bouclier |
| Guardian | ligne lente, grand bouclier et protection du commandant |
| Spearman | bande de portée, recul si le joueur entre sous la pointe |
| Flanker | orbite latérale, attaques rapides, aucun bouclier |
| Brute | marche lourde, poise élevé, coups engagés |
| Nsbire I | outil agricole, hésitation et fuite après blessure |
| Nsbire II | anneau longue portée, ligne de tir et projectile balistique |
| Captain | bash → coupe croisée → Heavy de commandement |
| Warlord | balayage → exécution → rush ; frénésie accélérée en phase 2 |
| Nathenian II | marteau vertical → poussée → balayage ; quake en phase 2 |
| Bronze Colossus | rugissement → charge → quake télégraphié → large balayage |
| Ncenturion | probe → bash avec lunge → combo lourd, garde renforcée |
| Ngeneral | feinte → coupe → finisher ; dash/spin/exécution en phase 2 |
| Nfullarmor | cleave → sweep → leap ; rush/storm/quake en phase 2 |

Les shockwaves dessinent maintenant leur rayon au sol pendant le windup, puis
une onde lumineuse au déclenchement. Leur dégât décroît jusqu'au bord du rayon.

## Validation

- `tools/enemy_roster_audit.gd` vérifie les 17 profils historiques et nouveaux,
  leurs modèles, équipements, défenses, patterns et chemins d'animation.
- `tools/enemy_combat_probe.gd` teste garde frontale/dorsale, consommation,
  contact physique, garde proactive, guard break, parade/contre et changement
  de phase.
- `tools/shooting_range_shield_probe.gd` charge la scène réelle et vérifie les
  56 montages du stand, dont les 14 surfaces de bouclier.
- `tools/enemy_animation_probe.gd` instancie les 9 élites et confirme que leur
  opener joue réellement sur le rig visible avec un timing synchronisé.
- `tools/pose_integrity_probe.gd` reste à zéro déformation sur les 18 clips du
  joueur et les huit nouveaux packages ennemis.
