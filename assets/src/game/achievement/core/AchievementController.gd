class_name AchievementController
extends BaseController

#region 配置与常量
const CONTROLLER_ID: StringName = &"achievement_controller"
const ACHIEVEMENT_FIRST_ENTER_PLANET: StringName = &"first_enter_planet"
#endregion

#region 信号-面向状态与流程
signal achievement_state_changed(snapshot: Dictionary)
signal achievement_unlocked(achievement_id: StringName, snapshot: Dictionary)
#endregion

#region 状态
var _model: AchievementModel = AchievementModel.new()
#endregion

#region 对外接口 - 标识
func get_id() -> StringName:
	return CONTROLLER_ID


func get_save_scope() -> StringName:
	return SAVE_SCOPE_PROFILE


func get_save_module_version() -> int:
	return 1
#endregion

#region 对外接口 - 生命周期
func on_game_start() -> void:
	_emit_state()
#endregion

#region 对外接口 - 成就
func record_first_enter_planet(slot_id: int) -> bool:
	return unlock_achievement(ACHIEVEMENT_FIRST_ENTER_PLANET, slot_id)


func unlock_achievement(achievement_id: StringName, source_slot_id: int = 0) -> bool:
	var did_unlock: bool = _model.apply_unlocked(
		achievement_id,
		int(Time.get_unix_time_from_system()),
		source_slot_id
	)
	if not did_unlock:
		return false

	var snapshot: Dictionary = get_runtime_snapshot()
	achievement_unlocked.emit(achievement_id, snapshot)
	achievement_state_changed.emit(snapshot)
	return true


func has_unlocked(achievement_id: StringName) -> bool:
	return _model.has_unlocked(achievement_id)


func get_runtime_snapshot() -> Dictionary:
	return _model.get_runtime_snapshot()
#endregion

#region 对外接口 - 存档数据
func export_save_data() -> Dictionary:
	if _model.is_empty():
		return {}
	return _model.to_dict()


func import_save_data(payload: Dictionary) -> bool:
	if payload.is_empty():
		return true
	_model.from_dict(payload)
	_emit_state()
	return true
#endregion

#region 内部实现
func _emit_state() -> void:
	achievement_state_changed.emit(get_runtime_snapshot())
#endregion
