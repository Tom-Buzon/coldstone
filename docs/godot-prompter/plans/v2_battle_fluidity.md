# Fluidité des batailles et mur d’escorte

Passe solo. Supprimer G gore, réserver l’entrée aux ordres. Ajouter une exclusion balayée autour des gardes B réellement présents, commune aux mouvements de masse et physiques, avec ouvertures après mort/perte de bouclier/bris de garde. Distribuer les groupes entre joueur et armée adverse ; retirer l’ancrage au spawn en défense, rapprocher le soutien, stabiliser les trajets et dégager les formations bloquées. Garder budgets et logique d’armes séparés. Skills : input-handling, physics-system, ai-navigation, godot-debugging, godot-code-review.

Validation : entrée clavier réelle (keycode + physical_keycode), gore inchangé ; test de traversée avec mouvement de masse et ouverture après décès ; quotas de groupes ; activité par formation et régressions.

Statut : implémenté. Probes escorte, authoring/quotas, trafic, retinue, Forge, crashes et rôles : PASS, sans erreur de script. Tests avec rendu : deux armées (1200 images) et escorte G puis B (1400 images), PASS ; capture de protection inspectée. Dernier test après recherche latérale des archers : 10 groupes sur 11 ont attaqué, le dernier a avancé de plus de 8 m ; environ 2186 dégâts dans le scénario. Ce sont des observations de ce test, pas une garantie de zéro attente sur toute géométrie. Budgets de pression conservés. Les avertissements de sauvegarde/certificats du sandbox et certaines libérations à fermeture restent distincts.

Correction collatérale minimale nécessaire à la validation : `_on_camera_outline_color_changed` appelait `_save_settings`, inexistant, dans audio_settings.gd ; remplacé par `_save_visual_settings` sans refaire les modifications caméra en cours.
