# Phase 5：打包与发布

## 目标

通过 npm CLI 实现插件自动安装，发布独立包名产品。

## 前置依赖

- **依赖 Phase 1-4**：完整功能实现

## CLI 命令

### `install`
验证环境并部署插件。

**用法**：
```bash
npx ai-godot-mcp install <godot-project-path>
```

**流程**：
1. 检测 Godot 4.6.x 安装（扫描常见路径或读取环境变量）
2. 验证目标路径为有效 Godot 项目（存在 `project.godot`）
3. 复制 `addons/ai_godot_mcp/` 到目标项目 `addons/` 目录
4. 提示用户启用插件：
   ```
   插件已安装到：<project>/addons/ai_godot_mcp/
   
   下一步（在 Godot 编辑器中）：
   1. 打开项目
   2. 项目 → 项目设置 → 插件
   3. 启用 "AI Godot MCP"
   4. 插件将在端口 6550 启动 WebSocket 服务器
   ```

**验证逻辑**：
- Godot 版本检查：
  ```bash
  godot --version
  # 预期：v4.6.x.stable.official
  ```
- 拒绝非 4.6.x 版本：
  ```
  错误：需要 Godot 4.6.x，当前检测到 v4.5.3
  AI-godot-mcp 不支持 Godot 4.0-4.5 或 3.x
  ```

### `uninstall`
移除插件。

**用法**：
```bash
npx ai-godot-mcp uninstall <godot-project-path>
```

**流程**：
1. 删除 `<project>/addons/ai_godot_mcp/` 目录
2. 提示用户在编辑器中禁用插件（如编辑器正在运行）

### `version`
显示版本信息。

**用法**：
```bash
npx ai-godot-mcp version
```

**输出**：
```
AI-godot-mcp v1.0.0
Supports: Godot 4.6.x only
Repository: https://github.com/DC925928496/AI-godot-mcp
```

## Godot 4.6.x 验证逻辑

### 版本检测

**方法 1：执行 `godot --version`**
```javascript
const { execSync } = require('child_process');
try {
  const output = execSync('godot --version', { encoding: 'utf-8' });
  const match = output.match(/v4\.6\.\d+/);
  if (!match) {
    throw new Error('Godot 4.6.x required');
  }
} catch (error) {
  console.error('Godot not found or version incompatible');
}
```

**方法 2：读取项目 `project.godot`**
```ini
config_version=5  ; Godot 4.x
features=PackedStringArray("4.6", "Forward Plus")
```
- `config_version=5` 表示 Godot 4.x
- `features` 包含 `"4.6"`

### 拒绝场景

**Godot 3.x**：
```
错误：检测到 Godot 3.x 项目
AI-godot-mcp 仅支持 Godot 4.6.x
```

**Godot 4.0-4.5**：
```
错误：检测到 Godot 4.5.x
AI-godot-mcp 需要 4.6.x 的编辑器 API
请升级 Godot 到 4.6.x：https://godotengine.org/download/
```

## 插件自动部署

### 目录结构

**CLI 包**：
```
ai-godot-mcp/
├── bin/
│   └── cli.js         # 入口脚本
├── src/
│   └── index.ts       # MCP 服务器
├── addons/
│   └── ai_godot_mcp/  # 插件源码（打包时包含）
│       ├── plugin.cfg
│       ├── plugin.gd
│       └── websocket_server.gd
└── package.json
```

**部署逻辑**（伪代码）：
```javascript
const fs = require('fs-extra');
const path = require('path');

async function install(targetProject) {
  const sourceAddon = path.join(__dirname, '../addons/ai_godot_mcp');
  const targetAddon = path.join(targetProject, 'addons/ai_godot_mcp');
  
  await fs.copy(sourceAddon, targetAddon);
  console.log(`✓ 插件已复制到 ${targetAddon}`);
}
```

### 文件清单

复制的文件：
- `plugin.cfg`（插件元数据）
- `plugin.gd`（主插件类）
- `websocket_server.gd`（WebSocket 服务器）
- `*.gd`（其他 GDScript 文件）

不复制：
- `.gitkeep`
- 测试文件（如有）

## 文档与发布检查清单

