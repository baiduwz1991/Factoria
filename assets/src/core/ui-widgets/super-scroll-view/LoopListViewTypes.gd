class_name LoopListViewTypes
extends RefCounted


enum ListItemArrangeType {
	TOP_TO_BOTTOM = 0,
	BOTTOM_TO_TOP = 1,
	LEFT_TO_RIGHT = 2,
	RIGHT_TO_LEFT = 3
}


class LoopListViewInitParam:
	extends RefCounted

	var distance_for_recycle0: float = 300.0
	var distance_for_new0: float = 200.0
	var distance_for_recycle1: float = 300.0
	var distance_for_new1: float = 200.0
	var smooth_dump_rate: float = 0.3
	var snap_finish_threshold: float = 0.01
	var snap_vec_threshold: float = 145.0
	var item_default_with_padding_size: float = 100.0


class ItemPosStruct:
	extends RefCounted

	var item_index: int = 0
	var item_offset: float = 0.0

