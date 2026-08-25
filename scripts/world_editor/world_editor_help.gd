extends Control
class_name HopliteWorldEditorHelp

signal shortcuts_changed(shortcuts: Dictionary)

const SHORTCUTS_PATH := "user://hoplite_worlds/editor_shortcuts.json"
const TUTORIAL_STEPS := ["start", "interface", "navigation", "selection", "terrain", "surfaces", "test_save"]
const DEFINITIONS := [
	{"id": "help", "category": "Général", "label": "Ouvrir / fermer l'aide", "primary": KEY_F1},
	{"id": "save", "category": "Général", "label": "Sauvegarder le monde", "primary": KEY_S, "ctrl": true},
	{"id": "undo", "category": "Général", "label": "Annuler", "primary": KEY_Z, "ctrl": true},
	{"id": "redo", "category": "Général", "label": "Rétablir", "primary": KEY_Y, "ctrl": true},
	{"id": "duplicate", "category": "Général", "label": "Dupliquer la sélection", "primary": KEY_D, "ctrl": true},
	{"id": "delete", "category": "Général", "label": "Supprimer la sélection", "primary": KEY_DELETE},
	{"id": "return_lab", "category": "Général", "label": "Retourner au laboratoire", "primary": KEY_ESCAPE},
	{"id": "select_tool", "category": "Outils", "label": "Outil Sélection", "primary": KEY_1},
	{"id": "brush_tool", "category": "Outils", "label": "Outil Placement / Pinceau", "primary": KEY_2},
	{"id": "eraser_tool", "category": "Outils", "label": "Outil Gomme", "primary": KEY_3},
	{"id": "rotate_y", "category": "Outils", "label": "Rotation horizontale", "primary": KEY_R},
	{"id": "rotate_x", "category": "Outils", "label": "Inclinaison verticale", "primary": KEY_R, "shift": true},
	{"id": "toggle_workspace", "category": "Outils", "label": "Bibliothèque / Scène", "primary": KEY_TAB},
	{"id": "focus", "category": "Vue 3D", "label": "Cadrer la sélection", "primary": KEY_F},
	{"id": "ghost", "category": "Vue 3D", "label": "Navigation libre", "primary": KEY_G},
	{"id": "test", "category": "Vue 3D", "label": "Tester le chapitre", "primary": KEY_F6},
	{"id": "move_forward", "category": "Navigation libre", "label": "Avancer", "primary": KEY_Z, "alternate": KEY_W},
	{"id": "move_back", "category": "Navigation libre", "label": "Reculer", "primary": KEY_S},
	{"id": "move_left", "category": "Navigation libre", "label": "Aller à gauche", "primary": KEY_Q, "alternate": KEY_A},
	{"id": "move_right", "category": "Navigation libre", "label": "Aller à droite", "primary": KEY_D},
	{"id": "move_up", "category": "Navigation libre", "label": "Monter", "primary": KEY_E, "alternate": KEY_SPACE},
	{"id": "move_down", "category": "Navigation libre", "label": "Descendre", "primary": KEY_C},
	{"id": "move_fast", "category": "Navigation libre", "label": "Accélérer", "primary": KEY_SHIFT},
]

