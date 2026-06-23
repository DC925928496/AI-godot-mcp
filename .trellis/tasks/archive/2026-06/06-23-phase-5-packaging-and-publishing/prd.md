# Phase 5：打包与发布

## 目标

实现npm CLI工具，支持插件自动安装到Godot项目，准备1.0.0正式发布。

## 背景

前4个Phase已完成核心功能：
- Phase 1: 基础工具（get/set/call/list）
- Phase 2: 场景变更和事务回滚
- Phase 3: 脚本附加
- Phase 4: 场景执行和日志

Phase 5聚焦用户体验：通过CLI简化插件安装，验证Godot版本兼容性，准备npm发布。

## 核心功能

### 1. CLI命令

#### `install <project-path>`
- 验证Godot版本（仅支持4.6.x）
- 验证目标路径存在`project.godot`
- 复制`addons/ai_godot_mcp/`到目标项目
- 显示启用插件的步骤

#### `uninstall <project-path>`
- 删除目标项目的`addons/ai_godot_mcp/`

#### `version`
- 显示版本号、支持的Godot版本、仓库链接

### 2. Godot 4.6.x验证

**方法1：执行`godot --version`**
- 解析输出匹配`v4.6.x`
- 失败时提示Godot未安装或版本不兼容

**方法2：读取`project.godot`**
```ini
config_version=5
features=PackedStringArray("4.6", ...)
```

**拒绝逻辑**：
- Godot 3.x → 错误提示"仅支持4.6.x"
- Godot 4.0-4.5 → 提示升级到4.6.x

### 3. 插件部署

复制文件：
- `plugin.cfg`
- `plugin.gd`
- `websocket_server.gd`
- 其他`.gd`文件

不复制：`.gitkeep`、测试文件

### 4. 发布准备

**文档**：
- README.md：安装步骤、快速开始、破坏性变更通知
- docs/MIGRATION.md：从legacy 0.1.1迁移指南
- CHANGELOG.md：v1.0.0发布说明

**npm发布**：
- 包名：`ai-godot-mcp`
- version：1.0.0
- `bin`字段指向CLI入口
- `files`包含：`build/`、`addons/`、`bin/`

**GitHub Release**：
- Tag: v1.0.0
- 附件：npm包tgz、plugin-only.zip

## 技术方案

### CLI架构

```
bin/cli.js (#!/usr/bin/env node)
  ↓
src/cli/
  ├── install.ts
  ├── uninstall.ts
  ├── version.ts
  └── validate.ts (Godot版本检测)
```

使用`commander`解析命令，`fs-extra`复制文件。

### package.json调整

```json
{
  "bin": {
    "ai-godot-mcp": "./bin/cli.js"
  },
  "files": ["build", "addons", "bin"],
  "scripts": {
    "build": "tsc && npm run bundle-addon",
    "bundle-addon": "cp -r addons build/",
    "prepublishOnly": "npm run build && npm test"
  }
}
```

### 版本检测伪代码

```typescript
async function validateGodotVersion(projectPath: string): Promise<void> {
  // 方法1: 执行godot --version
  try {
    const output = execSync('godot --version', { encoding: 'utf-8' });
    if (!/v4\.6\.\d+/.test(output)) {
      throw new Error('需要Godot 4.6.x');
    }
    return;
  } catch {}
  
  // 方法2: 读取project.godot
  const cfg = fs.readFileSync(path.join(projectPath, 'project.godot'), 'utf-8');
  if (!cfg.includes('"4.6"')) {
    throw new Error('需要Godot 4.6.x');
  }
}
```

## MVP范围

**包含**：
- CLI三个命令（install/uninstall/version）
- Godot 4.6.x验证
- README、MIGRATION、CHANGELOG
- npm发布准备（不实际发布）

**不包含**：
- 交互式安装（询问路径）
- 自动编辑`project.godot`启用插件
- Godot AssetLib提交

## 验收标准

- [ ] `npx ai-godot-mcp install <path>` 成功复制插件
- [ ] 拒绝Godot 4.5.x项目，显示清晰错误
- [ ] `uninstall`移除插件目录
- [ ] `version`显示正确信息
- [ ] README包含安装、快速开始、破坏性变更
- [ ] MIGRATION.md完整
- [ ] package.json配置正确，`npm pack`生成可用包

## 风险

1. **Godot未在PATH** → 回退到读取project.godot
2. **Windows路径问题** → 使用`path.join`和`fs-extra`处理
3. **npm包名冲突** → 提前检查npmjs.com可用性

## 参考

- 完整需求：`docs/phases/phase-5-packaging.md`
- Legacy项目：`E:/code/godot-mcp`（不兼容）
