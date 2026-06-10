class_name LocalFolderModSourceProvider
extends ModSourceProvider

const MANIFEST_FILE_NAME: String = "factoria.mod.json"

var _root_dir: String = "user://mods"


func _init(root_dir: String = "user://mods") -> void:
	_root_dir = root_dir


func discover_mod_roots() -> Array[String]:
	DirAccess.make_dir_recursive_absolute(_root_dir)
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(_root_dir)
	if dir == null:
		return result

	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if entry_name != "." and entry_name != ".." and dir.current_is_dir():
			var mod_root: String = "%s/%s" % [_root_dir, entry_name]
			if FileAccess.file_exists("%s/%s" % [mod_root, MANIFEST_FILE_NAME]):
				result.append(mod_root)
		entry_name = dir.get_next()
	dir.list_dir_end()
	return result
