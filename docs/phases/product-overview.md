# AI-godot-mcp 产品总览

## 产品定位

**AI-godot-mcp** 是为 Godot 游戏开发者设计的生产级 MCP 服务，让 AI 代理能够安全、可控、可观测、可回滚地与 Godot 编辑器协作。

### vs Legacy godot-mcp

| 维度 | Legacy godot-mcp | AI-godot-mcp |
|------|------------------|--------------|
| 架构 | 无状态冷启动脚本 | 常驻编辑器插件 + WebSocket 服务 |
| 响应速度 | 2-5秒（每次冷启 Godot） | <1秒（编辑器持久连接） |
| 稳定性 | 高失败率（依赖 stdout 解析） | 结构化 JSON 通信 |
| 回滚能力 | 无 | Godot 原生 UndoRedo 事务 |
| 支持版本 | Godot 3.x/4.x | **仅 Godot 4.6.x**（破坏性产品线） |
| 权限模型 | 无分级 | Green/Yellow/Red 三级权限 |

**产品线定位**：
- `AI-godot-mcp` 是独立的新代码库（`E:/code/AI-godot-mcp`），是规范产品线。
- Legacy `godot-mcp`（`E:/code/godot-mcp`）作为参考实现、安全约束来源、历史 bug 证据库。
- **不承诺向后兼容 0.1.1 版本的工具接口**。

## 完整架构

### WebSocket 通信层

```
AI Client (Claude/Cursor/...)
    ↓ stdio MCP protocol
Node MCP Server (src/index.ts)
    ↓ WebSocket client (port 6550)
Godot EditorPlugin (addons/ai_godot_mcp/)
    ↓ Godot Editor API
Scene Tree / UndoRedo / Resources
```

**通信细节**：
- **协议**：WebSocket（Node 端为客户端，Plugin 端为服务器）
- **默认端口**：6550（单项目单实例模式）
- **响应格式**：统一信封
  - 成功：`{ ok: true, data: ... }`
  - 失败：`{ ok: false, error: { code, message, suggestions? } }`

**连接管理**：
- **状态机**：`DISCONNECTED` → `CONNECTING` → `CONNECTED` ⇄ `RECONNECTING`
- **心跳**：每 10 秒 ping，5 秒无 pong 视为断连
- **重连策略**：最多 3 次，指数退避（1s, 3s, 5s），失败后进入 `DISCONNECTED`
- **请求队列**：连接中/重连中排队，10 秒超时返回 `EDITOR_CONNECTION_TIMEOUT`

**错误恢复建议**（所有错误响应必须包含）：
- 确认 Godot 4.6.x 编辑器运行中
- 确认插件已启用
- 确认插件端口与 MCP 服务器配置一致

### Node 侧职责
- MCP 协议集成（stdio 传输）
- 参数验证（严格 JSON Schema）
- 权限控制（Green/Yellow/Red 分级）
- WebSocket 客户端连接管理
- 标准化响应信封生成

### Godot Plugin 侧职责
- WebSocket 服务器（端口 6550）
- 编辑器 API 交互
- 场景树读写（Phase 2+）
- UndoRedo 事务管理（Phase 2+）
- 场景执行与日志捕获（Phase 4）
- 可选 Dock 面板显示 AI 操作历史（Phase 4）

## 安全模型

### 权限级别

#### Green（Phase 1-4）
只读工具和带完整验证的安全写操作：
- **Phase 1**：`get_project_context`, `get_scene_tree`, `get_editor_logs`
- **Phase 2**：`create_scene`, `add_node`, `set_node_property`, `load_resource`, `save_current_scene`
- **Phase 3**：`attach_script`, `get_resource_uid`
- **Phase 4**：`play_current_scene`, `stop_running_scene`

#### Yellow（Phase 2+）
破坏性操作，需存在性验证 + UndoRedo + 操作日志：
- `delete_node`

