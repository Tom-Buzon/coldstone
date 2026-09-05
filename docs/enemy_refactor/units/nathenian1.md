# Audit final distinct — `nathenian1`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Le teardown, le TTL de cadavre et la stabilité de rechargement sont couverts par les gates autoritaires de `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable (`5b4e0cb0f`)**\
**Renderer des probes : `gl_compatibility`, headless**\
**Portée : état courant du worktree; runtime central, scènes, profils, packages et preuves visuelles inspectés strictement en lecture seule.**

## Verdict synthétique

`nathenian1` passe la factory, le profil typé, les routes réelles Lab/Forge, les routes Battle/procédurales, les contrats faction/cible/claims, l'activation, la mort atomique, le nettoyage, le steering direct, les LOD shared/native/direct, les ressources partagées, le rayon monde du bouclier, les douze zones anatomiques et les dix sections. Les probes frais passent notamment le comportement exact, le démembrement exact, le roster `22/22`, le stress mixte `22 familles / 36 unités`, la campagne procédurale, la navigation, les transients et le benchmark ciblé.

Le défaut initial d'attaque non-masse est corrigé et couvert par un probe exact. Lorsque pattern, signature UAL2, Mixamo et driver spécialisé sont indisponibles, `_begin_ai_attack()` reconnaît désormais le package authored léger et réutilise son donneur UAL1 déjà chargé. `enemy_package_attack_fallback_probe.gd -- --id=nathenian1` prouve sur le package réel, avec `mass_battle_mode=false` et sans driver lourd, que `Sword_Attack` est sélectionné, réellement joué en one-shot, protégé par un verrou visuel, puis que résolution, sommeil/réveil et cleanup restent propres.

Le correctif couvre les routes réellement concernées : le groupe combiné du Combat Lab instancie deux `nathenian1` actifs avec la valeur par défaut non-masse (`scripts/main.gd:323-336`), et la Forge n'active le mode masse qu'à partir de 28 unités (`scripts/world_editor/world_runtime.gd:303-316`). Le probe comportement exact non-masse repasse également far/close, attaques, interruption, perte de cible, sommeil/réveil et cleanup. Il reste principalement mécanique, mais le nouveau probe dédié ferme explicitement son ancien angle mort animation.

Verdict final : **DONE**. Aucun autre défaut fonctionnel concret n'est reproduit. Les limites restantes sont honnêtement conservées au backlog : pointe à 56 actifs, absence de baseline historique strictement comparable, preuves visuelles globales trop distantes, géométrie source dense et limites topologiques du steering direct. Aucun donneur ne doit être supprimé sans preuve de remplacement : le package visible n'embarque aucune animation et UAL1 reste nécessaire à locomotion, attaque désormais masse comme non-masse, et mort.

## Profil canonique et identité

Source de vérité : `scripts/enemy/enemy_archetypes.gd:418-468`.

| Champ | Valeur |
|---|---:|
| nom / rang / famille | `NATHENIAN I` / `troop` / `nathenian` |
| rôle / skin / échelle | `light_shield_infantry` / `guardian` / `1.0` |
| PV / vitesse | `128` / `4.65 m/s` |
| dégâts / portée / aggro | `15` / `1.75 m` / `21 m` |
| arme / bouclier | épée `0.98` / aspis `1.0` |
| comportement / style | `guardian` / `disciplined` |
| windup / recovery | `0.28 s` / `0.31 s` |
| cooldown | `0.92–1.20 s` |
| vitesse d'animation | `1.10` |
| bande préférée | `0–1.68 m` |
| rayon tactique / séparation / approche | `1.85` / `1.35` / `0.80` |
| garde | chance `0.34`, durée `0.70`, cooldown `1.55`, dégâts ×`0.18`, section ×`0.12` |
| endurance garde / régénération | `86` / `21` |
| réaction / poise | `0.14 s` / `0.12` |
| signature | source `ual2`, `Shield_OneShot` ou `Sword_Regular_A`, chance `0.28` |
| procédural | coût `1.35`, poids `1.0`, vague initiale autorisée |
| package gagnant | `nathenian1-1787346222233.glb` |

