class_name StartGameController
extends BaseController

#region 配置与常量
const CONTROLLER_ID: StringName = &"start_game_controller"
#endregion

#region 对外接口 - 标识
func get_id() -> StringName:
	return CONTROLLER_ID
#endregion

#region 对外接口 - 页面流程
func request_start_game() -> void:
	UIManager.open_ui(UIRegistry.SAVE_SLOT_POP_LAYER, {}, UIManager.MODE_OVERLAY)


func request_open_settings() -> void:
	UIManager.open_ui(UIRegistry.SETTINGS_LAYER, {}, UIManager.MODE_REPLACE)


func request_open_mods() -> void:
	UIManager.open_ui(UIRegistry.MODS_LAYER, {}, UIManager.MODE_REPLACE)


func request_exit_game() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return
	scene_tree.quit()
#endregion
