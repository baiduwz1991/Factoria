class_name LayeredChunkMapView
extends Node2D

signal preload_progress_changed(snapshot: Dictionary)
signal preload_completed(snapshot: Dictionary)

const WATER_RECT_STRIDE: int = 4
const INVALID_CHUNK_COORD: Vector2i = Vector2i(2147483647, 2147483647)
const CSHARP_RUNTIME_MANAGER_PATH: String = "/root/CSharpRuntimeManager"

@export var visible_chunk_radius: int = 2
@export var preload_chunk_margin: int = 2
@export var update_interval_seconds: float = 0.05
@export var max_chunk_loads_per_frame: int = 8
@export var max_chunk_data_tasks: int = 8
@export var initial_preload_data_tasks: int = 8
@export var runtime_max_chunk_loads_per_frame: int = 1
@export var runtime_max_chunk_data_tasks: int = 4
@export var runtime_max_chunk_result_drains_per_frame: int = 4
@export var runtime_max_chunk_installs_per_frame: int = 1
@export var directional_preload_chunks: int = 2
@export var preload_camera_zoom_floor: float = 0.25
@export var max_chunk_installs_per_frame: int = 4
@export var max_water_collision_updates_per_frame: int = 2
@export var water_collision_chunk_radius: int = 1
@export var water_collision_layer: int = 1
@export var water_collision_mask: int = 0

var _planet_controller: PlanetController = null
var _player: Node2D = null
var _csharp_runtime_manager: Node = null
var _loaded_chunk_layers: Dictionary = {}
var _pending_chunk_coords: Array[Vector2i] = []
var _pending_chunk_keys: Dictionary = {}
var _active_visual_jobs: Dictionary = {}
var _completed_visual_results: Array[Dictionary] = []
var _rerender_after_cancel_coords: Dictionary = {}
var _required_chunk_keys: Dictionary = {}
var _preload_active: bool = false
var _preload_completed: bool = false
var _preload_required_keys: Dictionary = {}
var _preload_total_count: int = 0
var _preload_loaded_count: int = 0
var _preload_previous_max_chunk_data_tasks: int = -1
var _update_timer: float = 0.0
var _last_center_chunk: Vector2i = INVALID_CHUNK_COORD
var _last_prefetch_center_chunk: Vector2i = INVALID_CHUNK_COORD
var _last_load_radius: int = -1
var _last_visible_radius: int = -1
var _last_collision_center_chunk: Vector2i = INVALID_CHUNK_COORD
var _last_planet_position: Vector2 = Vector2.ZERO
var _has_last_planet_position: bool = false
var _pending_collision_refresh_keys: Array[String] = []
var _pending_collision_refresh_key_set: Dictionary = {}


func _ready() -> void:
	_cache_csharp_runtime_manager()
	set_process(false)


func _exit_tree() -> void:
	_cancel_all_visual_jobs(true)


func _process(delta: float) -> void:
	if _planet_controller == null or _player == null:
		return

	_process_completed_visual_jobs()
	_process_collision_refresh_queue()
	if _preload_active:
		_process_pending_chunk_loads()
		_update_preload_progress()
		return

	_update_timer -= delta
	if _update_timer <= 0.0:
		_update_timer = update_interval_seconds
		ensure_chunks_around(_player.global_position)
	_process_pending_chunk_loads()


func setup(planet_controller: PlanetController, player: Node2D) -> void:
	_planet_controller = planet_controller
	_player = player
	_cache_csharp_runtime_manager()
	_reset_streaming_cursor()
	set_process(_planet_controller != null and _player != null)
	if _player != null:
		ensure_chunks_around(_player.global_position)
		_process_pending_chunk_loads()


