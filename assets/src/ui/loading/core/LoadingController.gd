class_name LoadingController
extends BaseController

const CONTROLLER_ID: StringName = &"loading_controller"
const ERROR_LOADING_ACTIVE: StringName = &"loading_active"
const ERROR_SAVE_CONTROLLER_MISSING: StringName = &"save_controller_missing"
const ERROR_SAVE_LOAD_FAILED: StringName = &"save_load_failed"
const ERROR_LOADING_LAYER_OPEN_FAILED: StringName = &"loading_layer_open_failed"
const ERROR_SCENE_OPEN_FAILED: StringName = &"scene_open_failed"
const ERROR_MAP_PRELOAD_FAILED: StringName = &"map_preload_failed"
const INITIAL_PRELOAD_EXTRA_RADIUS: int = 1
const SCENE_REGISTRY_SCRIPT: GDScript = preload("res://assets/src/core/scene-manager/SceneRegistry.gd")

signal loading_changed(snapshot: Dictionary)

var _model: LoadingModel = LoadingModel.new()
var _steps: Array[Dictionary] = []
var _current_step_index: int = -1
var _current_step_started: bool = false
var _completed_weight: float = 0.0
var _total_weight: float = 0.0
var _flow_back: Callable = Callable()
var _source_ui_instance_id: int = -1
var _slot_id: int = 0
var _save_source: StringName = &"main"
var _loading_ui_instance_id: int = -1
var _save_done: bool = false
var _save_result: Dictionary = {}
var _game_scene: Node = null
var _map_view: LayeredChunkMapView = null
var _player: Node2D = null


func get_id() -> StringName:
	return CONTROLLER_ID


func request_enter_planet_from_save(
	source_ui_instance_id: int,
	slot_id: int,
	source: StringName = &"main",
	back: Callable = Callable()
) -> bool:
	if _model.is_active():
		_emit_back(back, {
			"ok": false,
			"error_code": ERROR_LOADING_ACTIVE
		})
		return false
	_begin_enter_planet_flow(source_ui_instance_id, slot_id, source, true, back)
	return true


func request_enter_planet_after_create(
	source_ui_instance_id: int,
	slot_id: int,
	back: Callable = Callable()
) -> bool:
	if _model.is_active():
		_emit_back(back, {
			"ok": false,
			"error_code": ERROR_LOADING_ACTIVE
		})
		return false
	_begin_enter_planet_flow(source_ui_instance_id, slot_id, &"main", false, back)
	return true


func process_loading(_delta: float = 0.0) -> void:
	if not _model.is_active():
		return
	if _current_step_index < 0:
		_advance_to_next_step()
	if _current_step_index < 0 or _current_step_index >= _steps.size():
		return

	var step: Dictionary = _steps[_current_step_index]
	if not _current_step_started:
		_current_step_started = true
		var start_callable: Callable = step.get("start", Callable()) as Callable
		if start_callable.is_valid():
			start_callable.call()

	var poll_callable: Callable = step.get("poll", Callable()) as Callable
	if not poll_callable.is_valid():
		_complete_current_step()
		return

	var poll_result_variant: Variant = poll_callable.call()
	var poll_result: Dictionary = poll_result_variant if poll_result_variant is Dictionary else {}
	var step_progress: float = clampf(float(poll_result.get("progress", 0.0)), 0.0, 1.0)
	var step_label: String = str(poll_result.get("label", step.get("label", "")))
	_apply_weighted_progress(step, step_progress, step_label)

	if not bool(poll_result.get("done", false)):
		return
	if not bool(poll_result.get("ok", true)):
		var error_code: StringName = StringName(poll_result.get("error_code", ERROR_MAP_PRELOAD_FAILED))
		_fail_flow(error_code, step_label)
		return

	_complete_current_step()


func get_runtime_snapshot() -> Dictionary:
	return _model.get_snapshot()


func cancel_active_loading() -> void:
	if not _model.is_active():
		return
	_cancel_current_step()
	_fail_flow(&"loading_cancelled", "加载已取消")


func _begin_enter_planet_flow(
	source_ui_instance_id: int,
	slot_id: int,
	source: StringName,
	include_save_load: bool,
	back: Callable
) -> void:
	_source_ui_instance_id = source_ui_instance_id
	_slot_id = slot_id
	_save_source = source
	_flow_back = back
	_save_done = false
	_save_result = {}
	_game_scene = null
	_map_view = null
	_player = null
	_completed_weight = 0.0
	_total_weight = 0.0
	_current_step_index = -1
	_current_step_started = false
	_steps = _build_enter_planet_steps(include_save_load)
	for step in _steps:
		_total_weight += maxf(float(step.get("weight", 0.0)), 0.0)
	if _total_weight <= 0.0:
		_total_weight = 1.0

	if not _open_loading_layer():
		_emit_back(_flow_back, {
			"ok": false,
			"error_code": ERROR_LOADING_LAYER_OPEN_FAILED,
			"slot_id": _slot_id
		})
		_reset_flow_state()
		return
	_model.begin("加载世界", "正在准备世界...")
	_emit_loading_changed()


