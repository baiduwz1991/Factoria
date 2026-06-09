extends Node

const DEFAULT_TOAST_DURATION: float = 2.5

var _layer: CanvasLayer = null
var _toast_root: Control = null
var _dialog: AcceptDialog = null


func _ready() -> void:
	_ensure_layer()


func show_toast(message: String, duration_sec: float = DEFAULT_TOAST_DURATION) -> void:
	_ensure_layer()
	var toast: PanelContainer = PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.anchor_left = 0.5
	toast.anchor_top = 0.9
	toast.anchor_right = 0.5
	toast.anchor_bottom = 0.9
	toast.offset_left = -220.0
	toast.offset_top = -24.0
	toast.offset_right = 220.0
	toast.offset_bottom = 24.0
	toast.modulate = Color(1, 1, 1, 0)

	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = message
	toast.add_child(label)
	_toast_root.add_child(toast)

	var tween: Tween = create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.2)
	tween.tween_interval(maxf(0.8, duration_sec))
	tween.tween_property(toast, "modulate:a", 0.0, 0.2)
	tween.finished.connect(
		func() -> void:
			if is_instance_valid(toast):
				toast.queue_free(),
		CONNECT_ONE_SHOT
	)


func show_dialog(title: String, message: String) -> void:
	_ensure_layer()
	if _dialog == null:
		_dialog = AcceptDialog.new()
		_dialog.dialog_text = ""
		_dialog.size = Vector2i(560, 280)
		_layer.add_child(_dialog)
	_dialog.title = title
	_dialog.dialog_text = message
	_dialog.popup_centered()


func show_update_restart_notice(bundle_version: int) -> void:
	show_toast("数值配置更新已下载，重启后生效。", 2.8)
	show_dialog("配置更新完成", "新数值包已下载完成（版本 %d）。\n请在方便时重启游戏以应用更新。" % bundle_version)


func _ensure_layer() -> void:
	if is_instance_valid(_layer) and is_instance_valid(_toast_root):
		return
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)
	_toast_root = Control.new()
	_toast_root.name = "ToastRoot"
	_toast_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_toast_root)
