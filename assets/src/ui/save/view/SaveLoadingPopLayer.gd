class_name SaveLoadingPopLayer
extends BaseUI

#region 配置与常量
@export var title_text: String = "读取存档中"
@export var fallback_hint_text: String = "正在准备读取..."
const MAX_PROGRESS_WHILE_LOADING: float = 99.0
#endregion

#region 状态
var _save_controller: SaveController = null
var _planet_controller: BaseController = null
var _use_planet_progress: bool = false
var _is_planet_loading_active: bool = false
#endregion

#region 节点引用
@export var title_label_path: NodePath
@export var hint_label_path: NodePath
@export var progress_bar_path: NodePath
@export var progress_percent_label_path: NodePath

@onready var title_label: Label = get_node(title_label_path) as Label
@onready var hint_label: Label = get_node(hint_label_path) as Label
@onready var progress_bar: ProgressBar = get_node(progress_bar_path) as ProgressBar
@onready var progress_percent_label: Label = get_node(progress_percent_label_path) as Label
#endregion

#region 生命周期
func on_ui_create(_params: Dictionary) -> void:
	title_label.text = title_text
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	hint_label.text = fallback_hint_text
	progress_percent_label.text = "0%"


func on_ui_open(params: Dictionary) -> void:
	var incoming_title: String = str(params.get("title_text", title_text))
	var incoming_hint: String = str(params.get("fallback_hint_text", fallback_hint_text))
	_use_planet_progress = bool(params.get("use_planet_progress", false))
	_is_planet_loading_active = false
	title_label.text = incoming_title
	fallback_hint_text = incoming_hint
	hint_label.text = fallback_hint_text

	_save_controller = _get_save_controller()
	_planet_controller = _get_planet_controller()
	_bind_save_controller_signals()
	_bind_planet_controller_signals()
	if _save_controller == null:
		_apply_progress(0.0, "存档系统未就绪")
		return
	_apply_from_runtime_snapshot(_save_controller.get_runtime_snapshot())
	if _use_planet_progress and _planet_controller != null and _planet_controller.has_method("get_runtime_snapshot"):
		var snapshot_variant: Variant = _planet_controller.call("get_runtime_snapshot")
		var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
		_apply_planet_loading_snapshot({
			"active": bool(snapshot.get("loading_active", false)),
			"progress": float(snapshot.get("loading_progress", 0.0)),
			"label": str(snapshot.get("loading_label", ""))
		})


func on_ui_destroy() -> void:
	_unbind_save_controller_signals()
	_unbind_planet_controller_signals()
#endregion

#region 交互与显示
func _on_save_runtime_changed(runtime_snapshot: Dictionary) -> void:
	_apply_from_runtime_snapshot(runtime_snapshot)


func _on_planet_loading_changed(loading_snapshot: Dictionary) -> void:
	_apply_planet_loading_snapshot(loading_snapshot)
#endregion

#region 内部逻辑
func _apply_from_runtime_snapshot(runtime_snapshot: Dictionary) -> void:
	var is_loading: bool = bool(runtime_snapshot.get("is_loading", false))
	var last_phase: StringName = StringName(runtime_snapshot.get("last_phase", ""))
	var last_state: StringName = StringName(runtime_snapshot.get("last_state", ""))
	var load_progress: float = clampf(float(runtime_snapshot.get("load_progress", 0.0)), 0.0, 100.0)
	var load_progress_label: String = str(runtime_snapshot.get("load_progress_label", ""))

	if is_loading and load_progress >= 100.0:
		load_progress = MAX_PROGRESS_WHILE_LOADING
	if not is_loading and last_phase == &"load" and last_state == &"ok":
		load_progress = 100.0
	if load_progress_label == "":
		load_progress_label = _build_fallback_label(is_loading, last_phase, last_state)

	if _use_planet_progress and _is_planet_loading_active:
		return
	_apply_progress(load_progress, load_progress_label)


func _apply_planet_loading_snapshot(loading_snapshot: Dictionary) -> void:
	if not _use_planet_progress:
		return
	_is_planet_loading_active = bool(loading_snapshot.get("active", false))
	if not _is_planet_loading_active:
		return
	var progress: float = clampf(float(loading_snapshot.get("progress", 0.0)), 0.0, 100.0)
	var label: String = str(loading_snapshot.get("label", fallback_hint_text))
	if label == "":
		label = fallback_hint_text
	_apply_progress(progress, label)


func _apply_progress(load_progress: float, load_progress_label: String) -> void:
	progress_bar.value = clampf(load_progress, 0.0, 100.0)
	progress_percent_label.text = "%d%%" % int(round(progress_bar.value))
	hint_label.text = load_progress_label


func _build_fallback_label(is_loading: bool, last_phase: StringName, last_state: StringName) -> String:
	if is_loading:
		return fallback_hint_text
	if last_phase == &"load" and last_state == &"failed":
		return "读档失败"
	if last_phase == &"load" and last_state == &"ok":
		return "读档完成"
	return fallback_hint_text


func _bind_save_controller_signals() -> void:
	if _save_controller == null:
		return
	var callback: Callable = Callable(self, "_on_save_runtime_changed")
	if not _save_controller.is_connected("save_runtime_changed", callback):
		_save_controller.connect("save_runtime_changed", callback)


func _unbind_save_controller_signals() -> void:
	if _save_controller == null:
		return
	var callback: Callable = Callable(self, "_on_save_runtime_changed")
	if _save_controller.is_connected("save_runtime_changed", callback):
		_save_controller.disconnect("save_runtime_changed", callback)


func _bind_planet_controller_signals() -> void:
	if _planet_controller == null:
		return
	if not _planet_controller.has_signal("planet_loading_changed"):
		return
	var callback: Callable = Callable(self, "_on_planet_loading_changed")
	if not _planet_controller.is_connected("planet_loading_changed", callback):
		_planet_controller.connect("planet_loading_changed", callback)


func _unbind_planet_controller_signals() -> void:
	if _planet_controller == null:
		return
	if not _planet_controller.has_signal("planet_loading_changed"):
		return
	var callback: Callable = Callable(self, "_on_planet_loading_changed")
	if _planet_controller.is_connected("planet_loading_changed", callback):
		_planet_controller.disconnect("planet_loading_changed", callback)


func _get_save_controller() -> SaveController:
	return _get_or_register_controller(
		SaveController.CONTROLLER_ID,
		func() -> BaseController:
			return SaveController.new()
	) as SaveController


func _get_planet_controller() -> BaseController:
	return ControllerManager.get_controller(&"planet_controller")
#endregion