func _build_enter_planet_steps(include_save_load: bool) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	if include_save_load:
		steps.append({
			"id": &"save_load",
			"label": "正在读取存档...",
			"weight": 30.0,
			"start": Callable(self, "_start_save_load_step"),
			"poll": Callable(self, "_poll_save_load_step"),
			"cancel": Callable()
		})
	steps.append({
		"id": &"open_scene",
		"label": "正在打开世界...",
		"weight": 10.0,
		"start": Callable(self, "_start_open_scene_step"),
		"poll": Callable(self, "_poll_open_scene_step"),
		"cancel": Callable()
	})
	steps.append({
		"id": &"map_preload",
		"label": "正在预热地图...",
		"weight": 60.0,
		"start": Callable(self, "_start_map_preload_step"),
		"poll": Callable(self, "_poll_map_preload_step"),
		"cancel": Callable()
	})
	return steps


func _advance_to_next_step() -> void:
	_current_step_index += 1
	_current_step_started = false
	if _current_step_index >= _steps.size():
		_complete_flow()


func _complete_current_step() -> void:
	if _current_step_index >= 0 and _current_step_index < _steps.size():
		var step: Dictionary = _steps[_current_step_index]
		_completed_weight += maxf(float(step.get("weight", 0.0)), 0.0)
	_advance_to_next_step()


func _apply_weighted_progress(step: Dictionary, step_progress: float, step_label: String) -> void:
	var step_id: StringName = StringName(step.get("id", &""))
	var step_weight: float = maxf(float(step.get("weight", 0.0)), 0.0)
	var weighted_progress: float = (_completed_weight + step_weight * step_progress) / _total_weight * 100.0
	_model.apply_step(step_id, step_label, weighted_progress)
	_emit_loading_changed()


func _start_save_load_step() -> void:
	_save_done = false
	_save_result = {}
	var save_controller: SaveController = _get_save_controller()
	if save_controller == null:
		_save_done = true
		_save_result = {
			"ok": false,
			"error_code": ERROR_SAVE_CONTROLLER_MISSING
		}
		return

	var started: bool = false
	if _save_source == &"main":
		started = save_controller.request_load_slot(_slot_id, Callable(self, "_on_save_load_completed"))
	else:
		started = save_controller.request_load_slot_by_source(_slot_id, _save_source, Callable(self, "_on_save_load_completed"))
	if not started:
		_save_done = true
		_save_result = {
			"ok": false,
			"error_code": ERROR_SAVE_LOAD_FAILED
		}


func _poll_save_load_step() -> Dictionary:
	if _save_done:
		return {
			"done": true,
			"ok": bool(_save_result.get("ok", false)),
			"progress": 1.0,
			"label": "存档读取完成" if bool(_save_result.get("ok", false)) else "存档读取失败",
			"error_code": StringName(_save_result.get("error_code", ERROR_SAVE_LOAD_FAILED))
		}

	var progress: float = 0.15
	var label: String = "正在读取存档..."
	var save_controller: SaveController = _get_save_controller()
	if save_controller != null:
		var snapshot: Dictionary = save_controller.get_runtime_snapshot()
		progress = clampf(float(snapshot.get("load_progress", 0.0)) / 100.0, 0.0, 0.95)
		var runtime_label: String = str(snapshot.get("load_progress_label", ""))
		if runtime_label != "":
			label = runtime_label
	return {
		"done": false,
		"ok": true,
		"progress": progress,
		"label": label
	}


func _on_save_load_completed(result: Dictionary) -> void:
	_save_result = result.duplicate(true)
	_save_done = true


func _start_open_scene_step() -> void:
	_game_scene = SceneManager.open_scene(
		SCENE_REGISTRY_SCRIPT.GAME_SCENE,
		{
			"slot_id": _slot_id,
			"defer_initial_loading": true
		},
		SceneManager.MODE_REPLACE,
		{
			"close_overlays": false
		}
	)
	if _game_scene == null:
		return
	UIManager.close_all_overlays_except(_loading_ui_instance_id)
	if _game_scene.has_method("get_map_view"):
		_map_view = _game_scene.call("get_map_view") as LayeredChunkMapView
	if _game_scene.has_method("get_player"):
		_player = _game_scene.call("get_player") as Node2D


