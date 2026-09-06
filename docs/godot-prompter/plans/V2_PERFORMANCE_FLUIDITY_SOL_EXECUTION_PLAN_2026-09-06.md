# V2 — plan d’exécution performance, fluidité et ressenti pour SOL

Date : 6 septembre 2026. Statut : **plan préparé ; aucun lot d’implémentation exécuté par cette passe**.

## 1. Mission et mode d’emploi

Préparer la fondation V2 pour la suite des migrations : obtenir des mesures fiables, supprimer le travail inutile, stabiliser les temps de frame, alléger les packages et préserver la réactivité, les formations, les armes et le démembrement.

Ce document est une instruction de travail pour une prochaine demande d’exécution. La présente demande autorise sa rédaction, pas la modification du gameplay. Lors de son exécution, ne pas interpréter « préparer les migrations » comme une autorisation de remplacer toutes les unités de production V1.

Racine du projet : `C:/Users/suean/Downloads/hoplite_ual_native_lab_v2`. Les identifiants `res://` ci-dessous désignent des ressources dans cette racine. Les noms de nouveaux fichiers sont des propositions, pas des fichiers déjà présents.

### Résultat attendu de SOL

1. Une base de comparaison reproductible, conservée hors des seuls caches `.godot`.
2. Des corrections de validité avant les optimisations qui pourraient masquer les bugs.
3. Des gains mesurés par lot, avec qualité et contrats fonctionnels préservés.
4. Des packages optimisés reproductibles sans supprimer les sources.
5. Une liste explicite : réalisé / testé / visuellement vérifié / gain non concluant / reporté avec raison.
6. Une décision argumentée de préparation à la migration pour chaque famille V2 actuelle, sans migration globale implicite.

### Règles impératives de conduite

- Lire `AGENTS.md`, puis `using-godot-prompter`. Charger les skills de chaque lot au moment de le traiter, pas tout le catalogue d’un coup.
- Employer `godot-debugging` pour une régression et `godot-code-review` pour relire chaque lot conservé. Utiliser les probes GDScript existants ; ne pas installer un framework de tests pour ce chantier.
- Travailler seul tant que l’utilisateur ne demande pas explicitement de délégation. L’ancien plan d’audit contient une étape de sous-agents historique : elle n’est pas reconduite ici.
- Préserver les modifications non commitées et les fichiers non suivis, notamment compétences, joueur, caméra, combat, runtime battlefield et tests récents.
- Ne pas faire de reset, stash global, changement de branche, commit englobant le travail utilisateur, publication de carte dans `user://` ou suppression d’assets sources.
- Un lot = un problème défini, une preuve avant, un changement borné, une preuve après. Ne pas modifier simultanément résolution, renderer, distances LOD, géométrie et logique pour annoncer un gain global.
- Ne pas migrer vers C#, GDExtension, une architecture ECS, des threads de simulation ou un autre renderer dans ce chantier. Ces alternatives demanderaient un audit distinct.
- Ne pas réduire silencieusement la population, les tirs NPC, les animations proches, le démembrement, la portée des attaques ou les effets importants du joueur.
- Ne pas réduire le tick physique global ni changer les commandes du joueur comme « optimisation ».
- Ne pas inventer un gain GPU à partir de timings headless, ni additionner des moniteurs CPU qui se recouvrent.
- Une fonctionnalité utile mais non mesurée n’est pas un gain démontré. Une alternative qui dégrade la qualité reste expérimentale et désactivée par défaut.
- Si une étape exige un choix artistique, une modification perceptible du gameplay ou une autorité supplémentaire, terminer les vérifications indépendantes puis demander ce choix. Ne pas remplacer cette décision par un réglage arbitraire.

## 2. Documents de référence et corrections de lecture de l’audit

Commencer par le [point d’entrée V2](C:/Users/suean/Downloads/hoplite_ual_native_lab_v2/docs/enemy_refactor/README.md), puis le [contrat de composition et des armées](C:/Users/suean/Downloads/hoplite_ual_native_lab_v2/docs/enemy_refactor/V2_COMPOSITION_AND_ARMIES.md).

Lire ensuite, dans cet ordre :

1. `res://docs/enemy_refactor/ENEMY_V2_ROLE_COMPONENTS.md`.
2. `res://docs/enemy_refactor/V2_FORMATION_TRAFFIC_CONTRACT.md`.
3. `res://docs/enemy_refactor/GIANT_V2_MINIBOSS_INTEGRATION_2026-09-05.md`.
4. `res://docs/enemy_refactor/COMBINED_ARMS_INTEGRATION_2026-09-05.md` pour la carte 414 et ses mesures historiques.
5. `res://docs/godot-prompter/plans/player_camera_audit_2026_09_06.md` et `combat_lock_audit_2026_09_06.md`, pour ne pas réintroduire les bugs corrigés.
6. Les packages actuels et les probes du lot avant de modifier son code.

Les rapports `FINAL_ENEMY_OPTIMIZATION_REPORT.md`, `CURRENT_STATE.md` et la matrice historique ne prouvent pas que toutes les identités V1 sont migrées dans la nouvelle V2. Le « DONE 22/22 » ancien concerne une autre passe. Les rapports historiques ne doivent pas supplanter les contrats actuels et le code.

### Ce que la relecture confirme

- Corps hoplite partagé, rig 23 os, animations bakées et bibliothèques mises en cache par combinaison de packs : améliorations structurelles réelles.
- Hoplites, fantassins et archers partagent le corps, mais composent leurs armes et leurs rôles ; ne pas réintroduire des branches par arme dans l’acteur central.
- La grande majorité de l’armée 414 utilise le déplacement de troupe, pas un `move_and_slide()` par soldat.
- Anatomie exacte/coarse limitée autour du joueur ; les centaines d’acteurs éloignés ne mettent pas tous leurs hitboxes à jour à pleine cadence.
- Trois atlas d’imposteurs par rôle et batches partagés existent. « culled » dans l’ancien compteur LOD signifie niveau 3, pas nécessairement absence de représentation.
- Les LOD réduisent fortement les primitives mais pas les huit surfaces actives du lancier mesuré.
- Le système audio possède déjà un pool de 14 lecteurs ; le fader évite déjà les réécritures de matériaux stabilisés. Ne pas réimplémenter ces gains.

### Ce qu’il faut rectifier ou traiter comme hypothèse

| Point | Lecture correcte et conséquence pour le plan |
|---|---|
| « L’animation coûte environ 5 ms » | Non établi. Le probe arrête aussi le composant LOD ; les étapes se succèdent sur une bataille qui évolue. Faire un vrai A/B isolé. |
| « Couper l’anatomie n’aide pas » | Non établi. Les callbacks LOD peuvent réactiver son état ; l’étape 15 Hz commence par l’activer sur tous les acteurs. Vérifier l’état effectif pendant toute la fenêtre. |
| « Le seuil 2 ms borne le service » | Faux comme plafond dur : une opération déjà commencée et le snapshot synchrone peuvent le dépasser. Mesurer le dépassement et la durée des unités de travail. |
| « 1 360 draws = le décor » | Il s’agit du résiduel monde + joueur + UI + autres passes de cette étape, pas du décor isolé. Mesurer séparément. |
| « Le LOD automatique fait doublon inutilement » | Pas une conclusion générale. Godot permet son cumul avec les LOD manuels ; comparer le rendu et le coût avant de désactiver quoi que ce soit. |
| « Les marges LOD font un fondu doux » | Le code utilise `VISIBILITY_RANGE_FADE_DISABLED` : marges d’hystérésis, pas crossfade. Ne pas promettre un fondu absent. |
| « Une mesh propre suffira » | Elle peut réduire import, spawn, surfaces et géométrie ; elle ne corrige pas l’ordonnancement, les allocations, les morts persistantes ou les pics VFX. |
| « Le géant n’a aucun LOD » | Son package déclare `source_import_generated`. Il n’a pas la chaîne manuelle complète ni l’imposteur des hoplites ; ce n’est pas une absence totale de LOD. |
| « Une mesh d’équipement liée aux mains garde les poses » | Pas pour tout l’équipement actuel : le bouclier est volontairement ancré dans l’espace acteur. Le fusionner rigidement sur l’avant-bras casserait ce contrat. |
| « Baisser les Hz/distances est une optimisation équivalente » | C’est un compromis de qualité. Garder la référence actuelle avant d’évaluer un éventuel preset distinct. |

La coexistence LOD automatique/manuels et la sélection automatique dépendante de l’écran sont documentées par Godot : [mesh LOD](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html). Le comportement des marges sans fondu est décrit dans [visibility ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html). Vérifier les API dans la version installée avant toute implémentation.

## 3. Mesures historiques à conserver, pas à présenter comme nouvelle baseline

Environnement du relevé graphique précédent : Godot 4.7, OpenGL Compatibility, RTX 4060 Laptop GPU, 1 280 × 720. Relever à nouveau pilote, moteur exact, alimentation, fréquence, fenêtre et paramètres au lot 00.

| Scénario historique | Moyenne frame | p95 frame | Draw calls | Primitives | Limite |
|---|---:|---:|---:|---:|---|
| Carte 414 complète | 16,444 ms | 19,234 ms | 2 939 | 1 919 829 | 90 frames, vue initiale, pas une longue mêlée |
| Même probe, étape finale sans ennemis visibles/actifs | 4,032 ms | 4,749 ms | 1 360 | 667 751 | Pas un A/B, résiduel non isolé |
| 24 hoplites proches, présentation seule | 1,753 ms | 2,954 ms | 192 | 620 976 | Combat désactivé |
| 60 hoplites proches superposés, présentation seule | 3,869 ms | 5,041 ms | 480 | 1 552 440 | Fixture artificielle |
| 60 hoplites à distance, présentation seule | 0,963 ms | 1,327 ms | 480 | 191 400 | Autres seuils LOD, pas attribution au seul LOD manuel |

