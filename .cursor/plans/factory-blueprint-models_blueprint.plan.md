---
name: factory-blueprint-models
overview: 暂存 factory / blueprint 模块的早期 model 草稿。原文件位于 assets/src/game/factory/model/ 与 assets/src/game/blueprint/model/，因当前没有 controller 与调用方，按 GAME_MODULE_ARCHITECTURE 的"业务 Controller 通过本模块 model 暴露状态"约定，先从 game/ 下移除并保留为蓝图。后续真正落地时按 game/<module>/{core,model} 完整建模。
todos:
  - id: factory-controller
    content: 新增 assets/src/game/factory/core/FactoryController.gd，承载实体放置/拆除/朝向/配方设置流程，决定 SAVE_SCOPE 与存档字段
    status: pending
  - id: factory-model-restore
    content: 按当前需要重建 EntityDef / RecipeDef / ItemDef / PlacedEntityData，序列化辅助方法直接复用 SerializeUtils
    status: pending
  - id: blueprint-controller
    content: 新增 assets/src/game/blueprint/core/BlueprintController.gd，承载蓝图复制/粘贴/校验/补丁应用流程
    status: pending
  - id: blueprint-model-restore
    content: 按当前需要重建 BlueprintData / BlueprintPatchData / ValidationResult，序列化辅助方法直接复用 SerializeUtils
    status: pending
isProject: false
---

# factory / blueprint 模块草稿归档

## 背景

2026-05-15 的架构蒸馏中，`assets/src/game/factory/` 与 `assets/src/game/blueprint/` 仅有 model 目录，不存在任何 controller 与外部引用：

- `factory/model/EntityDef.gd`
- `factory/model/RecipeDef.gd`
- `factory/model/ItemDef.gd`
- `factory/model/PlacedEntityData.gd`
- `blueprint/model/BlueprintData.gd`
- `blueprint/model/BlueprintPatchData.gd`
- `blueprint/model/ValidationResult.gd`

这些 model 是早期蓝图阶段的"裸数据结构"，与 `GAME_MODULE_ARCHITECTURE.mdc` 中"业务 Controller 通过本模块 model 暴露状态"的预期不符；保留在 `game/` 下会形成"对外 API 表面虚高"的语义噪声。

## 处置

- 从 `assets/src/game/` 下整体移除两个模块。
- 字段定义记录在本文档（见下"原 model 字段速记"）。
- 待真正落地时按 `<module>/{core,model}` 完整建模，序列化辅助方法直接复用新建的 `assets/src/core/utils/SerializeUtils.gd`。

## 原 model 字段速记（供后续重建参考）

### `factory/model/EntityDef`

```
id: StringName
display_name: String
size: Vector2i = Vector2i.ONE
categories: Array[StringName]
allowed_recipes: Array[StringName]
energy_usage_kw: float
crafting_speed: float
```

### `factory/model/RecipeDef`

```
id: StringName
category: StringName
craft_time: float = 1.0
ingredients: Array[Dictionary]
results: Array[Dictionary]
```

### `factory/model/ItemDef`

```
id: StringName
display_name: String
stack_size: int = 100
tags: Array[StringName]
```

### `factory/model/PlacedEntityData`

```
entity_id: StringName
prototype_id: StringName
tile_position: Vector2i
direction: StringName = &"north"
recipe_id: StringName
settings: Dictionary
```

### `blueprint/model/BlueprintData`

```
schema_version: int = 1
blueprint_id: StringName
display_name: String
origin_tile: Vector2i
entities: Array[PlacedEntityData]
metadata: Dictionary
```

### `blueprint/model/BlueprintPatchData`

```
schema_version: int = 1
target_blueprint_id: StringName
reason: String
actions: Array[Dictionary]
```

### `blueprint/model/ValidationResult`

```
ok: bool = true
errors: Array[Dictionary]
warnings: Array[Dictionary]
```

## 重建时的 checklist

1. 按 `GAME_MODULE_ARCHITECTURE.mdc` 建立 `<module>/{core,model}`
2. controller 继承 `BaseController`，明确 `get_save_scope()`（factory/blueprint 实例属于 `SAVE_SCOPE_SLOT`）
3. model 序列化全部使用 `SerializeUtils`，不再 copy 私有 `_parse_vector2i / _parse_dictionary_array` 等
4. 在 `.cursor/README.md` 的"技能路由"补对应模块入口
