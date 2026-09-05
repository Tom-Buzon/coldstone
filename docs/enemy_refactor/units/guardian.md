# `guardian` — audit final individuel

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Archetype exact :** `guardian`\
**Famille d’audit :** `legacy_standard_shield`\
**Portée :** caractérisation et validation finales en lecture seule des systèmes centraux. Aucun correctif de gameplay n’a été appliqué pendant cet audit.

## Verdict

`guardian` satisfait le contrat d’acceptation actuellement observable : construction par la factory canonique, identité stable, rig animé, axe et bouclier attachés, défense physique activée seulement pendant la garde, locomotion/combat fonctionnels, navigation `DIRECT_STEERING`, anatomie complète `12/12`, démembrement `10/12`, libération de l’équipement et teardown propre. Le probe ciblé termine avec le code `0` et le full roster valide les 22 identités.

Les réserves relevées ne bloquent pas ce verdict, mais doivent rester visibles : cet archétype n’utilise pas de navmesh, le moment de contact offensif est piloté par timer plutôt que par une piste d’événement d’animation, les volumes physiques héritent de scales de parents, et le LOD de simulation ne réduit pas explicitement la cadence de l’`AnimationPlayer` Mixamo direct.

## Preuves primaires

| Preuve | Résultat |
|---|---|
| `.tmp_tools/enemy_refactor/guardian_dismemberment_final.log` | `ENEMY_UNIT_DISMEMBERMENT_PROBE PASS id=guardian zones=12 severed=10`, code de sortie `0`, Godot `4.7.stable.official.5b4e0cb0f` |
| `.tmp_tools/enemy_refactor/full_roster_validation_probe.log` | `guardian`: famille `legacy_standard_shield`, rig `direct_mixamo`, anatomie `12/12`, équipement `axe+shield`, action `static`, navigation `DIRECT_STEERING`; fin `PASS: 22/22` |
| `.tmp_tools/enemy_refactor/logs/visual_guardian.log` | génération visuelle en six états réussie, sortie `docs/enemy_refactor/visual_evidence/guardian.png`, `1351 × 760` |
| `docs/enemy_refactor/visual_evidence/guardian.png` | inspection visuelle directe effectuée : idle sans équipement, jog sans équipement, attaque, impact, mort et section |
| `.tmp_tools/enemy_refactor/logs/enemy_combat_probe.log` | contrat transversal garde, rupture de garde, parade et patterns : PASS |
| `.tmp_tools/enemy_refactor/logs/enemy_action_state_probe.log` | priorité garde/récupération/wind-up/parade/tactique : PASS |
| `.tmp_tools/enemy_refactor/logs/enemy_transient_lifecycle_final.log` | ressources partagées, TTL borné, retrait collision/ombres : PASS |
| `.tmp_tools/enemy_refactor/mission_baseline_enemy_factory_route_probe.log` | toutes les routes runtime passent par la factory canonique : PASS |

Le message Windows `Failed to read the root certificate store` apparaît dans plusieurs logs headless. Il précède les PASS, n’est pas produit par le système ennemi et n’a pas affecté le code de sortie du probe ciblé.

## Construction, profil et routes

### Construction canonique

- `scripts/enemy/enemy_factory.gd:12-85` transforme l’appel historique en `EnemySpawnRequest`, instancie un unique `HopliteAthenianEnemy`, injecte l’identité, la position, les options d’IA/faction/masse/commandant, puis ajoute le nœud à l’arbre.
- `scripts/enemy/athenian_enemy.gd:313-358` applique le profil **avant** la construction du collider, du mannequin, de l’anatomie et de la navigation. Cette séquence évite un équipement ou un volume construit avec les valeurs par défaut du swordsman.
- `scripts/enemy/enemy_archetypes.gd:37-73` renvoie une copie profonde du profil et normalise `shield=true` en défense `shield`. `EnemyArchetypeData` fournit ensuite une vue typée et mise en cache; les consommateurs legacy ne peuvent pas muter le template partagé.
- Le champ `family=legacy_standard_shield` est une classification du manifest/probe, pas une seconde classe runtime ni une chaîne d’héritage. Le contrôleur reste commun aux 22 identités.

