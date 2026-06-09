class_name SaveJsonCodec
extends RefCounted

#region 配置与常量
const CURRENT_FORMAT_VERSION: int = 1
#endregion

#region 对外接口 - 编码
func encode(snapshot: Dictionary) -> String:
	return JSON.stringify(snapshot, "\t")
#endregion

#region 对外接口 - 解码
func decode(raw_text: String) -> Dictionary:
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(raw_text)
	if parse_error != OK:
		return {
			"ok": false,
			"error_code": &"json_parse_failed",
			"error_message": parser.get_error_message()
		}

	var parsed_data: Variant = parser.data
	if not (parsed_data is Dictionary):
		return {
			"ok": false,
			"error_code": &"snapshot_invalid_type",
			"error_message": "JSON 根节点必须是 Dictionary。"
		}

	var snapshot: Dictionary = parsed_data as Dictionary
	return migrate_to_current(snapshot)
#endregion

#region 对外接口 - 迁移
func migrate_to_current(snapshot: Dictionary) -> Dictionary:
	var working_snapshot: Dictionary = snapshot.duplicate(true)
	var header: Dictionary = working_snapshot.get("save_header", {})
	var format_version: int = int(header.get("format_version", 0))
	if format_version <= 0:
		format_version = 1
		header["format_version"] = 1
		working_snapshot["save_header"] = header

	if format_version > CURRENT_FORMAT_VERSION:
		return {
			"ok": false,
			"error_code": &"format_unsupported",
			"error_message": "存档版本高于当前客户端可支持版本。"
		}

	# 预留迁移链：未来版本在此按 v1->v2 逐步迁移。
	while format_version < CURRENT_FORMAT_VERSION:
		format_version += 1
		header["format_version"] = format_version
		working_snapshot["save_header"] = header

	_ensure_required_sections(working_snapshot)
	return {
		"ok": true,
		"snapshot": working_snapshot,
		"from_version": int(snapshot.get("save_header", {}).get("format_version", 1)),
		"to_version": CURRENT_FORMAT_VERSION
	}
#endregion

#region 内部实现
func _ensure_required_sections(snapshot: Dictionary) -> void:
	if not snapshot.has("save_header"):
		snapshot["save_header"] = {}
	if not snapshot.has("module_blobs"):
		snapshot["module_blobs"] = {}
	if not snapshot.has("meta"):
		snapshot["meta"] = {}
	if not snapshot.has("integrity"):
		snapshot["integrity"] = {}
#endregion
