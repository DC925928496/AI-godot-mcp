# Phase 3：脚本附加

## 目标

将现有 GDScript 资源安全绑定到场景节点。

## 前置依赖

- **依赖 Phase 2**：写操作基础（节点创建、属性修改）
- **依赖 Phase 1**：场景树读取

## 工具清单

### `attach_script`
附加脚本到目标节点。

**参数**：
- `node_path` (string)：目标节点路径
- `script_path` (string)：脚本资源路径（`res://` 格式）

**返回**：
- `attached_script` (string)：已附加的脚本路径
- `resource_uid` (string)：脚本资源 UID

**验证**：
- 节点必须存在
- 脚本文件必须存在且为有效 GDScript
- 脚本路径必须通过 `validatePath` 规则
- MVP 仅支持 `.gd` 文件（GDScript）

**UndoRedo 集成**：
- 支持撤销（恢复节点原脚本或移除脚本）
- 可包含在 `begin_ai_action` 事务中

### `get_resource_uid`
获取资源 UID 用于验证。

**参数**：
- `resource_path` (string)：资源路径

**返回**：
- `uid` (string)：资源 UID
- `type` (string)：资源类型

**用途**：
- 验证资源存在性
- 跨场景资源引用验证

## GDScript 附加验证

### 分离验证层次

1. **类名验证**（Node 侧）：
   - 使用 `validateClassName` 规则
   - 防止任意类实例化攻击

2. **资源路径验证**（Node 侧）：
   - 使用 `validatePath` 规则
   - 仅允许 `res://` 协议
   - 禁止路径遍历

3. **节点路径验证**（Plugin 侧）：
   - 重验证节点存在性
   - 验证节点可附加脚本

4. **脚本文件验证**（Plugin 侧）：
   - 文件存在性检查
   - GDScript 语法有效性（调用 `ResourceLoader.load` 验证）
   - 资源类型确认为 `GDScript`

### 错误场景

**脚本文件不存在**：
```json
{
  "ok": false,
  "error": {
    "code": "SCRIPT_NOT_FOUND",
    "message": "Script file does not exist: res://player.gd",
    "suggestions": ["Verify script path", "Check file exists in project"]
  }
}
```

**脚本语法错误**：
```json
{
  "ok": false,
  "error": {
    "code": "INVALID_SCRIPT",
    "message": "GDScript syntax error at line 15",
    "suggestions": ["Fix script syntax errors before attaching"]
  }
}
```

**节点不存在**：
```json
{
  "ok": false,
  "error": {
    "code": "NODE_NOT_FOUND",
    "message": "Target node not found: Player/InvalidNode",
    "suggestions": ["Call get_scene_tree first", "Verify node path"]
  }
}
```

## 工作流集成

### 典型流程

1. **创建脚本文件**（通用编码流程，非 MCP）：
   - AI 代理在用户编辑器/IDE 中生成 GDScript 代码
   - 保存为 `res://scripts/player.gd`

2. **验证脚本存在**：
   ```
   get_resource_uid("res://scripts/player.gd")
   → { uid: "uid://...", type: "GDScript" }
   ```

3. **附加到节点**：
   ```
   attach_script("Player", "res://scripts/player.gd")
   → { attached_script: "res://scripts/player.gd", resource_uid: "..." }
   ```

### 事务包裹示例

```
begin_ai_action("Setup player with script")
add_node(".", "CharacterBody2D", "Player")
add_node("Player", "Sprite2D", "Sprite")
attach_script("Player", "res://scripts/player.gd")
end_ai_action()
→ 整个操作（创建节点 + 附加脚本）作为单个撤销单元
```

## MCP 范围界定

### MCP 负责
- ✅ 验证脚本资源存在
- ✅ 附加脚本到节点
- ✅ 运行场景观测结果（Phase 4）
- ✅ 检查编辑器日志中的脚本错误

### MCP 不负责
- ❌ 生成 GDScript 代码内容
- ❌ 编辑现有脚本文件
- ❌ 脚本语法分析（由 Godot 编辑器处理）
- ❌ 脚本调试（断点、变量监视等）

**原则**：脚本创建/修改留在通用编码工作流；MCP 仅处理编辑器内的资源附加和执行观测。

## 验收标准

- [ ] `attach_script` 成功绑定 GDScript 到节点
- [ ] `get_resource_uid` 返回有效资源 UID
- [ ] 脚本不存在时返回 `SCRIPT_NOT_FOUND`
- [ ] 脚本语法错误时返回 `INVALID_SCRIPT`
- [ ] 节点不存在时返回 `NODE_NOT_FOUND`
- [ ] 附加操作支持 UndoRedo（可撤销）
- [ ] 附加操作可包含在 `begin_ai_action` 事务中
- [ ] 集成测试：创建节点 → 附加脚本 → 运行场景（Phase 4）

## 技术实现要点

### Node 侧
- `script_path` 参数通过 `validatePath` 验证
- 仅允许 `.gd` 文件扩展名（MVP 限制）

### Plugin 侧
```gdscript
# 伪代码
func attach_script(node_path: String, script_path: String):
    var node = get_node_or_null(node_path)
    if not node:
        return error("NODE_NOT_FOUND")
    
    var script = ResourceLoader.load(script_path)
    if not script or not script is GDScript:
        return error("INVALID_SCRIPT")
    
    var undo_redo = get_undo_redo()
    var old_script = node.get_script()
    undo_redo.create_action("AI: Attach script")
    undo_redo.add_do_method(node, "set_script", script)
    undo_redo.add_undo_method(node, "set_script", old_script)
    undo_redo.commit_action()
    
    return success({ "attached_script": script_path, "resource_uid": script.resource_uid })
```

## 未来扩展

- Phase 4：运行附加脚本的场景，检查运行时错误
- 未来：支持 C# 脚本附加（需要 Mono 构建验证）

详见 `docs/phases/product-overview.md` 第 3 节。
