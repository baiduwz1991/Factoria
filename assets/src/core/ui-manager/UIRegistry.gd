class_name UIRegistry
extends RefCounted

const START_GAME_LAYER: StringName = &"START_GAME_LAYER"
const SETTINGS_LAYER: StringName = &"SETTINGS_LAYER"
const SAVE_SLOT_POP_LAYER: StringName = &"SAVE_SLOT_POP_LAYER"
const SAVE_LOADING_POP_LAYER: StringName = &"SAVE_LOADING_POP_LAYER"
const LOADING_LAYER: StringName = &"LOADING_LAYER"
const SLOT_INFO_POP_LAYER: StringName = &"SLOT_INFO_POP_LAYER"
const ROLE_CREATE_LAYER: StringName = &"ROLE_CREATE_LAYER"
const PLANET_HUD_OVERLAY_LAYER: StringName = &"PLANET_HUD_OVERLAY_LAYER"
const PLANET_SYSTEM_MENU_POP_LAYER: StringName = &"PLANET_SYSTEM_MENU_POP_LAYER"
const DEBUG_POP_LAYER: StringName = &"DEBUG_POP_LAYER"
const DEBUG_STATS_OVERLAY: StringName = &"DEBUG_STATS_OVERLAY"

const _UI_REGISTRY: Dictionary[StringName, Dictionary] = {
	START_GAME_LAYER: {
		"scene_path": "res://assets/src/ui/startgame/view/StartGameLayer.tscn",
		"default_mode": &"replace",
		"layer": &"main",
		"allow_multi_instance": false,
		"block_input": true
	},
	SETTINGS_LAYER: {
		"scene_path": "res://assets/src/ui/settings/view/SettingsLayer.tscn",
		"default_mode": &"replace",
		"layer": &"main",
		"allow_multi_instance": false,
		"block_input": true
	},
	SAVE_SLOT_POP_LAYER: {
		"scene_path": "res://assets/src/ui/save/view/SaveSlotPopLayer.tscn",
		"default_mode": &"overlay",
		"layer": &"overlay",
		"allow_multi_instance": false,
		"block_input": true
	},
	SAVE_LOADING_POP_LAYER: {
		"scene_path": "res://assets/src/ui/save/view/SaveLoadingPopLayer.tscn",
		"default_mode": &"overlay",
		"layer": &"overlay",
		"allow_multi_instance": false,
		"block_input": true
	},
	LOADING_LAYER: {
		"scene_path": "res://assets/src/ui/loading/view/LoadingLayer.tscn",
		"default_mode": &"overlay",
		"layer": &"overlay",
		"allow_multi_instance": false,
		"block_input": true
	},
	SLOT_INFO_POP_LAYER: {
		"scene_path": "res://assets/src/ui/save/view/SlotInfoPopLayer.tscn",
		"default_mode": &"overlay",
		"layer": &"overlay",
		"allow_multi_instance": false,
		"block_input": true
	},
	ROLE_CREATE_LAYER: {
		"scene_path": "res://assets/src/ui/rolecreate/view/RoleCreateLayer.tscn",
		"default_mode": &"replace",
		"layer": &"main",
		"allow_multi_instance": false,
		"block_input": true
	},
	PLANET_HUD_OVERLAY_LAYER: {
		"scene_path": "res://assets/src/ui/planethud/view/PlanetHudOverlayLayer.tscn",
		"default_mode": &"overlay",
		"layer": &"overlay",
		"allow_multi_instance": false,
		"block_input": false
	},
	PLANET_SYSTEM_MENU_POP_LAYER: {
		"scene_path": "res://assets/src/ui/planethud/view/PlanetSystemMenuPopLayer.tscn",
		"default_mode": &"overlay",
		"layer": &"overlay",
		"allow_multi_instance": false,
		"block_input": true
	},
	DEBUG_POP_LAYER: {
		"scene_path": "res://assets/src/ui/debug/view/DebugPopLayer.tscn",
		"default_mode": &"overlay",
		"layer": &"overlay",
		"allow_multi_instance": false,
		"block_input": true
	},
	DEBUG_STATS_OVERLAY: {
		"scene_path": "res://assets/src/ui/debug/view/DebugStatsOverlay.tscn",
		"default_mode": &"overlay",
		"layer": &"overlay",
		"allow_multi_instance": false,
		"block_input": false
	}
}


static func has_ui(ui_id: StringName) -> bool:
	return _UI_REGISTRY.has(ui_id)


static func get_ui_config(ui_id: StringName) -> Dictionary:
	if not has_ui(ui_id):
		return {}
	return (_UI_REGISTRY[ui_id] as Dictionary).duplicate(true)


static func get_scene_path(ui_id: StringName) -> String:
	var config: Dictionary = get_ui_config(ui_id)
	return str(config.get("scene_path", ""))
