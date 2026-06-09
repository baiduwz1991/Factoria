class_name StartGameLayer
extends BaseUI

signal start_game_requested
signal settings_requested
signal exit_requested

#region 配置与常量
@export var title_text: String = "FACTORIA"
@export var subtitle_text: String = "工厂世界启动中"
@export var idle_status_text: String = "请选择一个操作。"
#endregion

#region 状态
var _start_game_controller: StartGameController = null
#endregion

#region 节点引用
@export var title_label_path: NodePath
@export var subtitle_label_path: NodePath
@export var status_label_path: NodePath

@onready var title_label: Label = get_node(title_label_path) as Label
@onready var subtitle_label: Label = get_node(subtitle_label_path) as Label
@onready var status_label: Label = get_node(status_label_path) as Label
#endregion

#region 生命周期
func on_ui_create(_params: Dictionary) -> void:
	_start_game_controller = _get_start_game_controller()


func on_ui_open(params: Dictionary) -> void:
	title_label.text = str(params.get("title", title_text))
	subtitle_label.text = str(params.get("subtitle", subtitle_text))
	_set_status(str(params.get("status", idle_status_text)))
#endregion

#region 交互与显示
func _on_start_button_pressed() -> void:
	start_game_requested.emit()
	if _start_game_controller != null:
		_start_game_controller.request_start_game()
	_set_status("请选择或创建一个存档槽位。")


func _on_settings_button_pressed() -> void:
	settings_requested.emit()
	if _start_game_controller != null:
		_start_game_controller.request_open_settings()
	_set_status("正在打开设置界面。")


func _on_exit_button_pressed() -> void:
	exit_requested.emit()
	if _start_game_controller != null:
		_start_game_controller.request_exit_game()
	_set_status("退出请求已触发。")
#endregion

#region 内部逻辑
func _set_status(message: String) -> void:
	status_label.text = message


func _get_start_game_controller() -> StartGameController:
	return _get_or_register_controller(
		StartGameController.CONTROLLER_ID,
		func() -> BaseController:
			return StartGameController.new()
	) as StartGameController
#endregion
