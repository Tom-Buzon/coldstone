# Audit final distinct — `nfull_armor`

> **Clôture post-revue — 2026-08-26.** Cette note remplace toute description historique plus bas d'une planche à six états, d'anciennes dimensions ou d'une présence Lab/Forge statique. Le probe comportemental exact et le probe de démembrement strict passent sur l'ID; la planche finale rend 13 états (`IDLE NU`, `JOG NU`, `SPRINT`, `ROTATION`, `GARDE`, `ATTAQUE`, `IMPACT`, `UPPER BODY`, `LOD LOIN`, `SOMMEIL`, `REVEIL`, `MORT`, `SECTION`), et les routes Lab/Forge rendent les 22 IDs avec six actions distribuées. Ses deux transitions déclarées passent le probe exact; teardown, TTL et rechargement sont couverts par `REGRESSION_MATRIX.md`.

**Statut : DONE**\
**Date : 2026-08-26**\
**Moteur validé : Godot 4.7-stable (`5b4e0cb0f`)**\
**Renderer des probes : `gl_compatibility`, headless**\
**Portée : état courant du worktree; sources centrales inspectées en lecture seule, écritures limitées au présent rapport et aux logs temporaires.**

## Verdict synthétique

`nfull_armor` est bien le boss final cuirassé attendu, et non une variante cosmétique d'un autre ennemi. Son profil canonique conserve 2 200 PV, une grande épée, une armure lourde, trois phases, des seuils à 68 % puis 32 %, des multiplicateurs cumulatifs et trois cycles distincts de 3 / 3 / 4 actions. Les transitions réelles annulent atomiquement le windup précédent, émettent exactement `[2, 3]`, remettent le curseur de pattern à zéro et appliquent une seule fois vitesse, dégâts, cadence puis affaiblissement d'armure. `iron_quake` et `throne_quake` gardent leurs ondes de choc de rayon 4,2 et 5,4 m.

Le package visible `nfullarmor-1787349525988.glb` passe le schéma Spartan : 53 os, dix parties corporelles, dix-huit caps gore, anatomie 12/12 et dix sections. Le rig visible reçoit la pose d'un UAL1 caché, puis les six clips de combat externes sont chargés sélectivement et retargetés. Cette pile plus lourde est volontairement réservée au boss hors mode masse; aucun donneur n'a été retiré faute de preuve de remplacement équivalente.

Les routes Combat Lab, Battle 03, campagne procédurale et Forge convergent vers la factory canonique. Les probes exacts passent le cycle de base, les trois phases, la perte de cible/lease, le désarmement, sommeil/réveil, ciblage de faction, mort atomique, lifecycle, roster 22/22 et stress 36 unités au seuil de masse inchangé 28. Les trois captures inspectées montrent une silhouette cuirassée identifiable, grande épée en main et aucune T-pose grossière.

Verdict final : **DONE**. Aucun défaut fonctionnel concret propre à `nfull_armor` n'est reproduit. Les limites de preuve restent explicites : aucun duel automatisé ne résout individuellement les sept actions des phases II/III contre une cible instrumentée; le probe de phase valide transitions et séquences tandis que le résolveur commun de shockwave est couvert transversalement. Les mesures sont CPU/headless, sans GPU, VRAM ni draw calls. Le modèle source reste lourd et la pile de donneurs doit être optimisée seulement après une nouvelle preuve animée, anatomique et rendue complète.

## Identité et profil canonique

Source de vérité : `scripts/enemy/enemy_archetypes.gd:1039-1106`, normalisée par `profile()` puis appliquée avant construction runtime.

| Champ | Valeur | Effet d'identité |
|---|---:|---|
| nom / rôle / rang | `STRATEGE CUIRASSE` / `boss_anchor` / `boss` | ancre centrale et boss final |
| échelle | `1.28` | silhouette dominante |
| PV | `2200` | endurance de boss |
| vitesse | `4.45 m/s` | fermeture active malgré l'armure |
| dégâts / portée / aggro | `52 / 2.55 / 32 m` | pression de mêlée et acquisition longue |
| arme | `greatsword`, échelle `1.22` | grande épée à deux mains visuellement distincte |
| comportement / style | `phase_boss` / `boss_combo` | décision et cycles propres |
| défense | `armor` | dégâts x`0.60`, section x`0.34` |
| poise | `0.88` | forte résistance à l'interruption |
| bande préférée | `0.0–2.32 m` | recherche du contact |
| coût / poids / vague procédurale | `12.0 / 0.05 / 9` | boss rare et tardif |