const ARTICLES := [
	{"id": "start", "category": "PREMIERS PAS", "title": "Bien démarrer", "summary": "Créer, construire et tester un premier monde.", "content": """[font_size=18][b]Votre premier monde en sept étapes[/b][/font_size]

[color=#70b7d1][b]1. Créez le document[/b][/color]
Cliquez sur [b]NOUVEAU MONDE[/b], donnez-lui un nom dans la barre supérieure puis sauvegardez-le.

[color=#70b7d1][b]2. Construisez le terrain[/b][/color]
Dans [b]Contenu > Bibliothèque > Terrain[/b], créez une plaine, des collines, des crêtes, une vallée ou une côte. Réglez sa largeur et sa profondeur dans Propriétés, puis utilisez Monter, Creuser, Lisser et Aplanir directement dans la vue. Choisissez ensuite une texture pour la peindre localement et ajoutez l'herbe MultiMesh seulement où elle est utile.

[color=#70b7d1][b]3. Construisez et habillez[/b][/color]
Ajoutez des Surfaces pour les sols architecturaux, murs et blocs, puis choisissez Textures, Objets 3D, Lumières ou Portes.

[color=#70b7d1][b]4. Organisez la scène[/b][/color]
L'onglet Scène liste tous les éléments du chapitre. Cliquez sur un élément pour le sélectionner et modifier ses Propriétés.

[color=#70b7d1][b]5. Ajoutez le gameplay[/b][/color]
Placez un Départ joueur, des troupes et des déclencheurs. Le dock Propriétés expose les comportements, formations et conditions d'apparition.

[color=#70b7d1][b]6. Testez[/b][/color]
Sauvegardez puis utilisez [b]TESTER F6[/b]. Échap arrête la simulation et revient à l'édition.

[color=#70b7d1][b]7. Itérez sans risque[/b][/color]
Chaque trait de sculpture, génération ou aplatissement est annulable avec Ctrl+Z et sauvegardé dans le document du monde."""},
	{"id": "interface", "category": "PREMIERS PAS", "title": "Comprendre l'interface", "summary": "Barres, palette, bibliothèque, scène et propriétés.", "content": """[font_size=18][b]Une interface organisée comme un logiciel 3D[/b][/font_size]

[b]Barre d'application[/b] — nom du monde courant et état d'édition.
[b]Barre de commandes[/b] — laboratoire, affichage des docks, nouveau monde, sauvegarde, chargement, historique, navigation libre, test et aide.
[b]Palette verticale[/b] — Sélection, Placement, Gomme, Cadrer et Navigation libre.
[b]Contenu du monde[/b] — chapitre, grille, étendue, bibliothèque d'éléments et hiérarchie de scène.
[b]Vue 3D[/b] — surface centrale dans laquelle vous construisez et manipulez le monde.
[b]Propriétés[/b] — transformation et paramètres spécialisés de la sélection.
[b]Barre d'état[/b] — instruction contextuelle, population théorique et chapitre actif.

Les docks Contenu et Propriétés peuvent être fermés indépendamment pour agrandir la vue. La palette d'outils reste toujours accessible."""},
	{"id": "navigation", "category": "ÉDITION 3D", "title": "Naviguer dans la vue 3D", "summary": "Orbite, panoramique, zoom, cadrage et vol libre.", "content": """[font_size=18][b]Navigation caméra[/b][/font_size]

[b]Clic droit + mouvement[/b] : orbiter autour du point de vue.
[b]Clic milieu + mouvement[/b] : déplacer latéralement la vue.
[b]Molette[/b] : zoomer et dézoomer.
[b]F[/b] : cadrer précisément l'élément sélectionné.

[color=#e2a85f][b]Navigation libre[/b][/color]
Appuyez sur G ou sur NAVIGATION LIBRE. Déplacez-vous avec ZQSD ou WASD, montez avec E/Espace, descendez avec C et accélérez avec Maj. Le clic droit oriente la caméra.

La navigation libre ne désactive pas l'édition : sélection, pinceau, gomme et propriétés continuent de fonctionner."""},
	{"id": "selection", "category": "ÉDITION 3D", "title": "Sélection et transformations", "summary": "Déplacer, tourner, incliner, dimensionner et dupliquer.", "content": """[font_size=18][b]Manipuler un élément[/b][/font_size]

[b]Sélection[/b] : outil 1 puis clic dans la vue, ou clic dans l'onglet Scène.
[b]Déplacement horizontal[/b] : Ctrl + clic-glissé sur la sélection.
[b]Déplacement vertical[/b] : Maj + clic-glissé. Le sol devient vert lorsque le point bas est aligné.
[b]Rotation horizontale[/b] : R puis mouvement de souris.
[b]Inclinaison verticale[/b] : Maj+R puis mouvement de souris.
[b]Aimantation angulaire[/b] : maintenez Ctrl pendant une rotation pour des pas de 15°.
[b]Valider / annuler[/b] : clic gauche ou Entrée / clic droit ou Échap.
[b]Cadrer[/b] : F.
[b]Dupliquer[/b] : Ctrl+D.
[b]Supprimer[/b] : Suppr.

Les surfaces possèdent six poignées dimensionnelles. Les modèles 3D utilisent une poignée dorée d'échelle uniforme afin de préserver leurs proportions."""},
	{"id": "terrain", "category": "CONSTRUCTION", "title": "Créer et sculpter le terrain", "summary": "Heightfield natif, relief procédural, collision, pinceaux et textures.", "content": """[font_size=18][b]Le mode Terrain[/b][/font_size]

Ouvrez [b]Terrain — Créer & sculpter[/b]. La Forge crée un heightfield Godot dont le maillage visible et la collision utilisent exactement les mêmes hauteurs.

[color=#e2a85f][b]Bases disponibles[/b][/color]
[b]Plaine[/b] : base parfaitement plate pour une arène ou une ville.
[b]Collines[/b] : relief naturel polyvalent.
[b]Crêtes[/b] : lignes rocheuses et positions dominantes.
[b]Vallée[/b] : axe central bas encadré par deux versants.
[b]Côte[/b] : pente générale utilisable pour plage, falaise ou rive.

[color=#e2a85f][b]Sculpture dans la vue[/b][/color]
[b]Monter[/b] élève le terrain ; [b]Creuser[/b] l'abaisse ; [b]Lisser[/b] retire les cassures ; [b]Aplanir[/b] rapproche le relief de la hauteur du premier clic. Maintenez le clic gauche et déplacez la souris. Maj inverse temporairement Monter et Creuser.

Le rayon règle la surface touchée et la force règle la variation par passage. Un trait complet correspond à une seule étape Ctrl+Z.

[color=#e2a85f][b]Dimensions, génération et précision[/b][/color]
Dans Propriétés, [b]Largeur X[/b] et [b]Profondeur Z[/b] règlent indépendamment la taille physique de 8 à 512 mètres. La résolution contrôle uniquement le nombre de points. Changer la résolution rééchantillonne le relief et les cartes peintes existantes.

Le seed rend le relief reproductible. L'amplitude contrôle la hauteur, la fréquence la taille des formes et les octaves leur détail.

Une résolution élevée donne un terrain plus détaillé mais alourdit le JSON et la reconstruction. 65 × 65 est le compromis recommandé pour un terrain moyen. Utilisez [b]Lisser tout[/b] pour rendre un terrain procédural jouable et [b]Aplatir tout[/b] pour repartir d'une base propre.

[color=#e2a85f][b]Peinture locale des textures[/b][/color]
Sélectionnez le terrain puis choisissez un matériau dans [b]Textures & matériaux[/b]. Ce choix équipe [b]Peindre la texture[/b] au lieu de remplacer tout le terrain. Clic-glissez sur les zones voulues ; [b]Retrouver la base[/b] efface progressivement la peinture. La texture de base reste modifiable dans Propriétés. Trois couches locales peuvent coexister.

[color=#e2a85f][b]Végétation MultiMesh[/b][/color]
[b]Peindre l'herbe[/b] ajoute une densité locale ; [b]Retirer l'herbe[/b] la diminue. Le preset méditerranéen combine herbes courtes et hautes, trèfles et fougères CC0 en quelques MultiMesh sans collision ni ombre individuelle. Quantité et seed sont dans Propriétés. Les objets, troupes, portes et surfaces peuvent toujours être posés directement sur le relief."""},
	{"id": "surfaces", "category": "CONSTRUCTION", "title": "Construire avec les surfaces", "summary": "Sols, murs, blocs, dimensions, textures et peinture continue.", "content": """[font_size=18][b]Le constructeur de surface[/b][/font_size]

Les surfaces forment la base de chaque niveau. Le sélecteur bleu [b]SURFACES — SOLS, MURS, BLOCS[/b] ouvre l'outil principal encadré en cuivre.

[b]Sol[/b] : plateforme horizontale.
[b]Mur[/b] : paroi verticale.
[b]Bloc[/b] : volume libre.

Réglez X (largeur), Y (hauteur) et Z (profondeur), puis cliquez sur [b]ACTIVER LE PINCEAU SURFACE[/b]. Un clic place une surface. Maintenir le clic peint en continu ; maintenir Maj force une ligne droite. Le pas de grille contrôle l'aimantation.

La catégorie Textures applique un matériau à la surface sélectionnée et au prochain pinceau. Après placement, utilisez les poignées colorées ou le dock Propriétés pour ajuster précisément la géométrie."""},
	{"id": "assets", "category": "CONSTRUCTION", "title": "Objets, textures et lumières", "summary": "Décor automatique, matériaux PBR et éclairage.", "content": """[font_size=18][b]Habiller le monde[/b][/font_size]

[b]Objets 3D[/b] détecte automatiquement les modèles de la bibliothèque du projet. Équipez un objet puis cliquez dans la vue ; il est ancré sur le dessus du sol visé.

[b]Textures[/b] contient les matériaux PBR avec un aperçu de leur texture source. Sur une surface, le choix est appliqué immédiatement ; sur un terrain, il équipe le pinceau de texture locale. La texture Mediterranean grass a été créée pour le sol antique et ne doit pas être confondue avec l'atlas transparent des brins d'herbe.

[b]Lumières[/b] propose une lumière omnidirectionnelle et un projecteur. Après placement, configurez couleur, énergie, portée, angle et ombres dans Propriétés."""},
	{"id": "characters", "category": "GAMEPLAY", "title": "Personnages et troupes", "summary": "Spawns, formations, comportements, vagues et réserves.", "content": """[font_size=18][b]Créer une rencontre[/b][/font_size]

Placez d'abord un [b]Départ joueur[/b], puis une Troupe ennemie ou un préréglage Phalange 15.

Dans Propriétés, réglez l'archétype, l'effectif, le rang, l'échelle et la formation : ligne, colonne, carré, cercle, coin, phalange, arc ou dispersée.

Les comportements disponibles sont normal, attente, patrouille et protection. Pour une patrouille, utilisez [b]Tracer / compléter la patrouille[/b] puis cliquez les points au sol. Pour une protection, cliquez directement l'objet ou la troupe cible.

Le déploiement peut être immédiat, en vagues périodiques ou en réserve progressive. Les conditions d'apparition couvrent le lancement, une zone, la mort d'un groupe et un timer."""},
	{"id": "logic", "category": "GAMEPLAY", "title": "Déclencheurs et narration", "summary": "Conditions, actions, références cartographiques et atmosphères.", "content": """[font_size=18][b]Programmer sans code[/b][/font_size]

Un Déclencheur est un volume logique visible uniquement dans la Forge. Il peut réagir à l'entrée du joueur, à la mort totale ou partielle d'une troupe, ou servir de zone nommée.

Ses actions peuvent ouvrir une porte, générer ou retirer une troupe, retirer tous les ennemis, afficher une narration, changer la musique ou appliquer une atmosphère.

Les boutons Carte permettent de choisir les cibles directement dans la vue. Entrée termine une capture ; clic droit ou Échap l'annule.

Un Texte réutilisable ne se déclenche jamais seul : il doit être référencé par une action de narration. Les zones d'atmosphère modifient localement soleil, ambiance et brouillard."""},
	{"id": "chapters", "category": "ORGANISATION", "title": "Chapitres, portes et passages", "summary": "Découper le monde et relier les zones.", "content": """[font_size=18][b]Construire un monde en plusieurs chapitres[/b][/font_size]

Le sélecteur Chapitre ouvre une zone sans mélanger ses objets avec les autres. Le bouton + voisin crée un chapitre vide et le champ inférieur le renomme.

Placez un [b]Point d'arrivée[/b] avec un identifiant, puis un [b]Passage de chapitre[/b] visant le chapitre et cet identifiant. En jeu, l'ancien chapitre est entièrement libéré avant la reconstruction du suivant.

Les portes existent en bois, fer, pierre et bronze, avec mouvements vertical, coulissant ou pivotant. Un déclencheur peut cibler une porte directement sur la carte et l'ouvrir."""},
	{"id": "test_save", "category": "ORGANISATION", "title": "Tester et sauvegarder", "summary": "Simulation locale, validation, fichiers et historique.", "content": """[font_size=18][b]Valider votre monde[/b][/font_size]

[b]Ctrl+S[/b] sauvegarde dans user://hoplite_worlds. La version précédente est conservée en .bak et la sauvegarde utilise un remplacement sécurisé.

[b]F6[/b] reconstruit tout le chapitre actif et lance le vrai joueur, la vraie IA et les événements. La sélection et la position de la caméra ne filtrent jamais les rencontres. Les troupes réglées sur [b]Au lancement[/b] apparaissent immédiatement ; celles liées à une zone, une mort ou un timer attendent leur condition. Échap arrête le test.

[b]Ctrl+Z / Ctrl+Y[/b] annule ou rétablit les modifications. La Gomme et Suppr restent donc récupérables.

La barre d'état affiche la population théorique du chapitre. Elle prévient lorsque l'effectif approche ou dépasse la limite de sécurité."""},
	{"id": "shortcuts", "category": "RÉFÉRENCE", "title": "Raccourcis personnalisables", "summary": "Consulter, modifier et réinitialiser toutes les commandes clavier.", "content": ""},
]

