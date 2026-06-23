import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

export function version(): void {
  const pkg = JSON.parse(readFileSync(join(__dirname, '../../package.json'), 'utf-8'));
  console.log(`AI-godot-mcp v${pkg.version}`);
  console.log('Supports: Godot 4.6.x only');
  console.log('Repository: https://github.com/DC925928496/AI-godot-mcp');
}