Ce profil diffère des miniboss lourds : il possède explicitement un rang `boss`, deux seuils de vie, une troisième phase et dix actions nommées. La campagne l'utilise comme unique `final_elite` du donjon et Battle 03 comme `final_boss` de l'acte IV.

## Trois phases et patterns 3 / 3 / 4

### Phase I — contrôle lourd

| Action | Clip externe | Windup / recovery / cooldown | Particularité |
|---|---|---:|---|
| `iron_cleave` | `heavy_release` | `0.52 / 0.48 / 0.90 s` | dégâts x`1.18`, portée x`1.08` |
| `iron_sweep` | `spin_low` | `0.44 / 0.46 / 0.86 s` | balayage large, arc dot `-0.38` |
| `iron_leap` | `air_down` | `0.66 / 0.58 / 1.14 s` | dégâts x`1.42`, portée x`1.15`, lunge `7.4` |

### Phase II — serment de fer, sous 68 %

La transition applique vitesse x`1.16`, dégâts x`1.15`, accélère les cooldowns et annule toute attaque phase I en windup.

| Action | Clip externe | Windup / recovery / cooldown | Particularité |
|---|---|---:|---|
| `iron_rush` | `dash_attack` | `0.24 / 0.24 / 0.40 s` | lunge `7.8` |
| `iron_storm` | `spin_high` | `0.32 / 0.35 / 0.62 s` | portée x`1.25`, arc dot `-0.55` |
| `iron_quake` | `axe_down` | `0.72 / 0.64 / 1.10 s` | shockwave rayon `4.2 m` |

Dans la campagne procédurale, le signal de phase queue huit `nsbire1` supplémentaires. Le signal et la file sont couverts par `procedural_campaign_probe`.

### Phase III — couronne brisée, sous 32 %

La transition applique encore vitesse x`1.15` et dégâts x`1.18`, puis relâche la réduction de dégâts d'armure à `0.78`. Elle ne réapplique pas les multiplicateurs de phase II.

| Action | Clip externe | Windup / recovery / cooldown | Particularité |
|---|---|---:|---|
| `crown_breaker` | `dash_attack` | `0.18 / 0.18 / 0.31 s` | lunge `9.0` |
| `dread_storm` | `spin_high` | `0.24 / 0.28 / 0.48 s` | portée x`1.36`, arc dot `-0.72` |
| `throne_quake` | `axe_down` | `0.56 / 0.48 / 0.82 s` | shockwave rayon `5.4 m` |
| `last_execution` | `heavy_release` | `0.34 / 0.35 / 0.58 s` | dégâts x`1.62`, portée x`1.16` |

La campagne queue alors six `nathenian1` et un dernier `ncenturion`. `enemy_phase_contract_probe -- --id=nfull_armor` confirme exactement les transitions `[2,3]`, les multiplicateurs et l'ordre déclaratif des 3 puis 4 actions. `enemy_unit_behavior_probe` résout les trois actions de phase I par le vrai scheduler, puis vérifie interruption par désarmement, perte de cible sans lease résiduelle et sommeil/réveil. Le chemin commun `_resolve_ai_attack()` déclenche télégraphe au windup et libération au resolve lorsque `special == shockwave`; il est couvert par les probes combat/lifecycle, mais les sept actions tardives ne disposent pas encore d'un test end-to-end chacune.

## Factory et routes réelles

`HopliteEnemyFactory.spawn_request()` est l'unique point de construction runtime. La requête typée transmet ID, cible, faction, participation IA et mode masse avant `_ready()`. Le probe de route ne trouve aucune construction parallèle sous `scripts/`.

Le full roster imprime :

```text
id=nfull_armor family=nfull_armor rig=package_retarget anatomy=12/12
equipment=greatsword action=iron_cleave navigation=DIRECT_STEERING
```

Routes inspectées et exercées :