Carte 414, relevé complet : 24 LOD0, 68 LOD1, 182 LOD2, 140 niveau 3 ; cinq acteurs en physique individuelle, 409 en mouvement de troupe ; anatomie exacte 4, coarse 4, off 406 ; 21 431 nœuds au total, pas seulement ennemis.

Stress 661 headless, 600 frames : médiane 29,59 ms, p95 51,915 ms, service battlefield pic 11 195 µs. Ces temps muraux n’établissent ni le coût GPU ni le FPS d’une session graphique isolée. Le probe impose actuellement `Engine.max_fps = 60` : son attente entre frames inclut ce plafond quand la charge est assez faible. Les populations vivantes peuvent évoluer pendant le chargement. Pour mesurer la capacité CPU, utiliser un mode de performance distinct sans ce plafond, avec durée de simulation contrôlée ; conserver le mode fonctionnel historique séparément.

Sources locales : `.godot/audit_battlefield_render_2026-09-06.log`, `.godot/audit_hoplite_performance_2026-09-06.log`, `.godot/audit_battlefield_stress_2026-09-06.log`. Ces caches peuvent disparaître : en extraire les résultats pertinents dans le rapport d’exécution avec provenance et limites, sans renommer les anciens résultats en « avant » d’un code ultérieur.

### Inventaire mesh à revérifier avant génération

Les chiffres Blender proviennent de l’audit précédent ; régénérer un rapport machine-readable au lot 03/10 avant transformation.

| Asset | Géométrie source relevée | Implication |
|---|---|---|
| Corps hoplite LOD0 / 1 / 2 | 22 820 / 8 127 / 2 560 triangles ; 17 957 / 8 894 / 4 014 sommets | Une chaîne existe déjà ; ne pas repartir de zéro par défaut |
| Corps hoplite | 2 matériaux ; 23 os ; 3 UV dont canal sémantique de zones | Préserver rig, atlas et masques de démembrement |
| Chaque GLB de corps | 13 objets / 11 meshes dont helpers/caps ; retrait runtime des éléments inutiles | Nettoyage export pour réduire l’assemblage, pas promesse de gain steady-state équivalent |
| Dory | 1 860 triangles, 3 matériaux | Première cible d’atlas à une surface |
| Aspis | 3 956 triangles, 3 matériaux | Préserver ancrage acteur et bouclier détachable |
| Xiphos | 6 334 triangles, 4 matériaux | Budget disproportionné pour l’équipement distant ; vérifier les LOD importés |
| Arc | 288 triangles, 3 meshes / 3 matériaux | La multiplication des surfaces importe davantage que ses triangles |
| Géant source | 79 177 triangles, 237 493 sommets, 10 parties, 53 os, 18 caps | Examiner les splits de sommets et attributs avant de décider une retopologie complète |

Les textures hoplite 4K sont partagées : leur taille sur disque n’est ni leur consommation GPU ni un coût multiplié par acteur. Une réduction de résolution doit avoir son propre test de mémoire et sa comparaison visuelle.

## 4. Architecture à conserver et alternatives retenues

Choix recommandé : **optimisation incrémentale de la V2 existante**.

- Option A, retenue : nettoyer les packages, réduire les surfaces, améliorer les cadences et les files de travail, maintenir les interfaces actuelles. Risque limité et preuves séparables.
- Option B, conditionnelle : packages LOD distants fusionnés par rôle, seulement après un premier gain par équipement modulaire et preuve des masques/poses. Complexité supérieure.
- Option C, reportée : refaire tous les personnages, changer de renderer ou de technologie de simulation. Trop de variables et aucune preuve actuelle que cela traite le facteur limitant principal.

### Propriété des données

| État | Propriétaire / contrat |
|---|---|
| Santé, mort, démembrement, équipement perdu | Acteur et composants existants ; jamais les meshes ou l’imposteur |
| Position, vitesse et dégâts autoritaires | Simulation existante ; l’interpolation visuelle n’écrit pas ces états |
| Intention de groupe et slots | Troop runtime / commandement existants ; un scheduler ne réécrit pas la doctrine |
| Cible et appartenance/faction | Service et acteur selon contrat actuel ; valider références et engagements |
| LOD de représentation | Politique visuelle cohérente avec la caméra de rendu |
| Précision de simulation/combat | Proximité/interactions pertinentes, pas seulement visibilité caméra |
| Ressources de corps, matériaux, clips | Cache immuable partagé, indexé par package/version/variante utile |
| Durée des débris et cadavres | Cycle de vie explicite, nettoyable lors du changement de monde |
| Effets locaux de caméra et temps ralenti | Propriétaires existants ; pas de deuxième système concurrent |

Ne pas ajouter de nouvel autoload global pour un service qui appartient à un monde. Les éventuels schedulers sont enfants du runtime de monde ou des services existants, avec enregistrement et désenregistrement explicites.

Flux cible : spawn → enregistrement → décisions de groupe → simulation due → pose/affichage → mort unique → sortie immédiate du combat → présentation de mort → repos → retraite visuelle/nettoyage. Les signaux de mort et victoire ne doivent pas attendre la suppression graphique du cadavre.

## 5. Ordre d’exécution et critères transversaux

| Lot | Priorité | Dépendances | Nature |
|---|---|---|---|
| 00 — sécurité, baseline et banc A/B | Bloquant | Aucune | Obligatoire |
| 01 — horloges d’animation et transitions LOD | Haute | 00 | Reproduire puis corriger |
| 02 — morts, nettoyage et accumulation | Haute | 00–01 | Mesurer et stabiliser |
| 03 — package hoplite propre / spawn | Haute | 00 | Gain structurel à quantifier |
| 04 — surfaces et équipement LOD | Haute | 03 | Modulaire d’abord, fusion conditionnelle |
| 05 — ordonnancement simulation/animation | Haute | 01–02, instrumentation 00 | Optimisation CPU |
| 06 — snapshots, ciblage et requêtes spatiales | Haute | 00, coordination avec 05 | Optimisation CPU / pics |
| 07 — VFX, audio et scans de compétences | Haute en mêlée | 00, API de 06 si utilisée | Réduction des pics |
| 08 — cohérence visuelle LOD et interpolation | Haute pour la fluidité | 01, 04–05 | Qualité et temps de frame |
| 09 — rendu monde résiduel | Selon profil | 00 | Optimisation ciblée |
| 10 — package géant | Haute avant migration géants | 00, 03–04 comme outillage | Famille distincte |
| 11 — validation du ressenti | Obligatoire | Lots conservés ci-dessus | Preuves automatiques + revue visuelle |
| 12 — campagne finale et gates migration | Bloquant | Lots retenus validés | Handoff, pas migration globale |

Suivre cet ordre par défaut ; si le profil désigne un autre facteur limitant, documenter la permutation. Un lot conditionnel peut être rejeté avec preuve : « traité et rejeté » est préférable à une complexité sans bénéfice.

### Acceptation commune

- Zéro nouvelle erreur de script, référence libérée ou comportement régressé dans les scénarios concernés.
- Mesures à configuration et charge comparables ; aucune « amélioration » issue d’une baisse cachée de qualité.
- Petits gains sous le bruit : résultat non concluant, pas pourcentage marketing. Conserver une simplification si elle apporte un avantage structurel démontré sans régression, en la qualifiant ainsi.
- Pour un gain mesurable, viser une baisse répétée du p95 et des pics pertinents, pas seulement du temps moyen. Si régression répétée > 5 % sur un scénario critique, investiguer avant acceptation ; ce seuil est un garde-fou proposé, pas une loi statistique.
- Cible de travail proposée : 60 FPS sur le scénario 414 de référence, donc p95 ≤ 16,67 ms, avec p99 et frames > 25/33,3 ms également publiés. Cela n’est ni un objectif utilisateur confirmé pour toute machine ni une garantie pour 661 unités.
- Ne pas valider cette cible avec une seule fenêtre de 90 frames. Les longues mêlées, spawns et ultimes doivent figurer dans les résultats.
- Toute approbation visuelle non réalisée doit rester `pending_visual_review`, jamais `PASS` supposé.

## 6. Lot 00 — protéger l’état et construire une mesure causale

Skills : `godot-optimization`, `godot-debugging`, `godot-testing`, `godot-code-review`.

### 00.1 — Capturer l’état réellement testé

- [ ] Lire `git status --short`, le diff ciblé et les changements depuis ce plan.
- [ ] Capturer commit HEAD + liste dirty/untracked + empreintes des scripts/assets/configs réellement consommés. HEAD seul ne décrit pas ce projet.
- [ ] Consigner les tests déjà rouges et les avertissements connus avant toute correction.
- [ ] Vérifier les processus Godot en cours. Ne pas fermer une session utilisateur ; arrêter uniquement les processus lancés par cette campagne et identifiés par leur PID.
- [ ] Consigner moteur/build, renderer, GPU/pilote, résolution, VSync, plafond FPS, focus de fenêtre, mode alimentation et état debug.
- [ ] Relever les paramètres effectifs APRÈS construction du monde et application différée des réglages UI. Distinguer carte 414 (10/26/65 m ; 24/10 Hz ; zone pleine cadence 3 m) des défauts de présentation (16/38/90 m ; 30/12 Hz).
- [ ] Ne pas modifier les préférences utilisateur pour obtenir une baseline. Si le harness doit isoler leur chargement/sauvegarde, prévoir une injection limitée au test et documentée ; ne pas inventer une option CLI non supportée.

### 00.2 — Corriger le protocole du probe, sans optimiser le jeu

Point de départ : `res://tools/enemy_v2/hoplite_v2_battlefield_render_cost_probe.gd`.

