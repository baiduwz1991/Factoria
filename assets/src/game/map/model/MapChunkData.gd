class_name MapChunkData
extends RefCounted

var chunk_coord: Vector2i = Vector2i.ZERO
var generation_version: int = 1
var chunk_size: int = 32
var tiles: PackedInt32Array = PackedInt32Array()
var resources: Array[Dictionary] = []
var entities: Array[Dictionary] = []
var minimap_colors: PackedInt32Array = PackedInt32Array()
var charted_mask: PackedByteArray = PackedByteArray()
var explored_mask: PackedByteArray = PackedByteArray()
var dirty: bool = false


func setup(next_chunk_coord: Vector2i, next_generation_version: int, next_chunk_size: int) -> void:
	chunk_coord = next_chunk_coord
	generation_version = maxi(next_generation_version, 1)
	chunk_size = maxi(next_chunk_size, 1)
	_ensure_buffer_sizes()


func get_terrain_id(local_x: int, local_y: int) -> int:
	var index: int = _to_index(local_x, local_y)
	if index < 0 or index >= tiles.size():
		return 0
	return tiles[index]


func set_terrain_id(local_x: int, local_y: int, terrain_id: int, minimap_color: int = -1) -> void:
	var index: int = _to_index(local_x, local_y)
	if index < 0 or index >= tiles.size():
		return
	tiles[index] = terrain_id
	if minimap_color >= 0 and index < minimap_colors.size():
		minimap_colors[index] = minimap_color
	dirty = true


func get_tile(local_x: int, local_y: int) -> int:
	return get_terrain_id(local_x, local_y)


func set_tile(local_x: int, local_y: int, tile_id: int) -> void:
	set_terrain_id(local_x, local_y, tile_id)


func to_dict() -> Dictionary:
	return {
		"chunk_coord": SerializeUtils.vector2i_to_dict(chunk_coord),
		"generation_version": generation_version,
		"chunk_size": chunk_size,
		"tiles": SerializeUtils.packed_int32_to_array(tiles),
		"resources": resources.duplicate(true),
		"entities": entities.duplicate(true),
		"minimap_colors": SerializeUtils.packed_int32_to_array(minimap_colors),
		"charted_mask": SerializeUtils.packed_byte_to_array(charted_mask),
		"explored_mask": SerializeUtils.packed_byte_to_array(explored_mask)
	}


func from_dict(raw: Dictionary) -> void:
	var raw_generation_version: int = int(raw.get("generation_version", generation_version))
	chunk_coord = SerializeUtils.parse_vector2i(raw.get("chunk_coord", chunk_coord), chunk_coord)
	generation_version = raw_generation_version
	chunk_size = int(raw.get("chunk_size", chunk_size))
	tiles = SerializeUtils.parse_packed_int32(raw.get("tiles", []))
	resources = SerializeUtils.parse_dictionary_array(raw.get("resources", []))
	entities = SerializeUtils.parse_dictionary_array(raw.get("entities", []))
	minimap_colors = SerializeUtils.parse_packed_int32(raw.get("minimap_colors", []))
	charted_mask = SerializeUtils.parse_packed_byte(raw.get("charted_mask", []))
	explored_mask = SerializeUtils.parse_packed_byte(raw.get("explored_mask", []))
	dirty = false
	_ensure_buffer_sizes()
	if raw_generation_version < 5:
		_migrate_legacy_terrain_ids()


func _ensure_buffer_sizes() -> void:
	var tile_count: int = chunk_size * chunk_size
	if tiles.size() != tile_count:
		tiles.resize(tile_count)
	if minimap_colors.size() != tile_count:
		minimap_colors.resize(tile_count)
	if charted_mask.size() != tile_count:
		charted_mask.resize(tile_count)
	if explored_mask.size() != tile_count:
		explored_mask.resize(tile_count)


func _to_index(local_x: int, local_y: int) -> int:
	if local_x < 0 or local_x >= chunk_size:
		return -1
	if local_y < 0 or local_y >= chunk_size:
		return -1
	return local_y * chunk_size + local_x


func _migrate_legacy_terrain_ids() -> void:
	for index in range(tiles.size()):
		var terrain_id: int = _migrate_legacy_terrain_id(tiles[index])
		tiles[index] = terrain_id
		if index < minimap_colors.size():
			minimap_colors[index] = _get_migrated_map_color(terrain_id)
	dirty = true


func _migrate_legacy_terrain_id(legacy_id: int) -> int:
	match legacy_id:
		45:
			return TerrainCatalog.TERRAIN_GRASS
		57:
			return TerrainCatalog.TERRAIN_DIRT
		59:
			return TerrainCatalog.TERRAIN_WATER
		1, 2:
			return TerrainCatalog.TERRAIN_GRASS
		3, 4, 5:
			return TerrainCatalog.TERRAIN_DIRT
		6:
			return TerrainCatalog.TERRAIN_SAND
		7:
			return TerrainCatalog.TERRAIN_BASE_SOIL
		8:
			return TerrainCatalog.TERRAIN_WATER
		9:
			return TerrainCatalog.TERRAIN_DEEP_WATER
		_:
			return TerrainCatalog.TERRAIN_BASE_SOIL


func _get_migrated_map_color(terrain_id: int) -> int:
	if terrain_id == TerrainCatalog.TERRAIN_DIRT:
		return 0x825836
	if terrain_id == TerrainCatalog.TERRAIN_GRASS:
		return 0x699737
	if terrain_id == TerrainCatalog.TERRAIN_SAND:
		return 0xcab064
	if terrain_id == TerrainCatalog.TERRAIN_WATER:
		return 0x3193ae
	if terrain_id == TerrainCatalog.TERRAIN_DEEP_WATER:
		return 0x185584
	return 0x603025
