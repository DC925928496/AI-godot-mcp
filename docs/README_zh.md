# AI-godot-mcp

[![MCP Server](https://badge.mcpx.dev?type=server)](https://modelcontextprotocol.io/introduction)
[![Made with Godot](https://img.shields.io/badge/Made%20with-Godot-478CBF?style=flat&logo=godot%20engine&logoColor=white)](https://godotengine.org)
[![GDScript](https://img.shields.io/badge/GDScript-478CBF?style=flat&logo=godot%20engine&logoColor=white)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
[![Node.js](https://img.shields.io/badge/Node.js-339933?style=flat&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![WebSocket](https://img.shields.io/badge/WebSocket-000000?style=flat&logo=socket.io&logoColor=white)](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
[![License: MIT](https://img.shields.io/badge/License-MIT-red.svg)](https://opensource.org/licenses/MIT)

生产级 Godot MCP 服务，用于 AI 驱动的游戏开发。

> 本项目参考了 [dpeachpeach/godot-mcp](https://github.com/dpeachpeach/godot-mcp)

## 愿景

AI-godot-mcp 的目标不只是做一个 Godot 编辑器自动化桥，而是让普通人也能借助 Codex 等智能体，配合本项目和 Godot 编辑器，完成真正的游戏开发。

长期来看，项目不是要把“怎么做一个战棋框架、怎么搭一个平台跳跃原型”这类思考写死在 MCP 里，而是要提供一层可靠的 Godot 执行能力：由智能体负责规划和推理，由 AI-godot-mcp 负责安全地检查、修改、运行和观测编辑器。

## 接下来的方向

当前仓库已经具备底层 MCP 桥接能力，接下来要做的是把它打磨成更适合 Codex 这类智能体调用的 Godot 执行底座：

- 保持“工作流智能在智能体侧、执行能力在 MCP 侧”的边界，同时把 MCP 能力面扩展得更完整、更可组合
- 强化观察与修复闭环，补齐更清晰的编辑器状态、操作历史和运行反馈
- 降低新手启动门槛，提供 starter template、示例项目和更适合智能体接管的说明文档
- 扩展真实游戏开发能力边界，优先覆盖信号连接、输入映射、场景实例化、autoload 和常见 UI 流程

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
