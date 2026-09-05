# Audit final — `warlord`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions, d'une phase II non déroulée ou d'une présence Lab/Forge statique. Le probe exact `enemy_phase_contract_probe -- --id=warlord` observe `transitions=[2]`, déroule les deux actions de phase II puis nettoie entièrement; les probes comportemental et démembrement strict passent aussi. La planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. TTL et rechargement sont couverts par `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Archétype exact :** `warlord`\
**Famille d'audit :** `legacy_boss`\
**Portée :** audit individuel de l'état courant; runtime, profils, assets, scènes et probes centraux examinés en lecture seule.

## Verdict

Le `warlord` satisfait le contrat audité : construction par la factory canonique, profil boss unique, faction/cibles communes, garde physique, deux phases de combat déclarées, leases partagés, locomotion `DIRECT_STEERING`, rig Mixamo direct, axe et bouclier, anatomie `12/12`, dix entrées sectionnables, mort atomique et teardown structurel. Le probe exact termine en code `0` avec `zones=12 severed=10`; le full roster valide son identité parmi `22/22`; le benchmark ciblé `1/12`, idle/actif, passe ses quatre scénarios et ne laisse aucune référence ennemie vivante.

La réévaluation finale lève le seul échec local reproductible. Le probe LOD partagé passe `10/10` exécutions consécutives sur les routes shared, native et Mixamo directe, y compris cadence LOD2, sommeil LOD3 et réveil LOD0. La matrice exacte `warlord` passe les quatre modèles du pool, soit `4` variantes et `48` zones anatomiques, avec squelette/lecteur valides, équipement détachable, cycle complet du pattern courant et rejet d'un override hors pool. La vraie route Forge construit et rend les `22/22` archétypes via `HopliteWorldRuntime` sous Compatibility; l'image inspectée ne montre aucune T-pose. Les preuves Battle rendues, le cycle phase 2 instrumenté et les métriques GPU comparables restent des extensions souhaitables, pas des pannes observées du contrat.

Aucun donneur, FBX, GLB, mesh ou matériau source n'a été supprimé. Le seul livrable modifié par cet audit est ce rapport.

## Preuves primaires

| Preuve | Résultat et portée réelle |
|---|---|
| `.tmp_tools/enemy_refactor/logs/warlord_dismemberment_final.log` | PASS exact : `id=warlord zones=12 severed=10`, exit `0` |
| `.tmp_tools/enemy_refactor/logs/warlord_shared_enemy_full_roster_validation_probe.log` | PASS `22/22`; ligne exacte : `legacy_boss`, `direct_mixamo`, `12/12`, `axe+shield`, `war_sweep`, `DIRECT_STEERING` |
| `.tmp_tools/enemy_refactor/logs/warlord_shared_enemy_animation_probe.log` | PASS; ouverture exacte `war_sweep -> mixamo/mutant_swipe`, durée visuelle à ±`0,10 s` de la mécanique |
| `.tmp_tools/enemy_refactor/logs/warlord_recheck_animation_lod_01.log` à `_10.log` | PASS `10/10` : cadence shared/native/direct, sommeil LOD3 et réveil réversible |
| `.tmp_tools/enemy_refactor/logs/warlord_recheck_mixamo_variant_matrix.log` | PASS exact : `id=warlord variants=4 zones=48`, équipement détachable, pattern courant complet, rejet cross-pool |
| `.tmp_tools/enemy_refactor/logs/warlord_performance_1_12_final.log` | benchmark v3 PASS, `1/12`, idle/actif, registre activé, teardown propre |
| `.tmp_tools/enemy_refactor/logs/warlord_shared_enemy_anatomy_regression_probe.log` | PASS : une section létale finalise toujours la mort |
| `.tmp_tools/enemy_refactor/logs/warlord_shared_enemy_registry_crowd_parity_probe.log` | PASS : parité registre/groupes lors des changements de participation |
| `.tmp_tools/enemy_refactor/logs/warlord_shared_enemy_mixed_stress_probe.log` | PASS : 22 familles/36 unités, cible déplacée/changée, sommeil/réveil, sections, morts et cleanup |
| `.tmp_tools/enemy_refactor/logs/warlord_shared_enemy_navigation_component_probe.log` | PASS : intention, arrivée, fallback et récupération, avec la clé `minimum_progress_speed` |
| `.tmp_tools/enemy_refactor/logs/warlord_shared_enemy_navigation_navmesh_probe.log` | PASS du mode partagé `NAVMESH_GROUND`; **non applicable au mode exact** du warlord |
| `.tmp_tools/enemy_refactor/logs/warlord_shared_enemy_action_state_probe.log` | PASS de la priorité garde/recovery/wind-up/parade/tactique du contrôleur commun |
| `.tmp_tools/enemy_refactor/logs/warlord_shared_enemy_combat_probe.log` | PASS transversal garde, guard break, parade et pattern de phase; pas un cycle warlord complet |
| `.tmp_tools/enemy_refactor/logs/warlord_shared_attack_scheduler_probe.log` | PASS capacité, FIFO, expiration et générations de leases; scheduler synthétique |
| `.tmp_tools/enemy_refactor/logs/warlord_shared_crowd_tactics_probe.log` | PASS anneau de contact, réserves, budget d'attaque et expulsion |
| `.tmp_tools/enemy_refactor/logs/warlord_shared_enemy_faction_targeting_probe.log` | PASS groupes, précédence de cibles, claims, représailles et friendly fire |
| `.tmp_tools/enemy_refactor/logs/warlord_shared_enemy_transient_lifecycle_probe.log` | PASS ressources partagées, TTL borné, retrait collision/ombres |
| `.tmp_tools/enemy_refactor/logs/warlord_route_battle_enemy_spawn_probe.log` | PASS helpers hostile/spartiate partagés; fixtures non-warlord |
| `.tmp_tools/enemy_refactor/logs/forge_full_roster_visual_clean.log` | PASS vraie route Forge : `context=forge ids=22`, renderer Compatibility |
| `docs/enemy_refactor/forge_full_roster_visual_probe.png` | capture Forge `1600 x 900` inspectée; 22 acteurs visibles, pas de T-pose observée |
| `docs/enemy_refactor/visual_evidence/warlord.png` | image `1351 x 760` inspectée directement en résolution originale |
| `.tmp_tools/enemy_refactor/logs/visual_warlord.log` | capture Compatibility PASS existante; six acteurs indépendants |

