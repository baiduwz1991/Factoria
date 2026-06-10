extends Node

signal mods_reloaded(snapshot: Dictionary)

const GAME_API_VERSION: String = "0.1"
const MODS_ROOT: String = "user://mods"
const ACTIVE_MODS_PATH: String = "user://mods/active_mods.json"
const CORE_MOD_ROOT: String = "res://assets/data/core"
const MANIFEST_FILE_NAME: String = "factoria.mod.json"
const CORE_MOD_ID: StringName = &"core"

var _registry: GameDataRegistry = GameDataRegistry.new()
var _discovered_mods: Dictionary = {}
var _manifest_errors: Dictionary = {}
var _active_mod_ids: Array[StringName] = []
var _load_order: Array[StringName] = []
var _diagnostics: Array[Dictionary] = []
var _initialized: bool = false


func _ready() -> void:
	reload_mods()


func reload_mods() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(MODS_ROOT)
	_discovered_mods.clear()
	_manifest_errors.clear()
	_diagnostics.clear()
	_active_mod_ids = _load_active_mod_ids()
	_discover_mods()
	_load_order = _resolve_load_order()
	_rebuild_registry()
	_initialized = true
	var snapshot: Dictionary = get_runtime_snapshot()
	mods_reloaded.emit(snapshot)
	return snapshot


func get_registry() -> GameDataRegistry:
	if not _initialized:
		reload_mods()
	return _registry


func get_runtime_snapshot() -> Dictionary:
	return {
		"active_mods": get_active_mod_snapshot(),
		"load_order": SerializeUtils.string_name_array_to_strings(_load_order),
		"fingerprint": get_game_data_fingerprint(),
		"diagnostics": get_mod_diagnostics()
	}


func get_game_data_fingerprint() -> String:
	return _registry.get_fingerprint()


func get_active_mod_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mod_id in _load_order:
		var manifest: Dictionary = _discovered_mods.get(mod_id, {}) as Dictionary
		if manifest == null or manifest.is_empty():
			continue
		result.append({
			"id": String(mod_id),
			"name": str(manifest.get("name", String(mod_id))),
			"version": str(manifest.get("version", "")),
			"game_api": str(manifest.get("game_api", "")),
			"source": str(manifest.get("source", ""))
		})
	return result


func get_active_mod_ids() -> Array[StringName]:
	return _load_order.duplicate()


func get_mod_diagnostics() -> Array[Dictionary]:
	var result: Array[Dictionary] = _diagnostics.duplicate(true)
	result.append_array(_registry.get_diagnostics())
	return result


func get_mod_list_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_id in _get_sorted_discovered_ids():
		var mod_id: StringName = raw_id
		var manifest: Dictionary = _discovered_mods.get(mod_id, {}) as Dictionary
		var errors: Array = _manifest_errors.get(mod_id, []) as Array
		result.append({
			"id": String(mod_id),
			"name": str(manifest.get("name", String(mod_id))),
			"version": str(manifest.get("version", "")),
			"game_api": str(manifest.get("game_api", "")),
			"source": str(manifest.get("source", "")),
			"base_dir": str(manifest.get("base_dir", "")),
			"enabled": mod_id == CORE_MOD_ID or _active_mod_ids.has(mod_id),
			"active": _load_order.has(mod_id),
			"locked": mod_id == CORE_MOD_ID,
			"errors": errors.duplicate(true)
		})
	return result


func set_mod_enabled(mod_id: StringName, enabled: bool) -> Dictionary:
	if mod_id == CORE_MOD_ID:
		return get_runtime_snapshot()
	if enabled:
		if not _active_mod_ids.has(mod_id):
			_active_mod_ids.append(mod_id)
	else:
		_active_mod_ids.erase(mod_id)
	_save_active_mod_ids()
	return reload_mods()