### README.md
- [ ] 产品简介（1 段）
- [ ] 安装步骤（CLI 命令）
- [ ] 快速开始（3 步：安装 → 启用插件 → 配置 MCP）
- [ ] 破坏性变更通知：
  ```
  ⚠️ 重大变更
  AI-godot-mcp 仅支持 Godot 4.6.x，与 legacy godot-mcp 0.1.1 不兼容。
  迁移指南：docs/MIGRATION.md
  ```
- [ ] 与 legacy 项目的关系：
  ```
  AI-godot-mcp 是新产品线，架构完全重写。
  Legacy godot-mcp (E:/code/godot-mcp) 不再维护。
  ```

### docs/MIGRATION.md
- [ ] Legacy 0.1.1 → 1.0.0 迁移步骤
- [ ] API 变更清单（工具名称、参数格式）
- [ ] 架构变更（无头脚本 → EditorPlugin）

### CHANGELOG.md
- [ ] v1.0.0 首个发布说明
- [ ] Phase 1-5 功能清单

### GitHub Release
- [ ] Tag: `v1.0.0`
- [ ] 发布说明（复制 CHANGELOG）
- [ ] 附件：
  - `ai-godot-mcp-1.0.0.tgz`（npm 包）
  - `plugin-only.zip`（仅插件，手动安装备份）

### npm 发布

**包名**（非 `@coding-solo/godot-mcp`）：
- 建议：`ai-godot-mcp`（如可用）
- 备选：`godot-mcp-ai`, `godot-ai-mcp`

**package.json 关键字段**：
```json
{
  "name": "ai-godot-mcp",
  "version": "1.0.0",
  "description": "Production-grade Godot MCP service for AI-driven game development",
  "bin": {
    "ai-godot-mcp": "./bin/cli.js"
  },
  "keywords": ["godot", "mcp", "ai", "game-development"],
  "engines": {
    "node": ">=18.0.0"
  },
  "files": [
    "dist/",
    "addons/",
    "bin/"
  ]
}
```

## 验收标准

- [ ] CLI `install` 命令成功部署插件到测试项目
- [ ] Godot 4.6.x 验证通过
- [ ] Godot 4.5.x 被拒绝并显示清晰错误
- [ ] `uninstall` 命令成功移除插件
- [ ] `version` 命令显示版本和支持信息
- [ ] README 包含安装、快速开始、破坏性变更通知
- [ ] docs/MIGRATION.md 完整
- [ ] npm 包发布到 npmjs.com（或私有 registry）
- [ ] GitHub Releases 包含 v1.0.0 tag 和附件

## 备份发布方式

### GitHub Releases 手动下载

用户可下载：
1. **完整 npm 包**：`ai-godot-mcp-1.0.0.tgz`
   - 解压后 `npm install -g ./ai-godot-mcp-1.0.0.tgz`
2. **仅插件包**：`plugin-only.zip`
   - 手动解压到项目 `addons/` 目录

### AssetLib（非 MVP）

未来考虑：
- Godot AssetLib 提交插件
- 需符合 AssetLib 质量标准
- Phase 5 不强制要求

## 技术实现要点

### CLI 入口（bin/cli.js）
```javascript
#!/usr/bin/env node
const { program } = require('commander');

program
  .command('install <project-path>')
  .description('Install plugin to Godot project')
  .action(require('../dist/cli/install'));

program
  .command('uninstall <project-path>')
  .description('Remove plugin from project')
  .action(require('../dist/cli/uninstall'));

program
  .command('version')
  .description('Show version info')
  .action(() => {
    console.log(`AI-godot-mcp v${require('../package.json').version}`);
  });

program.parse();
```

### Godot 版本检测
- 优先尝试 `godot --version`
- 回退到读取 `project.godot` 的 `features` 字段

### 打包脚本
```json
{
  "scripts": {
    "build": "tsc && npm run bundle-addon",
    "bundle-addon": "cp -r addons dist/",
    "prepublishOnly": "npm run build && npm test"
  }
}
```

## 未来扩展

- 交互式安装（询问项目路径而非命令行参数）
- 多项目管理（记住已安装项目）
- 自动启用插件（编辑 `project.godot` 的 `enabled_plugins`）

详见 `docs/phases/product-overview.md` 第 5 节。
