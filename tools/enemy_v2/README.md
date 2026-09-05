# Hoplite EnemyV2 — pipeline reproductible

## Laboratoire de commandement à 414 soldats

La Forge propose maintenant `champsDeBataille_V2_Commandement_414`, copie isolée du terrain V2 conçue pour éprouver le commandement hiérarchique : 17 phalanges de 24 et un bataillon de pression de 6. Les quatre contacts restent proches, quatre soutiens tiennent la profondeur et neuf réserves restent assez loin pour conserver durablement le LOD imposteur.

L'overlay affiche en jeu les groupes, la population, les rôles, la distribution LOD, le batch d'imposteurs, les corridors actifs et les brèches. Il expose aussi les conflits d'ancrage, les permissions d'attaque et les attaques lancées dos à la cible : les deux compteurs d'erreur doivent rester à zéro. La carte d'origine n'est pas modifiée.

Pour régénérer la copie après une modification du manifeste :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_v2/author_champsdebataille_v2_command_lab.gd
```

Les validations principales sont :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_v2/hoplite_v2_command_lab_probe.gd
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_v2/hoplite_v2_command_lab_runtime_probe.gd
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_v2/hoplite_v2_tactical_stability_probe.gd
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_v2/hoplite_v2_army_scale_probe.gd
```

Le laboratoire possède son profil LOD reproductible (`10 / 26 / 65 m`, physique complète à `3 m`) et restaure les réglages globaux en quittant la carte. Le run graphique de référence du 1er septembre 2026 mesure `13,582 ms` de moyenne et `16,185 ms` au p95 sur 414 soldats après échauffement, avec 208 imposteurs, `3 486` draw calls et `1 107 519` primitives. Le décor sans ennemis coûte `4,990 ms` dans le même probe. Les draw calls et l'animation des représentations 3D constituent désormais le coût dominant.

La stabilité locale est distincte de la stratégie d'armée : un front engagé continue de regarder la cible réelle même si le focus tactique est temporisé. Les défenseurs les plus proches reçoivent les permissions d'attaque, pivotent avant d'avancer, puis ne peuvent frapper qu'une fois dans le cône avant. Les ancres de formations possèdent une exclusion mutuelle et une correction déterministe des superpositions. Une brèche confirmée ouvre maintenant un canal de cinq colonnes autour du point de pénétration, sans scinder prématurément toute la phalange.

Le package de production est généré ; `C:\Users\suean\Downloads\dismemberedSpartanV2` reste une source 3DGen externe et n'est jamais modifiée.

Depuis la racine du projet, double-cliquer `HOPLITE_V2_PREPARER.bat` ou exécuter :

```powershell
.\HOPLITE_V2_PREPARER.bat
```

Pour publier un autre dossier exporté par 3DGen :

```powershell
.\HOPLITE_V2_PREPARER.bat -SourceRoot "C:\chemin\vers\le\package"
```

Le lanceur vérifie le manifest, les neuf fragments et les hashes des 22 textures partagées. Il copie les ressources dans `assets/characters/enemy_v2/hoplite`, transforme le corps 53 os en rig 23 os, publie les 14 clips du donneur partagé, force l'import Godot et exécute les probes de contrat et de sécurité V1.

Un résultat `PASS` signifie que le package est techniquement cohérent. Il ne change jamais la factory de production : le passage à V2 reste bloqué tant que `hoplite_v2.package.json` conserve `migration_ready: false`.

## Combat progressif

La Forge propose deux usages séparés :

- `PHALANGE V2` crée 24 hoplites (18 standards + 6 vétérans) en 8 × 3, avec combat, garde et coordination collective ;
- `DUEL V2 LAB` active explicitement les composants V2 d'anatomie, de vitalité et de combat contre le joueur.

La phalange n'exécute pas 24 IA de duel. Un `EnemyV2TroopRuntime` décide à cadence bornée (8 Hz proche, 2 Hz lointain), conserve les slots, mesure la cohésion, approche la cible radialement depuis la position propre à chaque groupe et limite les permissions d'attaque au premier rang. Les anciens couloirs globaux ont été retirés : ils pouvaient imposer plus de 50 m de déplacement latéral à certaines phalanges et donner l'impression qu'elles fuyaient.

Le LOD visuel et la simulation sont désormais séparés. Tous les membres de troupe sont déplacés par le runtime collectif ; seuls les soldats du premier rang situés dans la distance `full_rate_distance` du profil actif récupèrent temporairement une capsule et `move_and_slide()`. Sur la carte réelle à 150 soldats avec le profil Performance (`10/26/65 m`, physique complète à `3 m`), le diagnostic initial publie 144 membres en transform de troupe et zéro physique individuelle. Le benchmark headless complet est passé d'environ `217,9 ms` avant cette séparation à `7,1 ms` sur le run de validation. Le run graphique final mesure `19,9 ms` de moyenne (`36,6 ms` au p95), avec trois membres de troupe en physique individuelle et environ `2 574` draw calls. Le rendu Compatibility demeure donc la prochaine cible, notamment parce que la lance et l'aspis conservent chacune trois surfaces à tous les LOD.

Cette tranche couvre l'approche directe sur terrain dégagé, une garde à aspis physiquement interceptable, la réaction de blocage, trois patterns de lancier courts (torse, bas et attaque appuyée à deux mains), un télégraphe d'attaque commun, la récupération, la réception des coups et une mort recalée au sol. Les clips partiels reçoivent au bake les pistes de jambes de l'idle afin qu'une course précédente ne reste jamais figée pendant une attaque. Les deux thrusts conservent la pose défensive du bras gauche et l'aspis active ; l'attaque Bayonet à deux mains assume une fenêtre exposée.

`assets/animations/source_packs/spear/Bayonet_Stab.fbx` est une source Mixamo hors ligne. `tools/build_hoplite_animation_library.gd -- --v2` la retargete dans le donneur de travail dédié `hoplite_v2_source_53.res`, puis le publisher V2 la filtre vers les 23 os. La sortie historique `hoplite_animation_library_v4.res` n'est pas modifiée par ce mode et aucun squelette donneur Mixamo ni retargeter n'est instancié par soldat V2.

Le `Dismemberment` du Duel V2 applique les seuils anatomiques existants, désactive les hitboxes liées, masque durablement la chaîne d'os, retire l'équipement porté par le membre et lance le vrai fragment 3DGen préfabriqué. La tête suit ensuite la mort ordinaire. Le pooling global et le masque GPU exact fondé sur `TEXCOORD_2.x` restent les deux étapes suivantes ; le fallback actuel ne recrée jamais un corps complet.

`champsDeBataille_V2_150` est le scénario d'intégration : six phalanges de 24 et une garde de six vétérans. Le probe `res://tools/enemy_v2/hoplite_v2_battlefield_150_probe.gd` vérifie les 150 créations, les 144 membres coordonnés, les six cerveaux de troupe, les rangs avant, le budget de décision et le fait que chaque groupe réduit bien sa distance à la cible sans détour latéral. La navigation de l'ancre sur navmesh, les arcs tactiques avancés, les équipements atlasés/LOD et les imposteurs distants restent des tranches ultérieures. Le runtime V1 n'est pas modifié.
