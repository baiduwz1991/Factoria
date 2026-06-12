class_name ChunkLayerInstaller
extends RefCounted

const WATER_RECT_STRIDE: int = 4
const VISUAL_COMMAND_STRIDE: int = 5
const INVALID_CHUNK_COORD: Vector2i = Vector2i(2147483647, 2147483647)

var loaded_chunk_layers: Dictionary = {}
var last_collision_center_chunk: Vector2i = INVALID_CHUNK_COORD

var _owner: Node2D = null
var _planet_controller: PlanetController = null
var _pending_collision_refresh_keys: Array[String] = []
var _pending_collision_refresh_key_set: Dictionary = {}


func setup(owner: Node2D, planet_controller: PlanetController) -> void:
	_owner = owner
	_planet_controller = planet_controller


func clear() -> void:
	for key in loaded_chunk_layers.keys():
		_free_layers(loaded_chunk_layers[key] as Dictionary)
	loaded_chunk_layers.clear()
	_pending_collision_refresh_keys.clear()
	_pending_collision_refresh_key_set.clear()
	last_collision_center_chunk = INVALID_CHUNK_COORD


func install_completed_visual_result(
	entry: Dictionary,
	runtime_manager: Node,
	required_keys: Dictionary,
	center_chunk: Vector2i,
	visible_radius: int,
	water_collision_chunk_radius: int,
	water_collision_layer: int,
	water_collision_mask: int
) -> bool:
	var key: String = str(entry.get("key", ""))
	var visual_data: Dictionary = entry.get("visual_data", {}) as Dictionary
	if key == "" or visual_data.is_empty():
		return false
	if not required_keys.is_empty() and not required_keys.has(key):
		return false
	if loaded_chunk_layers.has(key):
		return false
	if runtime_manager == null or _owner == null:
		return false

	var chunk_coord: Vector2i = visual_data.get("chunk_coord", Vector2i.ZERO) as Vector2i
	var chunk_size: int = maxi(int(visual_data.get("chunk_size", 1)), 1)
	var tile_size: int = maxi(int(visual_data.get("tile_size", 32)), 1)
	var canvas: Node2D = runtime_manager.call("CreateTerrainChunkCanvas", visual_data) as Node2D
	if canvas == null:
		return false
	canvas.name = "TerrainChunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
	canvas.position = _chunk_coord_to_planet_position(chunk_coord, chunk_size, tile_size)
	_owner.add_child(canvas)

	var layers: Dictionary = {
		&"terrain": canvas,
		&"visual_data": visual_data
	}
	if _should_have_water_collision(chunk_coord, center_chunk, water_collision_chunk_radius):
		var collision_body: StaticBody2D = _create_water_collision_body_from_visual_data(
			visual_data,
			water_collision_layer,
			water_collision_mask
		)
		if collision_body != null:
			layers[&"water_collision"] = collision_body

	loaded_chunk_layers[key] = layers
	_apply_render_visibility_for_key(key, center_chunk, visible_radius)
	return true


func unload_missing_chunks(required_coords: Array[Vector2i]) -> void:
	var required_keys: Dictionary = {}
	for coord in required_coords:
		required_keys[_coord_to_key(coord)] = true

	for key in loaded_chunk_layers.keys():
		if required_keys.has(str(key)):
			continue
		_free_layers(loaded_chunk_layers[key] as Dictionary)
		loaded_chunk_layers.erase(key)


func remove_loaded_chunk(key: String) -> void:
	if not loaded_chunk_layers.has(key):
		return
	_free_layers(loaded_chunk_layers[key] as Dictionary)
	loaded_chunk_layers.erase(key)


func sync_loaded_chunk_visibility(center_chunk: Vector2i, visible_radius: int) -> void:
	for raw_key in loaded_chunk_layers.keys():
		_apply_render_visibility_for_key(str(raw_key), center_chunk, visible_radius)


