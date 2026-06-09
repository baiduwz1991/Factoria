class_name SaveRepository
extends RefCounted

#region 配置与常量
const SLOT_MIN: int = 1
const SLOT_MAX: int = 9

const ROOT_DIR: String = "user://saves"
const PROFILE_DIR: String = "user://saves/profile"

const MAIN_FILE_NAME_JSON: String = "main.json"
const BACKUP_FILE_NAME_JSON: String = "backup.json"
const BACKUP_FILE_NAME_JSON_2: String = "backup_2.json"
const BACKUP_FILE_NAME_JSON_3: String = "backup_3.json"
const META_FILE_NAME: String = "meta.dat"
const TMP_FILE_SUFFIX: String = ".tmp"
#endregion

#region 对外接口 - 目录
func ensure_layout() -> void:
	_ensure_dir(ROOT_DIR)
	_ensure_dir(PROFILE_DIR)
	for slot_id in range(SLOT_MIN, SLOT_MAX + 1):
		_ensure_dir(_get_slot_dir(slot_id))


func get_slot_paths(slot_id: int) -> Dictionary:
	var slot_dir: String = _get_slot_dir(slot_id)
	return {
		"slot_dir": slot_dir,
		"main": "%s/%s" % [slot_dir, MAIN_FILE_NAME_JSON],
		"backup": "%s/%s" % [slot_dir, BACKUP_FILE_NAME_JSON],
		"backup_2": "%s/%s" % [slot_dir, BACKUP_FILE_NAME_JSON_2],
		"backup_3": "%s/%s" % [slot_dir, BACKUP_FILE_NAME_JSON_3],
		"meta": "%s/%s" % [slot_dir, META_FILE_NAME]
	}


func get_slot_asset_path(slot_id: int, file_name: String) -> String:
	var normalized_file_name: String = file_name.get_file()
	if normalized_file_name == "":
		return ""
	return "%s/%s" % [_get_slot_dir(slot_id), normalized_file_name]


func get_slot_asset_relative_path(slot_id: int, relative_path: String) -> String:
	var normalized_path: String = _normalize_relative_asset_path(relative_path)
	if normalized_path == "":
		return ""
	return "%s/%s" % [_get_slot_dir(slot_id), normalized_path]
#endregion

#region 对外接口 - 写入
func write_slot_snapshot_json(slot_id: int, json_text: String, meta: Dictionary) -> Dictionary:
	var paths: Dictionary = get_slot_paths(slot_id)
	return _write_snapshot_files(paths, json_text, meta)


func write_slot_asset_text(slot_id: int, file_name: String, content: String) -> Dictionary:
	_ensure_dir(_get_slot_dir(slot_id))
	var asset_path: String = get_slot_asset_relative_path(slot_id, file_name)
	if asset_path == "":
		return {
			"ok": false,
			"error_code": &"asset_file_name_invalid",
			"slot_id": slot_id,
			"file_name": file_name
		}
	_ensure_dir(asset_path.get_base_dir())
	return _write_text_file(asset_path, content)


func write_profile_snapshot_json(json_text: String) -> Dictionary:
	var paths: Dictionary = {
		"slot_dir": PROFILE_DIR,
		"main": "%s/%s" % [PROFILE_DIR, MAIN_FILE_NAME_JSON],
		"backup": "%s/%s" % [PROFILE_DIR, BACKUP_FILE_NAME_JSON],
		"backup_2": "",
		"backup_3": "",
		"meta": ""
	}
	return _write_snapshot_files(paths, json_text, {})
#endregion

#region 对外接口 - 读取
func read_slot_snapshot_json(slot_id: int) -> Dictionary:
	var paths: Dictionary = get_slot_paths(slot_id)
	var main_result: Dictionary = _read_text_file(str(paths.get("main", "")))
	if bool(main_result.get("ok", false)):
		main_result["source"] = &"main"
		main_result["used_backup"] = false
		return main_result

	var backup_result: Dictionary = _read_text_file(str(paths.get("backup", "")))
	if bool(backup_result.get("ok", false)):
		backup_result["source"] = &"backup"
		backup_result["used_backup"] = true
		return backup_result

	return {
		"ok": false,
		"error_code": &"slot_snapshot_missing",
		"error_message": "主档与备份均不可用。",
		"main_error": main_result,
		"backup_error": backup_result
	}