- [ ] Conserver ses anciens résultats comme historiques et ajouter un mode indépendant par scénario, ou un nouveau runner explicitement versionné.
- [ ] Chaque variante reconstruit son monde dans un processus frais ; une seule variable diffère entre A et B.
- [ ] Deux catégories distinctes : fixture de rendu figée avec même pose/caméra/population ; bataille dynamique avec même seed, entrées enregistrées et durée de simulation comparable.
- [ ] Une seed seule ne rend pas la bataille déterministe : tracer spawns, morts, engagements et horloges utilisées, vérifier la comparabilité des populations/événements. Utiliser les fixtures figées pour l’attribution causale fine et plusieurs runs pour les scènes dynamiques.
- [ ] Dans la fixture, figer les décisions des DEUX variantes, pas seulement de celle dont on veut mesurer l’animation. Vérifier positions, poses et compteurs avant échantillonnage.
- [ ] Une ablation d’animation ne coupe pas le service LOD. Une ablation de physique ne coupe pas l’exécuteur de toutes les formations. Nommer précisément ce qui est coupé.
- [ ] Les ablations doivent résister aux refresh LOD : assertions par frame sur l’état effectif, ou politique de test explicite. Ne pas ajouter un contournement permanent dans le gameplay sans nécessité.
- [ ] Fixer les phases par seed/identité stable de fixture, pas seulement par `instance_id`, qui peut différer entre processus.
- [ ] Attendre fin des spawns et état attendu des imports/resources. Puis au moins 120 frames de chauffe pour les fixtures.
- [ ] Mesurer au moins 600 frames pour les fixtures ; pour les batailles, utiliser en plus une durée de simulation définie, par exemple 30 s, pour ne pas comparer deux moments différents selon le FPS.
- [ ] L’ancien argument `--sample-frames` est borné à 360 : l’étendre explicitement si conservé. Ne pas prétendre obtenir 600 frames en lui passant 600 sans corriger le harness.
- [ ] Conserver les temps bruts dans CSV/JSON, pas uniquement des moyennes. Ne pas imprimer chaque frame pendant la mesure.
- [ ] Ordre A/B puis B/A alterné, minimum cinq exécutions indépendantes par variante pour une décision finale ; commencer avec trois lors des itérations coûteuses et compléter avant verdict.
- [ ] Une seule mesure de performance à la fois, fenêtre graphique non minimisée. Ne pas additionner la charge d’un éditeur en jeu, d’un autre benchmark et d’un bake Blender.

### 00.3 — Matrice minimale

| Fixture | But | Variations à isoler |
|---|---|---|
| Présentation 1 / 24 / 60 | Corps, gear, surfaces, animation | Proche, LOD1, LOD2, rôle lance/épée/arc |
| Distribution espacée / superposée | Distinguer visibilité et surdessin | Caméra et géométrie constantes dans chaque paire |
| Carte 414 | Compatibilité fronts + coût total | Vue initiale, traversée, mêlée, retour éloigné |
| Deux armées adaptatives | Contrat actuel, pas seulement ancienne carte | Alliés/ennemis/élites, missions, NPC contre NPC |
| Stress 661 | Scaling CPU, files et équité | Headless pour contrat puis rendu séparé si faisable |
| Spawn 1 / 24 / 414 | Latence froide et amortie | Sans puis avec ressources déjà chargées |
| Morts répétées | Accumulation et nettoyage | 5 vagues, retour caméra, teardown monde |
| Compétences | Pics courts | Spirale, feu, Tonnerre, projectiles en bataille |
| Géants 1 / 2 / 5 | Package et comportement propre | Proche/loin, amputations, mort |
| Monde sans armée | Résiduel | Joueur/UI/contours/foliage isolés successivement dans des runs frais |

### 00.4 — Instrumentation à ajouter seulement où nécessaire

- Mesurer régions exclusives et inclusives en les nommant : ordonnanceur, dispatch membres, intégration mouvement, décisions groupe, terrain/trafic, leases, snapshot, ciblage, animation, VFX.
- Compter appels et éléments réellement traités, backlog, retard maximal, reconstructions et allocations d’objets si observables. Ne pas inférer les allocations d’un simple nombre de `Dictionary` dans le source.
- Relever p50/p95/p99/max frame, frames > 16,67/25/33,3 ms, draw calls, primitives, nœuds, objets actifs, meshes/surfaces, population vivante/morte, distributions LOD et mémoire disponible par moniteur.
- Distinguer mémoire partagée, instance et pic de spawn. Si la mémoire GPU n’est pas accessible avec les outils disponibles, écrire `non mesurée`.
- Profiler CPU/GPU séparément lorsqu’accessible. La durée d’attente de `process_frame` reste un temps mural, pas un chronomètre GPU.
- Désactiver les mesures fines hors développement et vérifier leur propre overhead.

Livrables proposés : `res://docs/enemy_refactor/performance_2026_09_06/baseline.json`, résultats bruts versionnés et `res://docs/enemy_refactor/V2_PERFORMANCE_EXECUTION_REPORT_2026-09-06.md`. Ne pas écraser des fichiers homonymes existants sans les lire.

Gate : mêmes fixtures reproductibles, paramètres réellement vérifiés, verdict de bruit documenté. Sans cela, pas de réécriture CPU large.

## 7. Lot 01 — vérifier les horloges avant de réduire les fréquences

Skills : `animation-system`, `godot-testing`, `godot-debugging`, `godot-optimization`.

Fichiers : `res://scripts/enemy_v2/hoplite_v2_lod_component.gd`, `hoplite_v2_animation_component.gd`, et consommateurs de l’état d’animation/attaque.

### Risque repéré dans le code actuel

`_sample_animation()` avance le lecteur de tout `animation_accumulator`, puis conserve `fmod(accumulator, interval)`. Ce reste déjà avancé est ajouté à la période suivante. De plus, une phase artificielle est injectée dans le même accumulateur au changement de LOD. Le déphasage d’ordonnancement ne doit pas devenir du temps d’animation fictif.

- [ ] Écrire d’abord un test qui mesure la somme des deltas réellement passés à `AnimationPlayer.advance()`.
- [ ] Tester 30/60/144 Hz de frames, fréquences 24/10 et 30/12 Hz, phases 0/0,37/0,99, puis deltas irréguliers et une frame de 120 ms.
- [ ] Exemple de reproduction : frames à 60 Hz, échantillonnage 24 Hz. Si le lecteur avance 0,05 s puis conserve un reliquat de 0,00833 s, ce reliquat ne doit pas être compté deux fois.
- [ ] Invariant : temps avancé + temps réel non encore consommé = temps de jeu écoulé depuis le dernier reset, à l’erreur numérique près. Le nombre d’appels suit la cadence mais ne change pas la vitesse du clip.
- [ ] Séparer l’échéance de prochain échantillon et le temps non consommé. Option simple : consommer tout le temps réellement accumulé puis le remettre à zéro, avec échéance indépendante pour le déphasage. Autre option : consommer uniquement les pas complets et garder leur reste. Choisir UNE convention et la tester.
- [ ] Tester entrée LOD1/2, retour LOD0, réveil imposteur, changement de clip, `speed_scale`, pause et ralentissement. Distinguer temps réel du feedback et temps de jeu de la simulation.
- [ ] Vérifier signaux de fin, pistes d’appel éventuelles, engagement/impact/récupération ; aucun impact doublé ni attaque terminée prématurément après rattrapage.
- [ ] Mettre à jour immédiatement la cadence lors d’un changement de settings, même si le niveau LOD reste identique.
- [ ] Ne pas réduire les Hz pour rendre le bug moins visible.

Tests existants à rejouer : runtime LOD, combat hoplite, rôles, imposteurs. Nouveau test proposé : `res://tests/enemy_v2_animation_clock_test.gd`.

Gate : conservation du temps démontrée sur toutes les séquences, cadence correcte, parité des fenêtres de dégâts proches. Publier correction de validité séparément du gain CPU.

## 8. Lot 02 — borner le coût des morts sans effacer le spectacle

Skills : `component-system`, `animation-system`, `physics-system`, `godot-testing`, `godot-optimization`.

Fichiers : `res://scripts/enemy_v2/enemy_actor_v2.gd`, `giant_v2_actor.gd`, `hoplite_v2_troop_runtime.gd`, `hoplite_v2_impostor_batch.gd`, `res://scripts/world_editor/world_runtime.gd`, composants santé/gore/débris.

- [ ] Instrumenter vivant, mort en animation, cadavre stabilisé, débris actifs, inscriptions dans les registres et nœuds après chaque vague.
- [ ] Reproduire mort en LOD0/1/2/3 et retour caméra. Un acteur sorti du batch distant avec son LOD arrêté ne doit pas rester dans un état incapable de rejouer/montrer correctement sa mort.
- [ ] Garantir `died` une seule fois, libération immédiate des leases et des cibles, arrêt des colliders de combat et sortie des groupes actifs.
- [ ] Ne pas annuler une flèche déjà tirée ni sa réservation utile à cause de la mort du tireur.
- [ ] Clarifier si le cadavre doit jouer jusqu’à la fin du clip, puis se figer. Prévoir timeout de sécurité pour clip absent/interrompu ; le timer fixe actuel de 2,45 s ne remplace pas une vérification de la pose.
- [ ] La pose figée conserve masques, membres sectionnés et équipement perdu. Aucun corps complet ne réapparaît lors d’un passage LOD.
- [ ] Vérifier `_ground_death_pose()` sans dérive cumulée, avec terrain en pente, échelles et corps partiellement amputé.
- [ ] Première amélioration sans choix artistique : arrêter les traitements inutiles après stabilisation et nettoyer les index d’actifs tout en conservant le cadavre visible.
- [ ] Ensuite seulement, évaluer une politique de retraite bornée des cadavres : priorité aux anciens hors champ, protection de la mort récente et proche, seuils configurables et hystérésis. Présenter durée/population proposées et comparaison visuelle avant activation par défaut.
- [ ] Ne pas figer un cadavre en fabriquant une nouvelle mesh coûteuse à chaque décès sans benchmark ; commencer par conserver sa pose et arrêter ses updates.
- [ ] Conserver le TTL existant du géant (18 s) tant qu’une politique commune ne prouve pas la même intention visuelle. Ne pas raccourcir arbitrairement sa présence.
- [ ] Vérifier les callbacks différés, timers et références faibles après `clear_world`, suppression d’un groupe, chargement d’une nouvelle carte et sortie du jeu.
- [ ] Éviter une reconstruction de tous les slots à chaque décès simultané : mesurer le chemin `unregister_member`, regrouper les invalidations si nécessaire, préserver les brèches et délais tactiques existants.

