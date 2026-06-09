class_name LoopListViewItem
extends Control

const TypesScript: Script = preload("res://assets/src/core/ui-widgets/super-scroll-view/LoopListViewTypes.gd")

var item_index: int = -1
var item_id: int = -1
var padding: float = 0.0
var start_pos_offset: float = 0.0
var item_created_check_frame_count: int = 0
var parent_list_view: Node = null

var user_object_data: Variant = null
var user_int_data1: int = 0
var user_int_data2: int = 0
var user_string_data1: String = ""
var user_string_data2: String = ""


func _set_list_item_runtime(list_view: Node, index: int, in_padding: float, in_start_pos_offset: float) -> void:
	parent_list_view = list_view
	item_index = index
	padding = in_padding
	start_pos_offset = in_start_pos_offset


func get_item_size() -> float:
	if parent_list_view == null:
		return 0.0
	var is_vert: bool = bool(parent_list_view.get("is_vert_list"))
	return size.y if is_vert else size.x


func get_item_size_with_padding() -> float:
	return get_item_size() + padding


func get_top_y() -> float:
	if parent_list_view == null:
		return 0.0
	var arrange_type: int = int(parent_list_view.get("arrange_type"))
	if arrange_type == TypesScript.ListItemArrangeType.TOP_TO_BOTTOM:
		return position.y
	if arrange_type == TypesScript.ListItemArrangeType.BOTTOM_TO_TOP:
		return position.y + size.y
	return 0.0


func get_bottom_y() -> float:
	if parent_list_view == null:
		return 0.0
	var arrange_type: int = int(parent_list_view.get("arrange_type"))
	if arrange_type == TypesScript.ListItemArrangeType.TOP_TO_BOTTOM:
		return position.y - size.y
	if arrange_type == TypesScript.ListItemArrangeType.BOTTOM_TO_TOP:
		return position.y
	return 0.0


func get_left_x() -> float:
	if parent_list_view == null:
		return 0.0
	var arrange_type: int = int(parent_list_view.get("arrange_type"))
	if arrange_type == TypesScript.ListItemArrangeType.LEFT_TO_RIGHT:
		return position.x
	if arrange_type == TypesScript.ListItemArrangeType.RIGHT_TO_LEFT:
		return position.x - size.x
	return 0.0


func get_right_x() -> float:
	if parent_list_view == null:
		return 0.0
	var arrange_type: int = int(parent_list_view.get("arrange_type"))
	if arrange_type == TypesScript.ListItemArrangeType.LEFT_TO_RIGHT:
		return position.x + size.x
	if arrange_type == TypesScript.ListItemArrangeType.RIGHT_TO_LEFT:
		return position.x
	return 0.0

