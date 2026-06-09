# `.cursor/roles` 索引

## 现有角色

- `engineering-code-reviewer.mdc`：代码审查与质量保障
- `engineering-rapid-prototyper.mdc`：快速原型与 MVP 验证
- `engineering-software-architect.mdc`：系统设计与架构决策
- `game-audio-engineer.mdc`：交互音频系统与性能预算
- `game-designer.mdc`：机制、循环与经济平衡设计
- `godot-gameplay-scripter.mdc`：Godot 4 脚本与信号架构
- `godot-shader-developer.mdc`：Godot 2D/3D Shader 与渲染优化
- `level-designer.mdc`：关卡流线、节奏与遭遇战设计
- `narrative-designer.mdc`：叙事系统、分支与世界观设计
- `technical-artist.mdc`：美术技术管线、VFX 与性能约束
- `testing-performance-benchmarker.mdc`：性能压测与容量规划
- `testing-reality-checker.mdc`：发布前现实检验与证据审查

## 元数据约定

- 所有角色文档 frontmatter 统一包含：
  - `name`
  - `description`
  - `color`
  - `owner`
  - `status`
  - `last_updated`
  - `version`

## 维护建议

- 新增角色时同步更新本索引。
- 若角色职责收敛/拆分，保持“一个角色一个核心职责”。
- 废弃角色使用 `status: deprecated`，并在文档首段注明替代角色。
