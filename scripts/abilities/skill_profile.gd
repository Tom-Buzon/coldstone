extends Resource

## Saved choices are separate from runtime timers and from shared definitions.
const SAVE_PATH := "user://hoplite_skills_v1.cfg"
const BRANCHES := ["Mouvement", "Attaques de base", "Attaques spéciales", "Ultimes"]
const ULTIMATES: Array[StringName] = [&"aura", &"flame", &"thunder", &"ares"]
const PARENTS := {&"air_jumps": &"jump", &"shield_wall": &"wall", &"giant_wall": &"shield_wall", &"shield_reset": &"shield_wall", &"shield_aim": &"shield_wall", &"giant_reset": &"giant_wall", &"giant_aim": &"giant_wall", &"perfect_charge": &"perfect", &"aura": &"dash", &"plunge": &"jump"}
@export var enabled: Dictionary = {}
@export var tuning: Dictionary = {}
@export var selected_ultimate: StringName = &"aura"
var save_path := SAVE_PATH

static func features() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		_f(&"jump", "Saut", 0, "Hauteurs indépendantes pour les trois premiers sauts."),
		_f(&"air_jumps", "Sauts aériens", 0, "Enchaîner des sauts en l'air.", &"jump"),
		_f(&"dash", "Dash", 0, "Accélération brève avec direction contrôlable."),
		_f(&"slide", "Glissade", 0, "Conserver son élan au ras du sol."),
		_f(&"parkour", "Franchissement", 0, "Passer au-dessus des obstacles."),
		_f(&"wall", "Course murale", 0, "Courir sur le décor."),
		_f(&"shield_wall", "Course sur boucliers", 0, "Utiliser les lignes de boucliers comme appui.", &"wall"),
		_f(&"giant_wall", "Course sur géants", 0, "Gravir les colosses.", &"shield_wall"),
		_f(&"shield_reset", "Rebond de phalange", 0, "Le saut de sortie recharge la chaîne murale.", &"shield_wall", false),
		_f(&"shield_aim", "Visée de phalange", 0, "Assistance renforcée pendant le saut de sortie.", &"shield_wall", false),
		_f(&"giant_reset", "Rebond du titan", 0, "Le saut de sortie recharge la chaîne murale.", &"giant_wall", false),
		_f(&"giant_aim", "Visée du titan", 0, "Assistance renforcée pendant le saut de sortie.", &"giant_wall", false),
		_f(&"regen", "Récupération vitale", 0, "Régénération après un délai sans dégâts."),
		_f(&"block", "Garde au bouclier", 1, "Bloquer les attaques frontales."),
		_f(&"aim_assist", "Assistance à la visée", 1, "Correction réglable séparément pour chaque contexte."),
		_f(&"perfect", "Réponses parfaites", 0, "Esquives et parades précises ouvrent une riposte."),
		_f(&"sever_charge", "Tribut du démembrement", 0, "Les démembrements remplissent la jauge d'ultime.", &"", false),
		_f(&"perfect_charge", "Tribut de la perfection", 0, "Les réponses parfaites remplissent la jauge d'ultime.", &"perfect", false),
		_f(&"ranged", "Javelot / seconde arme", 1, "Changer d'arme, viser et lancer un projectile.", &"", false),
		_f(&"spin_up", "Spirale haute", 2, "Coupe ascendante et projection aérienne."),
		_f(&"spin_down", "Spirale basse", 2, "Coupe descendante et impact au sol."),
		_f(&"edge", "Lame horizontale", 2, "Maintenir pendant un dash ou une spirale : contacts rapides. Bonus à l'activation bien synchronisée.", &"", false),
		_f(&"plunge", "Frappe tellurique", 2, "Planter la lame au sol. La hauteur de chute amplifie dégâts et répulsion.", &"jump", false),
		_f(&"aura", "Aura meurtrière", 3, "Dash et frappes parfaites automatiques vers les ennemis à portée. La direction reste guidée par vos entrées.", &"dash", false),
		_f(&"flame", "Fire Wall", 3, "Charger 2 s, puis tracer 15 m de flammes pendant 15 s. Brûlures persistantes et peur.", &"", false),
		_f(&"thunder", "Coup de tonnerre", 3, "Charger puis lancer un javelot. Explosion électrique, démembrement précis et caméra au ralenti.", &"", false),
		_f(&"ares", "Wrath of Ares", 3, "10 s de force brute : charge lourde accélérée, boucliers détruits et ondes à chaque mort. Attaques manuelles.", &"", false),
	]
	for context: String in ["idle", "run", "air", "dash", "slide", "wall"]:
		var label: String = {"idle": "Au sol", "run": "En course", "air": "En saut", "dash": "Après dash", "slide": "En glissade", "wall": "En course murale"}[context]
		for weight: String in ["light", "heavy"]:
			result.append(_f(StringName(weight + "_" + context), label + (" · légère" if weight == "light" else " · lourde"), 1, "Variante contextuelle indépendante."))
	return result

