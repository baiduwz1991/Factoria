class_name DebugPerformanceStats
extends RefCounted


static func get_snapshot() -> Dictionary:
	var fps: int = int(round(Performance.get_monitor(Performance.TIME_FPS)))
	return {
		"fps": fps,
		"frame_ms": _calculate_frame_ms(fps),
		"process_ms": float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0,
		"physics_ms": float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"render_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"render_primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_memory": float(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"texture_memory": float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"video_memory": float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"buffer_memory": float(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
		"physics_2d_active_objects": int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)),
		"physics_2d_collision_pairs": int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)),
		"physics_2d_island_count": int(Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT)),
		"terrain": _get_terrain_snapshot()
	}


static func format_quick_text(snapshot: Dictionary) -> String:
	return "FPS: %d  Frame: %.1f ms\nProcess: %.1f ms  Physics: %.1f ms\nDrawCall: %d  Nodes: %d\nMem: %s  VRAM: %s" % [
		int(snapshot.get("fps", 0)),
		float(snapshot.get("frame_ms", 0.0)),
		float(snapshot.get("process_ms", 0.0)),
		float(snapshot.get("physics_ms", 0.0)),
		int(snapshot.get("draw_calls", 0)),
		int(snapshot.get("node_count", 0)),
		format_bytes(float(snapshot.get("static_memory", 0.0))),
		format_bytes(float(snapshot.get("video_memory", 0.0)))
	]


static func format_detail_text(snapshot: Dictionary) -> String:
	var terrain: Dictionary = snapshot.get("terrain", {}) as Dictionary
	return "性能\nFPS: %d    Frame: %.2f ms\nProcess: %.2f ms    Physics: %.2f ms\nDrawCall: %d    Objects: %d    Primitives: %d\n\n地图\nChunks: %d loaded / %d visible / %d hidden / %d required    Radius: %d visible / %d load / %d max\nJobs: %d pending / %d active / %d done    This frame: %d started / %d drained / %d installed\nMap ms: %.2f total    %.2f jobs    %.2f ensure    %.2f pending    %.2f collision\nTerrain: %d batches    %d quads    animated %d loaded / %d visible / %d active    %d water collision\n\n对象\nNodes: %d    Objects: %d    Resources: %d    Orphans: %d\n\n内存\nStatic: %s    Texture: %s\nVRAM: %s    Buffer: %s\n\nPhysics2D\nActive: %d    Pairs: %d    Islands: %d" % [
		int(snapshot.get("fps", 0)),
		float(snapshot.get("frame_ms", 0.0)),
		float(snapshot.get("process_ms", 0.0)),
		float(snapshot.get("physics_ms", 0.0)),
		int(snapshot.get("draw_calls", 0)),
		int(snapshot.get("render_objects", 0)),
		int(snapshot.get("render_primitives", 0)),
		int(terrain.get("loaded_chunks", 0)),
		int(terrain.get("visible_chunks", 0)),
		int(terrain.get("hidden_chunks", 0)),
		int(terrain.get("required_chunks", 0)),
		int(terrain.get("visible_radius", -1)),
		int(terrain.get("load_radius", -1)),
		int(terrain.get("max_visible_radius", -1)),
		int(terrain.get("pending_chunks", 0)),
		int(terrain.get("active_visual_jobs", 0)),
		int(terrain.get("completed_visual_results", 0)),
		int(terrain.get("started_jobs", 0)),
		int(terrain.get("drained_results", 0)),
		int(terrain.get("installed_chunks", 0)),
		float(terrain.get("map_process_ms", 0.0)),
		float(terrain.get("completed_jobs_ms", 0.0)),
		float(terrain.get("ensure_ms", 0.0)),
		float(terrain.get("pending_loads_ms", 0.0)),
		float(terrain.get("collision_ms", 0.0)),
		int(terrain.get("terrain_batches", 0)),
		int(terrain.get("terrain_quads", 0)),
		int(terrain.get("animated_chunks", 0)),
		int(terrain.get("visible_animated_chunks", 0)),
		int(terrain.get("active_animated_chunks", 0)),
		int(terrain.get("water_collision_chunks", 0)),
		int(snapshot.get("node_count", 0)),
		int(snapshot.get("object_count", 0)),
		int(snapshot.get("resource_count", 0)),
		int(snapshot.get("orphan_node_count", 0)),
		format_bytes(float(snapshot.get("static_memory", 0.0))),
		format_bytes(float(snapshot.get("texture_memory", 0.0))),
		format_bytes(float(snapshot.get("video_memory", 0.0))),
		format_bytes(float(snapshot.get("buffer_memory", 0.0))),
		int(snapshot.get("physics_2d_active_objects", 0)),
		int(snapshot.get("physics_2d_collision_pairs", 0)),
		int(snapshot.get("physics_2d_island_count", 0))
	]


static func _get_terrain_snapshot() -> Dictionary:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null or scene_tree.root == null:
		return {}

	var scene_manager: Node = scene_tree.root.get_node_or_null("SceneManager")
	if scene_manager == null or not scene_manager.has_method("get_current_scene"):
		return {}

	var current_scene: Node = scene_manager.call("get_current_scene") as Node
	if current_scene == null or not current_scene.has_method("get_map_view"):
		return {}

	var map_view: Node = current_scene.call("get_map_view") as Node
	if map_view == null or not map_view.has_method("get_debug_snapshot"):
		return {}

	var snapshot_variant: Variant = map_view.call("get_debug_snapshot")
	if snapshot_variant is Dictionary:
		return snapshot_variant as Dictionary
	return {}


static func format_bytes(byte_count: float) -> String:
	var abs_bytes: float = absf(byte_count)
	if abs_bytes >= 1024.0 * 1024.0 * 1024.0:
		return "%.2f GB" % (byte_count / (1024.0 * 1024.0 * 1024.0))
	if abs_bytes >= 1024.0 * 1024.0:
		return "%.1f MB" % (byte_count / (1024.0 * 1024.0))
	if abs_bytes >= 1024.0:
		return "%.1f KB" % (byte_count / 1024.0)
	return "%.0f B" % byte_count


static func _calculate_frame_ms(fps: int) -> float:
	if fps <= 0:
		return 0.0
	return 1000.0 / float(fps)
