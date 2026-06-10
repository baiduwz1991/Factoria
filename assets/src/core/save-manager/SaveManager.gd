extends Node

#region 配置与常量
const RESULT_OK: StringName = &"ok"
const RESULT_FAILED: StringName = &"failed"
const RESULT_IN_PROGRESS: StringName = &"in_progress"

const ERROR_BUSY: StringName = &"busy"
const ERROR_INVALID_SLOT: StringName = &"invalid_slot"
const ERROR_EXPORT_FAILED: StringName = &"export_failed"
const ERROR_IMPORT_FAILED: StringName = &"import_failed"
const ERROR_REPOSITORY_WRITE_FAILED: StringName = &"repository_write_failed"
const ERROR_REPOSITORY_READ_FAILED: StringName = &"repository_read_failed"
const ERROR_CODEC_FAILED: StringName = &"codec_failed"
const ERROR_PRECHECK_FAILED: StringName = &"precheck_failed"

const SAVE_MAGIC: String = "FACTORIA_SAVE"
#endregion

#region 信号-面向controller与view状态广播
signal save_state_changed(snapshot: Dictionary)
signal slot_meta_updated(slots: Array[Dictionary])
#endregion

#region 状态
var _repository: SaveRepository = SaveRepository.new()
var _json_codec: SaveJsonCodec = SaveJsonCodec.new()

var _is_saving: bool = false
var _is_loading: bool = false
var _participant_blacklist: Array[StringName] = []
var _active_load_slot_id: int = 0
#endregion

#region 生命周期
func _ready() -> void:
	_repository.ensure_layout()
	_bind_controller_manager_signals()
	refresh_slot_meta()
#endregion

#region 对外接口 - 状态与配置
func is_busy() -> bool:
	return _is_saving or _is_loading


func is_saving() -> bool:
	return _is_saving


func is_loading() -> bool:
	return _is_loading


func set_participant_blacklist(controller_ids: Array[StringName]) -> void:
	_participant_blacklist = _dedupe_string_names(controller_ids)


func clear_participant_blacklist() -> void:
	_participant_blacklist.clear()


#endregion

#region 对外接口 - 槽位
func refresh_slot_meta() -> Array[Dictionary]:
	var slots: Array[Dictionary] = _repository.list_slot_meta()
	slot_meta_updated.emit(slots)
	return slots


func get_slot_meta() -> Array[Dictionary]:
	return _repository.list_slot_meta()


func get_slot_backups(slot_id: int) -> Array[Dictionary]:
	if not _is_valid_slot(slot_id):
		return []
	return _repository.list_slot_backups(slot_id)


func get_slot_asset_path(slot_id: int, file_name: String) -> String:
	if not _is_valid_slot(slot_id):
		return ""
	return _repository.get_slot_asset_path(slot_id, file_name)


func write_slot_asset_text(slot_id: int, file_name: String, content: String) -> Dictionary:
	if not _is_valid_slot(slot_id):
		return {
			"ok": false,
			"error_code": ERROR_INVALID_SLOT,
			"slot_id": slot_id
		}
	return _repository.write_slot_asset_text(slot_id, file_name, content)


func read_slot_asset_text(slot_id: int, relative_path: String) -> Dictionary:
	if not _is_valid_slot(slot_id):
		return {
			"ok": false,
			"error_code": ERROR_INVALID_SLOT,
			"slot_id": slot_id
		}
	return _repository.read_slot_asset_text(slot_id, relative_path)


func delete_slot_asset_dir(slot_id: int, relative_dir: String) -> Dictionary:
	if not _is_valid_slot(slot_id):
		return {
			"ok": false,
			"error_code": ERROR_INVALID_SLOT,
			"slot_id": slot_id
		}
	return _repository.delete_slot_asset_dir(slot_id, relative_dir)


func request_delete_slot(slot_id: int, back: Callable = Callable()) -> bool:
	if is_busy():
		_call_back(back, {
			"ok": false,
			"error_code": ERROR_BUSY,
			"slot_id": slot_id
		})
		return false
	if not _is_valid_slot(slot_id):
		_call_back(back, {
			"ok": false,
			"error_code": ERROR_INVALID_SLOT,
			"slot_id": slot_id
		})
		return false
	var result: Dictionary = _repository.delete_slot_snapshot(slot_id)
	refresh_slot_meta()
	_call_back(back, result)
	return bool(result.get("ok", false))
#endregion