Le profil n'a aucun `combat_pattern`; le roster le classe donc correctement `action=static`. Cette absence est licite pour un soldat simple. La branche package légère possède désormais le fallback générique visible requis lorsque la signature optionnelle ne peut pas jouer.

## Factory, cache et routes de contenu

`HopliteEnemyFactory.spawn_request()` est la route canonique. Il copie ID, position, participation IA, mode masse, faction, cible, `battle_player`, index de garde et options avant `add_child()`. `_ready()` applique alors le profil, construit corps/package/anatomie/équipement/navigation et rejoint les groupes. Les profils typés sont mis en cache comme données immuables; l'API dictionnaire legacy renvoie une copie profonde isolée. Les probes factory route/options/registry et archetype data/cache passent.

Routes vérifiées :

- **Combat Lab** : `scripts/main.gd` place `nathenian1` dans le showroom, le groupe combiné actif, l'annexe, les zones et patrouilles. Le groupe combiné de sept unités contient deux instances non-masse désormais couvertes par le fallback UAL1 validé.
- **Forge** : l'éditeur propose `nathenian1` par défaut; un document `enemy_group` est matérialisé par le vrai `HopliteWorldRuntime`, qui passe par la factory. Un groupe de moins de 28 reste non-masse et utilise le même fallback validé.
- **Battle 03 narratif** : plusieurs formations de 6, 12 et 20 unités utilisent explicitement l'ID. La route de bataille active le mode masse pour les soldats réguliers; `Sword_Attack` UAL1 est alors disponible.
- **Procédural** : le catalogue autorise l'unité dès la première vague; le directeur l'emploie dans les légions de murs, ville et donjon, généralement avec `mass=true`.
- **Preuve 22/22** : la capture Lab charge la vraie scène puis ajoute une annexe factory de validation; elle ne signifie pas que les 22 IDs sont tous des placements authored initiaux. La capture Forge construit les 22 groupes via un vrai document et le vrai runtime.

Le `procedural_enemy_spawn_probe` a lui aussi été aligné sur le contrat atomique puis relancé avec succès. Durant l'entrée élite, `set_ai_participation(false)` annule correctement `ai_player` tandis que `battle_player` reste stable; au réveil, la cible IA est restaurée. Le probe passe désormais les spawns factory ordinaires, miniboss et boss, dont les assertions exactes `nathenian1` sur ID, cible, route, faction/groupe campagne et `active_enemies`. `procedural_campaign_probe` passe également la campagne complète.

## Faction, cible, claims et activation

- Faction par défaut `athenian`; groupes hostiles `enemy`, `athenian`, `damageable`, `combatant` et groupes IA selon participation.
- Cible prioritaire : représailles valides, puis joueur de bataille dans l'aggro, puis candidat de faction opposée. La factory peut injecter une autre faction.
- `_set_combat_target()` est l'unique propriétaire du changement : le changement/perte de cible, le sommeil, la mort et la sortie d'arbre libèrent lease d'attaque et claim.
- `set_ai_participation(false)` retire l'autorité, annule la cible et les claims; le réveil rejoint les groupes et force un échantillon de simulation.
- Le probe exact passe décision loin/proche, attaque mécanique, interruption par désarmement sans dégâts, perte de cible, sommeil/réveil et cleanup. Le probe factions passe absence de friendly fire, représailles, précédence et nettoyage.

## Décision, combat et correction d'animation validée

Le contrôleur maintient la bande préférée, calcule intention/formation/séparation et demande une permission au scheduler borné avant windup. À la résolution il revérifie génération du lease, cible, portée, arc et capacité de frapper avant d'appliquer les dégâts. Les probes scheduler/action/combat et le stress mixte valident les contrats transversaux.

Chaîne exacte corrigée de `_begin_ai_attack()` (`scripts/enemy/athenian_enemy.gd:1626-1671`) :