### Valeurs finales du profil

| Propriété | Valeur |
|---|---:|
| nom / skin | `GUARDIAN` / `guardian` |
| couleur de fallback | bleu `Color(0.025, 0.18, 0.72)` |
| scale de corps | `1.05` |
| points de vie | `160` |
| vitesse | `4.0` |
| dégâts d’attaque | `16` |
| portée / aggro | `1.78` / `19.0` |
| arme / scale | `axe` / `1.0` |
| bouclier / scale | `true` / `1.18` |
| comportement / style | `guardian` / `light_mix` |
| wind-up / récupération | `0.30 s` / `0.34 s` |
| cooldown | `1.00–1.30 s` |
| vitesse d’animation d’attaque | `1.04` |
| bande préférée | `0.0–1.72 m` |

La normalisation du bouclier ajoute : chance déclarative `0.30`, fenêtre `0.68 s`, cooldown `1.55 s`, multiplicateurs dégâts/section `0.20/0.12`, garde `78`, régénération `18/s` après `1.30 s`, réaction `0.13 s` jusqu’à `3.60 m`. En pratique, une menace frontale valide déclenche un bouclier avec une probabilité `1.0`; la chance reste surtout pertinente pour la parade.

### Routes constatées

- Le manifest déclare `battle_01`, `battle_02` et `spartan_allies` comme routes primaires (`docs/enemy_refactor/roster_manifest.json`).
- Battle 01 et Battle 02 l’emploient dans les cohortes, lignes de front, rencontres urbaines et escortes de boss. Les grandes cohortes activent souvent `mass_battle_mode`.
- Les alliés spartiates réutilisent exactement le même archétype avec `faction=spartan`; seules les règles de faction/groupes et la cible changent.
- `guardian` ne fait pas partie de `ROSTER_IDS`, donc il n’entre pas dans le catalogue procédural moderne renvoyé par `procedural_catalog()`. Sa présence procédurale n’est pas revendiquée par cet audit.
- La capture visuelle est une route de preuve dédiée, pas la preuve d’une présence dans le showroom courant du combat lab.

## Combat et bouclier

### Offense

- Aucun `combat_pattern` spécialisé n’est défini : le full roster qualifie correctement l’action de `static`.
- Le style `light_mix` choisit `light1` ou `light2`; le catalogue direct Mixamo installe une réserve propre à `guardian` : `axe_horizontal`, `axe_down`, `sword_slash` (`scripts/enemy/mixamo_catalog.gd:76-85`).
- `_begin_ai_attack()` réserve un lease auprès du crowd director, abaisse la garde, bloque la translation initiale, lance le wind-up et l’animation; `_resolve_ai_attack()` vérifie encore le lease, la portée et l’arc avant d’appliquer `16` dégâts de base.
- Une perte du bras droit ou de l’avant-bras droit lâche l’axe et rend `_can_ai_attack()` faux. Les attaques en cours sont annulées par `_refresh_injury_state()`.

### Défense et équipement

- L’axe procédural est attaché à la main droite; le bouclier procédural est attaché à la main gauche. Le guardian n’emploie volontairement pas l’`aspis_shield.glb` réservé aux familles phalanx; `tools/phalanx_equipment_probe.gd:30-32` l’affirme explicitement.
- Le bouclier visuel est un cylindre bronze avec boss central; son `Area3D` utilise un `CylinderShape3D`, priorité de contact `5.0`, couche combat `8` seulement quand la garde est active.
- Une menace doit être frontale. La garde ralentit le mouvement à `42 %`, alimente un état `shield_guard`, place explicitement la plaque devant le torse et joue un impact de blocage.
- Les coups consomment la stamina de garde. À zéro, l’état passe à `guard_broken`, annule le wind-up, impose environ `0.52–0.94 s` de récupération et prolonge le cooldown.
- Une section du bras/avant-bras gauche ferme immédiatement la défense, désactive le hitbox et crée un bouclier `RigidBody3D`; à la mort, axe et bouclier sont également libérés.
- Les débris d’équipement utilisent des primitives, dorment, restent physiques `4 s`, deviennent ensuite sans collision/ombres, puis expirent à `12 s`.

