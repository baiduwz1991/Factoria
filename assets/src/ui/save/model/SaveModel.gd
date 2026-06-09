class_name SaveModel
extends BaseModel

#region 状态
var _current_slot_id: int = 1
var _is_saving: bool = false
var _is_loading: bool = false
var _last_phase: StringName = StringName()
var _last_state: StringName = StringName()
var _last_error_code: StringName = StringName()
var _used_backup_on_load: bool = false
var _load_progress: float = 0.0
var _load_progress_label: String = ""
var _slot_meta_list: Array[Dictionary] = []
#endregion

#region 对外只读
func get_current_slot_id() -> int:
	return _current_slot_id


func get_is_saving() -> bool:
	return _is_saving


func get_is_loading() -> bool:
	return _is_loading


func get_last_phase() -> StringName:
	return _last_phase


func get_last_state() -> StringName:
	return _last_state


func get_last_error_code() -> StringName:
	return _last_error_code


func get_used_backup_on_load() -> bool:
	return _used_backup_on_load


func get_load_progress() -> float:
	return _load_progress


func get_load_progress_label() -> String:
	return _load_progress_label


func get_slot_meta_list() -> Array[Dictionary]:
	return _slot_meta_list.duplicate(true)


func get_slot_meta_data_list() -> Array[SaveSlotMetaData]:
	var data_list: Array[SaveSlotMetaData] = []
	for raw in _slot_meta_list:
		var slot_meta_data: SaveSlotMetaData = SaveSlotMetaData.new()
		slot_meta_data.from_dict(raw)
		data_list.append(slot_meta_data)
	return data_list


func get_runtime_snapshot() -> Dictionary:
	return {
		"current_slot_id": _current_slot_id,
		"is_saving": _is_saving,
		"is_loading": _is_loading,
		"last_phase": String(_last_phase),
		"last_state": String(_last_state),
		"last_error_code": String(_last_error_code),
		"used_backup_on_load": _used_backup_on_load,
		"load_progress": _load_progress,
		"load_progress_label": _load_progress_label,
		"slot_meta_list": get_slot_meta_list()
	}
#endregion

#region 应用与重置
func apply_runtime_snapshot(update: Dictionary) -> void:
	_current_slot_id = _pick_int(update, "current_slot_id", _current_slot_id)
	_is_saving = _pick_bool(update, "is_saving", _is_saving)
	_is_loading = _pick_bool(update, "is_loading", _is_loading)
	_last_phase = _pick_string_name(update, "last_phase", _last_phase)
	_last_state = _pick_string_name(update, "last_state", _last_state)
	_last_error_code = _pick_string_name(update, "last_error_code", _last_error_code)
	_used_backup_on_load = _pick_bool(update, "used_backup_on_load", _used_backup_on_load)
	_load_progress = _pick_float(update, "load_progress", _load_progress)
	_load_progress_label = _pick_string(update, "load_progress_label", _load_progress_label)


func apply_slot_meta_list(slot_meta_list: Array[Dictionary]) -> void:
	_slot_meta_list = slot_meta_list.duplicate(true)


func clear() -> void:
	_current_slot_id = 1
	_is_saving = false
	_is_loading = false
	_last_phase = StringName()
	_last_state = StringName()
	_last_error_code = StringName()
	_used_backup_on_load = false
	_load_progress = 0.0
	_load_progress_label = ""
	_slot_meta_list.clear()


func reset() -> void:
	clear()
#endregion

#region 内部解析
func _pick_int(source: Dictionary, key: StringName, fallback: int) -> int:
	if not source.has(key):
		return fallback
	return int(source.get(key, fallback))


func _pick_bool(source: Dictionary, key: StringName, fallback: bool) -> bool:
	if not source.has(key):
		return fallback
	return bool(source.get(key, fallback))


func _pick_string_name(source: Dictionary, key: StringName, fallback: StringName) -> StringName:
	if not source.has(key):
		return fallback
	return StringName(source.get(key, String(fallback)))


func _pick_float(source: Dictionary, key: StringName, fallback: float) -> float:
	if not source.has(key):
		return fallback
	return float(source.get(key, fallback))


func _pick_string(source: Dictionary, key: StringName, fallback: String) -> String:
	if not source.has(key):
		return fallback
	return str(source.get(key, fallback))


#endregion
