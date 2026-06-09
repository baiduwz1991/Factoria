class_name LoopListView
extends ScrollContainer

const TypesScript: Script = preload("res://assets/src/core/ui-widgets/super-scroll-view/LoopListViewTypes.gd")

signal item_bound(item_index: int, item_node: Node)
signal item_recycled(item_node: Node)
signal top_line_triggered
signal down_line_triggered

@export_enum("TopToBottom:0", "BottomToTop:1", "LeftToRight:2", "RightToLeft:3")
var arrange_type: int = TypesScript.ListItemArrangeType.TOP_TO_BOTTOM
@export var support_variable_size: bool = false
@export var item_padding: float = 0.0
@export var start_pos_offset: float = 0.0
@export var distance_for_new0: float = 200.0
@export var distance_for_new1: float = 200.0
@export var enable_touch_drag_scroll: bool = true
@export var drag_scroll_deadzone: float = 6.0
@export var enable_inertia_scroll: bool = true
@export var inertia_release_boost: float = 28.0
@export var inertia_damping: float = 8.0
@export var inertia_min_speed: float = 8.0
@export var edge_action_drag_size: float = 100.0
@export var hide_scroll_bars: bool = true
@export var item_scene: PackedScene
@export var content_path: NodePath = ^"Content"
@export var auto_anchor_tail_on_reset: bool = true
@export var auto_anchor_frames: int = 8

var is_vert_list: bool = true

var _content: Control = null
var _pool_root: Control = null
var _active_items: Dictionary = {} # index -> Control
var _item_pool: Array[Control] = []

var _item_total_count: int = 0
var _list_view_inited: bool = false
var _default_item_extent: float = 80.0
var _item_extent_cache: Array[float] = []
var _item_start_cache: Array[float] = []
var _content_total_size: float = 0.0

var _dragging: bool = false
var _drag_pointer_id: int = -1
var _drag_last_pos: Vector2 = Vector2.ZERO
var _drag_accum_distance: float = 0.0
var _last_drag_offset_delta: float = 0.0
var _inertia_velocity: float = 0.0
var _needs_refresh: bool = true
var _last_refresh_offset: float = -1.0
var _last_viewport_size: float = -1.0
var _pending_auto_anchor_frames: int = 0
var _edge_drag_action_type: int = 0

const EDGE_ACTION_NONE: int = 0
const EDGE_ACTION_TOP: int = 1
const EDGE_ACTION_DOWN: int = 2


func _ready() -> void:
	_resolve_nodes()
	_apply_scroll_direction()
	_apply_scroll_bar_visibility()
	_default_item_extent = _calc_default_item_extent()
	set_process(true)


func _process(_delta: float) -> void:
	if not _list_view_inited:
		return
	_apply_inertia(_delta)
	if _pending_auto_anchor_frames > 0 and not _dragging:
		_apply_reset_anchor()
		_pending_auto_anchor_frames -= 1
	var curr_offset: float = _get_content_offset()
	var curr_viewport_size: float = _get_view_port_size()
	if _needs_refresh \
		or not is_equal_approx(curr_offset, _last_refresh_offset) \
		or not is_equal_approx(curr_viewport_size, _last_viewport_size):
		_refresh_window()


func _input(event: InputEvent) -> void:
	if not enable_touch_drag_scroll or not _list_view_inited or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			if _is_point_inside_view(touch.position):
				_start_drag(touch.index, touch.position)
		elif _dragging and _drag_pointer_id == touch.index:
			_stop_drag()
		return
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if _dragging and _drag_pointer_id == drag.index:
			_apply_drag_delta(drag.position - _drag_last_pos)
			_drag_last_pos = drag.position
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if _is_point_inside_view(mb.position):
				_start_drag(-999, mb.position)
		elif _dragging and _drag_pointer_id == -999:
			_stop_drag()
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _dragging and _drag_pointer_id == -999:
			_apply_drag_delta(mm.position - _drag_last_pos)
			_drag_last_pos = mm.position


func init_list_view(item_total_count: int = 0, _init_param: RefCounted = null) -> void:
	if _list_view_inited:
		push_error("[LoopListView] init_list_view 只能调用一次。")
		return
	if _content == null:
		return
	_list_view_inited = true
	_set_item_count(item_total_count, true)