var shortcuts: Dictionary = {}
var articles_by_id: Dictionary = {}
var navigation: VBoxContainer
var navigation_scroll: ScrollContainer
var search_edit: LineEdit
var content_host: VBoxContainer
var article_title: Label
var breadcrumb: Label
var status_label: Label
var header_shortcut_hint: Label
var current_article_id := "start"
var capture_id := ""
var capture_slot := ""
var capture_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	for article: Dictionary in ARTICLES:
		articles_by_id[String(article.get("id", ""))] = article
	_load_shortcuts()
	_build_ui()
	visible = false

func open(article_id: String = "start") -> void:
	visible = true
	if header_shortcut_hint != null:
		header_shortcut_hint.text = binding_text("help")
	_show_article(article_id if articles_by_id.has(article_id) else "start")
	search_edit.grab_focus()

func close() -> void:
	_cancel_capture()
	visible = false

func get_shortcuts() -> Dictionary:
	return shortcuts.duplicate(true)

func matches(event: InputEventKey, action_id: String) -> bool:
	if not shortcuts.has(action_id) or not event.pressed or event.echo:
		return false
	var binding := shortcuts[action_id] as Dictionary
	var keycode := int(event.keycode)
	var primary := int(binding.get("primary", 0))
	var alternate := int(binding.get("alternate", 0))
	return (keycode == primary or (alternate > 0 and keycode == alternate)) and event.ctrl_pressed == bool(binding.get("ctrl", false)) and event.shift_pressed == bool(binding.get("shift", false)) and not event.alt_pressed and not event.meta_pressed

