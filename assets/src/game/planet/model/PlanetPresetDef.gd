class_name PlanetPresetDef
extends RefCounted

#region 状态
var id: StringName = &"standard"
var label: String = "标准"
var description: String = ""
var terrain_ids: Array[StringName] = []
var decorative_ids: Array[StringName] = []
var resource_ids: Array[StringName] = []
var entity_ids: Array[StringName] = []
var autoplace_controls: Dictionary = {}
var climate_controls: Dictionary = {}
var surface_properties: Dictionary = {}
#endregion

#region 对外接口 - 序列化
func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"label": label,
		"description": description,
		"terrain_ids": SerializeUtils.string_name_array_to_strings(terrain_ids),
		"decorative_ids": SerializeUtils.string_name_array_to_strings(decorative_ids),
		"resource_ids": SerializeUtils.string_name_array_to_strings(resource_ids),
		"entity_ids": SerializeUtils.string_name_array_to_strings(entity_ids),
		"autoplace_controls": autoplace_controls.duplicate(true),
		"climate_controls": climate_controls.duplicate(true),
		"surface_properties": surface_properties.duplicate(true)
	}
#endregion
