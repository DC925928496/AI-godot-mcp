# PRD: 修复 Phase 4 核心 Bug 并完善 MCP 工具链

## 1. 背景与目标

### 当前状态
AI-godot-mcp 项目在代码审查中发现多个 P0/P1/P2 级别的缺陷，导致核心功能（play_current_scene、stop_running_scene、get_editor_logs）完全无法使用，以及通信层、安全模型、测试覆盖等方面存在严重问题。

### 目标
按优先级修复所有已识别的 Bug，确保：
1. **P0 问题**：核心功能可用（场景运行、日志捕获、错误传递）
2. **P1 问题**：连接稳定性、信息完整性、安全基线
3. **P2 问题**：文档对齐、测试覆盖、用户体验

### 非目标（本期不做）
- 新增"只读"工具（get_node_properties、get_script_content 等）
- 新增"写"工具（instantiate_scene、move_node 等）
- WebSocket 双向推送
- 调试器集成
- C# 支持

---

## 2. 问题清单与修复方案

### 🔴 P0 — 阻塞性问题（必须修复）

#### P0-1: Phase 4 方法未注册
**问题**：`websocket_server.gd` 的 `handle_request` 中没有注册 `play_current_scene` 和 `stop_running_scene`，导致这两个工具返回 `UNKNOWN_METHOD`。

**位置**：`addons/ai_godot_mcp/websocket_server.gd:40-89`

**修复方案**：
```gdscript
match req.get("method"):
    # ... 现有方法 ...
    "play_current_scene":
        return handle_play_scene(req)
    "stop_running_scene":
        return handle_stop_scene(req)
    "get_editor_logs":
        return handle_get_logs(req)  # 替换硬编码的空数组
```

**验证**：调用 `play_current_scene` 和 `stop_running_scene` 应返回 `{ok: true}`

---

#### P0-2: editorConnection.ts 错误传递失效
**问题**：第 13 行 `Promise.reject(new Error(...))` 返回一个已 rejected 的 Promise 对象作为 value 传给 `resolve`，导致外层 Promise 是 fulfilled 状态，AI 无法捕获错误。

**位置**：`src/server/editorConnection.ts:13`

**修复方案**：
```typescript
async connect(): Promise<void> {
  this.ws = new WebSocket(`ws://localhost:${this.port}`);
  this.ws.on("message", (data) => {
    const res = JSON.parse(data.toString());
    const cb = this.pending.get(res.id);
    if (!cb) return;
    this.pending.delete(res.id);
    
    if (res.ok) {
      cb(res.data);
    } else {
      cb(Promise.reject(new Error(res.error?.message || "Unknown error")));
    }
  });
  // ...
}

async send(method: string, params?: unknown, txnId?: string | null): Promise<unknown> {
  const id = Date.now().toString();
  return new Promise((resolve, reject) => {
    this.pending.set(id, (result) => {
      if (result instanceof Promise && result.catch) {
        result.then(resolve).catch(reject);
      } else {
        resolve(result);
      }
    });
    this.ws!.send(JSON.stringify({ id, method, params, txn_id: txnId }));
  });
}
```

**验证**：故意传入错误参数，应能 catch 到错误

---

#### P0-3: get_editor_logs 永远返回空数组
**问题**：
1. `handle_get_logs` 定义了但从未被注册（见 P0-1）
2. `_log_buffer` 只在 `handle_play_scene/handle_stop_scene` 中写入，但这两个方法也未被调用
3. `_setup_log_capture` 连接的信号回调是空的 `pass`

**位置**：`addons/ai_godot_mcp/websocket_server.gd:59-64, 362-395`

**修复方案**：
1. 注册 `get_editor_logs` → `handle_get_logs`（已在 P0-1 修复）
2. 实现真实的日志捕获：
   - 方案 A（简单）：重定向 `print_rich`/`push_error`/`push_warning`（GDScript 4.x 限制较大）
   - 方案 B（推荐）：监听 `EditorInterface.get_editor_main_screen()` 的输出面板
   - 方案 C（运行时）：用 `EditorDebuggerPlugin` 捕获运行时日志

**本期实现**（最小可行）：
```gdscript
func _setup_log_capture():
    # 监听编辑器场景变化，记录关键事件
    EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
    
func _on_selection_changed():
    var selected = EditorInterface.get_selection().get_selected_nodes()
    if selected.size() > 0:
        _add_log("info", "Selected: " + selected[0].name, "editor")

