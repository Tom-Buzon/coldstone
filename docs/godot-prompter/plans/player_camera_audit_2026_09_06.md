# Audit personnage et occultation — 6 septembre 2026

## Périmètre et méthode

Relecture du contrôleur, des entrées, du mouvement, des appels de détection
d'arme, du feedback et des deux passes caméra. Corrections ciblées dans
l'architecture actuelle ; l'arbre de compétences reste une étape ultérieure.
Skills utilisés : using-godot-prompter, godot-debugging, godot-optimization,
godot-brainstorming, camera-system, player-controller, input-handling,
godot-code-review.

Travaux réalisés : établir le test de référence et le benchmark CPU ; corriger
le fondu et son cache (camera-system / godot-optimization) ; corriger la réponse
du mouvement (player-controller / input-handling) ; vérifier les régressions
et relire les changements (godot-code-review).

## Bilan de l'implémentation

La base comporte déjà plusieurs protections utiles : mouvement physique,
requêtes de collision réutilisées, balayages d'arme réservés aux fenêtres
actives, conservation du momentum, index spatial pour le décor, recherche
d'occultation à 20 Hz et restauration des matériaux d'origine. Le test existant
d'annulation de combat et de reprise de course murale passe.

Le contrôleur reste un script de plus de 4 400 lignes réunissant déplacement,
combat, équipement et caméra. Cela rend les interactions difficiles à maintenir.
Avant la progression, prévoir des données de capacités distinctes du contrôleur
et une séparation graduelle des responsabilités, avec tests de transitions.
La présente passe ne certifie pas les performances GPU ou toutes les capacités.

## Corrections

- Plus de réécriture des matériaux quand leur fondu est stabilisé ; tableau de
  fin de fondu réutilisé et itération sans allocation de la liste des clés.
- Réapparition différée de 120 ms après perte d'occultation pour absorber les
  brèves pertes de détection au bord d'un obstacle. Désactivation de l'option :
  restauration sans ce délai supplémentaire.
- Les copies privées des contours ne sont plus enregistrées comme décor et
  n'invalident plus le cache d'association colliders/visuels.
- L'origine du scan inclut maintenant les offsets caméra utilisés par les
  effets cinématiques, comme le fait déjà la passe de silhouette.
- Vitesse de locomotion proportionnelle à l'amplitude du stick après deadzone.
  Les directions de dash et de parkour restent normalisées.
- Rotation du personnage avec lissage exponentiel, vérifié à 30, 60 et 144 Hz.

## Mesures et vérifications

Godot 4.7 stable, mode headless. `tests/camera_fade_benchmark.gd` : 128 objets
avec fondus stabilisés, cinq séries de 1 000 appels, médiane du temps CPU/appel.
Avant : 285,073 µs ; après : 115,655 µs, soit environ 59 % de réduction.
Ce benchmark mesure uniquement la boucle de mise à jour des fondus ; il ne
mesure ni les scans, ni les contours, ni le rendu GPU, ni un gain de FPS global.

Tests réussis :

- `camera_occlusion_fader_test.gd` : cas existants et régressions sur les offsets,
  les matériaux stabilisés, le délai de restauration et les copies de masque.
- `player_movement_response_test.gd` : stick partiel, vitesse maximale,
  arrêt et rotation à plusieurs fréquences.
- `enemy_attack_outline_test.gd`.
- `combat_wall_attach_reconciliation_test.gd`.
- Lancement de `combat_lab.tscn` pendant 180 images, code de sortie 0.
- `git diff --check`.

Pour lancer un test : exécuter Godot avec `--headless --path . --log-file
./test.log --script res://tests/<nom>.gd`. Le chemin de log explicite évite
l'échec d'accès au journal user:// dans l'environnement restreint.

Avertissements observés : accès au magasin de certificats Windows, impossibilité
d'enregistrer les paramètres Gore HUD dans cet environnement, alias root_2 du
skin Samus ; à la sortie des scénarios avec personnage complet, deux objets et
une ressource encore en usage. Leur origine n'a pas été isolée dans cette passe.
Les tests isolés de caméra et de mouvement n'affichent pas cette fuite de sortie.

## Ressenti : pistes pour la prochaine passe

L'attaque légère au clic gauche est déclenchée au **relâchement**, afin de
distinguer clic court et charge lourde. Ce choix peut expliquer une impression
de latence ; c'est une hypothèse à comparer en jeu avant de changer les commandes.
Le saut ne possède pas de buffer général pour une pression juste avant
l'atterrissage après épuisement des sauts. Ce serait une autre amélioration de
réactivité à tester avec les transitions parkour/slide existantes.

Validation visuelle encore nécessaire : longer un mur en tournant la caméra,
entrer sous un toit et dans une foule, déclencher un cadrage cinématique, puis
désactiver l'occultation. Vérifier le compromis des 120 ms de maintien et la
lecture des superpositions transparentes. Les matériaux ShaderMaterial utilisent
toujours le matériau de secours existant : préserver leur style demanderait un
traitement dédié. Aucun test de confort visuel ou profilage GPU n'a été réalisé.
