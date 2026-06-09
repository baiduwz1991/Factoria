class_name PlanetController
extends BaseController

const CONTROLLER_ID: StringName = &"planet_controller"
const ERROR_SAVE_MANAGER_MISSING: StringName = &"save_manager_missing"
const ERROR_PLANET_PRESET_INVALID: StringName = &"planet_preset_invalid"
const SAFE_SPAWN_SEARCH_RADIUS_TILES: int = 96
const SAFE_SPAWN_PLATFORM_RADIUS_TILES: int = 1
const INVALID_SPAWN_TILE: Vector2i = Vector2i(2147483647, 2147483647)

signal planet_loading_changed(snapshot: Dictionary)

var _save_data: PlanetSaveData = PlanetSaveData.new()
var _chunk_store: MapChunkStore = MapChunkStore.new()
var _chunk_cache: MapChunkCache = MapChunkCache.new()
var _terrain_catalog: TerrainCatalog = TerrainCatalog.new()
var _autoplace_catalog: TerrainAutoplaceCatalog = TerrainAutoplaceCatalog.new()
var _preset_catalog: PlanetPresetCatalog = PlanetPresetCatalog.new()
var _runtime_ready: bool = false
var _runtime_slot_id: int = 0
var _runtime_seed: int = 0
var _runtime_chunk_size: int = 0
var _runtime_preset_id: StringName = &""


func get_id() -> StringName:
	return CONTROLLER_ID


func get_save_scope() -> StringName:
	return SAVE_SCOPE_SLOT


func get_save_module_version() -> int:
	return 1


func get_planet_preset_options() -> Array[Dictionary]:
	return _preset_catalog.get_options()


func create_planet_for_slot(slot_id: int, planet_preset_id: StringName, planet_seed: int) -> Dictionary:
	if not _preset_catalog.has_preset(planet_preset_id):
		return _build_error_result(ERROR_PLANET_PRESET_INVALID, {
			"planet_preset_id": String(planet_preset_id)
		})

	var save_manager: Node = _get_save_manager()
	if save_manager == null:
		return _build_error_result(ERROR_SAVE_MANAGER_MISSING, {})

	var preset: PlanetPresetDef = _preset_catalog.get_preset(planet_preset_id)
	_save_data.apply_chunked_planet(
		slot_id,
		planet_preset_id,
		planet_seed,
		MapChunkGenerator.GENERATION_VERSION,
		MapChunkGenerator.DEFAULT_CHUNK_SIZE,
		MapChunkGenerator.DEFAULT_TILE_SIZE,
		Vector2i.ZERO,
		preset.surface_properties
	)
	_runtime_ready = false
	_setup_runtime(save_manager)
	_chunk_store.delete_all_chunks()
	return {
		"ok": true,
		"planet": _save_data.to_dict()
	}


func get_planet_snapshot() -> Dictionary:
	return _save_data.to_dict()


func get_runtime_snapshot() -> Dictionary:
	return {
		"storage_format": String(_save_data.storage_format),
		"planet_seed": _save_data.planet_seed,
		"generation_version": _save_data.generation_version,
		"chunk_size": _save_data.chunk_size,
		"tile_size": _save_data.tile_size,
		"planet_preset_id": String(_save_data.planet_preset_id),
		"surface_properties": _save_data.surface_properties.duplicate(true),
		"generated_chunk_count": _chunk_cache.get_generated_chunk_count(),
		"dirty_chunk_count": _chunk_cache.get_dirty_chunk_count()
	}


func get_chunk_size() -> int:
	return _save_data.chunk_size


func get_tile_size() -> int:
	return _save_data.tile_size


func get_or_generate_chunk(chunk_coord: Vector2i) -> MapChunkData:
	_ensure_runtime()
	return _chunk_cache.get_or_generate_chunk(chunk_coord)


func sample_terrain_id_for_render(global_tile: Vector2i) -> int:
	_ensure_runtime()
	return _chunk_cache.sample_terrain_id_for_render(global_tile)


func unload_chunks_except(chunk_coords: Array[Vector2i]) -> void:
	_ensure_runtime()
	_chunk_cache.unload_chunks_except(chunk_coords)