func refresh_collision_window(
	center_chunk: Vector2i,
	max_water_collision_updates_per_frame: int,
	water_collision_chunk_radius: int,
	water_collision_layer: int,
	water_collision_mask: int,
	visible_center_chunk: Vector2i,
	visible_radius: int
) -> int:
	if center_chunk == INVALID_CHUNK_COORD:
		return 0
	if center_chunk == last_collision_center_chunk and _pending_collision_refresh_keys.is_empty():
		return 0
	last_collision_center_chunk = center_chunk
	_pending_collision_refresh_keys.clear()
	_pending_collision_refresh_key_set.clear()
	for raw_key in loaded_chunk_layers.keys():
		_queue_collision_refresh_key(str(raw_key))
	_pending_collision_refresh_keys.sort_custom(func(a: String, b: String) -> bool:
		return _is_collision_refresh_key_before(a, b, center_chunk)
	)
	return process_collision_refresh_queue(
		max_water_collision_updates_per_frame,
		water_collision_chunk_radius,
		water_collision_layer,
		water_collision_mask,
		visible_center_chunk,
		visible_radius
	)


func process_collision_refresh_queue(
	max_water_collision_updates_per_frame: int,
	water_collision_chunk_radius: int,
	water_collision_layer: int,
	water_collision_mask: int,
	visible_center_chunk: Vector2i,
	visible_radius: int
) -> int:
	if _pending_collision_refresh_keys.is_empty():
		return 0
	var processed_count: int = 0
	var process_budget: int = maxi(max_water_collision_updates_per_frame, 1)
	while not _pending_collision_refresh_keys.is_empty() and processed_count < process_budget:
		var key: String = str(_pending_collision_refresh_keys.pop_front())
		_pending_collision_refresh_key_set.erase(key)
		_apply_collision_state_for_key(
			key,
			water_collision_chunk_radius,
			water_collision_layer,
			water_collision_mask,
			visible_center_chunk,
			visible_radius
		)
		processed_count += 1
	return processed_count


func get_loaded_layers() -> Dictionary:
	return loaded_chunk_layers


func _queue_collision_refresh_key(key: String) -> void:
	if key == "" or _pending_collision_refresh_key_set.has(key):
		return
	_pending_collision_refresh_key_set[key] = true
	_pending_collision_refresh_keys.append(key)


func _apply_collision_state_for_key(
	key: String,
	water_collision_chunk_radius: int,
	water_collision_layer: int,
	water_collision_mask: int,
	visible_center_chunk: Vector2i,
	visible_radius: int
) -> void:
	if not loaded_chunk_layers.has(key):
		return
	var layers: Dictionary = loaded_chunk_layers.get(key, {}) as Dictionary
	var visual_data: Dictionary = layers.get(&"visual_data", {}) as Dictionary
	if visual_data.is_empty():
		return

	var chunk_coord: Vector2i = visual_data.get("chunk_coord", Vector2i.ZERO) as Vector2i
	var has_collision: bool = layers.has(&"water_collision")
	var should_have_collision: bool = (
		_chunk_chebyshev_distance(chunk_coord, last_collision_center_chunk)
		<= maxi(water_collision_chunk_radius, 0)
	)
	if should_have_collision and not has_collision:
		var collision_body: StaticBody2D = _create_water_collision_body_from_visual_data(
			visual_data,
			water_collision_layer,
			water_collision_mask
		)
		if collision_body != null:
			layers[&"water_collision"] = collision_body
			loaded_chunk_layers[key] = layers
			_apply_render_visibility_for_key(key, visible_center_chunk, visible_radius)
	elif not should_have_collision and has_collision:
		var collision_node: Node = layers.get(&"water_collision", null) as Node
		if collision_node != null:
			collision_node.queue_free()
		layers.erase(&"water_collision")
		loaded_chunk_layers[key] = layers


func _is_collision_refresh_key_before(a: String, b: String, center_chunk: Vector2i) -> bool:
	return (
		_chunk_distance_sq(_get_loaded_chunk_coord_for_key(a), center_chunk)
		< _chunk_distance_sq(_get_loaded_chunk_coord_for_key(b), center_chunk)
	)


func _get_loaded_chunk_coord_for_key(key: String) -> Vector2i:
	var layers: Dictionary = loaded_chunk_layers.get(key, {}) as Dictionary
	var visual_data: Dictionary = layers.get(&"visual_data", {}) as Dictionary
	if visual_data.is_empty():
		return INVALID_CHUNK_COORD
	return visual_data.get("chunk_coord", INVALID_CHUNK_COORD) as Vector2i


