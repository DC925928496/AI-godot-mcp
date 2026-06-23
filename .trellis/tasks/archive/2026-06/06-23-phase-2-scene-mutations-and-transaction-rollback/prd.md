# Phase 2: Scene Mutations and Transaction Rollback

## 目标

实现安全的场景节点写操作，基于 Godot 原生 UndoRedo 系统的原子事务。

## 背景

Phase 1 已实现：
- WebSocket 服务器（Node 侧 + Godot Plugin 侧）
- 3 个只读工具：`get_project_context`, `get_scene_tree`, `get_editor_logs`
- 基础的请求/响应架构

Phase 2 在此基础上添加写操作能力，核心是**事务原子性**和**可撤销性**。

## 功能需求

### 1. 六个写操作工具

#### 1.1 `create_scene`
- **参数**：
  - `scene_name`: string
  - `root_node_type`: string (可选，默认 "Node2D")
- **返回**：`{ scene_path: string }`
- **验证**：场景名称合法性

#### 1.2 `add_node`
- **参数**：
  - `parent_path`: string (NodePath 格式)
  - `node_type`: string (如 "Sprite2D")
  - `node_name`: string
- **返回**：`{ node_path: string }`
- **验证**：父节点存在、节点类型有效

#### 1.3 `set_node_property`
- **参数**：
  - `node_path`: string
  - `property`: string (如 "position", "scale")
  - `value`: any (类型匹配 Godot 属性)
- **返回**：`{ old_value: any, new_value: any }`
- **验证**：节点存在、属性可写

#### 1.4 `load_resource`
- **参数**：
  - `resource_path`: string (res:// 格式)
  - `resource_type`: string (可选)
- **返回**：`{ resource_uid: string, resource_type: string }`
- **验证**：资源文件存在、类型匹配

#### 1.5 `save_current_scene`
- **参数**：无
- **返回**：`{ saved_path: string }`
- **验证**：有活动场景

#### 1.6 `delete_node`
- **参数**：
  - `node_path`: string
- **返回**：`{ deleted_node_path: string }`
- **验证**：节点存在
- **权限**：Yellow（记录日志）

### 2. 事务 API

#### 2.1 `begin_ai_action`
- **参数**：`name`: string (操作描述)
- **行为**：
  - 开启事务，后续写操作绑定到此事务
  - 支持嵌套（内层合并到外层）

#### 2.2 `end_ai_action`
- **参数**：无
- **行为**：
  - 提交事务为单个 UndoRedo Action
  - 用户可通过 Ctrl+Z 撤销整个事务

### 3. 原子性保证

**成功场景**：
```
begin_ai_action("Setup player")
add_node(".", "CharacterBody2D", "Player")
set_node_property("Player", "position", [100, 100])
end_ai_action()
→ 整个操作作为单个撤销单元
```

**失败场景**：
```
begin_ai_action("Setup invalid")
add_node(".", "Node2D", "Test")  ✓
set_node_property("Test", "invalid_prop", 123)  ✗
→ 整个事务自动回滚
→ 返回错误：{ ok: false, error: { code: "TRANSACTION_FAILED", failed_step: 2 } }
```

**单工具调用**：
```
add_node(".", "Node2D", "NewNode")
→ 自动包裹为单步事务
```

### 4. Read-before-write 原则

**规则**：写操作前调用 `get_scene_tree` 验证状态

**目的**：
- 防止基于过期状态操作
- 减少因状态不一致导致的失败

**强制级别**：
- Node 侧：工具文档建议
- Plugin 侧：重验证（不依赖 AI 遵守）

## 技术实现

### 核心原则：延迟执行模型

**关键概念**：所有写操作延迟到 `commit_action()` 时执行

```gdscript
# ❌ 错误：手动执行操作
undo_redo.add_do_method(...)
parent.add_child(new_node)  # 立即执行 - 错误！

# ✅ 正确：只注册，等 commit 时执行
undo_redo.add_do_method(parent, "add_child", new_node)
undo_redo.add_undo_method(parent, "remove_child", new_node)
undo_redo.commit_action()  # 这时才真正执行
```

**这意味着**：
- `add_node` 返回成功时，节点还未被添加
- 只有 `end_ai_action` 调用 commit 后，场景才改变
- 验证必须在 `add_do_method` 前完成
- 事务失败时不调用 commit，操作自动丢弃（无需手动回滚）

### Node 侧 (TypeScript)

1. **工具注册**：在 `createServer.ts` 中添加 6 个写操作工具 + 2 个事务 API
2. **参数验证**：使用 Zod schema 验证参数
3. **事务状态管理**：维护当前事务 ID，关联事务内所有请求
4. **超时管理**：Node 侧实现 30 秒超时，超时后自动发送 rollback 请求

### Plugin 侧 (GDScript)

1. **EditorUndoRedoManager 集成**：
   ```gdscript
   var undo_redo = EditorInterface.get_editor_undo_redo()
   
   # 开始事务
   undo_redo.create_action("AI: " + action_name)
   
   # 注册操作（不执行）
   undo_redo.add_do_method(target, "method_name", args...)
   undo_redo.add_undo_method(target, "undo_method", args...)
   
   # 提交时才执行
   undo_redo.commit_action()
   ```

2. **事务管理**：
   - `websocket_server.gd` 维护当前事务状态（ID、步骤计数）
   - 事务失败：清理状态，不调用 commit（操作自动丢弃）
   - 无需 `clear_history()`，未提交的 action 不会进入历史

3. **验证逻辑**（在注册操作前）：
   - 节点/父节点存在性
   - 节点类型有效性（ClassDB.class_exists）
   - 属性可写性
   - 资源文件存在性

4. **步骤计数**：
   - 每次工具调用递增 step_count
   - 验证失败时返回当前 step 作为 failed_step

## 验收标准

- [ ] 6 个写操作工具实现并通过单元测试
- [ ] 事务 API 实现
- [ ] 多步操作成功提交为单个 UndoRedo Action
- [ ] 失败事务完整回滚，返回 `failed_step`
- [ ] 单工具调用自动形成单步事务
- [ ] 未关闭事务在会话终止时自动回滚
- [ ] 集成测试：复杂多步场景构建 + 中途失败回滚
- [ ] 手动测试：编辑器内 Ctrl+Z 撤销 AI 事务

## 实现步骤

1. **Plugin 侧基础**：事务管理器 + UndoRedo 封装
2. **Node 侧工具**：6 个写操作工具 + 2 个事务 API
3. **测试**：单元测试 + 集成测试
4. **文档**：工具使用文档

## 非目标

- 不实现脚本附加（Phase 3）
- 不实现场景执行（Phase 4）
- 不实现复杂的冲突解决（由 read-before-write 避免）

## 依赖

- Phase 1：WebSocket 连接基础、只读工具
