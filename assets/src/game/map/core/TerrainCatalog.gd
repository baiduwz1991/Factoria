class_name TerrainCatalog
extends RefCounted

const TERRAIN_BASE_SOIL: int = 1
const TERRAIN_DIRT: int = 2
const TERRAIN_GRASS: int = 3
const TERRAIN_SAND: int = 4
const TERRAIN_WATER: int = 5
const TERRAIN_DEEP_WATER: int = 6
const TERRAIN_DRY_GRASS: int = 7
const TERRAIN_DRY_DIRT: int = 8
const TERRAIN_RED_DESERT: int = 9
const TERRAIN_STONE_GROUND: int = 10

const ID_BASE_SOIL: StringName = &"core.base_soil"
const ID_DIRT: StringName = &"core.dirt"
const ID_GRASS: StringName = &"core.grass"
const ID_SAND: StringName = &"core.sand"
const ID_WATER: StringName = &"core.water"
const ID_DEEP_WATER: StringName = &"core.deep_water"
const ID_DRY_GRASS: StringName = &"core.dry_grass"
const ID_DRY_DIRT: StringName = &"core.dry_dirt"
const ID_RED_DESERT: StringName = &"core.red_desert"
const ID_STONE_GROUND: StringName = &"core.stone_ground"

const MODDED_RUNTIME_ID_START: int = 1000

var _by_numeric_id: Dictionary = {}
var _by_id: Dictionary = {}
var _all: Array[TerrainDef] = []
var _palette: Dictionary = {}
var _visual_spec: Dictionary = {}
var _diagnostics: Array[Dictionary] = []
var _next_runtime_id: int = MODDED_RUNTIME_ID_START


func _init(saved_palette: Dictionary = {}) -> void:
	var registry: GameDataRegistry = _get_registry()
	if registry != null and not registry.get_terrain_defs().is_empty():
		_register_registry_terrains(registry, saved_palette)
		_build_visual_spec(registry)
	else:
		_register_default_terrains()
		_build_default_visual_spec()


func get_all() -> Array[TerrainDef]:
	return _all.duplicate()


func get_by_numeric_id(numeric_id: int) -> TerrainDef:
	return get_by_runtime_id(numeric_id)


func get_by_runtime_id(runtime_id: int) -> TerrainDef:
	var terrain: TerrainDef = _by_numeric_id.get(runtime_id, null) as TerrainDef
	if terrain != null:
		return terrain
	return _by_numeric_id.get(get_default_terrain_id(), null) as TerrainDef


func get_by_id(id: StringName) -> TerrainDef:
	var terrain: TerrainDef = _by_id.get(id, null) as TerrainDef
	if terrain != null:
		return terrain
	return get_by_runtime_id(get_default_terrain_id())


func get_by_id_or_null(id: StringName) -> TerrainDef:
	return _by_id.get(id, null) as TerrainDef


func has_terrain_id(id: StringName) -> bool:
	return _by_id.has(id)


func get_runtime_id(id: StringName) -> int:
	var terrain: TerrainDef = get_by_id(id)
	if terrain == null:
		return get_default_terrain_id()
	return terrain.numeric_id


func get_default_terrain_id() -> int:
	var terrain: TerrainDef = _by_id.get(ID_BASE_SOIL, null) as TerrainDef
	if terrain != null:
		return terrain.numeric_id
	return TERRAIN_BASE_SOIL


func get_base_soil_id() -> int:
	return get_default_terrain_id()


func get_map_color(runtime_id: int) -> int:
	var terrain: TerrainDef = get_by_runtime_id(runtime_id)
	if terrain == null:
		return 0xffffff
	return terrain.map_color


func is_walkable(runtime_id: int) -> bool:
	var terrain: TerrainDef = get_by_runtime_id(runtime_id)
	return terrain != null and terrain.walkable


func is_buildable(runtime_id: int) -> bool:
	var terrain: TerrainDef = get_by_runtime_id(runtime_id)
	return terrain != null and terrain.buildable


func is_water(runtime_id: int) -> bool:
	var terrain: TerrainDef = get_by_runtime_id(runtime_id)
	return terrain != null and terrain.is_water


func build_palette(_saved_palette: Dictionary = {}) -> Dictionary:
	return _palette.duplicate(true)


func get_palette() -> Dictionary:
	return _palette.duplicate(true)


func get_visual_spec() -> Dictionary:
	return _visual_spec.duplicate(true)


func get_diagnostics() -> Array[Dictionary]:
	return _diagnostics.duplicate(true)


func has_palette_errors() -> bool:
	for diagnostic in _diagnostics:
		if str(diagnostic.get("code", "")) == "terrain_palette_missing":
			return true
	return false


