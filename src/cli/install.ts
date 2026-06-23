import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, statSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { validateGodotProject, validateGodotVersion } from './validate.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

export function install(projectPath: string): void {
  try {
    validateGodotProject(projectPath);
    validateGodotVersion(projectPath);

    const sourceAddon = join(__dirname, '../../addons/ai_godot_mcp');
    const targetAddon = join(projectPath, 'addons/ai_godot_mcp');

    if (!existsSync(sourceAddon)) {
      throw new Error('插件源码未找到，请检查安装包完整性');
    }

    cpSync(sourceAddon, targetAddon, { recursive: true });

    console.log(`✓ 插件已安装到: ${targetAddon}\n`);
    console.log('下一步（在 Godot 编辑器中）：');
    console.log('1. 打开项目');
    console.log('2. 项目 → 项目设置 → 插件');
    console.log('3. 启用 "AI Godot MCP"');
    console.log('4. 插件将在端口 6550 启动 WebSocket 服务器');
  } catch (err: any) {
    console.error(`错误: ${err.message}`);
    process.exit(1);
  }
}
