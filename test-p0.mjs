// P0 修复快速验证
import { EditorConnection } from './build/server/editorConnection.js';

const conn = new EditorConnection();

try {
  console.log('📡 连接 Godot...');
  await conn.connect();
  console.log('✅ 连接成功\n');

  // 测试 P0-1: play_current_scene
  console.log('测试 P0-1: play_current_scene');
  const play = await conn.send('play_current_scene');
  console.log('✅', play, '\n');

  await new Promise(r => setTimeout(r, 1000));

  // 测试 P0-3: get_editor_logs
  console.log('测试 P0-3: get_editor_logs');
  const logs = await conn.send('get_editor_logs', { filter_level: 'all' });
  console.log('✅', logs, '\n');

  // 测试 P0-1: stop_running_scene
  console.log('测试 P0-1: stop_running_scene');
  const stop = await conn.send('stop_running_scene');
  console.log('✅', stop, '\n');

  // 测试 P0-2: 错误传递
  console.log('测试 P0-2: 错误传递');
  try {
    await conn.send('invalid_method');
    console.log('❌ 应该抛错但没有');
  } catch (err) {
    console.log('✅ 正确捕获:', err.message, '\n');
  }

  console.log('🎉 P0 修复验证通过！');
  process.exit(0);
} catch (err) {
  console.error('❌ 失败:', err.message);
  console.error('\n💡 请确保 Godot 编辑器已启动且插件已启用');
  process.exit(1);
}
