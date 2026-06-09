class_name BaseController
extends RefCounted

#region 配置与常量
const FLOW_SAVE_LOAD: StringName = &"on_save_load"
const FLOW_SAVE_UNLOAD: StringName = &"on_save_unload"
const FLOW_SAVE_FLUSH: StringName = &"on_save_flush"

const SAVE_SCOPE_NONE: StringName = &"none"
const SAVE_SCOPE_SLOT: StringName = &"slot"
const SAVE_SCOPE_PROFILE: StringName = &"profile"
#endregion

#region 对外接口 - 标识
func get_id() -> StringName:
	_report_abstract_method("get_id")
	return &"base_controller"
#endregion

#region 对外接口 - 存档编排依赖（ControllerManager 调度使用）
func get_save_load_dependencies() -> Array[StringName]:
	return []


func get_save_unload_dependencies() -> Array[StringName]:
	return []


func get_save_flush_dependencies() -> Array[StringName]:
	return get_save_unload_dependencies()
#endregion

#region 对外接口 - 存档数据契约（SaveManager 读写使用）
func get_save_scope() -> StringName:
	return SAVE_SCOPE_NONE


func is_save_participant() -> bool:
	return get_save_scope() != SAVE_SCOPE_NONE


func is_save_critical() -> bool:
	return false


func get_save_module_version() -> int:
	return 1


func export_save_data() -> Dictionary:
	return {}


func import_save_data(_payload: Dictionary) -> bool:
	return true


func get_save_meta_fragment() -> Dictionary:
	return {}
#endregion

#region 对外接口 - 生命周期
func on_game_start() -> void:
	# 单机建议在此做全局初始化（系统配置、事件绑定、缓存预热）。
	pass


func on_save_load() -> void:
	# 导入完成后的同步恢复时机。
	pass


func on_save_unload() -> void:
	# 导入前的同步清理时机（切档/回主菜单前）。
	pass


func on_save_flush() -> void:
	# 落盘前的同步聚合时机（可选流程）。
	pass


func on_release() -> void:
	pass
#endregion

#region 内部实现
func _call_back(back: Callable) -> void:
	if back.is_valid():
		back.call()


func _get_save_manager() -> Node:
	# SaveManager 通过 autoload 注册在场景树根。统一从 BaseController 提供，
	# 业务 Controller 不再自行 SceneTree 解析或拼装路径。
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return null
	var root: Window = scene_tree.root
	if root == null:
		return null
	return root.get_node_or_null("SaveManager")


func _report_abstract_method(method_name: String) -> void:
	push_error("BaseController 抽象方法未实现：%s" % method_name)
#endregion

