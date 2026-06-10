class_name GameDataRegistry
extends RefCounted

const CONTENT_TERRAIN: String = "terrain"
const CONTENT_TERRAIN_VISUALS: String = "terrain_visuals"
const CONTENT_AUTOPLACE: String = "autoplace"
const CONTENT_PLANET_PRESETS: String = "planet_presets"

var _terrain_defs: Dictionary = {}
var _terrain_order: Array[StringName] = []
var _terrain_visual_defs: Dictionary = {}
var _terrain_visual_order: Array[StringName] = []
var _autoplace_defs: Dictionary = {}
var _autoplace_order: Array[StringName] = []
var _planet_preset_defs: Dictionary = {}
var _planet_preset_order: Array[StringName] = []
var _diagnostics: Array[Dictionary] = []
var _fingerprint: String = ""


func clear() -> void:
	_terrain_defs.clear()
	_terrain_order.clear()
	_terrain_visual_defs.clear()
	_terrain_visual_order.clear()
	_autoplace_defs.clear()
	_autoplace_order.clear()
	_planet_preset_defs.clear()
	_planet_preset_order.clear()
	_diagnostics.clear()
	_fingerprint = ""


func load_mod_content(manifest: Dictionary) -> void:
	var mod_id: String = str(manifest.get("id", ""))
	var base_dir: String = str(manifest.get("base_dir", ""))
	var content: Dictionary = manifest.get("content", {}) as Dictionary
	if mod_id == "" or base_dir == "" or content == null:
		return

	_load_content_group(mod_id, base_dir, CONTENT_TERRAIN, content.get(CONTENT_TERRAIN, []))
	_load_content_group(mod_id, base_dir, CONTENT_TERRAIN_VISUALS, content.get(CONTENT_TERRAIN_VISUALS, []))
	_load_content_group(mod_id, base_dir, CONTENT_AUTOPLACE, content.get(CONTENT_AUTOPLACE, []))
	_load_content_group(mod_id, base_dir, CONTENT_PLANET_PRESETS, content.get(CONTENT_PLANET_PRESETS, []))


func finalize_registry(active_mods: Array[Dictionary]) -> void:
	var payload: Dictionary = {
		"active_mods": active_mods.duplicate(true),
		"terrain": SerializeUtils.string_name_array_to_strings(_terrain_order),
		"terrain_visuals": SerializeUtils.string_name_array_to_strings(_terrain_visual_order),
		"autoplace": SerializeUtils.string_name_array_to_strings(_autoplace_order),
		"planet_presets": SerializeUtils.string_name_array_to_strings(_planet_preset_order)
	}
	_fingerprint = JSON.stringify(payload).sha256_text()


func get_fingerprint() -> String:
	return _fingerprint


func get_diagnostics() -> Array[Dictionary]:
	return _diagnostics.duplicate(true)


func get_terrain_defs() -> Array[Dictionary]:
	return _collect_ordered_defs(_terrain_order, _terrain_defs)


func get_terrain_def(terrain_id: StringName) -> Dictionary:
	return _get_def(_terrain_defs, terrain_id)


func get_terrain_visual_defs() -> Array[Dictionary]:
	return _collect_ordered_defs(_terrain_visual_order, _terrain_visual_defs)


func get_terrain_visual_def(terrain_id: StringName) -> Dictionary:
	return _get_def(_terrain_visual_defs, terrain_id)


func get_autoplace_defs() -> Array[Dictionary]:
	return _collect_ordered_defs(_autoplace_order, _autoplace_defs)


func get_planet_preset_defs() -> Array[Dictionary]:
	return _collect_ordered_defs(_planet_preset_order, _planet_preset_defs)


func get_planet_preset_def(preset_id: StringName) -> Dictionary:
	return _get_def(_planet_preset_defs, preset_id)


func has_terrain(terrain_id: StringName) -> bool:
	return _terrain_defs.has(terrain_id)


func has_planet_preset(preset_id: StringName) -> bool:
	return _planet_preset_defs.has(preset_id)


func _load_content_group(mod_id: String, base_dir: String, content_kind: String, files_value: Variant) -> void:
	var files: Array = _to_array(files_value)
	for raw_file in files:
		var relative_path: String = str(raw_file)
		if relative_path == "":
			continue
		var content_path: String = _resolve_path(base_dir, relative_path)
		var entries: Array = _read_json_entries(content_path, content_kind)
		for raw_entry in entries:
			if not (raw_entry is Dictionary):
				_push_diagnostic(&"error", content_kind, "", mod_id, "content_entry_invalid")
				continue
			var entry: Dictionary = (raw_entry as Dictionary).duplicate(true)
			entry["source_mod_id"] = mod_id
			entry["source_path"] = content_path
			_register_content_entry(content_kind, entry, base_dir, mod_id)