func ensure_chunks_around(planet_position: Vector2) -> void:
	if _planet_controller == null:
		return

	var chunk_size: int = _planet_controller.get_chunk_size()
	var tile_size: int = _planet_controller.get_tile_size()
	var center_chunk: Vector2i = planet_position_to_chunk_coord(planet_position, chunk_size, tile_size)
	var visible_radius: int = _get_visible_chunk_radius(chunk_size, tile_size)
	var load_radius: int = visible_radius + preload_chunk_margin
	var prefetch_center_chunk: Vector2i = center_chunk + _get_directional_preload_offset(planet_position, chunk_size, tile_size)
	if (
		center_chunk == _last_center_chunk
		and prefetch_center_chunk == _last_prefetch_center_chunk
		and load_radius == _last_load_radius
		and visible_radius == _last_visible_radius
	):
		_sort_pending_chunks(center_chunk, prefetch_center_chunk, visible_radius)
		_cancel_preload_jobs_when_visible_pending(center_chunk, visible_radius)
		_refresh_collision_window(center_chunk)
		return
	_last_center_chunk = center_chunk
	_last_prefetch_center_chunk = prefetch_center_chunk
	_last_load_radius = load_radius
	_last_visible_radius = visible_radius

	var required_coords: Array[Vector2i] = []
	var required_keys: Dictionary = {}
	_append_required_chunk_coords(required_coords, required_keys, center_chunk, load_radius)
	if prefetch_center_chunk != center_chunk:
		_append_required_chunk_coords(required_coords, required_keys, prefetch_center_chunk, load_radius)
	_required_chunk_keys = required_keys.duplicate()
	for chunk_coord in required_coords:
		_queue_chunk_layer(chunk_coord)

	_unload_missing_chunks(required_coords)
	_planet_controller.unload_chunks_except(required_coords)
	_sort_pending_chunks(center_chunk, prefetch_center_chunk, visible_radius)
	_cancel_preload_jobs_when_visible_pending(center_chunk, visible_radius)
	_refresh_collision_window(center_chunk)


func planet_position_to_tile_coord(planet_position: Vector2, tile_size: int) -> Vector2i:
	var rendered_tile_size: float = _get_rendered_tile_size(tile_size)
	return Vector2i(
		floori(planet_position.x / rendered_tile_size),
		floori(planet_position.y / rendered_tile_size)
	)


func planet_position_to_chunk_coord(planet_position: Vector2, chunk_size: int, tile_size: int) -> Vector2i:
	var chunk_planet_size: float = _get_rendered_chunk_size(chunk_size, tile_size)
	return Vector2i(
		floori(planet_position.x / chunk_planet_size),
		floori(planet_position.y / chunk_planet_size)
	)


func tile_coord_to_planet_position(tile_coord: Vector2i, tile_size: int) -> Vector2:
	var rendered_tile_size: float = _get_rendered_tile_size(tile_size)
	return Vector2(
		float(tile_coord.x) * rendered_tile_size,
		float(tile_coord.y) * rendered_tile_size
	)


func chunk_coord_to_planet_position(chunk_coord: Vector2i, chunk_size: int, tile_size: int) -> Vector2:
	var rendered_chunk_size: float = _get_rendered_chunk_size(chunk_size, tile_size)
	return Vector2(
		float(chunk_coord.x) * rendered_chunk_size,
		float(chunk_coord.y) * rendered_chunk_size
	)


func rerender_chunk(chunk_coord: Vector2i) -> void:
	if _planet_controller == null:
		return
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			var target_coord: Vector2i = chunk_coord + Vector2i(offset_x, offset_y)
			var key: String = _coord_to_key(target_coord)
			if not _required_chunk_keys.is_empty() and not _required_chunk_keys.has(key) and not _loaded_chunk_layers.has(key):
				continue
			_remove_chunk_layers(target_coord, true)
	_process_completed_visual_jobs()
	_process_pending_chunk_loads()


func begin_preload_around(planet_position: Vector2, extra_chunk_radius: int = 2) -> void:
	if _planet_controller == null:
		return

	_restore_preload_data_task_limit()
	_preload_active = true
	_preload_completed = false
	_preload_required_keys.clear()
	_preload_total_count = 0
	_preload_loaded_count = 0
	_preload_previous_max_chunk_data_tasks = max_chunk_data_tasks
	max_chunk_data_tasks = maxi(max_chunk_data_tasks, initial_preload_data_tasks)

	var chunk_size: int = _planet_controller.get_chunk_size()
	var tile_size: int = _planet_controller.get_tile_size()
	var center_chunk: Vector2i = planet_position_to_chunk_coord(planet_position, chunk_size, tile_size)
	var load_radius: int = _get_preload_visible_chunk_radius(chunk_size, tile_size) + maxi(extra_chunk_radius, 0)
	for chunk_y in range(center_chunk.y - load_radius, center_chunk.y + load_radius + 1):
		for chunk_x in range(center_chunk.x - load_radius, center_chunk.x + load_radius + 1):
			var chunk_coord: Vector2i = Vector2i(chunk_x, chunk_y)
			var key: String = _coord_to_key(chunk_coord)
			_preload_required_keys[key] = true
			_queue_chunk_layer(chunk_coord)
	_preload_total_count = _preload_required_keys.size()
	_required_chunk_keys = _preload_required_keys.duplicate()
	_last_center_chunk = center_chunk
	_last_prefetch_center_chunk = center_chunk
	_last_load_radius = load_radius
	_last_visible_radius = load_radius
	_sort_pending_chunks(center_chunk, center_chunk, load_radius)
	_process_pending_chunk_loads()
	_update_preload_progress(true)