Le message Windows headless `Failed to read the root certificate store` précède les résultats de nombreux probes. Il n'est lié à aucun accès TLS de ces tests et n'en change pas les codes de sortie. `world_editor_flow_probe` journalise aussi les erreurs de sauvegarde de préférences audio dans le sandbox; sa gate finit néanmoins par `WORLD_EDITOR_FLOW_OK`.

## Construction, profil et routes réelles

### Source de vérité et factory

- `scripts/enemy/enemy_archetypes.gd:315` contient l'unique entrée `warlord`. `profile()` renvoie une copie profonde normalisée; `data()` expose une vue typée mise en cache. Il n'existe pas de seconde définition contradictoire de stats ou de comportement.
- `scripts/enemy/enemy_factory.gd:48-85` est le seul `EnemyScript.new()` runtime. La factory injecte avant `_ready()` l'ID, la position, les deux références de cible, la faction, le mode de masse, le registre optionnel et les overrides de compatibilité.
- `_ready()` applique le profil avant collider, mannequin, anatomie, navigation et groupes (`scripts/enemy/athenian_enemy.gd:316-361`). Le full roster confirme aussi `procedural_archetype=warlord`, la santé initiale, le rig, l'équipement et le teardown.
- Le registre de roster historique affiche `pattern=3/2 donors=5 package=bossmonster2.glb`. Le mot `donors` y compte cinq clés externes déclarées, pas des donneurs instanciés sur la route Mixamo directe; cette ambiguïté est documentée plus bas.

### Profil normalisé effectif

| Champ | Valeur |
|---|---:|
| nom / skin | `WARLORD` / `warlord` |
| rang | `boss` |
| couleur fallback | `Color(0.58, 0.045, 0.018)` |
| échelle racine | `1.34` |
| santé | `980` |
| vitesse phase 1 | `4.85 m/s` |
| dégâts phase 1 | `46` |
| portée / aggro | `2.48 m` / `28 m` |
| arme / échelle | `axe` / `1.34` |
| bouclier / échelle | oui / `1.28` |
| défense normalisée | `shield`, chance `0.30`, fenêtre `0.68 s`, cooldown `1.55 s` |
| garde | `78`, régénération `18/s` après `1.30 s` |
| comportement / style | `boss` / `captain` |
| défaut wind-up / recovery | `0.34 s` / `0.36 s` |
| défaut cooldown | `0.96–1.24 s` |
| bande préférée | `0–2.30 m` |
| phase 2 | à `55 %`, vitesse ×`1.12`, dégâts ×`1.18` |

À l'entrée en phase 2, les valeurs deviennent `5.432 m/s`, `54.28` dégâts de base et `1.232` de vitesse d'animation; les cooldowns par défaut deviennent environ `0.857–1.107 s`. Le pattern propre à chaque action conserve ensuite ses propres cooldowns.

### Routes Lab / Forge / Battle réellement liées

- **Battle 01 : réelle.** `_spawn_final_encounter()` instancie un `warlord` par le helper typé puis la factory, entouré de six gardes (`scripts/battle/battle_01.gd:465-482`). Le boss et les gardes alimentent le compteur de fin.
- **Battle 02 : réelle.** `_spawn_final_encounter()` instancie aussi un `warlord`, entouré de cinq ou huit gardes selon la quête (`scripts/battle/battle_02.gd:260-273`). La quête `slay_warlord` est activée puis complétée sur la rencontre. Le manifest qui ne mentionne que Battle 01 est donc obsolète.
- **Forge : réelle et rendue.** La bibliothèque parcourt `EnemyArchetypes.all_ids()` et crée un bouton Warlord; le runtime Forge appelle `EnemyFactory.spawn()` pour l'aperçu et le jeu (`scripts/world_editor/world_editor.gd:882-887`; `scripts/world_editor/world_runtime.gd:293-329`, `:357-383`). Le probe visuel construit un document Forge avec 22 `enemy_group`, passe par `HopliteWorldRuntime.build()`, retrouve exactement une unité par groupe puis capture le renderer Compatibility. Résultat `context=forge ids=22`; le warlord est présent avec squelette et anatomie `12/12`, sans T-pose visible. Ce probe valide construction et rendu, pas un combat/mort Forge complet.
- **Combat Lab principal : non applicable.** `scripts/main.gd:489-501` ne contient que huit zones du roster de remplacement; aucun `warlord` n'est instancié par le Lab actuel. La capture synthétique `enemy_unit_visual_evidence.gd` n'est pas une route Lab de gameplay.
- **Procédural : non applicable.** `warlord` n'appartient pas à `ROSTER_IDS`; `procedural_catalog()` ne peut donc pas le choisir.

