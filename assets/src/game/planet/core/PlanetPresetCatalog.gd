class_name PlanetPresetCatalog
extends RefCounted

const PRESET_STANDARD: StringName = &"core.standard"
const PRESET_RICH_RESOURCE: StringName = &"core.rich_resource"
const PRESET_DESERT: StringName = &"core.desert"

var _presets_by_id: Dictionary = {}
var _alias_to_id: Dictionary = {}
var _ordered_ids: Array[StringName] = []


func _init() -> void:
	var registry: GameDataRegistry = _get_registry()
	if registry != null and not registry.get_planet_preset_defs().is_empty():
		_register_registry_presets(registry)
	else:
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
	return _presets_by_id.has(_resolve_preset_id(preset_id))


func get_preset(preset_id: StringName) -> PlanetPresetDef:
	var resolved_id: StringName = _resolve_preset_id(preset_id)
	var preset: PlanetPresetDef = _presets_by_id.get(resolved_id, null) as PlanetPresetDef
	if preset != null:
		return preset
	return _presets_by_id.get(PRESET_STANDARD, null) as PlanetPresetDef


func _register_registry_presets(registry: GameDataRegistry) -> void:
	for raw_preset in registry.get_planet_preset_defs():
		var preset: PlanetPresetDef = _build_preset_from_dict(raw_preset)
		_register(preset, _parse_aliases(raw_preset.get("aliases", []), preset.id))


func _build_preset_from_dict(raw: Dictionary) -> PlanetPresetDef:
	return _build_preset(
		StringName(raw.get("id", "")),
		str(raw.get("label", raw.get("id", ""))),
		str(raw.get("description", "")),
		_parse_string_name_array(raw.get("terrain_ids", [])),
		_parse_string_name_array(raw.get("decorative_ids", [])),
		_parse_string_name_array(raw.get("resource_ids", [])),
		_parse_string_name_array(raw.get("entity_ids", [])),
		(raw.get("autoplace_controls", {}) as Dictionary).duplicate(true),
		(raw.get("climate_controls", {}) as Dictionary).duplicate(true),
		(raw.get("surface_properties", {}) as Dictionary).duplicate(true)
	)


func _register_default_presets() -> void:
	_register(_build_preset(
		PRESET_STANDARD,
		"Standard",
		"Balanced test planet with base soil, dirt, grass, sand, water, and deep water.",
		[TerrainCatalog.ID_BASE_SOIL, TerrainCatalog.ID_DIRT, TerrainCatalog.ID_GRASS, TerrainCatalog.ID_SAND, TerrainCatalog.ID_WATER, TerrainCatalog.ID_DEEP_WATER],
		[&"green_small_grass", &"brown_carpet_grass", &"small_rock"],
		[&"iron_ore", &"copper_ore", &"coal", &"stone", &"crude_oil"],
		[&"fish", &"big_rock"],
		{&"water": 1.0, &"trees": 1.0, &"rocks": 1.0, &"enemy_base": 1.0},
		{&"aux": true, &"moisture": true},
		_build_surface_properties(10, 1000, 90, 100, 7 * 60)
	), [&"standard"])
	_register(_build_preset(
		PRESET_RICH_RESOURCE,
		"Rich Resource",
		"Resource-rich planet for fast factory validation.",
		[TerrainCatalog.ID_BASE_SOIL, TerrainCatalog.ID_DIRT, TerrainCatalog.ID_GRASS, TerrainCatalog.ID_SAND, TerrainCatalog.ID_WATER, TerrainCatalog.ID_DEEP_WATER],
		[&"green_small_grass", &"small_rock"],
		[&"iron_ore", &"copper_ore", &"coal", &"stone", &"crude_oil", &"uranium_ore"],
		[&"fish", &"big_rock"],
		{&"water": 0.9, &"trees": 0.8, &"rocks": 1.0, &"enemy_base": 0.6, &"resources": 1.8},
		{&"aux": true, &"moisture": true},
		_build_surface_properties(10, 1000, 90, 100, 7 * 60)
	), [&"rich_resource"])
	_register(_build_preset(
		PRESET_DESERT,
		"Desert",
		"Drier planet with less water and vegetation.",
		[TerrainCatalog.ID_BASE_SOIL, TerrainCatalog.ID_DIRT, TerrainCatalog.ID_SAND, TerrainCatalog.ID_WATER, TerrainCatalog.ID_DEEP_WATER],
		[&"sand_decal", &"small_sand_rock", &"dry_bush"],
		[&"iron_ore", &"copper_ore", &"coal", &"stone", &"crude_oil"],
		[&"big_sand_rock", &"huge_rock"],
		{&"water": 0.35, &"trees": 0.2, &"rocks": 1.3, &"enemy_base": 1.1},
		{&"aux": true, &"moisture": true, &"moisture_bias": -0.35},
		_build_surface_properties(10, 950, 90, 115, 7 * 60)
	), [&"desert"])


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


func _register(preset: PlanetPresetDef, aliases: Array[StringName] = []) -> void:
	if preset == null or preset.id == StringName():
		return
	if _presets_by_id.has(preset.id):
		_ordered_ids.erase(preset.id)
	_presets_by_id[preset.id] = preset
	_ordered_ids.append(preset.id)
	_alias_to_id[preset.id] = preset.id
	for alias in aliases:
		if alias != StringName():
			_alias_to_id[alias] = preset.id


func _resolve_preset_id(preset_id: StringName) -> StringName:
	if _alias_to_id.has(preset_id):
		return _alias_to_id[preset_id]
	var preset_text: String = String(preset_id)
	if not preset_text.contains("."):
		var core_id: StringName = StringName("core.%s" % preset_text)
		if _presets_by_id.has(core_id):
			return core_id
	return preset_id


func _parse_aliases(value: Variant, stable_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for raw_alias in (value as Array):
			var alias: StringName = StringName(raw_alias)
			if alias != StringName() and not result.has(alias):
				result.append(alias)
	var stable_text: String = String(stable_id)
	var local_name: String = stable_text.get_slice(".", stable_text.get_slice_count(".") - 1)
	var local_alias: StringName = StringName(local_name)
	if local_alias != StringName() and not result.has(local_alias):
		result.append(local_alias)
	return result


func _parse_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not (value is Array):
		return result
	for raw_item in (value as Array):
		var item: StringName = StringName(raw_item)
		if item != StringName():
			result.append(item)
	return result


func _get_registry() -> GameDataRegistry:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null or scene_tree.root == null:
		return null
	var mod_manager: Node = scene_tree.root.get_node_or_null("ModManager")
	if mod_manager == null or not mod_manager.has_method("get_registry"):
		return null
	return mod_manager.call("get_registry") as GameDataRegistry
