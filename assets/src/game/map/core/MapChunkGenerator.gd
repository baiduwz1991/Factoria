class_name MapChunkGenerator
extends RefCounted

const GENERATION_VERSION: int = 6
const DEFAULT_CHUNK_SIZE: int = 32
const DEFAULT_TILE_SIZE: int = 32

var _height_noise: FastNoiseLite = FastNoiseLite.new()
var _moisture_noise: FastNoiseLite = FastNoiseLite.new()
var _temperature_noise: FastNoiseLite = FastNoiseLite.new()
var _variation_noise: FastNoiseLite = FastNoiseLite.new()
var _detail_noise: FastNoiseLite = FastNoiseLite.new()
var _terrain_catalog: TerrainCatalog = TerrainCatalog.new()
var _autoplace_rules: Array[TerrainAutoplaceRule] = []
var _enabled_terrain_ids: Dictionary = {}


func setup(
	terrain_catalog: TerrainCatalog,
	autoplace_catalog: TerrainAutoplaceCatalog,
	planet_preset: PlanetPresetDef = null
) -> void:
	if terrain_catalog != null:
		_terrain_catalog = terrain_catalog
	if autoplace_catalog != null:
		_autoplace_rules = autoplace_catalog.get_rules()
	else:
		_autoplace_rules = []

	_enabled_terrain_ids.clear()
	if planet_preset == null or planet_preset.terrain_ids.is_empty():
		return

	for raw_terrain_id in planet_preset.terrain_ids:
		var terrain_id: StringName = raw_terrain_id as StringName
		var terrain: TerrainDef = _terrain_catalog.get_by_id(terrain_id)
		if terrain != null:
			_enabled_terrain_ids[terrain.numeric_id] = true


func generate_chunk(planet_seed: int, chunk_coord: Vector2i, chunk_size: int = DEFAULT_CHUNK_SIZE) -> MapChunkData:
	_configure_noise(planet_seed)

	var chunk: MapChunkData = MapChunkData.new()
	chunk.setup(chunk_coord, GENERATION_VERSION, chunk_size)
	for local_y in range(chunk_size):
		for local_x in range(chunk_size):
			var planet_tile: Vector2i = Vector2i(
				chunk_coord.x * chunk_size + local_x,
				chunk_coord.y * chunk_size + local_y
			)
			var terrain_id: int = _pick_terrain_id(planet_tile)
			var terrain: TerrainDef = _terrain_catalog.get_by_numeric_id(terrain_id)
			var index: int = local_y * chunk_size + local_x
			chunk.tiles[index] = terrain_id
			chunk.minimap_colors[index] = terrain.map_color if terrain != null else 0xffffff

	chunk.dirty = false
	return chunk


func sample_terrain_id(planet_seed: int, global_tile: Vector2i) -> int:
	_configure_noise(planet_seed)
	return _pick_terrain_id(global_tile)


func _configure_noise(planet_seed: int) -> void:
	_height_noise.seed = planet_seed
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_height_noise.frequency = 0.006
	_height_noise.fractal_octaves = 3

	_moisture_noise.seed = planet_seed + 1009
	_moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_moisture_noise.frequency = 0.012
	_moisture_noise.fractal_octaves = 3

	_temperature_noise.seed = planet_seed + 2003
	_temperature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_temperature_noise.frequency = 0.006
	_temperature_noise.fractal_octaves = 3

	_variation_noise.seed = planet_seed + 4001
	_variation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_variation_noise.frequency = 0.018
	_variation_noise.fractal_octaves = 2

	_detail_noise.seed = planet_seed + 7001
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 0.055
	_detail_noise.fractal_octaves = 2


func _pick_terrain_id(planet_tile: Vector2i) -> int:
	var height_value: float = _height_noise.get_noise_2d(planet_tile.x, planet_tile.y)
	var moisture_value: float = _moisture_noise.get_noise_2d(planet_tile.x, planet_tile.y)
	var temperature_value: float = _temperature_noise.get_noise_2d(planet_tile.x, planet_tile.y)
	var variation_value: float = _get_variation_value(planet_tile)
	var best_terrain_id: int = _terrain_catalog.get_default_terrain_id()
	var best_score: float = -INF

	for raw_rule in _autoplace_rules:
		var rule: TerrainAutoplaceRule = raw_rule as TerrainAutoplaceRule
		if rule == null:
			continue
		if not _is_terrain_enabled(rule.terrain_numeric_id):
			continue
		var score: float = rule.score(height_value, moisture_value, temperature_value, variation_value)
		if score > best_score:
			best_score = score
			best_terrain_id = rule.terrain_numeric_id

	return best_terrain_id


func _is_terrain_enabled(terrain_numeric_id: int) -> bool:
	if _enabled_terrain_ids.is_empty():
		return true
	return _enabled_terrain_ids.has(terrain_numeric_id)


func _get_variation_value(planet_tile: Vector2i) -> float:
	var broad_variation: float = _variation_noise.get_noise_2d(planet_tile.x, planet_tile.y)
	var detail_variation: float = _detail_noise.get_noise_2d(planet_tile.x, planet_tile.y) * 0.04
	return clampf(broad_variation + detail_variation, -1.0, 1.0)
