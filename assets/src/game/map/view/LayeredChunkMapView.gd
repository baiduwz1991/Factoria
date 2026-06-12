class_name LayeredChunkMapView
extends Node2D

signal preload_progress_changed(snapshot: Dictionary)
signal preload_completed(snapshot: Dictionary)

const INVALID_CHUNK_COORD: Vector2i = Vector2i(2147483647, 2147483647)
const CSHARP_RUNTIME_MANAGER_PATH: String = "/root/CSharpRuntimeManager"
const CHUNK_STREAM_SCHEDULER_SCRIPT: GDScript = preload("res://assets/src/game/map/view/ChunkStreamScheduler.gd")
const TERRAIN_VISUAL_JOB_BRIDGE_SCRIPT: GDScript = preload("res://assets/src/game/map/view/TerrainVisualJobBridge.gd")
const CHUNK_LAYER_INSTALLER_SCRIPT: GDScript = preload("res://assets/src/game/map/view/ChunkLayerInstaller.gd")
const MAP_DEBUG_PROBE_SCRIPT: GDScript = preload("res://assets/src/game/map/view/MapDebugProbe.gd")

@export var visible_chunk_radius: int = 2
@export var max_runtime_visible_chunk_radius: int = 4
@export var preload_chunk_margin: int = 1
@export var update_interval_seconds: float = 0.05
@export var max_chunk_loads_per_frame: int = 8
@export var max_chunk_data_tasks: int = 8
@export var initial_preload_data_tasks: int = 8
@export var runtime_max_chunk_loads_per_frame: int = 1
@export var runtime_max_chunk_data_tasks: int = 2
@export var runtime_max_chunk_result_drains_per_frame: int = 2
@export var runtime_max_chunk_installs_per_frame: int = 1
@export var directional_preload_chunks: int = 1
@export var preload_camera_zoom_floor: float = 0.25
@export var max_chunk_installs_per_frame: int = 4
@export var max_water_collision_updates_per_frame: int = 2
@export var water_collision_chunk_radius: int = 1
@export var water_collision_layer: int = 1
@export var water_collision_mask: int = 0

var _planet_controller: PlanetController = null
var _player: Node2D = null
var _scheduler = CHUNK_STREAM_SCHEDULER_SCRIPT.new()
var _visual_jobs = TERRAIN_VISUAL_JOB_BRIDGE_SCRIPT.new()
var _layer_installer = CHUNK_LAYER_INSTALLER_SCRIPT.new()
var _debug_probe = MAP_DEBUG_PROBE_SCRIPT.new()
var _preload_active: bool = false
var _preload_completed: bool = false
var _preload_required_keys: Dictionary = {}
var _preload_total_count: int = 0
var _preload_loaded_count: int = 0
var _preload_previous_max_chunk_data_tasks: int = -1
var _update_timer: float = 0.0


func _ready() -> void:
	_visual_jobs.setup(self, CSHARP_RUNTIME_MANAGER_PATH)
	_layer_installer.setup(self, _planet_controller)
	set_process(false)


func _exit_tree() -> void:
	_cancel_all_visual_jobs(true)


func _process(delta: float) -> void:
	if _planet_controller == null or _player == null:
		return

	var process_start: int = Time.get_ticks_usec()
	_debug_probe.reset_frame_counters()
	var step_start: int = Time.get_ticks_usec()
	_process_completed_visual_jobs()
	_debug_probe.completed_jobs_ms = _debug_probe.elapsed_ms(step_start)
	step_start = Time.get_ticks_usec()
	_process_collision_refresh_queue()
	_debug_probe.collision_ms = _debug_probe.elapsed_ms(step_start)
	if _preload_active:
		step_start = Time.get_ticks_usec()
		_process_pending_chunk_loads()
		_debug_probe.pending_loads_ms = _debug_probe.elapsed_ms(step_start)
		_update_preload_progress()
		_debug_probe.map_process_ms = _debug_probe.elapsed_ms(process_start)
		return

	_update_timer -= delta
	if _update_timer <= 0.0:
		_update_timer = update_interval_seconds
		step_start = Time.get_ticks_usec()
		ensure_chunks_around(_player.global_position)
		_debug_probe.ensure_ms = _debug_probe.elapsed_ms(step_start)
	else:
		_debug_probe.ensure_ms = 0.0
	step_start = Time.get_ticks_usec()
	_process_pending_chunk_loads()
	_debug_probe.pending_loads_ms = _debug_probe.elapsed_ms(step_start)
	_debug_probe.map_process_ms = _debug_probe.elapsed_ms(process_start)