#region 对外接口 - 保存与读取
func request_save(slot_id: int, back: Callable = Callable()) -> bool:
	if is_busy():
		_emit_result("save", RESULT_FAILED, {
			"slot_id": slot_id,
			"error_code": ERROR_BUSY
		})
		_call_back(back, {
			"ok": false,
			"error_code": ERROR_BUSY,
			"slot_id": slot_id
		})
		return false

	if not _is_valid_slot(slot_id):
		_emit_result("save", RESULT_FAILED, {
			"slot_id": slot_id,
			"error_code": ERROR_INVALID_SLOT
		})
		_call_back(back, {
			"ok": false,
			"error_code": ERROR_INVALID_SLOT,
			"slot_id": slot_id
		})
		return false

	_is_saving = true
	_emit_result("save", &"started", {"slot_id": slot_id})
	ControllerManager.notify_save_flush(
		Callable(self, "_on_save_flush_done").bind(slot_id, back)
	)
	return true


func request_load(slot_id: int, back: Callable = Callable()) -> bool:
	if is_busy():
		_emit_result("load", RESULT_FAILED, {
			"slot_id": slot_id,
			"error_code": ERROR_BUSY
		})
		_call_back(back, {
			"ok": false,
			"error_code": ERROR_BUSY,
			"slot_id": slot_id
		})
		return false

	if not _is_valid_slot(slot_id):
		_emit_result("load", RESULT_FAILED, {
			"slot_id": slot_id,
			"error_code": ERROR_INVALID_SLOT
		})
		_call_back(back, {
			"ok": false,
			"error_code": ERROR_INVALID_SLOT,
			"slot_id": slot_id
		})
		return false

	_is_loading = true
	_active_load_slot_id = slot_id
	_emit_result("load", &"started", {"slot_id": slot_id})

	var precheck_result: Dictionary = _precheck_load(slot_id)
	if not bool(precheck_result.get("ok", false)):
		_finish_load(false, slot_id, back, precheck_result)
		return false

	_emit_result("load", RESULT_IN_PROGRESS, {
		"slot_id": slot_id,
		"load_progress": 15.0,
		"load_progress_label": "正在卸载旧存档..."
	})
	ControllerManager.notify_save_unload(
		Callable(self, "_on_load_unload_done").bind(slot_id, back, precheck_result)
	)
	return true


func request_load_by_source(
	slot_id: int,
	source: StringName,
	back: Callable = Callable()
) -> bool:
	if is_busy():
		_emit_result("load", RESULT_FAILED, {
			"slot_id": slot_id,
			"error_code": ERROR_BUSY
		})
		_call_back(back, {
			"ok": false,
			"error_code": ERROR_BUSY,
			"slot_id": slot_id
		})
		return false

	if not _is_valid_slot(slot_id):
		_emit_result("load", RESULT_FAILED, {
			"slot_id": slot_id,
			"error_code": ERROR_INVALID_SLOT
		})
		_call_back(back, {
			"ok": false,
			"error_code": ERROR_INVALID_SLOT,
			"slot_id": slot_id
		})
		return false

	_is_loading = true
	_active_load_slot_id = slot_id
	_emit_result("load", &"started", {
		"slot_id": slot_id,
		"source": source
	})

	var slot_result: Dictionary = _repository.read_slot_snapshot_json_by_source(slot_id, source)
	var precheck_result: Dictionary = _precheck_load_with_slot_result(slot_result)
	if not bool(precheck_result.get("ok", false)):
		_finish_load(false, slot_id, back, precheck_result)
		return false

	_emit_result("load", RESULT_IN_PROGRESS, {
		"slot_id": slot_id,
		"load_progress": 15.0,
		"load_progress_label": "正在卸载旧存档..."
	})
	ControllerManager.notify_save_unload(
		Callable(self, "_on_load_unload_done").bind(slot_id, back, precheck_result)
	)
	return true
#endregion

#region 内部实现 - 保存
func _on_save_flush_done(slot_id: int, back: Callable) -> void:
	var export_result: Dictionary = _collect_snapshot_for_save(slot_id)
	if not bool(export_result.get("ok", false)):
		_finish_save(false, slot_id, back, export_result)
		return

	var snapshot: Dictionary = export_result.get("snapshot", {})
	var json_text: String = _json_codec.encode(snapshot)
	var meta: Dictionary = export_result.get("meta", {})
	var write_result: Dictionary = _repository.write_slot_snapshot_json(slot_id, json_text, meta)
	if not bool(write_result.get("ok", false)):
		_finish_save(false, slot_id, back, {
			"ok": false,
			"error_code": ERROR_REPOSITORY_WRITE_FAILED,
			"detail": write_result
		})
		return

	var profile_snapshot_result: Dictionary = _collect_profile_snapshot()
	if not bool(profile_snapshot_result.get("ok", false)):
		_finish_save(false, slot_id, back, profile_snapshot_result)
		return
	var profile_json_text: String = _json_codec.encode(profile_snapshot_result.get("snapshot", {}))
	var profile_write_result: Dictionary = _repository.write_profile_snapshot_json(profile_json_text)
	if not bool(profile_write_result.get("ok", false)):
		_finish_save(false, slot_id, back, {
			"ok": false,
			"error_code": ERROR_REPOSITORY_WRITE_FAILED,
			"detail": profile_write_result
		})
		return

	refresh_slot_meta()
	_finish_save(true, slot_id, back, {
		"ok": true,
		"meta": meta
	})