## Faction, cible, activation, mort et nettoyage

- La faction hostile par défaut ajoute `enemy`, `athenian`, `damageable`, `combatant`, `combatant_ai`, `enemy_ai`, `enemy_miniboss` et `enemy_epic`. La factory sait techniquement construire une faction spartiate, mais aucune route Warlord spartiate n'est déclarée.
- `battle_player` reste la référence humaine stable et `ai_player` la cible immédiate. La sélection commune privilégie représailles valides, joueur local puis adversaires de faction, avec distance, pénalité de claims et hystérésis de cible courante. Changement et perte de cible passent par `_set_combat_target()` et libèrent le claim précédent.
- En tant que boss, le warlord combat dans les `28 m` ou tant que l'alerte est active; sinon il revient à `ai_home_position` et reste en `boss_idle`. Les Battles ne l'activent qu'à la rencontre finale. La Forge peut ajouter ses propres conditions de spawn/patrouille via le groupe.
- `set_ai_participation(false)` libère lease et cible, annule le wind-up, arrête la translation, vide les caches, efface la destination, retire les groupes IA et rafraîchit le registre. Le probe de parité et le mixed stress valident ce contrat partagé.
- `_die()` effectue maintenant une sortie atomique : lease et cible sont libérés avant `dead=true`, puis `set_ai_participation(false)` retire immédiatement l'acteur des vues IA. Santé, vitesse, attaque, couches/masques, capsule, colliders adaptés, anatomie et physique IA sont ensuite désactivés; axe et bouclier sont lâchés; le driver/tree est arrêté; une mort importée ou le collapse déterministe est joué.
- Les quatre modèles BossMonster observés n'exposent pas une preuve d'un clip `Death01` exploitable sur la route de capture; la planche montre le fallback de collapse au sol. Le corpse devient render-only après son settle, mais n'a pas de TTL local. Sa suppression dépend du cleanup d'encounter/scène.
- Axe/bouclier détachés : `4 s` physiques puis collision/ombres coupées, libération à `12 s`. Membres proxies : `4 s` physiques, libération à `14 s`. Le lifecycle partagé est vert; le benchmark confirme zéro référence ennemie vivante après teardown, sans prouver l'absence de toute ressource mise en cache.

## Décision, FSM, rôles, solo/groupe, leases et phases

### Autorité d'état actuelle

Il n'existe pas de nouvelle FSM objet autoritaire. La priorité reste l'if-chain du contrôleur partagé : `guard break -> recovery -> wind-up -> parry counter -> tactique`. `ai_state` est une façade diagnostique (`boss_idle`, `boss_attack`, `attack_windup`, `attack_recover`, `pressure_wait`, `shield_guard`, `guard_broken`, `disarmed`, `phase_2`, `dead`, etc.). Le probe d'action transversal est vert, mais il ne remplace pas un scénario exact Warlord.

### Pattern phase 1

| Étape | Clip direct | Wind-up | Recovery | Cooldown | Dégâts / portée | Mouvement / arc |
|---|---|---:|---:|---:|---:|---|
| `war_sweep` | `mutant_swipe` | `0.40 s` | `0.42 s` | `0.82 s` | ×`1.02` / ×`1.16` | arc large `dot >= -0.25` |
| `execution` | `axe_down` | `0.58 s` | `0.54 s` | `1.18 s` | ×`1.46` / ×`1.10` | frontal |
| `shield_rush` | `axe_combo` | `0.34 s` | `0.30 s` | `0.72 s` | ×`0.92` / portée standard | lunge `6.4 m/s` |

### Pattern phase 2

| Étape | Clip direct | Wind-up | Recovery | Cooldown | Dégâts / portée | Mouvement / arc |
|---|---|---:|---:|---:|---:|---|
| `rage_sweep` | `mutant_swipe` | `0.30 s` | `0.32 s` | `0.52 s` | ×`1.12` / ×`1.22` | arc `dot >= -0.45` |
| `rage_combo` | `axe_combo` | `0.36 s` | `0.34 s` | `0.58 s` | ×`1.26` / portée standard | lunge `5.6 m/s` |

