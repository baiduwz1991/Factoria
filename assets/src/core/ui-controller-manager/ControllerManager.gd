extends Node

signal phase_progress(phase: StringName, controller_id: StringName, completed_count: int, total_count: int)

var _controllers: Dictionary[StringName, BaseController] = {}
var _controller_dependencies: Dictionary = {}

var _actions_per_frame: int = 20

var _action_queue: Array[Callable] = []
var _current_phase_method: StringName = StringName()
var _phase_done: Dictionary[StringName, bool] = {}
var _phase_in_progress: Dictionary[StringName, bool] = {}
var _phase_dependencies: Dictionary = {}
var _phase_dependents: Dictionary = {}
var _phase_total_count: int = 0
var _phase_completed_count: int = 0
var _phase_back: Callable = Callable()


func register_controller(controller: BaseController) -> void:
	var controller_id: StringName = controller.get_id()
	_controllers[controller_id] = controller
	_log_lifecycle("register_controller -> %s" % String(controller_id))
	if not _controller_dependencies.has(controller_id):
		_controller_dependencies[controller_id] = []


func get_or_register_controller(controller_id: StringName, create_controller: Callable) -> BaseController:
	if has_controller(controller_id):
		return get_controller(controller_id)

	var created_variant: Variant = create_controller.call()
	var created_controller: BaseController = created_variant as BaseController
	if created_controller == null:
		push_error("ControllerManager 创建控制器失败：返回值不是 BaseController。")
		return null

	register_controller(created_controller)
	return created_controller


func has_controller(controller_id: StringName) -> bool:
	return _controllers.has(controller_id)


func list_controller_ids() -> Array[StringName]:
	var controller_ids: Array[StringName] = []
	for controller_id_variant in _controllers.keys():
		controller_ids.append(StringName(controller_id_variant))
	return controller_ids


func get_controller(controller_id: StringName) -> BaseController:
	if not has_controller(controller_id):
		return null
	return _controllers[controller_id]


func unregister_controller(controller_id: StringName) -> void:
	if has_controller(controller_id):
		_log_lifecycle("unregister_controller -> %s" % String(controller_id))
		var controller: BaseController = _controllers[controller_id]
		controller.on_release()
	_controllers.erase(controller_id)
	_controller_dependencies.erase(controller_id)


func clear_controllers() -> void:
	_log_lifecycle("clear_controllers -> total=%d" % _controllers.size())
	for controller in _controllers.values():
		controller.on_release()
	_controllers.clear()
	_controller_dependencies.clear()


func notify_game_start() -> void:
	_log_lifecycle("notify_game_start -> total=%d" % _controllers.size())
	for controller in _controllers.values():
		_log_lifecycle("on_game_start -> %s" % String(controller.get_id()))
		controller.on_game_start()


func notify_save_load(back: Callable = Callable()) -> void:
	_log_lifecycle("notify_save_load")
	_start_phase(BaseController.FLOW_SAVE_LOAD, back)


func notify_save_unload(back: Callable = Callable()) -> void:
	_log_lifecycle("notify_save_unload")
	_start_phase(BaseController.FLOW_SAVE_UNLOAD, back)


func notify_save_flush(back: Callable = Callable()) -> void:
	_log_lifecycle("notify_save_flush")
	_start_phase(BaseController.FLOW_SAVE_FLUSH, back)


func set_controller_dependencies(controller_id: StringName, dependencies: Array[StringName]) -> void:
	_controller_dependencies[controller_id] = _dedupe_dependencies(dependencies)


func clear_controller_dependencies(controller_id: StringName) -> void:
	_controller_dependencies.erase(controller_id)


func clear_phase_state() -> void:
	_action_queue.clear()
	_current_phase_method = StringName()
	_phase_done.clear()
	_phase_in_progress.clear()
	_phase_dependencies.clear()
	_phase_dependents.clear()
	_phase_total_count = 0
	_phase_completed_count = 0
	_phase_back = Callable()
	set_process(false)


func _process(_delta: float) -> void:
	var execute_count: int = mini(_actions_per_frame, _action_queue.size())
	var index: int = 0
	while index < execute_count:
		var action: Callable = _action_queue.pop_front()
		if action.is_valid():
			action.call()
		index += 1

	if _action_queue.is_empty() and _current_phase_method == StringName():
		set_process(false)


func _start_phase(method_name: StringName, back: Callable) -> void:
	if _current_phase_method != StringName():
		push_warning("ControllerManager 当前已有流程执行中：%s" % String(_current_phase_method))
		_call_back(back)
		return

	if _controllers.is_empty():
		_call_back(back)
		return

	clear_phase_state()
	_current_phase_method = method_name
	_phase_back = back
	_log_lifecycle("phase_start -> %s" % String(method_name))
	_build_phase_graph(method_name)

	if _phase_total_count == 0:
		_finish_phase()
		return

	if _action_queue.is_empty():
		push_error("ControllerManager 检测到循环依赖，无法启动流程：%s" % String(method_name))
		_finish_phase()
		return

	set_process(true)


