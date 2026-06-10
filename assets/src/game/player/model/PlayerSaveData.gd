class_name PlayerSaveData
extends SaveDataBase

#region 状态
var slot_id: int = 0
var has_position: bool = false
var position: Vector2 = Vector2.ZERO
var facing: StringName = &"down"
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
		"has_position": has_position,
		"position": SerializeUtils.vector2_to_dict(position),
		"facing": String(facing)
	}


func from_dict(raw: Dictionary) -> void:
	slot_id = int(raw.get("slot_id", slot_id))
	has_position = bool(raw.get("has_position", raw.has("position")))
	position = SerializeUtils.parse_vector2(raw.get("position", position), position)
	facing = StringName(raw.get("facing", String(facing)))
	sanitize()


func sanitize() -> void:
	slot_id = maxi(slot_id, 0)
	if String(facing) == "":
		facing = &"down"
#endregion

#region 对外接口 - 应用
func apply_slot(next_slot_id: int) -> void:
	slot_id = maxi(next_slot_id, 0)


func apply_player_state(next_slot_id: int, next_position: Vector2, next_facing: StringName) -> void:
	slot_id = maxi(next_slot_id, 0)
	has_position = true
	position = next_position
	facing = next_facing
	sanitize()


func clear() -> void:
	slot_id = 0
	has_position = false
	position = Vector2.ZERO
	facing = &"down"
#endregion