func _collect_snapshot_for_save(slot_id: int) -> Dictionary:
	var module_blobs: Dictionary = {}
	var meta: Dictionary = {
		"slot_id": slot_id,
		"title": "存档 %02d" % slot_id,
		"updated_at_unix": Time.get_unix_time_from_system()
	}

	for controller_id in ControllerManager.list_controller_ids():
		var controller: BaseController = ControllerManager.get_controller(controller_id)
		if not _is_participant_controller(controller_id, controller, BaseController.SAVE_SCOPE_SLOT):
			continue

		var payload_variant: Variant = controller.export_save_data()
		if not (payload_variant is Dictionary):
			return {
				"ok": false,
				"error_code": ERROR_EXPORT_FAILED,
				"controller_id": controller_id
			}
		var payload: Dictionary = (payload_variant as Dictionary).duplicate(true)
		module_blobs[String(controller_id)] = {
			"module_version": controller.get_save_module_version(),
			"scope": String(controller.get_save_scope()),
			"payload": payload
		}

		var meta_fragment: Dictionary = controller.get_save_meta_fragment()
		for key in meta_fragment.keys():
			meta[key] = meta_fragment[key]

	var snapshot: Dictionary = _build_snapshot(slot_id, module_blobs, meta)
	return {
		"ok": true,
		"snapshot": snapshot,
		"meta": meta
	}


func _collect_profile_snapshot() -> Dictionary:
	var module_blobs: Dictionary = _read_existing_profile_module_blobs()
	for controller_id in ControllerManager.list_controller_ids():
		var controller: BaseController = ControllerManager.get_controller(controller_id)
		if not _is_participant_controller(controller_id, controller, BaseController.SAVE_SCOPE_PROFILE):
			continue
		var payload_variant: Variant = controller.export_save_data()
		if not (payload_variant is Dictionary):
			return {
				"ok": false,
				"error_code": ERROR_EXPORT_FAILED,
				"controller_id": controller_id
			}
		var payload: Dictionary = payload_variant as Dictionary
		if payload.is_empty():
			continue
		module_blobs[String(controller_id)] = {
			"module_version": controller.get_save_module_version(),
			"scope": String(controller.get_save_scope()),
			"payload": payload.duplicate(true)
		}

	var snapshot: Dictionary = {
		"save_header": {
			"magic": SAVE_MAGIC,
			"format_version": SaveJsonCodec.CURRENT_FORMAT_VERSION,
			"saved_at_unix": Time.get_unix_time_from_system(),
			"scope": "profile"
		},
		"module_blobs": module_blobs,
		"meta": {},
		"integrity": {
			"payload_sha256": JSON.stringify(module_blobs).sha256_text()
		}
	}
	return {
		"ok": true,
		"snapshot": snapshot
	}


func _read_existing_profile_module_blobs() -> Dictionary:
	var profile_result: Dictionary = _repository.read_profile_snapshot_json()
	if not bool(profile_result.get("ok", false)):
		return {}

	var decoded_profile: Dictionary = _json_codec.decode(str(profile_result.get("text", "")))
	if not bool(decoded_profile.get("ok", false)):
		return {}

	var profile_snapshot: Dictionary = decoded_profile.get("snapshot", {})
	var module_blobs_variant: Variant = profile_snapshot.get("module_blobs", {})
	if not (module_blobs_variant is Dictionary):
		return {}
	return (module_blobs_variant as Dictionary).duplicate(true)


func _build_snapshot(slot_id: int, module_blobs: Dictionary, meta: Dictionary) -> Dictionary:
	return {
		"save_header": {
			"magic": SAVE_MAGIC,
			"format_version": SaveJsonCodec.CURRENT_FORMAT_VERSION,
			"slot_id": slot_id,
			"saved_at_unix": Time.get_unix_time_from_system()
		},
		"module_blobs": module_blobs,
		"meta": meta,
		"integrity": {
			"payload_sha256": JSON.stringify(module_blobs).sha256_text()
		}
	}