func get_preload_snapshot() -> Dictionary:
	var progress: float = 100.0 if _preload_completed else 0.0
	if _preload_total_count > 0:
		progress = float(_preload_loaded_count) / float(_preload_total_count) * 100.0
	return {
		"active": _preload_active,
		"completed": _preload_completed,
		"progress": clampf(progress, 0.0, 100.0),
		"loaded_count": _preload_loaded_count,
		"total_count": _preload_total_count
	}


func _queue_chunk_layer(chunk_coord: Vector2i) -> void:
	var key: String = _coord_to_key(chunk_coord)
	if _loaded_chunk_layers.has(key) or _active_visual_jobs.has(key) or _pending_chunk_keys.has(key):
		return
	_pending_chunk_coords.append(chunk_coord)
	_pending_chunk_keys[key] = true


func _append_required_chunk_coords(
	required_coords: Array[Vector2i],
	required_keys: Dictionary,
	center_chunk: Vector2i,
	load_radius: int
) -> void:
	for chunk_y in range(center_chunk.y - load_radius, center_chunk.y + load_radius + 1):
		for chunk_x in range(center_chunk.x - load_radius, center_chunk.x + load_radius + 1):
			var chunk_coord: Vector2i = Vector2i(chunk_x, chunk_y)
			var key: String = _coord_to_key(chunk_coord)
			if required_keys.has(key):
				continue
			required_keys[key] = true
			required_coords.append(chunk_coord)


func _process_pending_chunk_loads() -> void:
	if _pending_chunk_coords.is_empty():
		return
	var available_task_count: int = _get_chunk_data_task_limit() - _active_visual_jobs.size()
	if available_task_count <= 0:
		return
	var starts_this_frame: int = mini(_get_chunk_loads_per_frame(), available_task_count)
	for _index in range(starts_this_frame):
		if _pending_chunk_coords.is_empty():
			return
		var chunk_coord: Vector2i = _pending_chunk_coords.pop_front()
		var key: String = _coord_to_key(chunk_coord)
		_pending_chunk_keys.erase(key)
		_start_chunk_visual_job(chunk_coord)


func _start_chunk_visual_job(chunk_coord: Vector2i) -> void:
	var key: String = _coord_to_key(chunk_coord)
	if _loaded_chunk_layers.has(key) or _active_visual_jobs.has(key):
		return
	var runtime_manager: Node = _get_csharp_runtime_manager()
	if runtime_manager == null:
		return

	var chunk: MapChunkData = _planet_controller.get_or_generate_chunk(chunk_coord)
	if chunk == null:
		return

	var chunk_size: int = chunk.chunk_size
	var tile_size: int = _planet_controller.get_tile_size()
	var terrain_snapshot: PackedInt32Array = _build_terrain_snapshot(chunk, chunk_coord)
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
		_active_visual_jobs[key] = chunk_coord


func _process_completed_visual_jobs() -> void:
	_collect_completed_visual_jobs()
	_install_completed_visual_results()
	if _preload_active:
		_update_preload_progress()


func _collect_completed_visual_jobs() -> void:
	var runtime_manager: Node = _get_csharp_runtime_manager()
	if runtime_manager == null:
		return
	var drained_variant: Variant = runtime_manager.call(
		"DrainTerrainVisualResults",
		_get_visual_result_drain_limit()
	)
	if not (drained_variant is Array):
		return

	var drained_results: Array = drained_variant as Array
	for raw_result in drained_results:
		if not (raw_result is Dictionary):
			continue

		var result: Dictionary = raw_result as Dictionary
		var key: String = str(result.get("key", ""))
		if key == "":
			continue
		var was_active: bool = _active_visual_jobs.has(key)
		_active_visual_jobs.erase(key)
		var rerender_coord: Variant = _rerender_after_cancel_coords.get(key, null)
		_rerender_after_cancel_coords.erase(key)
		if not was_active and not (rerender_coord is Vector2i):
			continue

		if bool(result.get("cancelled", false)):
			if rerender_coord is Vector2i:
				_queue_chunk_layer(rerender_coord as Vector2i)
			continue

		var visual_data: Dictionary = result.get("visual_data", {}) as Dictionary
		if visual_data.is_empty():
			continue

		_completed_visual_results.append({
			"key": key,
			"visual_data": visual_data
		})