func _register_registry_terrains(registry: GameDataRegistry, saved_palette: Dictionary) -> void:
	var terrain_defs: Array[Dictionary] = registry.get_terrain_defs()
	var raw_by_id: Dictionary = {}
	for raw_def in terrain_defs:
		var terrain_id: StringName = StringName(raw_def.get("id", ""))
		if terrain_id == StringName():
			continue
		raw_by_id[terrain_id] = raw_def

	var used_runtime_ids: Dictionary = {}
	for raw_runtime_id in saved_palette.keys():
		var runtime_id: int = int(raw_runtime_id)
		var terrain_id: StringName = StringName(saved_palette.get(raw_runtime_id, ""))
		if runtime_id <= 0 or terrain_id == StringName():
			continue
		if not raw_by_id.has(terrain_id):
			_push_diagnostic("terrain_palette_missing", {
				"runtime_id": runtime_id,
				"terrain_id": String(terrain_id)
			})
			continue
		var terrain: TerrainDef = _build_terrain_from_dict(raw_by_id[terrain_id] as Dictionary, runtime_id)
		_register(terrain)
		used_runtime_ids[runtime_id] = true

	for raw_def in terrain_defs:
		var stable_id: StringName = StringName(raw_def.get("id", ""))
		if stable_id == StringName() or _by_id.has(stable_id):
			continue
		var preferred_runtime_id: int = int(raw_def.get("preferred_runtime_id", 0))
		var runtime_id: int = _pick_runtime_id(preferred_runtime_id, used_runtime_ids)
		var terrain: TerrainDef = _build_terrain_from_dict(raw_def, runtime_id)
		_register(terrain)
		used_runtime_ids[runtime_id] = true


func _build_terrain_from_dict(raw_def: Dictionary, runtime_id: int) -> TerrainDef:
	var terrain: TerrainDef = TerrainDef.new()
	terrain.numeric_id = runtime_id
	terrain.id = StringName(raw_def.get("id", ""))
	terrain.display_name = str(raw_def.get("display_name", String(terrain.id)))
	terrain.map_color = _parse_color(raw_def.get("map_color", 0xffffff))
	terrain.walkable = bool(raw_def.get("walkable", true))
	terrain.buildable = bool(raw_def.get("buildable", true))
	terrain.is_water = bool(raw_def.get("is_water", false))
	terrain.source_mod_id = StringName(raw_def.get("source_mod_id", "core"))
	terrain.preferred_runtime_id = int(raw_def.get("preferred_runtime_id", 0))
	terrain.aliases = _parse_aliases(raw_def.get("aliases", []), terrain.id)
	return terrain


func _pick_runtime_id(preferred_runtime_id: int, used_runtime_ids: Dictionary) -> int:
	if preferred_runtime_id > 0 and not used_runtime_ids.has(preferred_runtime_id):
		return preferred_runtime_id
	while used_runtime_ids.has(_next_runtime_id):
		_next_runtime_id += 1
	var result: int = _next_runtime_id
	_next_runtime_id += 1
	return result


func _register(terrain: TerrainDef) -> void:
	if terrain == null:
		return
	_by_numeric_id[terrain.numeric_id] = terrain
	_by_id[terrain.id] = terrain
	for alias in terrain.aliases:
		if alias != StringName():
			_by_id[alias] = terrain
	_all.append(terrain)
	_palette[str(terrain.numeric_id)] = String(terrain.id)


func _build_visual_spec(registry: GameDataRegistry) -> void:
	var entries: Array[Dictionary] = []
	var foam_texture_path: String = ""
	for terrain in _all:
		var visual_def: Dictionary = registry.get_terrain_visual_def(terrain.id)
		var textures: Dictionary = visual_def.get("textures", {}) as Dictionary
		if textures == null:
			textures = {}
		if foam_texture_path == "":
			foam_texture_path = str(visual_def.get("foam_texture", ""))
		entries.append({
			"runtime_id": terrain.numeric_id,
			"stable_id": String(terrain.id),
			"visual_index": terrain.numeric_id,
			"priority": int(visual_def.get("priority", _get_default_priority(terrain))),
			"is_water": bool(visual_def.get("is_water", terrain.is_water)),
			"textures": textures.duplicate(true)
		})
	_visual_spec = {
		"default_runtime_id": get_default_terrain_id(),
		"foam_texture_path": foam_texture_path,
		"terrains": entries
	}


func _build_default_visual_spec() -> void:
	var entries: Array[Dictionary] = []
	for terrain in _all:
		entries.append({
			"runtime_id": terrain.numeric_id,
			"stable_id": String(terrain.id),
			"visual_index": terrain.numeric_id,
			"priority": _get_default_priority(terrain),
			"is_water": terrain.is_water,
			"textures": {}
		})
	_visual_spec = {
		"default_runtime_id": get_default_terrain_id(),
		"foam_texture_path": "",
		"terrains": entries
	}