- **Combat Lab** : `scripts/main.gd` déclare explicitement `NFULLARMOR — BOSS` et l'inclut au roster élite; la capture globale utilise la vraie scène Lab plus son annexe de preuve.
- **Battle 03** : `_spawn_final_boss()` crée `nfull_armor` à l'acte IV par `_spawn_story_soldier()`, qui délègue à la factory. La mort du rôle `final_boss` termine l'histoire. `narrative_battle_probe` charge la vraie mission et passe ses trois actes, props, triggers et deux phalanges.
- **Procédural** : le directeur instancie `nfull_armor` avec `boss=true`, écoute `combat_phase_changed`, queue les renforts II/III et garde le cadavre sous un TTL borné. Les probes de spawn et campagne passent jusqu'à l'élite finale.
- **Forge** : `world_editor_flow_probe` passe document, ajout/sélection, sérialisation et playtest runtime. La capture roster Forge matérialise les 22 identités par le runtime réel.

Le seuil de foule reste exactement `28`; `enemy_mixed_stress_probe` le confirme avec 36 unités et deux cohortes.

## Package, rig, retargeting et animation

Asset résolu : `assets/characters/3dgen_demo/nfullarmor-1787349525988.glb`.

| Mesure statique | Valeur |
|---|---:|
| taille / SHA-256 | `12 535 932` octets / `E7F50EBA3D36BE29F360D4DD3766AEB082A34D3B2B77E0FEEB6F7D1C50178639` |
| glTF / générateur | `2.0` / Khronos Blender I/O `5.2.39` |
| scènes / nœuds | `1 / 83` |
| skins / joints | `1 / 53` |
| meshes / primitives | `28 / 28` |
| triangles LOD0 cumulés | `36 580` |
| matériaux / textures / images | `2 / 1 / 1` |
| animations locales | `1` |
| parties corps / caps gore | `10 / 18` (28 meshes au total) |

L'import active tangentes, LOD automatiques, shadow meshes, skins nommés et bake animation 30 FPS. Le schéma runtime exige `SPARTAN_ASSET`, `spartan_schema=1`, `spartan_rig=spartan_ual1_v1`, 53 os essentiels, dix parties nommées et deux caps par section.

La pile effective est :

1. un squelette visible canonique issu du package;
2. un UAL1 invisible pour locomotion, idle, impact et mort;
3. un `AuthoredPoseBridge` en rest-space vers le squelette visible;
4. le driver natif spécialisé du boss;
5. six clés externes sélectives (`heavy_release`, `spin_low`, `air_down`, `dash_attack`, `spin_high`, `axe_down`) dédupliquées par chemin dans l'`ExternalAnimationBank`.

`enemy_animation_probe` joue réellement l'ouverture `iron_cleave -> external:heavy_release`. `enemy_animation_lod_probe` passe la cadence des drivers shared/native/direct et le réveil réversible. Le LOD native réduit l'échantillonnage avec la distance, dort au niveau 3 et force une évaluation au réveil; aucun `AnimationTree` ne reste définitivement désactivé.

Cette architecture est fonctionnelle mais plus chère que la bibliothèque partagée des hoplites. Supprimer UAL1 ou un donneur externe casserait locomotion, mort ou une partie des dix actions. Il faut d'abord produire un bake partagé équivalent et le prouver sur les trois phases, les six états visuels et les dix sections.

## Grande épée, armure et physique

La grande épée est construite par `_make_greatsword()` sous `FullArmorGreatsword` : lame `0.13 x 1.48 x 0.045 m`, garde `0.52 x 0.075 x 0.10 m`, acier sombre métallique et bronze. L'échelle d'équipement `1.22` la rend nettement plus longue qu'une épée standard. La perte d'un bras ou avant-bras droit la détache; le corps physique tombé reçoit une box `0.16 x 1.70 x 0.10 m`, une impulsion, puis le lifecycle retire collision/ombres avant libération.

L'armure n'est pas seulement visuelle : la défense applique `damage x0.60`, `sever x0.34`, poise `0.88`, puis phase III change le multiplicateur dégâts à `0.78`. Le test combat transversal passe garde/break/parry/patterns, et le probe exact confirme que le désarmement interrompt le windup avant dégâts.