## Navigation et tactique

- Le mode exact validé est `HopliteEnemyNavigationComponent.Mode.DIRECT_STEERING`. Aucun `NavigationAgent3D` n’est créé pour ce mode; celui-ci n’existe que pour `NAVMESH_GROUND`.
- Le contrôleur fournit une destination tactique au composant à chaque tick physique. Celui-ci retourne une direction plane, une vitesse et un statut, tandis que le `CharacterBody3D` applique accélération, gravité et `move_and_slide()`.
- La séparation est calculée via le crowd director/spatial grid puis combinée à la direction de déplacement. Les collisions entre ennemis sont volontairement retirées du masque, ce qui évite leur coût quadratique et confie l’espacement au steering.
- Le composant surveille le progrès réel; après `0.82 s` sans progrès, il tente une esquive latérale de `0.48 s` à `72 %` de la vitesse. Cela traite un blocage local, mais ne calcule pas de chemin autour d’un obstacle complexe.
- Le comportement `guardian` conserve la ligne d’interception devant un commandant vivant (`hold_line`) et passe sinon en `shield_line`. Les slots persistants du crowd director empêchent tous les gardiens de viser l’origine de la même cible.
- Les décisions tactiques sont échantillonnées toutes les `0.045–0.18 s` selon distance et `mass_battle_mode`; l’intégration physique reste à chaque tick.

## Rig, animations et donneurs

- La route normale est `direct_mixamo`, confirmée par le full roster. Il n’existe ni package 3DGen ni donneur UAL1 caché ni pont de retarget pour ce guardian.
- Les modèles proviennent du pool `smallsbir5` / `smallsbir3`; en masse, le pool se réduit à `smallsbir5`. Le choix hors masse dépend de `guard_index` et de l’instance, donc la variante visuelle n’est pas stable entre toutes les instanciations.
- Le mannequin fournit directement `Skeleton3D` et `AnimationPlayer`; les deux mains sont résolues par recherche normalisée des noms de bones. Le full roster valide skeleton non vide, player animé et deux mains résolues.
- `install_personality()` ajoute une `AnimationLibrary` par instance, mais les ressources `Animation` dupliquées sont mises en cache statiquement. Les boucles sont marquées `LOOP_LINEAR`, les attaques `LOOP_NONE`, et les pistes de translation des hips sont supprimées pour que le `CharacterBody3D` reste propriétaire du déplacement.
- Les clips FBX utiles sont importés à `30 FPS`, avec trimming, retrait des pistes immuables, tangentes, shadow meshes et génération de LOD. Les modèles de corps sont des GLB avec LOD générés.
- Le code d’armure procédurale `skin_id == guardian` (cuirasse renforcée, casque corinthien, épaules, grèves, pteruges) n’est utilisé que sur le fallback UAL1. Une charge Mixamo réussie conserve le costume du modèle source et ajoute seulement l’axe et le bouclier procéduraux.

## Rendu et performance structurelle

- Les seuils de rendu sont pilotés par les réglages projet avec défauts `near=16 m`, `far=38 m`, `cull=90 m`; le LOD ajuste `lod_bias`, visibilité, ombres et particules.
- En `mass_battle_mode`, les ombres du visual root sont supprimées et le pool de modèles est réduit. La recherche récursive des géométries n’a lieu qu’au changement de niveau de LOD, pas chaque frame.
- Le tracking anatomique s’endort hors combat; près d’un impact il suit à chaque tick ou à `30 ms` en masse, puis passe à `45/65 ms`, `120/200 ms`, ou est désactivé loin de toute interaction.
- Le cache Mixamo évite de recharger et recopier les animations source pour chaque guardian. Les ressources de meshes/matériaux des débris sont également partagées et leur durée est bornée.
- Limite mesurable : le throttle `60/30/12/0 Hz` vise `ai_animation_driver`, mais `guardian` utilise l’`AnimationPlayer` Mixamo direct et n’a pas ce driver. La géométrie peut être culled tandis que l’animation enfant continue; aucun benchmark CPU individuel `guardian` n’a été produit.