func setup(planet_controller: PlanetController, player: Node2D) -> void:
	_planet_controller = planet_controller
	_player = player
	_visual_jobs.setup(self, CSHARP_RUNTIME_MANAGER_PATH)
	_layer_installer.setup(self, _planet_controller)
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
	var prefetch_center_chunk: Vector2i = center_chunk + _scheduler.get_directional_preload_offset(
		planet_position,
		_get_rendered_chunk_size(chunk_size, tile_size),
		directional_preload_chunks
	)
	var changed_window: bool = _scheduler.update_streaming_window(
		center_chunk,
		prefetch_center_chunk,
		load_radius,
		visible_radius
	)
	if not changed_window:
		_scheduler.sort_pending_chunks(center_chunk, prefetch_center_chunk, visible_radius)
		_cancel_preload_jobs_when_visible_pending(center_chunk, visible_radius)
		_layer_installer.sync_loaded_chunk_visibility(center_chunk, visible_radius)
		_refresh_collision_window(center_chunk)
		return

	var required_coords: Array[Vector2i] = _scheduler.build_required_coords(
		center_chunk,
		prefetch_center_chunk,
		load_radius
	)
	for chunk_coord in required_coords:
		_queue_chunk_layer(chunk_coord)

	_unload_missing_chunks(required_coords)
	_planet_controller.unload_chunks_except(required_coords)
	_scheduler.sort_pending_chunks(center_chunk, prefetch_center_chunk, visible_radius)
	_cancel_preload_jobs_when_visible_pending(center_chunk, visible_radius)
	_layer_installer.sync_loaded_chunk_visibility(center_chunk, visible_radius)
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
			var loaded_layers: Dictionary = _layer_installer.get_loaded_layers()
			if not _scheduler.required_chunk_keys.is_empty() and not _scheduler.required_chunk_keys.has(key) and not loaded_layers.has(key):
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
	_scheduler.set_required_keys(_preload_required_keys)
	_scheduler.update_streaming_window(center_chunk, center_chunk, load_radius, load_radius)
	_scheduler.sort_pending_chunks(center_chunk, center_chunk, load_radius)
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


func get_debug_snapshot() -> Dictionary:
	return _debug_probe.build_snapshot(
		_layer_installer.get_loaded_layers(),
		_scheduler.get_required_count(),
		_scheduler.get_pending_count(),
		_visual_jobs.get_active_count(),
		_visual_jobs.get_completed_count(),
		_scheduler.last_visible_radius,
		_scheduler.last_load_radius,
		max_runtime_visible_chunk_radius,
		preload_chunk_margin,
		directional_preload_chunks
	)


func _queue_chunk_layer(chunk_coord: Vector2i) -> void:
	_scheduler.queue_chunk_layer(
		chunk_coord,
		_layer_installer.get_loaded_layers(),
		_visual_jobs.active_visual_jobs
	)


func _process_pending_chunk_loads() -> void:
	_scheduler.process_pending_chunk_loads(
		_get_chunk_loads_per_frame(),
		_get_chunk_data_task_limit(),
		_visual_jobs.get_active_count(),
		Callable(self, "_start_chunk_visual_job")
	)


func _start_chunk_visual_job(chunk_coord: Vector2i) -> void:
	if _planet_controller == null:
		return
	var started: bool = _visual_jobs.start_chunk_visual_job(
		chunk_coord,
		_planet_controller,
		_layer_installer.get_loaded_layers()
	)
	if started:
		_debug_probe.started_jobs += 1


func _process_completed_visual_jobs() -> void:
	_collect_completed_visual_jobs()
	_install_completed_visual_results()
	if _preload_active:
		_update_preload_progress()


func _collect_completed_visual_jobs() -> void:
	var result: Dictionary = _visual_jobs.collect_completed_visual_jobs(_get_visual_result_drain_limit())
	_debug_probe.drained_results += int(result.get("drained_count", 0))
	var rerender_coords: Array = result.get("rerender_coords", []) as Array
	for raw_coord in rerender_coords:
		if raw_coord is Vector2i:
			_queue_chunk_layer(raw_coord as Vector2i)


func _install_completed_visual_results() -> void:
	if not _visual_jobs.has_completed_visual_results():
		return

	_visual_jobs.sort_completed_visual_results(
		_layer_installer.get_loaded_layers(),
		_scheduler.last_center_chunk,
		_scheduler.last_visible_radius,
		visible_chunk_radius
	)

	var installed_count: int = 0
	var install_budget: int = _get_chunk_installs_per_frame()
	while _visual_jobs.has_completed_visual_results() and installed_count < install_budget:
		var entry: Dictionary = _visual_jobs.pop_completed_visual_result()
		if _install_completed_visual_result(entry):
			installed_count += 1
	_debug_probe.installed_chunks += installed_count