func _apply_render_visibility_for_key(key: String, center_chunk: Vector2i, visible_radius: int) -> void:
	if not loaded_chunk_layers.has(key):
		return
	var layers: Dictionary = loaded_chunk_layers.get(key, {}) as Dictionary
	var visual_data: Dictionary = layers.get(&"visual_data", {}) as Dictionary
	if visual_data.is_empty():
		return

	var chunk_coord: Vector2i = visual_data.get("chunk_coord", INVALID_CHUNK_COORD) as Vector2i
	var should_render: bool = _is_chunk_visible_for_render(chunk_coord, center_chunk, visible_radius)
	var terrain_node: CanvasItem = layers.get(&"terrain", null) as CanvasItem
	if terrain_node != null:
		if terrain_node.has_method("SetRenderActive"):
			terrain_node.call("SetRenderActive", should_render)
		else:
			terrain_node.visible = should_render


func _is_chunk_visible_for_render(chunk_coord: Vector2i, center_chunk: Vector2i, visible_radius: int) -> bool:
	if center_chunk == INVALID_CHUNK_COORD:
		return true
	if chunk_coord == INVALID_CHUNK_COORD:
		return false
	return _chunk_chebyshev_distance(chunk_coord, center_chunk) <= maxi(visible_radius, 0)


func _should_have_water_collision(chunk_coord: Vector2i, center_chunk: Vector2i, water_collision_chunk_radius: int) -> bool:
	if center_chunk == INVALID_CHUNK_COORD:
		return false
	return _chunk_chebyshev_distance(chunk_coord, center_chunk) <= maxi(water_collision_chunk_radius, 0)


func _create_water_collision_body_from_visual_data(
	visual_data: Dictionary,
	water_collision_layer: int,
	water_collision_mask: int
) -> StaticBody2D:
	if visual_data.is_empty() or _planet_controller == null or _owner == null:
		return null

	var chunk_coord: Vector2i = visual_data.get("chunk_coord", Vector2i.ZERO) as Vector2i
	var chunk_size: int = maxi(int(visual_data.get("chunk_size", 1)), 1)
	var tile_size: int = maxi(int(visual_data.get("tile_size", _planet_controller.get_tile_size())), 1)
	var water_rects: PackedInt32Array = visual_data.get("water_rects", PackedInt32Array())
	var water_edge_commands: PackedInt32Array = visual_data.get("foam_commands", PackedInt32Array())
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "WaterCollision_%d_%d" % [chunk_coord.x, chunk_coord.y]
	body.collision_layer = water_collision_layer
	body.collision_mask = water_collision_mask
	_owner.add_child(body)

	_add_pure_water_collision_rects(body, chunk_coord, chunk_size, tile_size, water_rects)
	_add_water_edge_collision_polygons(body, chunk_coord, chunk_size, tile_size, water_edge_commands)

	if body.get_child_count() <= 0:
		body.queue_free()
		return null
	return body


func _add_pure_water_collision_rects(
	body: StaticBody2D,
	chunk_coord: Vector2i,
	chunk_size: int,
	tile_size: int,
	water_rects: PackedInt32Array
) -> void:
	for index in range(0, water_rects.size() - WATER_RECT_STRIDE + 1, WATER_RECT_STRIDE):
		var rect := Rect2i(
			water_rects[index],
			water_rects[index + 1],
			water_rects[index + 2],
			water_rects[index + 3]
		)
		_add_water_collision_rect(body, chunk_coord, chunk_size, tile_size, rect)


func _add_water_collision_rect(
	body: StaticBody2D,
	chunk_coord: Vector2i,
	chunk_size: int,
	tile_size: int,
	rect: Rect2i
) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(
		float(rect.size.x * tile_size),
		float(rect.size.y * tile_size)
	)
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	shape_node.shape = shape
	shape_node.position = Vector2(
		float(chunk_coord.x * chunk_size + rect.position.x) * float(tile_size)
			+ float(rect.size.x * tile_size) * 0.5,
		float(chunk_coord.y * chunk_size + rect.position.y) * float(tile_size)
			+ float(rect.size.y * tile_size) * 0.5
	)
	body.add_child(shape_node)