func flush_dirty_chunks() -> Dictionary:
	_ensure_runtime()
	var result: Dictionary = _chunk_cache.flush_dirty_chunks()
	_save_data.apply_runtime_stats(
		_chunk_cache.get_generated_chunk_count(),
		_chunk_cache.get_dirty_chunk_count()
	)
	planet_loading_changed.emit(get_runtime_snapshot())
	return result


func get_terrain_catalog() -> TerrainCatalog:
	return _terrain_catalog


func resolve_safe_spawn_position(preferred_position: Vector2) -> Vector2:
	_ensure_runtime()
	var tile_size: int = get_tile_size()
	var preferred_tile: Vector2i = _planet_position_to_tile_coord(preferred_position, tile_size)
	if _is_safe_spawn_tile(preferred_tile, SAFE_SPAWN_PLATFORM_RADIUS_TILES):
		return preferred_position

	var safe_tile: Vector2i = _find_nearest_walkable_tile(preferred_tile, SAFE_SPAWN_SEARCH_RADIUS_TILES)
	if safe_tile == INVALID_SPAWN_TILE:
		_force_spawn_area_walkable(preferred_tile, SAFE_SPAWN_PLATFORM_RADIUS_TILES)
		return _tile_coord_to_planet_position(preferred_tile, tile_size)
	return _tile_coord_to_planet_position(safe_tile, tile_size)


func landfill_tile(global_tile: Vector2i) -> bool:
	_ensure_runtime()
	var chunk_size: int = get_chunk_size()
	var chunk_coord: Vector2i = _global_tile_to_chunk_coord(global_tile, chunk_size)
	var chunk: MapChunkData = get_or_generate_chunk(chunk_coord)
	if chunk == null:
		return false

	var local_tile: Vector2i = _global_tile_to_local_coord(global_tile, chunk_coord, chunk_size)
	var current_terrain_id: int = chunk.get_terrain_id(local_tile.x, local_tile.y)
	if not _terrain_catalog.is_water(current_terrain_id):
		return false

	var base_soil_id: int = _terrain_catalog.get_base_soil_id()
	chunk.set_terrain_id(
		local_tile.x,
		local_tile.y,
		base_soil_id,
		_terrain_catalog.get_map_color(base_soil_id)
	)
	_chunk_cache.mark_dirty(chunk_coord)
	planet_loading_changed.emit(get_runtime_snapshot())
	return true


func on_save_flush() -> void:
	flush_dirty_chunks()


func export_save_data() -> Dictionary:
	_save_data.apply_runtime_stats(
		_chunk_cache.get_generated_chunk_count(),
		_chunk_cache.get_dirty_chunk_count()
	)
	return _save_data.to_dict()


func import_save_data(payload: Dictionary) -> bool:
	if payload.is_empty():
		_save_data.clear()
		_runtime_ready = false
		return true
	_save_data.from_dict(payload)
	_runtime_ready = false
	_ensure_runtime()
	return true


func get_save_meta_fragment() -> Dictionary:
	var preset: PlanetPresetDef = _preset_catalog.get_preset(_save_data.planet_preset_id)
	var planet_preset_label: String = preset.label if preset != null else ""
	return {
		"planet_preset_id": String(_save_data.planet_preset_id),
		"planet_preset_label": planet_preset_label,
		"planet_seed": _save_data.planet_seed,
		"storage_format": String(_save_data.storage_format),
		"generation_version": _save_data.generation_version,
		"chunk_size": _save_data.chunk_size,
		"generated_chunk_count": _chunk_cache.get_generated_chunk_count()
	}


func _ensure_runtime() -> void:
	var save_manager: Node = _get_save_manager()
	if save_manager != null:
		_setup_runtime(save_manager)


func _setup_runtime(save_manager: Node) -> void:
	if (
		_runtime_ready
		and _runtime_slot_id == _save_data.slot_id
		and _runtime_seed == _save_data.planet_seed
		and _runtime_chunk_size == _save_data.chunk_size
		and _runtime_preset_id == _save_data.planet_preset_id
	):
		return
	_chunk_store.setup(_save_data.slot_id, save_manager)
	_chunk_cache.setup(
		_save_data.planet_seed,
		_save_data.chunk_size,
		_chunk_store,
		_terrain_catalog,
		_autoplace_catalog,
		_preset_catalog.get_preset(_save_data.planet_preset_id)
	)
	_runtime_ready = true
	_runtime_slot_id = _save_data.slot_id
	_runtime_seed = _save_data.planet_seed
	_runtime_chunk_size = _save_data.chunk_size
	_runtime_preset_id = _save_data.planet_preset_id


