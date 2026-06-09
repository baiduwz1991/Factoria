class_name MapChunkCache
extends RefCounted

const READONLY_SAMPLE_CACHE_SIZE: int = 32

var _planet_seed: int = 0
var _chunk_size: int = MapChunkGenerator.DEFAULT_CHUNK_SIZE
var _generator: MapChunkGenerator = MapChunkGenerator.new()
var _store: MapChunkStore = null
var _chunks: Dictionary = {}
var _dirty_chunk_keys: Dictionary = {}
var _generated_chunk_keys: Dictionary = {}
var _readonly_sample_chunks: Dictionary = {}
var _readonly_sample_order: Array[String] = []


func setup(
	planet_seed: int,
	chunk_size: int,
	store: MapChunkStore,
	terrain_catalog: TerrainCatalog = null,
	autoplace_catalog: TerrainAutoplaceCatalog = null,
	planet_preset: PlanetPresetDef = null
) -> void:
	_planet_seed = planet_seed
	_chunk_size = maxi(chunk_size, 1)
	_store = store
	_generator.setup(terrain_catalog, autoplace_catalog, planet_preset)
	_chunks.clear()
	_dirty_chunk_keys.clear()
	_generated_chunk_keys.clear()
	_readonly_sample_chunks.clear()
	_readonly_sample_order.clear()


func get_or_generate_chunk(chunk_coord: Vector2i) -> MapChunkData:
	var key: String = _coord_to_key(chunk_coord)
	if _chunks.has(key):
		_forget_readonly_sample_chunk(key)
		return _chunks[key] as MapChunkData

	var chunk: MapChunkData = null
	var replacing_stale_chunk: bool = false
	if _store != null:
		chunk = _store.load_chunk(chunk_coord)
	if chunk != null and chunk.generation_version < MapChunkGenerator.GENERATION_VERSION:
		chunk = null
		replacing_stale_chunk = true
	if chunk == null:
		chunk = _generator.generate_chunk(_planet_seed, chunk_coord, _chunk_size)
		_generated_chunk_keys[key] = true
		if replacing_stale_chunk:
			chunk.dirty = true
			_dirty_chunk_keys[key] = true

	_chunks[key] = chunk
	return chunk


func sample_terrain_id_for_render(global_tile: Vector2i) -> int:
	var chunk_coord: Vector2i = _global_tile_to_chunk_coord(global_tile, _chunk_size)
	var local_tile: Vector2i = _global_tile_to_local_coord(global_tile, chunk_coord, _chunk_size)
	var key: String = _coord_to_key(chunk_coord)

	var loaded_chunk: MapChunkData = _chunks.get(key, null) as MapChunkData
	if loaded_chunk != null:
		return loaded_chunk.get_terrain_id(local_tile.x, local_tile.y)

	var readonly_chunk: MapChunkData = _get_readonly_sample_chunk(chunk_coord, key)
	if readonly_chunk != null:
		return readonly_chunk.get_terrain_id(local_tile.x, local_tile.y)

	return _generator.sample_terrain_id(_planet_seed, global_tile)


func unload_chunks_except(keep_coords: Array[Vector2i]) -> void:
	var keep_keys: Dictionary = {}
	for coord in keep_coords:
		keep_keys[_coord_to_key(coord)] = true

	for key in _chunks.keys():
		if keep_keys.has(str(key)):
			continue
		var chunk: MapChunkData = _chunks[key] as MapChunkData
		if chunk != null and chunk.dirty:
			if not _flush_chunk_before_unload(chunk):
				continue
		_chunks.erase(key)


func mark_dirty(chunk_coord: Vector2i) -> void:
	var key: String = _coord_to_key(chunk_coord)
	_forget_readonly_sample_chunk(key)
	_dirty_chunk_keys[key] = true
	if _chunks.has(key):
		var chunk: MapChunkData = _chunks[key] as MapChunkData
		if chunk != null:
			chunk.dirty = true


func flush_dirty_chunks() -> Dictionary:
	if _store == null:
		return {
			"ok": false,
			"error_code": &"chunk_store_missing"
		}

	for key in _chunks.keys():
		var loaded_chunk: MapChunkData = _chunks[key] as MapChunkData
		if loaded_chunk != null and loaded_chunk.dirty:
			_dirty_chunk_keys[str(key)] = true

	var saved_count: int = 0
	var failed: Array[Dictionary] = []
	for key in _dirty_chunk_keys.keys():
		if not _chunks.has(key):
			continue
		var chunk: MapChunkData = _chunks[key] as MapChunkData
		if chunk == null:
			continue
		var save_result: Dictionary = _store.save_chunk(chunk)
		if bool(save_result.get("ok", false)):
			chunk.dirty = false
			_forget_readonly_sample_chunk(str(key))
			saved_count += 1
		else:
			failed.append(save_result)

	if failed.is_empty():
		_dirty_chunk_keys.clear()
		return {
			"ok": true,
			"saved_count": saved_count
		}

	return {
		"ok": false,
		"saved_count": saved_count,
		"failed": failed
	}


func get_generated_chunk_count() -> int:
	return _generated_chunk_keys.size()


func get_dirty_chunk_count() -> int:
	return _dirty_chunk_keys.size()


func get_chunk_size() -> int:
	return _chunk_size


func _coord_to_key(chunk_coord: Vector2i) -> String:
	return "%d,%d" % [chunk_coord.x, chunk_coord.y]


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


func _get_readonly_sample_chunk(chunk_coord: Vector2i, key: String) -> MapChunkData:
	if _readonly_sample_chunks.has(key):
		return _readonly_sample_chunks[key] as MapChunkData

	var chunk: MapChunkData = null
	if _store != null:
		chunk = _store.load_chunk(chunk_coord)
	if chunk == null:
		return null
	if chunk.generation_version < MapChunkGenerator.GENERATION_VERSION:
		return null

	_remember_readonly_sample_chunk(key, chunk)
	return chunk


func _remember_readonly_sample_chunk(key: String, chunk: MapChunkData) -> void:
	if chunk == null:
		return
	if _readonly_sample_chunks.has(key):
		_readonly_sample_order.erase(key)
	_readonly_sample_chunks[key] = chunk
	_readonly_sample_order.append(key)
	while _readonly_sample_order.size() > READONLY_SAMPLE_CACHE_SIZE:
		var oldest_key: String = str(_readonly_sample_order.pop_front())
		_readonly_sample_chunks.erase(oldest_key)


func _forget_readonly_sample_chunk(key: String) -> void:
	_readonly_sample_chunks.erase(key)
	_readonly_sample_order.erase(key)


func _flush_chunk_before_unload(chunk: MapChunkData) -> bool:
	if _store == null:
		_dirty_chunk_keys[_coord_to_key(chunk.chunk_coord)] = true
		return false

	var save_result: Dictionary = _store.save_chunk(chunk)
	if not bool(save_result.get("ok", false)):
		_dirty_chunk_keys[_coord_to_key(chunk.chunk_coord)] = true
		return false

	chunk.dirty = false
	var key: String = _coord_to_key(chunk.chunk_coord)
	_dirty_chunk_keys.erase(key)
	_forget_readonly_sample_chunk(key)
	return true