func _register_content_entry(content_kind: String, entry: Dictionary, base_dir: String, mod_id: String) -> void:
	if content_kind == CONTENT_TERRAIN:
		_register_definition(
			CONTENT_TERRAIN,
			StringName(entry.get("id", "")),
			_resolve_texture_fields(entry, base_dir),
			_terrain_defs,
			_terrain_order,
			mod_id
		)
	elif content_kind == CONTENT_TERRAIN_VISUALS:
		_register_definition(
			CONTENT_TERRAIN_VISUALS,
			StringName(entry.get("terrain_id", "")),
			_resolve_texture_fields(entry, base_dir),
			_terrain_visual_defs,
			_terrain_visual_order,
			mod_id
		)
	elif content_kind == CONTENT_AUTOPLACE:
		var rule_id: StringName = StringName(entry.get("id", ""))
		if rule_id == StringName():
			rule_id = StringName("%s:%d" % [mod_id, _autoplace_order.size()])
			entry["id"] = String(rule_id)
		_register_definition(CONTENT_AUTOPLACE, rule_id, entry, _autoplace_defs, _autoplace_order, mod_id)
	elif content_kind == CONTENT_PLANET_PRESETS:
		_register_definition(
			CONTENT_PLANET_PRESETS,
			StringName(entry.get("id", "")),
			entry,
			_planet_preset_defs,
			_planet_preset_order,
			mod_id
		)


func _register_definition(
	content_kind: String,
	definition_id: StringName,
	definition: Dictionary,
	target: Dictionary,
	order: Array[StringName],
	mod_id: String
) -> void:
	if definition_id == StringName():
		_push_diagnostic(&"error", content_kind, "", mod_id, "definition_id_missing")
		return

	if target.has(definition_id):
		var previous: Dictionary = target.get(definition_id, {}) as Dictionary
		_push_diagnostic(&"override", content_kind, String(definition_id), mod_id, "definition_overridden", {
			"previous_mod_id": str(previous.get("source_mod_id", ""))
		})
		order.erase(definition_id)

	target[definition_id] = definition.duplicate(true)
	order.append(definition_id)


func _read_json_entries(path: String, content_kind: String) -> Array:
	if not FileAccess.file_exists(path):
		_push_diagnostic(&"error", content_kind, path, "", "content_file_missing")
		return []

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_push_diagnostic(&"error", content_kind, path, "", "content_file_open_failed")
		return []

	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	if parse_error != OK:
		_push_diagnostic(&"error", content_kind, path, "", "content_json_parse_failed", {
			"message": parser.get_error_message()
		})
		return []

	if parser.data is Array:
		return parser.data as Array
	if parser.data is Dictionary:
		var dictionary: Dictionary = parser.data as Dictionary
		if dictionary.has(content_kind) and dictionary.get(content_kind) is Array:
			return dictionary.get(content_kind) as Array
		if dictionary.has("definitions") and dictionary.get("definitions") is Array:
			return dictionary.get("definitions") as Array

	_push_diagnostic(&"error", content_kind, path, "", "content_json_invalid_shape")
	return []


func _resolve_texture_fields(entry: Dictionary, base_dir: String) -> Dictionary:
	var result: Dictionary = entry.duplicate(true)
	if result.has("foam_texture"):
		result["foam_texture"] = _resolve_resource_path(base_dir, str(result.get("foam_texture", "")))

	var textures: Dictionary = result.get("textures", {}) as Dictionary
	if textures == null:
		return result

	var resolved_textures: Dictionary = {}
	for key in textures.keys():
		resolved_textures[key] = _resolve_resource_path(base_dir, str(textures.get(key, "")))
	result["textures"] = resolved_textures
	return result


func _resolve_resource_path(base_dir: String, raw_path: String) -> String:
	if raw_path == "":
		return ""
	if raw_path.begins_with("res://") or raw_path.begins_with("user://") or _is_absolute_filesystem_path(raw_path):
		return raw_path
	return "%s/%s" % [base_dir, raw_path]


func _resolve_path(base_dir: String, relative_path: String) -> String:
	return _resolve_resource_path(base_dir, relative_path)


func _is_absolute_filesystem_path(path: String) -> bool:
	if path.begins_with("/") or path.begins_with("\\"):
		return true
	return path.length() >= 3 and (path.substr(1, 2) == ":\\" or path.substr(1, 2) == ":/")


func _to_array(value: Variant) -> Array:
	if value is Array:
		return value as Array
	if value is PackedStringArray:
		var result: Array = []
		for item in (value as PackedStringArray):
			result.append(item)
		return result
	if value == null:
		return []
	return [value]


func _collect_ordered_defs(order: Array[StringName], target: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition_id in order:
		var definition: Dictionary = _get_def(target, definition_id)
		if definition.is_empty():
			continue
		result.append(definition)
	return result


func _get_def(target: Dictionary, definition_id: StringName) -> Dictionary:
	var definition: Dictionary = target.get(definition_id, {}) as Dictionary
	if definition == null:
		return {}
	return definition.duplicate(true)


func _push_diagnostic(
	level: StringName,
	content_kind: String,
	definition_id: String,
	mod_id: String,
	code: String,
	extra: Dictionary = {}
) -> void:
	var diagnostic: Dictionary = {
		"level": String(level),
		"content_kind": content_kind,
		"definition_id": definition_id,
		"mod_id": mod_id,
		"code": code
	}
	for key in extra.keys():
		diagnostic[key] = extra[key]
	_diagnostics.append(diagnostic)