func set_count_and_refresh(item_count: int, reset_pos: bool = true) -> void:
	if not _list_view_inited:
		return
	_set_item_count(item_count, reset_pos)


func reset_list_view(reset_pos: bool = true) -> void:
	if reset_pos:
		_set_content_offset(0.0)
	_mark_refresh_dirty()
	_refresh_window()


func refresh_all_shown_item() -> void:
	var keys: Array = _active_items.keys()
	keys.sort()
	for key in keys:
		var index: int = int(key)
		var item: Control = _active_items[index]
		item_bound.emit(index, item)
		if support_variable_size and is_vert_list:
			_update_extent_for_item(index, item)
	_rebuild_layout_cache()
	_mark_refresh_dirty()
	_refresh_window()


func on_item_size_changed(item_index: int) -> void:
	if not support_variable_size or not is_vert_list:
		return
	var item: Control = _active_items.get(item_index, null)
	if item == null:
		return
	var old_max_offset: float = maxf(0.0, _content_total_size - _get_view_port_size())
	var old_offset: float = _get_content_offset()
	var keep_bottom_anchor: bool = _is_reverse_arrange() and old_offset >= old_max_offset - 2.0
	if _update_extent_for_item(item_index, item):
		_rebuild_layout_cache()
		if keep_bottom_anchor:
			scroll_to_list_end()
		_mark_refresh_dirty()
		_refresh_window()


func move_panel_to_item_index(item_index: int, offset: float) -> void:
	if _item_total_count <= 0:
		return
	_pending_auto_anchor_frames = 0
	var clamped_index: int = clampi(item_index, 0, _item_total_count - 1)
	var target: float = _get_item_start(clamped_index)
	if _is_reverse_arrange():
		target = target - (_get_view_port_size() - _get_item_extent(clamped_index))
	_set_content_offset(target + offset)
	_mark_refresh_dirty()
	_refresh_window()


func move_panel_by_offset(offset: float) -> void:
	_pending_auto_anchor_frames = 0
	_set_content_offset(_get_content_offset() + offset)
	_mark_refresh_dirty()
	_refresh_window()


func scroll_to_list_end() -> void:
	_pending_auto_anchor_frames = 0
	if _item_total_count <= 0:
		_set_content_offset(0.0)
		_mark_refresh_dirty()
		return
	if _is_reverse_arrange():
		var target: float = _get_item_start(0) - (_get_view_port_size() - _get_item_extent(0))
		_set_content_offset(target)
		_mark_refresh_dirty()
		_refresh_window()
		return
	var max_offset: float = maxf(0.0, _content_total_size - _get_view_port_size())
	_set_content_offset(max_offset)
	_mark_refresh_dirty()
	_refresh_window()


func get_shown_item_by_item_index(item_index: int) -> Node:
	return _active_items.get(item_index, null)


func recycle_all_item() -> void:
	var keys: Array = _active_items.keys()
	for key in keys:
		var i: int = int(key)
		var item: Control = _active_items.get(i, null)
		if item != null:
			_recycle_item(item)
	_active_items.clear()


func _set_item_count(count: int, reset_pos: bool) -> void:
	_item_total_count = maxi(0, count)
	if _item_total_count == 0:
		recycle_all_item()
		_item_extent_cache.clear()
		_item_start_cache.clear()
		_content_total_size = 0.0
		_update_content_size()
		_set_content_offset(0.0)
		_pending_auto_anchor_frames = 0
		_mark_refresh_dirty()
		return
	_item_extent_cache.resize(_item_total_count)
	var i: int = 0
	while i < _item_total_count:
		if _item_extent_cache[i] <= 0.0:
			_item_extent_cache[i] = _default_item_extent
		i += 1
	_rebuild_layout_cache()
	if reset_pos:
		if _is_reverse_arrange() and auto_anchor_tail_on_reset:
			_pending_auto_anchor_frames = maxi(1, auto_anchor_frames)
			_apply_reset_anchor()
		else:
			_pending_auto_anchor_frames = 0
			_set_content_offset(0.0)
	else:
		_pending_auto_anchor_frames = 0
	_mark_refresh_dirty()
	_refresh_window()


