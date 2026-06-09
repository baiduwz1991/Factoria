class_name AchievementModel
extends BaseModel

#region 配置与常量
const KEY_SCHEMA_VERSION: String = "schema_version"
const KEY_UNLOCKED: String = "unlocked"
const KEY_UNLOCKED_FLAG: String = "unlocked"
const KEY_UNLOCKED_AT_UNIX: String = "unlocked_at_unix"
const KEY_SOURCE_SLOT_ID: String = "source_slot_id"

const SCHEMA_VERSION: int = 1
#endregion

#region 状态
var _unlocked: Dictionary = {}
#endregion

#region 对外只读
func has_unlocked(achievement_id: StringName) -> bool:
	var entry: Dictionary = _unlocked.get(String(achievement_id), {})
	return bool(entry.get(KEY_UNLOCKED_FLAG, false))


func is_empty() -> bool:
	return _unlocked.is_empty()


func get_runtime_snapshot() -> Dictionary:
	return to_dict()
#endregion

#region 应用与重置
func apply_unlocked(achievement_id: StringName, unlocked_at_unix: int, source_slot_id: int) -> bool:
	if achievement_id == StringName():
		return false
	if has_unlocked(achievement_id):
		return false

	_unlocked[String(achievement_id)] = {
		KEY_UNLOCKED_FLAG: true,
		KEY_UNLOCKED_AT_UNIX: unlocked_at_unix,
		KEY_SOURCE_SLOT_ID: maxi(source_slot_id, 0)
	}
	return true


func clear() -> void:
	_unlocked.clear()


func reset() -> void:
	clear()
#endregion

#region 序列化
func to_dict() -> Dictionary:
	return {
		KEY_SCHEMA_VERSION: SCHEMA_VERSION,
		KEY_UNLOCKED: _unlocked.duplicate(true)
	}


func from_dict(raw: Dictionary) -> void:
	var unlocked_variant: Variant = raw.get(KEY_UNLOCKED, {})
	if not (unlocked_variant is Dictionary):
		_unlocked.clear()
		return

	_unlocked.clear()
	var raw_unlocked: Dictionary = unlocked_variant as Dictionary
	for achievement_id_variant in raw_unlocked.keys():
		var achievement_id: String = str(achievement_id_variant)
		var entry_variant: Variant = raw_unlocked.get(achievement_id_variant, {})
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant as Dictionary
		if not bool(entry.get(KEY_UNLOCKED_FLAG, false)):
			continue
		_unlocked[achievement_id] = {
			KEY_UNLOCKED_FLAG: true,
			KEY_UNLOCKED_AT_UNIX: int(entry.get(KEY_UNLOCKED_AT_UNIX, 0)),
			KEY_SOURCE_SLOT_ID: maxi(int(entry.get(KEY_SOURCE_SLOT_ID, 0)), 0)
		}
#endregion
