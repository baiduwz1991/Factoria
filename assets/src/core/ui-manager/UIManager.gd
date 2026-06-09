extends Node

const MODE_REPLACE: StringName = &"replace"
const MODE_OVERLAY: StringName = &"overlay"
const MODE_ATTACH: StringName = &"attach"

const UI_ROOT_SCENE: PackedScene = preload("res://assets/src/core/ui-manager/UIRoot.tscn")

var _ui_root: CanvasLayer = null
var _root_control: Control = null
var _main_layer: Control = null
var _overlay_layer: Control = null

@export var root_ui_id: StringName = UIRegistry.START_GAME_LAYER

var _ui_stack: Array[BaseUI] = []
var _overlay_stack: Array[BaseUI] = []
var _attach_map: Dictionary[StringName, BaseUI] = {}
var _ui_instance_index: Dictionary[int, BaseUI] = {}


func _ready() -> void:
	_ensure_ui_root()


func open_ui(
	ui_id: StringName,
	params: Dictionary = {},
	mode: StringName = MODE_REPLACE
) -> BaseUI:
	match mode:
		MODE_REPLACE:
			return _open_replace(ui_id, params)
		MODE_OVERLAY:
			return open_overlay(ui_id, params)
		_:
			push_warning("UIManager.open_ui 暂不支持 mode=%s，请用 open_attach。" % String(mode))
			return null


func close_ui(ui_instance_id: int = -1) -> void:
	if ui_instance_id < 0:
		if not _overlay_stack.is_empty():
			close_top_overlay()
			return
		_close_top_ui()
		return

	var ui: BaseUI = _ui_instance_index.get(ui_instance_id, null)
	if ui == null:
		return

	if _overlay_stack.has(ui):
		_remove_ui_refs(ui)
		_close_ui_instance(ui)
		_restore_current_top_ui()
		return

	var ui_index: int = _ui_stack.find(ui)
	if ui_index < 0:
		return
	_close_ui_at_index(ui_index)


func open_overlay(ui_id: StringName, params: Dictionary = {}) -> BaseUI:
	_ensure_ui_root()
	var ui: BaseUI = _instantiate_ui(ui_id)
	if ui == null:
		return null

	_overlay_layer.add_child(ui)
	_index_ui(ui)
	_overlay_stack.append(ui)
	_log_ui("open_overlay -> %s" % String(ui_id))
	_dispatch_open(ui, params, MODE_OVERLAY, StringName(), StringName())
	return ui


func open_attach(
	parent_ui_id: StringName,
	slot_id: StringName,
	ui_id: StringName,
	params: Dictionary = {}
) -> BaseUI:
	_ensure_ui_root()
	var parent_ui: BaseUI = _find_ui_by_ui_id(parent_ui_id)
	if parent_ui == null:
		push_error("UIManager.open_attach 失败：未找到父 UI %s" % String(parent_ui_id))
		return null

	var slot_node: Node = parent_ui.get_attach_slot_node(slot_id)
	if slot_node == null:
		push_error("UIManager.open_attach 失败：slot 无效 %s" % String(slot_id))
		return null

	var attach_key: StringName = _build_attach_key(parent_ui_id, slot_id)
	var old_attach: BaseUI = _attach_map.get(attach_key, null)
	if old_attach != null:
		_remove_ui_refs(old_attach)
		_close_ui_instance(old_attach)
		_attach_map.erase(attach_key)

	var new_attach: BaseUI = _instantiate_ui(ui_id)
	if new_attach == null:
		return null

	slot_node.add_child(new_attach)
	_index_ui(new_attach)
	_attach_map[attach_key] = new_attach
	_log_ui("open_attach -> parent=%s slot=%s ui=%s" % [String(parent_ui_id), String(slot_id), String(ui_id)])
	_dispatch_open(new_attach, params, MODE_ATTACH, parent_ui_id, slot_id)
	return new_attach


func switch_attach(
	parent_ui_id: StringName,
	slot_id: StringName,
	ui_id: StringName,
	params: Dictionary = {}
) -> BaseUI:
	return open_attach(parent_ui_id, slot_id, ui_id, params)


func close_top_overlay() -> void:
	if _overlay_stack.is_empty():
		return
	var top_overlay: BaseUI = _overlay_stack.pop_back()
	_remove_ui_refs(top_overlay)
	_close_ui_instance(top_overlay)
	_log_ui("close_top_overlay -> %s" % String(top_overlay.ui_id))