- Le seuil `539 PV` (`55 %`) annule proprement le wind-up courant, vide l'action, remet le curseur au début du pattern de rage, rafraîchit l'alerte et émet `combat_phase_changed`. Le probe transversal vérifie la sélection d'un pattern de phase, mais pas les multiplicateurs/timings exacts du warlord.
- `_begin_ai_attack()` revalide cible et anatomie, obtient un lease générationnel, ferme la garde, immobilise le corps durant l'ouverture, émet `attack_started` puis synchronise le clip à wind-up + recovery. L'opener exact `war_sweep` est prouvé.
- `_resolve_ai_attack()` revalide lease, arme/bras droit, cible, portée effective et arc avant de faire les dégâts. Une cible trop proche reste attaquable (`preferred_min=0`); une cible trop loin produit un near-miss borné ou un retour à la poursuite, sans état infini.
- La garde physique est frontale, désactivée hors fenêtre et dotée de stamina/guard break. La perte du bras gauche lâche le bouclier; la perte du bras droit lâche l'axe, annule le coup et interdit les attaques suivantes. Une jambe perdue plafonne à `1.85 m/s`; deux jambes à `0.72 m/s`, raccourcissent le collider et abaissent/inclinent le visuel.
- En solo sans directeur, la permission est immédiate. En groupe, le directeur attribue un anneau/slot et un lease FIFO borné à la capacité de la cible. Expiration/génération obsolète annulent le coup; mort, target switch, hold et sortie d'arbre libèrent immédiatement; guard break, désarmement et phase annulent puis la boucle libère au tick suivant si le lease reste détenu.
- La matrice exacte fixe successivement les quatre modèles et parcourt sans répétition ni omission le pattern phase 1 de trois actions de chaque instance. Le benchmark actif à 12 exerce simultanément le contrôleur et le registre, et les probes scheduler/crowd valident les invariants partagés. Ils ne déroulent toutefois pas automatiquement le pattern phase 2 de deux actions, les timings de hit exacts ni l'équité statistique entre douze warlords.

## Navigation, mouvement, blocage et récupération

- Mode exact : `HopliteEnemyNavigationComponent.Mode.DIRECT_STEERING`. Avec une échelle `1.34`, le warlord reste sous le seuil `1.75` du mode `LARGE_BODY`; aucun `NavigationAgent3D` n'est créé.
- Le contrôleur est l'unique propriétaire de `velocity`, de la rotation physique et de `move_and_slide()`. La destination tactique est recalculée à `0.045/0.085 s` hors masse et `0.055/0.10/0.18 s` en masse selon la distance; le composant ne considère un changement sémantique qu'après `3 m`, ce qui évite de réinitialiser le watchdog à chaque petit déplacement de cible.
- Paramètres exacts : arrivée `0.28 m`, progrès minimum `0.12 m/s`, blocage `0.82 s`, récupération latérale `0.48 s` à `72 %`, trois tentatives maximum puis `navigation_failed(recovery_exhausted)`.
- Le correctif de clé est présent et prouvé : l'appelant fournit `minimum_progress_speed` et `notify_motion_applied()` lit exactement cette clé. Le probe couvre progression lente, destination mouvante, blocage, récupération et échec borné.
- Gravité `24 m/s²` conservée séparément de la vitesse plane; la vitesse normale reste `4.85 m/s` sauf phase ou blessure. L'arrivée remet une intention invalide et laisse le contrôleur freiner; la séparation locale évite les collisions allié/allié.
- Patrouille/retour sont disponibles pour la Forge via `configure_demo_patrol()` et la route de groupe; le probe partagé de patrouille est vert. Les Battles finales utilisent poursuite/retour au home plutôt qu'une patrouille Warlord.
- Limite importante : `DIRECT_STEERING` ne calcule aucun détour topologique. Sa récupération latérale traite un coincement local, pas un obstacle complexe, un couloir dont la largeur approche le diamètre du boss, ni un labyrinthe. Le probe navmesh vert ne doit pas être attribué au warlord.
- Aucun scénario exact ne combine encore passage étroit, obstacle, retour au poste et reprise du mouvement avec chacun des quatre BossMonster. Le sommeil/réveil d'animation direct, lui, est désormais couvert par la gate LOD verte.

## Rig, pool, donneurs, clips, action partielle et LOD

### Route runtime directe

- Pool normal et de groupe : `bossmonster4`, `bossmonster3`, `bossmonster1`, `bossmonster2`. Aucun `MASS_MODEL_POOLS[warlord]` n'existe; même le benchmark à 12 peut donc charger les quatre corps.
- Une instance conserve un seul `Skeleton3D`, un seul `Skin` et un `AnimationPlayer` principal issus de son GLB. Il n'y a ni `AnimationTree`, ni retargeter, ni pose bridge persistant sur cette route.
- `install_personality()` charge un FBX source à sa première utilisation, duplique l'`Animation`, libère aussitôt le nœud source, puis conserve la ressource dans un cache statique. Il y a donc **zéro donneur instancié persistant** par warlord.
- Les cinq `external_animation_keys` sont un catalogue de compatibilité pour une route retarget non sélectionnée. Les appeler `donors=5` dans `enemy_roster_audit` est trompeur pour le coût runtime direct.
- Bibliothèque directe : idle `axe_block_idle`, locomotion `run`, réaction `hit_react`, taunt `mutant_roar`, attaques `mutant_swipe`, `axe_down`, `greatsword_jump`, `axe_combo`, `vertical_sword`, soit neuf clips demandés. Les patterns boss actuels consomment trois de ces cinq attaques; les autres restent des fallbacks du pool.
- Les pistes de translation des hips sont supprimées; le `CharacterBody3D` garde l'autorité de locomotion. Les actions sont corps entier : aucune couche partielle, aucun filtre d'os, aucun masque haut/bas à valider.
- La matrice exacte prouve pour les quatre rigs : sélection forcée, squelette peuplé, bibliothèque non vide, anatomie `12/12`, équipement détachable et refus des overrides cross-pool. Aucun donneur ni source n'a été supprimé; une suppression future resterait conditionnée à une matrice clip par clip et à une validation rendue équivalente.

