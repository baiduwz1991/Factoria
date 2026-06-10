class_name SaveController
extends BaseController

#region 配置与常量
const CONTROLLER_ID: StringName = &"save_controller"
const ERROR_SAVE_MANAGER_MISSING: StringName = &"save_manager_missing"
const ERROR_GAME_SCENE_LOAD_FAILED: StringName = &"game_scene_load_failed"
const SAVE_LOADING_UI_ID: StringName = UIRegistry.SAVE_LOADING_POP_LAYER
const SCENE_REGISTRY_SCRIPT: GDScript = preload("res://assets/src/core/scene-manager/SceneRegistry.gd")
#endregion

#region 信号-面向view的状态与流程
signal save_runtime_changed(snapshot: Dictionary)
signal slot_meta_changed(slot_meta_list: Array[Dictionary])
#endregion

#region 状态
var _model: SaveModel = SaveModel.new()
var _save_manager: Node = null
var _save_loading_ui_instance_id: int = -1
var _save_loading_overlay_allowed: bool = true
#endregion

#region 对外接口 - 标识
func get_id() -> StringName:
	return CONTROLLER_ID


func get_save_scope() -> StringName:
	return SAVE_SCOPE_NONE
#endregion

#region 对外接口 - 生命周期
func on_game_start() -> void:
	_save_manager = _get_save_manager()
	_bind_save_manager_signals()
	_ensure_save_participant_controllers()
	refresh_slot_meta()


func on_release() -> void:
	_close_save_loading_overlay()
	_unbind_save_manager_signals()
	_save_manager = null
	super.on_release()
#endregion

#region 对外接口 - 存读档
func request_save_slot(slot_id: int, back: Callable = Callable(), options: Dictionary = {}) -> bool:
	_ensure_save_participant_controllers()
	var manager: Node = _ensure_save_manager()
	if manager == null:
		return _fail_with_missing_save_manager(&"save", back)

	_save_loading_overlay_allowed = bool(options.get("show_loading_overlay", true))
	_prepare_slot_runtime(slot_id)
	var started: bool = bool(manager.call("request_save", slot_id, back))
	if not started:
		_save_loading_overlay_allowed = true
	return started


func request_load_slot(slot_id: int, back: Callable = Callable()) -> bool:
	_ensure_save_participant_controllers()
	var manager: Node = _ensure_save_manager()
	if manager == null:
		return _fail_with_missing_save_manager(&"load", back)

	_prepare_slot_runtime(slot_id)
	return bool(manager.call("request_load", slot_id, back))


func request_load_slot_by_source(
	slot_id: int,
	source: StringName,
	back: Callable = Callable()
) -> bool:
	_ensure_save_participant_controllers()
	var manager: Node = _ensure_save_manager()
	if manager == null:
		return _fail_with_missing_save_manager(&"load", back)

	_prepare_slot_runtime(slot_id)
	return bool(manager.call("request_load_by_source", slot_id, source, back))


func refresh_slot_meta() -> Array[Dictionary]:
	var manager: Node = _ensure_save_manager()
	if manager == null:
		_model.apply_slot_meta_list([])
		slot_meta_changed.emit([])
		return []

	var slot_meta_list: Array[Dictionary] = manager.call("refresh_slot_meta")
	_model.apply_slot_meta_list(slot_meta_list)
	slot_meta_changed.emit(_model.get_slot_meta_list())
	return _model.get_slot_meta_list()


func get_runtime_snapshot() -> Dictionary:
	return _model.get_runtime_snapshot()


func get_slot_meta_list() -> Array[Dictionary]:
	return _model.get_slot_meta_list()


func get_slot_meta_data_list() -> Array[SaveSlotMetaData]:
	return _model.get_slot_meta_data_list()


func get_slot_backups(slot_id: int) -> Array[Dictionary]:
	var manager: Node = _ensure_save_manager()
	if manager == null:
		return []
	return manager.call("get_slot_backups", slot_id)

func request_delete_slot(slot_id: int, back: Callable = Callable()) -> bool:
	var manager: Node = _ensure_save_manager()
	if manager == null:
		_emit_back(back, SaveHelper.build_error_result(ERROR_SAVE_MANAGER_MISSING))
		return false
	return bool(manager.call("request_delete_slot", slot_id, back))