func _install_completed_visual_results() -> void:
	if _completed_visual_results.is_empty():
		return

	_completed_visual_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _is_completed_visual_result_before(a, b)
	)

	var installed_count: int = 0
	var install_budget: int = _get_chunk_installs_per_frame()
	while not _completed_visual_results.is_empty() and installed_count < install_budget:
		var entry: Dictionary = _completed_visual_results.pop_front() as Dictionary
		if _install_completed_visual_result(entry):
			installed_count += 1


func _install_completed_visual_result(entry: Dictionary) -> bool:
	var key: String = str(entry.get("key", ""))
	var visual_data: Dictionary = entry.get("visual_data", {}) as Dictionary
	if key == "" or visual_data.is_empty():
		return false
	if not _required_chunk_keys.is_empty() and not _required_chunk_keys.has(key):
		return false
	if _loaded_chunk_layers.has(key):
		return false

	var chunk_coord: Vector2i = visual_data.get("chunk_coord", Vector2i.ZERO) as Vector2i
	var chunk_size: int = maxi(int(visual_data.get("chunk_size", 1)), 1)
	var tile_size: int = maxi(int(visual_data.get("tile_size", 32)), 1)
	var runtime_manager: Node = _get_csharp_runtime_manager()
	if runtime_manager == null:
		return false
	var canvas: Node2D = runtime_manager.call("CreateTerrainChunkCanvas", visual_data) as Node2D
	if canvas == null:
		return false
	canvas.name = "TerrainChunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
	canvas.position = chunk_coord_to_planet_position(chunk_coord, chunk_size, tile_size)
	add_child(canvas)

	var layers: Dictionary = {
		&"terrain": canvas,
		&"visual_data": visual_data
	}
	if _should_have_water_collision(chunk_coord):
		var collision_body: StaticBody2D = _create_water_collision_body_from_visual_data(visual_data)
		if collision_body != null:
			layers[&"water_collision"] = collision_body

	_loaded_chunk_layers[key] = layers
	return true


func _is_completed_visual_result_before(a: Dictionary, b: Dictionary) -> bool:
	var a_key: String = str(a.get("key", ""))
	var b_key: String = str(b.get("key", ""))
	var a_loaded: bool = _loaded_chunk_layers.has(a_key)
	var b_loaded: bool = _loaded_chunk_layers.has(b_key)
	if a_loaded != b_loaded:
		return not a_loaded

	var a_coord: Vector2i = _get_completed_visual_result_coord(a)
	var b_coord: Vector2i = _get_completed_visual_result_coord(b)
	var safe_visible_radius: int = maxi(_last_visible_radius, visible_chunk_radius)
	var a_visible: bool = _chunk_chebyshev_distance(a_coord, _last_center_chunk) <= safe_visible_radius
	var b_visible: bool = _chunk_chebyshev_distance(b_coord, _last_center_chunk) <= safe_visible_radius
	if a_visible != b_visible:
		return a_visible

	return _chunk_distance_sq(a_coord, _last_center_chunk) < _chunk_distance_sq(b_coord, _last_center_chunk)


func _get_completed_visual_result_coord(entry: Dictionary) -> Vector2i:
	var visual_data: Dictionary = entry.get("visual_data", {}) as Dictionary
	return visual_data.get("chunk_coord", Vector2i.ZERO) as Vector2i


func _build_terrain_snapshot(chunk: MapChunkData, chunk_coord: Vector2i) -> PackedInt32Array:
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
			local_y
		)

	var bottom_row_index: int = chunk_size * snapshot_width
	for local_x in range(chunk_size + 1):
		snapshot[bottom_row_index + local_x] = _sample_snapshot_border_terrain_id(
			chunk_coord,
			chunk_size,
			local_x,
			chunk_size
		)
	return snapshot


func _sample_snapshot_border_terrain_id(chunk_coord: Vector2i, chunk_size: int, local_x: int, local_y: int) -> int:
	var global_tile: Vector2i = Vector2i(
		chunk_coord.x * chunk_size + local_x,
		chunk_coord.y * chunk_size + local_y
	)
	return _planet_controller.sample_terrain_id_for_render(global_tile)


