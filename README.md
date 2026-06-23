# AI-godot-mcp

Production-grade Godot MCP service for AI-driven game development.

⚠️ **重大变更**  
AI-godot-mcp 仅支持 Godot 4.6.x，与 legacy godot-mcp 0.1.1 不兼容。  
迁移指南：[docs/MIGRATION.md](docs/MIGRATION.md)

## 安装

```bash
npx ai-godot-mcp install <godot-project-path>
```

## 快速开始

1. **安装插件**
   ```bash
   npx ai-godot-mcp install /path/to/your/godot/project
   ```

2. **启用插件**（在 Godot 编辑器中）
   - 打开项目
   - 项目 → 项目设置 → 插件
   - 启用 "AI Godot MCP"

3. **配置 MCP**
   插件将在端口 6550 启动 WebSocket 服务器，可在 Claude Desktop 等 MCP 客户端中连接。

## 命令

### install
```bash
npx ai-godot-mcp install <project-path>
```
部署插件到 Godot 项目，验证版本兼容性。

### uninstall
```bash
npx ai-godot-mcp uninstall <project-path>
```
从项目中移除插件。

### version
```bash
npx ai-godot-mcp version
```
显示版本信息和支持的 Godot 版本。

## 功能特性

- **节点操作**：获取/设置属性、调用方法、列出节点树
- **场景变更**：支持事务回滚的场景修改
- **脚本附加**：动态附加 GDScript 到节点
- **场景执行**：在编辑器中执行场景并收集日志

## 版本要求

- **Godot**: 4.6.x only
- **Node.js**: ≥18.0.0

## 与 Legacy 项目的关系

AI-godot-mcp 是新产品线，架构完全重写。  
Legacy godot-mcp 不再维护。

## 许可证

MIT
