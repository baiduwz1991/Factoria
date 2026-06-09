extends Control

#region 生命周期
func _ready() -> void:
	_apply_display_settings()
	var start_ui: BaseUI = UIManager.open_ui(
		UIRegistry.START_GAME_LAYER,
		{},
		&"replace"
	)
	if start_ui == null:
		push_error("UIBootstrap 启动失败：无法打开 START_GAME_LAYER。")
		return

	# 启动器只负责点火，启动成功后立即自销毁，避免常驻场景树。
	call_deferred("queue_free")
#endregion


#region 内部逻辑
func _apply_display_settings() -> void:
	var settings_controller: SettingsController = ControllerManager.get_or_register_controller(
		SettingsController.CONTROLLER_ID,
		func() -> BaseController:
			return SettingsController.new()
	) as SettingsController
	if settings_controller == null:
		return
	settings_controller.load_and_apply_on_boot()
#endregion
