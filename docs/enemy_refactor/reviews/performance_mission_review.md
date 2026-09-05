# Contre-revue finale — performance, tests, mission et documentation

**Verdict autoritaire : DONE**

## Réévaluation autoritaire — état courant du 26 août 2026

Cette section remplace intégralement le verdict et les findings de la revue initiale conservée plus bas. La réévaluation porte sur l'état courant après corrections, les journaux post-revue et les deux autres contre-revues autoritaires.

### Verdict final

**DONE**

Aucun P0, P1 ou P2 actif n'est retenu. Les métriques publiées sont traçables jusqu'aux journaux bruts, les comparaisons non homogènes ne sont plus transformées en pourcentages, les limites CPU/mémoire/rendu sont explicites, les 22 identités ont une clôture post-revue et les contre-revues architecture/navigation et visuel/animation/physique concluent désormais elles aussi `DONE`.

### P0

Aucun. Aucun crash runtime reproductible, aucune corruption, aucune référence ennemie forte persistante et aucun échec fonctionnel final ne ressortent du corpus autoritaire.

### P1

Aucun. Les anciens blockers — architecture, phase `warlord`, couverture visuelle, TTL de cadavres, stabilité multi-rechargement, attribution `boss_bronze__knight3` et tableau final incomplet — sont fermés par des probes ou documents postérieurs et explicitement identifiés.

### P2

Aucun actif. Les incohérences documentaires observées pendant la contre-revue ont été corrigées : portée des métadonnées de `final_metrics.json`, limitation NavigationServer, tableau `ngeneral` après passage `RefCounted`, baseline propre de `ngeneral_veteran`, rouge `radial_hit` périmé et clé `minimum_progress_speed`.

### P3 — limites de preuve conservées, non bloquantes

- Les p95 `physics_tick_interval_wall_ms` restent des intervalles cadencés, pas du temps CPU pur. Les snapshots `TIME_PROCESS`/`TIME_PHYSICS_PROCESS` sont à rafraîchissement lent. La région de callbacks mesure du temps monotone de mur incluant la préemption OS. Les documents le déclarent et n'en déduisent aucun gain causal.
- Seuls `swordsman` et `ngeneral` possèdent une baseline phase 0 propre. Les vingt autres lignes du tableau final portent exactement `N/A — baseline non capturée`; une photo courante n'est jamais substituée à un « avant » inventé.
- Les valeurs Forge/Lab sont des diagnostics rendus actuels, sans baseline GPU comparable. Aucun gain de draw calls, VRAM, FPS ou qualité visuelle n'est revendiqué.
- `enemy_unit_behavior_probe` valide le contrat par ID en appelant directement le début et la résolution après suspension de la physique. Les délais communs sont couverts par les probes d'état/animation, mais cette preuve ne doit pas être décrite comme une capture cinématique frame-par-frame propre à chaque ID.
- La stabilité 5 × 36 prouve un plateau post-préchauffage sur la route testée, pas l'absence universelle de tout cache moteur ou de toute dette audio/UI hors périmètre ennemi.

## Preuves autoritaires recalculées

### Intégrité des métriques

- `baseline_metrics.json` reproduit exactement les 10 scénarios `swordsman` et les 6 scénarios `ngeneral` de ses deux logs bruts : zéro divergence champ par champ.
- `final_metrics.json` reproduit exactement 16/16 scénarios structuraux, 3/3 scénarios callback à 56, 2/2 snapshots rendus et la campagne de 5 rechargements : zéro divergence sur spawn, snapshots process/physics, nœuds, objets, ressources, mémoire, p95, teardown, draw calls, primitives et mémoires vidéo/texture/buffer.
- Le rejeu callback sur le code final est persisté dans `logs/final_closure_action_{steady_clean,realistic_active,mixed_roles}_56.log` : p50/p95 `2 720/4 702`, `10 435/14 254` et `11 029/14 694 µs`. Les trois certificats portent le SHA-256 courant du contrôleur `042cdd09de72f2fa037e8c604c0ec244fe356e22d317196f82151e465fc502af`, des comptes objets stables pendant l'échantillonnage et un teardown sans référence vivante.
- Les métadonnées sont maintenant séparées en quatre contextes : structural headless `120/120`, callback headless `120/240`, rendu Windows avec `24` frames de stabilisation, et reload headless `5 × 36`.
- Les pourcentages mémoire structuraux publiés sont arithmétiquement corrects et issus de scénarios comparables. Les anciennes références callback v1/v2 sont explicitement non comparables; leurs pourcentages ont été retirés. Les hausses de spawn et de mémoire sont publiées, pas masquées.