1. `_play_pattern_attack()` échoue car le profil n'a pas de pattern;
2. `_play_signature_attack()` n'est tentée que dans 28 % des attaques; quand elle l'est, elle cherche `Shield_OneShot` ou `Sword_Regular_A`;
3. `nathenian1` générique n'a pas de driver natif spécialisé et son `AnimationPlayer` direct vient de UAL1; le catalogue frais montre que les deux clips demandés sont UAL2, donc aucun candidat ne joue;
4. la branche Mixamo est fausse (`package_retarget`), puis `ai_animation_driver` est nul;
5. la condition finale accepte désormais `mass_battle_mode OR uses_spartan_package_visual` et appelle le fallback direct déjà existant;
6. `_play_mass_attack_animation()` sélectionne `Sword_Attack` UAL1, impose `Animation.LOOP_NONE`, calcule un verrou visuel à partir de la durée et lance réellement le lecteur.

La capture GPU régénérée `nathenian1.png` montre désormais une pose de swing nettement distincte de l'idle et du jog, sans T-pose. Une colonne statique ne prouve toujours pas à elle seule lecture continue ou transition; le probe dédié complète donc la preuve en assertant simultanément `simple_anim_state == Sword_Attack`, `current_animation == Sword_Attack`, `is_playing()`, `LOOP_NONE` et un verrou positif sur l'instance non-masse réelle.

Revue du correctif : aucun driver, donneur ou ressource lourde supplémentaire n'est créé; la branche réutilise l'`AnimationPlayer` UAL1 du package léger et son fallback typé existant. Le one-shot ne peut pas être immédiatement écrasé par locomotion grâce à `simple_anim_lock_timer`. Le comportement exact repasse après la modification; aucune régression scheduler, interruption, cible ou lifecycle n'est observée.

## Navigation, foule et formation

Mode exact : `EnemyNavigationComponent.Mode.DIRECT_STEERING`; aucun `NavigationAgent3D` n'est alloué pour ce profil. Le contrôleur donne destination tactique, formation et séparation; le composant accélère puis le `CharacterBody3D` exécute `move_and_slide()`.

La récupération détecte un progrès insuffisant pendant `0.82 s`, applique une direction latérale bornée `0.48 s` à `72 %` de la vitesse puis reprend l'intention. Le probe composant passe intention, formation, fallback et recovery. Le probe navmesh passe vrai chemin, détour, retarget, arrivée et carte vide, mais exerce le mode `NAVMESH_GROUND` d'autres unités et ne constitue pas une preuve de pathfinding pour `nathenian1`.

Le steering direct ne promet pas un détour topologique autour d'un obstacle complexe : il ne fournit que séparation et récupération locales. C'est une limite de mode à conserver au backlog, pas une divergence propre à l'unité. La foule partagée rafraîchit la grille spatiale à 20 Hz et invalide immédiatement les changements de membres; le probe de cadence passe. Les intervalles de décision varient selon distance et mode masse afin de lisser les cohortes.

## Rig, package, donneurs et LOD

Audit statique de `assets/characters/3dgen_demo/nathenian1-1787346222233.glb` :

| Mesure | Valeur |
|---|---:|
| taille | 9 619 224 octets |
| format / générateur | glTF 2 / Blender glTF 5.2.39 |
| nœuds / skins / joints | 83 / 1 / 53 |
| meshes | 28 |
| triangles source | 21 628 |
| matériaux / textures | 2 / 1 PNG embarqué |
| animations locales | aucune |
| gore | 10 segments corporels, 18 caps |

L'adaptateur reconnaît `spartan_ual1_v1`, les 53 os, les zones et caps. Il instancie le package visible, un donneur caché `UAL1_Standard.glb`, désactive son rendu, puis copie sa pose via `AuthoredPoseBridge`. Pour cette troupe générique, aucun `HopliteNativeAnimationDriver` complet n'est construit. La locomotion, la mort et l'attaque de masse passent donc directement par UAL1.

