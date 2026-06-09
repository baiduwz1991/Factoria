class_name PlanetPresetCatalog
extends RefCounted

const PRESET_STANDARD: StringName = &"standard"
const PRESET_RICH_RESOURCE: StringName = &"rich_resource"
const PRESET_DESERT: StringName = &"desert"

var _presets_by_id: Dictionary = {}
var _ordered_ids: Array[StringName] = []


func _init() -> void:
	_register_default_presets()


func get_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for preset_id in _ordered_ids:
		var preset: PlanetPresetDef = get_preset(preset_id)
		if preset == null:
			continue
		var snapshot: Dictionary = preset.to_dict()
		snapshot["width"] = 0
		snapshot["height"] = 0
		result.append(snapshot)
	return result


func has_preset(preset_id: StringName) -> bool:
	return _presets_by_id.has(preset_id)


func get_preset(preset_id: StringName) -> PlanetPresetDef:
	var preset: PlanetPresetDef = _presets_by_id.get(preset_id, null) as PlanetPresetDef
	if preset != null:
		return preset
	return _presets_by_id.get(PRESET_STANDARD, null) as PlanetPresetDef


func _register_default_presets() -> void:
	_register(_build_preset(
		PRESET_STANDARD,
		"标准",
		"均衡的测试星球，包含底层地表、土地、草地、沙地和水域。",
		[&"base_soil", &"dirt", &"grass", &"sand", &"water", &"deep_water"],
		[&"green_small_grass", &"brown_carpet_grass", &"small_rock"],
		[&"iron_ore", &"copper_ore", &"coal", &"stone", &"crude_oil"],
		[&"fish", &"big_rock"],
		{
			&"water": 1.0,
			&"trees": 1.0,
			&"rocks": 1.0,
			&"enemy_base": 1.0
		},
		{
			&"aux": true,
			&"moisture": true
		},
		_build_surface_properties(10, 1000, 90, 100, 7 * 60)
	))
	_register(_build_preset(
		PRESET_RICH_RESOURCE,
		"富资源",
		"资源更丰厚，适合快速验证工厂系统。",
		[&"base_soil", &"dirt", &"grass", &"sand", &"water", &"deep_water"],
		[&"green_small_grass", &"small_rock"],
		[&"iron_ore", &"copper_ore", &"coal", &"stone", &"crude_oil", &"uranium_ore"],
		[&"fish", &"big_rock"],
		{
			&"water": 0.9,
			&"trees": 0.8,
			&"rocks": 1.0,
			&"enemy_base": 0.6,
			&"resources": 1.8
		},
		{
			&"aux": true,
			&"moisture": true
		},
		_build_surface_properties(10, 1000, 90, 100, 7 * 60)
	))
	_register(_build_preset(
		PRESET_DESERT,
		"荒芜",
		"水和植被更少，底层地表与沙地更多。",
		[&"base_soil", &"dirt", &"sand", &"water", &"deep_water"],
		[&"sand_decal", &"small_sand_rock", &"dry_bush"],
		[&"iron_ore", &"copper_ore", &"coal", &"stone", &"crude_oil"],
		[&"big_sand_rock", &"huge_rock"],
		{
			&"water": 0.35,
			&"trees": 0.2,
			&"rocks": 1.3,
			&"enemy_base": 1.1
		},
		{
			&"aux": true,
			&"moisture": true,
			&"moisture_bias": -0.35
		},
		_build_surface_properties(10, 950, 90, 115, 7 * 60)
	))


func _build_preset(
	id: StringName,
	label: String,
	description: String,
	terrain_ids: Array[StringName],
	decorative_ids: Array[StringName],
	resource_ids: Array[StringName],
	entity_ids: Array[StringName],
	autoplace_controls: Dictionary,
	climate_controls: Dictionary,
	surface_properties: Dictionary
) -> PlanetPresetDef:
	var preset: PlanetPresetDef = PlanetPresetDef.new()
	preset.id = id
	preset.label = label
	preset.description = description
	preset.terrain_ids = terrain_ids.duplicate()
	preset.decorative_ids = decorative_ids.duplicate()
	preset.resource_ids = resource_ids.duplicate()
	preset.entity_ids = entity_ids.duplicate()
	preset.autoplace_controls = autoplace_controls.duplicate(true)
	preset.climate_controls = climate_controls.duplicate(true)
	preset.surface_properties = surface_properties.duplicate(true)
	return preset


func _build_surface_properties(
	gravity: int,
	pressure: int,
	magnetic_field: int,
	solar_power: int,
	day_night_cycle: int
) -> Dictionary:
	return {
		"gravity": gravity,
		"pressure": pressure,
		"magnetic_field": magnetic_field,
		"solar_power": solar_power,
		"day_night_cycle": day_night_cycle
	}


func _register(preset: PlanetPresetDef) -> void:
	if preset == null:
		return
	_presets_by_id[preset.id] = preset
	_ordered_ids.append(preset.id)
