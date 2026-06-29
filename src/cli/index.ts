import { program } from 'commander';
import { startServer } from '../server/startServer.js';
import { install } from './install.js';
import { uninstall } from './uninstall.js';
import { version } from './version.js';
import { shouldStartMcpServer } from './mode.js';

program
  .name('ai-godot-mcp')
  .description('Production-grade Godot MCP service for AI-driven game development');

program
  .command('install <project-path>')
  .description('Install plugin to Godot project')
  .action(install);

program
  .command('uninstall <project-path>')
  .description('Remove plugin from project')
  .action(uninstall);

program
  .command('version')
  .description('Show version info')
  .action(version);

if (shouldStartMcpServer(process.argv)) {
  await startServer();
} else {
  program.parse();
}