### Teardown, objets et mémoire

- Les 16 scénarios finaux ont `structural_cleanup.ok=true`, zéro `WeakRef` ennemi vivant, zéro combatant résiduel et zéro orphelin au snapshot.
- Les trois régions callback gardent exactement le même nombre d'objets entre début et fin d'échantillonnage, puis libèrent ennemis et auxiliaires.
- Sur 5 cycles de 36 actifs, chaque cycle finit à zéro référence/groupe; après le premier préchauffage, les quatre comptes objets valent tous `1 596` (span `0`) et le span mémoire vaut `2 436 B`, sous la tolérance déclarée de `4 MiB`.
- Les snapshots rendus sont sourcés par `final_postreview_render_{forge,lab}.log` et restent qualifiés de budgets actuels, jamais de preuve d'optimisation GPU.

### Couverture 22/22 et variantes

- `roster_manifest.json` contient 22 IDs uniques et 22 statuts `DONE`; il existe 22 fiches et 22 bandeaux `Clôture post-revue`.
- Le ledger final contient 22 lignes `DONE`; le tableau final à 11 colonnes contient également 22 lignes `DONE`, avec 2 baselines exactes et 20 `N/A` explicites.
- Il existe 22/22 logs comportementaux post-revue `PASS` et 22/22 logs de démembrement `PASS zones=12 severed=10`.
- Les cinq profils à phases ont leurs logs exacts, dont `warlord transitions=[2] phase2_actions=2` et `nfull_armor` traversant ses deux transitions.
- La matrice Mixamo couvre 7 familles, 20 modèles et 240 zones. Après correction, le rerun indépendant `boss_bronze` termine en code `0` avec `variants=3 zones=36`; un override cross-pool est rejeté et retombe sur le package canonique.
- Les 22 planches canoniques rendent 13 états. `boss_bronze__knight3.png`, inspecté en résolution originale, montre bien Knight3 argent/or et non le package noir/bronze; le générateur exige désormais `uses_mixamo_visual` et l'ID demandé avant toute sauvegarde suffixée.

### Mission et cohérence documentaire

- Le seuil `total_count >= 28` est identique dans `HEAD` et le worktree.
- `CURRENT_STATE.md` et `MIGRATION_MATRIX.md` sont marqués historiques/non autoritaires; les anciens tableaux du ledger et de la matrice de régression sont explicitement remplacés par leurs gates finales.
- `FINAL_ENEMY_OPTIMIZATION_REPORT.md` contient le tableau prescrit `Unité / Logique / Navigation / Rig / Donneurs / Mesh / Démembrement / Tests / Perf avant / Perf après / Statut`, sans fabriquer les baselines absentes.
- `architecture_navigation_review.md` conclut `DONE` sans P0-P2 actif; `visual_animation_physics_review.md` conclut `DONE` après levée factuelle du dernier blocker Knight3.
- Les logs post-revue ne contiennent aucun rouge projet résiduel. Restent le warning Windows du magasin de certificats, le warning d'écriture du Gore HUD en sandbox et le warning intentionnel de rejet cross-pool; ils sont identifiés, hors contrat ennemi et sans code de sortie non nul retenu.

## Conclusion autoritaire

La mission est **DONE** sur le périmètre audité. Les preuves démontrent la conservation fonctionnelle, le teardown structurel, le plateau de rechargement testé, la couverture 22/22 et l'honnêteté des métriques. Elles ne démontrent pas un gain CPU/GPU global, et les documents finaux ne le prétendent plus.

## Revue initiale historique — remplacée par la réévaluation ci-dessus

Le texte ci-dessous décrit l'état antérieur aux corrections de post-revue. Ses verdicts, chiffres intermédiaires et actions ouvertes sont conservés uniquement pour la traçabilité; ils ne doivent pas être utilisés comme état courant.

Date : 2026-08-26\
Périmètre : baseline/final, campagnes `refcount`, région de callbacks, teardown, 22 fiches unitaires, manifest/ledger/matrices, preuves visuelles, rapport final et exigences de la mission.\
Méthode : inspection indépendante des sources, documents et logs. Aucun code central n'a été modifié.

