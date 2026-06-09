# FACTORIA `.cursor` 单 hub（权威入口）

> **本文件为 `.cursor` 下「任务路由 + 规则清单 + 目录分工」的唯一详表。**  
> `rules/README.md` 仅保留维护约定；子目录不再重复贴全表。

本目录用于沉淀项目内的 AI 协作规范与执行辅助文件。

---

## 一层蒸馏（目录分工）

| 层级 | 放什么 | 补充读 |
|------|--------|--------|
| **rules** | 短、硬、`globs` 可命中 | 本页 **§ 规则清单**；原文在 `rules/*.mdc` |
| **skills** | 任务流程、检查清单、`depends_on` | 本页 **§ 技能路由**；步骤在 `skills/<name>/SKILL.md` |
| **docs** | 产品设想、系统设计、玩法蓝图 | `docs/README.md` |
| **plans** | 阶段性蓝图与实施记录 | `plans/*.plan.md` |
| **roles** | 角色口吻与交付边界 | `roles/README.md` |

---

## 技能路由（权威表）

| 场景 | 技能目录 | 执行前依赖（规则 / 文档） |
|------|----------|---------------------------|
| 新建/改造 `assets/src/ui/**/*.gd`（含 `.tscn`、生命周期、`#region`） | `skills/ui-view-task-routing/SKILL.md` | `rules/UI_LIFECYCLE.mdc`、`rules/UI_VIEW_SCRIPT_REGION_STYLE.mdc` |
| 新建/改造 `assets/src/ui/<module>/core/*Controller.gd` 或 `assets/src/ui/<module>/model/*.gd` | `skills/ui-model-view-controller/SKILL.md` | `rules/UI_MODULE_MVC.mdc`、`rules/UI_CONTROLLER_REGION_STYLE.mdc`、`rules/UI_MODEL_REGION_STYLE.mdc` |
| 新建/改造 `assets/src/game/planet/**` 星球模块 | 暂按任务直接执行 | `rules/PLANET_MODULE_ARCHITECTURE.mdc`、`rules/GAME_MODULE_ARCHITECTURE.mdc`；若参与存档，再读 `rules/SAVE_SYSTEM_ACCESS_CONVENTION.mdc` |
| 新建/改造 `assets/src/game/map/**` 地图模块 | 暂按任务直接执行 | `rules/MAP_MODULE_ARCHITECTURE.mdc`、`rules/GAME_MODULE_ARCHITECTURE.mdc`；若参与存档，再读 `rules/SAVE_SYSTEM_ACCESS_CONVENTION.mdc` |
| 新建/改造 `assets/src/game/<module>/**` 无界面游戏业务模块 | 暂按任务直接执行 | `rules/GAME_MODULE_ARCHITECTURE.mdc`；若参与存档，再读 `rules/SAVE_SYSTEM_ACCESS_CONVENTION.mdc` |
| 新建/改造 `assets/src/core/scene-manager/**` 或 `assets/src/game/scene/**` gameplay 场景 | 暂按任务直接执行 | `rules/SCENE_MANAGER_CONVENTION.mdc`、`rules/GAME_MODULE_ARCHITECTURE.mdc` |
| 新建/改造 `assets/src/core/save-manager/**`、`assets/src/ui/save/**`、参与存档的 UI/Game Controller，或判断 slot/profile/local config 归属 | `skills/save-system-task-routing/SKILL.md` | `rules/SAVE_SYSTEM_ACCESS_CONVENTION.mdc`、`docs/save-and-local-config-architecture.md`、相关 UI/Game 模块规则 |

后续若补充 gameplay/planet/blueprint/agent 架构规范，再按 FACTORIA 实际目录补入本表。

---

## 规则清单（权威表）