func _refresh_collision_window(center_chunk: Vector2i) -> void:
	if center_chunk == INVALID_CHUNK_COORD:
		return
	if center_chunk == _last_collision_center_chunk and _pending_collision_refresh_keys.is_empty():
		return
	_last_collision_center_chunk = center_chunk
	_pending_collision_refresh_keys.clear()
	_pending_collision_refresh_key_set.clear()
	for raw_key in _loaded_chunk_layers.keys():
		_queue_collision_refresh_key(str(raw_key))
	_pending_collision_refresh_keys.sort_custom(func(a: String, b: String) -> bool:
		return _is_collision_refresh_key_before(a, b, center_chunk)
	)
	_process_collision_refresh_queue()


func _process_collision_refresh_queue() -> void:
	if _pending_collision_refresh_keys.is_empty():
		return
	var processed_count: int = 0
	var process_budget: int = maxi(max_water_collision_updates_per_frame, 1)
	while not _pending_collision_refresh_keys.is_empty() and processed_count < process_budget:
		var key: String = str(_pending_collision_refresh_keys.pop_front())
		_pending_collision_refresh_key_set.erase(key)
		_apply_collision_state_for_key(key)
		processed_count += 1


func _queue_collision_refresh_key(key: String) -> void:
	if key == "" or _pending_collision_refresh_key_set.has(key):
		return
	_pending_collision_refresh_key_set[key] = true
	_pending_collision_refresh_keys.append(key)


func _apply_collision_state_for_key(key: String) -> void:
	if not _loaded_chunk_layers.has(key):
		return
	var layers: Dictionary = _loaded_chunk_layers.get(key, {}) as Dictionary
	var visual_data: Dictionary = layers.get(&"visual_data", {}) as Dictionary
	if visual_data.is_empty():
		return

	var chunk_coord: Vector2i = visual_data.get("chunk_coord", Vector2i.ZERO) as Vector2i
	var has_collision: bool = layers.has(&"water_collision")
	var should_have_collision: bool = (
		_chunk_chebyshev_distance(chunk_coord, _last_collision_center_chunk)
		<= maxi(water_collision_chunk_radius, 0)
	)
	if should_have_collision and not has_collision:
		var collision_body: StaticBody2D = _create_water_collision_body_from_visual_data(visual_data)
		if collision_body != null:
			layers[&"water_collision"] = collision_body
			_loaded_chunk_layers[key] = layers
	elif not should_have_collision and has_collision:
		var collision_node: Node = layers.get(&"water_collision", null) as Node
		if collision_node != null:
			collision_node.queue_free()
		layers.erase(&"water_collision")
		_loaded_chunk_layers[key] = layers


func _is_collision_refresh_key_before(a: String, b: String, center_chunk: Vector2i) -> bool:
	return (
		_chunk_distance_sq(_get_loaded_chunk_coord_for_key(a), center_chunk)
		< _chunk_distance_sq(_get_loaded_chunk_coord_for_key(b), center_chunk)
	)


func _get_loaded_chunk_coord_for_key(key: String) -> Vector2i:
	var layers: Dictionary = _loaded_chunk_layers.get(key, {}) as Dictionary
	var visual_data: Dictionary = layers.get(&"visual_data", {}) as Dictionary
	if visual_data.is_empty():
		return INVALID_CHUNK_COORD
	return visual_data.get("chunk_coord", INVALID_CHUNK_COORD) as Vector2i


func _should_have_water_collision(chunk_coord: Vector2i) -> bool:
	if _last_center_chunk == INVALID_CHUNK_COORD:
		return false
	return _chunk_chebyshev_distance(chunk_coord, _last_center_chunk) <= maxi(water_collision_chunk_radius, 0)


