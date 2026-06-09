class_name RoleCreateController
extends BaseController

#region 配置与常量
const CONTROLLER_ID: StringName = &"role_create_controller"
const ERROR_PLAYER_NAME_EMPTY: StringName = &"player_name_empty"
const ERROR_PERSONALITY_INVALID: StringName = &"personality_invalid"
const ERROR_VALIDATION_FAILED: StringName = &"validation_failed"
const ERROR_SAVE_CONTROLLER_MISSING: StringName = &"save_controller_missing"
const ERROR_PLANET_CONTROLLER_MISSING: StringName = &"planet_controller_missing"
const ERROR_PLANET_CREATE_FAILED: StringName = &"planet_create_failed"
const PERSONALITY_OPTIONS: Array[String] = [
	"沉稳",
	"热血",
	"机敏"
]
#endregion

#region 信号-面向view的状态与流程
signal role_create_state_changed(snapshot: Dictionary)
#endregion

#region 状态
var _runtime_model: RoleCreateModel = RoleCreateModel.new()
var _profile_data: RoleProfileData = RoleProfileData.new()
#endregion

#region 对外接口 - 标识
func get_id() -> StringName:
	return CONTROLLER_ID


func get_save_scope() -> StringName:
	return SAVE_SCOPE_SLOT


func get_save_module_version() -> int:
	return 1
#endregion

#region 对外接口 - 生命周期
func on_game_start() -> void:
	_emit_state()
#endregion

#region 对外接口 - 角色创建
func begin_create(slot_id: int) -> Dictionary:
	_runtime_model.apply_begin_create(slot_id, PERSONALITY_OPTIONS[0])
	_emit_state()
	return _runtime_model.get_runtime_snapshot()


func get_personality_options() -> Array[String]:
	return PERSONALITY_OPTIONS.duplicate()


func get_planet_preset_options() -> Array[Dictionary]:
	var planet_controller: PlanetController = _get_planet_controller()
	if planet_controller == null:
		return []
	return planet_controller.get_planet_preset_options()


func update_player_name(player_name: String) -> Dictionary:
	var normalized_name: String = RoleCreateHelper.normalize_player_name(player_name)
	if normalized_name == "":
		return _build_error_result(ERROR_PLAYER_NAME_EMPTY)

	_profile_data.apply_profile(
		_profile_data.slot_id,
		normalized_name,
		_profile_data.player_personality
	)
	_runtime_model.apply_player_name_input(normalized_name)
	_emit_state()
	return {
		"ok": true
	}


func validate_role_input(player_name: String, personality: String) -> Dictionary:
	return RoleCreateHelper.validate_role_input(
		player_name,
		personality,
		PERSONALITY_OPTIONS,
		ERROR_PLAYER_NAME_EMPTY,
		ERROR_PERSONALITY_INVALID
	)


func request_create_role(
	slot_id: int,
	player_name: String,
	personality: String,
	planet_preset_id: StringName = &"standard",
	planet_seed: int = 0,
	back: Callable = Callable()
) -> bool:
	var validation: Dictionary = validate_role_input(player_name, personality)
	if not bool(validation.get("ok", false)):
		var error_code: StringName = validation.get("error_code", ERROR_VALIDATION_FAILED)
		_apply_error_state(error_code)
		_emit_back(back, {
			"ok": false,
			"error_code": error_code
		})
		return false

	var normalized_name: String = str(validation.get("normalized_name", ""))
	_profile_data.apply_profile(slot_id, normalized_name, personality)
	_runtime_model.apply_submit_request(slot_id, normalized_name, personality)
	_emit_state()

	var planet_controller: PlanetController = _get_planet_controller()
	if planet_controller == null:
		_apply_error_state(ERROR_PLANET_CONTROLLER_MISSING)
		_emit_back(back, {
			"ok": false,
			"error_code": ERROR_PLANET_CONTROLLER_MISSING
		})
		return false

	var resolved_planet_seed := planet_seed if planet_seed != 0 else _generate_planet_seed()
	var planet_result: Dictionary = planet_controller.create_planet_for_slot(slot_id, planet_preset_id, resolved_planet_seed)
	if not bool(planet_result.get("ok", false)):
		_apply_error_state(ERROR_PLANET_CREATE_FAILED)
		_emit_back(back, {
			"ok": false,
			"error_code": ERROR_PLANET_CREATE_FAILED,
			"detail": planet_result
		})
		return false

	var save_controller: SaveController = _get_save_controller()
	if save_controller == null:
		_apply_error_state(ERROR_SAVE_CONTROLLER_MISSING)
		_emit_back(back, {
			"ok": false,
			"error_code": ERROR_SAVE_CONTROLLER_MISSING
		})
		return false

	return save_controller.request_save_slot(
		slot_id,
		Callable(self, "_on_create_role_saved").bind(back)
	)
