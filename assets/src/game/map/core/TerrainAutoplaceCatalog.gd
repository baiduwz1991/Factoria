class_name TerrainAutoplaceCatalog
extends RefCounted

var _rules: Array[TerrainAutoplaceRule] = []
var _terrain_catalog: TerrainCatalog = null


func _init(terrain_catalog: TerrainCatalog = null) -> void:
	_terrain_catalog = terrain_catalog if terrain_catalog != null else TerrainCatalog.new()
	var registry: GameDataRegistry = _get_registry()
	if registry != null and not registry.get_autoplace_defs().is_empty():
		_register_registry_rules(registry)
	else:
		_register_default_rules()


func get_rules() -> Array[TerrainAutoplaceRule]:
	return _rules.duplicate()


func _register_registry_rules(registry: GameDataRegistry) -> void:
	for raw_rule in registry.get_autoplace_defs():
		var terrain_id: StringName = StringName(raw_rule.get("terrain_id", ""))
		var terrain: TerrainDef = _terrain_catalog.get_by_id_or_null(terrain_id)
		if terrain == null:
			continue
		_register(_build_rule(
			terrain.numeric_id,
			_parse_range(raw_rule.get("height_range", [-1.0, 1.0]), Vector2(-1.0, 1.0)),
			_parse_range(raw_rule.get("moisture_range", [-1.0, 1.0]), Vector2(-1.0, 1.0)),
			_parse_range(raw_rule.get("temperature_range", [-1.0, 1.0]), Vector2(-1.0, 1.0)),
			float(raw_rule.get("base_score", 0.0)),
			float(raw_rule.get("height_weight", 1.0)),
			float(raw_rule.get("moisture_weight", 1.0)),
			float(raw_rule.get("temperature_weight", 1.0)),
			float(raw_rule.get("variation_weight", 0.0)),
			float(raw_rule.get("range_falloff", 0.25))
		))


func _register_default_rules() -> void:
	_register(_build_rule(TerrainCatalog.TERRAIN_DEEP_WATER, Vector2(-1.0, -0.60), Vector2(-1.0, 1.0), Vector2(-1.0, 1.0), 0.55, 2.1, 0.0, 0.0, 0.0, 0.18))
	_register(_build_rule(TerrainCatalog.TERRAIN_WATER, Vector2(-0.64, -0.33), Vector2(-1.0, 1.0), Vector2(-1.0, 1.0), 0.45, 1.9, 0.0, 0.0, 0.0, 0.22))
	_register(_build_rule(TerrainCatalog.TERRAIN_SAND, Vector2(-0.38, 0.16), Vector2(-1.0, 0.08), Vector2(0.05, 1.0), 0.14, 0.50, 0.70, 0.32, 0.05, 0.40))
	_register(_build_rule(TerrainCatalog.TERRAIN_DRY_DIRT, Vector2(-0.28, 0.92), Vector2(-0.75, 0.05), Vector2(-0.65, 0.96), 0.18, 0.26, 0.74, 0.10, 0.11, 0.46))
	_register(_build_rule(TerrainCatalog.TERRAIN_DRY_GRASS, Vector2(-0.24, 0.82), Vector2(-0.05, 0.50), Vector2(-0.55, 0.78), 0.23, 0.23, 0.66, 0.13, 0.10, 0.48))
	_register(_build_rule(TerrainCatalog.TERRAIN_GRASS, Vector2(-0.30, 0.78), Vector2(0.30, 1.0), Vector2(-0.80, 0.68), 0.16, 0.25, 0.82, 0.20, 0.04, 0.52))
	_register(_build_rule(TerrainCatalog.TERRAIN_RED_DESERT, Vector2(-0.12, 1.0), Vector2(-1.0, -0.30), Vector2(0.20, 1.0), 0.26, 0.22, 0.96, 0.42, 0.18, 0.50))
	_register(_build_rule(TerrainCatalog.TERRAIN_STONE_GROUND, Vector2(0.12, 1.0), Vector2(-1.0, 0.48), Vector2(-0.85, 0.96), 0.18, 0.62, 0.36, 0.08, 0.55, 0.44))
	_register(_build_rule(TerrainCatalog.TERRAIN_DIRT, Vector2(-0.34, 1.0), Vector2(-0.55, 0.58), Vector2(-1.0, 0.88), 0.13, 0.24, 0.44, 0.08, 0.04, 0.50))
	_register(_build_rule(TerrainCatalog.TERRAIN_BASE_SOIL, Vector2(-0.34, 1.0), Vector2(-1.0, 0.32), Vector2(-0.20, 1.0), 0.09, 0.16, 0.32, 0.16, 0.03, 0.55))


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


func _parse_range(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array:
		var items: Array = value as Array
		if items.size() >= 2:
			return Vector2(float(items[0]), float(items[1]))
	if value is Dictionary:
		var dictionary: Dictionary = value as Dictionary
		return Vector2(float(dictionary.get("min", fallback.x)), float(dictionary.get("max", fallback.y)))
	return fallback


func _get_registry() -> GameDataRegistry:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null or scene_tree.root == null:
		return null
	var mod_manager: Node = scene_tree.root.get_node_or_null("ModManager")
	if mod_manager == null or not mod_manager.has_method("get_registry"):
		return null
	return mod_manager.call("get_registry") as GameDataRegistry
