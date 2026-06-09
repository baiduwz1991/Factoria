class_name LoadingModel
extends RefCounted

var active: bool = false
var title: String = ""
var label: String = ""
var current_step_id: StringName = &""
var progress: float = 0.0
var error_code: StringName = &""


func begin(next_title: String, next_label: String) -> void:
	active = true
	title = next_title
	label = next_label
	current_step_id = &""
	progress = 0.0
	error_code = &""


func apply_step(step_id: StringName, step_label: String, next_progress: float) -> void:
	active = true
	current_step_id = step_id
	label = step_label
	progress = clampf(next_progress, 0.0, 100.0)
	error_code = &""


func apply_completed(step_label: String = "加载完成") -> void:
	active = false
	current_step_id = &""
	label = step_label
	progress = 100.0
	error_code = &""


func apply_failed(next_error_code: StringName, step_label: String) -> void:
	active = false
	label = step_label
	error_code = next_error_code
	progress = clampf(progress, 0.0, 100.0)


func is_active() -> bool:
	return active


func get_snapshot() -> Dictionary:
	return {
		"active": active,
		"title": title,
		"label": label,
		"current_step_id": current_step_id,
		"progress": progress,
		"error_code": error_code
	}
