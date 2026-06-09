class_name PlayerFlashlight
extends PointLight2D

@export var cone_angle_degrees: float = 84.0
@export var effective_distance: float = 430.0
@export var edge_softness_degrees: float = 12.0
@export var night_energy: float = 1.25
@export var texture_size: int = 512
@export var origin_offset: Vector2 = Vector2(0.0, -18.0)
@export var front_offset: float = 34.0

var _world_time_controller: WorldTimeController = null


func _ready() -> void:
	texture = _build_cone_texture()
	texture_scale = effective_distance * 2.0 / float(maxi(texture_size, 1))
	color = Color(1.0, 0.92, 0.72, 1.0)
	energy = 0.0
	enabled = false
	shadow_enabled = false
	_bind_player_facing()
	_world_time_controller = _get_world_time_controller()
	set_process(true)


func _process(_delta: float) -> void:
	if _world_time_controller == null:
		_world_time_controller = _get_world_time_controller()

	var night_factor: float = 0.0
	if _world_time_controller != null:
		night_factor = _world_time_controller.get_night_factor()

	energy = night_energy * night_factor
	enabled = night_factor > 0.01
	visible = enabled


func _bind_player_facing() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var facing_callable := Callable(self, "_on_player_facing_changed")
	if parent_node.has_signal("facing_changed") and not parent_node.is_connected("facing_changed", facing_callable):
		parent_node.connect("facing_changed", facing_callable)
	if parent_node.has_method("get_facing"):
		_apply_facing(StringName(parent_node.call("get_facing")))


func _on_player_facing_changed(facing: StringName) -> void:
	_apply_facing(facing)


func _apply_facing(facing: StringName) -> void:
	var facing_vector: Vector2 = _get_facing_vector(facing)
	rotation = facing_vector.angle()
	position = origin_offset + facing_vector * front_offset


func _get_facing_vector(facing: StringName) -> Vector2:
	match facing:
		&"right":
			return Vector2.RIGHT
		&"down_right":
			return Vector2(1.0, 1.0).normalized()
		&"down":
			return Vector2.DOWN
		&"down_left":
			return Vector2(-1.0, 1.0).normalized()
		&"left":
			return Vector2.LEFT
		&"up_left":
			return Vector2(-1.0, -1.0).normalized()
		&"up":
			return Vector2.UP
		&"up_right":
			return Vector2(1.0, -1.0).normalized()
		_:
			return Vector2.DOWN


func _build_cone_texture() -> Texture2D:
	var size: int = maxi(texture_size, 8)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var center: Vector2 = Vector2(size, size) * 0.5
	var radius: float = float(size) * 0.5
	var half_angle: float = deg_to_rad(cone_angle_degrees) * 0.5
	var edge_softness: float = maxf(deg_to_rad(edge_softness_degrees), 0.001)

	for y in size:
		for x in size:
			var offset: Vector2 = Vector2(float(x), float(y)) - center
			var distance: float = offset.length()
			if distance > radius or distance <= 0.001:
				continue

			var angle: float = absf(wrapf(atan2(offset.y, offset.x), -PI, PI))
			if angle > half_angle:
				continue

			var radial_alpha: float = pow(1.0 - distance / radius, 1.35)
			var edge_weight: float = clampf((half_angle - angle) / edge_softness, 0.0, 1.0)
			var edge_alpha: float = _smoothstep(0.0, 1.0, edge_weight)
			var alpha: float = clampf(radial_alpha * edge_alpha, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 0.92, 0.70, alpha))

	return ImageTexture.create_from_image(image)


func _get_world_time_controller() -> WorldTimeController:
	var existing: WorldTimeController = ControllerManager.get_controller(WorldTimeController.CONTROLLER_ID) as WorldTimeController
	if existing != null:
		return existing
	return ControllerManager.get_or_register_controller(
		WorldTimeController.CONTROLLER_ID,
		func() -> BaseController:
			return WorldTimeController.new()
	) as WorldTimeController


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	var weight: float = clampf((value - edge0) / maxf(edge1 - edge0, 0.001), 0.0, 1.0)
	return weight * weight * (3.0 - 2.0 * weight)