func is_action_pressed(action_id: String) -> bool:
	if not shortcuts.has(action_id):
		return false
	var binding := shortcuts[action_id] as Dictionary
	var primary := int(binding.get("primary", 0))
	var alternate := int(binding.get("alternate", 0))
	return (primary > 0 and Input.is_key_pressed(primary)) or (alternate > 0 and Input.is_key_pressed(alternate))

func binding_text(action_id: String) -> String:
	if not shortcuts.has(action_id):
		return "—"
	return _binding_text(shortcuts[action_id] as Dictionary)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if capture_id.is_empty():
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or matches(event, "help")):
			close()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	get_viewport().set_input_as_handled()
	if key_event.keycode == KEY_ESCAPE:
		_cancel_capture()
		return
	if capture_slot == "alternate" and key_event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		(shortcuts[capture_id] as Dictionary)["alternate"] = 0
		_save_shortcuts()
		shortcuts_changed.emit(get_shortcuts())
		_cancel_capture()
		_show_article("shortcuts")
		return
	var candidate := {
		"primary": int(key_event.keycode),
		"ctrl": key_event.ctrl_pressed,
		"shift": key_event.shift_pressed,
	}
	if _has_conflict(capture_id, candidate):
		status_label.text = "Ce raccourci est déjà utilisé. Choisissez une autre combinaison."
		status_label.modulate = Color("e86d67")
		return
	var binding := shortcuts[capture_id] as Dictionary
	binding[capture_slot] = int(key_event.keycode)
	binding["ctrl"] = key_event.ctrl_pressed
	binding["shift"] = key_event.shift_pressed
	_save_shortcuts()
	shortcuts_changed.emit(get_shortcuts())
	_cancel_capture()
	_show_article("shortcuts")

