class_name GameScene
extends Node2D

var _slot_id: int = 0
var _scene_coordinator: PlanetSceneCoordinator = null
var _map_view: LayeredChunkMapView = null
var _player: Node2D = null
var _initial_loading_finished: bool = false


func get_slot_id() -> int:
	return _slot_id


func get_map_view() -> LayeredChunkMapView:
	return _map_view


func get_player() -> Node2D:
	return _player


func on_scene_enter(params: Dictionary) -> void:
	_slot_id = int(params.get("slot_id", 0))
	var defer_initial_loading: bool = bool(params.get("defer_initial_loading", false))
	_initial_loading_finished = false
	set_process_unhandled_input(not defer_initial_loading)
	_map_view = get_node_or_null("MapRoot") as LayeredChunkMapView
	_player = get_node_or_null("Player") as Node2D
	_set_player_runtime_enabled(not defer_initial_loading)
	_scene_coordinator = PlanetSceneCoordinator.new()
	_scene_coordinator.setup(self, _slot_id, _map_view, _player)
	_scene_coordinator.on_scene_enter(not defer_initial_loading)
	if not defer_initial_loading:
		_initial_loading_finished = true


func finish_initial_loading() -> void:
	if _initial_loading_finished:
		return
	_initial_loading_finished = true
	_set_player_runtime_enabled(true)
	set_process_unhandled_input(true)
	if _scene_coordinator != null:
		_scene_coordinator.finish_initial_loading()


func on_scene_destroy() -> void:
	set_process_unhandled_input(false)
	if _scene_coordinator != null:
		_scene_coordinator.on_scene_destroy()
		_scene_coordinator = null
	_map_view = null
	_player = null


func _unhandled_input(event: InputEvent) -> void:
	if _scene_coordinator == null:
		return
	_scene_coordinator.handle_unhandled_input(event)


func _set_player_runtime_enabled(enabled: bool) -> void:
	if _player == null:
		return
	_player.set_process(enabled)
	_player.set_physics_process(enabled)
	_player.set_process_unhandled_input(enabled)
