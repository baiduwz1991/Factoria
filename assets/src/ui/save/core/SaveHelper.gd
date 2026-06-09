class_name SaveHelper
extends RefCounted

static func pick_error_code_from_runtime_snapshot(runtime_snapshot: Dictionary) -> StringName:
	var detail: Dictionary = runtime_snapshot.get("detail", {})
	var detail_payload: Dictionary = detail.get("detail", {})
	return StringName(str(detail_payload.get("error_code", detail.get("error_code", ""))))


static func pick_used_backup_from_runtime_snapshot(runtime_snapshot: Dictionary) -> bool:
	var detail: Dictionary = runtime_snapshot.get("detail", {})
	var detail_payload: Dictionary = detail.get("detail", {})
	return bool(detail_payload.get("used_backup", false))


static func pick_load_progress_from_runtime_snapshot(runtime_snapshot: Dictionary) -> float:
	var detail: Dictionary = runtime_snapshot.get("detail", {})
	if detail.has("load_progress"):
		return clampf(float(detail.get("load_progress", 0.0)), 0.0, 100.0)
	var detail_payload: Dictionary = detail.get("detail", {})
	return clampf(float(detail_payload.get("load_progress", 0.0)), 0.0, 100.0)


static func pick_load_progress_label_from_runtime_snapshot(runtime_snapshot: Dictionary) -> String:
	var detail: Dictionary = runtime_snapshot.get("detail", {})
	if detail.has("load_progress_label"):
		return str(detail.get("load_progress_label", ""))
	var detail_payload: Dictionary = detail.get("detail", {})
	return str(detail_payload.get("load_progress_label", ""))


static func build_missing_manager_runtime_snapshot(phase: StringName, error_code: StringName) -> Dictionary:
	return {
		"last_phase": String(phase),
		"last_state": "failed",
		"last_error_code": String(error_code),
		"load_progress": 0.0,
		"load_progress_label": "存档系统未就绪"
	}


static func build_error_result(error_code: StringName) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code
	}
