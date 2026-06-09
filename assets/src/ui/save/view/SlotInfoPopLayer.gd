class_name SlotInfoPopLayer
extends BaseUI

#region 配置与常量
@export var title_text: String = "槽位详情"
#endregion

#region 状态
var _slot_id: int = 0
var _save_controller: SaveController = null
var _loading_controller: LoadingController = null
var _is_processing: bool = false
#endregion

#region 节点引用
@export var title_label_path: NodePath
@export var latest_entry_button_path: NodePath
@export var backup_hint_label_path: NodePath
@export var backup_1_button_path: NodePath
@export var backup_2_button_path: NodePath
@export var backup_3_button_path: NodePath
@export var close_button_path: NodePath
@export var delete_button_path: NodePath

@onready var title_label: Label = get_node(title_label_path) as Label
@onready var latest_entry_button: Button = get_node(latest_entry_button_path) as Button
@onready var backup_hint_label: Label = get_node(backup_hint_label_path) as Label
@onready var backup_1_button: Button = get_node(backup_1_button_path) as Button
@onready var backup_2_button: Button = get_node(backup_2_button_path) as Button
@onready var backup_3_button: Button = get_node(backup_3_button_path) as Button
@onready var close_button: Button = get_node(close_button_path) as Button
@onready var delete_button: Button = get_node(delete_button_path) as Button
#endregion

#region 生命周期
func on_ui_create(_params: Dictionary) -> void:
	title_label.text = title_text
	backup_hint_label.text = "备份存档"
	latest_entry_button.pressed.connect(_on_latest_pressed)
	backup_1_button.pressed.connect(_on_backup_1_pressed)
	backup_2_button.pressed.connect(_on_backup_2_pressed)
	backup_3_button.pressed.connect(_on_backup_3_pressed)
	close_button.pressed.connect(_on_close_pressed)
	delete_button.pressed.connect(_on_delete_pressed)


func on_ui_open(params: Dictionary) -> void:
	_slot_id = int(params.get("slot_id", 0))
	_is_processing = false
	_save_controller = _get_save_controller()
	_loading_controller = _get_loading_controller()
	_refresh_view()
	_set_interactable(true)


func on_ui_destroy() -> void:
	pass
#endregion

#region 交互与显示
func _on_latest_pressed() -> void:
	_request_load_by_source(&"main")


func _on_backup_1_pressed() -> void:
	_request_load_by_source(&"backup")


func _on_backup_2_pressed() -> void:
	_request_load_by_source(&"backup_2")


func _on_backup_3_pressed() -> void:
	_request_load_by_source(&"backup_3")


func _request_load_by_source(source: StringName) -> void:
	if _is_processing:
		return
	if _slot_id <= 0 or _save_controller == null:
		return
	_is_processing = true
	_set_interactable(false)
	if _loading_controller == null:
		push_warning("SlotInfoPopLayer failed to enter planet: LoadingController is missing.")
		_is_processing = false
		_set_interactable(true)
		return
	var started: bool = _loading_controller.request_enter_planet_from_save(
		get_instance_id(),
		_slot_id,
		source,
		Callable(self, "_on_enter_planet_completed")
	)
	if started:
		return
	_is_processing = false
	_set_interactable(true)


func _on_enter_planet_completed(result: Dictionary) -> void:
	_is_processing = false
	_set_interactable(true)
	if not bool(result.get("ok", false)):
		push_warning("SlotInfoPopLayer 进入游戏失败：%s" % String(result.get("error_code", "")))
		return


func _on_close_pressed() -> void:
	if _is_processing:
		return
	if _save_controller != null:
		_save_controller.request_close_ui(get_instance_id())


func _on_delete_pressed() -> void:
	if _is_processing:
		return
	if _slot_id <= 0 or _save_controller == null:
		return
	_is_processing = true
	_set_interactable(false)
	_save_controller.request_delete_slot(_slot_id, Callable(self, "_on_delete_completed"))


func _on_delete_completed(result: Dictionary) -> void:
	_is_processing = false
	_set_interactable(true)
	if not bool(result.get("ok", false)):
		push_warning("SlotInfoPopLayer 删除失败：%s" % String(result.get("error_code", "")))
		return
	if _save_controller != null:
		_save_controller.request_close_ui(get_instance_id())
#endregion

#region 内部逻辑
func _refresh_view() -> void:
	title_label.text = "槽位%02d %s" % [_slot_id, title_text]
	_apply_latest_button()
	var backups: Array[Dictionary] = []
	if _save_controller != null and _slot_id > 0:
		backups = _save_controller.get_slot_backups(_slot_id)
	_apply_backup_button(backup_1_button, backups, 1)
	_apply_backup_button(backup_2_button, backups, 2)
	_apply_backup_button(backup_3_button, backups, 3)
	backup_hint_label.visible = (
		backup_1_button.visible
		or backup_2_button.visible
		or backup_3_button.visible
	)


func _apply_latest_button() -> void:
	if _save_controller == null:
		latest_entry_button.text = "最新存档\n无"
		latest_entry_button.disabled = true
		return
	var slot_meta_list: Array[Dictionary] = _save_controller.refresh_slot_meta()
	for slot_meta in slot_meta_list:
		if int(slot_meta.get("slot_id", 0)) != _slot_id:
			continue
		var updated_unix: int = int(slot_meta.get("updated_at_unix", 0))
		if updated_unix <= 0:
			latest_entry_button.text = "最新存档\n无"
			latest_entry_button.disabled = true
			return
		latest_entry_button.text = "最新存档\n%s" % _format_unix_time(updated_unix)
		latest_entry_button.disabled = false
		return
	latest_entry_button.text = "最新存档\n无"
	latest_entry_button.disabled = true


func _apply_backup_button(button: Button, backups: Array[Dictionary], backup_index: int) -> void:
	for entry in backups:
		if int(entry.get("backup_index", 0)) != backup_index:
			continue
		var updated_unix: int = int(entry.get("updated_at_unix", 0))
		button.text = "备份%d\n%s" % [backup_index, _format_unix_time(updated_unix)]
		button.visible = true
		button.disabled = false
		return
	button.visible = false
	button.disabled = true


func _format_unix_time(unix_time: int) -> String:
	if unix_time <= 0:
		return "无"
	return Time.get_datetime_string_from_unix_time(unix_time, true)


func _set_interactable(enabled: bool) -> void:
	latest_entry_button.disabled = not enabled or latest_entry_button.text.ends_with("\n无")
	backup_1_button.disabled = (not backup_1_button.visible) or (not enabled)
	backup_2_button.disabled = (not backup_2_button.visible) or (not enabled)
	backup_3_button.disabled = (not backup_3_button.visible) or (not enabled)
	close_button.disabled = not enabled
	delete_button.disabled = not enabled


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
