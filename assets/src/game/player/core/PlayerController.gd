class_name PlayerController
extends BaseController

const CONTROLLER_ID: StringName = &"player_controller"

signal player_state_changed(snapshot: Dictionary)

var _save_data: PlayerSaveData = PlayerSaveData.new()
var _current_slot_id: int = 0
var _player: Node2D = null


func get_id() -> StringName:
	return CONTROLLER_ID


func get_save_scope() -> StringName:
	return SAVE_SCOPE_SLOT


func get_save_module_version() -> int:
	return 1


func prepare_save_slot(slot_id: int) -> void:
	if slot_id <= 0:
		return
	if _current_slot_id == slot_id:
		return
	_current_slot_id = slot_id
	_player = null
	_save_data.clear()
	_save_data.apply_slot(slot_id)
	_emit_changed()


func bind_player(player: Node2D) -> void:
	_player = player
	if _player == null:
		return
	_apply_facing_to_player()
	_capture_player_state()
	_emit_changed()


func unbind_player(player: Node2D = null) -> void:
	if player != null and player != _player:
		return
	_player = null


func has_saved_position() -> bool:
	return _save_data.has_position


func get_preferred_position(fallback: Vector2) -> Vector2:
	if _save_data.has_position:
		return _save_data.position
	return fallback


func get_runtime_snapshot() -> Dictionary:
	return {
		"slot_id": _current_slot_id,
		"has_position": _save_data.has_position,
		"position": SerializeUtils.vector2_to_dict(_save_data.position),
		"facing": String(_save_data.facing)
	}


func on_save_flush() -> void:
	_capture_player_state()


func on_save_unload() -> void:
	_player = null


func export_save_data() -> Dictionary:
	_capture_player_state()
	if not _save_data.has_position:
		return {}
	return _save_data.to_dict()


func import_save_data(payload: Dictionary) -> bool:
	if payload.is_empty():
		_save_data.clear()
		_save_data.apply_slot(_current_slot_id)
		_emit_changed()
		return true
	_save_data.from_dict(payload)
	if _save_data.slot_id > 0:
		_current_slot_id = _save_data.slot_id
	elif _current_slot_id > 0:
		_save_data.apply_slot(_current_slot_id)
	_emit_changed()
	return true


func get_save_meta_fragment() -> Dictionary:
	if not _save_data.has_position:
		return {}
	return {
		"player_position": SerializeUtils.vector2_to_dict(_save_data.position),
		"player_facing": String(_save_data.facing)
	}


func _capture_player_state() -> void:
	var player: Node2D = _get_live_player()
	if player == null:
		return
	var facing: StringName = _save_data.facing
	if player.has_method("get_facing"):
		facing = StringName(player.call("get_facing"))
	_save_data.apply_player_state(_current_slot_id, player.global_position, facing)


func _apply_facing_to_player() -> void:
	if _player == null:
		return
	if not _player.has_method("set_facing"):
		return
	_player.call("set_facing", _save_data.facing)


func _get_live_player() -> Node2D:
	var current_scene: Node = _get_current_scene()
	if current_scene == null:
		_player = null
		return null
	if current_scene.has_method("get_slot_id") and int(current_scene.call("get_slot_id")) != _current_slot_id:
		_player = null
		return null
	if is_instance_valid(_player) and _player.is_inside_tree():
		return _player
	if current_scene.has_method("get_player"):
		_player = current_scene.call("get_player") as Node2D
		if _player != null:
			return _player
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return null
	_player = scene_tree.get_first_node_in_group(&"player") as Node2D
	return _player


func _get_current_scene() -> Node:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null or scene_tree.root == null:
		return null
	var scene_manager: Node = scene_tree.root.get_node_or_null("SceneManager")
	if scene_manager == null or not scene_manager.has_method("get_current_scene"):
		return null
	return scene_manager.call("get_current_scene") as Node


func _emit_changed() -> void:
	player_state_changed.emit(get_runtime_snapshot())
