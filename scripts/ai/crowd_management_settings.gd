extends RefCounted
class_name HopliteCrowdManagementSettings

## Shared, data-only crowd tuning contract.
##
## Runtime systems read the ProjectSettings mirror. The global settings panel
## persists the same values in user:// and republishes them here, so Forge tests
## can tune a live battle without instantiating configuration Nodes per soldier.

const PROJECT_PREFIX := "hoplite/crowd/"
const CONFIG_SECTION := "crowd_management"
const CONFIG_SCHEMA_VERSION := 5

const DEFINITIONS := [
	{"section": "ANNEAUX", "id": &"slots_per_ring", "label": "PLACES PAR ANNEAU", "description": "Nombre maximal de soldats individuels répartis sur chaque cercle. N'affecte pas les phalanges.", "default": 6.0, "min": 4.0, "max": 12.0, "step": 1.0, "unit": ""},
	{"section": "ANNEAUX", "id": &"contact_radius", "label": "RAYON DE CONTACT", "description": "Distance entre le joueur et les postes du premier cercle de mêlée.", "default": 1.78, "min": 1.35, "max": 3.5, "step": 0.05, "unit": "m"},
	{"section": "ANNEAUX", "id": &"ring_spacing", "label": "ECART ENTRE ANNEAUX", "description": "Distance supplémentaire entre le cercle de contact et chaque ligne de réserve.", "default": 1.18, "min": 0.65, "max": 3.0, "step": 0.05, "unit": "m"},
	{"section": "ANNEAUX", "id": &"contact_slot_tolerance", "label": "TOLERANCE DU POSTE DE CONTACT", "description": "Distance maximale à son poste pour qu'un soldat du premier cercle ait réellement le droit d'attaquer.", "default": 0.90, "min": 0.25, "max": 2.0, "step": 0.05, "unit": "m"},
	{"section": "ANNEAUX", "id": &"contact_swap_hysteresis", "label": "STABILITE DES REMPLACEMENTS", "description": "Avantage temporaire donné aux combattants déjà au contact. Plus haut réduit les permutations; plus bas remplace plus vite par le soldat le plus proche.", "default": 0.45, "min": 0.0, "max": 1.5, "step": 0.05, "unit": "m"},
	{"section": "ROTATION", "id": &"rotation_speed_degrees", "label": "VITESSE DE ROTATION", "description": "Vitesse orbitale des soldats individuels. Les phalanges n'utilisent jamais cette rotation.", "default": 7.5, "min": 0.0, "max": 28.0, "step": 0.5, "unit": "deg/s"},
	{"section": "ROTATION", "id": &"rotation_variation", "label": "VARIATION ENTRE ANNEAUX", "description": "Différence déterministe de vitesse entre les cercles de réserve pour éviter un mouvement trop mécanique.", "default": 0.18, "min": 0.0, "max": 0.55, "step": 0.01, "unit": "x"},
	{"section": "ROTATION", "id": &"contact_rotation_scale", "label": "ROTATION DE L'ANNEAU DE CONTACT", "description": "Multiplicateur appliqué au premier cercle individuel. 0 le rend immobile; 1 utilise la vitesse complète.", "default": 0.35, "min": 0.0, "max": 1.0, "step": 0.05, "unit": "x"},
	{"section": "ROLES", "id": &"ranged_min_ring", "label": "ANNEAU MINIMUM DES DISTANCES", "description": "Premier cercle accessible aux archers et autres unités à distance.", "default": 2.0, "min": 1.0, "max": 6.0, "step": 1.0, "unit": ""},
	{"section": "ROLES", "id": &"boss_inner_radius", "label": "RAYON INTERIEUR BOSS", "description": "Position des boss et mini-boss à l'intérieur de la foule. Ils ne participent pas à la rotation.", "default": 1.05, "min": 0.55, "max": 1.65, "step": 0.05, "unit": "m"},
	{"section": "PHALANGE — DEPLACEMENT", "id": &"phalanx_advance_speed", "label": "VITESSE DU FRONT", "description": "Vitesse réelle de déplacement de l'ancre commune vers sa position tactique. C'est le réglage principal pour accélérer toute la phalange.", "default": 3.25, "min": 0.5, "max": 8.0, "step": 0.05, "unit": "m/s"},
	{"section": "PHALANGE — DEPLACEMENT", "id": &"phalanx_move_speed_multiplier", "label": "RATTRAPAGE DES HOPLITES", "description": "Multiplicateur de vitesse individuelle utilisé pour rejoindre un poste qui avance. Augmentez-le si l'arrière de la phalange prend du retard.", "default": 1.30, "min": 0.75, "max": 2.5, "step": 0.05, "unit": "x"},
	{"section": "PHALANGE — DEPLACEMENT", "id": &"phalanx_arrival_slowdown_distance", "label": "DISTANCE DE FREINAGE", "description": "Distance au poste où commence le ralentissement final. Plus bas rend l'arrivée plus vive; la tolérance d'arrêt reste séparée et sûre.", "default": 0.55, "min": 0.30, "max": 1.5, "step": 0.05, "unit": "m"},
	{"section": "PHALANGE — DEPLACEMENT", "id": &"phalanx_arrival_min_speed_scale", "label": "VITESSE MINIMALE AU FREINAGE", "description": "Part de la vitesse conservée juste avant l'arrêt. 0.80 conserve 80 % jusqu'aux derniers centimètres.", "default": 0.80, "min": 0.35, "max": 1.0, "step": 0.05, "unit": "x"},
	{"section": "PHALANGE — FORMATION", "id": &"phalanx_columns", "label": "COLONNES PAR RANG", "description": "Largeur maximale de chaque rang. Les identités gauche/droite restent persistantes lorsque ce nombre ne change pas.", "default": 5.0, "min": 3.0, "max": 7.0, "step": 1.0, "unit": ""},
	{"section": "PHALANGE — FORMATION", "id": &"phalanx_column_spacing", "label": "ECART ENTRE COLONNES", "description": "Distance horizontale entre deux hoplites voisins d'un même rang.", "default": 1.10, "min": 0.85, "max": 1.8, "step": 0.05, "unit": "m"},
	{"section": "PHALANGE — FORMATION", "id": &"phalanx_rank_spacing", "label": "ECART ENTRE RANGS", "description": "Distance en profondeur entre le rang de boucliers et les rangs de soutien.", "default": 1.20, "min": 0.90, "max": 2.0, "step": 0.05, "unit": "m"},
	{"section": "PHALANGE — FORMATION", "id": &"phalanx_assembly_tolerance", "label": "TOLERANCE DE RASSEMBLEMENT", "description": "Distance à son poste sous laquelle un hoplite est considéré correctement placé.", "default": 0.92, "min": 0.35, "max": 2.0, "step": 0.05, "unit": "m"},
	{"section": "PHALANGE — FORMATION", "id": &"phalanx_assembly_timeout", "label": "DELAI AVANT FORMATION DEGRADEE", "description": "Temps maximal avant d'autoriser une formation incomplète mais encore fonctionnelle.", "default": 3.5, "min": 1.0, "max": 8.0, "step": 0.1, "unit": "s"},
	{"section": "PHALANGE — FORMATION", "id": &"phalanx_degraded_ready_ratio", "label": "RATIO MINIMUM EN MODE DEGRADE", "description": "Part minimale des survivants à leur poste pour activer une formation dégradée.", "default": 0.60, "min": 0.35, "max": 0.90, "step": 0.05, "unit": "x"},
	{"section": "PHALANGE — FORMATION", "id": &"phalanx_turn_speed_degrees", "label": "PIVOT PENDANT LE RASSEMBLEMENT", "description": "Vitesse de réorientation avant que la ligne soit formée. Une ligne formée conserve son axe et utilise ensuite le demi-tour sur place.", "default": 45.0, "min": 8.0, "max": 180.0, "step": 1.0, "unit": "deg/s"},
	{"section": "PHALANGE — FORMATION", "id": &"phalanx_about_face_threshold_degrees", "label": "SEUIL DU DEMI-TOUR SUR PLACE", "description": "Angle réellement utilisé par une ligne formée pour échanger les rangs avant/arrière sans jamais inverser ses colonnes.", "default": 120.0, "min": 95.0, "max": 170.0, "step": 5.0, "unit": "deg"},
	{"section": "PHALANGE — COORDINATION", "id": &"phalanx_primary_cohorts", "label": "PHALANGES SUR L'ARC PRINCIPAL", "description": "Nombre maximal de cohortes placées côte à côte. Avec 4, elles peuvent fermer complètement le cercle.", "default": 4.0, "min": 2.0, "max": 4.0, "step": 1.0, "unit": ""},
	{"section": "PHALANGE — COORDINATION", "id": &"phalanx_coordination_distance", "label": "DISTANCE DE COORDINATION", "description": "Distance au joueur sous laquelle des phalanges distinctes activent leurs arcs coordonnés.", "default": 6.5, "min": 3.0, "max": 14.0, "step": 0.25, "unit": "m"},
	{"section": "PHALANGE — COORDINATION", "id": &"phalanx_two_coverage_degrees", "label": "COUVERTURE DE DEUX PHALANGES", "description": "Angle total occupé par deux cohortes coordonnées autour du joueur.", "default": 180.0, "min": 150.0, "max": 330.0, "step": 5.0, "unit": "deg"},
	{"section": "PHALANGE — COORDINATION", "id": &"phalanx_three_coverage_degrees", "label": "COUVERTURE DE TROIS PHALANGES", "description": "Angle total occupé par trois cohortes coordonnées autour du joueur.", "default": 280.0, "min": 240.0, "max": 355.0, "step": 5.0, "unit": "deg"},
	{"section": "PHALANGE — COORDINATION", "id": &"phalanx_multi_arc_radius_multiplier", "label": "DISTANCE DES ARCS COORDONNES", "description": "Multiplicateur de la distance tactique utilisée par les arcs de plusieurs cohortes.", "default": 2.0, "min": 1.0, "max": 3.0, "step": 0.05, "unit": "x"},
	{"section": "PHALANGE — COORDINATION", "id": &"phalanx_support_ring_spacing", "label": "RECUL DES COHORTES DE SOUTIEN", "description": "Distance séparant les phalanges supplémentaires du groupe principal déjà complet.", "default": 2.65, "min": 1.2, "max": 6.0, "step": 0.05, "unit": "m"},
	{"section": "PHALANGE — COORDINATION", "id": &"phalanx_arc_transition", "label": "TRANSITION VERS LES ARCS", "description": "Durée de transition utilisée par les arcs coordonnés et l'expulsion d'une phalange seule.", "default": 1.35, "min": 0.35, "max": 4.0, "step": 0.05, "unit": "s"},
	{"section": "PHALANGE — INTRUSION", "id": &"phalanx_single_arc_degrees", "label": "ARC D'EXPULSION SOLITAIRE", "description": "Courbure temporaire d'une phalange seule lorsque le joueur pénètre sa ligne droite.", "default": 136.0, "min": 70.0, "max": 190.0, "step": 2.0, "unit": "deg"},
	{"section": "PHALANGE — INTRUSION", "id": &"phalanx_intrusion_depth", "label": "SEUIL DE PENETRATION", "description": "Profondeur à laquelle le joueur doit franchir une phalange seule pour déclencher son arc d'expulsion.", "default": 0.72, "min": -0.5, "max": 2.0, "step": 0.05, "unit": "m"},
	{"section": "PHALANGE — INTRUSION", "id": &"phalanx_intrusion_margin", "label": "MARGE LATERALE D'INTRUSION", "description": "Largeur supplémentaire surveillée sur les côtés de la ligne contre les contournements proches.", "default": 2.35, "min": 0.5, "max": 5.0, "step": 0.05, "unit": "m"},
	{"section": "PHALANGE — INTRUSION", "id": &"phalanx_response_duration", "label": "DUREE DE L'EXPULSION", "description": "Temps pendant lequel une phalange seule maintient sa réponse d'expulsion.", "default": 5.6, "min": 1.5, "max": 10.0, "step": 0.1, "unit": "s"},
	{"section": "PHALANGE — SORTIES", "id": &"phalanx_sortie_size", "label": "HOPLITES PAR SORTIE", "description": "Nombre total d'hoplites qui quittent momentanément les arcs coordonnés pour frapper.", "default": 3.0, "min": 1.0, "max": 5.0, "step": 1.0, "unit": ""},
	{"section": "PHALANGE — SORTIES", "id": &"phalanx_sortie_attack_radius", "label": "RAYON D'ATTAQUE DE LA SORTIE", "description": "Distance au joueur réellement visée par les hoplites de sortie.", "default": 2.25, "min": 1.65, "max": 3.2, "step": 0.05, "unit": "m"},
	{"section": "PHALANGE — SORTIES", "id": &"phalanx_sortie_advance_duration", "label": "DUREE DE L'AVANCEE", "description": "Temps prévu pour quitter l'arc et atteindre le rayon d'attaque.", "default": 0.90, "min": 0.30, "max": 2.5, "step": 0.05, "unit": "s"},
	{"section": "PHALANGE — SORTIES", "id": &"phalanx_sortie_strike_duration", "label": "FENETRE DE FRAPPE", "description": "Temps pendant lequel la sortie tient sa position avancée et peut demander une attaque.", "default": 1.35, "min": 0.40, "max": 3.0, "step": 0.05, "unit": "s"},
	{"section": "PHALANGE — SORTIES", "id": &"phalanx_sortie_return_duration", "label": "DUREE DU RETOUR", "description": "Temps prévu pour revenir exactement aux places de l'arc après la frappe.", "default": 0.90, "min": 0.30, "max": 2.5, "step": 0.05, "unit": "s"},
	{"section": "PHALANGE — SORTIES", "id": &"phalanx_sortie_rest_duration", "label": "PAUSE ENTRE SORTIES", "description": "Temps durant lequel le mur est entièrement reformé avant le départ suivant.", "default": 0.85, "min": 0.20, "max": 3.0, "step": 0.05, "unit": "s"},
	{"section": "RYTHME", "id": &"base_attack_capacity", "label": "ATTAQUANTS SIMULTANES", "description": "Nombre d'autorisations d'attaque simultanées pendant un combat peu dense.", "default": 2.0, "min": 1.0, "max": 6.0, "step": 1.0, "unit": ""},
	{"section": "RYTHME", "id": &"dense_attack_capacity", "label": "ATTAQUANTS SOUS FORTE PRESSION", "description": "Nombre d'attaquants simultanés lorsque beaucoup d'ennemis entourent la cible.", "default": 3.0, "min": 1.0, "max": 8.0, "step": 1.0, "unit": ""},
	{"section": "RYTHME", "id": &"dense_pressure_threshold", "label": "SEUIL DE FORTE PRESSION", "description": "Nombre d'ennemis proches nécessaire pour utiliser la capacité d'attaque dense.", "default": 10.0, "min": 4.0, "max": 30.0, "step": 1.0, "unit": "soldats"},
	{"section": "RYTHME", "id": &"defense_reaction_jitter", "label": "DECALAGE DES REACTIONS DEFENSIVES", "description": "Petit décalage déterministe qui évite que toute la foule bloque exactement au même instant.", "default": 0.06, "min": 0.0, "max": 0.25, "step": 0.01, "unit": "s"},
	{"section": "RYTHME", "id": &"attack_lease_lifetime", "label": "DUREE D'UNE AUTORISATION D'ATTAQUE", "description": "Durée maximale réservée à un attaquant avant que sa place dans la file d'attaque soit libérée.", "default": 2.15, "min": 0.6, "max": 5.0, "step": 0.05, "unit": "s"},
	{"section": "RYTHME", "id": &"pressure_radius", "label": "RAYON DE CALCUL DE PRESSION", "description": "Zone autour du joueur utilisée pour décider si le combat est suffisamment dense.", "default": 10.0, "min": 4.0, "max": 20.0, "step": 0.5, "unit": "m"},
	{"section": "PERFORMANCE", "id": &"spatial_refresh_hz", "label": "MISE A JOUR SPATIALE", "description": "Fréquence de reconstruction de la grille locale utilisée pour compter rapidement les combattants proches.", "default": 20.0, "min": 5.0, "max": 40.0, "step": 1.0, "unit": "Hz"},
	{"section": "PERFORMANCE", "id": &"contact_rebalance_hz", "label": "REEQUILIBRAGE DU CONTACT", "description": "Fréquence de remplacement du premier cercle par les soldats réellement les plus proches. 10 Hz reste fluide sans trier à chaque image.", "default": 10.0, "min": 2.0, "max": 30.0, "step": 1.0, "unit": "Hz"},
	{"section": "PERFORMANCE", "id": &"formation_layout_refresh_hz", "label": "DETECTION DES COHORTES", "description": "Fréquence CPU de détection des cohortes proches. Ne modifie pas leur vitesse de déplacement.", "default": 10.0, "min": 2.0, "max": 30.0, "step": 1.0, "unit": "Hz"},
	{"section": "PERFORMANCE", "id": &"phalanx_assignment_refresh_hz", "label": "CALCUL DES POSTES DE PHALANGE", "description": "Fréquence CPU maximale de publication des postes. Ne modifie ni la vitesse du front ni la vitesse des hoplites.", "default": 12.0, "min": 5.0, "max": 30.0, "step": 1.0, "unit": "Hz"},
]


static func defaults() -> Dictionary:
	var values: Dictionary = {}
	for definition: Dictionary in DEFINITIONS:
		values[StringName(definition["id"])] = float(definition["default"])
	return values


static func sanitize(values: Dictionary) -> Dictionary:
	var result := defaults()
	for definition: Dictionary in DEFINITIONS:
		var id := StringName(definition["id"])
		var value := float(values.get(id, values.get(String(id), definition["default"])))
		value = clampf(value, float(definition["min"]), float(definition["max"]))
		if float(definition["step"]) >= 1.0:
			value = float(roundi(value))
		result[id] = value
	return result


static func read_project_settings() -> Dictionary:
	var values := defaults()
	for definition: Dictionary in DEFINITIONS:
		var id := StringName(definition["id"])
		values[id] = ProjectSettings.get_setting(PROJECT_PREFIX + String(id), definition["default"])
	return sanitize(values)


static func apply_project_settings(values: Dictionary) -> Dictionary:
	var sanitized := sanitize(values)
	for raw_id: Variant in sanitized.keys():
		var id := StringName(raw_id)
		ProjectSettings.set_setting(PROJECT_PREFIX + String(id), sanitized[id])
	return sanitized