func _resolve_nodes() -> void:
	_content = get_node_or_null(content_path) as Control
	if _content == null:
		push_error("[LoopListView] 缺少 content 节点。")
		return
	_pool_root = get_node_or_null("__LoopListViewPool__") as Control
	if _pool_root == null:
		_pool_root = Control.new()
		_pool_root.name = "__LoopListViewPool__"
		add_child(_pool_root)
	_pool_root.visible = false


func _apply_scroll_direction() -> void:
	is_vert_list = arrange_type == TypesScript.ListItemArrangeType.TOP_TO_BOTTOM or arrange_type == TypesScript.ListItemArrangeType.BOTTOM_TO_TOP
	if is_vert_list:
		vertical_scroll_mode = SCROLL_MODE_SHOW_NEVER if hide_scroll_bars else SCROLL_MODE_AUTO
		horizontal_scroll_mode = SCROLL_MODE_DISABLED
	else:
		horizontal_scroll_mode = SCROLL_MODE_SHOW_NEVER if hide_scroll_bars else SCROLL_MODE_AUTO
		vertical_scroll_mode = SCROLL_MODE_DISABLED


func _apply_scroll_bar_visibility() -> void:
	if not hide_scroll_bars:
		return
	var h: HScrollBar = get_h_scroll_bar()
	var v: VScrollBar = get_v_scroll_bar()
	if h != null:
		h.visible = false
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if v != null:
		v.visible = false
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh_window() -> void:
	if _content == null or _item_total_count <= 0:
		_last_refresh_offset = _get_content_offset()
		_last_viewport_size = _get_view_port_size()
		_needs_refresh = false
		return

	var offset: float = _get_content_offset()
	var window_start: float = maxf(0.0, offset - distance_for_new0)
	var window_end: float = maxf(window_start, offset + _get_view_port_size() + distance_for_new1)
	var layout_changed: bool = false

	var needed: Dictionary = {}
	var begin_order: int = _find_first_order_by_end(window_start)
	var end_order: int = _find_first_order_by_start_gt(window_end)
	var order: int = begin_order
	while order < end_order:
		var idx: int = _ordered_index_to_item_index(order)
		needed[idx] = true
		order += 1

	var to_recycle: Array[int] = []
	for key in _active_items.keys():
		var i: int = int(key)
		if not needed.has(i):
			to_recycle.append(i)
	for i in to_recycle:
		var old_item: Control = _active_items.get(i, null)
		_active_items.erase(i)
		if old_item != null:
			_recycle_item(old_item)

	var keys: Array = needed.keys()
	keys.sort()
	for key in keys:
		var i: int = int(key)
		var item: Control = _active_items.get(i, null)
		if item == null:
			item = _obtain_item()
			if item == null:
				continue
			_active_items[i] = item
			_fit_item_cross_size(item)
			if item.has_method("_set_list_item_runtime"):
				item.call("_set_list_item_runtime", self, i, item_padding, start_pos_offset)
			item_bound.emit(i, item)
			if support_variable_size and is_vert_list:
				if _update_extent_for_item(i, item):
					layout_changed = true
		else:
			_fit_item_cross_size(item)
			if item.has_method("_set_list_item_runtime"):
				item.call("_set_list_item_runtime", self, i, item_padding, start_pos_offset)

	if layout_changed:
		_rebuild_layout_cache()

	# 第二阶段统一定位，避免“边创建边重排”导致首屏间距异常。
	for key in keys:
		var i: int = int(key)
		var item: Control = _active_items.get(i, null)
		if item != null:
			_set_item_position(i, item)

	_last_refresh_offset = offset
	_last_viewport_size = _get_view_port_size()
	_needs_refresh = false


func _ordered_index_to_item_index(order_index: int) -> int:
	if not _is_reverse_arrange():
		return order_index
	return (_item_total_count - 1) - order_index


func _get_order_start(order_index: int) -> float:
	var item_index: int = _ordered_index_to_item_index(order_index)
	return _get_item_start(item_index)


func _get_order_end(order_index: int) -> float:
	var item_index: int = _ordered_index_to_item_index(order_index)
	return _get_item_start(item_index) + _get_item_extent(item_index)


func _find_first_order_by_end(window_start: float) -> int:
	var left: int = 0
	var right: int = _item_total_count
	while left < right:
		var mid: int = int((left + right) / 2)
		if _get_order_end(mid) >= window_start:
			right = mid
		else:
			left = mid + 1
	return left


