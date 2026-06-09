class_name SceneRegistry
extends RefCounted

#region 配置与常量
const GAME_SCENE: StringName = &"GAME_SCENE"

const _SCENE_REGISTRY: Dictionary[StringName, Dictionary] = {
	GAME_SCENE: {
		"scene_path": "res://assets/src/game/scene/game/GameScene.tscn",
		"default_mode": &"replace"
	}
}
#endregion

#region 对外接口
static func has_scene(scene_id: StringName) -> bool:
	return _SCENE_REGISTRY.has(scene_id)


static func get_scene_config(scene_id: StringName) -> Dictionary:
	if not has_scene(scene_id):
		return {}
	return (_SCENE_REGISTRY[scene_id] as Dictionary).duplicate(true)


static func get_scene_path(scene_id: StringName) -> String:
	var config: Dictionary = get_scene_config(scene_id)
	return str(config.get("scene_path", ""))
#endregion