func _register_default_terrains() -> void:
	_register(_build_default_terrain(TERRAIN_BASE_SOIL, ID_BASE_SOIL, "Base Soil", 0x603025, true, true, false, [&"base_soil"]))
	_register(_build_default_terrain(TERRAIN_DIRT, ID_DIRT, "Dirt", 0x825836, true, true, false, [&"dirt"]))
	_register(_build_default_terrain(TERRAIN_GRASS, ID_GRASS, "Grass", 0x699737, true, true, false, [&"grass"]))
	_register(_build_default_terrain(TERRAIN_SAND, ID_SAND, "Sand", 0xcab064, true, true, false, [&"sand"]))
	_register(_build_default_terrain(TERRAIN_WATER, ID_WATER, "Water", 0x3193ae, false, false, true, [&"water"]))
	_register(_build_default_terrain(TERRAIN_DEEP_WATER, ID_DEEP_WATER, "Deep Water", 0x185584, false, false, true, [&"deep_water"]))
	_register(_build_default_terrain(TERRAIN_DRY_GRASS, ID_DRY_GRASS, "Dry Grass", 0x6f7439, true, true, false, [&"dry_grass"]))
	_register(_build_default_terrain(TERRAIN_DRY_DIRT, ID_DRY_DIRT, "Dry Dirt", 0x7b4f32, true, true, false, [&"dry_dirt", &"dry_soil"]))
	_register(_build_default_terrain(TERRAIN_RED_DESERT, ID_RED_DESERT, "Red Desert", 0x9c552f, true, true, false, [&"red_desert", &"rust_desert"]))
	_register(_build_default_terrain(TERRAIN_STONE_GROUND, ID_STONE_GROUND, "Stone Ground", 0x62605a, true, true, false, [&"stone_ground", &"gravel"]))


func _build_default_terrain(
	runtime_id: int,
	id: StringName,
	display_name: String,
	map_color: int,
	walkable: bool,
	buildable: bool,
	is_water: bool,
	aliases: Array[StringName]
) -> TerrainDef:
	var terrain: TerrainDef = TerrainDef.new()
	terrain.numeric_id = runtime_id
	terrain.id = id
	terrain.display_name = display_name
	terrain.map_color = map_color
	terrain.walkable = walkable
	terrain.buildable = buildable
	terrain.is_water = is_water
	terrain.aliases = aliases
	terrain.preferred_runtime_id = runtime_id
	return terrain


func _parse_aliases(value: Variant, stable_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for raw_alias in (value as Array):
			var alias: StringName = StringName(raw_alias)
			if alias != StringName() and not result.has(alias):
				result.append(alias)
	var stable_text: String = String(stable_id)
	var local_name: String = stable_text.get_slice(".", stable_text.get_slice_count(".") - 1)
	var local_alias: StringName = StringName(local_name)
	if local_alias != StringName() and not result.has(local_alias):
		result.append(local_alias)
	return result


func _parse_color(value: Variant) -> int:
	if value is int:
		return int(value)
	var text: String = str(value).strip_edges()
	if text.begins_with("0x"):
		return _parse_hex_int(text.substr(2))
	if text.is_valid_int():
		return int(text)
	return 0xffffff


func _parse_hex_int(text: String) -> int:
	var result: int = 0
	for index in range(text.length()):
		var character: String = text.substr(index, 1).to_lower()
		var code: int = character.unicode_at(0)
		var digit: int = -1
		if code >= 48 and code <= 57:
			digit = code - 48
		elif code >= 97 and code <= 102:
			digit = 10 + code - 97
		if digit < 0:
			return 0xffffff
		result = result * 16 + digit
	return result


func _get_default_priority(terrain: TerrainDef) -> int:
	if terrain == null:
		return 0
	if terrain.is_water:
		return 50 if terrain.id == ID_DEEP_WATER else 40
	if terrain.id == ID_STONE_GROUND:
		return 35
	if terrain.id == ID_RED_DESERT:
		return 32
	if terrain.id == ID_SAND:
		return 30
	if terrain.id == ID_GRASS:
		return 20
	if terrain.id == ID_DRY_GRASS:
		return 18
	if terrain.id == ID_DRY_DIRT:
		return 12
	if terrain.id == ID_DIRT:
		return 10
	return 0


func _get_registry() -> GameDataRegistry:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null or scene_tree.root == null:
		return null
	var mod_manager: Node = scene_tree.root.get_node_or_null("ModManager")
	if mod_manager == null or not mod_manager.has_method("get_registry"):
		return null
	return mod_manager.call("get_registry") as GameDataRegistry


func _push_diagnostic(code: String, extra: Dictionary = {}) -> void:
	var diagnostic: Dictionary = {"code": code}
	for key in extra.keys():
		diagnostic[key] = extra[key]
	_diagnostics.append(diagnostic)