static func _f(id: StringName, label: String, branch: int, description: String, parent: StringName = &"", base: bool = true) -> Dictionary:
	return {"id": id, "label": label, "branch": branch, "description": description, "parent": parent, "default": base}

static func controls() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var specs := [
		["jump_1", "Hauteur saut 1", 1.61, 0.2, 12.0, 0.05, "m"],
		["jump_2", "Hauteur saut 2", 1.37, 0.2, 12.0, 0.05, "m"],
		["jump_3", "Hauteur saut 3+", 1.37, 0.2, 12.0, 0.05, "m"],
		["max_jumps", "Nombre total de sauts", 2, 1, 8, 1, ""],
		["max_speed", "Vitesse de course", 8.5, 2, 25, 0.25, "m/s"],
		["acceleration", "Accélération", 24, 4, 90, 1, "m/s²"],
		["dash_distance", "Distance du dash", 4.185, 1, 20, 0.1, "m"],
		["dash_duration", "Durée du dash", 0.27, 0.1, 0.8, 0.01, "s"],
		["dash_turn", "Réactivité direction du dash", 16, 0, 45, 1, ""],
		["dash_max_charges", "Charges de dash", 1, 1, 8, 1, ""],
		["dash_recharge_duration", "Recharge du dash", 3, 0.1, 12, 0.1, "s"],
		["slide_distance", "Distance de glissade", 2.511, 1, 20, 0.1, "m"],
		["slide_speed", "Vitesse de glissade", 13.3, 3, 35, 0.25, "m/s"],
		["slide_turn_response", "Réactivité de glissade", 8, 1, 40, 1, ""],
		["slide_max_charges", "Charges de glissade", 2, 1, 8, 1, ""],
		["slide_recharge_duration", "Recharge de glissade", 1.5, 0.1, 12, 0.1, "s"],
		["wall_run_max_distance", "Distance course murale", 10, 1, 80, 0.5, "m"],
		["wall_run_max_chain_runs", "Courses murales consécutives", 2, 1, 12, 1, ""],
		["wall_run_vertical_max_rise", "Ascension murale maximum", 2.65, 1, 25, 0.1, "m"],
		["wall_run_vertical_max_time", "Durée ascension murale", 0.72, 0.2, 6, 0.05, "s"],
		["wall_jump_up_speed", "Impulsion du saut mural", 8.6, 2, 25, 0.2, "m/s"],
		["max_health", "Vie maximum", 300, 25, 3000, 25, "PV"],
		["health_regen_rate", "Régénération", 9, 0, 100, 1, "PV/s"],
		["health_regen_delay", "Délai de régénération", 5, 0, 20, 0.25, "s"],
		["perfect_regen_rate", "Régénération parfaite", 24, 0, 150, 1, "PV/s"],
		["aim_idle", "Aim assist · au sol", 1, 0, 2, 0.05, "×"],
		["aim_run", "Aim assist · course", 1, 0, 2, 0.05, "×"],
		["aim_air", "Aim assist · saut", 1, 0, 2, 0.05, "×"],
		["aim_dash", "Aim assist · dash", 1, 0, 2, 0.05, "×"],
		["aim_slide", "Aim assist · glissade", 1, 0, 2, 0.05, "×"],
		["aim_wall", "Aim assist · mur", 1, 0, 2, 0.05, "×"],
		["wall_aim_bonus", "Aim assist après rebond spécial", 1.8, 1, 4, 0.1, "×"],
		["damage", "Dégâts de mêlée", 1, 0.1, 5, 0.1, "×"],
		["ranged_damage", "Dégâts du javelot", 45, 5, 300, 5, "PV"],
		["ranged_cooldown", "Cadence du javelot", 0.55, 0.15, 3, 0.05, "s"],
		["edge_damage", "Dégâts lame horizontale / contact", 12, 1, 80, 1, "PV"],
		["edge_interval", "Intervalle lame horizontale", 0.12, 0.06, 0.5, 0.01, "s"],
		["edge_timing", "Fenêtre timing parfait de lame", 0.15, 0.05, 0.4, 0.01, "s"],
		["plunge_base", "Dégâts de base frappe tellurique", 45, 5, 300, 5, "PV"],
		["plunge_height", "Dégâts par mètre de chute", 14, 0, 80, 1, "PV/m"],
		["plunge_cap", "Hauteur de chute prise en compte", 20, 2, 100, 1, "m"],
		["plunge_radius", "Rayon de frappe tellurique", 5, 1, 12, 0.25, "m"],
		["plunge_push", "Répulsion frappe tellurique", 8, 0, 25, 0.5, ""],
		["sever_reward", "Jauge gagnée / démembrement", 12, 0, 100, 1, "%"],
		["perfect_reward", "Jauge gagnée / réponse parfaite", 20, 0, 100, 1, "%"],
		["aura_speed", "Vitesse des ruées Aura", 34, 15, 60, 1, "m/s"],
		["aura_duration", "Durée Aura meurtrière", 8, 1, 30, 0.5, "s"],
		["aura_interval", "Intervalle des frappes Aura", 0.35, 0.15, 1, 0.05, "s"],
		["aura_damage", "Dégâts frappe Aura", 85, 10, 400, 5, "PV"],
		["flame_cast", "Charge de Fire Wall", 2, 0.2, 5, 0.1, "s"],
		["flame_length", "Longueur mur de flammes", 15, 3, 40, 1, "m"],
		["flame_duration", "Durée mur de flammes", 15, 2, 40, 1, "s"],
		["flame_dps", "Dégâts des flammes", 36, 5, 200, 1, "PV/s"],
		["burn_duration", "Brûlure résiduelle", 3, 0, 10, 0.25, "s"],
		["thunder_charge_time", "Temps de charge maximum du Tonnerre", 2.0, 0.3, 5.0, 0.1, "s"],
		["thunder_damage", "Dégâts Coup de tonnerre", 1300, 50, 6000, 25, "PV"],
		["thunder_radius", "Rayon explosion électrique", 7, 2, 16, 0.5, "m"],
		["thunder_blast", "Dégâts explosion / impact direct", 0.65, 0.1, 2, 0.05, "x"],
		["ares_duration", "Durée Wrath of Ares", 10, 1, 30, 0.5, "s"],
		["ares_charge", "Multiplicateur charge Ares", 12, 2, 30, 1, "×"],
		["ares_push", "Multiplicateur répulsion Ares", 3, 1, 8, 0.25, "×"],
		["ares_wave", "Dégâts onde de mort Ares", 45, 0, 250, 5, "PV"],
	]
	for spec: Array in specs:
		rows.append({"id": StringName(spec[0]), "label": spec[1], "default": float(spec[2]), "min": float(spec[3]), "max": float(spec[4]), "step": float(spec[5]), "unit": spec[6]})
	return rows

