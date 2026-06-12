class_name TerrainVisualJobBridge
extends RefCounted

var _owner: Node = null
var _runtime_path: String = ""
var _csharp_runtime_manager: Node = null
var active_visual_jobs: Dictionary = {}
var completed_visual_results: Array[Dictionary] = []
var rerender_after_cancel_coords: Dictionary = {}


func setup(owner: Node, runtime_path: String) -> void:
	_owner = owner
	_runtime_path = runtime_path
	_cache_csharp_runtime_manager()


func get_runtime_manager() -> Node:
	if _csharp_runtime_manager != null and is_instance_valid(_csharp_runtime_manager):
		return _csharp_runtime_manager
	return _cache_csharp_runtime_manager()


func start_chunk_visual_job(chunk_coord: Vector2i, planet_controller: PlanetController, loaded_chunk_layers: Dictionary) -> bool:
	var key: String = _coord_to_key(chunk_coord)
	if loaded_chunk_layers.has(key) or active_visual_jobs.has(key):
		return false
	var runtime_manager: Node = get_runtime_manager()
	if runtime_manager == null:
		return false

	var chunk: MapChunkData = planet_controller.get_or_generate_chunk(chunk_coord)
	if chunk == null:
		return false

	var chunk_size: int = chunk.chunk_size
	var tile_size: int = planet_controller.get_tile_size()
	var terrain_snapshot: PackedInt32Array = _build_terrain_snapshot(chunk, chunk_coord, planet_controller)
	var chunk_tiles: PackedInt32Array = chunk.tiles.duplicate()
	var started: bool = bool(runtime_manager.call(
		"StartTerrainVisualJob",
		key,
		chunk_coord,
		chunk_size,
		tile_size,
		terrain_snapshot,
		chunk_tiles
	))
	if started:
		active_visual_jobs[key] = chunk_coord
	return started


func collect_completed_visual_jobs(drain_limit: int) -> Dictionary:
	var runtime_manager: Node = get_runtime_manager()
	if runtime_manager == null:
		return {
			"drained_count": 0,
			"rerender_coords": []
		}
	var drained_variant: Variant = runtime_manager.call("DrainTerrainVisualResults", drain_limit)
	if not (drained_variant is Array):
		return {
			"drained_count": 0,
			"rerender_coords": []
		}

	var drained_results: Array = drained_variant as Array
	var rerender_coords: Array[Vector2i] = []
	for raw_result in drained_results:
		if not (raw_result is Dictionary):
			continue

		var result: Dictionary = raw_result as Dictionary
		var key: String = str(result.get("key", ""))
		if key == "":
			continue
		var was_active: bool = active_visual_jobs.has(key)
		active_visual_jobs.erase(key)
		var rerender_coord: Variant = rerender_after_cancel_coords.get(key, null)
		rerender_after_cancel_coords.erase(key)
		if not was_active and not (rerender_coord is Vector2i):
			continue

		if bool(result.get("cancelled", false)):
			if rerender_coord is Vector2i:
				rerender_coords.append(rerender_coord as Vector2i)
			continue

		var visual_data: Dictionary = result.get("visual_data", {}) as Dictionary
		if visual_data.is_empty():
			continue

		completed_visual_results.append({
			"key": key,
			"visual_data": visual_data
		})

	return {
		"drained_count": drained_results.size(),
		"rerender_coords": rerender_coords
	}


func sort_completed_visual_results(
	loaded_chunk_layers: Dictionary,
	center_chunk: Vector2i,
	visible_radius: int,
	fallback_visible_radius: int
) -> void:
	completed_visual_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _is_completed_visual_result_before(
			a,
			b,
			loaded_chunk_layers,
			center_chunk,
			visible_radius,
			fallback_visible_radius
		)
	)


func has_completed_visual_results() -> bool:
	return not completed_visual_results.is_empty()


func pop_completed_visual_result() -> Dictionary:
	if completed_visual_results.is_empty():
		return {}
	return completed_visual_results.pop_front() as Dictionary


func drop_completed_visual_results_except(required_keys: Dictionary) -> void:
	for index in range(completed_visual_results.size() - 1, -1, -1):
		var entry: Dictionary = completed_visual_results[index] as Dictionary
		var key: String = str(entry.get("key", ""))
		if required_keys.has(key):
			continue
		completed_visual_results.remove_at(index)


func remove_completed_visual_result(key: String) -> void:
	for index in range(completed_visual_results.size() - 1, -1, -1):
		var entry: Dictionary = completed_visual_results[index] as Dictionary
		if str(entry.get("key", "")) == key:
			completed_visual_results.remove_at(index)


func cancel_active_jobs_except(required_keys: Dictionary) -> void:
	for raw_key in active_visual_jobs.keys():
		var key: String = str(raw_key)
		if required_keys.has(key):
			continue
		cancel_terrain_visual_job(key)
		rerender_after_cancel_coords.erase(key)


func cancel_far_jobs_for_visible_pending(visible_center_chunk: Vector2i, visible_radius: int) -> void:
	for raw_key in active_visual_jobs.keys():
		var key: String = str(raw_key)
		var chunk_coord_variant: Variant = active_visual_jobs.get(key, null)
		if not (chunk_coord_variant is Vector2i):
			continue
		var chunk_coord: Vector2i = chunk_coord_variant as Vector2i
		if _chunk_chebyshev_distance(chunk_coord, visible_center_chunk) <= visible_radius:
			continue
		cancel_terrain_visual_job(key)
		rerender_after_cancel_coords[key] = chunk_coord


