---
name: save-system-task-routing
description: 在新增或改造 Godot 存档流程时，统一遵循 SaveManager/SaveController 分层、slot/profile/local config 域边界与备份加载语义。适用于改动 assets/src/core/save-manager、assets/src/ui/save、以及参与存档的 UI/Game Controller 场景。
owner: client-ui
status: active
last_updated: 2026-05-13
version: 1.2.0
depends_on:
  - .cursor/rules/SAVE_SYSTEM_ACCESS_CONVENTION.mdc
  - .cursor/rules/UI_MODULE_MVC.mdc
  - .cursor/rules/UI_CONTROLLER_REGION_STYLE.mdc
  - .cursor/rules/UI_MODEL_REGION_STYLE.mdc
  - .cursor/rules/UI_VIEW_SCRIPT_REGION_STYLE.mdc
  - .cursor/rules/UI_LIFECYCLE.mdc
  - .cursor/rules/GAME_MODULE_ARCHITECTURE.mdc
---

# 存档系统任务路由

## 何时使用

- 改动 `assets/src/core/save-manager/*.gd`（编排、读写、备份、回退）。
- 改动 `assets/src/ui/save/**`（存档入口、槽位 UI、状态同步）。
- 改动参与存档的 UI 或 Game 业务 Controller 的导入/导出接口时。
- 判断某类数据应进入 `slot`、`profile` 还是本地 `config/cache` 时。
- 处理“读档失败、备份切换、槽位元数据显示异常”等问题时。

## 执行前必读

0. `.cursor/README.md`（任务路由总表）
1. `.cursor/rules/SAVE_SYSTEM_ACCESS_CONVENTION.mdc`
2. 若改 `view/*.gd`：再读 `UI_LIFECYCLE.mdc` 与 `UI_VIEW_SCRIPT_REGION_STYLE.mdc`
3. 若改 `assets/src/ui/**/core/*Controller.gd` / `model/*Model.gd`：再读 `UI_MODULE_MVC`、`UI_CONTROLLER_REGION_STYLE`、`UI_MODEL_REGION_STYLE`
4. 若改 `assets/src/game/**`：再读 `GAME_MODULE_ARCHITECTURE`

## 实施流程（最小闭环）

1. 明确改动范围：`slot`、`profile` 还是本地 `config/cache`，是否涉及备份来源加载。
2. 先改 `SaveManager/SaveRepository` 的能力，再改 `SaveController` 对外入口。
3. 最后改 View 交互，仅做触发与展示，不下沉业务流程到 UI。
4. 对新增入口补失败回调与错误码透传，避免静默失败。
5. 检查不存在备份时的 UI 行为（隐藏项，不显示假可用按钮）。

## 实施检查（最小清单）

- [ ] 是否保持 `SaveManager -> SaveController -> View` 的调用方向。
- [ ] 是否保持 `SaveRepository` 仅做文件层，不承载业务决策。
- [ ] 新增导入/导出是否声明正确 `save_scope` 且不跨域写入。
- [ ] 系统设置、音量、语言、按键等本机偏好是否保持在本地 config/cache，不进入 `SaveManager`。
- [ ] 成就、累计统计、全局教程状态等跨槽位进度是否使用 `SAVE_SCOPE_PROFILE`。
- [ ] 备份来源语义是否与 `main/backup/backup_2/backup_3` 一致。
- [ ] `save/view` 是否只依赖 `SaveController`，不直接拿其它模块 Controller。
- [ ] View 是否只调用 Controller，不直接触达磁盘和阶段通知。
- [ ] 失败路径是否有明确 `error_code` 并可回传给 UI。

## 常见反例（禁止）

- 在业务模块自行拼接 `user://saves/slot_xx` 路径。
- 在 View 里直接做 JSON decode 或存档阶段编排。
- 在 `assets/src/ui/save/view` 里直接持有其它业务 Controller。
- 把系统设置写入 slot 或 profile 存档。
- 把“读取某一代备份”写成“读取主档失败才回退”的单一路径，导致无法指定加载目标。
