class_name PlanetSceneCoordinator
extends RefCounted

const AUTOSAVE_INTERVAL_HOURS: float = 12.0

var _scene: Node2D = null
var _slot_id: int = 0
var _map_view: LayeredChunkMapView = null
var _player: Node2D = null
var _planet_hud: PlanetHudOverlayLayer = null
var _planet_hud_instance_id: int = -1
var _system_menu: PlanetSystemMenuPopLayer = null
var _system_menu_instance_id: int = -1
var _initial_loading_finished: bool = false
var _save_controller: SaveController = null
var _world_time_controller: WorldTimeController = null
var _autosave_anchor_total_hours: float = -1.0
var _save_in_progress: bool = false


func setup(scene: Node2D, slot_id: int, map_view: LayeredChunkMapView, player: Node2D) -> void:
	_scene = scene
	_slot_id = slot_id
	_map_view = map_view
	_player = player


func on_scene_enter(finish_immediately: bool = true) -> void:
	_initial_loading_finished = false
	_setup_planet_map()
	if finish_immediately:
		finish_initial_loading()


func finish_initial_loading() -> void:
	if _initial_loading_finished:
		return
	_initial_loading_finished = true
	_record_first_enter_planet_achievement()
	_open_planet_hud()
	_start_autosave_clock()


func on_scene_destroy() -> void:
	_close_system_menu()
	_stop_autosave_clock()
	_unbind_player_controller()
	_close_planet_hud()
	_scene = null
	_map_view = null
	_player = null
	_initial_loading_finished = false


func handle_unhandled_input(event: InputEvent) -> void:
	if _scene == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_system_menu()
		var viewport: Viewport = _scene.get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func _setup_planet_map() -> void:
	if _map_view == null or _player == null:
		return
	var planet_controller: PlanetController = ControllerManager.get_controller(PlanetController.CONTROLLER_ID) as PlanetController
	if planet_controller == null:
		return
	var player_controller: PlayerController = _get_player_controller()
	var preferred_position: Vector2 = _player.global_position
	if player_controller != null:
		player_controller.prepare_save_slot(_slot_id)
		preferred_position = player_controller.get_preferred_position(preferred_position)
	_player.global_position = planet_controller.resolve_safe_spawn_position(preferred_position)
	if player_controller != null:
		player_controller.bind_player(_player)
	_map_view.setup(planet_controller, _player)


func _open_planet_hud() -> void:
	if _planet_hud_instance_id >= 0:
		return
	var planet_hud: PlanetHudOverlayLayer = UIManager.open_overlay(UIRegistry.PLANET_HUD_OVERLAY_LAYER, {
		"slot_id": _slot_id
	}) as PlanetHudOverlayLayer
	if planet_hud == null:
		return
	_planet_hud = planet_hud
	_planet_hud_instance_id = planet_hud.get_instance_id()


func _close_planet_hud() -> void:
	if _planet_hud_instance_id < 0:
		return
	UIManager.close_ui(_planet_hud_instance_id)
	_planet_hud = null
	_planet_hud_instance_id = -1


func _toggle_system_menu() -> void:
	if _system_menu_instance_id >= 0:
		_close_system_menu()
		return
	_open_system_menu()


func _open_system_menu() -> void:
	if _system_menu_instance_id >= 0:
		return
	var system_menu: PlanetSystemMenuPopLayer = UIManager.open_overlay(
		UIRegistry.PLANET_SYSTEM_MENU_POP_LAYER,
		{"slot_id": _slot_id}
	) as PlanetSystemMenuPopLayer
	if system_menu == null:
		return
	_system_menu = system_menu
	_system_menu_instance_id = system_menu.get_instance_id()
	system_menu.close_requested.connect(_on_system_menu_close_requested)
	system_menu.return_main_menu_requested.connect(_on_return_main_menu_requested)
	system_menu.save_requested.connect(_on_save_requested)
	system_menu.debug_requested.connect(_on_debug_requested)


func _close_system_menu() -> void:
	if _system_menu_instance_id < 0:
		return
	UIManager.close_ui(_system_menu_instance_id)
	_system_menu = null
	_system_menu_instance_id = -1


func _on_system_menu_close_requested() -> void:
	_close_system_menu()


func _on_return_main_menu_requested() -> void:
	_close_system_menu()
	UIManager.set_ui_root_visible(true)
	UIManager.set_main_layer_visible(true)
	SceneManager.close_current_scene()


func _on_debug_requested() -> void:
	_close_system_menu()
	UIManager.open_overlay(UIRegistry.DEBUG_POP_LAYER)


func _on_save_requested() -> void:
	_request_save(&"manual")


func _request_save(source: StringName) -> bool:
	if _slot_id <= 0:
		_push_system_info("存档失败：槽位无效")
		return false
	if _save_in_progress:
		if source == &"manual":
			_push_system_info("正在保存中...")
		return false

	var save_controller: SaveController = _get_save_controller()
	if save_controller == null:
		_push_system_info(_format_save_failed_message(source, &"save_controller_missing"))
		return false

	_save_in_progress = true
	_set_system_menu_save_busy(true)
	if source == &"manual":
		_push_system_info("正在保存存档...")

	var started: bool = save_controller.request_save_slot(
		_slot_id,
		Callable(self, "_on_save_completed").bind(source),
		{"show_loading_overlay": false}
	)
	if not started and _save_in_progress:
		_save_in_progress = false
		_set_system_menu_save_busy(false)
		_push_system_info(_format_save_failed_message(source, &"save_not_started"))
	return started