#### Red（非 MVP 范围）
高风险操作，默认禁用，需在插件设置显式解锁：
- 任意代码执行
- 任意 `.cfg` 修改
- 覆盖现有 `.tscn` 文件

### 验证规则

**Node 侧保护**：
- 工具注册层强制参数验证（严格 JSON Schema）
- **路径输入**：继续使用 legacy 的 `validatePath` 规则
- **类名输入**：继续使用 legacy 的 `validateClassName` 规则
- **WebSocket 连接**：要求本地 token 或等效本地认证（防止未授权本地进程访问）

**Plugin 侧保护**：
- 所有写操作遵循"先读后写"原则
- 插件必须重验证目标节点、父节点、资源路径存在性（不能仅依赖 AI 遵守规则）
- 禁止 `execute_script`、任意文件写入、任意配置重写能力
- MCP 服务不在编辑器内生成任意源文件内容；脚本创建/修改留在通用编码工作流

### UndoRedo 原子操作模型（Phase 2+）

**设计原则**：
- 插件必须使用 Godot 原生 `EditorUndoRedoManager` 处理所有 AI 操作回滚
- 所有写操作必须注册为 UndoRedo Actions
- 事务包裹多步操作为原子单元

**事务 API**：
- `begin_ai_action(name)`：开启事务，命名操作（如 "Add player with health component"）
- `end_ai_action()`：提交事务
- 单个工具调用无显式事务时，自动形成单步事务

**失败处理**：
- 事务步骤失败触发整个事务回滚
- 返回失败步骤和原因
- 未关闭事务在失败/会话终止时必须显式结束或回滚

**Read-before-write 原则**：
所有写操作前必须先调用 `get_scene_tree` 验证目标状态。

## Phase 1-5 完整路线图

### Phase 1：连接基础与只读工具 ✅（已完成 2026-06-23）
**目标**：建立 WebSocket 通信，实现只读场景检查。

**工具**：
- `get_project_context`（项目上下文、Godot 版本、连接状态）
- `get_scene_tree`（场景树，支持深度限制和类型过滤）
- `get_editor_logs`（编辑器输出面板日志）

**验收标准**：
- WebSocket 连接建立（Node 客户端 ↔ Plugin 服务器）
- 三个工具响应时间 <1 秒
- 统一响应信封格式
- 连接状态管理（基础连接/断连处理）
- `npm run build / lint / test` 通过

### Phase 2：场景变更与事务回滚
**目标**：安全的场景节点写操作，基于 UndoRedo 的原子事务。

**工具**：
- `create_scene`：创建新场景
- `add_node`：添加节点到场景树
- `set_node_property`：修改节点属性
- `load_resource`：加载资源引用
- `save_current_scene`：保存当前场景
- `delete_node`：删除节点（Yellow 权限）

**事务模型**：
- `begin_ai_action(name)` / `end_ai_action()`
- 单工具调用自动形成单步事务
- 失败步骤触发整个事务回滚，返回失败原因

**Read-before-write**：所有写操作前强制调用 `get_scene_tree`。

**验收标准**：
- 多步操作事务成功提交
- 失败事务完整回滚
- `delete_node` 验证节点存在性
- 详见 `docs/phases/phase-2-scene-mutations.md`

### Phase 3：脚本附加
**目标**：将现有 GDScript 资源绑定到节点。

**工具**：
- `attach_script`：附加脚本到目标节点（MVP 仅支持 GDScript）
- `get_resource_uid`：资源引用验证

**验证**：
- 分离验证：类名、资源路径、节点路径
- 脚本文件创建/修改留在通用编码流程
- MCP 仅验证、附加、运行和观测编辑器结果

**验收标准**：
- `attach_script` 成功绑定 GDScript
- 资源路径/UID 验证有效
- 详见 `docs/phases/phase-3-script-attachment.md`

### Phase 4：场景执行与调试
**目标**：运行场景并捕获日志，支持多步工作流回滚。