#endregion

#region 对外接口 - 页面流程
func request_close_ui(ui_instance_id: int) -> void:
	UIManager.close_ui(ui_instance_id)


func request_open_role_create(source_ui_instance_id: int, slot_id: int) -> void:
	UIManager.close_ui(source_ui_instance_id)
	UIManager.open_ui(UIRegistry.ROLE_CREATE_LAYER, {
		"slot_id": slot_id
	}, UIManager.MODE_REPLACE)


func request_open_slot_info(slot_id: int) -> void:
	UIManager.open_ui(UIRegistry.SLOT_INFO_POP_LAYER, {
		"slot_id": slot_id
	}, UIManager.MODE_OVERLAY)


func request_open_load_loading_overlay(
	title: String,
	hint: String,
	use_planet_progress: bool
) -> int:
	var loading_ui: BaseUI = UIManager.open_overlay(SAVE_LOADING_UI_ID, {
		"title_text": title,
		"fallback_hint_text": hint,
		"use_planet_progress": use_planet_progress
	})
	if loading_ui == null:
		push_warning("SaveController 打开加载界面失败：%s" % String(SAVE_LOADING_UI_ID))
		return -1
	return loading_ui.get_instance_id()


func request_close_loading_overlay(loading_ui_instance_id: int) -> void:
	if loading_ui_instance_id < 0:
		return
	UIManager.close_ui(loading_ui_instance_id)


func request_open_planet(
	source_ui_instance_id: int,
	slot_id: int,
	loading_ui_instance_id: int
) -> void:
	var game_scene: Node = SceneManager.open_scene(SCENE_REGISTRY_SCRIPT.GAME_SCENE, {
		"slot_id": slot_id,
		"loading_ui_instance_id": loading_ui_instance_id
	})
	if game_scene == null:
		request_close_loading_overlay(loading_ui_instance_id)
		push_error("SaveController 进入游戏场景失败：%s" % String(ERROR_GAME_SCENE_LOAD_FAILED))
		return

	UIManager.close_ui(source_ui_instance_id)
	UIManager.set_ui_root_visible(true)
	UIManager.set_main_layer_visible(false)
	request_close_loading_overlay(loading_ui_instance_id)
#endregion

#region 内部实现
func _ensure_save_manager() -> Node:
	var manager: Node = _get_save_manager()
	if manager == _save_manager:
		return manager

	_unbind_save_manager_signals()
	_save_manager = manager
	_bind_save_manager_signals()
	return _save_manager


func _ensure_save_participant_controllers() -> void:
	ControllerManager.get_or_register_controller(
		RoleCreateController.CONTROLLER_ID,
		func() -> BaseController:
			return RoleCreateController.new()
	)
	ControllerManager.get_or_register_controller(
		AchievementController.CONTROLLER_ID,
		func() -> BaseController:
			return AchievementController.new()
	)
	ControllerManager.get_or_register_controller(
		PlanetController.CONTROLLER_ID,
		func() -> BaseController:
			return PlanetController.new()
	)
	ControllerManager.get_or_register_controller(
		WorldTimeController.CONTROLLER_ID,
		func() -> BaseController:
			return WorldTimeController.new()
	)
	ControllerManager.get_or_register_controller(
		PlayerController.CONTROLLER_ID,
		func() -> BaseController:
			return PlayerController.new()
	)


func _bind_save_manager_signals() -> void:
	if _save_manager == null:
		return
	var save_state_callable: Callable = Callable(self, "_on_save_state_changed")
	if not _save_manager.is_connected("save_state_changed", save_state_callable):
		_save_manager.connect("save_state_changed", save_state_callable)

	var slot_meta_callable: Callable = Callable(self, "_on_slot_meta_updated")
	if not _save_manager.is_connected("slot_meta_updated", slot_meta_callable):
		_save_manager.connect("slot_meta_updated", slot_meta_callable)


