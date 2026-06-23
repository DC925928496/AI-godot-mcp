# 修复 README 中 Node.js 版本要求不一致

## 问题

README 和 package.json 中的 Node.js 版本要求不一致：
- README: `≥18.0.0`
- package.json: `>=20.0.0`

这会误导用户，可能导致 Node 18/19 用户尝试安装时失败。

## 解决方案

修改 README 文件（英文和中文版本）将 Node.js 要求统一为 `≥20.0.0`，与 package.json 保持一致。

选择此方案的原因：
- Node 18 已接近 EOL
- package.json 已定义 `>=20.0.0`，代码可能依赖 Node 20 特性
- 更改文档比更改代码依赖更安全

## 影响范围

- `README.md`
- `docs/README_zh.md`

## 验证

- [x] 两个 README 文件中的 Node.js 版本要求已更新为 `≥20.0.0`
- [x] 与 package.json 中的 engines.node 字段一致