Le corps est un `CharacterBody3D`, couche ennemie 4, masque monde + joueur. Hors mode hitbox parfaite géante, sa traversée utilise une `CapsuleShape3D` primitive locale de rayon `0.39`, hauteur `1.82`, centre Y `0.91`; l'échelle racine uniforme 1,28 donne environ `0.499 m` de rayon et `2.330 m` de hauteur monde. Aucune concave dynamique n'est utilisée.

La checklist physique recommande toutefois de dimensionner directement la shape plutôt que scaler un body. Ici l'échelle est uniforme et aucun défaut n'est reproduit, mais pentes, marches et passages étroits demandent un test Jolt dédié avant conversion des dimensions.

## IA, navigation, scheduler et ciblage

`nfull_armor` utilise `EnemyNavigationComponent.Mode.DIRECT_STEERING`, pas un `NavigationAgent3D`. C'est cohérent avec sa taille 1,28, inférieure au seuil `1.75` des grands corps. Le composant fournit l'intention; `CharacterBody3D` reste seul propriétaire de la vitesse, de la gravité et de `move_and_slide()`, puis notifie le déplacement réellement appliqué.

Configuration : arrivée `0.28 m`, progrès minimal `0.12 m/s`, blocage `0.82 s`, récupération latérale `0.48 s` à 72 % de vitesse. Ce mode possède donc une récupération bornée mais ne promet pas de détour topologique autour d'un labyrinthe comme un navmesh. `enemy_unit_behavior_probe` passe décisions loin/proche, cible stable puis détruite, lease relâchée, sommeil/réveil et cleanup. `enemy_faction_targeting_probe` passe priorité de groupe, claims, représailles et absence de friendly fire.

Le scheduler d'attaque est générationnel et FIFO au niveau foule. Le boss libère sa permission à l'interruption, au changement de phase, à la perte de cible, au sommeil et à la mort. Le stress mixte confirme qu'il cohabite avec les autres familles, deux cohortes, une cible mobile puis remplacée, quatre sections et quatre morts sans référence survivante.

## Anatomie, démembrement, mort et lifecycle

Le profil humanoïde expose douze zones : tête, cou, torse, bassin, deux bras supérieurs, deux avant-bras, deux cuisses et deux tibias. Tête/cou sont létaux; torse/bassin ne se sectionnent pas; les huit membres et la tête donnent dix résultats sectionnables en comptant le cou comme route vers la tête.

| Zone | Forme / rayon local | Dégâts | Section / seuil | Conséquence |
|---|---|---:|---:|---|
| `head` | sphère `0.25` | x`1.70` | x`1.00 / 64` | fatal, tête détachée |
| `neck` | capsule `0.15` | x`1.85` | x`1.35 / 56` | redirige tête, fatal |
| `torso` | capsule `0.34` | x`1.00` | x`0.35 / —` | dégâts localisés, armure |
| `pelvis` | capsule `0.30` | x`0.95` | x`0.30 / —` | dégâts localisés, armure |
| bras supérieurs L/R | capsule `0.16` | x`0.78` | x`1.00 / 78` | descendant masqué; côté droit lâche l'épée |
| avant-bras L/R | capsule `0.14` | x`0.75` | x`1.10 / 60` | équipement droit lâché |
| cuisses L/R | capsule `0.21` | x`0.88` | x`0.82 / 94` | tibia lié, boiterie |
| tibias L/R | capsule `0.18` | x`0.84` | x`1.05 / 72` | boiterie; deux jambes = crawl |

`enemy_unit_dismemberment_probe.gd -- --id=nfull_armor` instancie une unité fraîche par zone et passe `zones=12 severed=10`. Les zones sont des `Area3D` primitives liées aux os; la section masque la branche corporelle, révèle les caps et instancie le membre réel depuis le package, avec proxy seulement si cette route échoue.

La mort est atomique : permission et cible libérées, `dead=true`, `set_ai_participation(false)`, retrait du crowd/registre/groupes, destination annulée, collisions/anatomie/physique arrêtées, grande épée lâchée et driver fermé. `Death01` reprend alors la pose du cadavre avant sa réduction render-only; l'encounter reste propriétaire du TTL final. Sang, shockwaves, membres et arme détachée ont des ressources partagées et un lifecycle borné validé.