func _unbind_save_manager_signals() -> void:
	if _save_manager == null:
		return
	var save_state_callable: Callable = Callable(self, "_on_save_state_changed")
	if _save_manager.is_connected("save_state_changed", save_state_callable):
		_save_manager.disconnect("save_state_changed", save_state_callable)

	var slot_meta_callable: Callable = Callable(self, "_on_slot_meta_updated")
	if _save_manager.is_connected("slot_meta_updated", slot_meta_callable):
		_save_manager.disconnect("slot_meta_updated", slot_meta_callable)


func _on_save_state_changed(runtime_snapshot: Dictionary) -> void:
	var phase: StringName = StringName(runtime_snapshot.get("phase", ""))
	var state: StringName = StringName(runtime_snapshot.get("state", ""))
	var error_code: StringName = SaveHelper.pick_error_code_from_runtime_snapshot(runtime_snapshot)
	var used_backup_on_load: bool = SaveHelper.pick_used_backup_from_runtime_snapshot(runtime_snapshot)
	var load_progress: float = SaveHelper.pick_load_progress_from_runtime_snapshot(runtime_snapshot)
	var load_progress_label: String = SaveHelper.pick_load_progress_label_from_runtime_snapshot(runtime_snapshot)
	if phase == &"load" and state == &"ok":
		load_progress = 100.0
		if load_progress_label == "":
			load_progress_label = "读档完成"
	_model.apply_runtime_snapshot({
		"is_saving": bool(runtime_snapshot.get("is_saving", false)),
		"is_loading": bool(runtime_snapshot.get("is_loading", false)),
		"last_phase": phase,
		"last_state": state,
		"last_error_code": error_code,
		"used_backup_on_load": used_backup_on_load,
		"load_progress": load_progress,
		"load_progress_label": load_progress_label
	})
	_sync_save_loading_overlay()
	_emit_runtime_update({})


func _on_slot_meta_updated(slot_meta_list: Array[Dictionary]) -> void:
	_model.apply_slot_meta_list(slot_meta_list)
	slot_meta_changed.emit(_model.get_slot_meta_list())
	_emit_runtime_update({})


func _emit_runtime_update(extra: Dictionary) -> void:
	if not extra.is_empty():
		_model.apply_runtime_snapshot(extra)
	save_runtime_changed.emit(_model.get_runtime_snapshot())


func _emit_back(back: Callable, payload: Dictionary) -> void:
	if back.is_valid():
		back.call(payload)


func _prepare_slot_runtime(slot_id: int) -> void:
	_model.apply_runtime_snapshot({"current_slot_id": slot_id})
	for controller_id in ControllerManager.list_controller_ids():
		var controller: BaseController = ControllerManager.get_controller(controller_id)
		if controller != null and controller.has_method("prepare_save_slot"):
			controller.call("prepare_save_slot", slot_id)
	_emit_runtime_update({})


func _fail_with_missing_save_manager(phase: StringName, back: Callable) -> bool:
	_emit_runtime_update(SaveHelper.build_missing_manager_runtime_snapshot(phase, ERROR_SAVE_MANAGER_MISSING))
	_emit_back(back, SaveHelper.build_error_result(ERROR_SAVE_MANAGER_MISSING))
	return false


func _sync_save_loading_overlay() -> void:
	var is_saving: bool = _model.get_is_saving()
	var is_loading: bool = _model.get_is_loading()
	if is_saving and not is_loading and _save_loading_overlay_allowed:
		_open_save_loading_overlay()
		return
	_close_save_loading_overlay()
	if not is_saving:
		_save_loading_overlay_allowed = true


func _open_save_loading_overlay() -> void:
	if _save_loading_ui_instance_id >= 0:
		return
	var loading_ui: BaseUI = UIManager.open_overlay(SAVE_LOADING_UI_ID, {
		"title_text": "保存中",
		"fallback_hint_text": "正在保存...",
		"use_planet_progress": false
	})
	if loading_ui == null:
		return
	_save_loading_ui_instance_id = loading_ui.get_instance_id()


func _close_save_loading_overlay() -> void:
	if _save_loading_ui_instance_id < 0:
		return
	UIManager.close_ui(_save_loading_ui_instance_id)
	_save_loading_ui_instance_id = -1
#endregion
