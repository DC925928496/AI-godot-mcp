# 文档同步：更新PRD和README反映完整5阶段完成状态

## 目标

同步项目文档以反映所有5个开发阶段（Phase 1-5）已全部完成的事实，参考 legacy godot-mcp 的 README 结构改进当前 README。

## 背景

- 所有5个开发阶段已完成并归档（2026-06-23）
- 主 PRD 中的验收标准仍停留在 Phase 1 完成状态
- 当前 README 在 Phase 5 时更新过，但结构较简单，缺少：
  - 徽章（badges）和视觉元素
  - 详细的 MCP 工具列表
  - 不同 MCP 客户端的配置示例
  - 架构说明

## 需要更新的文档

### 1. 主 PRD（保持在当前位置）

文件：`.trellis/tasks/archive/2026-06/06-22-ai-godot-mcp-product/prd.md`

**更新内容**：
- ✅ 将 Phase 2-5 的验收标准标记为已完成
- ✅ 添加完成日期和关键提交记录
- ✅ 更新 Definition of Done 章节

### 2. README.md

参考 legacy `E:/code/godot-mcp/README.md` 的结构，改进当前 README：

**保留的部分**：
- ⚠️ 重大变更提示（Godot 4.6.x only）
- 快速安装命令（`npx ai-godot-mcp install`）
- 迁移指南链接
- MIT 许可证

**新增/改进的部分**：
1. **徽章区域**：
   - MCP Server 徽章
   - Godot / Node.js / TypeScript 技术栈徽章
   - GitHub stars/forks/license 徽章（适配新仓库）

2. **功能特性章节**：
   - 完整的 MCP 工具列表（按 Phase 分类）
   - Phase 1: `get_project_context`, `get_scene_tree`, `get_editor_logs`
   - Phase 2: `create_scene`, `add_node`, `set_node_property`, `delete_node`, `load_resource`, `save_current_scene`
   - Phase 2: `begin_ai_action`, `commit_ai_action`, `rollback_ai_action`
   - Phase 3: `attach_script`, `get_resource_uid`
   - Phase 4: `play_current_scene`, `stop_running_scene`
   - Phase 5: CLI 工具（`install`, `uninstall`, `version`）

3. **快速开始章节**（参考 legacy）：
   - Claude Code 配置示例
   - 其他 MCP 客户端配置示例（折叠）
   - 环境变量说明（如果有）

4. **架构说明**：
   - WebSocket 通信架构（Node MCP 客户端 ↔ Godot 插件服务端）
   - 端口 6550
   - 事务回滚机制（UndoRedo）

5. **从源码构建**（折叠）：
   ```bash
   git clone https://github.com/DC925928496/AI-godot-mcp.git
   cd AI-godot-mcp
   npm install
   npm run build
   ```

6. **故障排查**：
   - Godot 版本不匹配
   - 插件未启用
   - WebSocket 连接失败

## 不包含的内容

- ❌ 不移动主 PRD 到根目录（用户明确要求保持位置）
- ❌ 不更新 `.trellis/spec/`（现有规范已足够）
- ❌ 不添加 ASCII art（保持简洁）
- ❌ 不修改 CHANGELOG.md 和 MIGRATION.md（已在 Phase 5 完成）

## 技术方案

### 主 PRD 更新

在验收标准部分标记 Phase 2-5 已完成：

```markdown
### Phase 2 Criteria ✅ **COMPLETED** (2026-06-23, commit 172eaa7)
### Phase 3 Criteria ✅ **COMPLETED** (2026-06-23, commit e065af4)
### Phase 4 Criteria ✅ **COMPLETED** (2026-06-23, commit a1ae699)
### Phase 5 Criteria ✅ **COMPLETED** (2026-06-23, commit 62cb364)
```

### README 结构

```markdown
# AI-godot-mcp

[徽章区域]

[一句话描述]

⚠️ **重大变更** ...

## Features (核心特性)

### Phase 1: 基础读取工具
- `get_project_context`
- ...

### Phase 2: 场景编辑和事务
- 6个写操作工具
- UndoRedo 事务支持

### Phase 3-5 ...

## Requirements

- Godot: 4.6.x only
- Node.js: >=18.0.0

## Quick Start

### Installation
```bash
npx ai-godot-mcp install <project-path>
```

### Enable Plugin (in Godot Editor)
...

### Configure MCP Client

#### Claude Code
```bash
claude mcp add ai-godot-mcp -- npx ai-godot-mcp
```

<details><summary>Other Clients</summary>
...
</details>

## Architecture

[WebSocket 架构说明]

## CLI Commands

### install / uninstall / version

## Building from Source

<details>
...
</details>

## Troubleshooting

## License

MIT
```

## 验收标准

- [ ] 主 PRD 的 Phase 2-5 验收标准标记为已完成
- [ ] 主 PRD 添加了完成日期和提交记录
- [ ] README 添加了徽章区域（至少包含 MCP Server, Godot, Node.js 徽章）
- [ ] README 包含完整的 MCP 工具列表（按 Phase 分组）
- [ ] README 包含 Claude Code 配置示例
- [ ] README 包含其他 MCP 客户端配置示例（折叠）
- [ ] README 包含架构说明（WebSocket, port 6550）
- [ ] README 包含从源码构建步骤（折叠）
- [ ] README 包含故障排查章节
- [ ] 所有外部链接可访问（GitHub 仓库链接等）
- [ ] 文档语言风格统一（中英混排，技术术语用英文）

## 风险

1. **徽章链接失效** → 使用 shields.io 标准格式
2. **GitHub 仓库信息不确定** → 从 git remote 读取实际 URL
3. **工具列表遗漏** → 从 `src/server/createServer.ts` 读取工具注册代码确认

## 参考

- Legacy README: `E:/code/godot-mcp/README.md`
- 主 PRD: `.trellis/tasks/archive/2026-06/06-22-ai-godot-mcp-product/prd.md`
- Phase 5 README 更新: commit 62cb364
- MCP 工具定义: `src/server/createServer.ts`