func cancel_for_rerender(key: String, chunk_coord: Vector2i, queue_after_cancel: bool) -> bool:
	if not active_visual_jobs.has(key):
		return false
	cancel_terrain_visual_job(key)
	if queue_after_cancel:
		rerender_after_cancel_coords[key] = chunk_coord
	return true


func cancel_terrain_visual_job(key: String) -> void:
	var runtime_manager: Node = get_runtime_manager()
	if runtime_manager != null:
		runtime_manager.call("CancelTerrainVisualJob", key)


func cancel_all_visual_jobs() -> void:
	var runtime_manager: Node = get_runtime_manager()
	if runtime_manager != null:
		runtime_manager.call("CancelAllTerrainVisualJobs")
	active_visual_jobs.clear()
	completed_visual_results.clear()
	rerender_after_cancel_coords.clear()


func get_active_count() -> int:
	return active_visual_jobs.size()


func get_completed_count() -> int:
	return completed_visual_results.size()


func _cache_csharp_runtime_manager() -> Node:
	if _owner == null:
		return null
	_csharp_runtime_manager = _owner.get_node_or_null(_runtime_path)
	if _csharp_runtime_manager == null:
		push_error("CSharpRuntimeManager Autoload is missing at %s." % _runtime_path)
	return _csharp_runtime_manager


func _build_terrain_snapshot(
	chunk: MapChunkData,
	chunk_coord: Vector2i,
	planet_controller: PlanetController
) -> PackedInt32Array:
	var snapshot: PackedInt32Array = PackedInt32Array()
	if chunk == null:
		return snapshot

	var chunk_size: int = chunk.chunk_size
	var snapshot_width: int = chunk_size + 1
	snapshot.resize(snapshot_width * snapshot_width)
	for local_y in range(chunk_size):
		var source_row_index: int = local_y * chunk_size
		var snapshot_row_index: int = local_y * snapshot_width
		for local_x in range(chunk_size):
			var source_index: int = source_row_index + local_x
			snapshot[snapshot_row_index + local_x] = (
				chunk.tiles[source_index] if source_index < chunk.tiles.size() else 0
			)
		snapshot[snapshot_row_index + chunk_size] = _sample_snapshot_border_terrain_id(
			chunk_coord,
			chunk_size,
			chunk_size,
			local_y,
			planet_controller
		)

	var bottom_row_index: int = chunk_size * snapshot_width
	for local_x in range(chunk_size + 1):
		snapshot[bottom_row_index + local_x] = _sample_snapshot_border_terrain_id(
			chunk_coord,
			chunk_size,
			local_x,
			chunk_size,
			planet_controller
		)
	return snapshot


func _sample_snapshot_border_terrain_id(
	chunk_coord: Vector2i,
	chunk_size: int,
	local_x: int,
	local_y: int,
	planet_controller: PlanetController
) -> int:
	var global_tile: Vector2i = Vector2i(
		chunk_coord.x * chunk_size + local_x,
		chunk_coord.y * chunk_size + local_y
	)
	return planet_controller.sample_terrain_id_for_render(global_tile)


func _is_completed_visual_result_before(
	a: Dictionary,
	b: Dictionary,
	loaded_chunk_layers: Dictionary,
	center_chunk: Vector2i,
	visible_radius: int,
	fallback_visible_radius: int
) -> bool:
	var a_key: String = str(a.get("key", ""))
	var b_key: String = str(b.get("key", ""))
	var a_loaded: bool = loaded_chunk_layers.has(a_key)
	var b_loaded: bool = loaded_chunk_layers.has(b_key)
	if a_loaded != b_loaded:
		return not a_loaded

	var a_coord: Vector2i = _get_completed_visual_result_coord(a)
	var b_coord: Vector2i = _get_completed_visual_result_coord(b)
	var safe_visible_radius: int = maxi(visible_radius, fallback_visible_radius)
	var a_visible: bool = _chunk_chebyshev_distance(a_coord, center_chunk) <= safe_visible_radius
	var b_visible: bool = _chunk_chebyshev_distance(b_coord, center_chunk) <= safe_visible_radius
	if a_visible != b_visible:
		return a_visible

	return (
		_chunk_distance_sq(a_coord, center_chunk)
		< _chunk_distance_sq(b_coord, center_chunk)
	)


func _get_completed_visual_result_coord(entry: Dictionary) -> Vector2i:
	var visual_data: Dictionary = entry.get("visual_data", {}) as Dictionary
	return visual_data.get("chunk_coord", Vector2i.ZERO) as Vector2i


func _coord_to_key(chunk_coord: Vector2i) -> String:
	return "%d,%d" % [chunk_coord.x, chunk_coord.y]


func _chunk_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	var delta: Vector2i = a - b
	return maxi(absi(delta.x), absi(delta.y))


func _chunk_distance_sq(a: Vector2i, b: Vector2i) -> int:
	var delta: Vector2i = a - b
	return delta.x * delta.x + delta.y * delta.y
