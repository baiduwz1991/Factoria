class_name BaseUI
extends Control

## BaseUI 约束：
## 1) UI页面子类不要覆写 _ready() 承载业务初始化。
var ui_id: StringName = StringName()
var ui_mode: StringName = StringName()
var parent_ui_id: StringName = StringName()
var slot_id: StringName = StringName()

var _ui_created: bool = false
var _ui_visible: bool = false

#region 生命周期
func on_ui_create(_params: Dictionary) -> void:
	pass


func on_ui_open(_params: Dictionary) -> void:
	pass


func on_ui_show() -> void:
	pass


func on_ui_hide() -> void:
	pass


func on_ui_close() -> void:
	pass


func on_ui_destroy() -> void:
	pass
#endregion

#region 挂载点
func get_attach_slot_node(request_slot_id: StringName) -> Node:
	if request_slot_id == StringName() or request_slot_id == &"default":
		return self
	var node: Node = get_node_or_null(NodePath(String(request_slot_id)))
	if node != null:
		return node
	push_warning("BaseUI 未找到 attach slot：%s（ui_id=%s）" % [String(request_slot_id), String(ui_id)])
	return self
#endregion


#region Controller
func _get_or_register_controller(controller_id: StringName, create_controller: Callable) -> BaseController:
	return ControllerManager.get_or_register_controller(controller_id, create_controller)
#endregion


#region 框架分发
func _ui_dispatch_open(
	params: Dictionary,
	incoming_mode: StringName,
	incoming_parent_ui_id: StringName,
	incoming_slot_id: StringName
) -> void:
	ui_mode = incoming_mode
	parent_ui_id = incoming_parent_ui_id
	slot_id = incoming_slot_id

	if not _ui_created:
		_ui_created = true
		on_ui_create(params)

	on_ui_open(params)
	_ui_dispatch_show()


func _ui_dispatch_show() -> void:
	visible = true
	if _ui_visible:
		return
	_ui_visible = true
	on_ui_show()


func _ui_dispatch_hide() -> void:
	visible = false
	if not _ui_visible:
		return
	_ui_visible = false
	on_ui_hide()


func _ui_dispatch_close() -> void:
	on_ui_close()


func _ui_dispatch_destroy() -> void:
	on_ui_destroy()
#endregion


