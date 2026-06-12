class_name SettingsLayer
extends BaseUI

#region 状态
var _selected_mode_index: int = 0
var _selected_resolution_index: int = 2
var _selected_fps_limit_index: int = 0
var _settings_controller: SettingsController = null
#endregion

#region 节点引用
@export var title_label_path: NodePath
@export var mode_option_path: NodePath
@export var resolution_option_path: NodePath
@export var fps_limit_option_path: NodePath
@export var apply_button_path: NodePath
@export var back_button_path: NodePath

@onready var title_label: Label = get_node(title_label_path) as Label
@onready var mode_option: OptionButton = get_node(mode_option_path) as OptionButton
@onready var resolution_option: OptionButton = get_node(resolution_option_path) as OptionButton
@onready var fps_limit_option: OptionButton = get_node(fps_limit_option_path) as OptionButton
@onready var apply_button: Button = get_node(apply_button_path) as Button
@onready var back_button: Button = get_node(back_button_path) as Button
#endregion

#region 生命周期
func on_ui_create(_params: Dictionary) -> void:
	_settings_controller = _get_settings_controller()
	_initialize_options()
	mode_option.item_selected.connect(_on_mode_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	fps_limit_option.item_selected.connect(_on_fps_limit_selected)
	apply_button.pressed.connect(_on_apply_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_load_display_settings_from_controller()


func on_ui_open(_params: Dictionary) -> void:
	title_label.text = "显示设置"
	_load_display_settings_from_controller()
	_sync_ui_selection()
#endregion

#region 交互与显示
func _on_mode_selected(index: int) -> void:
	var max_index: int = mode_option.item_count - 1
	_selected_mode_index = clampi(index, 0, max_index)


func _on_resolution_selected(index: int) -> void:
	var max_index: int = resolution_option.item_count - 1
	_selected_resolution_index = clampi(index, 0, max_index)


func _on_fps_limit_selected(index: int) -> void:
	var max_index: int = fps_limit_option.item_count - 1
	_selected_fps_limit_index = clampi(index, 0, max_index)


func _on_apply_pressed() -> void:
	var save_ok: bool = _settings_controller.apply_and_save_display_settings(
		_selected_mode_index,
		_selected_resolution_index,
		_selected_fps_limit_index
	)
	if not save_ok:
		push_warning("SettingsLayer 保存显示设置失败。")


func _on_back_pressed() -> void:
	UIManager.close_ui(get_instance_id())
#endregion

#region 内部逻辑
func _initialize_options() -> void:
	if _settings_controller == null:
		return
	mode_option.clear()
	var mode_labels: Array[String] = _settings_controller.get_window_mode_labels()
	for mode_label in mode_labels:
		mode_option.add_item(mode_label)

	resolution_option.clear()
	var resolution_labels: Array[String] = _settings_controller.get_resolution_labels()
	for resolution_label in resolution_labels:
		resolution_option.add_item(resolution_label)

	fps_limit_option.clear()
	var fps_limit_labels: Array[String] = _settings_controller.get_fps_limit_labels()
	for fps_limit_label in fps_limit_labels:
		fps_limit_option.add_item(fps_limit_label)


func _sync_ui_selection() -> void:
	mode_option.select(_selected_mode_index)
	resolution_option.select(_selected_resolution_index)
	fps_limit_option.select(_selected_fps_limit_index)


func _load_display_settings_from_controller() -> void:
	if _settings_controller == null:
		return

	var snapshot: Dictionary = _settings_controller.get_display_snapshot()
	_selected_mode_index = int(snapshot.get("mode_index", 0))
	_selected_resolution_index = int(snapshot.get("resolution_index", 2))
	_selected_fps_limit_index = int(snapshot.get("fps_limit_index", 0))
	_selected_mode_index = clampi(_selected_mode_index, 0, mode_option.item_count - 1)
	_selected_resolution_index = clampi(_selected_resolution_index, 0, resolution_option.item_count - 1)
	_selected_fps_limit_index = clampi(_selected_fps_limit_index, 0, fps_limit_option.item_count - 1)


func _get_settings_controller() -> SettingsController:
	return _get_or_register_controller(
		SettingsController.CONTROLLER_ID,
		func() -> BaseController:
			return SettingsController.new()
	) as SettingsController
#endregion