## Verdict historique

**BLOCKED — état antérieur remplacé**

Le socle de preuves est substantiel : les 22 IDs possèdent une fiche `DONE`, un probe comportemental positif, une anatomie `12/12` avec `10` conséquences sectionnables, une planche rendue, et les logs finaux structuraux libèrent tous les `WeakRef` ennemis et groupes suivis. Le seuil de masse reste bien `28` dans la route Forge versionnée. Les logs finaux ne contiennent pas d'échec Godot autre que le warning Windows connu du magasin de certificats.

La clôture globale n'est toutefois pas démontrée. Une contre-revue indépendante déjà livrée est elle-même `BLOCKED` sur quatre P1 fonctionnels/architecturaux. En outre, la comparaison CPU publiée mélange deux versions de harness non comparables, la baseline obligatoire reste incomplète pour la majorité des unités, la preuve visuelle n'exécute pas la matrice exigée, et la phase 2 exacte du `warlord` n'a pas de log. Les assertions `DONE 22/22`, « preuves visuelles complètes » et « mission clôturable » doivent donc rester suspendues.

## Findings

### P0

Aucun P0 observé dans ce périmètre : aucun crash, corruption ou `WeakRef` ennemi persistant n'apparaît dans les logs finaux autoritaires.

### P1 — Le verdict final ignore une contre-revue indépendante `BLOCKED`

Fichiers :

- `docs/enemy_refactor/reviews/architecture_navigation_review.md`
- `docs/enemy_refactor/FINAL_ENEMY_OPTIMIZATION_REPORT.md:4-5,144`
- `docs/enemy_refactor/REGRESSION_MATRIX.md:5-21`

La contre-revue architecture/navigation conclut `BLOCKED` avec quatre P1 : aucun remplacement réel d'un survivant dans une vacance de première ligne, petite cohorte encore bloquable avec deux réservistes, aucun ennemi de production en `NAVMESH_GROUND`, et documentation présentant comme actuelles des autorités FSM/registre non actives. Le rapport final postérieur conclut pourtant `DONE` et « zéro blocage fonctionnel connu ».

Une mission dont la définition impose une revue croisée sans observation critique ne peut pas être clôturée tant qu'un reviewer distinct fournit des reproductions contraires.

**Action exacte :** corriger ou réfuter chaque P1 avec un probe qui reproduit précisément le cas décrit, relancer les gates communes sur l'état corrigé, puis demander une nouvelle revue indépendante. Tant que le reviewer ne passe pas à `PASS`, conserver le statut global `BLOCKED`.

### P1 — Les gains CPU de −17,9 % à −57,7 % ne proviennent pas d'un avant/après comparable

Fichiers/logs :

- `docs/enemy_refactor/PERFORMANCE.md:121-161,210-218`
- `docs/enemy_refactor/FINAL_ENEMY_OPTIMIZATION_REPORT.md:109-117`
- `.tmp_tools/enemy_refactor/enemy_action_cpu_before_*_56_run{1,2,3}.log`
- `.tmp_tools/enemy_refactor/mission_final_action_{steady_clean,realistic_active,mixed_roles}_56.log`

Les références `3 296 / 13 828 / 13 210 µs` sont les médianes du harness **version 1**. `PERFORMANCE.md` les qualifie lui-même de non autoritaires : teardown incomplet, ancien libellé CPU erroné et, pour `steady_clean`, crowd director encore inclus. Les finals sont issus du harness **version 2** avec marqueurs, hashes, teardown auxiliaire et `steady_clean` sans crowd director. La phrase affirmant que référence et final ont les mêmes sources v2 est donc fausse.

Le seul ancien jeu v2 comparable disponible est la campagne A du pilote sur `steady_clean`. Sa médiane A est environ `1 626 µs` au p50 et `6 200 µs` au p95, contre `2 623 / 4 488 µs` au final : p50 environ `+61 %`, p95 environ `−28 %`. Cette contradiction illustre précisément pourquoi un seul final et une référence différente ne peuvent porter des pourcentages de gain.

Les mesures strictement homogènes du benchmark structurel ne montrent pas de gain de spawn :

