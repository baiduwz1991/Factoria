class_name LoadingLayer
extends BaseUI

@export var title_label_path: NodePath
@export var hint_label_path: NodePath
@export var progress_bar_path: NodePath
@export var progress_percent_label_path: NodePath

@onready var title_label: Label = get_node(title_label_path) as Label
@onready var hint_label: Label = get_node(hint_label_path) as Label
@onready var progress_bar: ProgressBar = get_node(progress_bar_path) as ProgressBar
@onready var progress_percent_label: Label = get_node(progress_percent_label_path) as Label

var _loading_controller: LoadingController = null
var _fallback_hint_text: String = "正在准备..."


func on_ui_create(_params: Dictionary) -> void:
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = false
	progress_percent_label.text = "0%"
	set_process(false)


func on_ui_open(params: Dictionary) -> void:
	title_label.text = str(params.get("title_text", "加载中"))
	_fallback_hint_text = str(params.get("fallback_hint_text", "正在准备..."))
	hint_label.text = _fallback_hint_text
	_loading_controller = _get_loading_controller()
	_bind_loading_controller_signals()
	if _loading_controller != null:
		_apply_snapshot(_loading_controller.get_runtime_snapshot())
	set_process(true)


func on_ui_destroy() -> void:
	set_process(false)
	_unbind_loading_controller_signals()
	_loading_controller = null


func _process(delta: float) -> void:
	if _loading_controller == null:
		return
	_loading_controller.process_loading(delta)


func _on_loading_changed(snapshot: Dictionary) -> void:
	_apply_snapshot(snapshot)


func _apply_snapshot(snapshot: Dictionary) -> void:
	var title_text: String = str(snapshot.get("title", ""))
	if title_text != "":
		title_label.text = title_text
	var label_text: String = str(snapshot.get("label", ""))
	if label_text == "":
		label_text = _fallback_hint_text
	hint_label.text = label_text
	var progress: float = clampf(float(snapshot.get("progress", 0.0)), 0.0, 100.0)
	progress_bar.value = progress
	progress_percent_label.text = "%d%%" % int(round(progress))


func _bind_loading_controller_signals() -> void:
	if _loading_controller == null:
		return
	var callback: Callable = Callable(self, "_on_loading_changed")
	if not _loading_controller.is_connected("loading_changed", callback):
		_loading_controller.connect("loading_changed", callback)


func _unbind_loading_controller_signals() -> void:
	if _loading_controller == null:
		return
	var callback: Callable = Callable(self, "_on_loading_changed")
	if _loading_controller.is_connected("loading_changed", callback):
		_loading_controller.disconnect("loading_changed", callback)


func _get_loading_controller() -> LoadingController:
	var existing: LoadingController = ControllerManager.get_controller(LoadingController.CONTROLLER_ID) as LoadingController
	if existing != null:
		return existing
	return ControllerManager.get_or_register_controller(
		LoadingController.CONTROLLER_ID,
		func() -> BaseController:
			return LoadingController.new()
	) as LoadingController