**工具**：
- `play_current_scene`：运行当前场景
- `stop_running_scene`：停止运行场景
- 增强版 `get_editor_logs`：捕获运行时输出

**可选功能**：
- Dock 面板显示最近 AI 操作历史

**验收标准**：
- 完整游戏开发主工作流：检查场景 → 修改节点 → 附加脚本 → 运行场景 → 检查日志
- 详见 `docs/phases/phase-4-scene-execution.md`

### Phase 5：打包与发布
**目标**：npm CLI 与独立包名发布。

**CLI 命令**：
- `install`：验证 Godot 4.6.x，部署插件到 `addons/`，协助启用插件
- `uninstall`：移除插件
- `version`：显示版本信息

**发布**：
- 独立包名（非 `@coding-solo/godot-mcp`）
- 备份发布：GitHub Releases 手动下载
- AssetLib 不在 MVP 范围

**验收标准**：
- CLI `install` 验证 Godot 4.6.x
- 插件自动部署到目标项目
- README 包含破坏性变更通知和迁移指南
- 详见 `docs/phases/phase-5-packaging.md`

## 技术决策（ADR）

### ADR-1：为何选择 EditorPlugin 而非无头脚本
**背景**：Legacy 项目使用无状态冷启动脚本，每次操作启动 Godot 进程。

**决策**：围绕编辑器内 `EditorPlugin` + Node MCP stdio 服务器构建产品。

**理由**：
- 编辑器是场景状态和撤销历史的真实来源
- 持久连接消除冷启动延迟
- 原生 UndoRedo 支持安全回滚
- 结构化通信替代脆弱的 stdout 解析

**代价**：
- 需要用户在编辑器内启用插件
- 延迟可见的写自动化（Phase 1 仅只读）
- 但获得更安全的验证、可观测性、版本检查和回滚基础

### ADR-2：为何仅支持 Godot 4.6.x
**背景**：Legacy 项目支持多版本，导致兼容性负担。

**决策**：仅支持 Godot 4.6.x，视为破坏性产品线。

**理由**：
- 聚焦现代 Godot API
- 避免多版本兼容性碎片化
- 清晰的产品边界

**代价**：
- 不支持 Godot 3.x 和 4.0-4.5 用户
- 需在文档中明确标注破坏性变更

### ADR-3：WebSocket vs HTTP
**背景**：需要编辑器与 Node 服务器之间的双向通信。

**决策**：使用 WebSocket（Plugin 为服务器，Node 为客户端）。

**理由**：
- 支持双向实时通信（未来可推送编辑器事件）
- 低延迟持久连接
- 适合本地进程间通信

**代价**：
- 比 HTTP REST 略复杂
- 需要连接状态管理和重连逻辑

## 安全历史（不可回退）

以下约束从 legacy 项目继承，**必须保持**：

1. **路径验证**：`validatePath` 约束（防止路径遍历）
2. **类名验证**：`validateClassName` 约束（防止任意类实例化）
3. **进程执行**：安全执行，无 shell 插值
4. **协议通道保护**：无 stdout 污染 JSON-RPC/MCP 协议

## 文档索引

- **Phase 详细文档**：
  - `docs/phases/phase-2-scene-mutations.md`
  - `docs/phases/phase-3-script-attachment.md`
  - `docs/phases/phase-4-scene-execution.md`
  - `docs/phases/phase-5-packaging.md`
- **架构文档**：`docs/ARCHITECTURE.md`
- **项目范围**：`docs/PROJECT_SCOPE.md`
- **提取指南**：`docs/EXTRACTION.md`

## 当前状态

- **完成阶段**：Phase 1 ✅（2026-06-23）
- **GitHub 仓库**：https://github.com/DC925928496/AI-godot-mcp.git
- **最新提交**：d4ca46b
- **下一步**：Phase 2 场景变更与事务回滚