func move_mod(mod_id: StringName, direction: int) -> Dictionary:
	if mod_id == CORE_MOD_ID:
		return get_runtime_snapshot()
	var index: int = _active_mod_ids.find(mod_id)
	if index < 0:
		return get_runtime_snapshot()
	var next_index: int = clampi(index + direction, 0, _active_mod_ids.size() - 1)
	if next_index == index:
		return get_runtime_snapshot()
	_active_mod_ids.remove_at(index)
	_active_mod_ids.insert(next_index, mod_id)
	_save_active_mod_ids()
	return reload_mods()


func validate_saved_mod_state(
	saved_mods: Array,
	_saved_fingerprint: String = "",
	terrain_palette: Dictionary = {}
) -> Dictionary:
	var current_by_id: Dictionary = {}
	for mod_snapshot in get_active_mod_snapshot():
		if not (mod_snapshot is Dictionary):
			continue
		var snapshot: Dictionary = mod_snapshot as Dictionary
		current_by_id[str(snapshot.get("id", ""))] = snapshot

	if saved_mods.is_empty():
		if current_by_id.size() > 1:
			return _build_validation_error(&"legacy_save_requires_core_only", {
				"active_mods": current_by_id.keys()
			})
		return _validate_terrain_palette(terrain_palette)

	var saved_by_id: Dictionary = {}
	for raw_saved in saved_mods:
		if not (raw_saved is Dictionary):
			continue
		var saved: Dictionary = raw_saved as Dictionary
		var mod_id: String = str(saved.get("id", ""))
		if mod_id == "":
			continue
		saved_by_id[mod_id] = saved

	for mod_id in saved_by_id.keys():
		if not current_by_id.has(mod_id):
			return _build_validation_error(&"mod_missing", {"mod_id": mod_id})
		var saved_version: String = str((saved_by_id[mod_id] as Dictionary).get("version", ""))
		var current_version: String = str((current_by_id[mod_id] as Dictionary).get("version", ""))
		if saved_version != current_version:
			return _build_validation_error(&"mod_version_mismatch", {
				"mod_id": mod_id,
				"saved_version": saved_version,
				"current_version": current_version
			})

	for mod_id in current_by_id.keys():
		if not saved_by_id.has(mod_id):
			return _build_validation_error(&"extra_mod_active", {"mod_id": mod_id})

	return _validate_terrain_palette(terrain_palette)


func _discover_mods() -> void:
	var core_manifest: Dictionary = _load_manifest(CORE_MOD_ROOT, &"core")
	if not core_manifest.is_empty():
		core_manifest["source"] = "core"
		_discovered_mods[CORE_MOD_ID] = core_manifest

	var local_provider: LocalFolderModSourceProvider = LocalFolderModSourceProvider.new(MODS_ROOT)
	for mod_root in local_provider.discover_mod_roots():
		var manifest: Dictionary = _load_manifest(mod_root, &"local")
		if manifest.is_empty():
			continue
		var mod_id: StringName = StringName(manifest.get("id", ""))
		if _discovered_mods.has(mod_id):
			_record_manifest_error(mod_id, "duplicate_mod_id")
			continue
		_discovered_mods[mod_id] = manifest


func _load_manifest(mod_root: String, source: StringName) -> Dictionary:
	var manifest_path: String = "%s/%s" % [mod_root, MANIFEST_FILE_NAME]
	if not FileAccess.file_exists(manifest_path):
		return {}

	var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		_record_manifest_error(StringName(mod_root), "manifest_open_failed")
		return {}

	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	if parse_error != OK or not (parser.data is Dictionary):
		_record_manifest_error(StringName(mod_root), "manifest_json_invalid")
		return {}

	var manifest: Dictionary = (parser.data as Dictionary).duplicate(true)
	var mod_id: StringName = StringName(manifest.get("id", ""))
	if mod_id == StringName():
		_record_manifest_error(StringName(mod_root), "manifest_id_missing")
		return {}

	manifest["base_dir"] = mod_root
	manifest["source"] = String(source)
	if not _is_game_api_compatible(str(manifest.get("game_api", ""))):
		_record_manifest_error(mod_id, "game_api_incompatible")
		return {}

	return manifest


