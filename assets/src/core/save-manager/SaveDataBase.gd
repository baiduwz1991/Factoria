class_name SaveDataBase
extends RefCounted

#region 对外接口 - 版本
func get_schema_version() -> int:
	return 1
#endregion

#region 对外接口 - 序列化
func to_dict() -> Dictionary:
	return {}


func from_dict(_raw: Dictionary) -> void:
	pass


func sanitize() -> void:
	pass
#endregion