func _poll_open_scene_step() -> Dictionary:
	var ok: bool = _game_scene != null
	return {
		"done": true,
		"ok": ok,
		"progress": 1.0 if ok else 0.0,
		"label": "世界打开完成" if ok else "世界打开失败",
		"error_code": ERROR_SCENE_OPEN_FAILED
	}


func _start_map_preload_step() -> void:
	if _map_view == null or _player == null:
		return
	_map_view.begin_preload_around(_player.global_position, INITIAL_PRELOAD_EXTRA_RADIUS)


func _poll_map_preload_step() -> Dictionary:
	if _map_view == null:
		return {
			"done": true,
			"ok": false,
			"progress": 0.0,
			"label": "地图预热失败",
			"error_code": ERROR_MAP_PRELOAD_FAILED
		}

	var snapshot: Dictionary = _map_view.get_preload_snapshot()
	var active: bool = bool(snapshot.get("active", false))
	var completed: bool = bool(snapshot.get("completed", false))
	var progress: float = clampf(float(snapshot.get("progress", 0.0)), 0.0, 100.0) / 100.0
	var loaded_count: int = int(snapshot.get("loaded_count", 0))
	var total_count: int = int(snapshot.get("total_count", 0))
	if not active and not completed:
		return {
			"done": true,
			"ok": false,
			"progress": progress,
			"label": "地图预热失败",
			"error_code": ERROR_MAP_PRELOAD_FAILED
		}
	return {
		"done": completed,
		"ok": completed or active,
		"progress": progress,
		"label": "正在预热地图 %d/%d" % [loaded_count, total_count],
		"error_code": ERROR_MAP_PRELOAD_FAILED
	}


func _complete_flow() -> void:
	_model.apply_completed("加载完成")
	_emit_loading_changed()

	if _source_ui_instance_id >= 0:
		UIManager.close_ui(_source_ui_instance_id)
	_source_ui_instance_id = -1
	UIManager.set_ui_root_visible(true)
	UIManager.set_main_layer_visible(false)
	_close_loading_layer()
	if _game_scene != null and _game_scene.has_method("finish_initial_loading"):
		_game_scene.call("finish_initial_loading")
	_emit_back(_flow_back, {
		"ok": true,
		"slot_id": _slot_id
	})
	_reset_flow_state()


func _fail_flow(error_code: StringName, label: String) -> void:
	_model.apply_failed(error_code, label)
	_emit_loading_changed()
	UIManager.set_ui_root_visible(true)
	UIManager.set_main_layer_visible(true)
	if _game_scene != null:
		SceneManager.close_current_scene({"close_overlays": false})
	_close_loading_layer()
	_emit_back(_flow_back, {
		"ok": false,
		"error_code": error_code,
		"slot_id": _slot_id
	})
	_reset_flow_state()


func _cancel_current_step() -> void:
	if _current_step_index < 0 or _current_step_index >= _steps.size():
		return
	var step: Dictionary = _steps[_current_step_index]
	var cancel_callable: Callable = step.get("cancel", Callable()) as Callable
	if cancel_callable.is_valid():
		cancel_callable.call()


func _reset_flow_state() -> void:
	_steps.clear()
	_current_step_index = -1
	_current_step_started = false
	_completed_weight = 0.0
	_total_weight = 0.0
	_flow_back = Callable()
	_source_ui_instance_id = -1
	_slot_id = 0
	_save_source = &"main"
	_save_done = false
	_save_result = {}
	_game_scene = null
	_map_view = null
	_player = null


func _open_loading_layer() -> bool:
	if _loading_ui_instance_id >= 0:
		return true
	var loading_ui: BaseUI = UIManager.open_overlay(UIRegistry.LOADING_LAYER, {
		"title_text": "加载世界",
		"fallback_hint_text": "正在准备世界..."
	})
	if loading_ui == null:
		return false
	_loading_ui_instance_id = loading_ui.get_instance_id()
	return true


func _close_loading_layer() -> void:
	if _loading_ui_instance_id < 0:
		return
	UIManager.close_ui(_loading_ui_instance_id)
	_loading_ui_instance_id = -1


func _emit_loading_changed() -> void:
	loading_changed.emit(_model.get_snapshot())


func _emit_back(back: Callable, payload: Dictionary) -> void:
	if back.is_valid():
		back.call(payload)


func _get_save_controller() -> SaveController:
	var existing: SaveController = ControllerManager.get_controller(SaveController.CONTROLLER_ID) as SaveController
	if existing != null:
		return existing
	return ControllerManager.get_or_register_controller(
		SaveController.CONTROLLER_ID,
		func() -> BaseController:
			return SaveController.new()
	) as SaveController