Tests proposés : `enemy_v2_corpse_lifecycle_test.gd`, vague de morts groupées, suppression de groupe pendant un callback, morts distantes puis approche. Rejouer `battlefield_freed_target_regression_test.gd`, crash regression et combined arms.

Gate : pas de croissance des inscriptions actives après chaque vague ; charge des cadavres stabilisée et explicitée ; teardown sans référence invalide. Si conservation illimitée visuelle reste la politique produit, ne pas déclarer une mémoire totale bornée.

## 9. Lot 03 — nettoyer le package hoplite et le chemin de spawn

Skills : `assets-pipeline`, `3d-essentials`, `animation-system`, `godot-testing`, `godot-optimization` ; `3dblender` si production/modification d’un script Blender.

Fichiers : `res://scripts/enemy_v2/hoplite_v2_presentation_component.gd`, `res://scripts/enemy_v2/enemy_v2_definition.gd`, `res://assets/characters/enemy_v2/hoplite/hoplite_v2.package.json`, `res://tools/enemy_v2/build_hoplite_lod1.py`, `audit_lod_candidate.py`, générateurs existants d’atlas/fragments.

### 03.1 — Contrat d’export avant transformation

- [ ] Relire les scripts existants et vérifier leurs arguments ; `audit_lod_candidate.py` utilise `--input` et `--report`.
- [ ] Créer un inventaire JSON des objets, meshes, surfaces, triangles, sommets, os/rest poses, weights, UV, textures, caps et animations pour chaque source.
- [ ] Identifier les consommateurs des caps/helpers avant suppression du package RUNTIME. Le fait qu’un helper ait une échelle nulle ne prouve pas qu’il est inutile à toute la chaîne de génération.
- [ ] Préserver les GLB/BLEND sources, caps de section et fragments ; écrire des candidats dans un répertoire dédié.
- [ ] Ne pas renommer les 23 os, changer leur ordre/rest pose ni appliquer une transformation de rig sans retester toutes les bibliothèques.
- [ ] Préserver les trois canaux UV et les valeurs sémantiques de zones. Ne pas réutiliser `TEXCOORD_2` pour un atlas d’équipement par commodité.
- [ ] Vérifier absence de vertices sans poids, poids invalides, normales inversées, échelle négative et triangles dégénérés ; les suppressions doivent être justifiées et comparées.

### 03.2 — Package runtime léger

- [ ] Exporter uniquement corps/rig requis pour la présentation normale ; conserver caps/fragments dans leurs ressources séparées existantes.
- [ ] Faire en sorte que les meshes LOD partagent UN squelette runtime. Le système le fait déjà après assemblage : le gain visé concerne la construction et les helpers temporaires, pas la découverte d’un second squelette persistant inexistant.
- [ ] Étudier une scène runtime propre préassemblée ou un cache de références `Mesh`/`Skin` extraites une fois par package. Comparer complexité, import et coût cold/warm.
- [ ] Ne pas utiliser un cache global non indexé par source. Clé au minimum selon identité du package et sa variante compatible ; invalider explicitement les données de développement lorsque les exports changent.
- [ ] Ne partager que les ressources immuables ; pose, états d’équipement et couleurs variables restent propres à l’acteur selon les mécanismes existants.
- [ ] Mettre en place un fallback explicite vers le package précédent si un candidat échoue au contrat, avec erreur exploitable. Ne pas masquer silencieusement un rig incompatible.
- [ ] Si le chargement synchrone est le facteur limitant, préparer les références avant spawn via le workflow de chargement existant ; ne pas accéder au SceneTree depuis un thread non autorisé.
- [ ] Mesurer séparément chargement de ressource, instanciation, installation composants et premier tick. La limite de spawn 3 ms / max 2 acteurs est une admission, pas une préemption : une instanciation lourde peut toujours dépasser.
- [ ] Garder quotas et nombre d’acteurs constants pour mesurer le gain. Les modifier ensuite ne doit pas masquer une instanciation encore trop coûteuse.

### 03.3 — Preuves

- [ ] Contrats LOD et atlas, fondation, équipement, démembrement et animations des trois rôles.
- [ ] Rendu comparatif repos, course, lance haute/basse, garde, coupe épée, visée arc, mort et chaque zone sectionnée pertinente aux trois LOD.
- [ ] Compteurs nœuds/ressources en régime stable et au pic d’instanciation, spawn 1/24/414 cold puis warm.
- [ ] Rechargement monde et création de deux packages différents dans le même processus pour détecter une contamination du cache.
- [ ] Régénération deux fois et comparaison des invariants ; ne pas imposer un hash binaire identique si l’exporteur écrit des métadonnées variables.

Gate : rig/UV/gore identiques, source intacte, fabrication reproductible, bénéfice spawn ou simplification quantifié. Ne pas convertir cette étape en retopologie artistique générale.

## 10. Lot 04 — réduire les surfaces, puis étudier le LOD de l’équipement

Skills : `3d-essentials`, `assets-pipeline`, `animation-system`, `shader-basics` si masques modifiés, `godot-testing`, `3dblender` si génération Blender.

Fichiers : `res://scripts/enemy_v2/hoplite_v2_equipment_component.gd`, `hoplite_v2_presentation_component.gd`, `enemy_v2_team_palette.gd`, définitions lance/épée/arc, assets Dory/Aspis/Xiphos/arc et package runtime.

### 04.A — Première marche : conserver la modularité

- [ ] Documenter le nombre réel de surfaces/draws par rôle, LOD et passe. Les ombres/contours peuvent ajouter des passes ; huit draws de la fixture ne sont pas une constante de toute scène.
- [ ] Faire un atlas d’équipement avec matériaux compatibles, sans changer le style ni la transparence. Préserver albedo, normal, metallic/roughness et padding/mipmaps.
- [ ] Réduire chaque Dory/Aspis/Xiphos à une surface lorsque visuellement équivalent. Pour l’arc, vérifier les trois pièces et leurs transforms avant de les réunir.
- [ ] Objectif structurel candidat du lancier/épéiste : corps 2 + arme 1 + bouclier 1 = 4 surfaces actives, contre 8 / 9 sources respectivement. Mesurer les draws réellement obtenus ; ne pas annoncer une division par deux du temps de frame.
- [ ] Conserver les pivots, noms publics attendus, transformations d’export et calibrations de prise. Adapter explicitement les chemins de nœuds si renommage nécessaire.
- [ ] L’Aspis actuel reste ancré à l’acteur, centre `(0.36, 1.08, 0.32)`, et son collider reste aligné sur le disque. Ne pas le réattacher à l’avant-bras pour faciliter l’export.
- [ ] Préserver prise Bayonet, arme masquée, bouclier masqué/lâché, échelles par définition, projectile_origin et bras coupés.
- [ ] Vérifier faction spartiate, contours d’attaque, occultation caméra et restauration des matériaux. L’atlas ne doit pas introduire une copie de matériau par soldat à chaque refresh.
- [ ] Partager un matériau entre plusieurs MeshInstance ne fusionne pas automatiquement leurs surfaces en un seul appel : vérifier le compteur, pas seulement l’inspecteur.

### 04.B — Deuxième marche : géométrie distante de l’équipement

- [ ] Auditer le LOD automatique réellement importé avant de fabriquer des LOD manuels supplémentaires.
- [ ] Comparer A : équipement actuel + auto LOD ; B : équipement atlasé + auto LOD ; C : équipement distant simplifié manuellement si B reste insuffisant.
- [ ] Isoler le FOV, la résolution et les seuils, car ils influencent la sélection automatique.
- [ ] Préserver silhouette de lance, rayon du bouclier et lisibilité de l’arc ; un budget de triangles est une cible à ajuster à l’écran, pas une obligation aveugle.
- [ ] Ne pas décimer à travers les zones sémantiques, bords de section, jonctions d’équipement ou détails nécessaires à la lecture de l’attaque.
- [ ] Tester les angles de profil/dos et les transitions avec la caméra en mouvement.

### 04.C — Troisième marche conditionnelle : fusion par rôle à distance

N’exécuter que si 04.A/B laissent un coût de soumission significatif et si le gain attendu justifie les états supplémentaires.

- [ ] Prototype sur UN rôle en LOD2, non activé globalement.
- [ ] Définir comment chaque partie suit sa transformation : arme skinnée/attachée, bouclier en espace acteur, corps skinné. Le rig 23 os ne possède pas nécessairement un support statique équivalent au bouclier : conserver ce dernier séparé si cela évite un nouveau rig ou shader complexe.
- [ ] Ne pas promettre « deux draws par ennemi » avant ce prototype. Trois ou quatre surfaces peuvent être le meilleur compromis fiable.
- [ ] Définir la représentation des états : arme perdue, bouclier lâché, bras/jambe sectionné, mort. Les variations doivent être bornées ; éviter une explosion combinatoire de packages.
- [ ] Aucune régénération dynamique de mesh à chaque hit/changement de LOD. Si un masque shader est nécessaire, vérifier coût, intégrité UV, compatibilité et interactions avec les autres effets.
- [ ] Le passage LOD0 ↔ LOD1 ↔ LOD2 conserve exactement l’état de l’acteur. Le visuel distant ne peut pas faire repousser un membre ou un bouclier.
- [ ] N’étendre aux autres rôles qu’après test d’équipement, gore, contours et bénéfice CPU/GPU mesuré.

Gate : 04.A/B validés indépendamment ; 04.C peut être explicitement rejeté. Ne pas bloquer le projet pour atteindre un nombre théorique de draws.

## 11. Lot 05 — traiter seulement les acteurs dont la mise à jour est due

Skills : `godot-optimization`, `component-system`, `animation-system`, `physics-system`, `ai-navigation`, `godot-testing`.

