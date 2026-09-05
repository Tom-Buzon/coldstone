# Géant V2 — intégration miniboss (2026-09-05)

> Pour la composition et le commandement **V2 actuels**, commencer par [README.md](README.md). Ce document conserve le contexte de sa passe et ne remplace pas les nouveaux contrats.

## Contrat

`enemy_v2_giant` (Forge) résout `giant_v2` dans le catalogue et crée `giant_v2_actor.gd` via la ShadowFactory V2. La production legacy reste inchangée.

Le runtime appelle `set_visual_scale(size_multiplier)` avant l'entrée dans l'arbre. La valeur par défaut du géant est 3. La racine CharacterBody reste à l'échelle 1 ; seul le visuel est mis à l'échelle, avec dimensions physiques et anatomiques calculées explicitement.

Le vrai package `geant1-1787584159710.glb` conserve 53 os, 10 meshes corporels et ses caps. Il n'utilise jamais les fragments ni l'impostor hoplite. Sept animations ont été baked sur son propre rig, depuis les sources existantes, par `giant_v2_build_animation_library.gd`. Aucune instance `enemy.gd`, aucun donneur d'animation ni pose bridge ne sont créés en jeu.

## Combat

Les trois patterns sont poing (préparation 1,05 s / récupération 1,55 s), balayage (1,35 / 1,70 s), frappe au sol (1,70 / 2,15 s). Chaque attaque reçoit une permission de l'armée, verrouille orientation et zone au départ, expose un contour au sol et ne peut toucher qu'une fois. La frappe au sol se saute, et les impacts ne traversent pas une obstruction du monde. Les récupérations augmentent de 40 % les dégâts reçus pour récompenser l'esquive puis l'approche.

Les interfaces de formation sont communes, dont `is_attack_committed()` et `attack_budget_seconds()`. Les déplacements gardent une inertie et un collider physique actif ; la présentation conserve la cadence LOD V2. Le géant reste visible jusqu'à au moins 160 m, avec animation suspendue au LOD3.

Une jambe sectionnée réduit le déplacement à 55 %. Deux jambes sectionnées immobilisent et abaissent le géant, réduisent son collider et retirent la frappe sautée de son choix d'attaques. Ses autres zones restent atteignables. Les fragments proviennent du vrai package et disparaissent après 9 s ; le cadavre disparaît après 18 s.

La couche 256 et `is_wall_run_giant()` permettent au joueur de reconnaître le géant pour la traversée expérimentale. Le collider est une capsule primitive : le système V2 n'importe pas l'ancien dispositif complexe cylindre/tête/sommet du monolithe.

## Validation effectuée

- `giant_v2_build_animation_library.gd` : PASS, 7 clips sur 53 os.
- `giant_v2_combat_probe.gd` : PASS ; permission, visée fixe esquivable, impact unique, saut au-dessus du slam, fenêtre de vulnérabilité, échelle, anatomie, vrais fragments, ralentissement/effondrement, mort et retrait des collisions.
- `giant_v2_forge_probe.gd` : PASS ; construction Forge réelle à x3 et x2, racine non redimensionnée, vrai rig et identification traversée.
- `giant_v2_visual_probe.gd` : rendu OpenGL inspecté, idle/poing/balayage/frappe au sol, corps distinct et poses animées. Image `.tmp_tools/giant_v2_visual.png`.

Revue Godot : ressources visuelles partagées, aucune recherche de scène/donneur dans les ticks, état de combat isolé, contrôleur physique unique, arrêt du combat et des Areas à la mort, transients à durée bornée. L'asset source reste lourd (environ 80 k triangles avant LOD d'import) ; cette passe ne prétend pas être sa refonte géométrique individuelle ni un benchmark GPU du champ de bataille.
