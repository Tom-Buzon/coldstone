extends RefCounted

const TEXTURES := {
	&"aura": preload("res://assets/HUD/auraMeurtiere.jpeg"),
	&"flame": preload("res://assets/HUD/pourfendeur.jpeg"),
	&"thunder": preload("res://assets/HUD/coupDeTonerre.jpeg"),
	&"ares": preload("res://assets/HUD/Ares.jpeg"),
}

static func texture_for(id: StringName) -> Texture2D:
	return TEXTURES.get(id)
