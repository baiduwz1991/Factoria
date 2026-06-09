# `.cursor` 变更记录

- 2026-05-15 `assets/src/game` 架构蒸馏：
  - `GAME_MODULE_ARCHITECTURE.mdc` v1.1.0：新增 Controller / Coordinator 分工矩阵，Controller 进 `ControllerManager`、Coordinator scene-bound 不进；明确序列化辅助走 `SerializeUtils`。
  - `PLANET_MODULE_ARCHITECTURE.mdc` v1.1.0：拆分 `PlanetController`（持久化）与 `PlanetSceneCoordinator`（gameplay scene 编排）的职责，明确 `chunk_size/tile_size` 常量唯一来源是 `MapChunkGenerator.DEFAULT_*`。
  - `MAP_MODULE_ARCHITECTURE.mdc` v1.1.0：terrain catalog 三分（`TerrainCatalog` / `TerrainAutoplaceCatalog` / `TerrainRenderCatalog`）；`TerrainDef` 去除视图字段，视图字段收敛到 view 层 `TerrainRenderProfile`；`TerrainVariantResolver` 移到 `map/view/`。
  - 新增共享工具 `assets/src/core/utils/SerializeUtils.gd` 与 `BaseController._get_save_manager()`，业务 Controller 不再自行 SceneTree 解析 SaveManager。
  - `game/factory/`、`game/blueprint/`、`game/map/model/MiniMapModel.gd` 暂从 `game/` 下移除，归档到 `plans/factory-blueprint-models_blueprint.plan.md`；`game/player/` 迁到 `game/scene/player/`。
- 新增 `docs/` 设计文档入口，整理 FACTORIA 的“异星工场 + agent coding 蓝图体验”项目愿景与 agent 蓝图玩法设计。
- 按 FACTORIA 当前工程目录本地化 `.cursor` 规则与技能路由：从旧 `assets/src/modules` 路径收敛到 `assets/src/ui/<module>/{view,core,model}`、`assets/src/core/save-manager`。
- 完善存档与本地配置架构边界：slot 存世界进度，profile 存跨槽位长期进度，本地 config/cache 存系统设置。