func _init() -> void:
	reset()

func reset(all_enabled: bool = false) -> void:
	for feature: Dictionary in features():
		enabled[feature.id] = all_enabled or feature.default
	for control: Dictionary in controls():
		tuning[control.id] = control.default
	selected_ultimate = &"aura"
	emit_changed()

func active(id: StringName) -> bool:
	if not bool(enabled.get(id, false)):
		return false
	return active(PARENTS[id]) if PARENTS.has(id) else true

func value(id: StringName) -> float:
	return float(tuning.get(id, 0.0))

func set_feature(id: StringName, value_enabled: bool) -> void:
	if enabled.has(id):
		enabled[id] = value_enabled
		emit_changed()

func set_tuning(id: StringName, amount: float) -> void:
	if not is_finite(amount): return
	for control: Dictionary in controls():
		if control.id == id:
			tuning[id] = snappedf(clampf(amount, control.min, control.max), control.step)
			emit_changed()
			return

func load_settings() -> Error:
	var config := ConfigFile.new()
	var result := config.load(save_path)
	if result != OK: return result
	for feature: Dictionary in features():
		enabled[feature.id] = bool(config.get_value("features", feature.id, feature.default))
	for control: Dictionary in controls():
		var amount := float(config.get_value("tuning", control.id, control.default))
		tuning[control.id] = clampf(amount, control.min, control.max) if is_finite(amount) else control.default
	if int(config.get_value("meta", "version", 1)) < 2 and is_equal_approx(value(&"thunder_damage"), 650.0):
		tuning[&"thunder_damage"] = 1300.0
	var selected := StringName(config.get_value("meta", "ultimate", "aura"))
	selected_ultimate = selected if selected in ULTIMATES else &"aura"
	emit_changed()
	return OK

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("meta", "version", 2)
	config.set_value("meta", "ultimate", String(selected_ultimate))
	for id: StringName in enabled: config.set_value("features", id, enabled[id])
	for id: StringName in tuning: config.set_value("tuning", id, tuning[id])
	return config.save(save_path)
