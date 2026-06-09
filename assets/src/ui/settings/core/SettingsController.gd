class_name SettingsController
extends BaseController

#region 配置与常量
const CONTROLLER_ID: StringName = &"settings_controller"
const DISPLAY_CONFIG_PATH: String = "user://display_settings.cfg"

const WINDOW_MODE_WINDOWED: int = 0
const WINDOW_MODE_FULLSCREEN: int = 1
const DEFAULT_WINDOW_MODE: int = WINDOW_MODE_FULLSCREEN

const WINDOW_MODE_LABELS: Array[String] = [
	"窗口",
	"全屏"
]

const RESOLUTION_OPTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]
#endregion

#region 信号-面向view的状态与流程
signal display_settings_changed(snapshot: Dictionary)
#endregion

#region 状态
var _model: SettingsModel = SettingsModel.new()
#endregion

#region 对外接口 - 标识
func get_id() -> StringName:
	return CONTROLLER_ID


func get_save_scope() -> StringName:
	return SAVE_SCOPE_NONE
#endregion

#region 对外接口 - 生命周期
func on_game_start() -> void:
	load_and_apply_on_boot()
#endregion

#region 对外接口 - 显示设置
func load_and_apply_on_boot() -> void:
	var loaded_snapshot: Dictionary = _load_snapshot_from_disk()
	_model.apply_runtime_snapshot(SettingsHelper.normalize_display_snapshot(
		loaded_snapshot,
		DEFAULT_WINDOW_MODE,
		_pick_best_resolution_index(),
		WINDOW_MODE_LABELS.size(),
		RESOLUTION_OPTIONS.size()
	))
	_emit_runtime_state()


func get_window_mode_labels() -> Array[String]:
	return WINDOW_MODE_LABELS.duplicate()


func get_resolution_labels() -> Array[String]:
	return SettingsHelper.build_resolution_labels(RESOLUTION_OPTIONS)


func get_display_snapshot() -> Dictionary:
	return _model.get_runtime_snapshot().duplicate(true)


func apply_and_save_display_settings(mode_index: int, resolution_index: int) -> bool:
	var snapshot: Dictionary = SettingsHelper.normalize_display_snapshot(
		{
			"mode_index": mode_index,
			"resolution_index": resolution_index
		},
		DEFAULT_WINDOW_MODE,
		_pick_best_resolution_index(),
		WINDOW_MODE_LABELS.size(),
		RESOLUTION_OPTIONS.size()
	)
	_model.apply_runtime_snapshot(snapshot)
	return _apply_and_emit_runtime_state(true)
#endregion

#region 内部实现
func _emit_runtime_state() -> void:
	var snapshot: Dictionary = _model.get_runtime_snapshot()
	_apply_snapshot_to_display(snapshot)
	display_settings_changed.emit(snapshot)


func _apply_and_emit_runtime_state(save_to_disk: bool) -> bool:
	var snapshot: Dictionary = _model.get_runtime_snapshot()
	_apply_snapshot_to_display(snapshot)
	var save_ok: bool = true
	if save_to_disk:
		save_ok = _save_snapshot_to_disk(snapshot)
	display_settings_changed.emit(snapshot)
	return save_ok


func _apply_snapshot_to_display(snapshot: Dictionary) -> void:
	var mode_index: int = int(snapshot.get("mode_index", DEFAULT_WINDOW_MODE))
	var resolution_index: int = int(snapshot.get("resolution_index", _pick_best_resolution_index()))
	var target_size: Vector2i = SettingsHelper.pick_resolution(RESOLUTION_OPTIONS, resolution_index)
	var window: Window = _get_main_window()
	if _is_embedded_window(window):
		_apply_embedded_resolution(target_size, window)
		return

	if mode_index == WINDOW_MODE_FULLSCREEN:
		_apply_fullscreen_resolution(target_size, window)
		return

	_apply_windowed_resolution(target_size, window)


func _apply_windowed_resolution(target_size: Vector2i, window: Window) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if window != null:
		window.size = target_size
		window.position = _pick_centered_window_position(target_size)


func _apply_fullscreen_resolution(target_size: Vector2i, window: Window) -> void:
	if window != null:
		window.size = target_size
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func _apply_embedded_resolution(target_size: Vector2i, window: Window) -> void:
	if window == null:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	window.size = target_size


func _load_snapshot_from_disk() -> Dictionary:
	var config: ConfigFile = ConfigFile.new()
	var load_result: int = config.load(DISPLAY_CONFIG_PATH)
	if load_result != OK:
		return {}

	return {
		"mode_index": int(config.get_value("display", "mode_index", DEFAULT_WINDOW_MODE)),
		"resolution_index": int(config.get_value("display", "resolution_index", _pick_best_resolution_index()))
	}


func _save_snapshot_to_disk(snapshot: Dictionary) -> bool:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("display", "mode_index", int(snapshot.get("mode_index", DEFAULT_WINDOW_MODE)))
	config.set_value("display", "resolution_index", int(snapshot.get("resolution_index", _pick_best_resolution_index())))
	return config.save(DISPLAY_CONFIG_PATH) == OK


func _get_main_window() -> Window:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		return null
	return scene_tree.root as Window


func _is_embedded_window(window: Window) -> bool:
	if window == null:
		return false
	return bool(window.get("gui_embed_subwindows"))


func _pick_best_resolution_index() -> int:
	var screen_size: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var best_index: int = 0
	var best_area: int = 0
	for index in range(RESOLUTION_OPTIONS.size()):
		var option: Vector2i = RESOLUTION_OPTIONS[index]
		var fits_screen: bool = option.x <= screen_size.x and option.y <= screen_size.y
		var area: int = option.x * option.y
		if fits_screen and area > best_area:
			best_index = index
			best_area = area
	if best_area > 0:
		return best_index

	var smallest_delta: int = 2147483647
	for index in range(RESOLUTION_OPTIONS.size()):
		var option: Vector2i = RESOLUTION_OPTIONS[index]
		var delta: int = abs((option.x * option.y) - (screen_size.x * screen_size.y))
		if delta < smallest_delta:
			best_index = index
			smallest_delta = delta
	return best_index


func _pick_centered_window_position(target_size: Vector2i) -> Vector2i:
	var screen_id: int = DisplayServer.window_get_current_screen()
	var screen_position: Vector2i = DisplayServer.screen_get_position(screen_id)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	return screen_position + ((screen_size - target_size) / 2)
#endregion
