class_name ChunkStreamScheduler
extends RefCounted

const INVALID_CHUNK_COORD: Vector2i = Vector2i(2147483647, 2147483647)

var required_chunk_keys: Dictionary = {}
var pending_chunk_coords: Array[Vector2i] = []
var pending_chunk_keys: Dictionary = {}
var last_center_chunk: Vector2i = INVALID_CHUNK_COORD
var last_prefetch_center_chunk: Vector2i = INVALID_CHUNK_COORD
var last_load_radius: int = -1
var last_visible_radius: int = -1
var last_planet_position: Vector2 = Vector2.ZERO
var has_last_planet_position: bool = false


static func coord_to_key(chunk_coord: Vector2i) -> String:
	return "%d,%d" % [chunk_coord.x, chunk_coord.y]


static func chunk_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	var delta: Vector2i = a - b
	return maxi(absi(delta.x), absi(delta.y))


static func chunk_distance_sq(a: Vector2i, b: Vector2i) -> int:
	var delta: Vector2i = a - b
	return delta.x * delta.x + delta.y * delta.y


func reset_all() -> void:
	required_chunk_keys.clear()
	pending_chunk_coords.clear()
	pending_chunk_keys.clear()
	reset_streaming_cursor()


func reset_streaming_cursor() -> void:
	last_center_chunk = INVALID_CHUNK_COORD
	last_prefetch_center_chunk = INVALID_CHUNK_COORD
	last_load_radius = -1
	last_visible_radius = -1
	last_planet_position = Vector2.ZERO
	has_last_planet_position = false


func update_streaming_window(
	center_chunk: Vector2i,
	prefetch_center_chunk: Vector2i,
	load_radius: int,
	visible_radius: int
) -> bool:
	var changed: bool = not (
		center_chunk == last_center_chunk
		and prefetch_center_chunk == last_prefetch_center_chunk
		and load_radius == last_load_radius
		and visible_radius == last_visible_radius
	)
	last_center_chunk = center_chunk
	last_prefetch_center_chunk = prefetch_center_chunk
	last_load_radius = load_radius
	last_visible_radius = visible_radius
	return changed


func get_directional_preload_offset(
	planet_position: Vector2,
	chunk_planet_size: float,
	directional_preload_chunks: int
) -> Vector2i:
	if not has_last_planet_position:
		last_planet_position = planet_position
		has_last_planet_position = true
		return Vector2i.ZERO

	var movement_delta: Vector2 = planet_position - last_planet_position
	last_planet_position = planet_position
	if movement_delta.length_squared() < 1.0:
		return Vector2i.ZERO

	var minimum_axis_delta: float = maxf(chunk_planet_size * 0.002, 0.5)
	var offset: Vector2i = Vector2i.ZERO
	if absf(movement_delta.x) >= minimum_axis_delta:
		offset.x = (1 if movement_delta.x > 0.0 else -1) * maxi(directional_preload_chunks, 0)
	if absf(movement_delta.y) >= minimum_axis_delta:
		offset.y = (1 if movement_delta.y > 0.0 else -1) * maxi(directional_preload_chunks, 0)
	return offset


func build_required_coords(
	center_chunk: Vector2i,
	prefetch_center_chunk: Vector2i,
	load_radius: int
) -> Array[Vector2i]:
	var required_coords: Array[Vector2i] = []
	var next_required_keys: Dictionary = {}
	_append_required_chunk_coords(required_coords, next_required_keys, center_chunk, load_radius)
	if prefetch_center_chunk != center_chunk:
		_append_required_chunk_coords(required_coords, next_required_keys, prefetch_center_chunk, load_radius)
	required_chunk_keys = next_required_keys.duplicate()
	return required_coords


func set_required_keys(next_required_keys: Dictionary) -> void:
	required_chunk_keys = next_required_keys.duplicate()