func _add_water_edge_collision_polygons(
	body: StaticBody2D,
	chunk_coord: Vector2i,
	chunk_size: int,
	tile_size: int,
	water_edge_commands: PackedInt32Array
) -> void:
	for index in range(0, water_edge_commands.size() - VISUAL_COMMAND_STRIDE + 1, VISUAL_COMMAND_STRIDE):
		var local_x: int = water_edge_commands[index]
		var local_y: int = water_edge_commands[index + 1]
		var water_mask: int = water_edge_commands[index + 3]
		if water_mask <= 0 or water_mask >= 15:
			continue

		var origin := Vector2(
			float(chunk_coord.x * chunk_size + local_x) * float(tile_size),
			float(chunk_coord.y * chunk_size + local_y) * float(tile_size)
		)
		for polygon in _get_water_collision_polygons(water_mask, float(tile_size)):
			var polygon_node := CollisionPolygon2D.new()
			polygon_node.position = origin
			polygon_node.polygon = polygon
			body.add_child(polygon_node)


func _get_water_collision_polygons(mask: int, size: float) -> Array[PackedVector2Array]:
	var half: float = size * 0.5
	var top_left := Vector2(0.0, 0.0)
	var top_mid := Vector2(half, 0.0)
	var top_right := Vector2(size, 0.0)
	var right_mid := Vector2(size, half)
	var bottom_right := Vector2(size, size)
	var bottom_mid := Vector2(half, size)
	var bottom_left := Vector2(0.0, size)
	var left_mid := Vector2(0.0, half)

	match mask:
		1:
			return [PackedVector2Array([top_left, top_mid, left_mid])]
		2:
			return [PackedVector2Array([top_mid, top_right, right_mid])]
		3:
			return [PackedVector2Array([top_left, top_right, right_mid, left_mid])]
		4:
			return [PackedVector2Array([left_mid, bottom_mid, bottom_left])]
		5:
			return [PackedVector2Array([top_left, top_mid, bottom_mid, bottom_left])]
		6:
			return [
				PackedVector2Array([top_mid, top_right, right_mid]),
				PackedVector2Array([left_mid, bottom_mid, bottom_left])
			]
		7:
			return [PackedVector2Array([top_left, top_right, right_mid, bottom_mid, bottom_left])]
		8:
			return [PackedVector2Array([right_mid, bottom_right, bottom_mid])]
		9:
			return [
				PackedVector2Array([top_left, top_mid, left_mid]),
				PackedVector2Array([right_mid, bottom_right, bottom_mid])
			]
		10:
			return [PackedVector2Array([top_mid, top_right, bottom_right, bottom_mid])]
		11:
			return [PackedVector2Array([top_left, top_right, bottom_right, bottom_mid, left_mid])]
		12:
			return [PackedVector2Array([left_mid, right_mid, bottom_right, bottom_left])]
		13:
			return [PackedVector2Array([top_left, top_mid, right_mid, bottom_right, bottom_left])]
		14:
			return [PackedVector2Array([top_mid, top_right, bottom_right, bottom_left, left_mid])]
		_:
			return []


func _free_layers(layers: Dictionary) -> void:
	for layer in layers.values():
		if layer is Node:
			(layer as Node).queue_free()


func _chunk_coord_to_planet_position(chunk_coord: Vector2i, chunk_size: int, tile_size: int) -> Vector2:
	var rendered_chunk_size: float = float(maxi(chunk_size, 1)) * float(maxi(tile_size, 1))
	return Vector2(
		float(chunk_coord.x) * rendered_chunk_size,
		float(chunk_coord.y) * rendered_chunk_size
	)


func _coord_to_key(chunk_coord: Vector2i) -> String:
	return "%d,%d" % [chunk_coord.x, chunk_coord.y]


func _chunk_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	var delta: Vector2i = a - b
	return maxi(absi(delta.x), absi(delta.y))


func _chunk_distance_sq(a: Vector2i, b: Vector2i) -> int:
	var delta: Vector2i = a - b
	return delta.x * delta.x + delta.y * delta.y
