# Phase 4：场景执行与调试

## 目标

运行场景并捕获日志，完成游戏开发主工作流闭环。

## 前置依赖

- **依赖 Phase 3**：脚本附加能力
- **依赖 Phase 2**：场景构建能力
- **依赖 Phase 1**：只读检查工具

## 工具清单

### `play_current_scene`
运行当前编辑的场景。

**参数**：无

**返回**：
- `scene_path` (string)：运行的场景路径
- `status` (string)：`running`

**行为**：
- 等价于点击编辑器"运行当前场景"按钮（F6）
- 场景在独立窗口运行
- 编辑器保持响应

### `stop_running_scene`
停止当前运行的场景。

**参数**：无

**返回**：
- `stopped` (boolean)：`true`

**行为**：
- 等价于点击编辑器"停止"按钮（F8）
- 场景窗口关闭

### 增强版 `get_editor_logs`
获取编辑器输出面板日志（包含运行时输出）。

**新增参数**：
- `since_timestamp` (number, 可选)：仅返回此时间戳后的日志
- `filter_level` (string, 可选)：过滤日志级别（`error`, `warning`, `info`）

**返回**：
- `logs` (array)：日志条目
  - `timestamp` (number)：时间戳
  - `level` (string)：级别
  - `message` (string)：内容
  - `source` (string)：来源（`editor` / `runtime`）

**增强功能**：
- 区分编辑器日志和运行时日志
- 支持增量拉取（避免重复传输大量日志）

## 运行时日志捕获

### 典型工作流

1. **构建场景**（Phase 2）：
   ```
   begin_ai_action("Setup test scene")
   add_node(".", "Node2D", "Main")
   add_node("Main", "Sprite2D", "Player")
   end_ai_action()
   ```

2. **附加脚本**（Phase 3）：
   ```
   attach_script("Main", "res://main.gd")
   ```

3. **运行场景**：
   ```
   play_current_scene()
   → { scene_path: "res://test.tscn", status: "running" }
   ```

4. **捕获日志**：
   ```
   get_editor_logs({ filter_level: "error", since_timestamp: 1234567890 })
   → { logs: [
       { timestamp: 1234567895, level: "error", message: "Invalid call...", source: "runtime" }
     ] }
   ```

5. **停止场景**：
   ```
   stop_running_scene()
   ```

6. **分析错误 + 修复**（根据日志调整脚本或场景）

### 错误检测示例

**脚本运行时错误**：
```
play_current_scene()
get_editor_logs()
→ logs: [
    "Invalid get index 'health' (on base: 'Node2D').",
    "   at: GDScript::call (res://main.gd:15)"
  ]
→ AI 分析：节点缺少 health 属性，需修改脚本或添加变量
```

**资源加载失败**：
```
logs: [
    "Failed to load resource 'res://missing_texture.png'.",
    "   at: ResourceLoader::load"
  ]
→ AI 分析：纹理路径错误，需更正资源引用
```

## 可选 AI 操作历史面板

### 功能
在编辑器 Dock 显示最近 AI 操作：
- 操作类型（`add_node`, `attach_script`, 等）
- 时间戳
- 参数摘要
- 状态（成功/失败）

### 用途
- 开发者可视化 AI 所做修改
- 快速定位可疑操作
- 点击条目跳转到相关节点/资源

### 实现优先级
- 非 MVP 核心功能
- Phase 4 可选交付
- 改进用户信任和调试体验

## 验收标准

- [ ] `play_current_scene` 成功运行场景
- [ ] `stop_running_scene` 停止运行场景
- [ ] 增强版 `get_editor_logs` 区分编辑器/运行时日志
- [ ] 增量日志拉取（`since_timestamp` 参数）
- [ ] 集成测试：完整游戏开发工作流
  - 检查场景 → 修改节点 → 附加脚本 → 运行场景 → 检查日志 → 修复错误 → 重新运行
- [ ] 运行时错误正确捕获到日志
- [ ] 可选：AI 操作历史面板显示最近操作

## 技术实现要点

### Node 侧
- `play_current_scene` / `stop_running_scene` 无复杂验证
- `get_editor_logs` 支持增量查询参数

### Plugin 侧
```gdscript
# 伪代码
func play_current_scene():
    var editor_interface = get_editor_interface()
    editor_interface.play_current_scene()
    return success({ "scene_path": get_edited_scene_root().scene_file_path, "status": "running" })

func stop_running_scene():
    get_editor_interface().stop_playing_scene()
    return success({ "stopped": true })

var log_buffer = []  # 持久化日志缓冲区

func get_editor_logs(params):
    var since_ts = params.get("since_timestamp", 0)
    var filter_level = params.get("filter_level", "all")
    
    var filtered = log_buffer.filter(func(log):
        return log.timestamp > since_ts and (filter_level == "all" or log.level == filter_level)
    )
    
    return success({ "logs": filtered })
```

**日志捕获**：
- 重写 `EditorPlugin._print()` 捕获运行时输出
- 或监听编辑器输出面板变化信号

## 未来扩展

- Phase 5：打包发布后，此工作流作为完整功能演示
- 实时日志流（WebSocket 推送，无需轮询）
- 运行时变量监视（需 Godot 调试器 API）

详见 `docs/phases/product-overview.md` 第 4 节。