func handle_play_scene(req: Dictionary) -> Dictionary:
    # 现有代码已有日志记录，只需确保被调用
    # ...
```

**验证**：运行场景后调用 `get_editor_logs`，应返回至少 1 条日志

---

### 🟠 P1 — 高优先级改进

#### P1-1: editorConnection.ts 缺连接管理
**问题**：
- 无请求超时
- 无心跳
- 无重连
- `id = Date.now().toString()` 同毫秒并发冲突
- 连接失败被 `createServer.ts:24` 静默吞掉

**修复方案**：
```typescript
export class EditorConnection {
  private ws: WebSocket | null = null;
  private pending = new Map<string, { resolve: any; reject: any; timeout: NodeJS.Timeout }>();
  private nextId = 1;
  private pingInterval: NodeJS.Timeout | null = null;
  private reconnectAttempts = 0;
  private maxReconnects = 3;

  async connect(): Promise<void> {
    // 实现重连逻辑（指数退避）
    // 实现心跳（10s ping）
    // 实现超时清理
  }

  async send(method: string, params?: unknown, txnId?: string | null): Promise<unknown> {
    const id = (this.nextId++).toString();
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Request timeout: ${method}`));
      }, 10000); // 10s 超时
      
      this.pending.set(id, { resolve, reject, timeout });
      this.ws!.send(JSON.stringify({ id, method, params, txn_id: txnId }));
    });
  }
}
```

**验证**：
- 断开 Godot，应自动重连（最多 3 次）
- 单个请求超过 10s 应抛出超时错误
- 并发 100 个请求，ID 不应冲突

---

#### P1-2: serialize_node 信息严重不足
**问题**：只返回 `name/type/children`，AI 无法看到属性、脚本、信号、groups。

**修复方案**：
```gdscript
func serialize_node(node: Node, depth: int) -> Dictionary:
    if not node or depth <= 0:
        return {}
    
    var result = {
        "name": node.name,
        "type": node.get_class(),
        "children": node.get_children().map(func(c): return serialize_node(c, depth - 1))
    }
    
    # 添加关键属性
    if node.has_method("get_property_list"):
        var props = {}
        for prop in node.get_property_list():
            if prop.usage & PROPERTY_USAGE_EDITOR:
                props[prop.name] = str(node.get(prop.name))
        result["properties"] = props
    
    # 添加脚本信息
    var script = node.get_script()
    if script:
        result["script"] = script.resource_path
    
    # 添加 groups
    result["groups"] = node.get_groups()
    
    return result
```

**验证**：调用 `get_scene_tree`，返回应包含 `properties`、`script`、`groups` 字段

---

#### P1-3: 安全模型完全没实现
**问题**：
- 无 WebSocket 认证
- 无路径白名单（res:// 协议检查、.. 防护）
- 无类名白名单
- Yellow/Red 权限无实际校验

**修复方案**（最小化）：
```gdscript
# websocket_server.gd 添加
var auth_token := ""

func _ready() -> void:
    auth_token = _generate_token()
    _save_token_to_file()
    server.create_server(port)
    # ...

func _generate_token() -> String:
    return str(Time.get_ticks_msec()) + "_" + str(randi())

func _save_token_to_file():
    var file = FileAccess.open("user://ai_mcp_token", FileAccess.WRITE)
    file.store_string(auth_token)
    file.close()

func handle_request(req: Dictionary) -> Dictionary:
    # 验证 token
    if req.get("auth_token", "") != auth_token:
        return {"id": req.id, "ok": false, "error": {"code": "UNAUTHORIZED", "message": "Invalid token"}}
    # ...

func _validate_path(path: String) -> bool:
    if not path.begins_with("res://"):
        return false
    if ".." in path:
        return false
    return true

func _validate_class_name(class_name: String) -> bool:
    var blacklist = ["EditorInterface", "ScriptEditor", "OS"]
    return class_name not in blacklist
```

**Node 端**：
```typescript
async connect(): Promise<void> {
  const token = await fs.readFile(path.join(os.homedir(), ".godot", "ai_mcp_token"), "utf-8");
  this.authToken = token.trim();
  // ...
}

async send(method: string, params?: unknown, txnId?: string | null): Promise<unknown> {
  // ...
  this.ws!.send(JSON.stringify({ id, method, params, txn_id: txnId, auth_token: this.authToken }));
}
```

**验证**：
- 未传 token，应返回 `UNAUTHORIZED`
- 传入 `../../etc/passwd`，应被拒绝
- 尝试实例化 `EditorInterface`，应被拒绝

---

#### P1-4: create_scene 路径处理粗糙
**问题**：
- 不检查重名覆盖
- 不支持子目录
- 没有事务包裹

**修复方案**：
```gdscript
func handle_create_scene(req: Dictionary) -> Dictionary:
    var params = req.get("params", {})
    var scene_name = params.get("scene_name", "")
    var root_node_type = params.get("root_node_type", "Node2D")
    
    if not ClassDB.class_exists(root_node_type):
        return {"id": req.id, "ok": false, "error": {"code": "INVALID_TYPE", "message": "Invalid node type: " + root_node_type}}
    
    # 处理子目录
    var scene_path = "res://" + scene_name
    if not scene_path.ends_with(".tscn"):
        scene_path += ".tscn"
    
    # 检查重名
    if ResourceLoader.exists(scene_path):
        return {"id": req.id, "ok": false, "error": {"code": "FILE_EXISTS", "message": "Scene already exists: " + scene_path}}
    
    # 确保目录存在
    var dir_path = scene_path.get_base_dir()
    if not DirAccess.dir_exists_absolute(dir_path):
        DirAccess.make_dir_recursive_absolute(dir_path)
    
    # 创建场景
    var new_scene = ClassDB.instantiate(root_node_type)
    new_scene.name = scene_name.get_file().get_basename()
    
    var packed_scene = PackedScene.new()
    packed_scene.pack(new_scene)
    
    var err = ResourceSaver.save(packed_scene, scene_path)
    if err != OK:
        return {"id": req.id, "ok": false, "error": {"code": "SAVE_FAILED", "message": "Failed to create scene: " + str(err)}}
    
    return {"id": req.id, "ok": true, "data": {"scene_path": scene_path}}
```

**验证**：
- 创建 `ui/main_menu` 应生成 `res://ui/main_menu.tscn`
- 重复创建应返回 `FILE_EXISTS` 错误

---

### 🟡 P2 — 可选改进

#### P2-1: CHANGELOG 和代码对不上
**修复方案**：重写 `CHANGELOG.md`，使用实际工具名：
- ❌ `godot_get_property` → ✅ `get_scene_tree`
- ❌ `godot_mutate_scene` → ✅ `add_node`, `set_node_property`, `delete_node`
- ❌ `godot_rollback_scene` → ✅ `end_ai_action` (with rollback)
- ❌ `godot_execute_scene` → ✅ `play_current_scene`, `stop_running_scene`

**验证**：CHANGELOG 中的工具名应与 `createServer.ts` 中注册的工具名一致

---

#### P2-2: 测试覆盖近乎为零
**修复方案**（最小化）：
1. 扩展 `scripts/mock-godot-server.js`，覆盖所有 15 个方法
2. 为 `editorConnection.ts` 添加单元测试（超时、重连、错误传递）
3. 添加 E2E 测试：启动 Godot headless + 运行 MCP 客户端

**验证**：`npm test` 应覆盖至少 60% 的代码路径

---

#### P2-3: CLI 校验逻辑有 bug
**问题**：`validate.ts:29` 的逻辑会拒绝所有 `config_version=5` 前面有空格的项目。

**修复方案**：
```typescript
// validate.ts
const configMatch = content.match(/config_version\s*=\s*(\d+)/);
if (!configMatch || parseInt(configMatch[1]) < 5) {
  throw new Error("Project must be Godot 4.5+");
}

// 检查 4.6 特性
const featuresMatch = content.match(/features=PackedStringArray\("([^"]+)"\)/);
if (featuresMatch && !featuresMatch[1].includes("4.6")) {
  console.warn("Warning: Project may not be Godot 4.6");
}
```

**验证**：带缩进的 `project.godot` 文件应通过校验

---

#### P2-4: plugin.gd 的 Dock 是空壳
**修复方案**（最小化）：
```gdscript
# plugin.gd
func _build_dock_panel() -> Control:
    var panel := VBoxContainer.new()
    
    var title := Label.new()
    title.text = "AI-godot-mcp: WebSocket server on port 6550"
    panel.add_child(title)
    
    # 添加状态指示
    var status_label := Label.new()
    status_label.name = "StatusLabel"
    status_label.text = "Status: Connected"
    panel.add_child(status_label)
    
    # 添加操作历史列表
    var history_tree := Tree.new()
    history_tree.name = "HistoryTree"
    history_tree.set_columns(3)
    history_tree.set_column_titles_visible(true)
    history_tree.set_column_title(0, "Time")
    history_tree.set_column_title(1, "Method")
    history_tree.set_column_title(2, "Status")
    panel.add_child(history_tree)
    
    return panel
```

**验证**：启用插件后，Dock 应显示状态和操作历史（即使历史为空）

---

## 3. 实施计划

### 阶段 1：P0 修复（1-2 天）
- [ ] P0-1: 注册 Phase 4 方法
- [ ] P0-2: 修复错误传递
- [ ] P0-3: 实现基础日志捕获

### 阶段 2：P1 修复（2-3 天）
- [ ] P1-1: 连接管理（超时、重连、心跳、ID 生成）
- [ ] P1-2: 增强 serialize_node
- [ ] P1-3: 基础安全模型（token、路径校验、类名黑名单）
- [ ] P1-4: 改进 create_scene

### 阶段 3：P2 修复（1-2 天）
- [ ] P2-1: 对齐 CHANGELOG
- [ ] P2-2: 扩展测试覆盖
- [ ] P2-3: 修复 CLI 校验
- [ ] P2-4: 改进 Dock 面板

### 总计：4-7 天

---

## 4. 验收标准

### 功能验收
1. ✅ 调用 `play_current_scene` 能成功运行场景
2. ✅ 调用 `stop_running_scene` 能停止运行
3. ✅ 调用 `get_editor_logs` 返回非空日志
4. ✅ 故意传错误参数，AI 能捕获到错误
5. ✅ 断开 WebSocket，能自动重连（3 次内）
6. ✅ `get_scene_tree` 返回包含属性、脚本、groups
7. ✅ 未传 token 返回 `UNAUTHORIZED`
8. ✅ 传入非法路径（`..`）被拒绝

### 测试验收
1. ✅ `npm test` 通过率 100%
2. ✅ 代码覆盖率 ≥ 60%
3. ✅ 手动 E2E 测试通过（启动 Godot + 运行 MCP 客户端）

### 文档验收
1. ✅ CHANGELOG 与代码一致
2. ✅ README 更新（如有新功能）

---

## 5. 后续方向（不在本期范围）

### 第 2 期：补齐"只读"工具（2-3 周）
- `get_node_properties`
- `get_node_script`
- `get_script_content`
- `list_resources`
- `open_scene`
- `get_project_settings`
- `get_input_map`
- `get_autoloads`

### 第 3 期：补齐"写"工具（2-3 周）
- `instantiate_scene`
- `move_node`
- `reorder_node`
- `duplicate_node`
- `set_node_script`
- `add_node_signal_connection`
- `set_project_setting`
- `add_autoload` / `remove_autoload`

### 第 4 期：双向推送 + 调试器集成（3-4 周）
- WebSocket 事件推送
- `EditorDebuggerPlugin` 集成
- AI 操作历史 Dock（完整版）
- 审批流（Yellow/Red 操作确认对话框）

### 第 5 期：工程化和生态（持续）
- GUT 单元测试（GDScript）
- CI/CD（GitHub Actions）
- 版本兼容（>=4.4）
- CLI 增强（`doctor`、`init`）
- C# 支持

---

## 6. 风险与依赖

### 技术风险
- **日志捕获**：GDScript 无法直接重定向 `print()`，可能需要 `EditorDebuggerPlugin`（较复杂）
- **心跳/重连**：WebSocket 库行为依赖 Node.js 版本
- **token 文件位置**：`user://` 路径在不同 OS 下不同，需跨平台测试

### 外部依赖
- Godot 4.6.x（已锁定）
- Node.js >= 18（已在 package.json 声明）
- `ws` 库（已安装）

---

## 7. 附录

### 代码位置速查
| 组件 | 文件路径 |
|------|----------|
| WebSocket 服务端 | `addons/ai_godot_mcp/websocket_server.gd` |
| Node 连接层 | `src/server/editorConnection.ts` |
| MCP 工具注册 | `src/server/createServer.ts` |
| CLI 校验 | `src/cli/validate.ts` |
| 插件主入口 | `addons/ai_godot_mcp/plugin.gd` |

### 参考文档
- [Godot 4.6 EditorInterface API](https://docs.godotengine.org/en/stable/classes/class_editorinterface.html)
- [WebSocket API (ws npm)](https://github.com/websockets/ws)
- [MCP SDK](https://github.com/modelcontextprotocol/sdk)
