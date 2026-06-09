class_name RoleCreateModel
extends BaseModel

#region 状态
const KEY_SLOT_ID: StringName = &"slot_id"
const KEY_DRAFT_NAME: StringName = &"draft_name"
const KEY_DRAFT_PERSONALITY: StringName = &"draft_personality"
const KEY_IS_SUBMITTING: StringName = &"is_submitting"
const KEY_LAST_ERROR_CODE: StringName = &"last_error_code"

var _slot_id: int = 1
var _draft_name: String = ""
var _draft_personality: String = ""
var _is_submitting: bool = false
var _last_error_code: StringName = StringName()
#endregion

#region 对外只读
func get_slot_id() -> int:
	return _slot_id


func get_draft_name() -> String:
	return _draft_name


func get_draft_personality() -> String:
	return _draft_personality


func get_is_submitting() -> bool:
	return _is_submitting


func get_last_error_code() -> StringName:
	return _last_error_code


func get_runtime_snapshot() -> Dictionary:
	return {
		KEY_SLOT_ID: _slot_id,
		KEY_DRAFT_NAME: _draft_name,
		KEY_DRAFT_PERSONALITY: _draft_personality,
		KEY_IS_SUBMITTING: _is_submitting,
		KEY_LAST_ERROR_CODE: String(_last_error_code)
	}


func get_snapshot() -> Dictionary:
	return get_runtime_snapshot()
#endregion

#region 应用与重置
func apply(payload: Dictionary) -> void:
	_slot_id = _pick_int(payload, KEY_SLOT_ID, _slot_id)
	_draft_name = _pick_string(payload, KEY_DRAFT_NAME, _draft_name)
	_draft_personality = _pick_string(payload, KEY_DRAFT_PERSONALITY, _draft_personality)
	_is_submitting = _pick_bool(payload, KEY_IS_SUBMITTING, _is_submitting)
	_last_error_code = _pick_string_name(payload, KEY_LAST_ERROR_CODE, _last_error_code)


func apply_begin_create(slot_id: int, default_personality: String) -> void:
	var personality: String = _draft_personality
	if personality == "":
		personality = default_personality
	apply({
		KEY_SLOT_ID: slot_id,
		KEY_DRAFT_NAME: "",
		KEY_DRAFT_PERSONALITY: personality,
		KEY_IS_SUBMITTING: false,
		KEY_LAST_ERROR_CODE: StringName()
	})


func apply_player_name_input(normalized_name: String) -> void:
	apply({
		KEY_DRAFT_NAME: normalized_name,
		KEY_LAST_ERROR_CODE: StringName()
	})


func apply_submit_request(slot_id: int, normalized_name: String, personality: String) -> void:
	apply({
		KEY_SLOT_ID: slot_id,
		KEY_DRAFT_NAME: normalized_name,
		KEY_DRAFT_PERSONALITY: personality,
		KEY_IS_SUBMITTING: true,
		KEY_LAST_ERROR_CODE: StringName()
	})


func apply_submit_result(error_code: StringName) -> void:
	apply({
		KEY_IS_SUBMITTING: false,
		KEY_LAST_ERROR_CODE: error_code
	})


func apply_imported_slot(slot_id: int) -> void:
	apply({
		KEY_SLOT_ID: slot_id
	})


func clear() -> void:
	_slot_id = 1
	_draft_name = ""
	_draft_personality = ""
	_is_submitting = false
	_last_error_code = StringName()


func reset() -> void:
	clear()
#endregion

#region 内部解析
func _pick_int(source: Dictionary, key: StringName, fallback: int) -> int:
	if not source.has(key):
		return fallback
	return int(source.get(key, fallback))


func _pick_string(source: Dictionary, key: StringName, fallback: String) -> String:
	if not source.has(key):
		return fallback
	return str(source.get(key, fallback))


func _pick_bool(source: Dictionary, key: StringName, fallback: bool) -> bool:
	if not source.has(key):
		return fallback
	return bool(source.get(key, fallback))


func _pick_string_name(source: Dictionary, key: StringName, fallback: StringName) -> StringName:
	if not source.has(key):
		return fallback
	return StringName(source.get(key, String(fallback)))
#endregion