| Scénario actif | Spawn baseline → final | Écart |
|---|---:|---:|
| swordsman 28 | 502,941 → 547,934 ms | +8,9 % |
| swordsman 36 | 587,715 → 739,080 ms | +25,8 % |
| ngeneral 28 | 225,957 → 295,258 ms | +30,7 % |
| ngeneral 36 | 266,736 → 367,337 ms | +37,7 % |

Les compteurs structurels sont plus favorables pour swordsman (parité des nœuds, `−21` objets à 28 actifs, `−29` à 36), mais moins favorables pour `ngeneral` (`+60/+76` objets actifs et environ `+1,2 %` de mémoire). Cela prouve des compromis, pas un gain CPU global.

**Action exacte :** retirer les pourcentages callback v1→v2 et qualifier le résultat `INCONCLUSIVE`, ou exécuter une campagne A/B alternée avec même version de harness, mêmes hashes, même inclusion du crowd, mêmes scénarios et plusieurs processus frais. Publier médiane, Q1/Q3/IQR et seuil d'acceptation pré-déclaré. Si l'ancien runtime exact n'est plus reconstructible, indiquer honnêtement `baseline comparable indisponible` au lieu d'un pourcentage.

### P1 — La baseline et le tableau avant/après obligatoires ne couvrent pas la mission annoncée

Fichiers :

- `docs/enemy_refactor/baseline_metrics.json:33`
- `docs/enemy_refactor/BASELINE.md`
- `docs/enemy_refactor/units/*.md`
- `docs/enemy_refactor/FINAL_ENEMY_OPTIMIZATION_REPORT.md:47-73,103-121`

`baseline_metrics.json` conserve explicitement comme pendants le mélange de familles, Forge, bataille réelle, sleep/wake, mort de masse, démembrement répété et compteurs rig/anatomie par unité. Dix-sept fiches unitaires reconnaissent l'absence d'une baseline strictement comparable propre à leur ID. Le rapport final remplace le tableau exigé `Logique / Navigation / Rig / Donneurs / Mesh / Démembrement / Tests / Perf avant / Perf après / Statut` par un tableau de cinq colonnes sans performance par unité.

Le bilan global obligatoire ne publie pas d'avant/après comparable pour frame time/FPS rendu, IA, navigation, animation, formation, draw calls, VRAM, squelettes/os, lecteurs/arbres, donneurs/retargeters, meshes/surfaces/triangles, collisions/hitboxes, mort et nettoyage. Les valeurs GPU actuelles sont correctement présentées comme diagnostics sans baseline, mais elles ne satisfont pas une comparaison avant/après.

**Action exacte :** soit reconstruire un état initial reproductible et capturer les mêmes scénarios/compteurs pour chaque famille et unité, soit marquer ces champs `N/A — baseline non capturée` et conserver la mission `BLOCKED`. Compléter le tableau final avec toutes les colonnes prescrites, y compris les absences de mesure, sans substituer un benchmark swordsman/ngeneral à 17 autres IDs.

### P1 — La preuve visuelle par unité ne couvre pas le protocole obligatoire

Fichiers :

- `tools/enemy_unit_visual_evidence.gd:14,75-80,191-247`
- `tools/enemy_lab_forge_full_roster_visual_probe.gd:35-126`
- `docs/enemy_refactor/visual_evidence/*.png`
- `docs/enemy_refactor/{lab,forge}_full_roster_visual_probe.png`

La planche unitaire ne contient que `IDLE NU`, `JOG NU`, `ATTAQUE`, `IMPACT`, `MORT`, `SECTION`. Elle fige plusieurs instances après avoir appelé directement des méthodes privées. Elle ne prouve pas Sprint, rotation, garde, locomotion sous action partielle, proche→lointain→proche, sommeil/réveil, reprise temporelle des pieds/mains, ni absence de gel sur une séquence animée. Seuls Idle/Jog masquent l'équipement, alors que le protocole animation demande les preuves sans arme/bouclier.

Les captures Lab/Forge prouvent que 22 modèles existent au repos dans les deux contextes. Elles sont très distantes; les labels sont difficilement lisibles et le Lab est fortement contrasté. Elles ne prouvent pas le comportement, l'action ou le réveil de chaque ID dans ces scènes.

