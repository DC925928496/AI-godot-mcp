# 迁移指南：Legacy 0.1.1 → AI-godot-mcp 1.0.0

## 架构变更

| Legacy (0.1.1) | AI-godot-mcp (1.0.0) |
|---|---|
| 无头脚本 | EditorPlugin |
| 手动启动服务器 | 插件自动启动 |
| 需配置路径 | CLI 自动部署 |

## 安装方式

**Legacy**:
```bash
# 手动复制文件 + 配置 MCP
```

**AI-godot-mcp**:
```bash
npx ai-godot-mcp install <project-path>
# 在编辑器中启用插件即可
```

## API 变更

### 工具名称

| Legacy | 1.0.0 | 说明 |
|---|---|---|
| `get_property` | `godot_get_property` | 保持一致 |
| `set_property` | `godot_set_property` | 保持一致 |
| `call_method` | `godot_call_method` | 保持一致 |
| `list_nodes` | `godot_list_nodes` | 保持一致 |
| - | `godot_mutate_scene` | **新增**：场景变更 |
| - | `godot_rollback_scene` | **新增**：回滚变更 |
| - | `godot_attach_script` | **新增**：附加脚本 |
| - | `godot_execute_scene` | **新增**：执行场景 |

### 参数格式

基本工具（get/set/call/list）参数格式不变。

## 迁移步骤

1. **卸载 Legacy**
   - 删除旧的 MCP 服务器配置
   - 从项目移除旧插件文件

2. **安装 1.0.0**
   ```bash
   npx ai-godot-mcp install <project-path>
   ```

3. **更新 MCP 配置**
   ```json
   {
     "mcpServers": {
       "godot": {
         "command": "npx",
         "args": ["ai-godot-mcp"]
       }
     }
   }
   ```

4. **启用插件**（Godot 编辑器中）
   - 项目 → 项目设置 → 插件
   - 启用 "AI Godot MCP"

5. **测试连接**
   - 重启 MCP 客户端
   - 验证工具可用

## 兼容性

AI-godot-mcp 1.0.0 仅支持 Godot 4.6.x。  
如果项目使用 Godot 4.0-4.5 或 3.x，需先升级 Godot。

## 新功能

- **场景变更回滚**：测试变更前可创建快照回滚
- **脚本附加**：无需手动创建 .gd 文件
- **场景执行**：在编辑器中运行场景并收集日志

## 问题排查

### 插件未启动
检查 Godot 版本：
```bash
godot --version  # 应显示 v4.6.x
```

### CLI 命令失败
验证项目路径：
```bash
ls /path/to/project/project.godot  # 应存在
```

### WebSocket 连接失败
确认端口 6550 未被占用：
```bash
netstat -an | grep 6550
```