func read_slot_snapshot_json_by_source(slot_id: int, source: StringName) -> Dictionary:
	var paths: Dictionary = get_slot_paths(slot_id)
	var target_path: String = ""
	if source == &"main":
		target_path = str(paths.get("main", ""))
	elif source == &"backup":
		target_path = str(paths.get("backup", ""))
	elif source == &"backup_2":
		target_path = str(paths.get("backup_2", ""))
	elif source == &"backup_3":
		target_path = str(paths.get("backup_3", ""))
	else:
		return {
			"ok": false,
			"error_code": &"invalid_backup_source",
			"source": source
		}

	var result: Dictionary = _read_text_file(target_path)
	if not bool(result.get("ok", false)):
		return result
	result["source"] = source
	result["used_backup"] = source != &"main"
	return result


func read_profile_snapshot_json() -> Dictionary:
	var main_result: Dictionary = _read_text_file("%s/%s" % [PROFILE_DIR, MAIN_FILE_NAME_JSON])
	if bool(main_result.get("ok", false)):
		main_result["source"] = &"main"
		main_result["used_backup"] = false
		return main_result

	var backup_result: Dictionary = _read_text_file("%s/%s" % [PROFILE_DIR, BACKUP_FILE_NAME_JSON])
	if bool(backup_result.get("ok", false)):
		backup_result["source"] = &"backup"
		backup_result["used_backup"] = true
		return backup_result

	return {
		"ok": false,
		"error_code": &"profile_snapshot_missing",
		"error_message": "profile 主档与备份均不可用。"
	}


func read_slot_asset_text(slot_id: int, relative_path: String) -> Dictionary:
	var asset_path: String = get_slot_asset_relative_path(slot_id, relative_path)
	return _read_text_file(asset_path)


func list_slot_meta() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_id in range(SLOT_MIN, SLOT_MAX + 1):
		result.append(_read_slot_meta(slot_id))
	return result


func list_slot_backups(slot_id: int) -> Array[Dictionary]:
	var paths: Dictionary = get_slot_paths(slot_id)
	var entries: Array[Dictionary] = []

	var backup_path: String = str(paths.get("backup", ""))
	if FileAccess.file_exists(backup_path):
		entries.append(_build_backup_entry(1, backup_path))

	var backup_path_2: String = str(paths.get("backup_2", ""))
	if FileAccess.file_exists(backup_path_2):
		entries.append(_build_backup_entry(2, backup_path_2))

	var backup_path_3: String = str(paths.get("backup_3", ""))
	if FileAccess.file_exists(backup_path_3):
		entries.append(_build_backup_entry(3, backup_path_3))

	return entries


func delete_slot_snapshot(slot_id: int) -> Dictionary:
	var paths: Dictionary = get_slot_paths(slot_id)
	DirAccess.remove_absolute(str(paths.get("main", "")))
	DirAccess.remove_absolute(str(paths.get("backup", "")))
	DirAccess.remove_absolute(str(paths.get("backup_2", "")))
	DirAccess.remove_absolute(str(paths.get("backup_3", "")))
	DirAccess.remove_absolute(str(paths.get("meta", "")))
	DirAccess.remove_absolute("%s%s" % [str(paths.get("main", "")), TMP_FILE_SUFFIX])
	_remove_dir_recursive(get_slot_asset_relative_path(slot_id, "planet"))
	return {
		"ok": true,
		"slot_id": slot_id
	}
#endregion

#region 对外接口 - 槽位资源管理
func delete_slot_asset_dir(slot_id: int, relative_dir: String) -> Dictionary:
	var dir_path: String = get_slot_asset_relative_path(slot_id, relative_dir)
	if dir_path == "":
		return {
			"ok": false,
			"error_code": &"asset_dir_invalid",
			"slot_id": slot_id,
			"relative_dir": relative_dir
		}
	_remove_dir_recursive(dir_path)
	return {
		"ok": true,
		"slot_id": slot_id,
		"relative_dir": relative_dir
	}
#endregion

