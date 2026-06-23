import { rmSync, existsSync } from 'fs';
import { join } from 'path';

export function uninstall(projectPath: string): void {
  try {
    const targetAddon = join(projectPath, 'addons/ai_godot_mcp');

    if (!existsSync(targetAddon)) {
      console.log('插件未安装，无需卸载');
      return;
    }

    rmSync(targetAddon, { recursive: true, force: true });
    console.log(`✓ 插件已从项目中移除: ${targetAddon}`);
    console.log('\n如果 Godot 编辑器正在运行，请手动禁用插件');
  } catch (err: any) {
    console.error(`错误: ${err.message}`);
    process.exit(1);
  }
}
