class_name DebugStatsOverlay
extends BaseUI

const DebugPerformanceStatsUtil = preload("res://assets/src/ui/debug/view/DebugPerformanceStats.gd")

@export var stats_label_path: NodePath
@export var update_interval: float = 0.25

@onready var stats_label: Label = get_node(stats_label_path) as Label

var _elapsed: float = 0.0


func on_ui_open(_params: Dictionary) -> void:
	_elapsed = 0.0
	_sync_stats()
	set_process(true)


func on_ui_hide() -> void:
	set_process(false)


func on_ui_destroy() -> void:
	set_process(false)
	DebugPopLayer.notify_stats_overlay_destroyed(get_instance_id())


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < update_interval:
		return
	_elapsed = 0.0
	_sync_stats()


func _sync_stats() -> void:
	stats_label.text = DebugPerformanceStatsUtil.format_quick_text(DebugPerformanceStatsUtil.get_snapshot())
