# AI-godot-mcp

[![MCP Server](https://badge.mcpx.dev?type=server)](https://modelcontextprotocol.io/introduction)
[![Made with Godot](https://img.shields.io/badge/Made%20with-Godot-478CBF?style=flat&logo=godot%20engine&logoColor=white)](https://godotengine.org)
[![GDScript](https://img.shields.io/badge/GDScript-478CBF?style=flat&logo=godot%20engine&logoColor=white)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
[![Node.js](https://img.shields.io/badge/Node.js-339933?style=flat&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![WebSocket](https://img.shields.io/badge/WebSocket-000000?style=flat&logo=socket.io&logoColor=white)](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
[![License: MIT](https://img.shields.io/badge/License-MIT-red.svg)](https://opensource.org/licenses/MIT)

生产级 Godot MCP 服务，用于 AI 驱动的游戏开发。

> 本项目参考了 [dpeachpeach/godot-mcp](https://github.com/dpeachpeach/godot-mcp)

## 功能特性

### 🔍 项目检查
- **`get_project_context`** - 获取 Godot 版本、项目名称、插件状态
- **`get_scene_tree`** - 获取当前场景节点树（支持深度限制和类型过滤）
- **`get_editor_logs`** - 获取编辑器输出面板日志（支持时间戳和级别过滤）

### 🎨 场景编辑
- **`create_scene`** - 创建新场景文件
- **`add_node`** - 向场景树添加节点，自动解析父节点
- **`set_node_property`** - 修改节点属性，带类型验证
- **`delete_node`** - 删除节点，完整撤销支持
- **`load_resource`** - 加载和引用外部资源
- **`save_current_scene`** - 保存当前场景到磁盘

### ⚡ 事务管理
- **`begin_ai_action` / `end_ai_action`** - 原子批量操作，集成原生 UndoRedo

### 📝 脚本管理
- **`attach_script`** - 附加 GDScript 到节点，自动生成模板
- **`get_resource_uid`** - 获取资源 UID 用于跨引用验证

### ▶️ 场景执行
- **`play_current_scene`** - 在编辑器中运行当前场景（F6）
- **`stop_running_scene`** - 停止运行场景（F8）

### 🛠️ 命令行工具
- **`install`** - 部署插件到 Godot 项目，带版本验证
- **`uninstall`** - 从项目中干净移除插件
- **`version`** - 显示版本和兼容性信息

## 系统要求

- **Godot**: 仅支持 4.6.x
- **Node.js**: ≥20.0.0

## 快速开始

### 安装

```bash
npx ai-godot-mcp install <godot-project-path>
```

### 启用插件

在 Godot 编辑器中：
1. 打开项目
2. **项目 → 项目设置 → 插件**
3. 启用 **"AI Godot MCP"**

### 配置 MCP 客户端

#### Claude Code

```bash
claude mcp add ai-godot-mcp -- npx ai-godot-mcp
```

重启 Claude Code，工具即可使用。

<details>
<summary><strong>其他 MCP 客户端</strong></summary>

对于任意 MCP 兼容客户端，使用以下配置：

```json
{
  "mcpServers": {
    "ai-godot-mcp": {
      "command": "npx",
      "args": ["ai-godot-mcp"]
    }
  }
}
```

</details>

## 架构

AI-godot-mcp 使用 **WebSocket 通信架构**：

- **Node MCP 服务器** (WebSocket 客户端) ↔ **Godot 编辑器插件** (WebSocket 服务器，端口 6550)
- 所有写操作集成 Godot 原生 **UndoRedo** 系统，支持原子事务
- 统一响应格式：`{ok: true, data}` 或 `{ok: false, error: {code, message, suggestions}}`

## 命令行指令

### install

```bash
npx ai-godot-mcp install <project-path>
```

部署插件到 Godot 项目，验证版本兼容性（仅支持 Godot 4.6.x）。

### uninstall

```bash
npx ai-godot-mcp uninstall <project-path>
```

从项目中移除 `addons/ai_godot_mcp/` 目录。

### version

```bash
npx ai-godot-mcp version
```

显示版本信息和支持的 Godot 版本。

## 从源码构建

<details>
<summary>展开查看</summary>

```bash
git clone https://github.com/DC925928496/AI-godot-mcp.git
cd AI-godot-mcp
npm install
npm run build
```

然后在 MCP 客户端配置中指向 `build/index.js` 而不是使用 `npx`。

</details>

## 故障排查

- **Godot 版本不匹配** → 确保使用 Godot 4.6.x（运行 `godot --version` 验证）
- **插件未启用** → 在编辑器中检查 **项目 → 项目设置 → 插件**，确保 "AI Godot MCP" 已勾选
- **WebSocket 连接失败** → 确认插件已启动且端口 6550 未被占用
- **工具调用超时** → 确保 Godot 编辑器正在运行且插件已加载

## 许可证

MIT