Fichiers : `res://scripts/enemy_v2/hoplite_v2_troop_runtime.gd`, `enemy_actor_v2.gd`, `hoplite_v2_lod_component.gd`, `hoplite_v2_impostor_batch.gd`. Service enfant supplémentaire uniquement si les composants existants ne suffisent pas.

### 05.1 — Attribuer le coût

- [ ] Séparer `_tick_mass_members` / appels d’acteurs, intégration réelle, `_tick_group`, tri des candidats, leases, terrain et trafic.
- [ ] Compter les acteurs parcourus alors qu’ils retournent immédiatement. Une boucle de 661 appels peut être inutile sans être la source de tous les millisecondes du runtime.
- [ ] Mesurer création de signatures de settings dans `refresh` : envisager une révision partagée au lieu d’une chaîne formatée par acteur, seulement avec invalidation à chaud conservée.
- [ ] Identifier les dictionnaires temporaires de décision et reconstructions `members_by_id`. Réutiliser les buffers/caches avec génération d’appartenance plutôt que conserver des références mortes.

### 05.2 — Scheduler borné, intégré à la responsabilité existante

- [ ] Partir des cadences existantes : mouvement mass LOD1 ≈ 30 Hz, LOD2 ≈ 12 Hz, LOD3 ≈ 4 Hz ; décisions par groupe et animation ont leurs horloges distinctes.
- [ ] Choisir des listes de membres par cadence avec échéances ou buckets phasés. Ne pas remplacer le scan O(N) par une file nécessitant un tri O(N log N) à chaque frame.
- [ ] Enregistrer/changer de classe/désinscrire aux transitions effectives. Identifiant + génération ou référence validée ; suppression différée sûre si une mort survient pendant l’itération.
- [ ] Ne garder les callbacks individuels à pleine cadence que lorsqu’ils ont du travail utile ou une responsabilité proche/standalone non transférable.
- [ ] Déphaser à partir d’un identifiant stable de spawn/groupe ; ne pas réveiller toutes les troupes ensemble après un reload de settings.
- [ ] Préserver le temps de simulation écoulé. La remise à zéro actuelle des accumulateurs de mouvement peut introduire de la dérive : ajouter un test de distance parcourue sur une durée fixe à FPS variable avant correction.
- [ ] Borner le rattrapage après frame longue : pas de centaines de recherches ou d’attaques instantanées en une frame. Définir séparément rattrapage de déplacement et progression du cycle de combat ; ne pas supprimer des événements engagés.
- [ ] Priorité au combat immédiat, aux acteurs touchés et aux changements de cible indispensables. Le retard d’une unité distante ne doit jamais devenir une famine indéfinie.
- [ ] Une entrée/sortie de zone proche force le rafraîchissement nécessaire avant interaction ; éviter un premier hit sur une pose ancienne.
- [ ] Garder un seul propriétaire du mouvement et les validations terrain/obstacles. Ne pas remplacer les routes de groupe par un agent de navigation par soldat.
- [ ] Les géants restent sur leur contrôleur spécialisé tant que leur contrat n’autorise pas autre chose.
- [ ] Au niveau 3, ne pas supprimer le combat NPC-vs-NPC sous prétexte que le joueur ne voit pas les troupes.

### 05.3 — Vérifications

- [ ] Identité des vitesses et distances après 10 s à 30/60/144 FPS, hors tolérances physiques explicitées.
- [ ] Un acteur planifié une seule fois, jamais après sa désinscription, et pas simultanément en mode physique individuel et mass.
- [ ] Retard maximal de tâche et backlog publiés à 414/661, et après 100 morts ou spawns proches dans la même fenêtre.
- [ ] Franchissement d’obstacles, rotation de formation, écoulement aux passages étroits, G/H, réaffectation, maintien des brèches et équité des attaques.
- [ ] Régénérer la mesure A/B à cadences IDENTIQUES avant toute tentative de preset plus agressif.

Gate : moins de travail inutile, amélioration ou simplification démontrée, aucune perte de vitesse/engagement/équité. Pas de promotion si l’optimisation gagne en moyenne mais introduit une file qui explose au p99.

## 12. Lot 06 — étaler les snapshots et mutualiser les requêtes sûres

Skills : `godot-optimization`, `component-system`, `ai-navigation`, `godot-testing`, `godot-debugging`.

Fichiers : `res://scripts/enemy_v2/battlefield/battlefield_runtime.gd`, `army_situation.gd`, `adaptive_army_planner.gd`, `army_commander.gd`, contrats de targeting et trafic.

### 06.1 — Mesurer le vrai dépassement de budget

- [ ] Chronométrer séparément reconstruction des acteurs, cellules spatiales, charges de cible, résumés groupes, planificateurs et acquisitions.
- [ ] Distinguer budget d’admission actuel de 2 ms et coût maximal d’une tâche non préemptible.
- [ ] Relever taille maximale des cellules, candidats visités, acquisitions différées et âge de snapshot réellement lu.
- [ ] Ne pas recopier aveuglément la limite de 24/48 candidats à de nouveaux consommateurs : c’est une règle de ciblage, pas une garantie d’exhaustivité des dégâts de zone.

### 06.2 — Transformation incrémentale

- [ ] Commencer par réutilisation des buffers et reconstructions sur révision d’appartenance lorsqu’approprié ; conserver la mise à jour spatiale due au mouvement.
- [ ] Regrouper plusieurs invalidations d’une même frame ; ne pas reconstruire tous les résumés à chaque mort individuelle.
- [ ] Si le snapshot reste le pic principal : construction en tranches avec curseur, double buffer ou génération cohérente. Publier uniquement un snapshot complet ; ne pas exposer une grille moitié ancienne/moitié nouvelle aux décisions.
- [ ] Définir la période maximale de fraîcheur acceptable par consommateur. Les sorties/morts doivent être invalidées immédiatement même si la géométrie spatiale est légèrement ancienne.
- [ ] Partir d’un budget global du service partagé entre reconstruction et targeting ; donner une part minimale à chaque catégorie pour éviter la famine de la seconde.
- [ ] Réduire la taille d’une tranche plutôt que promettre un plafond dur sur une fonction native non préemptible.
- [ ] Décaler les décisions des différents groupes/armées sans modifier leurs délais de difficulté ou priorités tactiques.
- [ ] Conserver le groupe adverse assigné, la vengeance, les exceptions des miniboss, les cibles engagées et les charges anti-concentration.
- [ ] Préserver le contrat distinct : plafonds de pression JOUEUR ; pas de nouveau plafond tactique global arbitraire sur les duels NPC.
- [ ] Tester les références `Variant` libérées AVANT conversion typée. Ne pas retirer les protections ajoutées dans `battlefield_freed_target_regression_test.gd`.

### 06.3 — API de requête réutilisable, seulement pour les consommateurs migrés

- [ ] Exposer des requêtes dans un buffer fourni par l’appelant, avec rayon, faction/source, filtre de vivant et règle d’ordre documentés.
- [ ] Distinguer `candidates_for_targeting` éventuellement bornée de `all_hits_in_area` exhaustive et de balayage de segment projectile.
- [ ] Si une requête est bornée, traiter explicitement son overflow. Ne pas manquer silencieusement le 49e ennemi d’un ultime.
- [ ] Vérifier les anciennes règles d’égalité de distance/ordre ; un changement de choix n’est pas une simple optimisation s’il affecte le gameplay.
- [ ] Maintenir un fallback pour scènes sans battlefield runtime et unités legacy, sans double hit ni double inscription.
- [ ] Ne pas transformer tout le registre V1 en autorité globale dans ce lot.

Tests : adaptive army, attaque/budget, boss, escort, authoring, freed target, crash, stress 661. Ajouter un test de snapshot interrompu par mort/spawn/suppression de monde et un test d’exhaustivité d’AOE dense.

Gate : p95/p99 service et fraîcheur publiés, invariants tactiques verts, charge CPU réduite sans NPC congelés ni attaques perdues.

## 13. Lot 07 — réduire les pics VFX et les scans de compétences

Skills : `particles-vfx`, `audio-system`, `shader-basics` si nécessaire, `ability-system`, `physics-system`, `godot-optimization`, `godot-testing`.

Fichiers : `res://scripts/combat/combat_feedback.gd`, `res://scripts/audio/combat_audio.gd`, `res://scripts/abilities/skill_vfx.gd`, `skill_runtime.gd`, `skill_projectile.gd`, `flame_wall.gd` et leurs tests. Vérifier les noms actuels avec `rg --files` avant édition : le dossier compétences est encore non suivi lors de la préparation de ce plan.

### 07.1 — Réutilisation des géométries

- [ ] Mesurer nombre et coût des créations de Mesh, Material, MeshInstance, particules et lumières pendant spirale/Tonnerre/feu.
- [ ] Mettre en cache des géométries unitaires pour anneaux, cylindres, quads et segments ; varier leur transform plutôt que créer une nouvelle ressource à chaque trail.
- [ ] Séparer paramètres partagés et paramètres d’instance. Une animation d’alpha sur un matériau partagé ne doit pas faire disparaître les autres effets.
- [ ] Regrouper les segments répétitifs dans un MultiMesh ou une géométrie unique si le profil confirme le bénéfice. Tester transparence, ordre, culling et coût de mise à jour.
- [ ] Créer des pools bornés par famille seulement pour les objets fréquemment instanciés, pas un pool universel de tout le jeu.
- [ ] Contrat `reset` exhaustif : transform, visibilité, temps restant, emission, lumière, couleur, matériau d’instance, source/cible, callbacks, parent, état de collision et marqueur d’utilisation.
- [ ] Réinitialiser un effet sans tween ou timer d’un ancien usage encore capable de le libérer/modifier.
- [ ] Pré-chauffage limité avant gameplay ; croissance contrôlée hors d’une frame d’impact si possible. Publier mémoire retenue et pic d’occupation.
- [ ] À saturation, sacrifier un accent secondaire lointain/ancien ; conserver confirmation d’impact joueur, télégraphe dangereux et réaction lisible. Jamais annuler les dégâts parce qu’un pool VFX est plein.
- [ ] Ne pas convertir automatiquement toutes les CPUParticles en GPU : mesurer les alternatives sur le renderer réel et les budgets disponibles.

