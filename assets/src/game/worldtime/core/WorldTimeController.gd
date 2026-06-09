class_name WorldTimeController
extends BaseController

const CONTROLLER_ID: StringName = &"world_time_controller"

signal world_time_changed(snapshot: Dictionary)

var _model: WorldTimeModel = WorldTimeModel.new()


func get_id() -> StringName:
	return CONTROLLER_ID


func get_save_scope() -> StringName:
	return SAVE_SCOPE_SLOT


func get_save_module_version() -> int:
	return 1


func on_game_start() -> void:
	_emit_changed()


func on_save_load() -> void:
	_emit_changed()


func on_save_unload() -> void:
	reset_to_default()


func advance(delta: float) -> void:
	if _model.advance(delta):
		_emit_changed()


func reset_to_default() -> void:
	_model.reset_to_default()
	_emit_changed()


func set_time_of_day(value: float) -> void:
	if _model.set_time_of_day(value):
		_emit_changed()


func set_time_scale(value: float) -> void:
	if _model.set_time_scale(value):
		_emit_changed()


func set_paused(value: bool) -> void:
	if _model.set_paused(value):
		_emit_changed()


func get_day_index() -> int:
	return _model.day_index


func get_time_of_day() -> float:
	return _model.time_of_day


func get_time_scale() -> float:
	return _model.time_scale


func get_night_factor() -> float:
	var hour: float = _model.time_of_day
	if hour >= 21.0 or hour < 5.0:
		return 1.0
	if hour >= 18.0 and hour < 21.0:
		return _smoothstep(18.0, 21.0, hour)
	if hour >= 5.0 and hour < 7.0:
		return 1.0 - _smoothstep(5.0, 7.0, hour)
	return 0.0


func get_runtime_snapshot() -> Dictionary:
	var snapshot: Dictionary = _model.get_snapshot()
	snapshot["night_factor"] = get_night_factor()
	return snapshot


func export_save_data() -> Dictionary:
	return _model.to_dict()


func import_save_data(payload: Dictionary) -> bool:
	_model.from_dict(payload)
	_emit_changed()
	return true


func get_save_meta_fragment() -> Dictionary:
	return {
		"world_time_label": _model.format_time_label(),
		"world_day_index": _model.day_index,
		"world_time_of_day": _model.time_of_day
	}


func _emit_changed() -> void:
	world_time_changed.emit(get_runtime_snapshot())


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	var weight: float = clampf((value - edge0) / maxf(edge1 - edge0, 0.001), 0.0, 1.0)
	return weight * weight * (3.0 - 2.0 * weight)