#endregion

#region 对外接口 - 页面流程
func request_close_ui(ui_instance_id: int) -> void:
	UIManager.close_ui(ui_instance_id)


func request_open_planet_after_create(source_ui_instance_id: int, slot_id: int) -> void:
	var loading_controller: LoadingController = _get_loading_controller()
	if loading_controller != null:
		loading_controller.request_enter_planet_after_create(source_ui_instance_id, slot_id)
		return

	push_error("RoleCreateController 打开世界失败：LoadingController 未就绪。")
#endregion

#region 内部实现
func _on_create_role_saved(result: Dictionary, back: Callable) -> void:
	var ok: bool = bool(result.get("ok", false))
	_runtime_model.apply_submit_result(StringName(result.get("error_code", "")))
	_emit_state()

	var payload: Dictionary = result.duplicate(true)
	if ok:
		payload["profile"] = get_player_profile()
	_emit_back(back, payload)


func _get_save_controller() -> SaveController:
	var existing: SaveController = ControllerManager.get_controller(SaveController.CONTROLLER_ID) as SaveController
	if existing != null:
		return existing

	return ControllerManager.get_or_register_controller(
		SaveController.CONTROLLER_ID,
		func() -> BaseController:
			return SaveController.new()
	) as SaveController


func _get_loading_controller() -> LoadingController:
	var existing: LoadingController = ControllerManager.get_controller(LoadingController.CONTROLLER_ID) as LoadingController
	if existing != null:
		return existing

	return ControllerManager.get_or_register_controller(
		LoadingController.CONTROLLER_ID,
		func() -> BaseController:
			return LoadingController.new()
	) as LoadingController


func _get_planet_controller() -> PlanetController:
	var existing: PlanetController = ControllerManager.get_controller(PlanetController.CONTROLLER_ID) as PlanetController
	if existing != null:
		return existing

	return ControllerManager.get_or_register_controller(
		PlanetController.CONTROLLER_ID,
		func() -> BaseController:
			return PlanetController.new()
	) as PlanetController


func _generate_planet_seed() -> int:
	return randi_range(1, 2147483647)


func _emit_state() -> void:
	role_create_state_changed.emit(_runtime_model.get_runtime_snapshot())


func get_player_profile() -> Dictionary:
	return {
		"slot_id": _profile_data.slot_id,
		"player_name": _profile_data.player_name,
		"player_personality": _profile_data.player_personality
	}


func export_save_data() -> Dictionary:
	return _profile_data.to_dict()


func import_save_data(payload: Dictionary) -> bool:
	if payload.is_empty():
		return true
	_profile_data.from_dict(payload)
	_runtime_model.apply_imported_slot(_profile_data.slot_id)
	_emit_state()
	return true


func get_save_meta_fragment() -> Dictionary:
	var player_name: String = _profile_data.player_name
	var personality: String = _profile_data.player_personality
	return {
		"title": player_name if player_name != "" else "存档 %02d" % _profile_data.slot_id,
		"player_name": player_name,
		"personality": personality
	}


func _emit_back(back: Callable, payload: Dictionary) -> void:
	if back.is_valid():
		back.call(payload)


func _apply_error_state(error_code: StringName) -> void:
	_runtime_model.apply_submit_result(error_code)
	_emit_state()


func _build_error_result(error_code: StringName) -> Dictionary:
	_apply_error_state(error_code)
	return RoleCreateHelper.build_error_result(error_code)
#endregion