func _install_completed_visual_result(entry: Dictionary) -> bool:
	return _layer_installer.install_completed_visual_result(
		entry,
		_visual_jobs.get_runtime_manager(),
		_scheduler.required_chunk_keys,
		_scheduler.last_center_chunk,
		_scheduler.last_visible_radius,
		water_collision_chunk_radius,
		water_collision_layer,
		water_collision_mask
	)


func _refresh_collision_window(center_chunk: Vector2i) -> void:
	var processed_count: int = _layer_installer.refresh_collision_window(
		center_chunk,
		max_water_collision_updates_per_frame,
		water_collision_chunk_radius,
		water_collision_layer,
		water_collision_mask,
		_scheduler.last_center_chunk,
		_scheduler.last_visible_radius
	)
	_debug_probe.collision_updates += processed_count


func _process_collision_refresh_queue() -> void:
	var processed_count: int = _layer_installer.process_collision_refresh_queue(
		max_water_collision_updates_per_frame,
		water_collision_chunk_radius,
		water_collision_layer,
		water_collision_mask,
		_scheduler.last_center_chunk,
		_scheduler.last_visible_radius
	)
	_debug_probe.collision_updates += processed_count


func _unload_missing_chunks(required_coords: Array[Vector2i]) -> void:
	_visual_jobs.drop_completed_visual_results_except(_scheduler.required_chunk_keys)
	_layer_installer.unload_missing_chunks(required_coords)
	_visual_jobs.cancel_active_jobs_except(_scheduler.required_chunk_keys)
	_scheduler.filter_pending_except(_scheduler.required_chunk_keys)


func _remove_chunk_layers(chunk_coord: Vector2i, queue_after_cancel: bool = false) -> void:
	var key: String = _coord_to_key(chunk_coord)
	_visual_jobs.remove_completed_visual_result(key)
	_layer_installer.remove_loaded_chunk(key)
	_scheduler.remove_pending_key(key)

	if _visual_jobs.cancel_for_rerender(key, chunk_coord, queue_after_cancel):
		return

	if queue_after_cancel:
		_queue_chunk_layer(chunk_coord)


func _cancel_all_visual_jobs(_wait_for_completion: bool) -> void:
	_visual_jobs.cancel_all_visual_jobs()
	_scheduler.reset_all()
	_preload_active = false
	_preload_completed = false
	_preload_required_keys.clear()
	_preload_total_count = 0
	_preload_loaded_count = 0
	_layer_installer.last_collision_center_chunk = INVALID_CHUNK_COORD
	_restore_preload_data_task_limit()
	_reset_streaming_cursor()


func _reset_streaming_cursor() -> void:
	_update_timer = 0.0
	_scheduler.reset_streaming_cursor()
	_layer_installer.last_collision_center_chunk = INVALID_CHUNK_COORD


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


func _cancel_preload_jobs_when_visible_pending(visible_center_chunk: Vector2i, visible_radius: int) -> void:
	if not _scheduler.has_pending_visible_chunk(visible_center_chunk, visible_radius):
		return
	_visual_jobs.cancel_far_jobs_for_visible_pending(visible_center_chunk, visible_radius)


func _get_visible_chunk_radius(chunk_size: int, tile_size: int) -> int:
	return _get_visible_chunk_radius_for_zoom(chunk_size, tile_size, _get_camera_zoom())


func _get_preload_visible_chunk_radius(chunk_size: int, tile_size: int) -> int:
	return _get_visible_chunk_radius_for_zoom(chunk_size, tile_size, _get_preload_camera_zoom_floor())


func _get_visible_chunk_radius_for_zoom(chunk_size: int, tile_size: int, camera_zoom: float) -> int:
	var viewport_size: Vector2 = Vector2(get_viewport_rect().size)
	var visible_planet_size: Vector2 = viewport_size / maxf(camera_zoom, 0.01)
	var chunk_planet_size: float = _get_rendered_chunk_size(chunk_size, tile_size)
	var calculated_radius: int = ceili(maxf(visible_planet_size.x, visible_planet_size.y) / chunk_planet_size * 0.5)
	var resolved_radius: int = maxi(calculated_radius, visible_chunk_radius)
	if max_runtime_visible_chunk_radius > 0:
		resolved_radius = mini(resolved_radius, max_runtime_visible_chunk_radius)
	return resolved_radius


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
	var loaded_layers: Dictionary = _layer_installer.get_loaded_layers()
	for key in _preload_required_keys.keys():
		if loaded_layers.has(str(key)):
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