func _finish_save(ok: bool, slot_id: int, back: Callable, result: Dictionary) -> void:
	_is_saving = false
	var callback_payload: Dictionary = result.duplicate(true)
	callback_payload["slot_id"] = slot_id
	if ok:
		_emit_result("save", RESULT_OK, {
			"slot_id": slot_id,
			"detail": result
		})
	else:
		_emit_result("save", RESULT_FAILED, {
			"slot_id": slot_id,
			"detail": result
		})
	_call_back(back, callback_payload)
#endregion

#region 内部实现 - 读取
func _precheck_load(slot_id: int) -> Dictionary:
	var slot_result: Dictionary = _repository.read_slot_snapshot_json(slot_id)
	return _precheck_load_with_slot_result(slot_result)


func _precheck_load_with_slot_result(slot_result: Dictionary) -> Dictionary:
	if not bool(slot_result.get("ok", false)):
		return {
			"ok": false,
			"error_code": ERROR_REPOSITORY_READ_FAILED,
			"detail": slot_result
		}

	var decoded_slot: Dictionary = _json_codec.decode(str(slot_result.get("text", "")))
	if not bool(decoded_slot.get("ok", false)):
		return {
			"ok": false,
			"error_code": ERROR_CODEC_FAILED,
			"detail": decoded_slot
		}

	var slot_snapshot: Dictionary = decoded_slot.get("snapshot", {})
	var precheck_slot: Dictionary = _precheck_snapshot_payloads(
		slot_snapshot,
		BaseController.SAVE_SCOPE_SLOT
	)
	if not bool(precheck_slot.get("ok", false)):
		return {
			"ok": false,
			"error_code": ERROR_PRECHECK_FAILED,
			"detail": precheck_slot
		}

	var profile_snapshot: Dictionary = {}
	var profile_result: Dictionary = _repository.read_profile_snapshot_json()
	if bool(profile_result.get("ok", false)):
		var decoded_profile: Dictionary = _json_codec.decode(str(profile_result.get("text", "")))
		if bool(decoded_profile.get("ok", false)):
			profile_snapshot = decoded_profile.get("snapshot", {})
		else:
			return {
				"ok": false,
				"error_code": ERROR_CODEC_FAILED,
				"detail": decoded_profile
			}

	var precheck_profile: Dictionary = _precheck_snapshot_payloads(
		profile_snapshot,
		BaseController.SAVE_SCOPE_PROFILE
	)
	if not bool(precheck_profile.get("ok", false)):
		return {
			"ok": false,
			"error_code": ERROR_PRECHECK_FAILED,
			"detail": precheck_profile
		}

	return {
		"ok": true,
		"slot_snapshot": slot_snapshot,
		"profile_snapshot": profile_snapshot,
		"used_backup": bool(slot_result.get("used_backup", false))
	}


func _on_load_unload_done(slot_id: int, back: Callable, precheck_result: Dictionary) -> void:
	var import_result: Dictionary = _apply_snapshot_imports(
		precheck_result.get("slot_snapshot", {}),
		precheck_result.get("profile_snapshot", {})
	)
	if not bool(import_result.get("ok", false)):
		_finish_load(false, slot_id, back, import_result)
		return

	_emit_result("load", RESULT_IN_PROGRESS, {
		"slot_id": slot_id,
		"load_progress": 55.0,
		"load_progress_label": "正在执行加载生命周期..."
	})
	ControllerManager.notify_save_load(
		Callable(self, "_on_load_phase_done").bind(slot_id, back, precheck_result)
	)


func _on_load_phase_done(slot_id: int, back: Callable, precheck_result: Dictionary) -> void:
	refresh_slot_meta()
	_finish_load(true, slot_id, back, {
		"ok": true,
		"used_backup": bool(precheck_result.get("used_backup", false))
	})


func _apply_snapshot_imports(slot_snapshot: Dictionary, profile_snapshot: Dictionary) -> Dictionary:
	var slot_blobs: Dictionary = slot_snapshot.get("module_blobs", {})
	var profile_blobs: Dictionary = profile_snapshot.get("module_blobs", {})

	for controller_id in ControllerManager.list_controller_ids():
		var controller: BaseController = ControllerManager.get_controller(controller_id)
		var scope: StringName = controller.get_save_scope()
		if scope == BaseController.SAVE_SCOPE_NONE:
			continue
		if not _is_participant_controller(controller_id, controller, scope):
			continue

		var controller_id_str: String = String(controller_id)
		var source_blobs: Dictionary = slot_blobs
		if scope == BaseController.SAVE_SCOPE_PROFILE:
			source_blobs = profile_blobs

		var payload_entry_variant: Variant = source_blobs.get(controller_id_str, {})
		if not (payload_entry_variant is Dictionary):
			return {
				"ok": false,
				"error_code": ERROR_IMPORT_FAILED,
				"controller_id": controller_id
			}
		var payload_entry: Dictionary = payload_entry_variant as Dictionary
		var payload_variant: Variant = payload_entry.get("payload", {})
		if not (payload_variant is Dictionary):
			return {
				"ok": false,
				"error_code": ERROR_IMPORT_FAILED,
				"controller_id": controller_id
			}
		var payload: Dictionary = payload_variant as Dictionary
		var import_ok: bool = controller.import_save_data(payload)
		if not import_ok:
			return {
				"ok": false,
				"error_code": ERROR_IMPORT_FAILED,
				"controller_id": controller_id
			}

	return {
		"ok": true
	}


