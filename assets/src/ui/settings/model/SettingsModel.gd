class_name SettingsModel
extends BaseModel

#region 状态
var _mode_index: int = 1
var _resolution_index: int = 2
var _fps_limit_index: int = 0
#endregion

#region 对外只读
func get_mode_index() -> int:
	return _mode_index


func get_resolution_index() -> int:
	return _resolution_index


func get_fps_limit_index() -> int:
	return _fps_limit_index


func get_runtime_snapshot() -> Dictionary:
	return {
		"mode_index": _mode_index,
		"resolution_index": _resolution_index,
		"fps_limit_index": _fps_limit_index
	}
#endregion

#region 应用与重置
func apply_runtime_snapshot(snapshot: Dictionary) -> void:
	_mode_index = _pick_int(snapshot, "mode_index", _mode_index)
	_resolution_index = _pick_int(snapshot, "resolution_index", _resolution_index)
	_fps_limit_index = _pick_int(snapshot, "fps_limit_index", _fps_limit_index)


func clear() -> void:
	_mode_index = 1
	_resolution_index = 2
	_fps_limit_index = 0


func reset() -> void:
	clear()
#endregion

#region 内部解析
func _pick_int(source: Dictionary, key: StringName, fallback: int) -> int:
	if not source.has(key):
		return fallback
	return int(source.get(key, fallback))
#endregion