## Performance — photographie exacte actuelle

Commande fraîche :

```powershell
Godot_v4.7-stable_win64.exe --headless --path . --script res://tools/enemy_performance_benchmark.gd -- --counts=1,28 --mode=both --warmup=30 --frames=60 --seed=13371 --archetype=nfull_armor --registry=on
```

| Mode | Unités | Spawn | Snapshot process / physics | Nœuds / objets | Mémoire statique | Corps actifs | Tick p95 / p99 / max | Cleanup |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| idle | 1 | `154.782 ms` | `0.622 / 0.396 ms` | `85 / 1 765` | `64 207 793 o` | `0` | `20.717 / 20.727 / 20.727 ms` | PASS |
| idle | 28 | `384.563 ms` | `394.288* / 3.615 ms` | `2 191 / 4 384` | `77 981 627 o` | `0` | `20.697 / 23.647 / 23.647 ms` | PASS structurel |
| actif | 1 | `201.179 ms` | `0.626 / 0.955 ms` | `86 / 1 768` | `65 047 557 o` | `1` | `20.702 / 20.720 / 20.720 ms` | PASS |
| actif | 28 | `528.606 ms` | `10.992 / 7.533 ms` | `2 219 / 4 441` | `78 315 039 o` | `28` | `23.348 / 24.047 / 24.047 ms` | PASS structurel |

`*` Snapshot lent contaminable par le scénario précédent, explicitement non utilisé comme gate. Les quatre scénarios finissent avec zéro combattant, zéro WeakRef vivant et zéro orphelin. Le registre contient exactement 1/28 références pendant la mesure puis zéro.

Cette photo ne doit pas être présentée comme une comparaison avant/après propre à cette famille. Elle montre surtout que 28 boss passent le contrat structurel et cleanup, malgré un cas artificiel bien au-delà de l'usage contenu. Le modèle de 36 580 triangles, les meshes/caps et les donneurs retargetés restent des candidats d'optimisation, mais aucune réduction n'est sûre sans benchmark GPU et nouvelle preuve visuelle/anatomique.

## Preuves visuelles inspectées

`docs/enemy_refactor/visual_evidence/nfull_armor.png` (1 351 x 760, SHA-256 `486683F5...`) montre `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`. La cuirasse et la grande épée sont reconnaissables dans toutes les poses utiles; idle/jog ne sont pas en T-pose, l'attaque engage réellement l'épée, et la section montre un membre séparé. La planche prouve la silhouette globale, pas les coutures, collisions, timing des dix actions ni la qualité rapprochée des caps; quelques particules rouges lointaines polluent le bord droit.

`lab_full_roster_visual_probe.png` (1 600 x 900, SHA-256 `02BF8ED9...`) et `forge_full_roster_visual_probe.png` (1 600 x 900, SHA-256 `8996442A...`) ont été inspectées en résolution originale. `nfull_armor` est visible au premier rang, cuirassé et équipé, parmi les 22 identités. Aucune T-pose grossière n'apparaît. Les labels sont petits, plusieurs silhouettes se chevauchent et Forge est très lumineux : ces captures prouvent intégration et présence, pas une QA rapprochée de phase ou de matériau.

## Tests exécutés

