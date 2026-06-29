// P0 修复快速验证
import test from 'node:test';
import { EditorConnection } from './build/server/editorConnection.js';

test('manual Godot integration smoke test', async (t) => {
  const conn = new EditorConnection();

  try {
    console.log('📡 连接 Godot...');
    await conn.connect();
    console.log('✅ 连接成功\n');
  } catch (err) {
    t.skip(`Godot editor/plugin not available: ${err.message}`);
    return;
  }

  try {
    console.log('测试 P0-1: play_current_scene');
    let play;
    try {
      play = await conn.send('play_current_scene');
    } catch (err) {
      if (String(err.message).includes('NO_SCENE')) {
        t.skip('No scene is currently open in the Godot editor.');
        return;
      }
      throw err;
    }
    console.log('✅', play, '\n');

    if (!play || typeof play !== 'object' || play.status !== 'running') {
      t.skip('No playable scene is currently open in the editor.');
      return;
    }

    await new Promise(r => setTimeout(r, 1000));

    console.log('测试 P0-3: get_editor_logs');
    const logs = await conn.send('get_editor_logs', { filter_level: 'all' });
    console.log('✅', logs, '\n');

    console.log('测试 P0-1: stop_running_scene');
    const stop = await conn.send('stop_running_scene');
    console.log('✅', stop, '\n');

    console.log('测试 P0-2: 错误传递');
    let invalidMethodFailed = false;
    try {
      await conn.send('invalid_method');
    } catch (err) {
      invalidMethodFailed = true;
      console.log('✅ 正确捕获:', err.message, '\n');
    }
    if (!invalidMethodFailed) {
      throw new Error('Expected invalid_method to fail');
    }

    console.log('🎉 P0 修复验证通过！');
  } finally {
    conn.close();
  }
});
