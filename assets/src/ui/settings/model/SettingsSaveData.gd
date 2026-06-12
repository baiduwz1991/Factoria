class_name SettingsSaveData
extends SaveDataBase

#region 状态
var mode_index: int = 1
var resolution_index: int = 2
var fps_limit_index: int = 0
#endregion

#region 对外接口 - 版本
func get_schema_version() -> int:
	return 2
#endregion

#region 对外接口 - 序列化
func to_dict() -> Dictionary:
	return {
		"schema_version": get_schema_version(),
		"mode_index": mode_index,
		"resolution_index": resolution_index,
		"fps_limit_index": fps_limit_index
	}


func from_dict(raw: Dictionary) -> void:
	mode_index = int(raw.get("mode_index", mode_index))
	resolution_index = int(raw.get("resolution_index", resolution_index))
	fps_limit_index = int(raw.get("fps_limit_index", fps_limit_index))
	sanitize()


func sanitize() -> void:
	mode_index = maxi(mode_index, 0)
	resolution_index = maxi(resolution_index, 0)
	fps_limit_index = maxi(fps_limit_index, 0)
#endregion

#region 对外接口 - 域转换
func apply_from_runtime_snapshot(snapshot: Dictionary) -> void:
	mode_index = int(snapshot.get("mode_index", mode_index))
	resolution_index = int(snapshot.get("resolution_index", resolution_index))
	fps_limit_index = int(snapshot.get("fps_limit_index", fps_limit_index))
	sanitize()


func to_runtime_snapshot() -> Dictionary:
	return {
		"mode_index": mode_index,
		"resolution_index": resolution_index,
		"fps_limit_index": fps_limit_index
	}
#endregion
