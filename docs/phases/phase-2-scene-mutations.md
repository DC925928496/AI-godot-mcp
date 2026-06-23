# Phase 2：场景变更与事务回滚

## 目标

实现安全的场景节点写操作，基于 Godot 原生 UndoRedo 系统的原子事务。

## 前置依赖

- **依赖 Phase 1**：WebSocket 连接基础、只读工具（`get_scene_tree` 用于 read-before-write）

## 工具清单

### `create_scene`
创建新场景文件。

**参数**：
- `scene_name` (string)：场景名称
- `root_node_type` (string, 可选)：根节点类型，默认 `Node2D`

**返回**：
- `scene_path` (string)：创建的场景路径

### `add_node`
向场景树添加节点。

**参数**：
- `parent_path` (string)：父节点路径（NodePath 格式）
- `node_type` (string)：节点类型（如 `Sprite2D`, `CharacterBody2D`）
- `node_name` (string)：节点名称

**返回**：
- `node_path` (string)：新节点的完整路径

**验证**：
- 父节点必须存在（插件侧重验证）
- 节点类型必须在 Godot 类注册表中有效

### `set_node_property`
修改节点属性。

**参数**：
- `node_path` (string)：目标节点路径
- `property` (string)：属性名（如 `position`, `scale`, `modulate`）
- `value` (any)：属性值（类型匹配 Godot 属性类型）

**返回**：
- `old_value` (any)：修改前的值
- `new_value` (any)：修改后的值

**验证**：
- 节点必须存在
- 属性必须存在且可写

### `load_resource`
加载资源引用（纹理、材质、PackedScene 等）。

**参数**：
- `resource_path` (string)：资源路径（`res://` 格式）
- `resource_type` (string, 可选)：预期资源类型

**返回**：
- `resource_uid` (string)：资源 UID
- `resource_type` (string)：实际资源类型

**验证**：
- 资源文件必须存在
- 资源类型必须匹配（如指定）

### `save_current_scene`
保存当前编辑的场景。

**参数**：无

**返回**：
- `saved_path` (string)：保存的场景路径

**验证**：
- 当前必须有活动场景

### `delete_node` (Yellow 权限)
删除场景节点。

**参数**：
- `node_path` (string)：目标节点路径

**返回**：
- `deleted_node_path` (string)：已删除节点路径

**验证**：
- 节点必须存在（插件侧强制验证）
- 操作记录到日志

## UndoRedo 事务模型

### 事务 API

#### `begin_ai_action(name: string)`
开启 AI 操作事务。

**参数**：
- `name` (string)：操作描述（如 "Add player with health component"）

**行为**：
- 后续所有写操作绑定到此事务
- 事务嵌套：内层事务合并到外层

#### `end_ai_action()`
提交当前事务。

**行为**：
- 所有操作作为单个 UndoRedo Action 提交
- 用户可在编辑器中通过 Ctrl+Z 撤销整个事务

### 原子性保证

**成功场景**：
```
begin_ai_action("Setup player character")
add_node(".", "CharacterBody2D", "Player")
add_node("Player", "Sprite2D", "Sprite")
set_node_property("Player/Sprite", "texture", "res://player.png")
end_ai_action()
→ 整个操作作为单个撤销单元提交
```

**失败场景**：
```
begin_ai_action("Setup invalid character")
add_node(".", "CharacterBody2D", "Player")  ✓
set_node_property("Player", "invalid_prop", 123)  ✗ 失败
→ 整个事务自动回滚
→ 返回 { ok: false, error: { code: "TRANSACTION_FAILED", message: "...", failed_step: 2 } }
```

**单工具调用**：
```
add_node(".", "Node2D", "NewNode")
→ 自动包裹为单步事务
→ 等价于：begin_ai_action("add_node") → add_node → end_ai_action()
```

### 失败处理

**事务失败时**：
- 整个事务回滚到 `begin_ai_action` 前状态
- 返回错误响应，包含：
  - `code`: 错误代码（如 `NODE_NOT_FOUND`, `INVALID_PROPERTY`）
  - `message`: 错误描述
  - `failed_step`: 失败的步骤编号（从 1 开始）
  - `suggestions`: 恢复建议

**未关闭事务**：
- 会话终止时，未提交事务自动回滚
- 插件侧维护超时机制（30 秒无操作自动结束事务）

## Read-before-write 原则

**规则**：所有写操作前必须先调用 `get_scene_tree` 验证目标状态。

**目的**：
- 防止基于过期状态的操作
- AI 代理确认场景结构后再修改
- 减少因状态不一致导致的失败

**强制级别**：
- Node 侧：工具文档强烈建议
- Plugin 侧：重验证目标节点/父节点存在性（不依赖 AI 遵守）

## 验收标准

- [ ] 六个写操作工具实现并通过单元测试
- [ ] 事务 API（`begin_ai_action` / `end_ai_action`）实现
- [ ] 多步操作成功提交为单个 UndoRedo Action
- [ ] 失败事务完整回滚，返回 `failed_step`
- [ ] `delete_node` 验证节点存在性后删除
- [ ] 单工具调用自动形成单步事务
- [ ] 未关闭事务在会话终止时自动回滚
- [ ] 集成测试：复杂多步场景构建 + 中途失败回滚
- [ ] 手动测试：编辑器内 Ctrl+Z 撤销 AI 事务

## 技术实现要点

### Node 侧
- 工具参数 JSON Schema 验证
- `begin_ai_action` / `end_ai_action` 状态管理
- 请求 ID 关联（事务内所有操作共享事务 ID）

### Plugin 侧
- `EditorUndoRedoManager` 集成
  ```gdscript
  var undo_redo = get_undo_redo()
  undo_redo.create_action("AI: " + action_name)
  # ... add do/undo method pairs
  undo_redo.commit_action()
  ```
- 节点/属性存在性验证（不信任客户端）
- 事务失败时调用 `undo_redo.clear_history()`（仅清除当前未提交事务）

## 未来扩展

- Phase 3：脚本附加（基于此阶段的节点操作基础）
- Phase 4：场景执行（需要完整的场景构建能力）

详见 `docs/phases/product-overview.md` 第 2 节。