### 07.2 — Priorités de feedback

- [ ] Inventorier les feedbacks déjà présents avant d’en ajouter : shake/FOV/rumble, ralenti, flash, SFX et réaction adverse.
- [ ] Maintenir une seule confirmation par hit accepté ; pas de feedback de dégâts sur une cible qui a refusé le hit.
- [ ] Donner priorité aux impacts du joueur et aux menaces proches sur la foule lointaine, avec quotas visuels indépendants des permissions de combat.
- [ ] Conserver le propriétaire actuel du `time_scale`, pause et cinéma. Pas de second hit-stop concurrent ajouté par le pool.
- [ ] Ne pas augmenter lumière, shake ou durée du ralenti pour masquer une animation hachée.

### 07.3 — Requêtes compétences et feu

- [ ] Mesurer les scans du mur de feu, d’aura et des projectiles à grande population, sans attribuer leur coût à la seule VFX.
- [ ] Utiliser l’API spatiale du lot 06 seulement après parité : ennemis touchés, faction, distance, segment, occlusion et cas legacy.
- [ ] Pour le mur de feu : mettre en cache transforms/inverses et volumes larges, filtrer spatialement avant les tests précis ; ne pas recalculer tous les murs pour chaque soldat si une sélection locale est possible.
- [ ] Les dégâts périodiques restent au même rythme et le projectile garde son balayage anti-tunneling ; pas de baisse de cadence arbitraire.
- [ ] Réutiliser buffers et résultats intermédiaires dans la même fenêtre quand valides, en les invalidant sur disparition/changement du mur.
- [ ] Ajouter cas dense avec plus de 48 cibles, cible libérée, deux factions, plusieurs murs et projectile traversant plusieurs cellules.

### 07.4 — Audio : compléter ce qui existe, ne pas remplacer le pool

- [ ] Auditer le pool de 14 lecteurs et son choix de voix à saturation ; compter les confirmations importantes coupées par la foule.
- [ ] Ajouter une priorité/réservation pour les sons essentiels seulement si nécessaire, en conservant variantes aléatoires et cooldowns par catégorie.
- [ ] Réinitialiser les paramètres spatiaux/volume/pitch/bus à chaque réutilisation ; vérifier changement de scène.
- [ ] Ne pas convertir toute la banque MP3 sans mesure de latence/décodage et vérification des sources.
- [ ] Les sons optionnels absents restent un cas traité, pas une raison d’inventer des assets ou de modifier le mix global.

Tests : skill system/revision/live flow, enemy integration, ultimate charge/input routing, lock lifecycle, combat cursor, spiral recovery, thunder explosion camera. Rendu long avec répétition d’effets et teardown.

Gate : p99 et instanciations par impact réduits, mémoire bornée, aucun hit/son prioritaire perdu sans politique explicite, transitions de caméra/temps intactes.

## 14. Lot 08 — LOD visuel cohérent et mouvement fluide

Skills : `3d-essentials`, `animation-system`, `physics-system`, `camera-system`, `godot-testing`, `godot-optimization`.

Fichiers : composants LOD/presentation/actor, impostor batch/shader et politique de caméra. Ne pas refactorer le contrôleur joueur entier.

### 08.1 — Distinguer représentation et précision de combat

- [ ] Reproduire caméra loin du joueur, hauteur importante, FOV cinématique, orbit et zoom. Les visibility ranges utilisent la caméra alors que le LOD de simulation actuel utilise souvent le joueur et une distance planaire.
- [ ] Définir deux décisions explicites : représentation selon vue ; précision gameplay selon interaction/proximité. Ne pas appliquer simplement `min(distance_joueur, distance_camera)` à tout sans examiner le coût et les contrats.
- [ ] Assurer que la représentation visible reçoit une pose à cadence adaptée et que la proximité du joueur reçoit ses hitboxes même si la caméra regarde ailleurs.
- [ ] Un acteur 3D visible ne doit pas être endormi parce que son imposteur a été sélectionné dans un autre référentiel.
- [ ] Ajouter hystérésis cohérente à la décision CPU si nécessaire, avec états de transition explicites. Les marges graphiques seules ne stabilisent pas l’état CPU.
- [ ] Corps, arme, bouclier, ombres et imposteur partagent des frontières compatibles ; vérifier qu’il n’y a ni trou ni double silhouette prolongée.
- [ ] Vérifier l’AABB de chaque représentation et les déplacements rapides ; ne pas élargir arbitrairement toutes les bornes pour cacher des culls erronés.

### 08.2 — Interpolation ciblée

- [ ] Mesurer/filmer le mouvement mass à 12 et 4 Hz : un FPS élevé peut toujours afficher des pas de position visibles.
- [ ] Prototype interpolation du visuel entre deux positions autoritaires avec timestamps, sans interpoler les données de collision/dégâts.
- [ ] Inclure équipement et ombres dans la même représentation cohérente ; ne pas lisser le corps en laissant son bouclier ou télégraphe dériver.
- [ ] Évaluer le retard visuel introduit. En combat proche ou pendant une fenêtre de hit, préserver l’alignement visuel/collision ; désactiver ou réduire l’interpolation si nécessaire.
- [ ] Réinitialiser les historiques lors de spawn, téléportation, changement de monde, mort, saut de LOD, déplacement forcé et changement de parent.
- [ ] Pour les imposteurs, comparer interpolation de transforms et extrapolation bornée à partir d’un mouvement connu ; pas de soldat qui traverse un obstacle pendant que sa simulation s’arrête.
- [ ] Ne pas ajouter une boucle coûteuse de tous les acteurs par frame pour économiser celle du lot 05. Mesurer le coût de lissage et privilégier le traitement des représentations visibles ou un chemin partagé adapté.
- [ ] Ne pas activer globalement l’interpolation physique moteur sans audit des acteurs déjà lissés et des écritures directes de transform.

### 08.3 — Batches d’imposteurs

- [ ] Mesurer le batch actuel et son grand AABB ; un découpage spatial n’est utile que si le culling gagné dépasse les draws/updates ajoutés.
- [ ] Si justifié, partitionner par rôle et secteur raisonnable, avec migrations de cellules bornées et capacité réutilisée.
- [ ] Conserver équipe, phase, orientation, échelle et compteurs exacts lors de transfert entre batches.
- [ ] Ne pas supposer que chaque instance d’un MultiMesh est cullée indépendamment. Godot recommande le découpage lorsque les instances sont dispersées : [optimisation MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html).
- [ ] Pas d’imposteur hoplite pour le géant ; sa solution reste spécifique au lot 10.

### 08.4 — Presets uniquement après gain équivalent

- [ ] Garder les distances et fréquences actuelles dans la mesure principale.
- [ ] Si une option performance est utile, comparer un preset nommé distinct, avec capture proche/moyen/loin et coût des concessions.
- [ ] Ne pas faire passer 24 → 15 Hz, 10 → 5 Hz ou 65 → 45 m pour une amélioration gratuite. Choix utilisateur si cette concession devient le nouveau défaut.

Gate : transitions propres, vitesse correcte, aucune dérive corps/arme/hitbox en combat, fluidité visuelle comparée en mouvement et coût du lissage publié.

## 15. Lot 09 — isoler et optimiser le résiduel du monde

Skills : `3d-essentials`, `assets-pipeline`, `godot-optimization`, `godot-testing`, `camera-system` uniquement si ce système est réellement modifié.

Fichiers candidats : `res://scripts/world_editor/world_runtime.gd`, `world_terrain_foliage.gd`, constructeurs d’assets/terrain, scènes environnement et matériaux concernés. Identifier par profil, pas par taille du fichier.

- [ ] Mesurer monde seul puis joueur/UI/contours/foliage dans des fixtures séparées ; les 1 360 draws historiques ne désignent pas un propriétaire unique.
- [ ] Identifier les principaux groupes de surfaces, ombres, transparences et petites instances répétées.
- [ ] Réutiliser meshes/materials immuables et regrouper des objets répétitifs par secteurs si leur état ne demande pas des nœuds individuels.
- [ ] Tester HLOD/distance/occlusion sur les portions vraiment coûteuses. Préserver collisions, navigation, destruction éventuelle et sélection Forge.
- [ ] Éviter un MultiMesh unique couvrant tout le monde : mesurer les secteurs qui permettent un culling utile.
- [ ] Préserver la géométrie du terrain, ses hauteurs d’échantillonnage et les emprises de trafic. Aucune simplification ne doit faire flotter les troupes ou ouvrir une route à travers un obstacle.
- [ ] Les ombres et transparences peuvent être coûteuses ; une réduction de qualité doit être séparée du regroupement à qualité identique.
- [ ] Ne pas générer une nouvelle forêt/carte ou déplacer les obstacles pour obtenir un meilleur score.
- [ ] Fader caméra : conserver cache dynamique, index statique, maintien de réapparition et absence de réécriture stable. N’y revenir que si un profil complet le désigne ; le microbench de fade n’est pas son coût total.

Tests : `world_environment_assets_test.gd`, chargement Forge, carte 414, deux armées, camera fader/outline si impactés. Comparer screenshots avec même caméra et settings.

Gate : coût résiduel attribué, modifications localisées, aucun changement de layout/gameplay, gain rendu mesuré ou abandon justifié.

## 16. Lot 10 — géant : un package distinct, pas un hoplite agrandi

Skills : `assets-pipeline`, `3d-essentials`, `animation-system`, `physics-system`, `godot-testing`, `3dblender` pour les scripts Blender.

Fichiers : `res://scripts/enemy_v2/giant_v2_definition.gd`, `giant_v2_presentation_component.gd`, `giant_v2_actor.gd`, `res://assets/characters/enemy_v2/giant/giant_v2.package.json`, package `spartan_character_package` existant, bibliothèques et fragments géants.

### 10.1 — Décider sur la structure réelle

