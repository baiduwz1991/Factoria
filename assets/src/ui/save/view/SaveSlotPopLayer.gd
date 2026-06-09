class_name SaveSlotPopLayer
extends BaseUI

#region 配置与常量
@export var title_text: String = "选择存档"
@export var empty_slot_text: String = "空槽位"
const LONG_PRESS_SECONDS: float = 0.45
#endregion

#region 状态
var _save_controller: SaveController = null
var _loading_controller: LoadingController = null
var _slot_buttons: Array[Button] = []
var _slot_meta_map: Dictionary[int, Dictionary] = {}
var _is_processing: bool = false
var _long_press_slot_id: int = 0
var _consume_pressed_slot_id: int = 0
#endregion

#region 节点引用
@export var title_label_path: NodePath
@export var slots_grid_path: NodePath
@export var close_button_path: NodePath
@export var long_press_timer_path: NodePath

@onready var title_label: Label = get_node(title_label_path) as Label
@onready var slots_grid: GridContainer = get_node(slots_grid_path) as GridContainer
@onready var close_button: Button = get_node(close_button_path) as Button
@onready var long_press_timer: Timer = get_node(long_press_timer_path) as Timer
#endregion

#region 生命周期
func on_ui_create(_params: Dictionary) -> void:
	title_label.text = title_text
	close_button.pressed.connect(_on_close_pressed)
	long_press_timer.wait_time = LONG_PRESS_SECONDS
	long_press_timer.timeout.connect(_on_long_press_timeout)
	_collect_slot_buttons()
	_bind_slot_buttons()


func on_ui_open(_params: Dictionary) -> void:
	_is_processing = false
	_long_press_slot_id = 0
	_consume_pressed_slot_id = 0
	_save_controller = _get_save_controller()
	_loading_controller = _get_loading_controller()
	_bind_save_controller_signals()
	_refresh_slot_view()


func on_ui_destroy() -> void:
	_unbind_save_controller_signals()
#endregion

#region 交互与显示
func _on_close_pressed() -> void:
	if _is_processing:
		return
	if _save_controller != null:
		_save_controller.request_close_ui(get_instance_id())


func _on_slot_pressed(slot_id: int) -> void:
	if _is_processing:
		return
	if _consume_pressed_slot_id == slot_id:
		_consume_pressed_slot_id = 0
		return

	var slot_meta: Dictionary = _slot_meta_map.get(slot_id, {})
	var is_existing_slot: bool = bool(slot_meta.get("exists", false))
	if _save_controller == null:
		push_warning("SaveSlotPopLayer 操作失败：SaveController 未就绪。")
		return
	if not is_existing_slot:
		_save_controller.request_open_role_create(get_instance_id(), slot_id)
		return

	_is_processing = true
	if _loading_controller == null:
		push_warning("SaveSlotPopLayer failed to enter planet: LoadingController is missing.")
		_is_processing = false
		return
	var started: bool = _loading_controller.request_enter_planet_from_save(
		get_instance_id(),
		slot_id,
		&"main",
		Callable(self, "_on_enter_planet_completed")
	)
	if started:
		return
	_is_processing = false


func _on_enter_planet_completed(result: Dictionary) -> void:
	_is_processing = false
	if not bool(result.get("ok", false)):
		push_warning("SaveSlotPopLayer 进入游戏失败：%s" % String(result.get("error_code", "")))
		return



func _on_long_press_timeout() -> void:
	if _is_processing:
		return
	var slot_id: int = _long_press_slot_id
	_long_press_slot_id = 0
	if slot_id <= 0:
		return
	var slot_meta: Dictionary = _slot_meta_map.get(slot_id, {})
	if not bool(slot_meta.get("exists", false)):
		return
	_consume_pressed_slot_id = slot_id
	if _save_controller != null:
		_save_controller.request_open_slot_info(slot_id)
#endregion

#region 内部逻辑
func _collect_slot_buttons() -> void:
	_slot_buttons.clear()
	for child in slots_grid.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		_slot_buttons.append(button)


func _bind_slot_buttons() -> void:
	for index in range(_slot_buttons.size()):
		var slot_id: int = index + 1
		var button: Button = _slot_buttons[index]
		button.button_down.connect(_on_slot_button_down.bind(slot_id))
		button.button_up.connect(_on_slot_button_up.bind(slot_id))
		button.pressed.connect(_on_slot_pressed.bind(slot_id))


func _on_slot_button_down(slot_id: int) -> void:
	_long_press_slot_id = slot_id
	long_press_timer.start()


func _on_slot_button_up(slot_id: int) -> void:
	if _long_press_slot_id == slot_id:
		_long_press_slot_id = 0
		if long_press_timer.time_left > 0.0:
			long_press_timer.stop()


func _refresh_slot_view() -> void:
	if _save_controller == null:
		return
	var slot_meta_list: Array[Dictionary] = _save_controller.refresh_slot_meta()
	_apply_slot_meta(slot_meta_list)


func _apply_slot_meta(slot_meta_list: Array[Dictionary]) -> void:
	_slot_meta_map.clear()
	for slot_meta in slot_meta_list:
		var slot_id: int = int(slot_meta.get("slot_id", 0))
		if slot_id <= 0:
			continue
		_slot_meta_map[slot_id] = slot_meta

	for index in range(_slot_buttons.size()):
		var slot_id: int = index + 1
		var button: Button = _slot_buttons[index]
		var slot_meta: Dictionary = _slot_meta_map.get(slot_id, {})
		var exists: bool = bool(slot_meta.get("exists", false))
		var title: String = str(slot_meta.get("title", ""))
		if title == "":
			title = empty_slot_text
		button.text = "槽位%02d\n%s" % [slot_id, title]
		button.disabled = false
		button.tooltip_text = "" if not exists else "玩家：%s" % str(slot_meta.get("player_name", ""))


func _bind_save_controller_signals() -> void:
	if _save_controller == null:
		return
	var callback: Callable = Callable(self, "_on_slot_meta_changed")
	if not _save_controller.is_connected("slot_meta_changed", callback):
		_save_controller.connect("slot_meta_changed", callback)


func _unbind_save_controller_signals() -> void:
	if _save_controller == null:
		return
	var callback: Callable = Callable(self, "_on_slot_meta_changed")
	if _save_controller.is_connected("slot_meta_changed", callback):
		_save_controller.disconnect("slot_meta_changed", callback)


func _on_slot_meta_changed(slot_meta_list: Array[Dictionary]) -> void:
	_apply_slot_meta(slot_meta_list)


func _get_save_controller() -> SaveController:
	return _get_or_register_controller(
		SaveController.CONTROLLER_ID,
		func() -> BaseController:
			return SaveController.new()
	) as SaveController


func _get_loading_controller() -> LoadingController:
	return _get_or_register_controller(
		LoadingController.CONTROLLER_ID,
		func() -> BaseController:
			return LoadingController.new()
	) as LoadingController


#endregion
