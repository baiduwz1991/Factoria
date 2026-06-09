extends Node

#region 配置与常量
const MODE_REPLACE: StringName = &"replace"

const SCENE_ROOT_NAME: StringName = &"SceneRoot"
const SCENE_REGISTRY_SCRIPT: GDScript = preload("res://assets/src/core/scene-manager/SceneRegistry.gd")
#endregion

#region 信号-场景生命周期
signal scene_changed(scene_id: StringName, scene_node: Node)
#endregion

#region 状态
var _scene_root: Node2D = null
var _current_scene_id: StringName = StringName()
var _current_scene: Node = null
#endregion

#region 生命周期
func _ready() -> void:
	_ensure_scene_root()
#endregion

#region 对外接口
func open_scene(
	scene_id: StringName,
	params: Dictionary = {},
	mode: StringName = MODE_REPLACE,
	options: Dictionary = {}
) -> Node:
	if mode != MODE_REPLACE:
		push_warning("SceneManager.open_scene 暂不支持 mode=%s。" % String(mode))
		return null

	return _open_replace(scene_id, params, options)


func close_current_scene(options: Dictionary = {}) -> void:
	if _current_scene == null:
		return
	if bool(options.get("close_overlays", true)):
		_close_overlay_ui_before_scene_change()
	_close_scene_instance(_current_scene)
	_current_scene = null
	_current_scene_id = StringName()
	scene_changed.emit(_current_scene_id, null)


func get_current_scene() -> Node:
	return _current_scene


func get_current_scene_id() -> StringName:
	return _current_scene_id


func set_scene_root_visible(is_visible: bool) -> void:
	_ensure_scene_root()
	if _scene_root == null:
		return
	_scene_root.visible = is_visible
	_log_scene("set_scene_root_visible -> %s" % str(is_visible))
#endregion

#region 内部实现
func _open_replace(scene_id: StringName, params: Dictionary, options: Dictionary) -> Node:
	_ensure_scene_root()

	var scene: Node = _instantiate_scene(scene_id)
	if scene == null:
		return null

	if bool(options.get("close_overlays", true)):
		_close_overlay_ui_before_scene_change()

	if _current_scene != null:
		_close_scene_instance(_current_scene)

	_current_scene = scene
	_current_scene_id = scene_id
	_scene_root.add_child(scene)
	_dispatch_scene_enter(scene, params)
	_dispatch_scene_show(scene)
	_log_scene("open_replace -> %s" % String(scene_id))
	scene_changed.emit(scene_id, scene)
	return scene


func _ensure_scene_root() -> void:
	if is_instance_valid(_scene_root):
		return

	_scene_root = Node2D.new()
	_scene_root.name = SCENE_ROOT_NAME
	add_child(_scene_root)


func _instantiate_scene(scene_id: StringName) -> Node:
	if not SCENE_REGISTRY_SCRIPT.has_scene(scene_id):
		push_error("SceneManager 未注册 scene_id：%s" % String(scene_id))
		return null

	var scene_path: String = SCENE_REGISTRY_SCRIPT.get_scene_path(scene_id)
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("SceneManager 加载场景失败：%s" % scene_path)
		return null

	return packed_scene.instantiate()


func _close_overlay_ui_before_scene_change() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return

	var root: Window = scene_tree.root
	if root == null:
		return

	var ui_manager: Node = root.get_node_or_null("UIManager")
	if ui_manager == null or not ui_manager.has_method("close_all_overlays"):
		return

	ui_manager.call("close_all_overlays")


func _close_scene_instance(scene: Node) -> void:
	if not is_instance_valid(scene):
		return
	_dispatch_scene_hide(scene)
	_dispatch_scene_exit(scene)
	_dispatch_scene_destroy(scene)
	scene.queue_free()


func _dispatch_scene_enter(scene: Node, params: Dictionary) -> void:
	_call_scene_method(scene, &"on_scene_enter", [params])


func _dispatch_scene_show(scene: Node) -> void:
	_call_scene_method(scene, &"on_scene_show")


func _dispatch_scene_hide(scene: Node) -> void:
	_call_scene_method(scene, &"on_scene_hide")


func _dispatch_scene_exit(scene: Node) -> void:
	_call_scene_method(scene, &"on_scene_exit")


func _dispatch_scene_destroy(scene: Node) -> void:
	_call_scene_method(scene, &"on_scene_destroy")


func _call_scene_method(scene: Node, method_name: StringName, args: Array = []) -> void:
	if scene == null:
		return
	if not scene.has_method(String(method_name)):
		return
	scene.callv(String(method_name), args)


func _log_scene(message: String, is_warning: bool = false) -> void:
	if not OS.has_feature("debug"):
		return
	if is_warning:
		push_warning("[SceneManager] %s" % message)
		return
	print("[SceneManager] %s" % message)
#endregion