func _build_ui() -> void:
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.015, 0.018, 0.023, 0.92)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	var shell := PanelContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	shell.add_theme_stylebox_override("panel", _style(Color("191d23"), Color("47505c"), 5, 0))
	add_child(shell)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 0)
	shell.add_child(root_box)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 54
	header.add_theme_constant_override("separation", 8)
	header.add_theme_stylebox_override("panel", _style(Color("20252c"), Color("20252c"), 0, 10))
	root_box.add_child(header)
	var mark := Label.new()
	mark.text = "?"
	mark.custom_minimum_size = Vector2(36, 36)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 18)
	mark.add_theme_color_override("font_color", Color("101318"))
	mark.add_theme_stylebox_override("normal", _style(Color("70b7d1"), Color("70b7d1"), 4, 0))
	header.add_child(mark)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.add_child(_label("CENTRE D'AIDE", 15, Color("f0f3f7")))
	titles.add_child(_label("GUIDES · TUTORIELS · RÉFÉRENCE", 9, Color("84909e")))
	header.add_child(titles)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "⌕  Rechercher dans l'aide…"
	search_edit.custom_minimum_size = Vector2(310, 34)
	search_edit.text_changed.connect(_rebuild_navigation)
	header.add_child(search_edit)
	header_shortcut_hint = _label(binding_text("help"), 10, Color("9da6b2"))
	header_shortcut_hint.add_theme_stylebox_override("normal", _style(Color("15191e"), Color("3b424c"), 3, 7))
	header.add_child(header_shortcut_hint)
	header.add_child(_button("×  FERMER", close, Color("343a43")))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root_box.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 278
	sidebar.add_theme_constant_override("separation", 8)
	sidebar.add_theme_stylebox_override("panel", _style(Color("171b20"), Color("303640"), 0, 12))
	body.add_child(sidebar)
	var tutorial_panel := PanelContainer.new()
	tutorial_panel.add_theme_stylebox_override("panel", _style(Color("24313a"), Color("4e7b91"), 4, 10))
	sidebar.add_child(tutorial_panel)
	var tutorial_box := VBoxContainer.new()
	tutorial_panel.add_child(tutorial_box)
	tutorial_box.add_child(_label("PARCOURS GUIDÉ", 10, Color("70b7d1")))
	var tutorial_text := _label("Apprenez la Forge en 7 étapes, du premier terrain au test jouable.", 11, Color("c9d0d9"))
	tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_box.add_child(tutorial_text)
	tutorial_box.add_child(_button("▶  COMMENCER LE TUTORIEL", func() -> void: _show_article(TUTORIAL_STEPS[0]), Color("315f73")))
	navigation_scroll = ScrollContainer.new()
	navigation_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(navigation_scroll)
	navigation = VBoxContainer.new()
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_theme_constant_override("separation", 3)
	navigation_scroll.add_child(navigation)

	var content_panel := VBoxContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_constant_override("separation", 0)
	body.add_child(content_panel)
	var article_header := VBoxContainer.new()
	article_header.custom_minimum_size.y = 74
	article_header.add_theme_constant_override("separation", 1)
	article_header.add_theme_stylebox_override("panel", _style(Color("1e232a"), Color("343b45"), 0, 18))
	content_panel.add_child(article_header)
	breadcrumb = _label("AIDE", 9, Color("758391"))
	article_header.add_child(breadcrumb)
	article_title = _label("", 22, Color("f0f2f5"))
	article_header.add_child(article_title)
	content_host = VBoxContainer.new()
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_host.add_theme_constant_override("separation", 8)
	content_panel.add_child(content_host)
	status_label = _label("Les raccourcis modifiés sont sauvegardés automatiquement.", 10, Color("87929f"))
	status_label.custom_minimum_size.y = 28
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_stylebox_override("normal", _style(Color("171b20"), Color("303640"), 0, 12))
	content_panel.add_child(status_label)
	_apply_theme(shell)
	_rebuild_navigation("")