func _resolve_load_order() -> Array[StringName]:
	var candidates: Array[StringName] = [CORE_MOD_ID]
	for mod_id in _active_mod_ids:
		if mod_id == CORE_MOD_ID:
			continue
		if not _discovered_mods.has(mod_id):
			_record_manifest_error(mod_id, "active_mod_missing")
			continue
		candidates.append(mod_id)

	var candidate_set: Dictionary = {}
	for mod_id in candidates:
		candidate_set[mod_id] = true

	var changed: bool = true
	while changed:
		changed = false
		for mod_id in candidates.duplicate():
			if mod_id == CORE_MOD_ID:
				continue
			var missing_dependency: StringName = _find_missing_dependency(mod_id, candidate_set)
			if missing_dependency != StringName():
				_record_manifest_error(mod_id, "dependency_missing:%s" % String(missing_dependency))
				candidates.erase(mod_id)
				candidate_set.erase(mod_id)
				changed = true

	var result: Array[StringName] = []
	var temporary: Dictionary = {}
	var permanent: Dictionary = {}
	for mod_id in candidates:
		if not _visit_mod_for_load_order(mod_id, candidate_set, temporary, permanent, result):
			_record_manifest_error(mod_id, "dependency_cycle")
			return [CORE_MOD_ID]
	return result


func _visit_mod_for_load_order(
	mod_id: StringName,
	candidate_set: Dictionary,
	temporary: Dictionary,
	permanent: Dictionary,
	result: Array[StringName]
) -> bool:
	if permanent.has(mod_id):
		return true
	if temporary.has(mod_id):
		return false

	temporary[mod_id] = true
	var manifest: Dictionary = _discovered_mods.get(mod_id, {}) as Dictionary
	for dependency_id in _get_dependency_ids(manifest):
		if not candidate_set.has(dependency_id):
			continue
		if not _visit_mod_for_load_order(dependency_id, candidate_set, temporary, permanent, result):
			return false
	temporary.erase(mod_id)
	permanent[mod_id] = true
	if not result.has(mod_id):
		result.append(mod_id)
	return true


func _rebuild_registry() -> void:
	_registry.clear()
	for mod_id in _load_order:
		var manifest: Dictionary = _discovered_mods.get(mod_id, {}) as Dictionary
		if manifest == null or manifest.is_empty():
			continue
		_registry.load_mod_content(manifest)
	_registry.finalize_registry(get_active_mod_snapshot())


func _find_missing_dependency(mod_id: StringName, candidate_set: Dictionary) -> StringName:
	var manifest: Dictionary = _discovered_mods.get(mod_id, {}) as Dictionary
	for dependency_id in _get_dependency_ids(manifest):
		if dependency_id == StringName():
			continue
		if not candidate_set.has(dependency_id):
			return dependency_id
		if not _is_dependency_version_compatible(manifest, dependency_id):
			return dependency_id
	return StringName()


