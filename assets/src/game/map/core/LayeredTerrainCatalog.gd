class_name LayeredTerrainCatalog
extends RefCounted

const SOURCE_TILE_SIZE: int = 64
const TERRAIN_TEXTURE_ROOT: String = "res://assets/texture/terrain"

var _sheet_defs: Array[Dictionary] = []
var _visual_by_terrain_id: Dictionary = {}


func _init() -> void:
	_register_default_visual_terrains()
	_register_default_sheets()


func get_source_tile_size() -> int:
	return SOURCE_TILE_SIZE


func get_sheet_defs() -> Array[Dictionary]:
	return _sheet_defs.duplicate(true)


func get_visual_terrain(terrain_id: int) -> StringName:
	return _visual_by_terrain_id.get(terrain_id, &"base_soil") as StringName


func is_water_visual(visual: StringName) -> bool:
	return visual == &"water" or visual == &"deep_water"


func _register_default_visual_terrains() -> void:
	_visual_by_terrain_id[TerrainCatalog.TERRAIN_BASE_SOIL] = &"base_soil"
	_visual_by_terrain_id[TerrainCatalog.TERRAIN_DIRT] = &"dirt"
	_visual_by_terrain_id[TerrainCatalog.TERRAIN_GRASS] = &"grass"
	_visual_by_terrain_id[TerrainCatalog.TERRAIN_SAND] = &"sand"
	_visual_by_terrain_id[TerrainCatalog.TERRAIN_WATER] = &"water"
	_visual_by_terrain_id[TerrainCatalog.TERRAIN_DEEP_WATER] = &"deep_water"
	_visual_by_terrain_id[TerrainCatalog.TERRAIN_DRY_GRASS] = &"dry_grass"
	_visual_by_terrain_id[TerrainCatalog.TERRAIN_DRY_DIRT] = &"dry_dirt"
	_visual_by_terrain_id[TerrainCatalog.TERRAIN_RED_DESERT] = &"red_desert"
	_visual_by_terrain_id[TerrainCatalog.TERRAIN_STONE_GROUND] = &"stone_ground"


func _register_default_sheets() -> void:
	_register_base_sheet(&"base_soil")
	_register_base_sheet(&"dirt")
	_register_base_sheet(&"grass")
	_register_base_sheet(&"sand")
	_register_base_sheet(&"water")
	_register_base_sheet(&"deep_water")
	_register_base_sheet(&"dry_grass")
	_register_base_sheet(&"dry_dirt")
	_register_base_sheet(&"red_desert")
	_register_base_sheet(&"stone_ground")


func _register_base_sheet(visual: StringName) -> void:
	_sheet_defs.append({
		"kind": &"base",
		"visual": visual,
		"texture_path": "%s/%s/base/1x1.png" % [TERRAIN_TEXTURE_ROOT, String(visual)]
	})