### Inventaire source GLB

| Modèle | Taille | Nœuds | Meshes / surfaces | Triangles LOD0 source | Skins / joints | Animations | Matériaux / textures |
|---|---:|---:|---:|---:|---:|---:|---:|
| `bossmonster1.glb` | `1 629 328 o` | 83 | `1 / 1` | `12 626` | `1 / 81` | 1 | `1 / 2` |
| `bossmonster2.glb` | `1 555 676 o` | 66 | `1 / 1` | `13 910` | `1 / 64` | 1 | `1 / 3` |
| `bossmonster3.glb` | `2 031 204 o` | 68 | `1 / 1` | `9 620` | `1 / 66` | 1 | `1 / 2` |
| `bossmonster4.glb` | `1 467 224 o` | 98 | `24 / 24` | `11 146` | `1 / 72` | 1 | `1 / 1` |

Ces compteurs viennent des chunks JSON glTF. Les rigs diffèrent de `64` à `81` joints et `bossmonster4` est segmenté en 24 surfaces quand les trois autres sont monoblocs. La compatibilité de Skin ou la possibilité d'une bibliothèque rig canonique ne peut pas être déduite de leur silhouette. Les imports activent tangentes, génération de LOD, shadow meshes, animation à `30 FPS` et suppression des pistes immuables.

### Sommeil LOD et réveil

- LOD rendu par défaut : proche `16 m`, lointain `38 m`, cull `90 m`; `lod_bias`, visibilité, ombres et particules sont adaptés. Les ombres sont désactivées en mode masse.
- Pour l'`AnimationPlayer` direct, LOD1/LOD2 passent en callback manuel aux cadences `30/12 Hz`; LOD3 arrête l'avance; le retour LOD0 restaure le callback idle et force `advance(0.0)`.
- Le flake initial venait du probe : son premier `_process()` manuel pouvait aussi déclencher la politique de distance sans caméra de bataille et remplacer le LOD2 forcé par LOD3 selon le nombre de frames consommées par le chargement. Le probe isole maintenant l'horloge avec `performance_lod_timer=999.0`.
- Le runtime tolère l'arrondi flottant (`+ 0.000001`) et conserve le reliquat par `fmod()` au lieu de remettre toute la réserve à zéro. Dix processus frais consécutifs passent la cadence shared/native/direct et le réveil réversible; aucune panne locale n'a été reproduite.

## Meshes, matériaux, équipement et rendu

