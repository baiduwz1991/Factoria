class_name Player
extends CharacterBody2D

signal facing_changed(facing: StringName)

@export var move_speed: float = 250.0
@export var camera_initial_zoom: float = 0.6
@export var camera_min_zoom: float = 0.25
@export var camera_max_zoom: float = 1.4
@export var camera_zoom_step: float = 0.1
@export var pixel_snap_camera: bool = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_label: Label = $StateLabel
@onready var camera: Camera2D = $Camera2D

var _facing: StringName = &"down"
var _current_state: StringName = &""
var _speed_multiplier: float = 1.0


func _ready() -> void:
	add_to_group(&"player")
	camera.position_smoothing_enabled = false
	_apply_camera_zoom(camera_initial_zoom)
	_set_state(&"idle_down")


func _process(_delta: float) -> void:
	_snap_camera_to_pixel_grid()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_wheel(event as InputEventMouseButton)


func get_speed_multiplier() -> float:
	return _speed_multiplier


func get_facing() -> StringName:
	return _facing


func set_facing(value: StringName) -> void:
	if not _is_valid_facing(value):
		return
	var previous_facing: StringName = _facing
	_facing = value
	animated_sprite.flip_h = false
	if _facing != previous_facing:
		facing_changed.emit(_facing)
	_set_state(StringName("idle_%s" % _facing))


func set_speed_multiplier(value: float) -> void:
	_speed_multiplier = clampf(value, 1.0, 3.0)


func _physics_process(_delta: float) -> void:
	var direction := _get_move_direction()

	if direction != Vector2.ZERO:
		_update_facing(direction)
		velocity = direction.normalized() * move_speed * _speed_multiplier
		_set_state(StringName("run_%s" % _facing))
	else:
		velocity = Vector2.ZERO
		_set_state(StringName("idle_%s" % _facing))

	move_and_slide()


func _handle_mouse_wheel(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_apply_camera_zoom(camera.zoom.x + camera_zoom_step)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_apply_camera_zoom(camera.zoom.x - camera_zoom_step)
		get_viewport().set_input_as_handled()


func _apply_camera_zoom(zoom_value: float) -> void:
	var clamped_zoom := clampf(zoom_value, camera_min_zoom, camera_max_zoom)
	camera.zoom = Vector2.ONE * clamped_zoom
	_snap_camera_to_pixel_grid()


func _snap_camera_to_pixel_grid() -> void:
	if not pixel_snap_camera:
		return
	var zoom := maxf(camera.zoom.x, 0.01)
	if absf(zoom - roundf(zoom)) > 0.001:
		camera.global_position = global_position
		return
	camera.global_position = (global_position * zoom).round() / zoom


func _get_move_direction() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		direction.y += 1.0
	return direction


func _update_facing(direction: Vector2) -> void:
	var previous_facing: StringName = _facing
	if direction.x < 0.0 and direction.y < 0.0:
		_facing = &"up_left"
	elif direction.x > 0.0 and direction.y < 0.0:
		_facing = &"up_right"
	elif direction.x < 0.0 and direction.y > 0.0:
		_facing = &"down_left"
	elif direction.x > 0.0 and direction.y > 0.0:
		_facing = &"down_right"
	elif direction.x < 0.0:
		_facing = &"left"
	elif direction.x > 0.0:
		_facing = &"right"
	elif direction.y < 0.0:
		_facing = &"up"
	else:
		_facing = &"down"

	animated_sprite.flip_h = false
	if _facing != previous_facing:
		facing_changed.emit(_facing)


func _set_state(state: StringName) -> void:
	if _current_state == state:
		return

	_current_state = state
	animated_sprite.play(_get_animation_name(state))
	state_label.text = str(state)


func _get_animation_name(state: StringName) -> StringName:
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(state):
		return state

	var state_text: String = str(state)
	var separator_index: int = state_text.find("_")
	if separator_index < 0:
		return state

	var action: String = state_text.substr(0, separator_index)
	var facing: String = state_text.substr(separator_index + 1)
	match facing:
		"up", "up_left", "up_right":
			return StringName("%s_up" % action)
		"down", "down_left", "down_right":
			return StringName("%s_down" % action)
		"left", "right":
			return StringName("%s_right" % action)
		_:
			return state


func _is_valid_facing(value: StringName) -> bool:
	return [
		&"down",
		&"down_left",
		&"down_right",
		&"left",
		&"right",
		&"up",
		&"up_left",
		&"up_right"
	].has(value)
