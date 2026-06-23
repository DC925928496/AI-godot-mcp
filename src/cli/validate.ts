import { execSync } from 'child_process';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

export function validateGodotProject(projectPath: string): void {
  const projectFile = join(projectPath, 'project.godot');
  if (!existsSync(projectFile)) {
    throw new Error(`未找到 project.godot，路径无效: ${projectPath}`);
  }
}

export function validateGodotVersion(projectPath: string): void {
  // 方法1: 执行godot --version
  try {
    const output = execSync('godot --version', { encoding: 'utf-8', stdio: ['ignore', 'pipe', 'ignore'] });
    if (!/v4\.6\.\d+/.test(output)) {
      throw new Error(`需要 Godot 4.6.x，当前检测到: ${output.trim()}\nAI-godot-mcp 不支持 Godot 4.0-4.5 或 3.x`);
    }
    return;
  } catch (err: any) {
    if (err.message.includes('需要 Godot')) throw err;
    // godot命令不存在，回退到方法2
  }

  // 方法2: 读取project.godot
  const projectFile = join(projectPath, 'project.godot');
  const content = readFileSync(projectFile, 'utf-8');

  if (content.includes('config_version=4') || !content.includes('config_version=5')) {
    throw new Error('检测到 Godot 3.x 项目\nAI-godot-mcp 仅支持 Godot 4.6.x');
  }

  if (!content.includes('"4.6"')) {
    const match = content.match(/"4\.(\d+)"/);
    if (match) {
      throw new Error(`检测到 Godot 4.${match[1]}.x\nAI-godot-mcp 需要 4.6.x 的编辑器 API\n请升级 Godot 到 4.6.x: https://godotengine.org/download/`);
    }
    throw new Error('无法检测 Godot 版本，请确认项目有效');
  }
}