func _find_first_order_by_start_gt(window_end: float) -> int:
	var left: int = 0
	var right: int = _item_total_count
	while left < right:
		var mid: int = int((left + right) / 2)
		if _get_order_start(mid) > window_end:
			right = mid
		else:
			left = mid + 1
	return left


func _set_item_position(item_index: int, item: Control) -> void:
	var axis_pos: float = _get_item_start(item_index)
	if is_vert_list:
		item.position = Vector2(start_pos_offset, axis_pos)
	else:
		item.position = Vector2(axis_pos, start_pos_offset)


func _fit_item_cross_size(item: Control) -> void:
	if item == null or _content == null:
		return
	if is_vert_list:
		var target_width: float = maxf(maxf(_content.size.x, _content.custom_minimum_size.x), size.x)
		target_width = maxf(target_width, 1.0)
		item.size.x = target_width
	else:
		var target_height: float = maxf(maxf(_content.size.y, _content.custom_minimum_size.y), size.y)
		target_height = maxf(target_height, 1.0)
		item.size.y = target_height


func _obtain_item() -> Control:
	while not _item_pool.is_empty():
		var pooled: Control = _item_pool.pop_back()
		if is_instance_valid(pooled):
			if pooled.get_parent() != _content:
				pooled.reparent(_content)
			pooled.visible = true
			return pooled
	if item_scene == null:
		push_error("[LoopListView] item_scene 未设置。")
		return null
	var node: Node = item_scene.instantiate()
	var item: Control = node as Control
	if item == null:
		push_error("[LoopListView] item_scene 根节点必须是 Control。")
		if is_instance_valid(node):
			node.queue_free()
		return null
	if item.get_parent() != _content:
		_content.add_child(item)
	item.visible = true
	return item


func _recycle_item(item: Control) -> void:
	if item == null or not is_instance_valid(item):
		return
	item_recycled.emit(item)
	if item.get_parent() != _pool_root:
		item.reparent(_pool_root)
	item.visible = false
	_item_pool.append(item)


func _rebuild_layout_cache() -> void:
	_item_start_cache.resize(_item_total_count)
	var cursor: float = 0.0
	if _is_reverse_arrange():
		var i: int = _item_total_count - 1
		while i >= 0:
			_item_start_cache[i] = cursor
			cursor += _get_item_extent(i)
			if i > 0:
				cursor += item_padding
			i -= 1
	else:
		var i: int = 0
		while i < _item_total_count:
			_item_start_cache[i] = cursor
			cursor += _get_item_extent(i)
			if i < _item_total_count - 1:
				cursor += item_padding
			i += 1
	_content_total_size = cursor
	_update_content_size()


func _update_content_size() -> void:
	if _content == null:
		return
	var min_size: Vector2 = _content.custom_minimum_size
	if is_vert_list:
		min_size.x = maxf(min_size.x, size.x)
		min_size.y = _content_total_size
	else:
		min_size.y = maxf(min_size.y, size.y)
		min_size.x = _content_total_size
	_content.custom_minimum_size = min_size


func _update_extent_for_item(index: int, item: Control) -> bool:
	if index < 0 or index >= _item_extent_cache.size():
		return false
	var new_extent: float = _measure_item_extent(item)
	var old_extent: float = _item_extent_cache[index]
	if is_equal_approx(new_extent, old_extent):
		return false
	_item_extent_cache[index] = new_extent
	return true


func _get_item_extent(index: int) -> float:
	if index < 0 or index >= _item_extent_cache.size():
		return _default_item_extent
	return maxf(1.0, _item_extent_cache[index])


func _get_item_start(index: int) -> float:
	if index < 0 or index >= _item_start_cache.size():
		return 0.0
	return _item_start_cache[index]


func _calc_default_item_extent() -> float:
	if item_scene == null:
		return 80.0
	var node: Node = item_scene.instantiate()
	var extent: float = 80.0
	if node is Control:
		extent = _measure_item_extent(node as Control)
	if is_instance_valid(node):
		node.queue_free()
	return maxf(1.0, extent)


func _measure_item_extent(item: Control) -> float:
	if item == null:
		return 80.0
	if is_vert_list:
		return maxf(item.custom_minimum_size.y, 1.0)
	return maxf(item.custom_minimum_size.x, 1.0)


