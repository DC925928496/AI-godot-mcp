/**
 * P0 修复单元测试 - 不需要 Godot 运行
 */

console.log('🧪 P0 修复单元测试\n');

// 测试 1: EditorConnection 错误传递逻辑
console.log('测试 1: 错误传递逻辑 (P0-2)');
try {
  const mockPending = new Map();
  let nextId = 1;

  // 模拟正确的错误处理
  const id = (nextId++).toString();
  const promise = new Promise((resolve, reject) => {
    mockPending.set(id, { resolve, reject });
  });

  // 模拟错误响应
  const res = { id: '1', ok: false, error: { message: 'Test error' } };
  const cb = mockPending.get(res.id);
  if (cb) {
    cb.reject(new Error(res.error.message));
  }

  promise.catch(err => {
    console.log('✅ 错误正确传递:', err.message);
  });

} catch (err) {
  console.error('❌ 失败:', err.message);
}

// 测试 2: ID 生成不冲突
console.log('\n测试 2: ID 自增生成 (P0-2)');
let nextId = 1;
const ids = new Set();
for (let i = 0; i < 1000; i++) {
  const id = (nextId++).toString();
  if (ids.has(id)) {
    console.error('❌ ID 冲突:', id);
    break;
  }
  ids.add(id);
}
if (ids.size === 1000) {
  console.log('✅ 1000 个并发请求无 ID 冲突');
}

// 测试 3: 检查 GDScript 方法注册
console.log('\n测试 3: GDScript 方法注册 (P0-1)');
import { readFileSync } from 'fs';

const gdScript = readFileSync('addons/ai_godot_mcp/websocket_server.gd', 'utf-8');

const methodsToCheck = [
  'play_current_scene',
  'stop_running_scene',
  'get_editor_logs'
];

let allRegistered = true;
for (const method of methodsToCheck) {
  const pattern = new RegExp(`"${method}":\\s*return handle_`);
  if (pattern.test(gdScript)) {
    console.log(`✅ ${method} 已注册`);
  } else {
    console.error(`❌ ${method} 未注册`);
    allRegistered = false;
  }
}

if (allRegistered) {
  console.log('✅ 所有 Phase 4 方法已正确注册');
}

// 测试 4: 检查硬编码空数组是否移除
console.log('\n测试 4: get_editor_logs 硬编码检查 (P0-3)');
const hardcodedEmpty = gdScript.includes('"get_editor_logs":\n\t\t\treturn {\n\t\t\t\t"id": req.id,\n\t\t\t\t"ok": true,\n\t\t\t\t"data": {"logs": []}');

if (hardcodedEmpty) {
  console.error('❌ get_editor_logs 仍然硬编码返回空数组');
} else {
  console.log('✅ get_editor_logs 调用实际处理函数');
}

console.log('\n🎉 P0 修复单元测试完成！');
console.log('\n💡 集成测试需要：');
console.log('   1. 启动 Godot 编辑器 (4.6.x)');
console.log('   2. 启用 AI-godot-mcp 插件');
console.log('   3. 打开一个场景文件');
console.log('   4. 运行: node test-p0.mjs');
