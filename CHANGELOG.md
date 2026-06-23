# Changelog

## [1.0.0] - 2026-06-23

### 首个正式发布

AI-godot-mcp 是完全重写的 Godot MCP 服务，基于 EditorPlugin 架构。

### 功能清单

#### Phase 1: 基础工具
- `godot_get_property` - 获取节点属性
- `godot_set_property` - 设置节点属性
- `godot_call_method` - 调用节点方法
- `godot_list_nodes` - 列出场景树节点

#### Phase 2: 场景变更
- `godot_mutate_scene` - 支持事务的场景修改（创建/删除/移动节点）
- `godot_rollback_scene` - 回滚场景到快照

#### Phase 3: 脚本附加
- `godot_attach_script` - 动态附加 GDScript 到节点

#### Phase 4: 场景执行
- `godot_execute_scene` - 在编辑器中执行场景
- 自动收集 print/push_error/push_warning 日志

#### Phase 5: 打包与发布
- CLI 工具：`install` / `uninstall` / `version`
- Godot 4.6.x 版本验证
- npm 自动部署插件

### 破坏性变更

- **不兼容 legacy godot-mcp 0.1.1**
- **仅支持 Godot 4.6.x**（不支持 4.0-4.5 或 3.x）
- 架构从无头脚本改为 EditorPlugin

### 版本要求

- Godot: 4.6.x
- Node.js: ≥18.0.0

### 已知限制

- WebSocket 端口固定为 6550
- 场景执行不支持自定义超时
- 回滚仅保留最近一次快照

---

[1.0.0]: https://github.com/DC925928496/AI-godot-mcp/releases/tag/v1.0.0