func _create_water_collision_body_from_visual_data(visual_data: Dictionary) -> StaticBody2D:
	if visual_data.is_empty() or _planet_controller == null:
		return null
	var water_rects: PackedInt32Array = visual_data.get("water_rects", PackedInt32Array())
	if water_rects.size() < WATER_RECT_STRIDE:
		return null

	var chunk_coord: Vector2i = visual_data.get("chunk_coord", Vector2i.ZERO) as Vector2i
	var chunk_size: int = maxi(int(visual_data.get("chunk_size", 1)), 1)
	var tile_size: int = maxi(int(visual_data.get("tile_size", _planet_controller.get_tile_size())), 1)
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "WaterCollision_%d_%d" % [chunk_coord.x, chunk_coord.y]
	body.collision_layer = water_collision_layer
	body.collision_mask = water_collision_mask
	add_child(body)

	for index in range(0, water_rects.size() - WATER_RECT_STRIDE + 1, WATER_RECT_STRIDE):
		var rect_x: int = water_rects[index]
		var rect_y: int = water_rects[index + 1]
		var rect_width: int = water_rects[index + 2]
		var rect_height: int = water_rects[index + 3]
		if rect_width <= 0 or rect_height <= 0:
			continue

		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(
			float(rect_width * tile_size),
			float(rect_height * tile_size)
		)
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		shape_node.shape = shape
		shape_node.position = Vector2(
			float(chunk_coord.x * chunk_size + rect_x) * float(tile_size)
				+ float(rect_width * tile_size) * 0.5,
			float(chunk_coord.y * chunk_size + rect_y) * float(tile_size)
				+ float(rect_height * tile_size) * 0.5
		)
		body.add_child(shape_node)

	if body.get_child_count() <= 0:
		body.queue_free()
		return null
	return body


func _unload_missing_chunks(required_coords: Array[Vector2i]) -> void:
	var required_keys: Dictionary = {}
	for coord in required_coords:
		required_keys[_coord_to_key(coord)] = true
	_drop_completed_visual_results_except(required_keys)

	for key in _loaded_chunk_layers.keys():
		if required_keys.has(str(key)):
			continue
		_free_layers(_loaded_chunk_layers[key] as Dictionary)
		_loaded_chunk_layers.erase(key)

	for key in _active_visual_jobs.keys():
		if required_keys.has(str(key)):
			continue
		_cancel_terrain_visual_job(str(key))
		_rerender_after_cancel_coords.erase(str(key))

	for index in range(_pending_chunk_coords.size() - 1, -1, -1):
		var pending_coord: Vector2i = _pending_chunk_coords[index]
		var pending_key: String = _coord_to_key(pending_coord)
		if required_keys.has(pending_key):
			continue
		_pending_chunk_coords.remove_at(index)
		_pending_chunk_keys.erase(pending_key)


func _remove_chunk_layers(chunk_coord: Vector2i, queue_after_cancel: bool = false) -> void:
	var key: String = _coord_to_key(chunk_coord)
	_remove_completed_visual_result(key)
	if _loaded_chunk_layers.has(key):
		_free_layers(_loaded_chunk_layers[key] as Dictionary)
		_loaded_chunk_layers.erase(key)
	_pending_chunk_keys.erase(key)
	for index in range(_pending_chunk_coords.size() - 1, -1, -1):
		if _coord_to_key(_pending_chunk_coords[index]) == key:
			_pending_chunk_coords.remove_at(index)

	if _active_visual_jobs.has(key):
		_cancel_terrain_visual_job(key)
		if queue_after_cancel:
			_rerender_after_cancel_coords[key] = chunk_coord
		return

	if queue_after_cancel:
		_queue_chunk_layer(chunk_coord)


func _free_layers(layers: Dictionary) -> void:
	for layer in layers.values():
		if layer is Node:
			(layer as Node).queue_free()


func _drop_completed_visual_results_except(required_keys: Dictionary) -> void:
	for index in range(_completed_visual_results.size() - 1, -1, -1):
		var entry: Dictionary = _completed_visual_results[index] as Dictionary
		var key: String = str(entry.get("key", ""))
		if required_keys.has(key):
			continue
		_completed_visual_results.remove_at(index)


func _remove_completed_visual_result(key: String) -> void:
	for index in range(_completed_visual_results.size() - 1, -1, -1):
		var entry: Dictionary = _completed_visual_results[index] as Dictionary
		if str(entry.get("key", "")) == key:
			_completed_visual_results.remove_at(index)


func _cancel_all_visual_jobs(_wait_for_completion: bool) -> void:
	var runtime_manager: Node = _get_csharp_runtime_manager()
	if runtime_manager != null:
		runtime_manager.call("CancelAllTerrainVisualJobs")
	_active_visual_jobs.clear()
	_completed_visual_results.clear()
	_rerender_after_cancel_coords.clear()
	_required_chunk_keys.clear()
	_pending_chunk_coords.clear()
	_pending_chunk_keys.clear()
	_preload_active = false
	_preload_completed = false
	_preload_required_keys.clear()
	_preload_total_count = 0
	_preload_loaded_count = 0
	_pending_collision_refresh_keys.clear()
	_pending_collision_refresh_key_set.clear()
	_restore_preload_data_task_limit()
	_reset_streaming_cursor()