#region 内部实现 - 写入
func _write_snapshot_files(paths: Dictionary, json_text: String, meta: Dictionary) -> Dictionary:
	var main_path: String = str(paths.get("main", ""))
	var backup_path: String = str(paths.get("backup", ""))
	var meta_path: String = str(paths.get("meta", ""))
	var tmp_path: String = "%s%s" % [main_path, TMP_FILE_SUFFIX]

	var write_tmp_result: Dictionary = _write_text_file(tmp_path, json_text)
	if not bool(write_tmp_result.get("ok", false)):
		return write_tmp_result

	if FileAccess.file_exists(backup_path):
		var backup_2_path: String = str(paths.get("backup_2", ""))
		var backup_3_path: String = str(paths.get("backup_3", ""))
		if backup_2_path != "":
			if backup_3_path != "":
				DirAccess.remove_absolute(backup_3_path)
			if backup_3_path != "" and FileAccess.file_exists(backup_2_path):
				DirAccess.rename_absolute(backup_2_path, backup_3_path)
			DirAccess.rename_absolute(backup_path, backup_2_path)
		else:
			DirAccess.remove_absolute(backup_path)

	if FileAccess.file_exists(main_path):
		var rename_backup_err: Error = DirAccess.rename_absolute(main_path, backup_path)
		if rename_backup_err != OK:
			DirAccess.remove_absolute(tmp_path)
			return {
				"ok": false,
				"error_code": &"rename_main_to_backup_failed",
				"error_message": "无法将 main 重命名为 backup。",
				"godot_error": rename_backup_err
			}

	var rename_main_err: Error = DirAccess.rename_absolute(tmp_path, main_path)
	if rename_main_err != OK:
		DirAccess.remove_absolute(tmp_path)
		return {
			"ok": false,
			"error_code": &"rename_tmp_to_main_failed",
			"error_message": "无法将 tmp 提升为 main。",
			"godot_error": rename_main_err
		}

	if meta_path != "":
		_write_text_file(meta_path, JSON.stringify(meta))

	return {
		"ok": true,
		"main_path": main_path,
		"backup_path": backup_path
	}
#endregion

#region 内部实现 - 读取
func _read_slot_meta(slot_id: int) -> Dictionary:
	var paths: Dictionary = get_slot_paths(slot_id)
	var meta_path: String = str(paths.get("meta", ""))
	var meta_result: Dictionary = _read_text_file(meta_path)
	if not bool(meta_result.get("ok", false)):
		return {
			"slot_id": slot_id,
			"exists": false,
			"title": "",
			"updated_at_unix": 0
		}

	var parser: JSON = JSON.new()
	var parse_err: Error = parser.parse(str(meta_result.get("text", "")))
	if parse_err != OK or not (parser.data is Dictionary):
		return {
			"slot_id": slot_id,
			"exists": false,
			"title": "",
			"updated_at_unix": 0
		}

	var parsed: Dictionary = parser.data as Dictionary
	parsed["slot_id"] = slot_id
	parsed["exists"] = true
	return parsed


func _build_backup_entry(backup_index: int, path: String) -> Dictionary:
	return {
		"backup_index": backup_index,
		"path": path,
		"updated_at_unix": int(FileAccess.get_modified_time(path)),
		"label": "备份%d" % backup_index
	}


func _read_text_file(path: String) -> Dictionary:
	if path == "":
		return {
			"ok": false,
			"error_code": &"path_empty"
		}
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"error_code": &"file_not_found",
			"path": path
		}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"error_code": &"open_for_read_failed",
			"path": path
		}

	return {
		"ok": true,
		"text": file.get_as_text(),
		"path": path
	}


func _write_text_file(path: String, content: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"error_code": &"open_for_write_failed",
			"path": path
		}
	file.store_string(content)
	file.flush()
	return {
		"ok": true,
		"path": path
	}
#endregion

#region 内部实现 - 路径
func _get_slot_dir(slot_id: int) -> String:
	var clamped_slot: int = clampi(slot_id, SLOT_MIN, SLOT_MAX)
	return "%s/slot_%02d" % [ROOT_DIR, clamped_slot]


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)


func _normalize_relative_asset_path(relative_path: String) -> String:
	var normalized: String = relative_path.replace("\\", "/").simplify_path()
	if normalized == "." or normalized == "":
		return ""
	if normalized.begins_with("/") or normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ""
	if normalized.contains("../") or normalized == "..":
		return ""
	return normalized


func _remove_dir_recursive(path: String) -> void:
	if path == "" or not DirAccess.dir_exists_absolute(path):
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if entry_name != "." and entry_name != "..":
			var entry_path := "%s/%s" % [path, entry_name]
			if dir.current_is_dir():
				_remove_dir_recursive(entry_path)
			else:
				DirAccess.remove_absolute(entry_path)
		entry_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
#endregion