func _on_save_completed(result: Dictionary, source: StringName) -> void:
	_save_in_progress = false
	_set_system_menu_save_busy(false)
	if bool(result.get("ok", false)):
		_refresh_autosave_anchor()
		_push_system_info(_format_save_success_message(source))
		return
	_push_system_info(_format_save_failed_message(source, StringName(result.get("error_code", ""))))


func _start_autosave_clock() -> void:
	_world_time_controller = _get_world_time_controller()
	if _world_time_controller == null:
		return
	_refresh_autosave_anchor()
	var changed_callable: Callable = Callable(self, "_on_world_time_changed")
	if not _world_time_controller.is_connected("world_time_changed", changed_callable):
		_world_time_controller.connect("world_time_changed", changed_callable)


func _stop_autosave_clock() -> void:
	if _world_time_controller == null:
		return
	var changed_callable: Callable = Callable(self, "_on_world_time_changed")
	if _world_time_controller.is_connected("world_time_changed", changed_callable):
		_world_time_controller.disconnect("world_time_changed", changed_callable)
	_world_time_controller = null
	_autosave_anchor_total_hours = -1.0


func _on_world_time_changed(snapshot: Dictionary) -> void:
	if _autosave_anchor_total_hours < 0.0:
		_autosave_anchor_total_hours = _world_time_total_hours(snapshot)
		return
	var current_total_hours: float = _world_time_total_hours(snapshot)
	if current_total_hours < _autosave_anchor_total_hours:
		_autosave_anchor_total_hours = current_total_hours
		return
	if current_total_hours - _autosave_anchor_total_hours < AUTOSAVE_INTERVAL_HOURS:
		return
	if _save_in_progress:
		return
	_autosave_anchor_total_hours = current_total_hours
	_request_save(&"auto")


func _world_time_total_hours(snapshot: Dictionary) -> float:
	var day_index: int = maxi(int(snapshot.get("day_index", 1)), 1)
	var time_of_day: float = clampf(float(snapshot.get("time_of_day", 0.0)), 0.0, WorldTimeModel.HOURS_PER_DAY)
	return float(day_index - 1) * WorldTimeModel.HOURS_PER_DAY + time_of_day


func _refresh_autosave_anchor() -> void:
	var world_time_controller: WorldTimeController = _get_world_time_controller()
	if world_time_controller == null:
		return
	_autosave_anchor_total_hours = _world_time_total_hours(world_time_controller.get_runtime_snapshot())


func _get_save_controller() -> SaveController:
	if _save_controller != null:
		return _save_controller
	var existing: SaveController = ControllerManager.get_controller(SaveController.CONTROLLER_ID) as SaveController
	if existing != null:
		_save_controller = existing
		return existing
	_save_controller = ControllerManager.get_or_register_controller(
		SaveController.CONTROLLER_ID,
		func() -> BaseController:
			return SaveController.new()
	) as SaveController
	return _save_controller


func _get_world_time_controller() -> WorldTimeController:
	var existing: WorldTimeController = ControllerManager.get_controller(WorldTimeController.CONTROLLER_ID) as WorldTimeController
	if existing != null:
		return existing
	return ControllerManager.get_or_register_controller(
		WorldTimeController.CONTROLLER_ID,
		func() -> BaseController:
			return WorldTimeController.new()
	) as WorldTimeController


func _get_player_controller() -> PlayerController:
	var existing: PlayerController = ControllerManager.get_controller(PlayerController.CONTROLLER_ID) as PlayerController
	if existing != null:
		return existing
	return ControllerManager.get_or_register_controller(
		PlayerController.CONTROLLER_ID,
		func() -> BaseController:
			return PlayerController.new()
	) as PlayerController


func _unbind_player_controller() -> void:
	var player_controller: PlayerController = ControllerManager.get_controller(PlayerController.CONTROLLER_ID) as PlayerController
	if player_controller == null:
		return
	player_controller.unbind_player(_player)


func _set_system_menu_save_busy(is_busy: bool) -> void:
	if not is_instance_valid(_system_menu):
		return
	_system_menu.set_save_busy(is_busy)


func _push_system_info(message: String) -> void:
	if not is_instance_valid(_planet_hud):
		return
	_planet_hud.push_system_message(message)


func _format_save_success_message(source: StringName) -> String:
	var prefix: String = "自动存档" if source == &"auto" else "存档"
	return "%s成功：%s" % [prefix, _format_current_world_time()]


func _format_save_failed_message(source: StringName, error_code: StringName) -> String:
	var prefix: String = "自动存档" if source == &"auto" else "存档"
	var error_text: String = String(error_code)
	if error_text == "":
		error_text = "unknown"
	return "%s失败：%s" % [prefix, error_text]


func _format_current_world_time() -> String:
	var world_time_controller: WorldTimeController = _get_world_time_controller()
	if world_time_controller == null:
		return "--"
	return str(world_time_controller.get_runtime_snapshot().get("time_label", "--"))


func _record_first_enter_planet_achievement() -> void:
	var achievement_controller: AchievementController = ControllerManager.get_controller(AchievementController.CONTROLLER_ID) as AchievementController
	if achievement_controller == null:
		push_warning("PlanetSceneCoordinator missing AchievementController during first-enter record.")
		return
	achievement_controller.record_first_enter_planet(_slot_id)
