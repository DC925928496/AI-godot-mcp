# Changelog

## [1.0.3] - 2026-06-29

### 修复

- 修复 Godot 插件启动时 `websocket_server.gd` 的 Parse error。
- 改用 Godot 4 官方兼容的 `TCPServer` + `WebSocketPeer.accept_stream()` WebSocket 服务端流程。
- 修复 Godot 4.7 对 `class_name` 参数名和 `:=` 返回类型推断的解析兼容问题。
- 新增 `EditorConnection.close()`，主动关闭连接时不再触发重连定时器，避免集成测试进程挂住。

### 验证

- 通过 Godot 4.7 `--check-only` 解析插件脚本。
- 通过临时 Godot 工程的真实 WebSocket 集成验证，`test-p0.mjs` 为 `1 pass, 0 skipped`。

---

## [1.0.0] - 2026-06-23

### 首个正式发布

AI-godot-mcp 是完全重写的 Godot MCP 服务，基于 EditorPlugin 架构。

### 功能清单

#### 项目信息
- `get_project_context` - 获取 Godot 项目上下文（版本、项目名、主场景、插件状态）
- `get_scene_tree` - 获取当前场景节点树
- `get_resource_uid` - 获取资源 UID 和类型

#### 事务管理
- `begin_ai_action` - 开始事务（支持多操作原子性）
- `end_ai_action` - 提交或回滚当前事务

#### 场景编辑
- `add_node` - 添加节点到场景树
- `set_node_property` - 设置节点属性
- `delete_node` - 删除场景节点
- `create_scene` - 创建新场景文件
- `save_current_scene` - 保存当前场景

#### 脚本与资源
- `attach_script` - 附加 GDScript 到节点
- `load_resource` - 加载资源引用

#### 场景运行
- `play_current_scene` - 运行当前场景（F6）
- `stop_running_scene` - 停止运行场景（F8）
- `get_editor_logs` - 获取编辑器日志（支持时间戳和级别过滤）

#### CLI 工具
- `ai-godot-mcp install <project-path>` - 安装插件到 Godot 项目
- `ai-godot-mcp uninstall <project-path>` - 卸载插件
- `ai-godot-mcp version` - 显示版本信息

### 架构特性

- **事务系统** - 所有写操作支持 txn_id，可原子性提交/回滚
- **WebSocket 通信** - 端口 6550，支持心跳和重连
- **安全模型** - token 认证，路径白名单，类名黑名单
- **EditorPlugin 集成** - 无需外部进程，直接调用 Godot 编辑器 API

### 破坏性变更

- **不兼容 legacy godot-mcp 0.1.1**
- **仅支持 Godot 4.6.x**（不支持 4.0-4.5 或 3.x）
- 架构从无头脚本改为 EditorPlugin

### 版本要求

- Godot: 4.6.x
- Node.js: ≥20.0.0

### 已知限制

- WebSocket 端口固定为 6550
- 事务超时 30 秒后自动回滚
- 重连最多 3 次

---

[1.0.3]: https://github.com/DC925928496/AI-godot-mcp/releases/tag/v1.0.3
[1.0.0]: https://github.com/DC925928496/AI-godot-mcp/releases/tag/v1.0.0