- [ ] Refaire l’inventaire Blender et Godot : source 79 177 triangles / 237 493 sommets, dix parties, 53 os, surfaces réellement rendues et LOD automatiques importés.
- [ ] Examiner pourquoi presque trois sommets sont exportés par triangle : normales séparées, coutures UV, attributs, weights, frontières de zone. Ne pas conclure automatiquement à des doublons supprimables.
- [ ] Premier candidat : réindexation/nettoyage conservant TOUS les attributs identiques, avec avant/après de shading et skinning.
- [ ] Deuxième candidat : LOD propres et assemblage par surfaces compatibles, en préservant les parties nécessaires à l’amputation.
- [ ] Troisième option seulement si les précédentes échouent : retopologie plus profonde sur copie, transfert contrôlé UV/weights/zones, comparaison de silhouette. Une nouvelle direction artistique requiert décision utilisateur.
- [ ] Conserver le rig 53 os au premier passage. Réduction à 23 os non incluse par défaut : elle imposerait retarget, validation animations et surfaces de gameplay supplémentaires.
- [ ] Vérifier le cache de corps fusionné du package source avant toute réutilisation : une clé globale non dépendante de l’asset peut faire partager le mauvais corps entre familles.

### 10.2 — Package et comportement

- [ ] Établir des budgets candidats selon taille à l’écran et nombre prévu de géants ; ne pas recopier les chiffres de triangle du hoplite.
- [ ] Produire corps/LOD/caps/fragments séparés et cohérents, sans helpers inutiles au spawn courant.
- [ ] Préserver volumes, échelle 2/3, sol, collision, zones sectionnables, matériaux et caps sans fissures visibles.
- [ ] Préserver coups de poing, balayage, slam, télégraphes, esquive par saut, contraintes de jambes et affaissement après double amputation.
- [ ] Vérifier le contrat de traversée réellement présent en V2. L’ancien dispositif V1 complexe de grimpe tête/sommet n’est pas automatiquement migré : préserver la V2 actuelle et marquer la parité V1 manquante, sans prétendre la rétablir par un export.
- [ ] Une optimisation visuelle ne change pas le rôle défensif ou les exceptions de commandement du géant.
- [ ] Si un imposteur géant est envisagé, prouver d’abord que sa grande silhouette distante le permet ; rendre compte des poses/amputations et réveil. Option conditionnelle, pas préalable imposé.
- [ ] Conserver durée et état de mort, physique et effets associés ; vérifier le lot 02 sur cette famille.

Tests : giant combat, doctrine review, mixed group, Forge, visual, combined arms, boss. Mesurer 1/2/5 géants à mêmes distances, échelles et animations.

Gate : package plus efficace à rendu comparable, rig/gore/attaques intacts, compatibilité V1 non transférée explicitement inscrite comme reste à faire. Aucun `migration_ready=true` seulement parce que le GLB est plus léger.

## 17. Lot 11 — rendre le gameplay fluide et satisfaisant sans réécrire ses règles

Skills : `animation-system`, `camera-system`, `audio-system`, `particles-vfx`, `player-controller`, `input-handling`, `godot-testing`. Charger seulement les domaines effectivement modifiés.

### 11.1 — Distinguer quatre problèmes différents

1. Frame trop longue : à résoudre par profiling/optimisation, pas par un shake supplémentaire.
2. Simulation ou pose trop espacée : à résoudre par horloge/scheduler/interpolation et précision proche.
3. Retour d’impact peu lisible : à résoudre par timing, priorité et cohérence du feedback.
4. Choix d’interaction jugé lent : demande un choix de gameplay, pas une correction de performance déguisée.

### 11.2 — Instrumenter la chaîne d’une action

- [ ] Relever temps de réception input, acceptation commande, début de préparation, engagement, début de fenêtre active, hit accepté, feedback visuel/audio et reprise du mouvement.
- [ ] Ajouter des marqueurs de diagnostic non persistants, désactivables et sans impression par frame dans les benchmarks.
- [ ] Vérifier qu’un hit accepté déclenche sa confirmation sans attendre une décision de groupe distante.
- [ ] Vérifier animation/arme/collision synchronisées après changement LOD et frame longue.
- [ ] Rejouer à FPS stable puis sous charge et avec frame longue injectée dans un test contrôlé ; séparer latence logique de latence physique de périphérique, non mesurée ici.
- [ ] Ne pas changer le clic léger au relâchement : il distingue actuellement clic court/charge. Une expérimentation « au press » exige de redéfinir la charge avec l’utilisateur.
- [ ] Buffer de saut, coyote time, nouvelles annulations, combo chaining ou nouvelles fenêtres de contre : suggestions séparées, non activées dans un lot perf.

### 11.3 — Parcours de validation visuelle obligatoire

| Parcours | À observer | Échec bloquant |
|---|---|---|
| 10 s de marche/course dans une phalange | Cadence, positions, pieds, lisibilité des lignes | Glissements nouveaux, vibration ou téléportation |
| Caméra aller/retour sur chaque seuil LOD | Corps/gear/imposteur et ombres | Trou, double corps, bouclier flottant, membre réapparu |
| Lance/épée/arc en duel | Préparation, impact, récupération | Dégâts hors animation, arc/arme mal orienté |
| Garde, contre, bouclier lâché | Son/étincelle/réaction concordants | Double feedback, collider sans bouclier |
| Spirales haute/basse puis attaque normale | Continuité et reprise des contrôles | Verrou bloqué ou attaque avalée |
| Tonnerre puis retour caméra | Pic visuel, dégâts, caméra, temps | Temps ralenti non restauré, shake permanent |
| Feu + projectiles + deux factions | Lisibilité sous charge et exhaustivité | Ennemi oublié à cause d’une limite de candidats |
| Morts/amputations puis éloignement/retour | Continuité des poses et du gore | Repousse, corpse actif en combat, fuite croissante |
| Géant amputé à échelles 2 et 3 | Sol, attaque, chute, zones de gameplay | Glissement/collision grossièrement désalignée |
| Mur/toit/foule et caméra cinématique | Occultation, contours, restauration | Matériau perdu ou silhouette persistante |
| Pause/focus/roue/changement d’arme | Libération des états et jauges | Dépense double, commande tardive, contrôle bloqué |

- [ ] Capturer avant/après à caméra/seed/settings égaux, avec les mêmes animations et timestamps.
- [ ] Inspecter réellement les captures ; une image sauvegardée n’est pas automatiquement une validation visuelle.
- [ ] Les tests automatisés valident contrats et timings. Le plaisir et le confort exigent un essai humain ; fournir un parcours court et indiquer ce qui reste à confirmer.
- [ ] Ne pas amplifier le flash, le blur, le shake ou le volume pour rendre un graphique de performance meilleur ou « plus satisfying » sans retour visuel/sonore.

Gate : aucun recul de réactivité/lecture, transitions documentées et revue visuelle explicite. Les ajustements subjectifs proposés restent distincts des corrections prouvées.

## 18. Lot 12 — campagne finale et gate avant migration des identités

Skills : `godot-code-review`, `godot-testing`, `godot-optimization`, `assets-pipeline`, domaines des changements retenus.

### 12.1 — Régression par périmètre, puis intégration

Après chaque lot, exécuter ses tests ciblés. À la fin, exécuter la matrice élargie ci-dessous. Un test historique rouge doit être reproduit, expliqué et distingué d’une nouvelle régression ; ne pas « corriger » son assertion pour la faire passer sans vérifier le contrat.

| Domaine | Probes/tests existants à retrouver |
|---|---|
| Fondation et assets | `hoplite_v2_foundation_probe`, `hoplite_v2_lod_contract_probe`, `hoplite_v2_atlas_probe`, `hoplite_v2_equipment_axis_probe` |
| LOD et rendu distant | `hoplite_v2_runtime_lod_probe`, `hoplite_v2_impostor_probe`, `enemy_v2_roles_impostor_probe`, probes visuels LOD/rôles |
| Combat/gore | `hoplite_v2_combat_probe`, `hoplite_v2_dismemberment_probe`, `enemy_v2_roles_probe` |
| Formations/trafic | `enemy_v2_formation_traffic_probe`, `enemy_v2_traffic_map_probe`, `hoplite_v2_battle_layout_probe`, `hoplite_v2_tactical_stability_probe`, `enemy_v2_fronts_probe` |
| Armées actuelles | `adaptive_army_probe`, `player_escort_probe`, `battlefield_attack_budget_probe`, `battlefield_v2_runtime_probe`, `enemy_v2_combined_arms_runtime_probe` |
| Cycle de vie | `battlefield_v2_crash_regression_probe`, `battlefield_freed_target_regression_test` et nouveaux tests horloges/cadavres/schedulers |
| Forge et boss | `hoplite_v2_forge_probe`, `battlefield_v2_authoring_probe`, `battlefield_v2_forge_probe`, `battlefield_boss_probe`, `battlefield_boss_forge_probe` |
| Géants | `giant_v2_combat_probe`, `giant_v2_doctrine_review_probe`, `giant_v2_mixed_group_probe`, `giant_v2_forge_probe`, `giant_v2_visual_probe` |
| Joueur/compétences | `combat_cursor_regression_test`, `skill_lock_lifecycle_test`, `ultimate_input_routing_test`, `ultimate_charge_transfer_test`, `skill_live_flow_test`, `skill_enemy_integration_test`, `skill_system_test`, `skill_revision_test` |
| Ressenti/caméra | `spiral_combat_recovery_test`, `thunder_explosion_camera_test`, `camera_occlusion_fader_test`, `player_movement_response_test`, `enemy_attack_outline_test`, `combat_wall_attach_reconciliation_test` |

Les probes sont principalement dans `res://tools/enemy_v2/`, les tests dans `res://tests/`. Lire chaque entrée avant lancement : certaines génèrent des assets/images ou utilisent des cartes `user://` et ne sont pas toutes des opérations sans écriture. Donner une destination de sortie de campagne lorsque leur API le permet. Ne pas lancer tous les générateurs sous prétexte que leur nom contient « probe ».