Le package importe tangentes, shadow meshes et `meshes/generate_lods=true`. La branche générique conserve ses surfaces segmentées; `optimize_body_meshes()` est réservé à la branche package partagée de `ngeneral`. Les 21 628 triangles dépassent l'objectif indicatif de 12 k, mais le démembrement dépend de cette segmentation et aucun remplacement comparatif n'existe. Aucun mesh, package ou donneur ne peut être supprimé sur ce seul constat.

LOD partagé : seuils 16 / 38 / 90 m, biais `1.0 / 0.55 / 0.22`, ombres coupées après le proche ou en masse, particules coupées après LOD1. La route directe échantillonne LOD1 autour de 30 Hz, LOD2 autour de 12 Hz, gèle LOD3 et force un échantillon immédiat au réveil. `enemy_animation_lod_probe` passe shared/native/direct et réveil réversible. Le suivi anatomique est lui aussi décimé : `0.03 s` durant la frappe en masse, `0.045/0.065 s` proche, `0.12/0.20 s` loin, puis arrêté hors combat.

## Équipement, rendu et physique

Le package ne contient pas d'arme authored. Le runtime construit une épée procédurale sous `DEF-hand.R` à l'échelle `0.98` et un aspis procédural à gauche à l'échelle `1.0`. Les matériaux procéduraux d'arme et d'armure sont mis en cache par paramètres immuables; le probe de cache passe. Le rayon de requête combat du bouclier est `0.48 ×` l'échelle mondiale héritée et le probe dédié passe.

Corps principal : `CharacterBody3D`, capsule rayon `0.39`, hauteur `1.82`, centre y `0.91`, couche 4, masque monde + joueur, sans collision ennemi-ennemi. Les zones anatomiques sont des `Area3D` couche 8. Les membres et équipements lâchés deviennent des `RigidBody3D` couche 16, masque monde, sommeil autorisé; collision/ombres sont retirées après environ 4 s, libération vers 12 s. Le probe transient passe ressources partagées, TTL bornée et retrait collision/ombres.

L'aspis porte une rotation de nœud; conformément au risque physique documenté, sa requête utilise le rayon monde au lieu d'une mesure locale non transformée. Les probes ne mesurent pas passages étroits, marches, interpolation ni charge Jolt; ce sont des limites transversales de validation, pas une panne reproduite ici.

## Anatomie, section et mort atomique

| Zone | Forme | Dégâts | Section | Seuil | Effet |
|---|---|---:|---:|---:|---|
| `head` | sphère r=0.25 | ×1.70 | ×1.00 | 64 | fatal, tête |
| `neck` | capsule r=0.15 | ×1.85 | ×1.35 | 56 | redirige tête, fatal |
| `torso` | capsule r=0.34 | ×1.00 | ×0.35 | — | non sectionnable |
| `pelvis` | capsule r=0.30 | ×0.95 | ×0.30 | — | non sectionnable |
| `upper_arm_l/r` | capsule r=0.16 | ×0.78 | ×1.00 | 78 | descendant; droite lâche épée, gauche bouclier |
| `forearm_l/r` | capsule r=0.14 | ×0.75 | ×1.10 | 60 | droite lâche épée, gauche bouclier |
| `thigh_l/r` | capsule r=0.21 | ×0.88 | ×0.82 | 94 | tibia lié, boiterie |
| `shin_l/r` | capsule r=0.18 | ×0.84 | ×1.05 | 72 | boiterie; deux jambes = crawl |

Les douze zones sont présentes et dix sont sectionnables. La route package emploie les vrais meshes segmentés/caps et crée un `SpartanDetachedLimb`; le proxy n'est qu'un fallback d'échec. Le probe exact passe `zones=12 severed=10`; la régression anatomique passe aussi la finalisation fatale.

La mort est atomique : lease/claim/cible libérés, `dead=true`, IA retirée, PV et vitesse à zéro, attaque annulée, collisions corps/anatomie désactivées, physique active arrêtée, équipement lâché, driver arrêté, `Death01` UAL1 tenté puis cadavre allégé. Le contrôleur ne libère pas immédiatement le cadavre; le propriétaire de scène/rencontre assure la fin de vie. Stress, comportement et benchmark terminent avec zéro combattant, référence live et orphelin.

