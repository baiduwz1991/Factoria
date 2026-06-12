class_name MapDebugProbe
extends RefCounted

var map_process_ms: float = 0.0
var completed_jobs_ms: float = 0.0
var collision_ms: float = 0.0
var ensure_ms: float = 0.0
var pending_loads_ms: float = 0.0
var started_jobs: int = 0
var drained_results: int = 0
var installed_chunks: int = 0
var collision_updates: int = 0


func reset_frame_counters() -> void:
	map_process_ms = 0.0
	completed_jobs_ms = 0.0
	collision_ms = 0.0
	ensure_ms = 0.0
	pending_loads_ms = 0.0
	started_jobs = 0
	drained_results = 0
	installed_chunks = 0
	collision_updates = 0


func elapsed_ms(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


func build_snapshot(
	loaded_chunk_layers: Dictionary,
	required_chunk_count: int,
	pending_chunk_count: int,
	active_visual_job_count: int,
	completed_visual_result_count: int,
	visible_radius: int,
	load_radius: int,
	max_visible_radius: int,
	preload_margin: int,
	directional_preload: int
) -> Dictionary:
	var visible_chunk_count: int = 0
	var hidden_chunk_count: int = 0
	var water_collision_count: int = 0
	var terrain_batch_count: int = 0
	var terrain_quad_count: int = 0
	var animated_chunk_count: int = 0
	var visible_animated_chunk_count: int = 0
	var active_animated_chunk_count: int = 0
	for raw_key in loaded_chunk_layers.keys():
		var layers: Dictionary = loaded_chunk_layers.get(raw_key, {}) as Dictionary
		var terrain_node: CanvasItem = layers.get(&"terrain", null) as CanvasItem
		var is_terrain_visible: bool = terrain_node != null and terrain_node.visible
		if is_terrain_visible:
			visible_chunk_count += 1
		else:
			hidden_chunk_count += 1
		if layers.has(&"water_collision"):
			water_collision_count += 1
		var terrain_debug: Dictionary = _get_terrain_node_debug_snapshot(layers)
		terrain_batch_count += int(terrain_debug.get("render_batches", 0))
		terrain_quad_count += int(terrain_debug.get("render_quads", 0))
		if bool(terrain_debug.get("has_animated_water", false)):
			animated_chunk_count += 1
			if is_terrain_visible:
				visible_animated_chunk_count += 1
			if bool(terrain_debug.get("water_animation_active", false)):
				active_animated_chunk_count += 1

	return {
		"loaded_chunks": loaded_chunk_layers.size(),
		"visible_chunks": visible_chunk_count,
		"hidden_chunks": hidden_chunk_count,
		"required_chunks": required_chunk_count,
		"pending_chunks": pending_chunk_count,
		"active_visual_jobs": active_visual_job_count,
		"completed_visual_results": completed_visual_result_count,
		"visible_radius": visible_radius,
		"load_radius": load_radius,
		"max_visible_radius": max_visible_radius,
		"preload_margin": preload_margin,
		"directional_preload": directional_preload,
		"water_collision_chunks": water_collision_count,
		"terrain_batches": terrain_batch_count,
		"terrain_quads": terrain_quad_count,
		"animated_chunks": animated_chunk_count,
		"visible_animated_chunks": visible_animated_chunk_count,
		"active_animated_chunks": active_animated_chunk_count,
		"map_process_ms": map_process_ms,
		"completed_jobs_ms": completed_jobs_ms,
		"collision_ms": collision_ms,
		"ensure_ms": ensure_ms,
		"pending_loads_ms": pending_loads_ms,
		"started_jobs": started_jobs,
		"drained_results": drained_results,
		"installed_chunks": installed_chunks,
		"collision_updates": collision_updates
	}


func _get_terrain_node_debug_snapshot(layers: Dictionary) -> Dictionary:
	var terrain_node: Node = layers.get(&"terrain", null) as Node
	if terrain_node == null:
		return {}
	if not terrain_node.has_method("GetTerrainDebugSnapshot"):
		return {}
	var snapshot_variant: Variant = terrain_node.call("GetTerrainDebugSnapshot")
	if snapshot_variant is Dictionary:
		return snapshot_variant as Dictionary
	return {}
