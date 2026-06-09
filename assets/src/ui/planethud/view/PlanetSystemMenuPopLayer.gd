class_name PlanetSystemMenuPopLayer
extends BaseUI

#region 信号
signal close_requested
signal return_main_menu_requested
signal save_requested
signal reload_requested
signal debug_requested
#endregion

#region 节点引用
@export var close_button_path: NodePath
@export var return_main_menu_button_path: NodePath
@export var save_button_path: NodePath
@export var reload_button_path: NodePath
@export var debug_button_path: NodePath

@onready var close_button: Button = get_node(close_button_path) as Button
@onready var return_main_menu_button: Button = get_node(return_main_menu_button_path) as Button
@onready var save_button: Button = get_node(save_button_path) as Button
@onready var reload_button: Button = get_node(reload_button_path) as Button
@onready var debug_button: Button = get_node(debug_button_path) as Button
#endregion

#region 生命周期
func on_ui_create(_params: Dictionary) -> void:
	close_button.pressed.connect(_on_close_pressed)
	return_main_menu_button.pressed.connect(_on_return_main_menu_pressed)
	save_button.pressed.connect(_on_save_pressed)
	reload_button.pressed.connect(_on_reload_pressed)
	debug_button.pressed.connect(_on_debug_pressed)


func on_ui_open(_params: Dictionary) -> void:
	save_button.disabled = true
	reload_button.disabled = true
#endregion

#region 交互与显示
func _on_close_pressed() -> void:
	close_requested.emit()


func _on_return_main_menu_pressed() -> void:
	return_main_menu_requested.emit()


func _on_save_pressed() -> void:
	save_requested.emit()


func _on_reload_pressed() -> void:
	reload_requested.emit()


func _on_debug_pressed() -> void:
	debug_requested.emit()
#endregion