func close_all_overlays() -> void:
	while not _overlay_stack.is_empty():
		close_top_overlay()


func close_all_overlays_except(keep_ui_instance_id: int) -> void:
	var overlays_to_close: Array[BaseUI] = []
	for index in range(_overlay_stack.size() - 1, -1, -1):
		var overlay: BaseUI = _overlay_stack[index]
		if overlay == null:
			continue
		if overlay.get_instance_id() == keep_ui_instance_id:
			continue
		overlays_to_close.append(overlay)

	for overlay in overlays_to_close:
		if not is_instance_valid(overlay):
			continue
		_remove_ui_refs(overlay)
		_close_ui_instance(overlay)
		_log_ui("close_overlay_except -> %s" % String(overlay.ui_id))

	_restore_current_top_ui()


func close_attach(parent_ui_id: StringName, slot_id: StringName) -> void:
	var attach_key: StringName = _build_attach_key(parent_ui_id, slot_id)
	var attach_ui: BaseUI = _attach_map.get(attach_key, null)
	if attach_ui == null:
		return
	_attach_map.erase(attach_key)
	_remove_ui_refs(attach_ui)
	_close_ui_instance(attach_ui)
	_log_ui("close_attach -> parent=%s slot=%s" % [String(parent_ui_id), String(slot_id)])


func set_ui_root_visible(is_visible: bool) -> void:
	_ensure_ui_root()
	if _root_control == null:
		return
	_root_control.visible = is_visible
	_log_ui("set_ui_root_visible -> %s" % str(is_visible))


func set_main_layer_visible(is_visible: bool) -> void:
	_ensure_ui_root()
	if _main_layer == null:
		return
	_main_layer.visible = is_visible
	_log_ui("set_main_layer_visible -> %s" % str(is_visible))


func _open_replace(ui_id: StringName, params: Dictionary) -> BaseUI:
	_ensure_ui_root()

	while not _overlay_stack.is_empty():
		close_top_overlay()

	var current_top: BaseUI = _get_current_top_ui()
	if current_top != null and current_top.ui_id == ui_id:
		_log_ui("open_replace_reopen -> %s" % String(ui_id))
		_dispatch_open(current_top, params, MODE_REPLACE, StringName(), StringName())
		return current_top

	if current_top != null:
		current_top._ui_dispatch_hide()

	var ui: BaseUI = _instantiate_ui(ui_id)
	if ui == null:
		return null

	_ui_stack.append(ui)
	_index_ui(ui)
	_main_layer.add_child(ui)
	_log_ui("open_replace_push -> %s (depth=%d)" % [String(ui_id), _ui_stack.size()])
	_dispatch_open(ui, params, MODE_REPLACE, StringName(), StringName())
	return ui


func _ensure_ui_root() -> void:
	if is_instance_valid(_ui_root):
		return

	var root_instance: Node = UI_ROOT_SCENE.instantiate()
	_ui_root = root_instance as CanvasLayer
	if _ui_root == null:
		push_error("UIManager 初始化失败：UIRoot 不是 CanvasLayer。")
		return
	add_child(_ui_root)

	_root_control = _ui_root.get_node_or_null("RootControl") as Control
	if _root_control == null:
		push_error("UIManager 初始化失败：UIRoot 缺少 RootControl。")
		return

	_main_layer = _root_control.get_node_or_null("MainLayer") as Control
	_overlay_layer = _root_control.get_node_or_null("OverlayLayer") as Control
	if _main_layer == null or _overlay_layer == null:
		push_error("UIManager 初始化失败：UIRoot 缺少 MainLayer 或 OverlayLayer。")


func _instantiate_ui(ui_id: StringName) -> BaseUI:
	if not UIRegistry.has_ui(ui_id):
		push_error("UIManager 未注册 ui_id：%s" % String(ui_id))
		return null

	var scene_path: String = UIRegistry.get_scene_path(ui_id)
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("UIManager 加载场景失败：%s" % scene_path)
		return null

	var ui_node: Node = packed_scene.instantiate()
	var ui: BaseUI = ui_node as BaseUI
	if ui == null:
		push_error("UIManager 实例化失败：%s 未继承 BaseUI。" % scene_path)
		if is_instance_valid(ui_node):
			ui_node.queue_free()
		return null

	ui.ui_id = ui_id
	return ui


