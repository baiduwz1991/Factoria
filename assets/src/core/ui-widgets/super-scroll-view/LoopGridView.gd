class_name LoopGridView
extends "res://assets/src/core/ui-widgets/super-scroll-view/LoopListView.gd"

## 网格单元尺寸（宽高）。
@export var cell_size: Vector2 = Vector2(100.0, 100.0)
## 网格单元间距（横向、纵向）。
@export var cell_spacing: Vector2 = Vector2(8.0, 8.0)
## 固定横轴数量（竖向列表=列数，横向列表=行数），<=0 表示自动根据视口计算。
@export var fixed_cross_count: int = 0

signal grid_item_init(item_index: int, item_node: Node, item_data: Variant)
signal grid_item_enable(item_index: int, item_node: Node, item_data: Variant)
signal grid_item_update(item_index: int, item_node: Node, item_data: Variant)
signal grid_item_disable(item_index: int, item_node: Node, item_data: Variant)
signal grid_item_destroy(item_index: int, item_node: Node, item_data: Variant)

var _data_list: Array[Variant] = []
var _item_state_by_id: Dictionary = {} # instance_id -> {inited: bool, shown: bool, index: int}
var _last_cross_count: int = 1
var _current_show_count: int = 0


func _ready() -> void:
	super._ready()
	if not is_connected("item_bound", Callable(self, "_on_grid_item_bound")):
		connect("item_bound", Callable(self, "_on_grid_item_bound"))
	if not is_connected("item_recycled", Callable(self, "_on_grid_item_recycled")):
		connect("item_recycled", Callable(self, "_on_grid_item_recycled"))


func _process(delta: float) -> void:
	var cross_count_now: int = _get_cross_count()
	if cross_count_now != _last_cross_count:
		_last_cross_count = cross_count_now
		_rebuild_layout_cache()
		_mark_refresh_dirty()
	super._process(delta)


func set_data_list(data_list: Array[Variant], reset_pos: bool = false) -> void:
	_data_list = data_list
	_current_show_count = data_list.size()
	set_count_and_refresh(_current_show_count, reset_pos)
	if not reset_pos:
		refresh_list()


func refresh_list() -> void:
	refresh_all_shown_item()


func set_data_list_and_move_to_index(data_list: Array[Variant], move_index: int) -> void:
	_data_list = data_list
	_current_show_count = data_list.size()
	set_count_and_refresh(_current_show_count, false)
	move_to_index(move_index)


func set_data_list_and_snap_to_index(data_list: Array[Variant], snap_index: int) -> void:
	set_data_list_and_move_to_index(data_list, snap_index)


func move_to_index(move_index: int) -> void:
	move_panel_to_item_index(move_index, 0.0)


func snap_to_index(snap_index: int) -> void:
	move_to_index(snap_index)


func set_data_list_only(data_list: Array[Variant], reset_pos: bool = true) -> void:
	_data_list = data_list
	_current_show_count = 0
	set_count_and_refresh(0, reset_pos)


func pop_one_item() -> void:
	if _current_show_count >= _data_list.size():
		return
	_current_show_count += 1
	set_count_and_refresh(_current_show_count, false)
	move_to_index(_current_show_count - 1)


func clear_all_item() -> void:
	var all_nodes: Array[Node] = []
	for key in _item_state_by_id.keys():
		var id_val: int = int(key)
		var node: Object = instance_from_id(id_val)
		if node is Node:
			all_nodes.append(node as Node)
	for node in all_nodes:
		var state: Dictionary = _item_state_by_id.get(node.get_instance_id(), {})
		var idx: int = int(state.get("index", -1))
		var data: Variant = _get_item_data(idx)
		if bool(state.get("shown", false)):
			grid_item_disable.emit(idx, node, data)
		grid_item_destroy.emit(idx, node, data)
	_item_state_by_id.clear()
	_data_list.clear()
	_current_show_count = 0
	recycle_all_item()
	set_count_and_refresh(0, true)


func _set_item_position(item_index: int, item: Control) -> void:
	var cross_count: int = _get_cross_count()
	var order_index: int = _item_index_to_ordered_index(item_index)
	var main_index: int = int(order_index / cross_count)
	var cross_index: int = order_index % cross_count
	var main_start: float = _get_item_start(item_index)
	if is_vert_list:
		var x_pos: float = start_pos_offset + cross_index * (cell_size.x + cell_spacing.x)
		item.position = Vector2(x_pos, main_start)
	else:
		var y_pos: float = start_pos_offset + cross_index * (cell_size.y + cell_spacing.y)
		item.position = Vector2(main_start, y_pos)


