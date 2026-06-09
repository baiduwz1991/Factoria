class_name TerrainAutoplaceRule
extends RefCounted

var terrain_numeric_id: int = 0
var height_range: Vector2 = Vector2(-1.0, 1.0)
var moisture_range: Vector2 = Vector2(-1.0, 1.0)
var temperature_range: Vector2 = Vector2(-1.0, 1.0)
var base_score: float = 0.0
var height_weight: float = 1.0
var moisture_weight: float = 1.0
var temperature_weight: float = 1.0
var variation_weight: float = 0.0
var range_falloff: float = 0.25


func setup(
	next_terrain_numeric_id: int,
	next_height_range: Vector2,
	next_moisture_range: Vector2,
	next_temperature_range: Vector2,
	next_base_score: float,
	next_height_weight: float,
	next_moisture_weight: float,
	next_temperature_weight: float,
	next_variation_weight: float,
	next_range_falloff: float = 0.25
) -> void:
	terrain_numeric_id = next_terrain_numeric_id
	height_range = _sanitize_range(next_height_range)
	moisture_range = _sanitize_range(next_moisture_range)
	temperature_range = _sanitize_range(next_temperature_range)
	base_score = next_base_score
	height_weight = next_height_weight
	moisture_weight = next_moisture_weight
	temperature_weight = next_temperature_weight
	variation_weight = next_variation_weight
	range_falloff = maxf(next_range_falloff, 0.001)


func score(height_value: float, moisture_value: float, temperature_value: float, variation_value: float) -> float:
	return (
		base_score
		+ _range_score(height_value, height_range) * height_weight
		+ _range_score(moisture_value, moisture_range) * moisture_weight
		+ _range_score(temperature_value, temperature_range) * temperature_weight
		+ variation_value * variation_weight
	)


func _range_score(value: float, value_range: Vector2) -> float:
	if value >= value_range.x and value <= value_range.y:
		return 1.0

	var distance: float = value_range.x - value if value < value_range.x else value - value_range.y
	return clampf(1.0 - distance / range_falloff * 2.0, -1.0, 1.0)


func _sanitize_range(value_range: Vector2) -> Vector2:
	if value_range.x <= value_range.y:
		return value_range
	return Vector2(value_range.y, value_range.x)
