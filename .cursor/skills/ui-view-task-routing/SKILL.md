---
name: ui-view-task-routing
description: 在新增或改造 assets/src/ui UI 脚本时执行统一流程，并路由到 UI 生命周期与 region 规范。适用于 BaseUI 子类、tab/panel、节点引用与生命周期调整场景。
owner: client-ui
status: active
last_updated: 2026-05-13
version: 1.4.0
depends_on:
  - .cursor/rules/UI_LIFECYCLE.mdc
  - .cursor/rules/UI_VIEW_SCRIPT_REGION_STYLE.mdc
---

# UI 视图任务路由

## 触发条件

当任务涉及以下任一内容时使用本技能：
- 新建 `assets/src/ui/**/*.gd` 或对应 `.tscn`
- 重构现有视图脚本结构（`#region`、节点引用、生命周期）
- 调整 `BaseUI` 子类的 `on_ui_*` 行为

## 执行步骤

0. **技能 / 规则总路由**：`.cursor/README.md`（单 hub）。  
1. 先读取并遵循以下规则：
   - `.cursor/rules/UI_LIFECYCLE.mdc`
   - `.cursor/rules/UI_VIEW_SCRIPT_REGION_STYLE.mdc`
2. 扫描目标脚本，确认是否满足以下约束：
   - region 顺序统一
   - 固定节点使用 `NodePath + @onready get_node(...)`
   - 生命周期函数按约定顺序组织
3. 若新增脚本，使用“最小模板”起步；若改造旧脚本，采用增量治理（只整理触达文件）。
4. 变更完成后，在结果中明确说明：
   - 本次遵循了哪些规则
   - 哪些旧代码暂未治理（若有）

## 最小模板（新增 View 起步）

```gdscript
class_name ExamplePanel
extends BaseUI

#region 配置与常量
@export var title: String = ""
#endregion

#region 状态
var _state: int = 0
#endregion

#region 节点引用
@export var button_path: NodePath
@onready var button: Button = get_node(button_path) as Button
#endregion

#region 生命周期
func on_ui_create(_params: Dictionary) -> void:
	button.pressed.connect(_on_button_pressed)
#endregion

#region 交互与显示
func _on_button_pressed() -> void:
	_state += 1
#endregion
```

## 增量治理策略（旧脚本改造）

- 只整理本次触达文件，不做无关全量重构。
- 优先治理顺序：
  1. 生命周期顺序与放置位置（`#region 生命周期`）
  2. 节点引用方式（`NodePath + @onready get_node(...)`）
  3. `region` 结构顺序与命名一致性

## 验证清单（执行后自检）

- 场景替换：启动后打开 `StartGameLayer`，再切换到其它主页面，观察旧页面进入隐藏状态并压入主栈。
- 页面恢复：调用 `close_ui()` 后，当前主页面关闭且自动恢复上一页并输出恢复日志。
- 覆盖层：调用 `UIManager.open_overlay()` 打开覆盖层，关闭后下层页面恢复显示。
- attach 切换：同一 `parent_ui_id + slot_id` 连续切换 A/B 页面，确认 A 被销毁后再创建 B。
- 父页关闭：关闭主页面时，关联 attach 页面执行 `hide -> close -> destroy` 且不残留。

## 输出要求

- 说明必须包含修改文件列表与变更目的。
- 不引入“业务流程”到 View 层。
