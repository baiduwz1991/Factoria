class_name MapChunkStore
extends RefCounted

const CHUNK_DIR: String = "planet/chunks"
const CHUNK_FILE_EXTENSION: String = ".chunk.json"

var _slot_id: int = 0
var _save_manager: Node = null


func setup(slot_id: int, save_manager: Node) -> void:
	_slot_id = slot_id
	_save_manager = save_manager


func load_chunk(chunk_coord: Vector2i) -> MapChunkData:
	if _save_manager == null or not _save_manager.has_method("read_slot_asset_text"):
		return null

	var raw_result: Variant = _save_manager.call(
		"read_slot_asset_text",
		_slot_id,
		_get_chunk_relative_path(chunk_coord)
	)
	if not (raw_result is Dictionary):
		return null
	var result: Dictionary = raw_result as Dictionary
	if not bool(result.get("ok", false)):
		return null

	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(str(result.get("text", "")))
	if parse_error != OK or not (parser.data is Dictionary):
		return null

	var chunk: MapChunkData = MapChunkData.new()
	chunk.from_dict(parser.data as Dictionary)
	return chunk


func save_chunk(chunk: MapChunkData) -> Dictionary:
	if _save_manager == null or not _save_manager.has_method("write_slot_asset_text"):
		return {
			"ok": false,
			"error_code": &"save_manager_missing"
		}
	var json_text: String = JSON.stringify(chunk.to_dict())
	var raw_result: Variant = _save_manager.call(
		"write_slot_asset_text",
		_slot_id,
		_get_chunk_relative_path(chunk.chunk_coord),
		json_text
	)
	if raw_result is Dictionary:
		return raw_result as Dictionary
	return {
		"ok": false,
		"error_code": &"chunk_store_write_failed"
	}


func delete_all_chunks() -> Dictionary:
	if _save_manager == null or not _save_manager.has_method("delete_slot_asset_dir"):
		return {
			"ok": false,
			"error_code": &"save_manager_missing"
		}
	var raw_result: Variant = _save_manager.call("delete_slot_asset_dir", _slot_id, CHUNK_DIR)
	if raw_result is Dictionary:
		return raw_result as Dictionary
	return {
		"ok": false,
		"error_code": &"chunk_store_delete_failed"
	}


func _get_chunk_relative_path(chunk_coord: Vector2i) -> String:
	return "%s/%d_%d%s" % [
		CHUNK_DIR,
		chunk_coord.x,
		chunk_coord.y,
		CHUNK_FILE_EXTENSION
	]
