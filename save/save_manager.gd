class_name SaveManager
extends RefCounted
## Lists, creates and deletes world folders under user://saves.

const SAVES_ROOT := "user://saves"


static func list_worlds(root: String = SAVES_ROOT) -> Array:
	var worlds: Array = []
	if not DirAccess.dir_exists_absolute(root):
		return worlds
	for folder in DirAccess.get_directories_at(root):
		var directory := root.path_join(folder)
		var info := {"directory": directory, "folder": folder, "name": folder, "error": "",
			"last_played": "", "game_version": "", "generator": ""}
		var opened := WorldSave.open(directory)
		if opened.save == null:
			info.error = opened.error
		else:
			var save: WorldSave = opened.save
			info.name = save.get_name()
			info.last_played = str(save.metadata.get("last_played", ""))
			info.game_version = str(save.metadata.get("game_version", ""))
			info.generator = save.get_generator()
		worlds.append(info)
	worlds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.last_played > b.last_played)
	return worlds


## A filesystem-safe, unused folder name derived from the world name.
static func make_folder_name(world_name: String, root: String = SAVES_ROOT) -> String:
	var base := ""
	for character in world_name.to_lower().strip_edges():
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			base += character
		elif character == " " or character == "-" or character == "_":
			base += "_"
	if base.is_empty():
		base = "world"
	var candidate := base
	var suffix := 2
	while DirAccess.dir_exists_absolute(root.path_join(candidate)):
		candidate = "%s_%d" % [base, suffix]
		suffix += 1
	return candidate


## Deletes a world folder. Refuses paths outside the saves root.
static func delete_world(directory: String, root: String = SAVES_ROOT) -> Error:
	if not directory.begins_with(root + "/") or directory.contains(".."):
		Log.error("SAVE", "Refusing to delete %s: not inside %s" % [directory, root])
		return ERR_UNAUTHORIZED
	return _remove_recursive(directory)


static func _remove_recursive(directory: String) -> Error:
	for folder in DirAccess.get_directories_at(directory):
		var err := _remove_recursive(directory.path_join(folder))
		if err != OK:
			return err
	for file in DirAccess.get_files_at(directory):
		var err := DirAccess.remove_absolute(directory.path_join(file))
		if err != OK:
			return err
	return DirAccess.remove_absolute(directory)