func _get_csharp_runtime_manager() -> Node:
	if _csharp_runtime_manager != null and is_instance_valid(_csharp_runtime_manager):
		return _csharp_runtime_manager
	return _cache_csharp_runtime_manager()


func _cache_csharp_runtime_manager() -> Node:
	_csharp_runtime_manager = get_node_or_null(CSHARP_RUNTIME_MANAGER_PATH)
	if _csharp_runtime_manager == null:
		push_error("CSharpRuntimeManager Autoload is missing at %s." % CSHARP_RUNTIME_MANAGER_PATH)
	return _csharp_runtime_manager


func _cancel_terrain_visual_job(key: String) -> void:
	var runtime_manager: Node = _get_csharp_runtime_manager()
	if runtime_manager != null:
		runtime_manager.call("CancelTerrainVisualJob", key)


func _reset_streaming_cursor() -> void:
	_update_timer = 0.0
	_last_center_chunk = INVALID_CHUNK_COORD
	_last_prefetch_center_chunk = INVALID_CHUNK_COORD
	_last_load_radius = -1
	_last_visible_radius = -1
	_last_collision_center_chunk = INVALID_CHUNK_COORD
	_last_planet_position = Vector2.ZERO
	_has_last_planet_position = false


func _get_chunk_data_task_limit() -> int:
	if _preload_active:
		return maxi(max_chunk_data_tasks, 1)
	return maxi(runtime_max_chunk_data_tasks, 1)


func _get_chunk_loads_per_frame() -> int:
	if _preload_active:
		return maxi(max_chunk_loads_per_frame, 1)
	return maxi(runtime_max_chunk_loads_per_frame, 1)


func _get_visual_result_drain_limit() -> int:
	if _preload_active:
		return maxi(max_chunk_installs_per_frame * 4, 16)
	return maxi(runtime_max_chunk_result_drains_per_frame, 1)


func _get_chunk_installs_per_frame() -> int:
	if _preload_active:
		return maxi(max_chunk_installs_per_frame, 1)
	return maxi(runtime_max_chunk_installs_per_frame, 1)


func _sort_pending_chunks(
	visible_center_chunk: Vector2i,
	priority_center_chunk: Vector2i,
	visible_radius: int
) -> void:
	_pending_chunk_coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _is_chunk_before(a, b, visible_center_chunk, priority_center_chunk, visible_radius)
	)


func _cancel_preload_jobs_when_visible_pending(visible_center_chunk: Vector2i, visible_radius: int) -> void:
	if not _has_pending_visible_chunk(visible_center_chunk, visible_radius):
		return

	for raw_key in _active_visual_jobs.keys():
		var key: String = str(raw_key)
		var chunk_coord_variant: Variant = _active_visual_jobs.get(key, null)
		if not (chunk_coord_variant is Vector2i):
			continue
		var chunk_coord: Vector2i = chunk_coord_variant as Vector2i
		if _chunk_chebyshev_distance(chunk_coord, visible_center_chunk) <= visible_radius:
			continue
		_cancel_terrain_visual_job(key)
		_rerender_after_cancel_coords[key] = chunk_coord


func _has_pending_visible_chunk(visible_center_chunk: Vector2i, visible_radius: int) -> bool:
	for chunk_coord in _pending_chunk_coords:
		if _chunk_chebyshev_distance(chunk_coord, visible_center_chunk) <= visible_radius:
			return true
	return false


func _is_chunk_before(
	a: Vector2i,
	b: Vector2i,
	visible_center_chunk: Vector2i,
	priority_center_chunk: Vector2i,
	visible_radius: int
) -> bool:
	var a_group: int = 0 if _chunk_chebyshev_distance(a, visible_center_chunk) <= visible_radius else 1
	var b_group: int = 0 if _chunk_chebyshev_distance(b, visible_center_chunk) <= visible_radius else 1
	if a_group != b_group:
		return a_group < b_group

	var a_priority_distance: int = _chunk_distance_sq(a, priority_center_chunk)
	var b_priority_distance: int = _chunk_distance_sq(b, priority_center_chunk)
	if a_priority_distance != b_priority_distance:
		return a_priority_distance < b_priority_distance

	return _chunk_distance_sq(a, visible_center_chunk) < _chunk_distance_sq(b, visible_center_chunk)


