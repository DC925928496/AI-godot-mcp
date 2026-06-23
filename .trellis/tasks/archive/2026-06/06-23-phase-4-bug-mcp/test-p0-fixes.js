#!/usr/bin/env node
/**
 * P0 修复验证测试
 * 验证：play_current_scene、stop_running_scene、get_editor_logs、错误传递
 */

import { WebSocket } from 'ws';

class TestConnection {
  constructor(port = 6550) {
    this.port = port;
    this.ws = null;
    this.pending = new Map();
    this.nextId = 1;
  }

  async connect() {
    this.ws = new WebSocket(`ws://localhost:${this.port}`);

    this.ws.on('message', (data) => {
      const res = JSON.parse(data.toString());
      const cb = this.pending.get(res.id);
      if (!cb) return;
      this.pending.delete(res.id);

      if (res.ok) {
        cb.resolve(res.data);
      } else {
        cb.reject(new Error(res.error?.message || 'Unknown error'));
      }
    });

    await new Promise((ok, fail) => {
      this.ws.once('open', ok);
      this.ws.once('error', fail);
    });
  }

  async send(method, params = {}) {
    const id = (this.nextId++).toString();
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  close() {
    this.ws?.close();
  }
}

async function runTests() {
  console.log('🧪 开始 P0 修复验证测试\n');

  const conn = new TestConnection();

  try {
    console.log('📡 连接到 Godot WebSocket 服务器...');
    await conn.connect();
    console.log('✅ 连接成功\n');

    // 测试 1: get_project_context（基线测试）
    console.log('测试 1: get_project_context (基线)');
    try {
      const ctx = await conn.send('get_project_context');
      console.log('✅ 通过:', JSON.stringify(ctx, null, 2));
    } catch (err) {
      console.error('❌ 失败:', err.message);
    }
    console.log('');

    // 测试 2: play_current_scene
    console.log('测试 2: play_current_scene (P0-1)');
    try {
      const result = await conn.send('play_current_scene');
      console.log('✅ 通过:', JSON.stringify(result, null, 2));
    } catch (err) {
      console.error('❌ 失败:', err.message);
    }
    console.log('');

    // 等待场景运行
    await new Promise(resolve => setTimeout(resolve, 2000));

    // 测试 3: get_editor_logs
    console.log('测试 3: get_editor_logs (P0-3)');
    try {
      const logs = await conn.send('get_editor_logs', { filter_level: 'all' });
      console.log('✅ 通过:', JSON.stringify(logs, null, 2));
      if (logs.logs && logs.logs.length > 0) {
        console.log('✅ 日志捕获正常工作');
      } else {
        console.warn('⚠️  日志为空（可能需要触发更多编辑器操作）');
      }
    } catch (err) {
      console.error('❌ 失败:', err.message);
    }
    console.log('');

    // 测试 4: stop_running_scene
    console.log('测试 4: stop_running_scene (P0-1)');
    try {
      const result = await conn.send('stop_running_scene');
      console.log('✅ 通过:', JSON.stringify(result, null, 2));
    } catch (err) {
      console.error('❌ 失败:', err.message);
    }
    console.log('');

    // 测试 5: 错误传递测试 (P0-2)
    console.log('测试 5: 错误传递 (P0-2)');
    try {
      await conn.send('invalid_method_name');
      console.error('❌ 失败: 应该抛出错误但没有');
    } catch (err) {
      console.log('✅ 通过: 正确捕获错误 -', err.message);
    }
    console.log('');

    console.log('🎉 P0 修复验证完成！');

  } catch (err) {
    console.error('❌ 测试失败:', err.message);
    console.error('\n💡 请确保：');
    console.error('   1. Godot 编辑器已启动');
    console.error('   2. AI-godot-mcp 插件已启用');
    console.error('   3. WebSocket 服务器运行在 6550 端口');
  } finally {
    conn.close();
  }
}

runTests();