func _precheck_snapshot_payloads(snapshot: Dictionary, scope: StringName) -> Dictionary:
	if snapshot.is_empty():
		return {"ok": true}

	var module_blobs: Dictionary = snapshot.get("module_blobs", {})
	for controller_id in ControllerManager.list_controller_ids():
		var controller: BaseController = ControllerManager.get_controller(controller_id)
		if not _is_participant_controller(controller_id, controller, scope):
			continue

		var payload_entry: Dictionary = module_blobs.get(String(controller_id), {})
		if payload_entry.is_empty():
			continue
		var payload_variant: Variant = payload_entry.get("payload", {})
		if not (payload_variant is Dictionary):
			return {
				"ok": false,
				"error_code": &"payload_invalid_type",
				"controller_id": controller_id
			}
		var precheck_variant: Variant = controller.precheck_import_save_data(payload_variant as Dictionary)
		if precheck_variant is Dictionary:
			var precheck_result: Dictionary = precheck_variant as Dictionary
			if not bool(precheck_result.get("ok", false)):
				return {
					"ok": false,
					"error_code": &"payload_precheck_failed",
					"controller_id": controller_id,
					"detail": precheck_result
				}

	return {"ok": true}


func _finish_load(ok: bool, slot_id: int, back: Callable, result: Dictionary) -> void:
	_is_loading = false
	_active_load_slot_id = 0
	var callback_payload: Dictionary = result.duplicate(true)
	callback_payload["slot_id"] = slot_id
	if ok:
		_emit_result("load", RESULT_OK, {
			"slot_id": slot_id,
			"detail": result
		})
	else:
		_emit_result("load", RESULT_FAILED, {
			"slot_id": slot_id,
			"detail": result
		})
	_call_back(back, callback_payload)
#endregion

#region 内部实现 - 策略与工具
func _is_participant_controller(
	controller_id: StringName,
	controller: BaseController,
	scope: StringName
) -> bool:
	if controller == null:
		return false
	if _participant_blacklist.has(controller_id):
		return false
	if not controller.is_save_participant():
		return false
	if controller.get_save_scope() != scope:
		return false
	return true


func _emit_result(phase: StringName, state: StringName, detail: Dictionary) -> void:
	save_state_changed.emit({
		"phase": phase,
		"state": state,
		"detail": detail,
		"is_saving": _is_saving,
		"is_loading": _is_loading
	})


func _is_valid_slot(slot_id: int) -> bool:
	return slot_id >= SaveRepository.SLOT_MIN and slot_id <= SaveRepository.SLOT_MAX


func _call_back(back: Callable, payload: Dictionary) -> void:
	if back.is_valid():
		back.call(payload)


func _dedupe_string_names(source: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for item in source:
		if item == StringName():
			continue
		if result.has(item):
			continue
		result.append(item)
	return result


func _bind_controller_manager_signals() -> void:
	var phase_progress_callable: Callable = Callable(self, "_on_phase_progress")
	if not ControllerManager.is_connected("phase_progress", phase_progress_callable):
		ControllerManager.connect("phase_progress", phase_progress_callable)


func _on_phase_progress(
	phase: StringName,
	controller_id: StringName,
	completed_count: int,
	total_count: int
) -> void:
	if not _is_loading:
		return
	if _active_load_slot_id <= 0:
		return
	if phase != BaseController.FLOW_SAVE_LOAD:
		return
	if total_count <= 0:
		return
	var normalized: float = clampf(float(completed_count) / float(total_count), 0.0, 1.0)
	var load_progress: float = 55.0 + normalized * 44.0
	_emit_result("load", RESULT_IN_PROGRESS, {
		"slot_id": _active_load_slot_id,
		"load_progress": load_progress,
		"load_progress_label": "正在加载模块：%s" % String(controller_id)
	})
#endregion
