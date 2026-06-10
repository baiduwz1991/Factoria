class_name PlanetSaveData
extends SaveDataBase

#region 状态
var slot_id: int = 1
var planet_preset_id: StringName = &"standard"
var planet_seed: int = 0
var storage_format: StringName = &"chunked_planet"
var generation_version: int = 1
var chunk_size: int = MapChunkGenerator.DEFAULT_CHUNK_SIZE
var tile_size: int = MapChunkGenerator.DEFAULT_TILE_SIZE
var spawn_chunk: Vector2i = Vector2i.ZERO
var surface_properties: Dictionary = {}
var generated_chunk_count: int = 0
var dirty_chunk_count: int = 0
var active_mods: Array[Dictionary] = []
var game_data_fingerprint: String = ""
var terrain_palette: Dictionary = {}
#endregion

#region 对外接口 - 版本
func get_schema_version() -> int:
	return 3
#endregion

#region 对外接口 - 序列化
func to_dict() -> Dictionary:
	return {
		"schema_version": get_schema_version(),
		"slot_id": slot_id,
		"planet_preset_id": String(planet_preset_id),
		"planet_seed": planet_seed,
		"storage_format": String(storage_format),
		"generation_version": generation_version,
		"chunk_size": chunk_size,
		"tile_size": tile_size,
		"spawn_chunk": SerializeUtils.vector2i_to_dict(spawn_chunk),
		"surface_properties": surface_properties.duplicate(true),
		"generated_chunk_count": generated_chunk_count,
		"dirty_chunk_count": dirty_chunk_count,
		"active_mods": active_mods.duplicate(true),
		"game_data_fingerprint": game_data_fingerprint,
		"terrain_palette": terrain_palette.duplicate(true)
	}


func from_dict(raw: Dictionary) -> void:
	slot_id = int(raw.get("slot_id", slot_id))
	planet_preset_id = StringName(raw.get("planet_preset_id", String(planet_preset_id)))
	planet_seed = int(raw.get("planet_seed", planet_seed))
	storage_format = StringName(raw.get("storage_format", String(storage_format)))
	generation_version = int(raw.get("generation_version", generation_version))
	chunk_size = int(raw.get("chunk_size", chunk_size))
	tile_size = int(raw.get("tile_size", tile_size))
	spawn_chunk = SerializeUtils.parse_vector2i(raw.get("spawn_chunk", spawn_chunk), spawn_chunk)
	surface_properties = SerializeUtils.parse_dictionary(raw.get("surface_properties", surface_properties))
	generated_chunk_count = int(raw.get("generated_chunk_count", generated_chunk_count))
	dirty_chunk_count = int(raw.get("dirty_chunk_count", dirty_chunk_count))
	active_mods = SerializeUtils.parse_dictionary_array(raw.get("active_mods", active_mods))
	game_data_fingerprint = str(raw.get("game_data_fingerprint", game_data_fingerprint))
	terrain_palette = SerializeUtils.parse_dictionary(raw.get("terrain_palette", terrain_palette))
	sanitize()


func sanitize() -> void:
	slot_id = maxi(slot_id, 1)
	generation_version = maxi(generation_version, 1)
	chunk_size = MapChunkGenerator.DEFAULT_CHUNK_SIZE
	tile_size = MapChunkGenerator.DEFAULT_TILE_SIZE
	generated_chunk_count = maxi(generated_chunk_count, 0)
	dirty_chunk_count = maxi(dirty_chunk_count, 0)
#endregion

#region 对外接口 - 应用
func apply_chunked_planet(
	next_slot_id: int,
	next_planet_preset_id: StringName,
	next_planet_seed: int,
	next_generation_version: int,
	next_chunk_size: int,
	next_tile_size: int,
	next_spawn_chunk: Vector2i,
	next_surface_properties: Dictionary = {},
	next_active_mods: Array[Dictionary] = [],
	next_game_data_fingerprint: String = "",
	next_terrain_palette: Dictionary = {}
) -> void:
	slot_id = next_slot_id
	planet_preset_id = next_planet_preset_id
	planet_seed = next_planet_seed
	storage_format = &"chunked_planet"
	generation_version = next_generation_version
	chunk_size = next_chunk_size
	tile_size = next_tile_size
	spawn_chunk = next_spawn_chunk
	surface_properties = next_surface_properties.duplicate(true)
	generated_chunk_count = 0
	dirty_chunk_count = 0
	active_mods = next_active_mods.duplicate(true)
	game_data_fingerprint = next_game_data_fingerprint
	terrain_palette = next_terrain_palette.duplicate(true)
	sanitize()


func apply_runtime_stats(next_generated_chunk_count: int, next_dirty_chunk_count: int) -> void:
	generated_chunk_count = next_generated_chunk_count
	dirty_chunk_count = next_dirty_chunk_count
	sanitize()


func clear() -> void:
	slot_id = 1
	planet_preset_id = &"standard"
	planet_seed = 0
	storage_format = &"chunked_planet"
	generation_version = 1
	chunk_size = MapChunkGenerator.DEFAULT_CHUNK_SIZE
	tile_size = MapChunkGenerator.DEFAULT_TILE_SIZE
	spawn_chunk = Vector2i.ZERO
	surface_properties = {}
	generated_chunk_count = 0
	dirty_chunk_count = 0
	active_mods = []
	game_data_fingerprint = ""
	terrain_palette = {}
#endregion
