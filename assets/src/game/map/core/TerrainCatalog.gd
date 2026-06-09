class_name TerrainCatalog
extends RefCounted

const TERRAIN_BASE_SOIL: int = 1
const TERRAIN_DIRT: int = 2
const TERRAIN_GRASS: int = 3
const TERRAIN_SAND: int = 4
const TERRAIN_WATER: int = 5
const TERRAIN_DEEP_WATER: int = 6

var _by_numeric_id: Dictionary = {}
var _by_id: Dictionary = {}
var _all: Array[TerrainDef] = []


func _init() -> void:
	_register_default_terrains()


func get_all() -> Array[TerrainDef]:
	return _all.duplicate()


func get_by_numeric_id(numeric_id: int) -> TerrainDef:
	var terrain: TerrainDef = _by_numeric_id.get(numeric_id, null) as TerrainDef
	if terrain != null:
		return terrain
	return _by_numeric_id.get(TERRAIN_BASE_SOIL, null) as TerrainDef


func get_by_id(id: StringName) -> TerrainDef:
	var terrain: TerrainDef = _by_id.get(id, null) as TerrainDef
	if terrain != null:
		return terrain
	return get_by_numeric_id(TERRAIN_BASE_SOIL)


func get_default_terrain_id() -> int:
	return TERRAIN_BASE_SOIL


func get_base_soil_id() -> int:
	return TERRAIN_BASE_SOIL


func get_map_color(numeric_id: int) -> int:
	var terrain: TerrainDef = get_by_numeric_id(numeric_id)
	if terrain == null:
		return 0xffffff
	return terrain.map_color


func is_walkable(numeric_id: int) -> bool:
	var terrain: TerrainDef = get_by_numeric_id(numeric_id)
	return terrain != null and terrain.walkable


func is_buildable(numeric_id: int) -> bool:
	var terrain: TerrainDef = get_by_numeric_id(numeric_id)
	return terrain != null and terrain.buildable


func is_water(numeric_id: int) -> bool:
	var terrain: TerrainDef = get_by_numeric_id(numeric_id)
	return terrain != null and terrain.is_water


func _register_default_terrains() -> void:
	_register(_build_terrain(
		TERRAIN_BASE_SOIL,
		&"base_soil",
		"底层地表",
		0x603025,
		true,
		true,
		false
	))
	_register(_build_terrain(
		TERRAIN_DIRT,
		&"dirt",
		"土地",
		0x825836,
		true,
		true,
		false
	))
	_register(_build_terrain(
		TERRAIN_GRASS,
		&"grass",
		"草地",
		0x699737,
		true,
		true,
		false
	))
	_register(_build_terrain(
		TERRAIN_SAND,
		&"sand",
		"沙地",
		0xcab064,
		true,
		true,
		false
	))
	_register(_build_terrain(
		TERRAIN_WATER,
		&"water",
		"水",
		0x3193ae,
		false,
		false,
		true
	))
	_register(_build_terrain(
		TERRAIN_DEEP_WATER,
		&"deep_water",
		"深水",
		0x185584,
		false,
		false,
		true
	))


func _build_terrain(
	numeric_id: int,
	id: StringName,
	display_name: String,
	map_color: int,
	walkable: bool,
	buildable: bool,
	is_water: bool
) -> TerrainDef:
	var terrain: TerrainDef = TerrainDef.new()
	terrain.numeric_id = numeric_id
	terrain.id = id
	terrain.display_name = display_name
	terrain.map_color = map_color
	terrain.walkable = walkable
	terrain.buildable = buildable
	terrain.is_water = is_water
	return terrain


func _register(terrain: TerrainDef) -> void:
	if terrain == null:
		return
	_by_numeric_id[terrain.numeric_id] = terrain
	_by_id[terrain.id] = terrain
	_all.append(terrain)
