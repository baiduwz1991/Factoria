class_name TerrainAutoplaceCatalog
extends RefCounted

var _rules: Array[TerrainAutoplaceRule] = []


func _init() -> void:
	_register_default_rules()


func get_rules() -> Array[TerrainAutoplaceRule]:
	return _rules.duplicate()


func _register_default_rules() -> void:
	_register(_build_rule(
		TerrainCatalog.TERRAIN_DEEP_WATER,
		Vector2(-1.0, -0.58),
		Vector2(-1.0, 1.0),
		Vector2(-1.0, 1.0),
		0.50,
		2.0,
		0.0,
		0.0,
		0.0,
		0.20
	))
	_register(_build_rule(
		TerrainCatalog.TERRAIN_WATER,
		Vector2(-0.62, -0.34),
		Vector2(-1.0, 1.0),
		Vector2(-1.0, 1.0),
		0.42,
		1.8,
		0.0,
		0.0,
		0.0,
		0.22
	))
	_register(_build_rule(
		TerrainCatalog.TERRAIN_SAND,
		Vector2(-0.36, 0.20),
		Vector2(-1.0, 0.20),
		Vector2(0.00, 1.0),
		0.10,
		0.45,
		0.75,
		0.25,
		0.08,
		0.46
	))
	_register(_build_rule(
		TerrainCatalog.TERRAIN_GRASS,
		Vector2(-0.34, 0.78),
		Vector2(0.08, 1.0),
		Vector2(-0.80, 0.72),
		0.18,
		0.25,
		0.85,
		0.20,
		0.04,
		0.52
	))
	_register(_build_rule(
		TerrainCatalog.TERRAIN_DIRT,
		Vector2(-0.34, 1.0),
		Vector2(-0.55, 0.55),
		Vector2(-1.0, 0.88),
		0.15,
		0.28,
		0.50,
		0.10,
		0.05,
		0.50
	))
	_register(_build_rule(
		TerrainCatalog.TERRAIN_BASE_SOIL,
		Vector2(-0.34, 1.0),
		Vector2(-1.0, 0.30),
		Vector2(-0.20, 1.0),
		0.12,
		0.18,
		0.35,
		0.18,
		0.05,
		0.55
	))


func _build_rule(
	terrain_numeric_id: int,
	height_range: Vector2,
	moisture_range: Vector2,
	temperature_range: Vector2,
	base_score: float,
	height_weight: float,
	moisture_weight: float,
	temperature_weight: float,
	variation_weight: float,
	range_falloff: float
) -> TerrainAutoplaceRule:
	var rule: TerrainAutoplaceRule = TerrainAutoplaceRule.new()
	rule.setup(
		terrain_numeric_id,
		height_range,
		moisture_range,
		temperature_range,
		base_score,
		height_weight,
		moisture_weight,
		temperature_weight,
		variation_weight,
		range_falloff
	)
	return rule


func _register(rule: TerrainAutoplaceRule) -> void:
	if rule == null:
		return
	_rules.append(rule)