func _global_tile_to_chunk_coord(global_tile: Vector2i, chunk_size: int) -> Vector2i:
	var safe_chunk_size: int = maxi(chunk_size, 1)
	return Vector2i(
		floori(float(global_tile.x) / float(safe_chunk_size)),
		floori(float(global_tile.y) / float(safe_chunk_size))
	)


func _global_tile_to_local_coord(global_tile: Vector2i, chunk_coord: Vector2i, chunk_size: int) -> Vector2i:
	var safe_chunk_size: int = maxi(chunk_size, 1)
	return Vector2i(
		global_tile.x - chunk_coord.x * safe_chunk_size,
		global_tile.y - chunk_coord.y * safe_chunk_size
	)


func _planet_position_to_tile_coord(planet_position: Vector2, tile_size: int) -> Vector2i:
	var safe_tile_size: float = float(maxi(tile_size, 1))
	return Vector2i(
		floori(planet_position.x / safe_tile_size),
		floori(planet_position.y / safe_tile_size)
	)


func _tile_coord_to_planet_position(tile_coord: Vector2i, tile_size: int) -> Vector2:
	var safe_tile_size: float = float(maxi(tile_size, 1))
	return Vector2(
		(float(tile_coord.x) + 0.5) * safe_tile_size,
		(float(tile_coord.y) + 0.5) * safe_tile_size
	)


func _find_nearest_walkable_tile(preferred_tile: Vector2i, search_radius_tiles: int) -> Vector2i:
	if _is_safe_spawn_tile(preferred_tile, SAFE_SPAWN_PLATFORM_RADIUS_TILES):
		return preferred_tile

	var safe_radius: int = maxi(search_radius_tiles, 0)
	for radius in range(1, safe_radius + 1):
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				if absi(offset_x) != radius and absi(offset_y) != radius:
					continue
				var candidate_tile: Vector2i = preferred_tile + Vector2i(offset_x, offset_y)
				if _is_safe_spawn_tile(candidate_tile, SAFE_SPAWN_PLATFORM_RADIUS_TILES):
					return candidate_tile
	return INVALID_SPAWN_TILE


func _is_safe_spawn_tile(global_tile: Vector2i, radius_tiles: int) -> bool:
	var safe_radius: int = maxi(radius_tiles, 0)
	for offset_y in range(-safe_radius, safe_radius + 1):
		for offset_x in range(-safe_radius, safe_radius + 1):
			if not _is_walkable_tile(global_tile + Vector2i(offset_x, offset_y)):
				return false
	return true


func _is_walkable_tile(global_tile: Vector2i) -> bool:
	return _terrain_catalog.is_walkable(sample_terrain_id_for_render(global_tile))


func _force_spawn_area_walkable(global_tile: Vector2i, radius_tiles: int) -> Vector2i:
	var chunk_size: int = get_chunk_size()
	var base_soil_id: int = _terrain_catalog.get_base_soil_id()
	var base_soil_color: int = _terrain_catalog.get_map_color(base_soil_id)
	var safe_radius: int = maxi(radius_tiles, 0)
	for offset_y in range(-safe_radius, safe_radius + 1):
		for offset_x in range(-safe_radius, safe_radius + 1):
			var tile: Vector2i = global_tile + Vector2i(offset_x, offset_y)
			var chunk_coord: Vector2i = _global_tile_to_chunk_coord(tile, chunk_size)
			var chunk: MapChunkData = get_or_generate_chunk(chunk_coord)
			if chunk == null:
				continue

			var local_tile: Vector2i = _global_tile_to_local_coord(tile, chunk_coord, chunk_size)
			chunk.set_terrain_id(
				local_tile.x,
				local_tile.y,
				base_soil_id,
				base_soil_color
			)
			_chunk_cache.mark_dirty(chunk_coord)
	return global_tile


func _build_error_result(error_code: StringName, extra: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"error_code": error_code
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result
