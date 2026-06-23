# Phase 2 手动测试指南

## 前置条件

1. 启动 Godot 编辑器并打开一个项目
2. 启用 ai_godot_mcp 插件
3. 创建或打开一个场景
4. 在终端运行：`node build/index.js`

## 测试场景

### 1. 单操作测试（自动事务包裹）

通过 MCP 客户端调用：

```json
{
  "method": "tools/call",
  "params": {
    "name": "add_node",
    "arguments": {
      "parent_path": ".",
      "node_type": "Node2D",
      "node_name": "TestNode"
    }
  }
}
```

**预期结果**：
- 节点被添加到场景
- 在 Godot 编辑器按 Ctrl+Z 可撤销

### 2. 多步事务测试

```json
// 步骤 1：开始事务
{"method": "tools/call", "params": {"name": "begin_ai_action", "arguments": {"name": "Setup Player"}}}

// 步骤 2：添加节点
{"method": "tools/call", "params": {"name": "add_node", "arguments": {"parent_path": ".", "node_type": "CharacterBody2D", "node_name": "Player"}}}

// 步骤 3：设置属性
{"method": "tools/call", "params": {"name": "set_node_property", "arguments": {"node_path": "Player", "property": "position", "value": {"x": 100, "y": 100}}}}

// 步骤 4：提交事务
{"method": "tools/call", "params": {"name": "end_ai_action"}}
```

**预期结果**：
- Player 节点被创建且位置为 (100, 100)
- 按一次 Ctrl+Z 撤销整个操作（节点消失 + 属性重置）

### 3. 失败回滚测试

```json
// 步骤 1：开始事务
{"method": "tools/call", "params": {"name": "begin_ai_action", "arguments": {"name": "Invalid Setup"}}}

// 步骤 2：添加节点（成功）
{"method": "tools/call", "params": {"name": "add_node", "arguments": {"parent_path": ".", "node_type": "Node2D", "node_name": "Test"}}}

// 步骤 3：设置无效属性（失败）
{"method": "tools/call", "params": {"name": "set_node_property", "arguments": {"node_path": "Test", "property": "invalid_prop", "value": 123}}}
```

**预期结果**：
- 第 3 步返回错误：`{"ok": false, "error": {"code": "INVALID_PROPERTY", "failed_step": 2}}`
- 场景保持原样（Test 节点未被添加）

### 4. 删除节点测试

```json
// 先添加一个节点
{"method": "tools/call", "params": {"name": "add_node", "arguments": {"parent_path": ".", "node_type": "Node2D", "node_name": "ToDelete"}}}

// 删除节点
{"method": "tools/call", "params": {"name": "delete_node", "arguments": {"node_path": "ToDelete"}}}
```

**预期结果**：
- 节点被删除
- Ctrl+Z 可恢复

### 5. 保存场景测试

```json
{"method": "tools/call", "params": {"name": "save_current_scene"}}
```

**预期结果**：
- 返回 `{"ok": true, "data": {"saved_path": "res://..."}}`
- 场景文件被保存

## 验证清单

- [ ] 单操作自动包裹为事务
- [ ] 多步事务作为单个撤销单元
- [ ] 失败事务完全回滚（场景不变）
- [ ] Ctrl+Z 可撤销 AI 操作
- [ ] 错误响应包含 failed_step
- [ ] 所有工具返回正确的数据格式
