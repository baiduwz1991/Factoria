class_name PlanetHudOverlayLayer
extends BaseUI

#region 信号
signal inventory_requested
signal map_requested
signal tool_selected(tool_id: StringName)
signal quick_slot_selected(slot_index: int)
#endregion

#region 节点引用
@export var objective_label_path: NodePath
@export var minimap_button_path: NodePath
@export var world_time_label_path: NodePath
@export var build_tool_button_path: NodePath
@export var dismantle_tool_button_path: NodePath
@export var inventory_button_path: NodePath
@export var quick_slots_container_path: NodePath
@export var quick_actions_container_path: NodePath

@onready var objective_label: Label = get_node(objective_label_path) as Label
@onready var minimap_button: Button = get_node(minimap_button_path) as Button
@onready var world_time_label: Label = get_node(world_time_label_path) as Label
@onready var build_tool_button: Button = get_node(build_tool_button_path) as Button
@onready var dismantle_tool_button: Button = get_node(dismantle_tool_button_path) as Button
@onready var inventory_button: Button = get_node(inventory_button_path) as Button
@onready var quick_slots_container: HBoxContainer = get_node(quick_slots_container_path) as HBoxContainer
@onready var quick_actions_container: HBoxContainer = get_node(quick_actions_container_path) as HBoxContainer

var _world_time_controller: WorldTimeController = null
#endregion

#region 生命周期
func on_ui_create(_params: Dictionary) -> void:
	minimap_button.pressed.connect(_on_minimap_pressed)
	build_tool_button.pressed.connect(_on_build_tool_pressed)
	dismantle_tool_button.pressed.connect(_on_dismantle_tool_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	_bind_quick_slot_buttons()
	_bind_quick_action_buttons()


func on_ui_open(params: Dictionary) -> void:
	_world_time_controller = _get_world_time_controller()
	_bind_world_time_controller()
	_sync_world_time_label()
	var slot_id: int = int(params.get("slot_id", 0))
	objective_label.text = "目标：建立第一条自动化产线"
	if slot_id > 0:
		objective_label.text = "%s\n槽位：%02d" % [objective_label.text, slot_id]
#endregion

#region 交互与显示
func on_ui_hide() -> void:
	_unbind_world_time_controller()


func on_ui_destroy() -> void:
	_unbind_world_time_controller()


func _on_minimap_pressed() -> void:
	map_requested.emit()


func _on_build_tool_pressed() -> void:
	tool_selected.emit(&"build")


func _on_dismantle_tool_pressed() -> void:
	tool_selected.emit(&"dismantle")


func _on_inventory_pressed() -> void:
	inventory_requested.emit()


func _on_quick_slot_pressed(slot_index: int) -> void:
	quick_slot_selected.emit(slot_index)


func _on_quick_action_pressed(action_id: StringName) -> void:
	tool_selected.emit(action_id)
#endregion

#region 内部逻辑
func _bind_quick_slot_buttons() -> void:
	var slot_index: int = 1
	for child in quick_slots_container.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		button.pressed.connect(_on_quick_slot_pressed.bind(slot_index))
		slot_index += 1


func _bind_quick_action_buttons() -> void:
	for child in quick_actions_container.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var action_id: StringName = StringName(button.name)
		button.pressed.connect(_on_quick_action_pressed.bind(action_id))


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


func _bind_world_time_controller() -> void:
	if _world_time_controller == null:
		return
	var changed_callable := Callable(self, "_on_world_time_changed")
	if not _world_time_controller.is_connected("world_time_changed", changed_callable):
		_world_time_controller.connect("world_time_changed", changed_callable)


func _unbind_world_time_controller() -> void:
	if _world_time_controller == null:
		return
	var changed_callable := Callable(self, "_on_world_time_changed")
	if _world_time_controller.is_connected("world_time_changed", changed_callable):
		_world_time_controller.disconnect("world_time_changed", changed_callable)


func _on_world_time_changed(snapshot: Dictionary) -> void:
	_apply_world_time_snapshot(snapshot)


func _sync_world_time_label() -> void:
	var world_time_controller: WorldTimeController = _world_time_controller
	if world_time_controller == null:
		world_time_controller = _get_world_time_controller()
	if world_time_controller == null:
		world_time_label.text = "时间：--:--"
		return

	_apply_world_time_snapshot(world_time_controller.get_runtime_snapshot())


func _apply_world_time_snapshot(snapshot: Dictionary) -> void:
	world_time_label.text = "时间：%s" % str(snapshot.get("time_label", ""))
#endregion
