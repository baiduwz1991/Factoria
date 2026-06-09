class_name PlanetSceneCoordinator
extends RefCounted

var _scene: Node2D = null
var _slot_id: int = 0
var _map_view: LayeredChunkMapView = null
var _player: Node2D = null
var _planet_hud_instance_id: int = -1
var _system_menu_instance_id: int = -1
var _initial_loading_finished: bool = false


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


func on_scene_destroy() -> void:
	_close_system_menu()
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
	_player.global_position = planet_controller.resolve_safe_spawn_position(_player.global_position)
	_map_view.setup(planet_controller, _player)


func _open_planet_hud() -> void:
	if _planet_hud_instance_id >= 0:
		return
	var planet_hud: BaseUI = UIManager.open_overlay(UIRegistry.PLANET_HUD_OVERLAY_LAYER, {
		"slot_id": _slot_id
	})
	if planet_hud == null:
		return
	_planet_hud_instance_id = planet_hud.get_instance_id()


func _close_planet_hud() -> void:
	if _planet_hud_instance_id < 0:
		return
	UIManager.close_ui(_planet_hud_instance_id)
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
	_system_menu_instance_id = system_menu.get_instance_id()
	system_menu.close_requested.connect(_on_system_menu_close_requested)
	system_menu.return_main_menu_requested.connect(_on_return_main_menu_requested)
	system_menu.debug_requested.connect(_on_debug_requested)


func _close_system_menu() -> void:
	if _system_menu_instance_id < 0:
		return
	UIManager.close_ui(_system_menu_instance_id)
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


func _record_first_enter_planet_achievement() -> void:
	var achievement_controller: AchievementController = ControllerManager.get_controller(AchievementController.CONTROLLER_ID) as AchievementController
	if achievement_controller == null:
		push_warning("PlanetSceneCoordinator missing AchievementController during first-enter record.")
		return
	achievement_controller.record_first_enter_planet(_slot_id)