func _get_content_offset() -> float:
	return float(scroll_vertical) if is_vert_list else float(scroll_horizontal)


func _set_content_offset(offset: float) -> void:
	var max_offset: float = maxf(0.0, _content_total_size - _get_view_port_size())
	var clamped: float = clampf(offset, 0.0, max_offset)
	var old_offset: float = _get_content_offset()
	if is_vert_list:
		scroll_vertical = int(clamped)
	else:
		scroll_horizontal = int(clamped)
	if not is_equal_approx(old_offset, clamped):
		_mark_refresh_dirty()


func _get_view_port_size() -> float:
	return size.y if is_vert_list else size.x


func _is_reverse_arrange() -> bool:
	return arrange_type == TypesScript.ListItemArrangeType.BOTTOM_TO_TOP or arrange_type == TypesScript.ListItemArrangeType.RIGHT_TO_LEFT


func _start_drag(pointer_id: int, global_pos: Vector2) -> void:
	_pending_auto_anchor_frames = 0
	_inertia_velocity = 0.0
	_last_drag_offset_delta = 0.0
	_edge_drag_action_type = EDGE_ACTION_NONE
	_dragging = true
	_drag_pointer_id = pointer_id
	_drag_last_pos = global_pos
	_drag_accum_distance = 0.0


func _stop_drag() -> void:
	if enable_inertia_scroll and _drag_accum_distance >= drag_scroll_deadzone:
		_inertia_velocity = _last_drag_offset_delta * inertia_release_boost
	else:
		_inertia_velocity = 0.0
	_emit_edge_drag_action()
	_dragging = false
	_drag_pointer_id = -1
	_drag_accum_distance = 0.0
	_edge_drag_action_type = EDGE_ACTION_NONE


func _apply_drag_delta(delta: Vector2) -> void:
	var axis_delta: float = delta.y if is_vert_list else delta.x
	_drag_accum_distance += absf(axis_delta)
	if _drag_accum_distance < drag_scroll_deadzone:
		return
	var old_offset: float = _get_content_offset()
	var attempted_offset: float = old_offset - axis_delta
	_update_edge_drag_action(old_offset, attempted_offset)
	_set_content_offset(attempted_offset)
	var new_offset: float = _get_content_offset()
	_last_drag_offset_delta = new_offset - old_offset
	_refresh_window()


func _is_point_inside_view(global_pos: Vector2) -> bool:
	return get_global_rect().has_point(global_pos)


func _mark_refresh_dirty() -> void:
	_needs_refresh = true


func _apply_reset_anchor() -> void:
	if _item_total_count <= 0:
		_set_content_offset(0.0)
		return
	if _is_reverse_arrange() and auto_anchor_tail_on_reset:
		var target: float = _get_item_start(0) - (_get_view_port_size() - _get_item_extent(0))
		_set_content_offset(target)
	else:
		_set_content_offset(0.0)


func _apply_inertia(delta: float) -> void:
	if not enable_inertia_scroll or _dragging:
		return
	if absf(_inertia_velocity) < inertia_min_speed:
		_inertia_velocity = 0.0
		return
	var old_offset: float = _get_content_offset()
	_set_content_offset(old_offset + _inertia_velocity * delta)
	var new_offset: float = _get_content_offset()
	if is_equal_approx(old_offset, new_offset):
		_inertia_velocity = 0.0
		return
	var damping_t: float = clampf(inertia_damping * delta, 0.0, 1.0)
	_inertia_velocity = lerpf(_inertia_velocity, 0.0, damping_t)


func _update_edge_drag_action(old_offset: float, attempted_offset: float) -> void:
	var max_offset: float = maxf(0.0, _content_total_size - _get_view_port_size())
	if old_offset <= 0.0 and attempted_offset < 0.0:
		if -attempted_offset >= edge_action_drag_size:
			_edge_drag_action_type = EDGE_ACTION_TOP
		return
	if old_offset >= max_offset and attempted_offset > max_offset:
		if attempted_offset - max_offset >= edge_action_drag_size:
			_edge_drag_action_type = EDGE_ACTION_DOWN


func _emit_edge_drag_action() -> void:
	if _edge_drag_action_type == EDGE_ACTION_TOP:
		top_line_triggered.emit()
	elif _edge_drag_action_type == EDGE_ACTION_DOWN:
		down_line_triggered.emit()
