---
name: ui-model-view-controller
description: 新增或改造 assets/src/ui/<module> 下 core/model、或梳理 UI 模块间数据访问时，对齐 View/Controller/Model 分工与依赖方向
owner: client-ui
status: active
last_updated: 2026-05-13
version: 1.2.0
depends_on:
  - .cursor/rules/UI_MODULE_MVC.mdc
  - .cursor/rules/UI_CONTROLLER_REGION_STYLE.mdc
  - .cursor/rules/UI_MODEL_REGION_STYLE.mdc
---

# 模块 View / Controller / Model 任务路由

## 何时使用

- **仅改** `assets/src/ui/<module>/view/*.gd` / `.tscn` 时优先使用 `ui-view-task-routing`；本技能在触及 `core` / `model` 或模块边界时启用。
- 新建或改造 UI 模块下的 `core/*Controller.gd`、`model/*Model.gd`
- 调整「谁写状态、谁持有数据缓存、View 从哪取数」
- 评估是否应合并/拆分模块（按玩法功能聚合）

## 执行前必读

0. **技能 / 规则总路由**：`.cursor/README.md`（单 hub）  
1. `.cursor/rules/UI_MODULE_MVC.mdc`（UI 模块分工与依赖方向）  
2. `.cursor/rules/UI_CONTROLLER_REGION_STYLE.mdc`（改造 `*Controller.gd` 时）  
3. `.cursor/rules/UI_MODEL_REGION_STYLE.mdc`（改造 `*Model.gd` 时）  

## 实施检查（最小清单）

- [ ] `*Controller.gd` 的 `#region` 符合 `UI_CONTROLLER_REGION_STYLE`（信号区 `信号-<用途>`、对外接口含 `生命周期` 等）
- [ ] `*Model.gd` 的 `#region` 与写入方式符合 `UI_MODEL_REGION_STYLE`（`apply` + 只读 getter、私有 `_pick_*`）
- [ ] View 仅依赖对应 `*Controller`，不在 View 中直接改写业务状态
- [ ] Controller 持有本模块 Model，对外读接口稳定；写路径集中
- [ ] Model 无 UI 引用、无玩法分支；跨模块读数优先经对方 Controller
- [ ] 模块工具方法是否放在本模块 `core/*Helper.gd`（纯函数静态方法），未把模块特定工具塞进 `BaseController`
- [ ] Helper 方法命名前缀是否统一（`normalize_ / validate_ / pick_ / build_`）
- [ ] 顶层模块划分按**功能聚合**，避免“一功能多模块”或“万能大模块”
