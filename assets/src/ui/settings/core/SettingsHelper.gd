class_name SettingsHelper
extends RefCounted


static func normalize_display_snapshot(
	snapshot: Dictionary,
	default_mode_index: int,
	default_resolution_index: int,
	default_fps_limit_index: int,
	window_mode_count: int,
	resolution_count: int,
	fps_limit_count: int
) -> Dictionary:
	var max_mode_index: int = maxi(window_mode_count - 1, 0)
	var max_resolution_index: int = maxi(resolution_count - 1, 0)
	var max_fps_limit_index: int = maxi(fps_limit_count - 1, 0)
	var mode_index: int = clampi(int(snapshot.get("mode_index", default_mode_index)), 0, max_mode_index)
	var resolution_index: int = clampi(int(snapshot.get("resolution_index", default_resolution_index)), 0, max_resolution_index)
	var fps_limit_index: int = clampi(int(snapshot.get("fps_limit_index", default_fps_limit_index)), 0, max_fps_limit_index)
	return {
		"mode_index": mode_index,
		"resolution_index": resolution_index,
		"fps_limit_index": fps_limit_index
	}


static func build_resolution_labels(resolution_options: Array[Vector2i]) -> Array[String]:
	var labels: Array[String] = []
	for size in resolution_options:
		labels.append("%dx%d" % [size.x, size.y])
	return labels


static func pick_resolution(
	resolution_options: Array[Vector2i],
	resolution_index: int
) -> Vector2i:
	if resolution_options.is_empty():
		return Vector2i.ZERO
	var safe_index: int = clampi(resolution_index, 0, resolution_options.size() - 1)
	return resolution_options[safe_index]


static func pick_fps_limit(
	fps_limit_options: Array[int],
	fps_limit_index: int
) -> int:
	if fps_limit_options.is_empty():
		return 0
	var safe_index: int = clampi(fps_limit_index, 0, fps_limit_options.size() - 1)
	return fps_limit_options[safe_index]
