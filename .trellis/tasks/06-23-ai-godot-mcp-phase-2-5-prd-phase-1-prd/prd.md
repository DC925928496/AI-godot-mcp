# 创建AI-godot-mcp Phase 2-5 PRD并重构Phase 1 PRD

## Goal

将归档的大型Phase 1-5综合PRD拆分成清晰的多阶段文档结构：创建Phase 2-5的独立PRD、一个产品总览PRD，并精简归档的Phase 1 PRD。

## Requirements

### 文档结构

创建以下新PRD文档（位置：`docs/phases/`）：

1. **`product-overview.md`** - 产品总览
   - 产品定位与愿景
   - 完整架构设计（WebSocket通信、Node MCP Server、Godot EditorPlugin）
   - 安全模型（Green/Yellow/Red权限级别）
   - Phase 1-5路线图摘要
   - 与legacy godot-mcp的关系
   - 技术决策（ADR-lite）

2. **`phase-2-scene-mutations.md`** - Phase 2: 场景/节点变更
   - 目标：实现安全的场景写操作
   - 工具列表：`create_scene`, `add_node`, `set_node_property`, `load_resource`, `save_current_scene`, `delete_node`
   - UndoRedo事务模型：`begin_ai_action` / `end_ai_action`
   - Read-before-write原则
   - 验收标准
   - 技术实现细节

3. **`phase-3-script-attachment.md`** - Phase 3: 脚本/资源附加
   - 目标：安全地将脚本附加到节点
   - 工具列表：`attach_script`, `get_resource_uid`
   - GDScript附加验证
   - 资源路径验证
   - 验收标准

4. **`phase-4-scene-execution.md`** - Phase 4: 场景执行与调试
   - 目标：运行场景并捕获输出
   - 工具列表：`play_current_scene`, `stop_running_scene`, 增强的`get_editor_logs`
   - 多步骤工作流回滚
   - 可选的AI操作历史面板
   - 验收标准

5. **`phase-5-packaging.md`** - Phase 5: 打包与分发
   - 目标：npm CLI与发布流程
   - CLI命令：`install`, `uninstall`, `version`
   - Godot 4.6.x验证
   - 插件部署自动化
   - 文档与发布检查清单
   - 验收标准

### 归档PRD修改

修改 `.trellis/tasks/archive/2026-06/06-22-ai-godot-mcp-product/prd.md`：
- 保留Phase 1的完整内容（WebSocket通信、3个只读工具、连接管理）
- 保留简要的Phase 2-5路线图引用（2-3句话每个phase）
- 移除Phase 2-5的详细验收标准、技术细节、工具参数说明
- 添加明确的"详见 docs/phases/phase-X-*.md"引用

### 内容一致性

- 所有新PRD的安全约束必须与product-overview.md一致
- 技术架构描述引用product-overview.md，不重复详细内容
- Phase之间的依赖关系明确（如Phase 2依赖Phase 1的连接基础）

## Acceptance Criteria

- [ ] `docs/phases/` 目录存在且包含5个新PRD文件
- [ ] `product-overview.md` 包含完整架构、安全模型、Phase路线图
- [ ] Phase 2-5的PRD各自聚焦单一阶段，包含明确的验收标准
- [ ] 归档的Phase 1 PRD精简完成，Phase 2-5内容移除
- [ ] 所有PRD的安全约束、架构描述保持一致
- [ ] 每个Phase PRD包含"前置依赖"和"技术实现要点"章节
- [ ] 文档间的交叉引用清晰（如"详见product-overview.md第X节"）

## Definition of Done

- 5个新PRD文件创建完成并提交
- 归档PRD修改完成
- 所有PRD经过一次完整性检查（无遗漏关键信息、无架构冲突）
- README.md更新，添加docs/phases/目录的说明

## Out of Scope

- 实现任何Phase的代码
- 修改现有的代码或配置
- 创建Phase 2-5的任务目录（PRD完成后按需创建）

## Technical Notes

- 参考源：`.trellis/tasks/archive/2026-06/06-22-ai-godot-mcp-product/prd.md`
- 新文档位置：`docs/phases/`
- 目标：为未来Phase实现提供清晰、独立、可执行的需求文档