- Les variantes 1/2/3 présentent un corps monobloc à une surface; `bossmonster4` présente 24 meshes/surfaces. Le warlord ajoute normalement une axe procédurale de trois meshes/surfaces et un bouclier de deux meshes/surfaces.
- Selon le modèle, l'acteur visible représente donc environ 6 surfaces ou 29 surfaces avant effets/debug. Les quatre matériaux procéduraux d'équipement (bois, acier, bronze de l'axe, bronze du bouclier) sont recréés par instance; ils empêchent le partage/batching inter-warlords.
- Le fallback `_build_armor_skin()` contient bien une tenue `warlord` (cuirasse fer, casque cornu, grandes épaulières, grèves, jupe et ceinture), mais il n'est appelé que sur la route UAL1 non-Mixamo. La route hostile effective conserve le costume BossMonster et n'ajoute que l'équipement procédural.
- Le pool recouvre entièrement les trois modèles du `brute` et ajoute seulement `bossmonster4`; identité et hiérarchie sont surtout portées par l'échelle `1.34`, le bouclier, le pattern et les stats. La matrice fixe et valide désormais chaque variante séparément, mais Battle/Forge continuent légitimement à sélectionner des silhouettes différentes sous le même ID.
- Les LOD d'import sont présents, le culling runtime est actif et le renderer Compatibility est explicitement supporté par la capture. Aucun chiffre de draw calls ou VRAM rendu n'a été obtenu en headless.
- Aucune fusion de mesh n'a été tentée. Fusionner `bossmonster4` ou substituer un modèle plus léger sans préserver Skin, matériaux, zones anatomiques et section serait contraire au protocole.

## Anatomie, 12 zones, démembrement et équipement

Le probe exact instancie un warlord distinct pour chaque zone, applique un coup de section massif, vérifie état/fatalité, création d'un proxy ou équipement détaché, puis nettoie la fixture. Résultat : douze zones présentes, dix entrées sectionnables. La matrice de variantes répète en plus les douze zones sur chacun des quatre BossMonster : `48/48` cas traités conformément au profil, axe/bouclier lâchés sur les côtés attendus.

| Zone | Forme / rayon local | Dégâts / section | Seuil | Conséquence logique et équipement |
|---|---|---:|---:|---|
| `head` | sphère `0.25` | ×`1.70` / ×`1.00` | 64 | tête détachée, fatal |
| `neck` | capsule `0.15` | ×`1.85` / ×`1.35` | 56 | redirige vers `head`, fatal |
| `torso` | capsule `0.34` | ×`1.00` / ×`0.35` | 9999 | non sectionnable |
| `pelvis` | capsule `0.30` | ×`0.95` / ×`0.30` | 9999 | non sectionnable |
| `upper_arm_l` | capsule `0.16` | ×`0.78` / ×`1.00` | 78 | bras + avant-bras neutralisés, bouclier lâché |
| `forearm_l` | capsule `0.14` | ×`0.75` / ×`1.10` | 60 | bouclier lâché |
| `upper_arm_r` | capsule `0.16` | ×`0.78` / ×`1.00` | 78 | bras + avant-bras neutralisés, axe lâchée, attaque impossible |
| `forearm_r` | capsule `0.14` | ×`0.75` / ×`1.10` | 60 | axe lâchée, attaque impossible |
| `thigh_l` | capsule `0.21` | ×`0.88` / ×`0.82` | 94 | cuisse + tibia neutralisés, boiterie |
| `shin_l` | capsule `0.18` | ×`0.84` / ×`1.05` | 72 | boiterie; deux jambes = crawl |
| `thigh_r` | capsule `0.21` | ×`0.88` / ×`0.82` | 94 | cuisse + tibia neutralisés, boiterie |
| `shin_r` | capsule `0.18` | ×`0.84` / ×`1.05` | 72 | boiterie; deux jambes = crawl |

- La chaîne de bones de la zone sectionnée est réduite à `0.001`. Le membre détaché est un proxy sphère/capsule avec cap de coupe rouge sombre partagé, pas la géométrie skinnée originale.
- Les matériaux et meshes de proxies sont mis en cache. Le proxy et les équipements détachés utilisent `RigidBody3D`, primitives, impulsion bornée, sommeil autorisé et lifecycle partagé.
- Les preuves exactes valident la perte axe/bouclier et la fatalité tête/cou sur le probe individuel, puis la sectionnabilité et le détachement d'équipement sur les quatre variantes. Elles ne mesurent pas le temps CPU répété de section, ne comparent pas visuellement les douze zones et ne vérifient pas une géométrie de membre originale, puisque le contrat actuel utilise des proxies.

## Physique

- Corps principal : `CharacterBody3D`, couche 4, masque monde + joueur lorsque l'IA est active; pas de collision ennemi/ennemi puisque la séparation assure l'espacement.
- Collider principal : capsule primitive locale rayon `0.39`, hauteur `1.82`; aucun concave sur corps mobile. À échelle Warlord `1.34`, le volume monde est agrandi par la scale racine.
- Anatomie : une `Area3D` couche 8, masque 0, douze `CollisionShape3D` primitives. Le code annule la scale de transformation lors du suivi des bones puis applique explicitement le rayon monde.
- Bouclier : `Area3D` et cylindre local rayon `0.48`, hauteur `0.13`, couche 8 uniquement pendant la garde. Le bouclier visuel/physique hérite de `shield_scale=1.28` et de la racine `1.34`.
- Débris : couche 16, masque monde 1, sommeil activé; axe = box, bouclier = cylindre, membres = sphère/capsule. Interpolation physique du projet n'est pas démontrée par un probe Warlord; aucun teleport propre à ce boss n'est appliqué après placement initial.
- Dette partagée : le `CharacterBody3D` et des parents d'équipement portent des scales, contrairement à la préférence de dimensionner les shapes elles-mêmes. Plus grave pour l'arbitrage, `HopliteShieldHitbox.zone_radius_from_shape_index()` retourne toujours `0.48`, sans convertir la scale monde : le rayon logique communiqué au joueur est inférieur au rayon physique/visuel réel du warlord. Aucun test exact ne compare bord visuel, cylindre physique et rayon d'arbitrage à `1.34 × 1.28`.

## Performance — état courant, sans revendication de gain

Commande exécutée :

```powershell
& 'C:\Users\suean\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tools/enemy_performance_benchmark.gd -- --counts=1,12 --mode=both --warmup=30 --frames=60 --archetype=warlord --registry=on --seed=13371
```

| Mode | Unités | Spawn ms | Nœuds | Objets | Ressources | Mémoire statique | Corps actifs | Tick p95 / max | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 1 | `255.042` | 39 | 1 638 | 54 | 68.5 MB | 0 | `20.713 / 20.954 ms` | PASS |
| idle | 12 | `691.125` | 487 | 2 422 | 98 | 149.0 MB | 0 | `20.717 / 20.832 ms` | PASS |
| actif | 1 | `261.027` | 40 | 1 641 | 54 | 68.7 MB | 1 | `20.707 / 20.734 ms` | PASS |
| actif | 12 | `611.654` | 547 | 2 486 | 91 | 115.4 MB | 12 | `20.705 / 20.720 ms` | PASS |

Interprétation honnête :

- `12` warlords est un stress artificiel; Battle 01/02 n'en instancient qu'un, entouré de gardes d'autres archétypes.
- Les ticks sont cadencés à 60 Hz et reflètent ordonnanceur + attente; ils ne mesurent pas le temps CPU propre du contrôleur. Les snapshots `process/physics/FPS` sont à rafraîchissement lent et ne sont pas utilisés comme gate.
- Les différences mémoire idle/actif et ressources viennent aussi de l'ordre de scénarios et des caches Mixamo; elles ne constituent pas une comparaison de fuite ni un gain.
- La baseline de mission utilise le swordsman/default, `120` frames de warm-up/sample et des comptes `1/5/15/28/36`; elle n'est pas une baseline Warlord comparable. Aucun avant/après Warlord n'existe, donc aucun pourcentage d'amélioration n'est revendiqué.
- Les compteurs structurels confirment un squelette et un lecteur par unité, zéro arbre/donneur persistant, douze hitboxes anatomiques, capsule, bouclier et équipement. Le coût varie fortement selon que le pool choisit le corps monobloc ou `bossmonster4` à 24 surfaces.
- Draw calls, triangles réellement rendus après LOD, VRAM, coût GPU, matériaux effectivement batchés, temps de mort en masse et temps de démembrement répété ne sont pas mesurés.

## Preuves visuelles inspectées

Fichier : `docs/enemy_refactor/visual_evidence/warlord.png` (`1351 x 760`, inspection directe en résolution originale).

- `IDLE NU` montre un BossMonster clair au sol, sans pose en T; `JOG NU` montre une autre silhouette et une pose de locomotion distincte.
- `ATTAQUE` montre un mouvement engagé et l'axe; `MORT` montre le corps allongé, avec axe et bouclier séparés; `SECTION` montre perte du bras droit, sang et proxy/équipement détaché.
- Les six acteurs sont des instances indépendantes et le pool n'est pas fixé. La planche ne prouve donc ni continuité d'un rig à travers les six états, ni lecture de chacun des quatre modèles.
- Les grands boucliers recouvrent fortement `JOG`, `ATTAQUE` et `IMPACT`; les mains, l'axe et la réaction sont partiellement masquées. Le proxy de `SECTION` déborde du bord droit.
- La taille monstrueuse, les cornes/pointes, l'axe et le bouclier donnent une identité de boss lisible, mais les trois modèles partagés avec `brute` empêchent d'attribuer cette identité au seul ID sans variante fixée.
- La planche n'est ni une capture Battle 01/02, ni une capture Forge; elle ne prouve pas garde, phase 2, retour, obstacle, sommeil/réveil, passage étroit, rotation ou les cinq actions.

Fichier Forge : `docs/enemy_refactor/forge_full_roster_visual_probe.png` (`1600 x 900`, inspection directe en résolution originale).

- La capture provient d'un document Forge construit par `HopliteWorldRuntime`, pas d'une grille qui appelle directement la factory. Les 22 groupes demandés sont confirmés dans le log, avec un acteur visible par ID.
- La scène Compatibility montre les 22 silhouettes posées sur le sol et animées en idle; aucune T-pose n'est visible. Le warlord figure dans la rangée arrière parmi les grands profils.
- La vue d'ensemble est volontairement distante : elle prouve présence, skinning global et absence de pose cassée, mais pas les détails du visage, la garde, le combat, la mort ou le teardown du warlord dans la Forge.

## Tests exécutés

| Test | Résultat | Qualification |
|---|---|---|
| `enemy_unit_dismemberment_probe.gd -- --id=warlord` | PASS `12/10` | exact zones, fatalités, détachement, équipement, cleanup fixture |
| `enemy_full_roster_validation_probe.gd` | PASS `22/22` | identité/rig/anatomie/équipement/action/navigation/teardown, ligne exacte Warlord |
| `enemy_animation_probe.gd` | PASS | opener exact Warlord; pas les quatre autres actions |
| `enemy_animation_lod_probe.gd` | PASS `10/10` | shared/native/direct, cadence LOD2, sommeil LOD3, réveil LOD0; politique de distance isolée |
| `enemy_mixamo_variant_matrix_probe.gd -- --id=warlord` | PASS `4 variantes / 48 zones` | quatre rigs forcés, équipement détachable, pattern courant complet, rejet cross-pool |
| `enemy_archetype_data_probe.gd` | PASS | 22 vues typées égales aux profils normalisés |
| `enemy_factory_route_probe.gd` | PASS | toutes les constructions runtime passent par la factory |
| `enemy_factory_options_probe.gd` | PASS | contrat d'options et promotion legacy |
| `enemy_factory_registry_probe.gd` | PASS | enregistrement post-ready explicite et lifecycle |
| `enemy_combatant_registry_probe.gd` | PASS | filtres, ordre, liveness et weak teardown |
| `enemy_registry_crowd_parity_probe.gd` | PASS | participation atomique registre/groupes |
| `enemy_mixed_stress_probe.gd` | PASS | stress 36 unités, changement cible, wake, sections, morts, cleanup |
| `enemy_anatomy_regression_probe.gd` | PASS | mort toujours finalisée après section létale |
| `enemy_faction_targeting_probe.gd` | PASS | groupes, claims, représailles et friendly fire |
| `enemy_action_state_probe.gd` | PASS | priorité d'action partagée |
| `enemy_combat_probe.gd` | PASS | garde/guard break/parade/pattern de phase synthétique |
| `attack_scheduler_probe.gd` | PASS | capacité/FIFO/expiration/générations |
| `crowd_tactics_probe.gd` | PASS | anneaux/réserves/budget/expulsion |
| `enemy_navigation_component_probe.gd` | PASS | clé minimum, arrivée, fallback, blocage/récupération |
| `enemy_navigation_navmesh_probe.gd` | PASS | composant navmesh partagé, non applicable au warlord direct |
| `enemy_patrol_probe.gd` | PASS | contrat patrouille partagé, non ciblé Warlord |
| `enemy_transient_lifecycle_probe.gd` | PASS | débris/TTL/ombres/collisions |
| `battle_enemy_spawn_probe.gd` | PASS | helpers Battle partagés, fixtures non-warlord |
| `enemy_lab_forge_full_roster_visual_probe.gd -- --context=forge` | PASS `22/22` | vraie construction `WorldRuntime`, squelette/anatomie de chaque ID, capture Compatibility inspectée |
| `world_editor_flow_probe.gd` | PASS | flux d'édition Forge partagé |
| benchmark `1/12`, idle/actif | PASS | structure/spawn/ticks cadencés/teardown, pas CPU/GPU avant-après |

## Dettes partagées et suites non bloquantes

Le statut `DONE` signifie qu'aucune panne locale reproductible ne subsiste dans les gates requises. Les points suivants restent des améliorations ou des preuves plus profondes; ils ne doivent pas être interprétés comme des résultats déjà acquis.

1. **Rayon de bouclier non converti en monde.** `ShieldHitbox.zone_radius_from_shape_index()` renvoie `0.48` même sous les scales racine/équipement; l'arbitrage joueur peut diverger du cylindre réel. Corriger ou qualifier ce contrat, puis tester le bord à `1.34 × 1.28` et avec un `size_multiplier` Forge.
2. **Scales sur corps/volumes physiques.** La racine `CharacterBody3D` et le bouclier sont scalés. Les probes passent, mais dimensionner directement les primitives réduirait l'ambiguïté des variantes Forge.
3. **Libellé de donneurs trompeur.** `enemy_roster_audit` affiche `donors=5` pour un direct Mixamo qui ne conserve aucun donneur runtime; il compte des clés potentielles.
4. **Manifest de route obsolète.** `roster_manifest.json` ne déclare que `battle_01`, alors que Battle 02 instancie explicitement un warlord final.
5. **Preuve visuelle d'action multi-instance.** La planche dédiée compare six instances potentiellement différentes, pas six états du même rig. La matrice fonctionnelle fixe bien les quatre modèles, mais une planche rendue par variante et clip améliorerait la lecture visuelle.
6. **Matériaux d'équipement par instance.** Axe et bouclier reconstruisent quatre matériaux, ce qui fragmente le batching; `bossmonster4` ajoute déjà 24 surfaces.
7. **Cadavres sans TTL local.** Le corpse est retiré du runtime actif mais persiste visuellement jusqu'au cleanup d'encounter/scène. Tester la politique des rencontres finales sous morts répétées reste utile.
8. **Couverture boss approfondie.** Ajouter un probe exact qui force `539 PV`, déroule aussi `rage_sweep -> rage_combo`, mesure timings/dégâts/portée/arc et combine garde, blessures, changements de cible et leases en solo/groupe. La matrice actuelle prouve le pattern courant phase 1, pas toute cette combinatoire.
9. **Navigation volumétrique.** Ajouter un scénario exact `DIRECT_STEERING` avec obstacle local, passage étroit dimensionné, trois récupérations/échec, retour au home et patrouille Forge; le probe navmesh reste non applicable au warlord.
10. **Routes Battle rendues.** Déclencher et capturer les rencontres finales Battle 01 et 02 avec combat, mort et teardown. La liaison de code est réelle, mais la preuve actuelle n'est pas une session Battle rendue.
11. **Métriques rendues et avant/après.** Mesurer avec commandes identiques CPU attribuable, draw calls, VRAM, mort en masse et démembrement répété avant de revendiquer un gain. Le benchmark actuel est une photographie structurelle honnête.
12. **Identité du pool.** Décider explicitement si les quatre BossMonster partagés constituent l'identité voulue du Warlord. Toute consolidation future doit préserver Skins, matériaux, clips, LOD et démembrement; aucune source ou donneur ne doit être supprimé avant preuves équivalentes.

**Conclusion : DONE.** Les relances locales sont vertes, les quatre variantes et les 48 zones sont couvertes, la route Forge réelle est rendue, et les limites restantes sont consignées sans leur attribuer une preuve qu'elles n'ont pas.
