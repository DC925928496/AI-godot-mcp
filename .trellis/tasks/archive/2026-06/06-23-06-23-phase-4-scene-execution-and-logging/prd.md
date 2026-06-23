# Phase 4: 场景执行与日志捕获

## 目标
实现场景运行控制和完整的运行时日志捕获系统，完成游戏开发工作流闭环。

## 核心功能

### 1. 场景控制工具
- **`play_current_scene`**：运行当前编辑的场景（等价于 F6）
  - 返回场景路径和运行状态
  - 场景在独立窗口运行，编辑器保持响应
  
- **`stop_running_scene`**：停止运行的场景（等价于 F8）
  - 关闭场景窗口
  - 返回停止确认

### 2. 增强日志系统
升级现有的 `get_editor_logs` 工具：

**新增参数**：
- `since_timestamp` (number, 可选)：仅返回此时间戳之后的日志
- `filter_level` (string, 可选)：过滤日志级别（`error`, `warning`, `info`, `all`）

**返回结构**：
```json
{
  "logs": [
    {
      "timestamp": 1719117968,
      "level": "error",
      "message": "Invalid get index 'health' (on base: 'Node2D')",
      "source": "runtime"
    }
  ]
}
```

**日志来源标识**：
- `editor`：编辑器操作日志
- `runtime`：场景运行时日志

### 3. 真实日志捕获
**关键需求**：捕获 Godot 场景运行时的所有输出
- `print()` 输出
- `push_error()` / `push_warning()` 输出
- 资源加载错误
- 脚本运行时错误

**技术约束**：
- Godot 没有官方 API 拦截标准输出
- 需要探索可行的捕获方案（见技术方案）

## 典型工作流

```
1. 构建场景（Phase 2）
   begin_ai_action() → add_node() → end_ai_action()

2. 附加脚本（Phase 3）
   attach_script(node_path, script_path)

3. 运行场景
   play_current_scene() → { scene_path: "res://test.tscn", status: "running" }

4. 捕获日志（增量拉取）
   t0 = current_timestamp
   get_editor_logs({ since_timestamp: t0, filter_level: "error" })

5. 停止场景
   stop_running_scene()

6. 根据日志修复错误 → 重新运行
```

## 技术方案

### Node 侧 (TypeScript)

**文件**：`src/server/createServer.ts`

1. 新增 Schema 定义：
```typescript
const PlayCurrentSceneSchema = z.object({});
const StopRunningSceneSchema = z.object({});
const GetEditorLogsSchema = z.object({
  since_timestamp: z.number().optional(),
  filter_level: z.enum(["error", "warning", "info", "all"]).optional()
});
```

2. 新增工具注册：
```typescript
server.tool("play_current_scene", "Run current scene (F6)", async () => {
  const data = await conn.send("play_current_scene");
  return { content: [{ type: "text", text: JSON.stringify(data) }] };
});

server.tool("stop_running_scene", "Stop running scene (F8)", async () => {
  const data = await conn.send("stop_running_scene");
  return { content: [{ type: "text", text: JSON.stringify(data) }] };
});
```

3. 替换现有的 `get_editor_logs` 为增强版本

### Godot Plugin 侧 (GDScript)

**文件**：`addons/ai_godot_mcp/websocket_server.gd`

#### 日志缓冲区基础设施
```gdscript
var _log_buffer: Array[Dictionary] = []
var _max_log_size := 1000
var _is_scene_running := false

func _add_log(level: String, message: String, source: String):
    _log_buffer.append({
        "timestamp": int(Time.get_unix_time_from_system()),
        "level": level,
        "message": message,
        "source": source
    })
    if _log_buffer.size() > _max_log_size:
        _log_buffer.pop_front()
```

#### 场景控制 RPC
```gdscript
func handle_play_current_scene(_params: Dictionary) -> Dictionary:
    var editor := get_editor_interface()
    var scene_root := editor.get_edited_scene_root()
    if not scene_root:
        return error("No scene is currently open")
    
    var scene_path := scene_root.scene_file_path
    _is_scene_running = true
    editor.play_current_scene()
    
    return success({
        "scene_path": scene_path,
        "status": "running"
    })

func handle_stop_running_scene(_params: Dictionary) -> Dictionary:
    get_editor_interface().stop_playing_scene()
    _is_scene_running = false
    return success({ "stopped": true })
```

#### 日志捕获实现（核心难点）

**方案探索**：

**方案 A：EditorPlugin 输出重定向**
- 利用 `EditorPlugin.get_editor_interface().get_base_control()` 监听子控制台
- 可行性：待验证

**方案 B：AutoLoad 单例拦截**
- 创建全局脚本重写 `print` 函数
- 问题：Godot 4.x 的 `print` 是内置函数，无法重写

**方案 C：监听编辑器输出面板**
- 查找 `EditorLog` 节点，连接其信号
- 可行性：高（如果 Godot 暴露了此节点）

**方案 D：文件重定向**
- 启动场景时重定向 stdout 到临时文件
- 在 `_process` 中读取文件内容
- 缺点：延迟高，需要轮询

**推荐方案**：先尝试方案 C，如果不可行则用方案 D 兜底。

#### 增强日志查询
```gdscript
func handle_get_editor_logs(params: Dictionary) -> Dictionary:
    var since_ts := params.get("since_timestamp", 0)
    var filter_level := params.get("filter_level", "all")
    
    var filtered := _log_buffer.filter(func(log):
        var match_time := log.timestamp > since_ts
        var match_level := (filter_level == "all" or log.level == filter_level)
        return match_time and match_level
    )
    
    return success({ "logs": filtered })
```

## 验收标准

- [ ] `play_current_scene` 成功运行场景并返回场景路径
- [ ] `stop_running_scene` 停止场景并返回确认
- [ ] 场景在独立窗口运行，编辑器保持响应
- [ ] `get_editor_logs` 支持 `since_timestamp` 参数
- [ ] `get_editor_logs` 支持 `filter_level` 参数（error/warning/info/all）
- [ ] 日志区分 `editor` 和 `runtime` 来源
- [ ] 捕获运行时的 `print()` 输出
- [ ] 捕获运行时错误（脚本错误、资源加载失败等）
- [ ] 增量日志拉取避免重复传输
- [ ] 集成测试：完整工作流（构建→附加脚本→运行→捕获日志→修复→重新运行）

## 实现优先级

1. **P0（核心）**：场景控制工具 + 日志缓冲区基础设施
2. **P0（核心）**：增强日志查询（时间戳过滤 + 级别过滤）
3. **P0（核心）**：运行时日志捕获（至少实现一种可行方案）
4. **P1（重要）**：区分 editor 和 runtime 日志来源
5. **P2（可选）**：AI 操作历史面板（暂不实现）

## 技术风险

1. **日志捕获可行性**：Godot 可能没有提供捕获输出的 API
   - 缓解：准备多个备选方案，至少实现文件重定向方案
   
2. **场景运行时插件响应**：场景运行可能阻塞插件 WebSocket
   - 缓解：验证 Godot 的线程模型，确保 WebSocket 在主线程响应

3. **日志缓冲区内存溢出**：长时间运行可能积累大量日志
   - 缓解：限制 1000 条 + 滚动窗口

## 依赖

- Phase 2（场景构建）
- Phase 3（脚本附加）
- 现有 WebSocket 基础设施
- 现有 `get_editor_logs` 工具（需升级）

## 参考资料

- `docs/phases/phase-4-scene-execution.md`：原始 PRD
- Godot 文档：`EditorInterface` API
- Godot 文档：`EditorPlugin` 生命周期