func _chunk_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	var delta: Vector2i = a - b
	return maxi(absi(delta.x), absi(delta.y))


func _chunk_distance_sq(a: Vector2i, b: Vector2i) -> int:
	var delta: Vector2i = a - b
	return delta.x * delta.x + delta.y * delta.y


func _get_directional_preload_offset(planet_position: Vector2, chunk_size: int, tile_size: int) -> Vector2i:
	if not _has_last_planet_position:
		_last_planet_position = planet_position
		_has_last_planet_position = true
		return Vector2i.ZERO

	var movement_delta: Vector2 = planet_position - _last_planet_position
	_last_planet_position = planet_position
	if movement_delta.length_squared() < 1.0:
		return Vector2i.ZERO

	var chunk_planet_size: float = _get_rendered_chunk_size(chunk_size, tile_size)
	var minimum_axis_delta: float = maxf(chunk_planet_size * 0.002, 0.5)
	var offset: Vector2i = Vector2i.ZERO
	if absf(movement_delta.x) >= minimum_axis_delta:
		offset.x = (1 if movement_delta.x > 0.0 else -1) * maxi(directional_preload_chunks, 0)
	if absf(movement_delta.y) >= minimum_axis_delta:
		offset.y = (1 if movement_delta.y > 0.0 else -1) * maxi(directional_preload_chunks, 0)
	return offset


func _get_visible_chunk_radius(chunk_size: int, tile_size: int) -> int:
	return _get_visible_chunk_radius_for_zoom(chunk_size, tile_size, _get_camera_zoom())


func _get_preload_visible_chunk_radius(chunk_size: int, tile_size: int) -> int:
	return _get_visible_chunk_radius_for_zoom(chunk_size, tile_size, _get_preload_camera_zoom_floor())


func _get_visible_chunk_radius_for_zoom(chunk_size: int, tile_size: int, camera_zoom: float) -> int:
	var viewport_size: Vector2 = Vector2(get_viewport_rect().size)
	var visible_planet_size: Vector2 = viewport_size / maxf(camera_zoom, 0.01)
	var chunk_planet_size: float = _get_rendered_chunk_size(chunk_size, tile_size)
	var calculated_radius: int = ceili(maxf(visible_planet_size.x, visible_planet_size.y) / chunk_planet_size * 0.5)
	return maxi(calculated_radius, visible_chunk_radius)


func _get_preload_camera_zoom_floor() -> float:
	if _player != null:
		var player_min_zoom: Variant = _player.get("camera_min_zoom")
		if player_min_zoom is float:
			return maxf(float(player_min_zoom), 0.01)
		if player_min_zoom is int:
			return maxf(float(player_min_zoom), 0.01)
	return maxf(preload_camera_zoom_floor, 0.01)


func _get_rendered_tile_size(tile_size: int) -> float:
	return float(maxi(tile_size, 1))


func _get_rendered_chunk_size(chunk_size: int, tile_size: int) -> float:
	return float(maxi(chunk_size, 1)) * _get_rendered_tile_size(tile_size)


func _get_camera_zoom() -> float:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return 1.0
	var camera: Camera2D = viewport.get_camera_2d()
	if camera == null:
		return 1.0
	return maxf(camera.zoom.x, 0.01)


func _coord_to_key(chunk_coord: Vector2i) -> String:
	return "%d,%d" % [chunk_coord.x, chunk_coord.y]


func _update_preload_progress(force_emit: bool = false) -> void:
	if not _preload_active:
		return
	var loaded_count: int = 0
	for key in _preload_required_keys.keys():
		if _loaded_chunk_layers.has(str(key)):
			loaded_count += 1
	var changed: bool = force_emit or loaded_count != _preload_loaded_count
	_preload_loaded_count = loaded_count
	if changed:
		preload_progress_changed.emit(get_preload_snapshot())
	if _preload_total_count <= 0 or _preload_loaded_count < _preload_total_count:
		return
	_preload_active = false
	_preload_completed = true
	_restore_preload_data_task_limit()
	var snapshot: Dictionary = get_preload_snapshot()
	preload_progress_changed.emit(snapshot)
	preload_completed.emit(snapshot)


func _restore_preload_data_task_limit() -> void:
	if _preload_previous_max_chunk_data_tasks < 0:
		return
	max_chunk_data_tasks = _preload_previous_max_chunk_data_tasks
	_preload_previous_max_chunk_data_tasks = -1