| Test | Résultat | Portée / réserve |
|---|---|---|
| `enemy_unit_dismemberment_probe -- --id=nfull_armor` | PASS `12 / 10` | chaque zone, fatalités, équipement, teardown |
| `enemy_unit_behavior_probe -- --id=nfull_armor` | PASS | loin/proche, 3 attaques phase I, interruption, target-loss, sleep/wake, cleanup |
| `enemy_phase_contract_probe -- --id=nfull_armor` | PASS `[2,3]`, `3/4` | transitions, annulation atomique, multiplicateurs, ordre des phases II/III |
| `enemy_full_roster_validation_probe` | PASS `22/22` | famille, rig, anatomie, grande épée, opener, navigation |
| `enemy_roster_audit` | PASS `22` | packages, rangs, défenses, clips externes, profils |
| `enemy_animation_probe` | PASS `14/14` | opener du boss joue `heavy_release` |
| `enemy_animation_lod_probe` | PASS | shared/native/direct, cadence et réveil réversible |
| `enemy_combat_probe` | PASS | garde, break, parry, cycles élite communs |
| `enemy_action_state_probe` | PASS | garde, recovery, windup, parry, priorité |
| `enemy_faction_targeting_probe` | PASS | groupes, claims, représailles, friendly fire |
| `enemy_transient_lifecycle_probe` | PASS | ressources partagées, TTL, collisions/ombres retirées |
| `procedural_enemy_spawn_probe` | PASS | spawn boss par factory et contrats runtime |
| `procedural_campaign_probe` | PASS | phases, renforts, surge 20 unités, élite finale |
| `enemy_factory_route_probe` | PASS | construction canonique unique |
| `narrative_battle_probe` | PASS | vraie Battle 03, trois actes, deux phalanges |
| `world_editor_flow_probe` | PASS `WORLD_EDITOR_FLOW_OK` | document/runtime Forge |
| `enemy_mixed_stress_probe` | PASS `22 familles / 36 unités` | seuil 28, retarget, wake, sections, morts, cleanup |
| `enemy_performance_benchmark` | PASS structurel | 1/28 idle/actif, registre et cleanup |

Logs : `.tmp_tools/enemy_refactor/nfull_armor_audit/`. L'avertissement Windows de certificat racine et l'échec d'écriture des préférences Gore HUD dans le sandbox sont sans incidence sur les assertions. `world_editor_flow_probe` signale huit objets et quatre ressources encore en usage au shutdown du harness; son contrat fonctionnel est vert et ce bruit n'est pas attribué à `nfull_armor`.

## Revue Godot 4.7

### Critique

Aucune panne critique propre à `nfull_armor` n'est reproduite.

### Améliorations / dette honnête

- Ajouter un probe exact qui, après chaque transition, résout chacune des 3 puis 4 actions tardives contre des cibles placées dedans/dehors, observe les télégraphes/release et mesure les rayons monde 4,2/5,4 m. Le contrat actuel prouve les séquences et le résolveur commun, pas ces sept livraisons une par une.
- Étendre `enemy_roster_audit.gd` à `phase_three_pattern`; son résumé `pattern=3/3` omet aujourd'hui les quatre actions de phase III. Le probe dédié les couvre, mais la sortie roster est incomplète.
- Baker à terme locomotion et six clips externes dans une bibliothèque compatible au rig visible afin de supprimer les squelettes/bridges cachés par instance. Ne retirer aucun donneur avant parité multi-frame des trois phases, mort, wake LOD, Lab, Battle, Forge et dix sections.
- Réduire les `36 580` triangles source, 28 meshes et coût d'ombres seulement par retopologie/LOD prouvés. Préserver les dix parties logiques, dix-huit caps, skin et équipement.
- Remplacer l'échelle du `CharacterBody3D` par des dimensions explicites après tests Jolt de pentes, marches, passages étroits et interpolation.
- Mesurer GPU/VRAM/draw calls, surfaces réellement visibles, sélection des LOD et ombres dans une vraie fenêtre; le headless ne couvre pas ces coûts.
- Produire une planche rapprochée dédiée aux phases II/III : rush, spin, les deux shockwaves, execution, armure phase III, main/grande épée, mort et transition LOD3→0.
- Diagnostiquer séparément les huit objets/quatre ressources signalés au shutdown de `world_editor_flow_probe`; le test fonctionnel passe, mais un harness propre faciliterait l'attribution future des régressions.

### Points solides

- Boss réellement distinct : rang, armure, poise, trois phases et dix actions.
- Factory unique et quatre routes de contenu exercées.
- Transitions de phase atomiques, ordonnées et accompagnées de renforts procéduraux.
- Rig visible 53 os validé, retarget sélectif fonctionnel et LOD animation réversible.
- Grande épée présente, physique et détachable; armure mécanique, pas seulement visuelle.
- Anatomie 12/12 et dix sections conservées avec caps réels.
- Mort, leases, ciblage, crowd, registre et transients nettoyés de manière bornée.
- Seuil de masse 28 inchangé; stress 36 unités et benchmark structurel sans survivant.

---

Revu contre les checklists Godot 4.3+ / 4.7 de navigation, animation, physique, assets, 3D, testing, debugging et code review.