func queue_chunk_layer(
	chunk_coord: Vector2i,
	loaded_chunk_layers: Dictionary,
	active_visual_jobs: Dictionary
) -> bool:
	var key: String = coord_to_key(chunk_coord)
	if loaded_chunk_layers.has(key) or active_visual_jobs.has(key) or pending_chunk_keys.has(key):
		return false
	pending_chunk_coords.append(chunk_coord)
	pending_chunk_keys[key] = true
	return true


func process_pending_chunk_loads(
	chunk_loads_per_frame: int,
	chunk_data_task_limit: int,
	active_visual_job_count: int,
	start_callable: Callable
) -> void:
	if pending_chunk_coords.is_empty():
		return
	var available_task_count: int = chunk_data_task_limit - active_visual_job_count
	if available_task_count <= 0:
		return
	var starts_this_frame: int = mini(chunk_loads_per_frame, available_task_count)
	for _index in range(starts_this_frame):
		if pending_chunk_coords.is_empty():
			return
		var chunk_coord: Vector2i = pending_chunk_coords.pop_front()
		var key: String = coord_to_key(chunk_coord)
		pending_chunk_keys.erase(key)
		if start_callable.is_valid():
			start_callable.call(chunk_coord)


func sort_pending_chunks(
	visible_center_chunk: Vector2i,
	priority_center_chunk: Vector2i,
	visible_radius: int
) -> void:
	pending_chunk_coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _is_chunk_before(a, b, visible_center_chunk, priority_center_chunk, visible_radius)
	)


func remove_pending_key(key: String) -> void:
	pending_chunk_keys.erase(key)
	for index in range(pending_chunk_coords.size() - 1, -1, -1):
		if coord_to_key(pending_chunk_coords[index]) == key:
			pending_chunk_coords.remove_at(index)


func filter_pending_except(required_keys: Dictionary) -> void:
	for index in range(pending_chunk_coords.size() - 1, -1, -1):
		var pending_coord: Vector2i = pending_chunk_coords[index]
		var pending_key: String = coord_to_key(pending_coord)
		if required_keys.has(pending_key):
			continue
		pending_chunk_coords.remove_at(index)
		pending_chunk_keys.erase(pending_key)


func has_pending_visible_chunk(visible_center_chunk: Vector2i, visible_radius: int) -> bool:
	for chunk_coord in pending_chunk_coords:
		if chunk_chebyshev_distance(chunk_coord, visible_center_chunk) <= visible_radius:
			return true
	return false


func get_pending_count() -> int:
	return pending_chunk_coords.size()


func get_required_count() -> int:
	return required_chunk_keys.size()


func _append_required_chunk_coords(
	required_coords: Array[Vector2i],
	required_keys: Dictionary,
	center_chunk: Vector2i,
	load_radius: int
) -> void:
	for chunk_y in range(center_chunk.y - load_radius, center_chunk.y + load_radius + 1):
		for chunk_x in range(center_chunk.x - load_radius, center_chunk.x + load_radius + 1):
			var chunk_coord: Vector2i = Vector2i(chunk_x, chunk_y)
			var key: String = coord_to_key(chunk_coord)
			if required_keys.has(key):
				continue
			required_keys[key] = true
			required_coords.append(chunk_coord)


func _is_chunk_before(
	a: Vector2i,
	b: Vector2i,
	visible_center_chunk: Vector2i,
	priority_center_chunk: Vector2i,
	visible_radius: int
) -> bool:
	var a_group: int = 0 if chunk_chebyshev_distance(a, visible_center_chunk) <= visible_radius else 1
	var b_group: int = 0 if chunk_chebyshev_distance(b, visible_center_chunk) <= visible_radius else 1
	if a_group != b_group:
		return a_group < b_group

	var a_priority_distance: int = chunk_distance_sq(a, priority_center_chunk)
	var b_priority_distance: int = chunk_distance_sq(b, priority_center_chunk)
	if a_priority_distance != b_priority_distance:
		return a_priority_distance < b_priority_distance

	return chunk_distance_sq(a, visible_center_chunk) < chunk_distance_sq(b, visible_center_chunk)