## Anatomie : 12 zones et démembrement

Toutes les zones sont créées dans une seule `Area3D` sur la couche `8`, avec une primitive par zone, un état localisé et un suivi des bones. Le probe ciblé a instancié un ennemi indépendant par zone, appliqué un fort sever hit, contrôlé l’état, la fatalité, la création d’un détachement et la perte d’équipement.

| Zone | Forme / rayon | Dégâts × | Sever × / seuil | Section | Conséquence |
|---|---|---:|---:|---|---|
| `head` | sphère `0.25` | `1.70` | `1.00 / 64` | oui, fatale | tête détachée, mort |
| `neck` | capsule `0.15` | `1.85` | `1.35 / 56` | oui, cible `head`, fatale | tête détachée, mort |
| `torso` | capsule `0.34` | `1.00` | `0.35 / 9999` | non | dégâts localisés seulement |
| `pelvis` | capsule `0.30` | `0.95` | `0.30 / 9999` | non | dégâts localisés seulement |
| `upper_arm_l` | capsule `0.16` | `0.78` | `1.00 / 78` | oui | désactive aussi `forearm_l`, lâche le bouclier |
| `forearm_l` | capsule `0.14` | `0.75` | `1.10 / 60` | oui | lâche le bouclier |
| `upper_arm_r` | capsule `0.16` | `0.78` | `1.00 / 78` | oui | désactive aussi `forearm_r`, lâche l’axe, désarme |
| `forearm_r` | capsule `0.14` | `0.75` | `1.10 / 60` | oui | lâche l’axe, désarme |
| `thigh_l` | capsule `0.21` | `0.88` | `0.82 / 94` | oui | désactive `shin_l`, état limp/crawl |
| `shin_l` | capsule `0.18` | `0.84` | `1.05 / 72` | oui | état limp/crawl |
| `thigh_r` | capsule `0.21` | `0.88` | `0.82 / 94` | oui | désactive `shin_r`, état limp/crawl |
| `shin_r` | capsule `0.18` | `0.84` | `1.05 / 72` | oui | état limp/crawl |

Une jambe perdue limite la vitesse à `1.85`; deux jambes la limitent à `0.72`, abaissent/inclinent le visuel et raccourcissent le collider. Les membres détachés utilisent `RigidBody3D` + sphère/capsule, une impulsion bornée, `4 s` de physique et `14 s` de vie totale. Sur ce rig Mixamo monobloc, la chaîne de bones sectionnée est réduite à `0.001`; le morceau détaché est un proxy procédural, pas la géométrie skinnée originale.

## Physique

- Corps principal : `CharacterBody3D`, capsule primitive `radius=0.39`, `height=1.82`, gravité `24`, mouvement via `move_and_slide()` dans `_physics_process()`.
- Couches runtime : corps ennemi sur `4`, monde/joueur dans le masque; anatomie/bouclier sur `8`; débris sur `16` avec masque monde `1`. Les couches ne sont pas nommées dans `project.godot`, ce qui rend les bitmasks moins vérifiables dans l’éditeur.
- Les dégâts utilisent des `Area3D` monitorables sans réponse physique; la collision de locomotion reste la capsule du `CharacterBody3D`. Les RigidBodies reçoivent des impulsions, peuvent dormir et sont retirés de la simulation par timer.
- Réserve de conformité : le `CharacterBody3D` entier est mis à l’échelle par le profil (`1.05`) et le hitbox du bouclier est enfant du `shield_root` mis à l’échelle (`1.18`). Les shapes n’ont pas un `scale` local explicite, mais héritent tout de même de ces transformations. Cela s’écarte de la recommandation Godot consistant à dimensionner les shapes elles-mêmes; aucun défaut de contact n’a été observé dans les probes actuels.
- `project.godot` ne verrouille ni le moteur physique 3D ni `physics_interpolation`. Le binaire testé est Godot 4.7, mais l’audit ne revendique donc pas une configuration explicite Jolt/interpolation dans le dépôt.