func _dispatch_open(
	ui: BaseUI,
	params: Dictionary,
	mode: StringName,
	parent_ui_id: StringName,
	slot_id: StringName
) -> void:
	if not is_instance_valid(ui):
		return
	if ui.is_node_ready():
		ui._ui_dispatch_open(params, mode, parent_ui_id, slot_id)
		return
	ui.call_deferred("_ui_dispatch_open", params, mode, parent_ui_id, slot_id)


func _close_ui_instance(ui: BaseUI) -> void:
	if not is_instance_valid(ui):
		return
	ui._ui_dispatch_hide()
	ui._ui_dispatch_close()
	ui._ui_dispatch_destroy()
	ui.queue_free()


func _close_attach_group(parent_ui_id: StringName) -> void:
	var prefix: String = "%s:" % String(parent_ui_id)
	var keys_to_close: Array[StringName] = []
	for key in _attach_map.keys():
		var key_string: String = String(key)
		if key_string.begins_with(prefix):
			keys_to_close.append(key)

	for key in keys_to_close:
		var ui: BaseUI = _attach_map.get(key, null)
		_attach_map.erase(key)
		_remove_ui_refs(ui)
		_close_ui_instance(ui)


func _remove_ui_refs(ui: BaseUI) -> void:
	if ui == null:
		return

	var instance_id: int = ui.get_instance_id()
	_ui_instance_index.erase(instance_id)

	var ui_index: int = _ui_stack.find(ui)
	if ui_index >= 0:
		_ui_stack.remove_at(ui_index)

	var overlay_index: int = _overlay_stack.find(ui)
	if overlay_index >= 0:
		_overlay_stack.remove_at(overlay_index)

	var attach_keys_to_remove: Array[StringName] = []
	for attach_key in _attach_map.keys():
		if _attach_map.get(attach_key, null) == ui:
			attach_keys_to_remove.append(attach_key)
	for attach_key in attach_keys_to_remove:
		_attach_map.erase(attach_key)


func _index_ui(ui: BaseUI) -> void:
	if ui == null:
		return
	_ui_instance_index[ui.get_instance_id()] = ui


func _get_current_top_ui() -> BaseUI:
	if not _overlay_stack.is_empty():
		return _overlay_stack[_overlay_stack.size() - 1]
	if not _ui_stack.is_empty():
		return _ui_stack[_ui_stack.size() - 1]
	return null


func _find_ui_by_ui_id(ui_id: StringName) -> BaseUI:
	var overlay_index: int = _overlay_stack.size() - 1
	while overlay_index >= 0:
		var overlay: BaseUI = _overlay_stack[overlay_index]
		if overlay.ui_id == ui_id:
			return overlay
		overlay_index -= 1

	var ui_index: int = _ui_stack.size() - 1
	while ui_index >= 0:
		var ui: BaseUI = _ui_stack[ui_index]
		if ui.ui_id == ui_id:
			return ui
		ui_index -= 1

	for attach in _attach_map.values():
		if attach.ui_id == ui_id:
			return attach

	return null


func _build_attach_key(parent_ui_id: StringName, slot_id: StringName) -> StringName:
	return StringName("%s:%s" % [String(parent_ui_id), String(slot_id)])


func _close_top_ui() -> void:
	if _ui_stack.is_empty():
		return
	_close_ui_at_index(_ui_stack.size() - 1)


func _close_ui_at_index(index: int) -> void:
	if index < 0 or index >= _ui_stack.size():
		return
	var ui: BaseUI = _ui_stack[index]
	var is_stack_bottom: bool = index == 0
	if is_stack_bottom and ui.ui_id == root_ui_id:
		_log_ui("close_ui_blocked_root -> %s" % String(root_ui_id), true)
		return

	_close_attach_group(ui.ui_id)
	_remove_ui_refs(ui)
	_close_ui_instance(ui)
	_log_ui("close_ui -> %s (remaining=%d)" % [String(ui.ui_id), _ui_stack.size()])
	_restore_current_top_ui()


func _restore_current_top_ui() -> void:
	var current_top: BaseUI = _get_current_top_ui()
	if current_top == null:
		_log_ui("restore_skipped -> no ui")
		return
	current_top._ui_dispatch_show()
	_log_ui("restore_top -> %s" % String(current_top.ui_id))


func _log_ui(message: String, is_warning: bool = false) -> void:
	if not OS.has_feature("debug"):
		return
	if is_warning:
		push_warning("[UIManager] %s" % message)
		return
	print("[UIManager] %s" % message)
