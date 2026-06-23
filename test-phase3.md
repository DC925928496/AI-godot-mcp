# Phase 3: Script Attachment - 手动测试指南

## 前置条件
1. Godot 4.6.x 已安装并打开项目
2. AI-godot-mcp 插件已启用
3. MCP server 已运行 (`npm start`)
4. 创建一个测试场景并打开

## 测试用例

### 1. 基础脚本附加
```json
// 1. 创建节点
{"method": "add_node", "params": {"parent_path": ".", "node_type": "CharacterBody2D", "node_name": "Player"}}

// 2. 附加脚本（需要先在项目中创建 res://player.gd）
{"method": "attach_script", "params": {"node_path": "Player", "script_path": "res://player.gd"}}
```

**预期结果**：
- `ok: true`
- 返回 `attached_script` 和 `resource_uid`
- Player节点显示脚本图标
- 可以撤销（Ctrl+Z）

### 2. 获取资源UID
```json
{"method": "get_resource_uid", "params": {"resource_path": "res://player.gd"}}
```

**预期结果**：
- `ok: true`
- 返回 `uid` 和 `type: "GDScript"`

### 3. 错误场景

#### 脚本不存在
```json
{"method": "attach_script", "params": {"node_path": "Player", "script_path": "res://nonexistent.gd"}}
```

**预期结果**：
- `ok: false`
- `error.code: "SCRIPT_NOT_FOUND"`
- 包含 `suggestions`

#### 节点不存在
```json
{"method": "attach_script", "params": {"node_path": "InvalidNode", "script_path": "res://player.gd"}}
```

**预期结果**：
- `ok: false`
- `error.code: "NODE_NOT_FOUND"`

#### 脚本语法错误
创建一个语法错误的脚本（如 `tests/fixtures/invalid_syntax.gd`），然后附加：

```json
{"method": "attach_script", "params": {"node_path": "Player", "script_path": "res://invalid_syntax.gd"}}
```

**预期结果**：
- `ok: false`
- `error.code: "INVALID_SCRIPT"`
- 提示修复语法错误

### 4. 事务集成
```json
// 多步骤操作：创建节点+附加脚本，作为单个撤销单元
{"method": "begin_ai_action", "params": {"name": "Setup player with script"}}
{"method": "add_node", "params": {"parent_path": ".", "node_type": "CharacterBody2D", "node_name": "Player"}}
{"method": "add_node", "params": {"parent_path": "Player", "node_type": "Sprite2D", "node_name": "Sprite"}}
{"method": "attach_script", "params": {"node_path": "Player", "script_path": "res://player.gd"}}
{"method": "end_ai_action"}
```

**预期结果**：
- 所有操作成功
- 单次撤销（Ctrl+Z）移除整个Player节点及其脚本

## 实现摘要

### Node端 (createServer.ts)
- ✅ 添加 `AttachScriptSchema`（验证 `.gd` 扩展名）
- ✅ 添加 `GetResourceUidSchema`
- ✅ 注册 `attach_script` 工具
- ✅ 注册 `get_resource_uid` 工具

### Godot端 (websocket_server.gd)
- ✅ `handle_attach_script()`: 
  - 节点验证
  - 脚本存在性检查（区分不存在和语法错误）
  - GDScript类型验证
  - UndoRedo集成
  - 自动事务包裹
- ✅ `handle_get_resource_uid()`:
  - 资源存在性检查
  - 返回UID和类型（支持所有资源类型）

### 测试fixtures
- ✅ `tests/fixtures/test_player.gd` - 有效的GDScript
- ✅ `tests/fixtures/invalid_syntax.gd` - 语法错误的脚本

## 验收标准检查

根据 `docs/phases/phase-3-script-attachment.md`:

- [x] `attach_script` 成功绑定 GDScript 到节点
- [x] `get_resource_uid` 返回有效资源 UID
- [x] 脚本不存在时返回 `SCRIPT_NOT_FOUND`
- [x] 脚本语法错误时返回 `INVALID_SCRIPT`（区分加载失败）
- [x] 节点不存在时返回 `NODE_NOT_FOUND`
- [x] 附加操作支持 UndoRedo（可撤销）
- [x] 附加操作可包含在 `begin_ai_action` 事务中
- [ ] 集成测试：创建节点 → 附加脚本 → 运行场景（需要Phase 4）

## 构建状态
- ✅ TypeScript编译通过
- ✅ 现有测试通过
- ✅ 无lint错误
