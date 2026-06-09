# `.cursor/rules` 说明

**任务路由、技能选表、规则全表**：见 **`../README.md`（单 hub）** — 请勿在其它文件重复维护同一张表。

## 规则优先级（冲突时）

1. 命中范围更小（`globs` 更窄）的规则优先  
2. 与当前业务目录更接近的规则优先  
3. 若仍冲突，以较新版本（`version` / `last_updated`）为准  
4. 若仍无法判定，由对应 `owner` 裁决，并在说明中记录取舍  

## 新增规则建议

- 命名：`<DOMAIN>_<TOPIC>.mdc`（例如 `NET_REQUEST_CONVENTION.mdc`）  
- 一文件一主题；frontmatter 含 `description`、`globs`、`alwaysApply`、`owner`、`status`、`last_updated`、`version`  
- **合并入 hub**：新规则文件落地后，在 **`../README.md` § 规则清单** 增加一行  

## 现有规则文件（文件名速查）

除 hub 表格外，仓库内规则文件包括：

- `UI_LIFECYCLE.mdc`
- `UI_VIEW_SCRIPT_REGION_STYLE.mdc`
- `UI_MODULE_MVC.mdc`
- `UI_CONTROLLER_REGION_STYLE.mdc`
- `UI_MODEL_REGION_STYLE.mdc`
- `SAVE_SYSTEM_ACCESS_CONVENTION.mdc`