func _build_phase_graph(method_name: StringName) -> void:
	for controller_id_variant in _controllers.keys():
		var controller_id: StringName = controller_id_variant
		_phase_done[controller_id] = false
		_phase_in_progress[controller_id] = false

		var dependencies: Array[StringName] = _resolve_dependencies(controller_id, method_name)
		_phase_dependencies[controller_id] = dependencies

		if dependencies.is_empty():
			_enqueue_controller_start(controller_id)
			continue

		for dependency_id in dependencies:
			if not _phase_dependents.has(dependency_id):
				_phase_dependents[dependency_id] = []
			var dependent_ids: Array[StringName] = _to_string_name_array(_phase_dependents.get(dependency_id, []))
			dependent_ids.append(controller_id)
			_phase_dependents[dependency_id] = dependent_ids

	_phase_total_count = _controllers.size()


func _enqueue_controller_start(controller_id: StringName) -> void:
	if _phase_done.get(controller_id, false):
		return
	if _phase_in_progress.get(controller_id, false):
		return
	_action_queue.append(func() -> void:
		_start_controller(controller_id)
	)


func _start_controller(controller_id: StringName) -> void:
	var controller: BaseController = _controllers.get(controller_id, null)
	if controller == null:
		_on_controller_done(controller_id)
		return

	_phase_in_progress[controller_id] = true
	_log_lifecycle("phase_call -> %s.%s" % [String(controller_id), String(_current_phase_method)])
	if not controller.has_method(String(_current_phase_method)):
		push_warning(
			"ControllerManager 流程方法缺失：%s.%s"
			% [String(controller_id), String(_current_phase_method)]
		)
		_on_controller_done(controller_id)
		return

	controller.call(String(_current_phase_method))
	_on_controller_done(controller_id)


func _on_controller_done(controller_id: StringName) -> void:
	if not _phase_in_progress.get(controller_id, false) and _phase_done.get(controller_id, false):
		return

	_phase_in_progress[controller_id] = false
	_phase_done[controller_id] = true
	_phase_completed_count += 1
	phase_progress.emit(_current_phase_method, controller_id, _phase_completed_count, _phase_total_count)
	_log_lifecycle(
		"phase_done -> %s (%d/%d)"
		% [String(controller_id), _phase_completed_count, _phase_total_count]
	)

	var dependent_ids: Array[StringName] = _to_string_name_array(_phase_dependents.get(controller_id, []))
	for dependent_id in dependent_ids:
		if _can_start_controller(dependent_id):
			_enqueue_controller_start(dependent_id)

	if _phase_completed_count >= _phase_total_count:
		_finish_phase()


func _finish_phase() -> void:
	var back: Callable = _phase_back
	_log_lifecycle("phase_finish -> %s" % String(_current_phase_method))
	clear_phase_state()
	_call_back(back)


func _can_start_controller(controller_id: StringName) -> bool:
	if _phase_done.get(controller_id, false):
		return false
	if _phase_in_progress.get(controller_id, false):
		return false

	var dependencies: Array[StringName] = _to_string_name_array(_phase_dependencies.get(controller_id, []))
	for dependency_id in dependencies:
		if not _phase_done.get(dependency_id, false):
			return false
	return true


func _resolve_dependencies(controller_id: StringName, method_name: StringName) -> Array[StringName]:
	var dependencies: Array[StringName] = []
	var manual_dependencies: Array[StringName] = _to_string_name_array(_controller_dependencies.get(controller_id, []))
	for dependency_id in manual_dependencies:
		dependencies.append(dependency_id)

	var controller: BaseController = _controllers.get(controller_id, null)
	if controller != null:
		var controller_dependencies: Array[StringName] = []
		if method_name == BaseController.FLOW_SAVE_LOAD:
			controller_dependencies = controller.get_save_load_dependencies()
		elif method_name == BaseController.FLOW_SAVE_UNLOAD:
			controller_dependencies = controller.get_save_unload_dependencies()
		elif method_name == BaseController.FLOW_SAVE_FLUSH:
			controller_dependencies = controller.get_save_flush_dependencies()
		for dependency_id in controller_dependencies:
			dependencies.append(dependency_id)

	return _dedupe_dependencies(dependencies)


func _dedupe_dependencies(dependencies: Array[StringName]) -> Array[StringName]:
	var deduped: Array[StringName] = []
	for dependency_id in dependencies:
		if dependency_id == StringName():
			continue
		if not _controllers.has(dependency_id):
			continue
		if deduped.has(dependency_id):
			continue
		deduped.append(dependency_id)
	return deduped


func _call_back(back: Callable) -> void:
	if back.is_valid():
		back.call()


func _to_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not (value is Array):
		return result
	for item in value as Array:
		result.append(StringName(item))
	return result


func _log_lifecycle(message: String) -> void:
	if not OS.has_feature("debug"):
		return
	print("[ControllerManager][Lifecycle] %s" % message)