| 文件 | `globs`（摘要） | 说明 |
|------|-----------------|------|
| `UI_LIFECYCLE.mdc` | `assets/src/ui/**/*.gd` | `BaseUI` 生命周期与页面切换 |
| `UI_VIEW_SCRIPT_REGION_STYLE.mdc` | `assets/src/ui/**/*.gd` | region 与节点引用 |
| `UI_MODULE_MVC.mdc` | `assets/src/ui/**/*.gd` | UI 模块 View / Controller / Model 分工 |
| `UI_CONTROLLER_REGION_STYLE.mdc` | `assets/src/ui/**/core/*Controller.gd` | Controller region 与对外接口 |
| `UI_MODEL_REGION_STYLE.mdc` | `assets/src/ui/**/model/*.gd` | Model region、写入方式与快照 |
| `PLANET_MODULE_ARCHITECTURE.mdc` | `assets/src/game/planet/**/*.{gd,tscn}` | planet/core/model 边界、`PlanetController` 与 `PlanetSceneCoordinator` 分工、存档生命周期与 map 编排约定 |
| `MAP_MODULE_ARCHITECTURE.mdc` | `assets/src/game/map/**/*.{gd,tscn}` | map/core/model/view/adapter 边界、`TerrainCatalog` / `TerrainAutoplaceCatalog` / `TerrainRenderCatalog` 三分约定与 terrain-trans 适配 |
| `GAME_MODULE_ARCHITECTURE.mdc` | `assets/src/game/**/*.{gd,tscn}` | 无界面游戏业务模块的目录边界与分层；Controller（进 `ControllerManager`）与 Coordinator（scene-bound）分工 |
| `SCENE_MANAGER_CONVENTION.mdc` | `assets/src/{core/scene-manager,game/scene}/**/*.{gd,tscn}` | SceneManager、SceneRegistry 与 gameplay 场景生命周期 |
| `SAVE_SYSTEM_ACCESS_CONVENTION.mdc` | `assets/src/{core/save-manager,ui/save,ui/**/core,game/**/core}/*.gd` | 存档访问边界与 slot/profile/local config 语义 |

---

## 当前结构（文件形态）

- `roles/*.mdc`：角色边界与交付约束  
- `rules/*.mdc`：项目级行为约束  
- `skills/<name>/SKILL.md`：按场景任务流程  
- `plans/*.plan.md`：阶段性蓝图与实施记录  
- `scripts/*.ps1`：维护与一致性检查脚本  

---

## 共享工具（非规则文件，登记在此供检索）

- `assets/src/core/utils/SerializeUtils.gd`：model / SaveData 通用序列化辅助（vector / packed array / dictionary / StringName 数组）。新增 model 时直接 `SerializeUtils.parse_*`，禁止再在 model 内复制私有 `_parse_*` 方法。
- `assets/src/core/ui-controller-manager/BaseController.gd`：业务 Controller 基类，已下沉 `_get_save_manager()`。业务 Controller 需要 SaveManager 时统一调用此方法，不再自行 `Engine.get_main_loop().root.get_node_or_null("SaveManager")`。

---

## 使用约定（新增内容放哪）

1. 长期规范 → `roles/` 或 `rules/`  
2. 任务执行流程 → `skills/`（并在本页 **§ 技能路由** 增一行）  
3. 产品设想 / 系统设计 / 玩法蓝图 → `docs/`  
4. 阶段计划 / 蓝图 → `plans/`  
5. 维护脚本 → `scripts/`  
6. 若后续需要长文说明，再新增对应目录并同步本 hub  

**新增规则后**：须同步更新本页 **§ 规则清单**；新增技能后须同步 **§ 技能路由**。

---

## 规则优先级（冲突处理）

1. 更具体 `globs` / 更靠近业务目录的规则优先  
2. 其次 `rules/` 通用项，再次 `roles/`  
3. 仍冲突：`version` / `last_updated` 更新者优先，或由 `owner` 裁决并在提交说明记录  

判定口诀：`globs 更窄 > 目录更近 > 版本更新 > owner 裁决`。

---

## 维护建议

- 规则单一职责；技能单一高频场景。  
- **路由与全表只维护本 hub**；子 README 禁止再复制整张路由表。  
- 规则 frontmatter 建议含：`description`、`globs`、`alwaysApply`、`owner`、`status`、`last_updated`、`version`。  
- 提交前可运行：`powershell -ExecutionPolicy Bypass -File .cursor/scripts/check-cursor-consistency.ps1`（检查 hub 引用路径与 `skills` 的 `depends_on`）。

---

## 其它入口（非重复索引）

- `CHANGELOG.md`：规范演进记录  
- `docs/README.md`：产品与系统设计文档入口  
- `docs/save-and-local-config-architecture.md`：slot/profile/local config 架构边界  
- `roles/README.md`：角色列表与元数据约定  
