class_name DebugPopLayer
extends BaseUI

const DebugPerformanceStatsUtil = preload("res://assets/src/ui/debug/view/DebugPerformanceStats.gd")

#region 节点引用
@export var close_button_path: NodePath
@export var speed_slider_path: NodePath
@export var speed_value_label_path: NodePath
@export var time_value_label_path: NodePath
@export var time_slider_path: NodePath
@export var dawn_button_path: NodePath
@export var noon_button_path: NodePath
@export var dusk_button_path: NodePath
@export var midnight_button_path: NodePath
@export var stats_toggle_path: NodePath
@export var stats_detail_label_path: NodePath

@onready var close_button: Button = get_node(close_button_path) as Button
@onready var speed_slider: HSlider = get_node(speed_slider_path) as HSlider
@onready var speed_value_label: Label = get_node(speed_value_label_path) as Label
@onready var time_value_label: Label = get_node(time_value_label_path) as Label
@onready var time_slider: HSlider = get_node(time_slider_path) as HSlider
@onready var dawn_button: Button = get_node(dawn_button_path) as Button
@onready var noon_button: Button = get_node(noon_button_path) as Button
@onready var dusk_button: Button = get_node(dusk_button_path) as Button
@onready var midnight_button: Button = get_node(midnight_button_path) as Button
@onready var stats_toggle: CheckButton = get_node(stats_toggle_path) as CheckButton
@onready var stats_detail_label: Label = get_node(stats_detail_label_path) as Label
#endregion

#region 状态
var _world_time_controller: WorldTimeController = null
var _is_syncing_time_controls: bool = false
var _stats_detail_elapsed: float = 0.0
static var _stats_overlay_instance_id: int = -1


static func notify_stats_overlay_destroyed(instance_id: int) -> void:
	if _stats_overlay_instance_id == instance_id:
		_stats_overlay_instance_id = -1
#endregion

#region 生命周期
func on_ui_create(_params: Dictionary) -> void:
	close_button.pressed.connect(_on_close_pressed)
	speed_slider.value_changed.connect(_on_speed_slider_value_changed)
	time_slider.value_changed.connect(_on_time_slider_value_changed)
	dawn_button.pressed.connect(_on_time_preset_pressed.bind(6.0))
	noon_button.pressed.connect(_on_time_preset_pressed.bind(12.0))
	dusk_button.pressed.connect(_on_time_preset_pressed.bind(18.0))
	midnight_button.pressed.connect(_on_time_preset_pressed.bind(0.0))
	stats_toggle.toggled.connect(_on_stats_toggle_toggled)


func on_ui_open(_params: Dictionary) -> void:
	_sync_speed_controls()
	_world_time_controller = _get_world_time_controller()
	_sync_time_controls()
	_sync_stats_toggle()
	_stats_detail_elapsed = 0.0
	_sync_stats_detail()
	set_process(true)


func on_ui_hide() -> void:
	set_process(false)


func on_ui_destroy() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_sync_time_controls()
	_stats_detail_elapsed += delta
	if _stats_detail_elapsed >= 0.25:
		_stats_detail_elapsed = 0.0
		_sync_stats_detail()
#endregion

#region 交互与显示
func _on_close_pressed() -> void:
	UIManager.close_ui(get_instance_id())


func _on_speed_slider_value_changed(value: float) -> void:
	var multiplier := clampf(value, 1.0, 3.0)
	var player: Player = _get_player()
	if player != null:
		player.set_speed_multiplier(multiplier)
	_apply_speed_label(multiplier)


func _on_time_slider_value_changed(value: float) -> void:
	if _is_syncing_time_controls:
		return
	var world_time_controller: WorldTimeController = _get_world_time_controller()
	if world_time_controller == null:
		return
	world_time_controller.set_time_of_day(value)
	_sync_time_controls()


func _on_time_preset_pressed(hour: float) -> void:
	var world_time_controller: WorldTimeController = _get_world_time_controller()
	if world_time_controller == null:
		return
	world_time_controller.set_time_of_day(hour)
	_sync_time_controls()


func _on_stats_toggle_toggled(is_pressed: bool) -> void:
	if is_pressed:
		_open_stats_overlay()
	else:
		_close_stats_overlay()
#endregion


func _sync_speed_controls() -> void:
	var player: Player = _get_player()
	if player == null:
		_apply_speed_label(1.0)
		speed_slider.value = 1.0
		return
	speed_slider.value = player.get_speed_multiplier()
	_apply_speed_label(speed_slider.value)

#region 内部逻辑
func _get_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _get_world_time_controller() -> WorldTimeController:
	var existing: WorldTimeController = ControllerManager.get_controller(WorldTimeController.CONTROLLER_ID) as WorldTimeController
	if existing != null:
		_world_time_controller = existing
		return existing
	_world_time_controller = ControllerManager.get_or_register_controller(
		WorldTimeController.CONTROLLER_ID,
		func() -> BaseController:
			return WorldTimeController.new()
	) as WorldTimeController
	return _world_time_controller


func _apply_speed_label(multiplier: float) -> void:
	speed_value_label.text = "角色移速：%.2f 倍" % multiplier


func _sync_time_controls() -> void:
	var world_time_controller: WorldTimeController = _world_time_controller
	if world_time_controller == null:
		world_time_controller = _get_world_time_controller()
	if world_time_controller == null:
		_apply_time_label("时间：未就绪")
		_set_time_slider_value(WorldTimeModel.DEFAULT_TIME_OF_DAY)
		return

	var snapshot: Dictionary = world_time_controller.get_runtime_snapshot()
	_apply_time_label("时间：%s" % str(snapshot.get("time_label", "")))
	_set_time_slider_value(world_time_controller.get_time_of_day())


func _apply_time_label(text: String) -> void:
	time_value_label.text = text


func _set_time_slider_value(value: float) -> void:
	_is_syncing_time_controls = true
	time_slider.value = clampf(value, 0.0, 24.0)
	_is_syncing_time_controls = false


func _sync_stats_toggle() -> void:
	stats_toggle.set_pressed_no_signal(_stats_overlay_instance_id >= 0)


func _sync_stats_detail() -> void:
	stats_detail_label.text = DebugPerformanceStatsUtil.format_detail_text(DebugPerformanceStatsUtil.get_snapshot())


func _open_stats_overlay() -> void:
	if _stats_overlay_instance_id >= 0:
		return
	var overlay: BaseUI = UIManager.open_overlay(UIRegistry.DEBUG_STATS_OVERLAY)
	if overlay == null:
		stats_toggle.set_pressed_no_signal(false)
		return
	_stats_overlay_instance_id = overlay.get_instance_id()


func _close_stats_overlay() -> void:
	if _stats_overlay_instance_id < 0:
		return
	UIManager.close_ui(_stats_overlay_instance_id)
	_stats_overlay_instance_id = -1
#endregion
