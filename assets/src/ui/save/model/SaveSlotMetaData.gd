class_name SaveSlotMetaData
extends SaveDataBase

#region 状态
var slot_id: int = 0
var title: String = ""
var updated_at_unix: int = 0
#endregion

#region 对外接口 - 版本
func get_schema_version() -> int:
	return 1
#endregion

#region 对外接口 - 序列化
func to_dict() -> Dictionary:
	return {
		"slot_id": slot_id,
		"title": title,
		"updated_at_unix": updated_at_unix
	}


func from_dict(raw: Dictionary) -> void:
	slot_id = int(raw.get("slot_id", slot_id))
	title = str(raw.get("title", title))
	updated_at_unix = int(raw.get("updated_at_unix", updated_at_unix))
	sanitize()


func sanitize() -> void:
	slot_id = maxi(slot_id, 0)
	if title == "":
		title = "存档 %02d" % slot_id
	updated_at_unix = maxi(updated_at_unix, 0)
#endregion
