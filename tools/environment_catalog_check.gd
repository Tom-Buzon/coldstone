extends SceneTree

const CatalogScript = preload("res://scripts/environment/environment_asset_catalog.gd")
const RAW_ROOT := "res://_source/environment_props_raw"

func _initialize() -> void:
	var registered_folders := Array(CatalogScript.registered_folders())
	var registered_textures := Array(CatalogScript.registered_texture_files())
	var found_folders: Array[String] = []
	var unregistered_folders: Array[String] = []
	var root_dir := DirAccess.open(RAW_ROOT)
	if root_dir == null:
		push_error("[ENVIRONMENT CATALOG] Raw asset root is missing: %s" % RAW_ROOT)
		quit(1)
		return
	root_dir.list_dir_begin()
	var entry := root_dir.get_next()
	while not entry.is_empty():
		if root_dir.current_is_dir() and not entry.begins_with(".") and entry != "texture":
			found_folders.append(entry)
			if not registered_folders.has(entry):
				unregistered_folders.append(entry)
		entry = root_dir.get_next()
	root_dir.list_dir_end()

	var found_textures: Array[String] = []
	var unregistered_textures: Array[String] = []
	var texture_dir := DirAccess.open(RAW_ROOT + "/texture")
	if texture_dir != null:
		texture_dir.list_dir_begin()
		entry = texture_dir.get_next()
		while not entry.is_empty():
			if not texture_dir.current_is_dir() and entry.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
				found_textures.append(entry)
				if not registered_textures.has(entry):
					unregistered_textures.append(entry)
			entry = texture_dir.get_next()
		texture_dir.list_dir_end()

	var missing_folders: Array[String] = []
	for folder: String in registered_folders:
		if not found_folders.has(folder):
			missing_folders.append(folder)
	var missing_textures: Array[String] = []
	for filename: String in registered_textures:
		if not found_textures.has(filename):
			missing_textures.append(filename)

	print("[ENVIRONMENT CATALOG] %d/%d asset folders registered; %d/%d textures registered." % [found_folders.size() - unregistered_folders.size(), found_folders.size(), found_textures.size() - unregistered_textures.size(), found_textures.size()])
	if not unregistered_folders.is_empty():
		print("[ENVIRONMENT CATALOG] NEW ASSET FOLDERS: %s" % ", ".join(unregistered_folders))
	if not unregistered_textures.is_empty():
		print("[ENVIRONMENT CATALOG] NEW TEXTURES: %s" % ", ".join(unregistered_textures))
	if not missing_folders.is_empty() or not missing_textures.is_empty():
		print("[ENVIRONMENT CATALOG] MISSING FROM DISK: %s %s" % [missing_folders, missing_textures])
	var has_drift := not unregistered_folders.is_empty() or not unregistered_textures.is_empty() or not missing_folders.is_empty() or not missing_textures.is_empty()
	quit(2 if has_drift else 0)
