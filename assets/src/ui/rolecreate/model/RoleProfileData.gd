class_name RoleProfileData
extends SaveDataBase

#region 状态
var slot_id: int = 1
var player_name: String = ""
var player_personality: String = ""
#endregion

#region 对外接口 - 版本
func get_schema_version() -> int:
	return 1
#endregion

#region 对外接口 - 序列化
func to_dict() -> Dictionary:
	return {
		"schema_version": get_schema_version(),
		"slot_id": slot_id,
		"player_name": player_name,
		"player_personality": player_personality
	}


func from_dict(raw: Dictionary) -> void:
	slot_id = int(raw.get("slot_id", slot_id))
	player_name = str(raw.get("player_name", player_name))
	player_personality = str(raw.get("player_personality", player_personality))
	sanitize()


func sanitize() -> void:
	slot_id = maxi(slot_id, 1)
#endregion

#region 对外接口 - 应用
func apply_profile(next_slot_id: int, next_player_name: String, next_player_personality: String) -> void:
	slot_id = next_slot_id
	player_name = next_player_name
	player_personality = next_player_personality
	sanitize()
#endregion