**Action exacte :** produire pour chacun des 22 IDs une séquence Compatibility ou une série de captures horodatées couvrant Idle, Jog, Sprint si disponible, rotation, garde, attaque, impact, mort, section et locomotion sous action partielle, sans équipement lorsque le protocole l'exige. Ajouter une séquence proche→LOD2/3→proche avec compteur d'échantillons et image du réveil. Dans Lab et Forge, cadrer chaque ID ou des groupes lisibles pendant une action réelle, pas seulement l'annexe idle.

### P1 — La gate « phases 5/5 » ne possède aucune preuve exacte pour `warlord`

Fichiers/logs :

- `docs/enemy_refactor/REGRESSION_MATRIX.md:11`
- `docs/enemy_refactor/FINAL_ENEMY_OPTIMIZATION_REPORT.md:92-96`
- `docs/enemy_refactor/units/warlord.md:111-123,240`
- `tools/enemy_phase_contract_probe.gd`

Quatre logs exacts existent : `nathenian2`, `bronze_colossus`, `giant_veteran`, `nfull_armor`. Aucun log ne contient `ENEMY_PHASE_CONTRACT_PROBE PASS id=warlord`. Sa propre fiche dit que le pattern phase 2 de deux actions n'est pas déroulé automatiquement et classe le cycle phase 2 instrumenté parmi les extensions souhaitables. La gate `PASS 5/5` est donc sans support.

**Action exacte :** exécuter `enemy_phase_contract_probe.gd -- --id=warlord`, conserver le log dans `.tmp_tools/enemy_refactor/logs/`, vérifier transition unique, annulation atomique du windup, multiplicateurs et cycle exact des deux actions, puis seulement rétablir `5/5`.

### P1 — La stabilité multi-rechargement et le cleanup process-wide ne sont pas établis

Fichiers/logs :

- `docs/enemy_refactor/PERFORMANCE.md:29-36,182-190`
- `tools/enemy_performance_benchmark.gd:168-214`
- `tools/enemy_action_cpu_benchmark.gd:118-150`
- `.tmp_tools/enemy_refactor/mission_final_action_*.log`

Le teardown structurel est correctement défini comme zéro `WeakRef` ennemi/auxiliaire et retour des groupes; il passe. Il n'impose pas le retour d'`OBJECT_COUNT` ou de la mémoire au niveau initial. Les trois finals callback finissent à `1622/1623/1637` objets contre `1549` avant. Cela peut être un cache moteur légitime, mais aucune campagne de plusieurs chargements/déchargements n'établit un plateau. `PERFORMANCE.md` conserve d'ailleurs le harness trois cycles comme `Pending`.

**Action exacte :** ajouter une gate de 3 à 10 cycles identiques, préchauffer le premier cycle, puis exiger stabilité des nœuds/orphelins, `WeakRef`, groupes, objets et mémoire avec tolérance explicitée. Séparer cache initial, plateau et croissance monotone. Ne résumer la preuve actuelle que comme « teardown structurel », jamais comme absence globale de fuite.

### P2 — Le dernier changement central n'a pas de corpus brut complet post-intégration

Le passage de `EnemyNavigationComponent` de `Node` à `RefCounted` date de 04:46, après la majorité des logs par ID, du stress mixte et des captures. La contre-revue architecture a depuis relancé les probes communs et rapporte leur succès, ce qui réduit le risque fonctionnel. Cependant, aucun nouveau corpus brut 22 comportements/22 démembrements/roster/stress/LOD n'est archivé après ce dernier changement.

**Action exacte :** rejouer et journaliser la matrice finale après le dernier hash central : navigation composant/navmesh, full roster, mixed stress, lifecycle, LOD, puis behavior et dismemberment pour les 22 IDs. Enregistrer le hash des fichiers centraux dans un manifest de run.

### P2 — Les métriques rendues n'ont pas de log source traçable

`final_metrics.json` publie `359` draw calls Forge et `1149` Lab, mais aucun fichier sous `.tmp_tools` ne contient `ENEMY_LAB_FORGE_RENDER_METRICS_JSON`. Les logs Lab/Forge disponibles précèdent l'ajout de cette sortie au probe. Les images ont bien été régénérées après modification du probe, mais l'origine des nombres ne peut pas être recalculée depuis les artefacts conservés.

**Action exacte :** relancer les deux contextes avec `--log-file` explicite, conserver les deux JSON bruts et référencer leurs chemins/hashes dans `final_metrics.json`. Maintenir l'absence actuelle de revendication de gain GPU.