### 12.2 — Performance finale

- [ ] Rejouer EXACTEMENT la baseline versionnée du lot 00 avec le même harness et les mêmes paramètres.
- [ ] Si le harness a dû être corrigé après la baseline, refaire les deux branches comparables ; ne pas mélanger deux versions de mesure.
- [ ] Publier médiane des runs, dispersion entre runs, p50/p95/p99/max et échantillons bruts ; ne pas calculer le p95 final comme une moyenne de FPS.
- [ ] Différencier fixture présentation, bataille 414, armées adaptatives, stress 661, spawn, compétences et accumulation de morts.
- [ ] Vérifier temps de frame de la longue mêlée et des pics, pas seulement l’image d’ouverture.
- [ ] Confirmer compteurs d’unités, types, attaques/dégâts observés et travail dû : un jeu qui ne simule plus correctement peut être artificiellement rapide.
- [ ] Si un changement est neutre ou régressif sans avantage de maintenance prouvé, l’abandonner en annulant uniquement ses propres modifications connues.
- [ ] Ne jamais faire de `git checkout --` sur un fichier dirty utilisateur pour revenir en arrière. Revenir par patch ciblé, ou conserver le candidat séparé jusqu’à décision.

### 12.3 — Fiche de préparation par famille

Créer quatre lignes minimales : hoplite lance/vétéran, infanterie épée, archer, géant. Pour chaque ligne renseigner :

1. IDs V2 testés, corps, rig, packs, équipement, capacités et sources conservées.
2. Coût mesuré proche/moyen/loin et en mélange ; import/spawn/mémoire.
3. LOD/ombres/imposteur et transitions effectivement validés.
4. Santé/anatomie/gore/équipement perdu/mort/teardown.
5. Contrats de commandement, terrain, armes et dégâts NPC/joueur.
6. Rendus revus, tests passés et limites connues.
7. Différences entre la famille V2 et chaque identité V1 qu’on souhaite migrer plus tard.
8. Statut : `ready_for_migration_pilot`, `blocked_functional`, `pending_visual_review`, `performance_unproven` ou `not_in_scope`.

Ne pas confondre `ready_for_migration_pilot` avec une migration de production terminée. Le corps partagé actuel des fantassins/archers reste un placeholder artistique ; leur rôle fonctionnel peut être prêt sans leur apparence finale.

### 12.4 — Gate d’une future unité, à préparer sans l’exécuter maintenant

Pour toute future identité : inventaire V1 → composition V2 explicite → tests de parité spécifiques → package et animation → QA gore/LOD → benchmark individuel/mixte → pilote Forge/Lab → validation → bascule de production séparée. Aucun alias global qui redirige tous les profils vers un rôle approchant.

Les miniboss/phases, armes inédites, limites de déplacement et capacités uniques doivent avoir des tests propres. Un test « lance » ne prouve pas un capitaine, un boss à phases ou un géant V1 complet.

- [ ] Réconcilier métadonnées `migration_ready` et liste de compatibilité avec les preuves présentes. Conserver `false` si un gate obligatoire manque.
- [ ] Ne pas éditer les anciennes matrices historiques comme si elles étaient le tableau V2 actuel ; ajouter le gate au contrat/document courant avec un lien depuis son point d’entrée.
- [ ] Documenter les candidats Blender retenus/rejetés et les procédures de régénération.
- [ ] Ne supprimer aucune source ou bibliothèque donneuse lors de ce chantier.

## 19. Commandes de départ et sécurité des exécutions

Chemins observés lors de l’audit, à vérifier sur la machine au démarrage :

```powershell
$godotAuditExe = 'C:\Users\suean\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe'
$blenderAuditExe = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
Test-Path -LiteralPath $godotAuditExe
Test-Path -LiteralPath $blenderAuditExe
& $godotAuditExe --version
```

Depuis la racine du projet, exemples de commandes **existantes**, à lancer séparément :

```powershell
& $godotAuditExe --headless --path . --script res://tools/enemy_v2/hoplite_v2_lod_contract_probe.gd --log-file .godot/sol_lod_contract.log
& $godotAuditExe --headless --path . --script res://tests/battlefield_freed_target_regression_test.gd --log-file .godot/sol_freed_target.log
& $godotAuditExe --headless --path . --script res://tools/enemy_v2/battlefield_v2_runtime_probe.gd --log-file .godot/sol_battlefield_stress.log -- --stress --frames=600
```

Ancien probe graphique, uniquement pour reproduction historique et vérification de paramètres ; **pas le protocole final A/B** :

```powershell
& $godotAuditExe --path . --resolution 1280x720 --script res://tools/enemy_v2/hoplite_v2_battlefield_render_cost_probe.gd --log-file .godot/sol_render_historical.log -- --world=res://worlds/forge/champsdebataille_v2_commandement_414.hoplite.json --full-map --sample-frames=90
```

Les nouveaux modes/options d’A/B n’existent pas encore : les ajouter au lot 00, documenter leur aide et leurs exemples après implémentation. Ne pas fabriquer des commandes qui semblent disponibles avant de les avoir écrites et testées.

- Capturer commande, exit code, durée et log pour chaque résultat. `exit 0` ne remplace pas les assertions attendues ni l’absence de nouvelles erreurs.
- Un démarrage headless ou un éditeur interrompu pendant le scan ne prouve pas un import propre complet. Attendre la fin réelle de l’import dans une validation dédiée et conserver ses logs.
- Les avertissements d’accès certificats/préférences en sandbox sont distincts des erreurs de script. Les signaler ; ne pas masquer une nouvelle fuite sous l’étiquette « warning connu ».
- Ne pas supprimer `.godot` pour nettoyer un benchmark : coût élevé, pertes de caches utiles et comparaison cold/warm faussée. Employer des sorties de campagne dédiées et une méthode cold documentée.
- Pour les gros JSON de carte sur une ligne, utiliser `ConvertFrom-Json` et sélectionner les champs utiles ; ne pas déverser tout le fichier dans les sorties.
- Scripts et documentation : modifications avec `apply_patch`. Les générateurs autorisés produisent leurs assets dans des candidats dédiés, avec limites et provenance.
- Si Blender doit tourner en arrière-plan via `Start-Process`, garder la fenêtre cachée et suivre son PID. Aucun arrêt global de tous les processus Blender/Godot.
- Pas de benchmark graphique caché/minimisé si cela affecte le throttling ; réserver le mode caché aux opérations où l’état de fenêtre ne biaise pas la mesure.

## 20. Livrables, checkpoints et gestion d’une reprise

Ne pas disperser les conclusions dans dix rapports concurrents. Garder ce plan comme checklist et un rapport d’exécution principal, avec liens vers logs/JSON/captures.

### Arborescence proposée pour les preuves

```text
docs/enemy_refactor/
  V2_PERFORMANCE_EXECUTION_REPORT_2026-09-06.md
  performance_2026_09_06/
    baseline.json
    environment.json
    lot_00/ ... lot_12/
      results.json
      commands.md
      comparison.csv
      captures/   # uniquement les images utiles et réellement revues
```

Adapter sans écraser si cette arborescence existe déjà. Éviter de versionner des gigaoctets de logs/vidéos : conserver les résultats nécessaires et indiquer les chemins des données lourdes.

### Checkpoint obligatoire après chaque lot

```text
Lot :
Statut : non commencé / en cours / validé / rejeté / bloqué / attente revue visuelle
Hypothèse et preuve avant :
Changements conservés et fichiers :
Réglages inchangés / différences délibérées :
Tests (commandes, exit code, assertions) :
Mesures après et comparaison :
Qualité visuelle réellement inspectée :
Risques ou dettes restants :
Procédure de retrait ciblé du candidat :
Prochaine action exacte :
```

En cas de reprise/contexte compacté, relire ce checkpoint et le diff, puis reprendre la prochaine action. Ne pas refaire tous les audits déjà terminés et ne pas cocher rétroactivement un test absent.

### Définition de terminé pour ce chantier

- Baseline et comparaison finale exploitables.
- Corrections d’horloge/cycle de vie validées ou risque initial infirmé par test.
- Chaque optimisation prioritaire implémentée avec preuve OU rejetée/reportée avec cause concrète, pas simplement oubliée.
- Sources intactes, packages reproductibles et candidats séparés.
- Tests ciblés et campagne d’intégration exécutés ; toute limite graphique/humaine clairement indiquée.
- Objectif 60 FPS : atteint sur scénarios nommés, non atteint ou non mesurable — verdict explicite.
- Préparation migration par famille renseignée ; aucune bascule V1 non demandée.

Le chantier n’est pas « terminé » parce que quelques tests headless passent ou parce qu’un GLB a moins de triangles. Le gain et la conservation du gameplay doivent être établis séparément.

## 21. Message prêt à envoyer à SOL

> Exécute le plan `C:/Users/suean/Downloads/hoplite_ual_native_lab_v2/docs/godot-prompter/plans/V2_PERFORMANCE_FLUIDITY_SOL_EXECUTION_PLAN_2026-09-06.md`. Lis-le intégralement, vérifie l’état actuel du projet, puis commence par le lot 00 et les tests de reproduction du lot 01. Je veux une implémentation progressive des optimisations validées, pas seulement une nouvelle analyse. Préserve toutes mes modifications en cours, les contrats V2, le gameplay proche, les formations, les armes et le démembrement. Applique les gates et les tests indiqués ; ne retiens pas une optimisation dont le gain vient d’une dégradation cachée. Continue les lots en ordre de dépendance et tiens le rapport d’exécution à jour avec mesures avant/après et prochaine action précise. Les options de fusion complexe, les concessions visuelles et la refonte artistique restent conditionnelles aux preuves ou à mon choix ; avance sur les lots indépendants si l’une bloque. Ne migre pas globalement les identités V1 et ne supprime aucune source. Termine par le bilan vérifié, les limites et la préparation à la migration par famille. N’annonce pas une validation visuelle ou 60 FPS si tu ne l’as pas réellement démontrée.
