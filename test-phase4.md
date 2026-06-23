# Phase 4 测试文档：场景执行与日志捕获

## 测试环境
- Godot 编辑器运行中
- MCP Server 已启动 (`npm start`)
- 已安装插件 (`addons/ai_godot_mcp`)

## 测试 1：场景控制基础功能

### 1.1 运行当前场景
```typescript
// 确保有场景打开
const projectContext = await mcp.callTool("get_project_context", );
console.log("Project:", projectContext);

// 运行场景
const runResult = await mcp.callTool("play_current_scene", {});
console.log("Run result:", runResult);
// 预期: { scene_path: "res://xxx.tscn", status: "running" }
```

### 1.2 停止场景
```typescript
// 等待几秒后停止
await new Promise(resolve => setTimeout(resolve, 3000));

const stopResult = await mcp.callTool("stop_running_scene", {});
console.log("Stop result:", stopResult);
// 预期: { stopped: true }
```

## 测试 2：增强日志系统

### 2.1 获取所有日志
```typescript
const logs = await mcp.callTool("get_editor_logs", {});
console.log("All logs:", logs);
// 预期: { logs: [{ timestamp, level, message, source }, ...] }
```

### 2.2 增量日志拉取
```typescript
const t0 = Math.floor(Date.now() / 1000);

// 运行场景产生日志
await mcp.callTool("play_current_scene", {});
await new Promise(resolve => setTimeout(resolve, 2000));
await mcp.callTool("stop_running_scene", {});

// 拉取新日志
const newLogs = await mcp.callTool("get_editor_logs", { 
  since_timestamp: t0 
});
console.log("New logs:", newLogs);
// 预期: 只包含运行场景后的日志
```

### 2.3 过滤日志级别
```typescript
const errorLogs = await mcp.callTool("get_editor_logs", { 
  filter_level: "error" 
});
console.log("Error logs:", errorLogs);

const infoLogs = await mcp.callTool("get_editor_logs", { 
  filter_level: "info" 
});
console.log("Info logs:", infoLogs);
```

## 测试 3：完整工作流

### 3.1 构建场景
```typescript
await mcp.callTool("begin_ai_action", { name: "Phase4 test scene" });
await mcp.callTool("add_node", { 
  parent_path: ".", 
  node_type: "Node2D", 
  node_name: "Main" 
});
await mcp.callTool("end_ai_action", {});
await mcp.callTool("save_current_scene", {});
```

### 3.2 附加测试脚本
创建 `res://phase4_test.gd`:
```gdscript
extends Node2D

func _ready():
    print("Phase 4 test scene started!")
    print("Testing runtime output capture")
```

```typescript
await mcp.callTool("attach_script", { 
  node_path: "Main", 
  script_path: "res://phase4_test.gd" 
});
await mcp.callTool("save_current_scene", {});
```

### 3.3 运行并捕获日志
```typescript
const t0 = Math.floor(Date.now() / 1000);

// 运行场景
await mcp.callTool("play_current_scene", {});

// 等待场景输出
await new Promise(resolve => setTimeout(resolve, 2000));

// 捕获日志
const logs = await mcp.callTool("get_editor_logs", { 
  since_timestamp: t0,
  filter_level: "info"
});
console.log("Runtime logs:", logs);

// 停止场景
await mcp.callTool("stop_running_scene", {});
```

## 测试 4：错误日志捕获

### 4.1 创建有错误的脚本
创建 `res://error_test.gd`:
```gdscript
extends Node2D

func _ready():
    var node = get_node("NonExistent")  # 会产生错误
```

### 4.2 附加并运行
```typescript
await mcp.callTool("attach_script", { 
  node_path: "Main", 
  script_path: "res://error_test.gd" 
});
await mcp.callTool("save_current_scene", {});

const t0 = Math.floor(Date.now() / 1000);
await mcp.callTool("play_current_scene", {});
await new Promise(resolve => setTimeout(resolve, 2000));

const errorLogs = await mcp.callTool("get_editor_logs", { 
  since_timestamp: t0,
  filter_level: "error"
});
console.log("Error logs:", errorLogs);
// 预期: 包含 "Node not found" 或类似错误

await mcp.callTool("stop_running_scene", {});
```

## 验收标准检查

- [x] `play_current_scene` 返回场景路径和状态
- [x] `stop_running_scene` 成功停止场景
- [x] `get_editor_logs` 支持 `since_timestamp` 参数
- [x] `get_editor_logs` 支持 `filter_level` 参数
- [x] 日志包含 `timestamp`, `level`, `message`, `source` 字段
- [x] 日志区分 `editor` 和 `runtime` 来源
- [ ] 捕获运行时 `print()` 输出（需 Godot 侧进一步实现）
- [ ] 捕获运行时错误（需 Godot 侧进一步实现）

## 已知限制

当前实现的日志捕获是**基础版本**：
- ✅ 场景启动/停止事件会记录日志
- ⚠️ GDScript 的 `print()` 输出**暂未捕获**（需要 Godot 引擎级别的输出重定向）
- ⚠️ 运行时错误**暂未捕获**（需要连接 Godot 调试器 API）

**改进方向**（Phase 4.3）：
1. 使用 `OS.execute` 重定向 stdout 到临时文件
2. 轮询读取文件内容并解析为日志
3. 或探索 `EditorDebuggerPlugin` API 捕获调试输出

## 当前功能已满足
- ✅ 场景可以运行和停止
- ✅ 日志系统支持时间戳过滤
- ✅ 日志系统支持级别过滤
- ✅ 日志结构完整（timestamp/level/message/source）
- ✅ 基础工作流闭环（构建→附加→运行→日志→停止）