func _fit_item_cross_size(item: Control) -> void:
	if item == null:
		return
	item.custom_minimum_size = cell_size
	item.size = cell_size


func _rebuild_layout_cache() -> void:
	_item_start_cache.resize(_item_total_count)
	_item_extent_cache.resize(_item_total_count)
	if _item_total_count <= 0:
		_content_total_size = 0.0
		_update_content_size()
		return

	var cross_count: int = _get_cross_count()
	var main_extent: float = cell_size.y if is_vert_list else cell_size.x
	var main_spacing: float = cell_spacing.y if is_vert_list else cell_spacing.x
	var order_index: int = 0
	while order_index < _item_total_count:
		var item_index: int = _ordered_index_to_item_index(order_index)
		var main_index: int = int(order_index / cross_count)
		_item_start_cache[item_index] = main_index * (main_extent + main_spacing)
		_item_extent_cache[item_index] = main_extent
		order_index += 1

	var total_main_count: int = int(ceili(float(_item_total_count) / float(cross_count)))
	if total_main_count <= 0:
		_content_total_size = 0.0
	else:
		_content_total_size = float(total_main_count) * main_extent + float(maxi(0, total_main_count - 1)) * main_spacing
	_update_content_size()


func _update_content_size() -> void:
	if _content == null:
		return
	var cross_count: int = _get_cross_count()
	var cross_extent: float = cell_size.x if is_vert_list else cell_size.y
	var cross_spacing: float = cell_spacing.x if is_vert_list else cell_spacing.y
	var cross_total: float = float(cross_count) * cross_extent + float(maxi(0, cross_count - 1)) * cross_spacing
	var min_size: Vector2 = _content.custom_minimum_size
	if is_vert_list:
		min_size.x = maxf(size.x, cross_total + start_pos_offset)
		min_size.y = _content_total_size
	else:
		min_size.x = _content_total_size
		min_size.y = maxf(size.y, cross_total + start_pos_offset)
	_content.custom_minimum_size = min_size


func _on_grid_item_bound(item_index: int, item_node: Node) -> void:
	if item_node == null:
		return
	var state: Dictionary = _get_or_create_item_state(item_node)
	var data: Variant = _get_item_data(item_index)
	state["index"] = item_index
	if not bool(state.get("inited", false)):
		state["inited"] = true
		grid_item_init.emit(item_index, item_node, data)
		if item_node.has_method("on_item_init"):
			item_node.call("on_item_init", item_index, data)
	if not bool(state.get("shown", false)):
		state["shown"] = true
		grid_item_enable.emit(item_index, item_node, data)
		if item_node.has_method("on_item_enable"):
			item_node.call("on_item_enable", item_index, data)
	grid_item_update.emit(item_index, item_node, data)
	if item_node.has_method("on_item_update"):
		item_node.call("on_item_update", item_index, data)
	if item_node.has_method("bind_item_data"):
		item_node.call("bind_item_data", item_index, data)


func _on_grid_item_recycled(item_node: Node) -> void:
	if item_node == null:
		return
	var key: int = item_node.get_instance_id()
	if not _item_state_by_id.has(key):
		return
	var state: Dictionary = _item_state_by_id[key]
	if not bool(state.get("shown", false)):
		return
	state["shown"] = false
	var item_index: int = int(state.get("index", -1))
	var data: Variant = _get_item_data(item_index)
	grid_item_disable.emit(item_index, item_node, data)
	if item_node.has_method("on_item_disable"):
		item_node.call("on_item_disable", item_index, data)


func _get_or_create_item_state(item_node: Node) -> Dictionary:
	var key: int = item_node.get_instance_id()
	if not _item_state_by_id.has(key):
		_item_state_by_id[key] = {
			"inited": false,
			"shown": false,
			"index": -1
		}
	return _item_state_by_id[key]


func _get_item_data(item_index: int) -> Variant:
	if item_index < 0 or item_index >= _data_list.size():
		return null
	return _data_list[item_index]


func _get_cross_count() -> int:
	if fixed_cross_count > 0:
		return fixed_cross_count
	var cross_viewport_size: float = size.x if is_vert_list else size.y
	var cross_cell_size: float = cell_size.x if is_vert_list else cell_size.y
	var cross_spacing: float = cell_spacing.x if is_vert_list else cell_spacing.y
	var span: float = maxf(1.0, cross_cell_size + cross_spacing)
	var estimated: int = int(floor((cross_viewport_size + cross_spacing) / span))
	return maxi(1, estimated)


func _item_index_to_ordered_index(item_index: int) -> int:
	if not _is_reverse_arrange():
		return item_index
	return (_item_total_count - 1) - item_index
