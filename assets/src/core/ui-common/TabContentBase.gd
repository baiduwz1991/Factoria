class_name TabContentBase
extends BaseUI

#region 状态
var _bound_parent_ui: BaseUI = null
var _current_tab_context: Dictionary = {}
#endregion


#region 生命周期
func on_ui_create(params: Dictionary) -> void:
	_on_tab_content_create(params)


func on_ui_open(params: Dictionary) -> void:
	_bind_parent_tab_signal()
	_apply_tab_context(params)
	_on_tab_content_open(params)


func on_ui_destroy() -> void:
	_unbind_parent_tab_signal()
	_on_tab_content_destroy()
#endregion


#region 交互与显示
func refresh_tab_content(tab_context: Dictionary) -> void:
	_apply_tab_context(tab_context)
#endregion


#region 扩展点
func _get_tab_id() -> StringName:
	return StringName()


func _on_tab_content_create(_params: Dictionary) -> void:
	pass


func _on_tab_content_open(_params: Dictionary) -> void:
	pass


func _on_tab_content_destroy() -> void:
	pass


func _on_tab_context_changed(_tab_context: Dictionary) -> void:
	pass
#endregion


#region 内部逻辑
func _bind_parent_tab_signal() -> void:
	if parent_ui_id == StringName():
		return
	if is_instance_valid(_bound_parent_ui):
		return
	var ui_manager: Node = get_tree().root.find_child("UIManager", true, false)
	if ui_manager == null:
		return

	var parent_ui: BaseUI = ui_manager.call("_find_ui_by_ui_id", parent_ui_id) as BaseUI
	if parent_ui == null:
		return
	if not parent_ui.has_signal("tab_context_changed"):
		return

	var callback: Callable = Callable(self, "_on_parent_tab_context_changed")
	if not parent_ui.is_connected("tab_context_changed", callback):
		parent_ui.connect("tab_context_changed", callback)
	_bound_parent_ui = parent_ui


func _unbind_parent_tab_signal() -> void:
	if not is_instance_valid(_bound_parent_ui):
		_bound_parent_ui = null
		return

	var callback: Callable = Callable(self, "_on_parent_tab_context_changed")
	if _bound_parent_ui.is_connected("tab_context_changed", callback):
		_bound_parent_ui.disconnect("tab_context_changed", callback)
	_bound_parent_ui = null


func _on_parent_tab_context_changed(
	tab_id: StringName,
	tab_title: String,
	tab_params: Dictionary
) -> void:
	if tab_id != _get_tab_id():
		return
	var merged_context: Dictionary = tab_params.duplicate(true)
	if not merged_context.has("title"):
		merged_context["title"] = tab_title
	refresh_tab_content(merged_context)


func _apply_tab_context(tab_context: Dictionary) -> void:
	_current_tab_context = tab_context.duplicate(true)
	_on_tab_context_changed(_current_tab_context)
#endregion