func _rebuild_navigation(query: String) -> void:
	if navigation == null:
		return
	for child: Node in navigation.get_children():
		child.queue_free()
	var normalized := query.to_lower().strip_edges()
	var last_category := ""
	for article: Dictionary in ARTICLES:
		var searchable := "%s %s %s" % [article.get("title", ""), article.get("summary", ""), article.get("content", "")]
		if not normalized.is_empty() and normalized not in searchable.to_lower():
			continue
		var category := String(article.get("category", "AIDE"))
		if category != last_category:
			var category_label := _label(category, 9, Color("737e8c"))
			category_label.custom_minimum_size.y = 23
			category_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			navigation.add_child(category_label)
			last_category = category
		var article_id := String(article.get("id", ""))
		var button := _button(String(article.get("title", "Article")), func() -> void: _show_article(article_id), Color("292e35") if article_id == current_article_id else Color("1d2228"))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = String(article.get("summary", ""))
		navigation.add_child(button)
	if navigation.get_child_count() == 0:
		navigation.add_child(_label("Aucun article trouvé.", 11, Color("8d97a4")))

func _show_article(article_id: String) -> void:
	if not articles_by_id.has(article_id):
		return
	_cancel_capture()
	current_article_id = article_id
	var article := articles_by_id[article_id] as Dictionary
	article_title.text = String(article.get("title", "Aide"))
	breadcrumb.text = "AIDE  /  %s" % String(article.get("category", "RÉFÉRENCE"))
	for child: Node in content_host.get_children():
		child.queue_free()
	if article_id == "shortcuts":
		_build_shortcuts_page()
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		content_host.add_child(scroll)
		var article_box := VBoxContainer.new()
		article_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		article_box.add_theme_constant_override("separation", 14)
		scroll.add_child(article_box)
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.custom_minimum_size.x = 720
		text.add_theme_font_size_override("normal_font_size", 13)
		text.add_theme_color_override("default_color", Color("cbd2db"))
		text.text = String(article.get("content", ""))
		article_box.add_child(text)
		_add_tutorial_navigation(article_box, article_id)
	status_label.text = "Article %d/%d  ·  Utilisez la recherche pour retrouver une fonction." % [_article_index(article_id) + 1, ARTICLES.size()]
	status_label.modulate = Color.WHITE
	_rebuild_navigation(search_edit.text if search_edit != null else "")