## Inspection visuelle

La planche `guardian.png` rend les six états demandés sur fond sombre. Les silhouettes Mixamo sont correctement au sol et l’identité de porteur lourd est lisible dès les vues équipées : grand disque bronze, axe, posture fermée et contraste métal/tunique. L’attaque montre le bouclier dominant la face avant; l’impact reste lisible; la mort est couchée; la section montre la perte du bras droit et la libération de l’équipement/proxy avec sang.

Les libellés `IDLE NU` et `JOG NU` sont cohérents avec le générateur de preuve : celui-ci masque volontairement axe et bouclier pour exposer la pose du rig. Ils ne signalent pas un défaut d’équipement. Le proxy sectionné reçoit une forte impulsion et finit près du bord droit de la capture; la planche prouve sa création, mais pas sa qualité en gros plan. Les variantes `smallsbir5/smallsbir3` rendent aussi l’identité moins strictement uniforme qu’un package de personnage unique.

## Tests, couverture et limites

### Couvert par preuve dynamique

- spawn factory et identité `guardian`;
- présence/activité du rig, du skeleton, de l’`AnimationPlayer` et des bones de mains;
- axe, bouclier, main d’attache, défense et hitbox;
- navigation `DIRECT_STEERING` et ownership du composant;
- 12 définitions, 12 états, 12 mappings de skeleton sans bone manquant;
- 12 impacts localisés, 10 sections, fatalité tête/cou, non-section du torse/pelvis;
- détachement par zone, chute axe/bouclier pour les membres concernés;
- teardown séquentiel et sortie du stage;
- capture GPU des six états;
- contrats transversaux de garde/guard break/action priority et cycle de vie des débris.

### Non couvert ou seulement indirect

- aucun parcours guardian sur un navmesh ou labyrinthe; ce mode ne sait pas pathfinder;
- aucun benchmark CPU/GPU isolé par guardian ni test de foule composé uniquement de guardians;
- aucune mesure de précision entre bord visuel du bouclier scalé et cylindre physique;
- aucune capture rapprochée des attaches de main, de la face de l’axe ou du proxy sectionné;
- aucune garantie de déterminisme de la variante visuelle hors `mass_battle_mode`;
- la réserve d’attaque contient `sword_slash` malgré `weapon_kind=axe`; le geste reste jouable sur le rig, mais sa lecture arme/mouvement n’a pas été qualifiée en gros plan;
- aucune piste Call Method/marker ne lie le frame visuel exact au contact : le synchronisme repose sur wind-up, durée et vitesse calculés;
- les tests de combat transversaux valident le système de défense commun, pas une longue simulation statistique exclusivement guardian;
- l’avertissement de certificat Windows reste présent dans les runs headless, sans incidence fonctionnelle observée.

## Conclusion

**DONE.** Les preuves nécessaires au contrat `guardian` sont positives et reproductibles : full roster `22/22`, ligne guardian complète, image générée, et probe de démembrement ciblé `12 zones / 10 sections` avec code `0`. Les limites listées sont des travaux de robustesse/performance/qualité visuelle, pas des ruptures du contrat validé lors de cet audit.

### Clôture transversale post-audit

Les réserves communes ont été testées après cette fiche : `enemy_mixamo_variant_matrix_probe --id=guardian` passe les deux modèles et 24 zones cumulées, `enemy_unit_behavior_probe --id=guardian` passe toutes les décisions/attaques/interruption/perte de cible/sleep-wake, `enemy_animation_lod_probe` couvre le lecteur direct, `enemy_shield_world_radius_probe` valide le rayon physique mondial après mise à l'échelle et `enemy_material_cache_probe` confirme le partage des matériaux immuables. Ces preuves complètent la couverture sans changer le verdict DONE.