### P2 — Le ledger ne possède toujours pas les 22 lignes finales prescrites

`ORCHESTRATION_LEDGER.md` contient une synthèse `DONE 22/22`, suivie du seul tableau détaillé par ID où les 22 statuts restent `AUDITING` et où Visuel/Démembrement/Revue valent souvent `non`. L'explication « historique » évite l'ambiguïté humaine, mais ne respecte pas le format persistant demandé par la mission et gêne tout contrôle machine.

**Action exacte :** ajouter un tableau final de 22 lignes avec Agent, Audit, tests, implémentation, visuel, démembrement, perf, revue et statut courant. Déplacer le tableau initial dans un fichier/appendice explicitement historique.

### P2 — Le probe comportemental exact court-circuite le timing intégré

`enemy_unit_behavior_probe.gd:68-93` appelle directement `_begin_ai_attack()` puis `_resolve_ai_attack()` après avoir désactivé `_physics_process()`. Il valide très utilement pattern, scheduler, interruption et leases, mais pas windup réel, cooldown, hit frame, locomotion concomitante ou sortie automatique de FSM. Le qualifier « exact » doit rester limité à ces contrats.

**Action exacte :** ajouter un probe intégré à temps simulé/réel par famille qui laisse `_physics_process()` actif, observe la télégraphie, interdit tout dommage avant la fenêtre, exige un impact pendant la fenêtre et une sortie de récupération bornée.

### P3 — Les documents historiques contredisent encore la synthèse finale

`MIGRATION_MATRIX.md`, `CURRENT_STATE.md` et les sections détaillées historiques de `REGRESSION_MATRIX.md` conservent des états `characterized/pending` désormais dépassés. La mention « superseded » aide, mais les documents sont encore présentés comme matrices courantes.

**Action exacte :** les renommer ou les marquer en en-tête `HISTORIQUE — NON AUTORITAIRE`, puis faire de la matrice finale et du ledger final les deux seules sources de statut.

## Vérifications positives

- `roster_manifest.json` contient exactement 22 IDs uniques, tous `DONE`; 22 fiches distinctes existent et portent `DONE` sans `BLOCKED` courant.
- Un log `ENEMY_UNIT_BEHAVIOR_PROBE PASS id=...` existe pour chacun des 22 IDs.
- Un log `ENEMY_UNIT_DISMEMBERMENT_PROBE PASS ... zones=12 severed=10` existe pour 22/22; celui de `spearman` est conservé dans `%TEMP%` plutôt que dans le workspace.
- La matrice Mixamo couvre bien les sept pools directs : 20 variantes et 240 zones cumulées.
- Les deux benchmarks `refcount` reprennent build, renderer, seed, comptes, ordre, warm-up et sample de la baseline; les 16 scénarios ont `structural_cleanup.ok=true`, zéro orphelin au snapshot et zéro référence ennemie vivante.
- La conversion navigation vers `RefCounted` ramène les nœuds swordsman à la parité baseline; elle n'est pas présentée comme une réduction de qualité visuelle.
- Le seuil `total_count >= 28` est inchangé par rapport à `HEAD` dans `scripts/world_editor/world_runtime.gd`.
- Aucun gain GPU/VRAM avant-après n'est revendiqué; les valeurs rendues sont annoncées comme diagnostics actuels.
- Aucun donneur ou asset source non prouvé n'a été supprimé.

## Conditions minimales de passage à PASS

1. Fermer les quatre P1 de la revue architecture/navigation et obtenir sa réévaluation `PASS`.
2. Remplacer la comparaison callback v1/v2 par une campagne réellement homogène, ou supprimer tous les pourcentages de gain et déclarer la performance CPU comparative non prouvée.
3. Exécuter et archiver la phase exacte `warlord`.
4. Rejouer une matrice globale brute après le dernier changement central, incluant 22 comportements et 22 démembrements.
5. Produire la couverture visuelle temporelle manquante par ID, plus des preuves Lab/Forge lisibles en action.
6. Ajouter une gate multi-rechargement et qualifier strictement le teardown actuel de structurel.
7. Corriger le ledger final et le tableau avant/après obligatoire; tout champ sans baseline doit être explicite et empêcher une fausse clôture.

---

Revue effectuée contre Godot 4.7+ avec `using-godot-prompter`, `godot-code-review`, `godot-debugging`, `godot-optimization` et `godot-testing`.