func _get_dependency_ids(manifest: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var dependencies: Array = []
	if manifest != null and manifest.get("dependencies", []) is Array:
		dependencies = manifest.get("dependencies", []) as Array
	for raw_dependency in dependencies:
		var dependency_id: StringName = StringName()
		if raw_dependency is Dictionary:
			dependency_id = StringName((raw_dependency as Dictionary).get("id", ""))
		else:
			dependency_id = StringName(raw_dependency)
		if dependency_id != StringName() and not result.has(dependency_id):
			result.append(dependency_id)
	return result


func _is_dependency_version_compatible(manifest: Dictionary, dependency_id: StringName) -> bool:
	var dependencies: Array = manifest.get("dependencies", []) as Array
	for raw_dependency in dependencies:
		if not (raw_dependency is Dictionary):
			continue
		var dependency: Dictionary = raw_dependency as Dictionary
		if StringName(dependency.get("id", "")) != dependency_id:
			continue
		var version_range: String = str(dependency.get("version", ""))
		if version_range == "":
			return true
		var dependency_manifest: Dictionary = _discovered_mods.get(dependency_id, {}) as Dictionary
		return _matches_version_range(str(dependency_manifest.get("version", "")), version_range)
	return true


func _matches_version_range(version: String, version_range: String) -> bool:
	if version_range.begins_with(">="):
		return _compare_semver(version, version_range.substr(2).strip_edges()) >= 0
	return version == version_range


func _compare_semver(left: String, right: String) -> int:
	var left_parts: PackedStringArray = left.split(".")
	var right_parts: PackedStringArray = right.split(".")
	for index in range(3):
		var left_value: int = int(left_parts[index]) if index < left_parts.size() else 0
		var right_value: int = int(right_parts[index]) if index < right_parts.size() else 0
		if left_value < right_value:
			return -1
		if left_value > right_value:
			return 1
	return 0


func _is_game_api_compatible(game_api: String) -> bool:
	return game_api == "" or game_api == GAME_API_VERSION


func _load_active_mod_ids() -> Array[StringName]:
	if not FileAccess.file_exists(ACTIVE_MODS_PATH):
		return []
	var file: FileAccess = FileAccess.open(ACTIVE_MODS_PATH, FileAccess.READ)
	if file == null:
		return []
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return []
	var raw_ids: Array = []
	if parser.data is Array:
		raw_ids = parser.data as Array
	elif parser.data is Dictionary:
		raw_ids = (parser.data as Dictionary).get("enabled", []) as Array
	var result: Array[StringName] = []
	for raw_id in raw_ids:
		var mod_id: StringName = StringName(raw_id)
		if mod_id == StringName() or mod_id == CORE_MOD_ID or result.has(mod_id):
			continue
		result.append(mod_id)
	return result


func _save_active_mod_ids() -> void:
	DirAccess.make_dir_recursive_absolute(MODS_ROOT)
	var file: FileAccess = FileAccess.open(ACTIVE_MODS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"enabled": SerializeUtils.string_name_array_to_strings(_active_mod_ids)
	}, "\t"))
	file.flush()


func _validate_terrain_palette(terrain_palette: Dictionary) -> Dictionary:
	if terrain_palette.is_empty():
		return {"ok": true}
	var registry: GameDataRegistry = get_registry()
	for runtime_id in terrain_palette.keys():
		var terrain_id: StringName = StringName(terrain_palette.get(runtime_id, ""))
		if not registry.has_terrain(terrain_id):
			return _build_validation_error(&"terrain_palette_missing", {
				"runtime_id": str(runtime_id),
				"terrain_id": String(terrain_id)
			})
	return {"ok": true}


func _build_validation_error(error_code: StringName, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"error_code": error_code
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result


func _record_manifest_error(mod_id: StringName, code: String) -> void:
	if not _manifest_errors.has(mod_id):
		_manifest_errors[mod_id] = []
	var errors: Array = _manifest_errors.get(mod_id, []) as Array
	errors.append(code)
	_manifest_errors[mod_id] = errors
	_diagnostics.append({
		"level": "error",
		"mod_id": String(mod_id),
		"code": code
	})


func _get_sorted_discovered_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if _discovered_mods.has(CORE_MOD_ID):
		result.append(CORE_MOD_ID)
	for mod_id in _active_mod_ids:
		if mod_id != CORE_MOD_ID and _discovered_mods.has(mod_id) and not result.has(mod_id):
			result.append(mod_id)
	for raw_id in _discovered_mods.keys():
		var mod_id: StringName = raw_id
		if not result.has(mod_id):
			result.append(mod_id)
	return result