func _add_tutorial_navigation(parent: VBoxContainer, article_id: String) -> void:
	var step := TUTORIAL_STEPS.find(article_id)
	if step < 0:
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("222a31"), Color("415d6c"), 4, 10))
	parent.add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	row.add_child(_label("TUTORIEL  ·  ÉTAPE %d / %d" % [step + 1, TUTORIAL_STEPS.size()], 10, Color("70b7d1")))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(spacer)
	if step > 0:
		var previous_id := String(TUTORIAL_STEPS[step - 1])
		row.add_child(_button("‹  PRÉCÉDENT", func() -> void: _show_article(previous_id)))
	if step + 1 < TUTORIAL_STEPS.size():
		var next_id := String(TUTORIAL_STEPS[step + 1])
		row.add_child(_button("SUIVANT  ›", func() -> void: _show_article(next_id), Color("315f73")))
	else:
		row.add_child(_button("✓  VOIR LES RACCOURCIS", func() -> void: _show_article("shortcuts"), Color("35664f")))

func _build_shortcuts_page() -> void:
	var top_row := HBoxContainer.new()
	top_row.add_child(_label("Cliquez sur une touche pour la remplacer. Les conflits sont bloqués.", 11, Color("aeb6c2")))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top_row.add_child(spacer)
	top_row.add_child(_button("RÉINITIALISER TOUT", _reset_all_shortcuts, Color("53383a")))
	content_host.add_child(top_row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_host.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var last_category := ""
	for definition: Dictionary in DEFINITIONS:
		var category := String(definition.get("category", "Général"))
		if category != last_category:
			var category_label := _label(category.to_upper(), 10, Color("70b7d1"))
			category_label.custom_minimum_size.y = 28
			category_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			list.add_child(category_label)
			last_category = category
		var action_id := String(definition.get("id", ""))
		var binding := shortcuts[action_id] as Dictionary
		var row_panel := PanelContainer.new()
		row_panel.add_theme_stylebox_override("panel", _style(Color("20252b"), Color("303740"), 3, 7))
		list.add_child(row_panel)
		var row := HBoxContainer.new()
		row_panel.add_child(row)
		var action_label := _label(String(definition.get("label", action_id)), 11, Color("d6dbe2"))
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(action_label)
		var primary_button := Button.new()
		primary_button = _button(_single_binding_text(binding, "primary"), func() -> void: _begin_capture(action_id, "primary", primary_button), Color("303a44"))
		primary_button.custom_minimum_size.x = 118
		primary_button.tooltip_text = "Modifier le raccourci principal"
		row.add_child(primary_button)
		if definition.has("alternate"):
			var alternate_button := Button.new()
			alternate_button = _button(_single_binding_text(binding, "alternate"), func() -> void: _begin_capture(action_id, "alternate", alternate_button), Color("292f36"))
			alternate_button.custom_minimum_size.x = 92
			alternate_button.tooltip_text = "Raccourci secondaire · Suppr pour le retirer"
			row.add_child(alternate_button)
		var reset_button := _button("↺", func() -> void: _reset_shortcut(action_id), Color("292e35"))
		reset_button.tooltip_text = "Valeur par défaut"
		row.add_child(reset_button)

func _begin_capture(action_id: String, slot: String, button: Button) -> void:
	_cancel_capture()
	capture_id = action_id
	capture_slot = slot
	capture_button = button
	button.text = "APPUYEZ…"
	button.modulate = Color("e2a85f")
	status_label.text = "Appuyez sur la nouvelle touche ou combinaison · Échap annule."
	status_label.modulate = Color("e2a85f")

func _cancel_capture() -> void:
	if capture_button != null and is_instance_valid(capture_button):
		capture_button.modulate = Color.WHITE
	capture_id = ""
	capture_slot = ""
	capture_button = null

func _has_conflict(action_id: String, candidate: Dictionary) -> bool:
	var candidate_key := int(candidate.get("primary", 0))
	for other_id: String in shortcuts:
		if other_id == action_id:
			continue
		var other := shortcuts[other_id] as Dictionary
		if bool(other.get("ctrl", false)) != bool(candidate.get("ctrl", false)) or bool(other.get("shift", false)) != bool(candidate.get("shift", false)):
			continue
		if candidate_key == int(other.get("primary", 0)) or candidate_key == int(other.get("alternate", 0)):
			return true
	return false

func _load_shortcuts() -> void:
	shortcuts.clear()
	for definition: Dictionary in DEFINITIONS:
		var binding := definition.duplicate(true)
		binding.erase("id")
		binding.erase("category")
		binding.erase("label")
		shortcuts[String(definition.get("id", ""))] = binding
	if not FileAccess.file_exists(SHORTCUTS_PATH):
		return
	var file := FileAccess.open(SHORTCUTS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return
	for action_id: String in parsed:
		if shortcuts.has(action_id) and parsed[action_id] is Dictionary:
			(shortcuts[action_id] as Dictionary).merge(parsed[action_id] as Dictionary, true)

func _save_shortcuts() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHORTCUTS_PATH.get_base_dir()))
	var file := FileAccess.open(SHORTCUTS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(shortcuts, "\t"))
	if header_shortcut_hint != null:
		header_shortcut_hint.text = binding_text("help")