## Performance — mesure actuelle, pas de gain revendiqué

Commande fraîche :

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/enemy_performance_benchmark.gd -- --counts=1,12,56 --mode=both --warmup=120 --frames=120 --seed=13371 --archetype=nathenian1
```

Tous les scénarios du benchmark utilisent `mass_battle_mode=true`, registry désactivé, 60 ticks/s.

| Mode | Unités | Spawn ms | Nœuds | Objets | Mémoire statique | Corps actifs | Tick p95 / p99 / max | Teardown |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 1 | 149.529 | 90 | 1 773 | 62 192 341 o | 0 | 20.704 / 20.744 / 20.781 ms | PASS |
| idle | 12 | 334.133 | 1 014 | 2 939 | 69 145 339 o | 0 | 20.703 / 20.725 / 20.803 ms | PASS |
| idle | 56 | 963.089 | 4 710 | 7 603 | 96 455 599 o | 0 | 20.005 / 21.068 / 23.697 ms | PASS |
| actif | 1 | 203.400 | 91 | 1 776 | 63 903 745 o | 1 | 20.702 / 20.711 / 20.714 ms | PASS |
| actif | 12 | 333.798 | 1 026 | 2 964 | 70 549 519 o | 12 | 20.709 / 20.891 / 21.036 ms | PASS |
| actif | 56 | 963.323 | 4 766 | 7 716 | 95 875 263 o | 56 | **37.534 / 40.914 / 45.492 ms** | PASS structurel |

À 56 actifs homogènes, le p95 dépasse nettement le budget 16.67 ms. C'est une limite de performance mesurée à suivre, même si le harness conclut PASS parce que son gate porte surtout sur structure et cleanup. Aucune baseline historique strictement comparable `nathenian1` n'existe : les baselines phase 0 `swordsman`/`ngeneral` ont d'autres rigs et profils. Aucun pourcentage de gain ou régression n'est donc revendiqué. Le run headless ne mesure ni GPU, VRAM, draw calls, shaders ni qualité de LOD. Le benchmark est entièrement en mode masse et sa route d'attaque était déjà la même; le correctif non-masse n'ajoute aucun driver lourd. Une mesure future Lab/Forge non-masse reste utile, mais aucune régression nouvelle n'est indiquée par la structure du changement.

## Preuves visuelles inspectées

`docs/enemy_refactor/visual_evidence/nathenian1.png` (1 351 × 760) a été régénérée après le correctif et inspectée en résolution originale. Elle contient `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION` : silhouette bleu/argent lisible, épée/aspis présents dans les colonnes équipées, swing d'attaque ample nettement distinct de l'idle/jog, impact, corps horizontal et membre sectionné. Aucune T-pose grossière n'apparaît.

Limites observées : le bouclier masque fortement torse et bras dans l'impact; la planche est un instantané de six instances, pas une séquence, et ne prouve donc pas transition, scheduler, retour idle ou réveil. Le swing lui-même est désormais visuellement distinct et le probe exact confirme sa lecture. Le membre/proxy de section est projeté très loin à droite et les particules rouges finissent au bord inférieur : preuve technique valide, composition encore faible pour une preuve marketing. Il manque gros plans des mains, attaches, caps et frame de contact.

Les captures `lab_full_roster_visual_probe.png` et `forge_full_roster_visual_probe.png` (1 600 × 900) ont été inspectées en résolution originale. Elles montrent 22 unités dans le vrai contexte Lab et dans le vrai `WorldRuntime` Forge, mais l'échelle des personnages/labels est petite. Le Lab montre une annexe dans la scène réelle avec une zone basse surexposée; la Forge a un sol/fond très pâles. Elles prouvent présence, construction et absence de T-pose grossière, pas la qualité fine ni le comportement exact `22/22`.

## Tests exécutés

| Test | Résultat | Portée / réserve |
|---|---|---|
| `enemy_unit_dismemberment_probe.gd -- --id=nathenian1` | PASS, `zones=12 severed=10` | exact, package, fatalités, équipement, teardown |
| `enemy_full_roster_validation_probe.gd` | PASS `22/22` | ligne exacte `nathenian`, `package_retarget`, `12/12`, `sword+shield`, `static`, `DIRECT_STEERING` |
| `enemy_package_attack_fallback_probe.gd -- --id=nathenian1` | **PASS exact après correctif** | package réel, non-masse, aucun driver lourd, `Sword_Attack` sélectionné/joué, one-shot, verrou, résolution, sleep/wake, cleanup |
| `enemy_unit_behavior_probe.gd -- --id=nathenian1` | PASS après correctif | exact, far/close, démarrage/résolution/dégâts, interruption, cible, sleep/wake, cleanup |
| `enemy_mixed_stress_probe.gd` | PASS `22 familles / 36 unités` | deux cohortes, cible mobile/changée, wake, 4 sections, 4 morts, cleanup |
| `enemy_navigation_component_probe.gd` | PASS | intention, formation, fallback, recovery du mode direct |
| `enemy_navigation_navmesh_probe.gd` | PASS transversal | path/détour/retarget/arrivée/carte vide; mode différent |
| `enemy_animation_lod_probe.gd` | PASS | shared/native/direct, cadences et réveil réversible |
| `enemy_transient_lifecycle_probe.gd` | PASS | ressources partagées, TTL, collisions/ombres retirées |
| `enemy_material_cache_probe.gd` | PASS | matériaux procéduraux partagés par paramètres immuables |
| `enemy_shield_world_radius_probe.gd` | PASS | rayon de requête = échelle physique héritée |
| factory route/options/registry | PASS | route canonique, options legacy, registre |
| archetype data/cache | PASS | 22 profils typés exacts/cachés, copies legacy isolées |
| action state / combat / faction targeting | PASS | contrats communs décision, défense, claims, friendly fire |
| anatomy regression / crowd cadence | PASS | mort fatale; grille 20 Hz + invalidation immédiate |
| `procedural_enemy_spawn_probe.gd` | PASS après alignement | contrat atomique d'entrée/sommeil, `battle_player` stable, restauration cible au réveil; ordinary/miniboss/boss |
| `procedural_campaign_probe.gd` | PASS | légions étagées, entrée donjon 20 unités, fin élite |
| benchmark 1/12/56 idle/actif | PASS structure/cleanup | limite 56 actifs p95 `37.534 ms`, sans baseline comparable |
| catalogue animation | PASS diagnostic | UAL1 contient `Idle`, `Jog_Fwd`, `Sprint`, `Sword_Attack`, `Death01`; signatures du profil présentes seulement en UAL2 |
| captures Lab/Forge | PASS `22/22` | vraies routes; cadrage global, pas preuve fine |

Journaux frais : `.tmp_tools/enemy_refactor/nathenian1_audit/`, dont `package_attack_fallback_after_fix.log`, `behavior_after_fix.log` et `procedural_spawn_after_fix.log`. Chaque run Godot émet le bruit Windows `Failed to read the root certificate store`; certains affichent aussi l'impossibilité de créer `user://.tmp_tools/enemy_refactor` alors que les journaux explicites workspace sont bien produits. Ces messages n'affectent pas les sorties fonctionnelles décrites.

## Décision de sortie

**DONE**. Le seul défaut fonctionnel concret de l'audit initial est corrigé et couvert par un test de régression exact non-masse, tandis que le comportement complet et le spawn procédural atomique repassent. Tout le reste du contrat audité est vert ou documenté comme limite de qualité/performance sans baseline. La composition encore technique des captures, l'absence de baseline historique `nathenian1`, la densité géométrique du package et la limite du steering direct restent du backlog; ils ne justifient ni une réécriture du runtime ni la suppression d'un donneur sans preuve.
