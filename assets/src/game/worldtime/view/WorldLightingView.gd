class_name WorldLightingView
extends CanvasModulate

const COLOR_DEEP_NIGHT: Color = Color(0.10, 0.13, 0.24, 1.0)
const COLOR_DAWN: Color = Color(0.55, 0.62, 0.72, 1.0)
const COLOR_NOON: Color = Color(1.00, 1.00, 1.00, 1.0)
const COLOR_DUSK: Color = Color(1.00, 0.76, 0.52, 1.0)
const COLOR_NIGHT: Color = Color(0.18, 0.22, 0.36, 1.0)

var _world_time_controller: WorldTimeController = null


func _ready() -> void:
	_world_time_controller = _get_world_time_controller()
	_apply_lighting()
	set_process(true)


func _process(delta: float) -> void:
	if _world_time_controller == null:
		_world_time_controller = _get_world_time_controller()
	if _world_time_controller == null:
		return

	_world_time_controller.advance(delta)
	_apply_lighting()


func _apply_lighting() -> void:
	var hour: float = WorldTimeModel.DEFAULT_TIME_OF_DAY
	if _world_time_controller != null:
		hour = _world_time_controller.get_time_of_day()
	color = _sample_lighting_color(hour)


func _sample_lighting_color(hour: float) -> Color:
	var wrapped_hour: float = fposmod(hour, WorldTimeModel.HOURS_PER_DAY)
	if wrapped_hour < 6.0:
		return COLOR_DEEP_NIGHT.lerp(COLOR_DAWN, wrapped_hour / 6.0)
	if wrapped_hour < 12.0:
		return COLOR_DAWN.lerp(COLOR_NOON, (wrapped_hour - 6.0) / 6.0)
	if wrapped_hour < 18.0:
		return COLOR_NOON.lerp(COLOR_DUSK, (wrapped_hour - 12.0) / 6.0)
	if wrapped_hour < 21.0:
		return COLOR_DUSK.lerp(COLOR_NIGHT, (wrapped_hour - 18.0) / 3.0)
	return COLOR_NIGHT.lerp(COLOR_DEEP_NIGHT, (wrapped_hour - 21.0) / 3.0)


func _get_world_time_controller() -> WorldTimeController:
	var existing: WorldTimeController = ControllerManager.get_controller(WorldTimeController.CONTROLLER_ID) as WorldTimeController
	if existing != null:
		return existing
	return ControllerManager.get_or_register_controller(
		WorldTimeController.CONTROLLER_ID,
		func() -> BaseController:
			return WorldTimeController.new()
	) as WorldTimeController