func _reset_shortcut(action_id: String) -> void:
	for definition: Dictionary in DEFINITIONS:
		if String(definition.get("id", "")) == action_id:
			var binding := definition.duplicate(true)
			binding.erase("id"); binding.erase("category"); binding.erase("label")
			shortcuts[action_id] = binding
			break
	_save_shortcuts()
	shortcuts_changed.emit(get_shortcuts())
	_show_article("shortcuts")

func _reset_all_shortcuts() -> void:
	_load_defaults()
	_save_shortcuts()
	shortcuts_changed.emit(get_shortcuts())
	_show_article("shortcuts")
	status_label.text = "Tous les raccourcis ont été réinitialisés."
	status_label.modulate = Color("72c7a7")

func _load_defaults() -> void:
	shortcuts.clear()
	for definition: Dictionary in DEFINITIONS:
		var binding := definition.duplicate(true)
		binding.erase("id"); binding.erase("category"); binding.erase("label")
		shortcuts[String(definition.get("id", ""))] = binding

func _binding_text(binding: Dictionary) -> String:
	var result := _single_binding_text(binding, "primary")
	if int(binding.get("alternate", 0)) > 0:
		result += " / %s" % _single_binding_text(binding, "alternate")
	return result

func _single_binding_text(binding: Dictionary, slot: String) -> String:
	var keycode := int(binding.get(slot, 0))
	if keycode <= 0:
		return "AUCUN"
	var pieces: Array[String] = []
	if bool(binding.get("ctrl", false)): pieces.append("Ctrl")
	if bool(binding.get("shift", false)) and keycode != KEY_SHIFT: pieces.append("Maj")
	pieces.append(OS.get_keycode_string(keycode))
	return "+".join(pieces)

func _article_index(article_id: String) -> int:
	for index in range(ARTICLES.size()):
		if String((ARTICLES[index] as Dictionary).get("id", "")) == article_id:
			return index
	return 0

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable, color: Color = Color("292f36")) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 30
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _style(color, color.lightened(0.10), 3, 9))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.10), Color("5c8297"), 3, 9))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.10), Color("c8893f"), 3, 9))
	button.pressed.connect(callback)
	return button

func _style(color: Color, border: Color, radius: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = 7.0 if margin > 0.0 else 0.0
	style.content_margin_bottom = 7.0 if margin > 0.0 else 0.0
	return style

func _apply_theme(root: Control) -> void:
	var theme := Theme.new()
	theme.default_font_size = 12
	theme.set_color("font_color", "Label", Color("d7dce4"))
	theme.set_color("font_color", "Button", Color("e5e9ef"))
	theme.set_color("font_color", "LineEdit", Color("e6eaf0"))
	theme.set_color("font_placeholder_color", "LineEdit", Color("77818e"))
	theme.set_constant("separation", "HBoxContainer", 7)
	theme.set_constant("separation", "VBoxContainer", 7)
	theme.set_stylebox("normal", "LineEdit", _style(Color("15191e"), Color("3a424d"), 3, 8))
	theme.set_stylebox("focus", "LineEdit", _style(Color("15191e"), Color("70b7d1"), 3, 8))
	var separator := StyleBoxLine.new()
	separator.color = Color("343b44")
	separator.thickness = 1
	theme.set_stylebox("separator", "HSeparator", separator)
	theme.set_stylebox("separator", "VSeparator", separator)
	root.theme = theme
