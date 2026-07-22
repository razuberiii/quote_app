# Rubusoo 产品闭环与视觉收敛计划

## 1. Context and Goal
- Project/area: 全站 i18n、AI 导入、报价体验、导航入口与遗留清理。
- Why now: 老项目迁移留下硬编码文案、重复模型关系和多代样式；新商业流程已有基础但入口与确认闭环不完整。
- Target outcome: 中文优先的统一产品；所有 AI 导入严格输出结构化 JSON，未知字段留空，并经二级确认后写入。
- Out of scope: 更换 AI 供应商、计费系统重构、历史迁移重写。
- Business value / success metric: 用户可从公司资料、产品目录、询盘一路完成报价、发布、买家确认和成交文档。
- Delivery deadline (if any): 本轮持续交付。

## 2. Current Problems
- Problem A: 前端仍存在大量硬编码英文/中文，无法由 locale 统一控制。
- Problem B: 产品导入已有审核链路，公司资料缺少对应的 AI 分析与二级确认入口。
- Problem C: 营销 Hero 与应用页存在多代 CSS 和老项目残留，视觉与交互入口不完全统一。
- Existing workaround and why it is insufficient: 用户手填公司资料或依赖零散入口；无法形成可审计、可确认的导入闭环。

## 3. Scope and Constraints
- Scope (explicit pages/modules/files): routes、Company/AI schema 与服务、公司设置、Library/产品导入、Landing/Quote Hero、共享导航、中文 locale、同作用域 CSS、测试与文档。
- Business logic policy (allowed / not allowed): 允许新增确认态持久化；禁止 AI 直接写 Company/Product/Quote，禁止猜测价格、运费和缺失事实。
- Visual/UX policy: 复用 Rubusoo Neo Commerce OS 与既有 `button`/`field`/导入类族，清理同域冲突规则。
- Risk boundaries: 不删除仍被路由、模型或视图引用的业务代码；不改历史迁移。
- Non-negotiable constraints (performance/compliance/compatibility): 严格 JSON Schema、公司隔离、失败可降级、移动端可用、reduced-motion。

## 4. Execution Roadmap

### Phase 1 - 导入闭环
Status: `Completed`

Goals (outcome):
- 公司资料、产品目录与询盘均有入口、结构化分析和人工确认边界。

Implementation actions (must be executable):
- [x] 新增公司资料导入的 source、analysis、review、apply 流程。
- [x] 收敛产品导入硬编码提示并强化入口与未知字段语义。
- [x] 增加 Schema、权限、失败路径与写入测试。

Deliverables (must be tangible):
- Code files: controllers/models/services/views/routes/locales/tests。
- Docs updated: ARCHITECTURE、README、本计划。
- Test cases added/updated: 公司资料导入与产品导入控制器/服务测试。

Acceptance (must be verifiable):
- [ ] Behavior acceptance: AI 结果只进入确认页，确认后才更新业务表。
- [ ] Channel/output acceptance: 三类导入均能从导航或业务页到达。
- [ ] Regression acceptance: 原产品导入与公司设置保存测试通过。

Evidence required:
- Commands/checks run: 针对性 Rails tests、zeitwerk、i18n 扫描。
- Screenshot/PDF paths: `tmp/review_shots/product-convergence-20260718/`。
- Notes on what could not be verified: 真实 AI 依赖部署密钥，以 fake client 覆盖契约。

### Phase 2 - i18n 与视觉收敛
Status: `In Progress`

Goals (outcome):
- 用户可见静态文案中文化并进入 i18n；Landing/报价 Hero 更具品牌冲击力且移动端一致。

Implementation actions (must be executable):
- [ ] 扫描视图与控制器 flash，迁移用户可见硬编码文案。
- [x] 重做 Hero 层级、动效与报价入口表现。
- [ ] 清理修改范围内重复/冲突 CSS 并更新样式文档。

Deliverables (must be tangible):
- Code files: locale、ERB、rubusoo.css/相关 controller。
- Docs updated: css-components.md。
- Test cases added/updated: 页面渲染与视觉审计。

Acceptance (must be verifiable):
- [ ] Behavior acceptance: 中文默认页面无关键硬编码英文操作文案。
- [ ] Channel/output acceptance: 桌面、390px、412px 无溢出或操作丢失。
- [ ] Regression acceptance: reduced-motion 与现有 Story 控制仍工作。

Evidence required:
- Commands/checks run: Playwright visual review、Rails tests。
- Screenshot/PDF paths: 同一 review_shots 子目录。
- Notes on what could not be verified: 记录任何浏览器/服务限制。

### Phase 3 - 遗留清理与全站验收
Status: `Planned`

Goals (outcome):
- 删除确认无引用的旧入口、重复关系和影子样式，核心业务从导入到成交闭环可走通。

Implementation actions (must be executable):
- [ ] 通过路由、引用、CSS selector 与视觉 crawler 交叉审计遗留。
- [ ] 删除无引用内容并修正文档与测试。
- [ ] 跑核心业务流与全站视觉审计。

Deliverables (must be tangible):
- Code files: 经引用证明可安全删除的遗留文件/规则。
- Docs updated: README、ARCHITECTURE、视觉审计记录。
- Test cases added/updated: business flow / full-site audit。

Acceptance (must be verifiable):
- [ ] Behavior acceptance: 导入 → 确认 → 报价 → 发布 → 买家响应 → 最终单据闭环。
- [ ] Channel/output acceptance: 所有主要功能均有入口，无空链接或假按钮。
- [ ] Regression acceptance: 全量测试或明确列出未执行部分。

Evidence required:
- Commands/checks run: Rails suite、Playwright audits、dead-selector/reference scan。
- Screenshot/PDF paths: 同一 review_shots 子目录。
- Notes on what could not be verified: 外部邮件、支付与 AI 线上端到端另列。

## 5. Rules for Implementation
- Keep scope tight and phase-based.
- Reuse existing component/system patterns before creating new ones.
- Avoid parallel style/component families unless explicitly approved.
- AI 只能产生候选 JSON；人工确认前不得更新业务记录。
- Clean conflicting/obsolete same-scope rules while editing.
- No intent-only phase updates: every status update must include completed actions and evidence.

## 6. Definition of Done
- 三类导入入口与确认边界清楚。
- 核心流程无功能回归，主要页面中文且视觉一致。
- 改动、验证和延后项均可追踪。

## 7. Verification Plan
- Desktop checks: 1440px Landing、公司导入、Library、产品审核、Quote Studio/发布页。
- Mobile checks: 390px 与 412px 同页面。
- Minimal functional checks: controller/service/model tests、zeitwerk、路由、i18n key。
- What is intentionally not tested: 无密钥时不调用真实 AI；使用契约测试。
- Execution log format: Command / Result / Pass-Fail / Evidence path。

## 8. File Impact Plan
- Expected files: `config/routes.rb`, `config/locales/zh-CN*.yml`, `app/controllers`, `app/services`, `app/views`, `app/assets/stylesheets/rubusoo.css`, tests。
- Optional files: migration/model for staged company import。
- Docs to update: README、ARCHITECTURE、css-components.md、本计划。
- Out-of-scope files that must not be touched: credentials、deploy secrets、历史归档计划。

## 9. Progress Log
- `2026-07-18`: 完成仓库、路由、AI Schema、产品导入、视觉规范和硬编码初审；Phase 1 started。
- `2026-07-18`: 完成公司资料严格 Schema 导入、二级确认、白名单应用、来源限制与公司隔离测试；产品导入入口/提示收敛。
- `2026-07-18`: Landing 成交 Hero 改为中文 i18n 驱动的动态三阶段成交图，并补充移动端与 reduced-motion；Phase 2 started。
- `2026-07-18`: 使用项目 Docker 环境完成迁移和 17 项导入契约测试（115 assertions）；新增 1440/390 双视口视觉审计并通过。全量测试已实际执行，修复陈旧 test DB 后为 177 runs / 724 assertions，仅剩测试镜像刻意不含 Chromium 导致的 PDF 环境错误，以及一项已更新的旧英文断言。
- `2026-07-18`: 移除不安全的旧邀请模型、路由、页面、入口与同域 CSS。旧实现会直接改写用户 `company_id`，无法兼容当前工作区边界；团队成员管理保留。
- `2026-07-19`: 完成产品负责人审计第一批：定位收敛为跨境 B2B Deal OS；明确 Inquiry → Working Quote → Published Version → Acceptance → PI/Final Document；价格页对齐真实 5/30/150/500 发送额度并移除未实现席位承诺；交易详情首屏与概览进入 i18n；单语言状态不再展示无效切换器。
- `2026-07-19`: 修复全局 IntersectionObserver 先隐藏全部下方内容的问题。内容现在默认可见，只在进入视口前挂载短入场状态；390/1440 公开页检查无溢出、无 missing translation、无全页空白。

## 10. Next Priority Queue
- Next phase/task: 先完成 Deal 详情页的业务语言与 i18n 收敛，再迁移其余静态硬编码候选。
- Deferred items: 真实供应商 smoke test 在部署环境执行。
- Reopen conditions: Schema 或 Company 字段变化。
- Owner: Codex / project owner。
- Earliest start date: 2026-07-18。
- Dependency: `OPENAI_API_KEY` 仅影响真实分析，不阻塞手动确认与测试。

### Product direction audit · 2026-07-19
- Ideal category: 面向跨境 B2B 销售的 Deal OS，覆盖原始询盘、报价编制、不可变版本、买家决策与 PI/最终文件交接；不替代 CRM、ERP 或会计系统。
- Single-record rule: Inquiry 是输入，Working Quote 是内部工作稿，Published Version 是对外承诺，Acceptance 是锁定证据，PI/Final Document 是结果；它们必须始终归属于同一笔 Deal。
- Commercial truth rule: 套餐页面只承诺服务器真实执行的发送额度与现有功能。团队邀请恢复安全实现之前，不宣传席位数量或团队邀请能力。
- AI boundary: AI 的价值是整理来源和暴露缺失信息，不是自动做价格与贸易承诺。
- Buyer promise: 买家无需账号，在一个安全链接中查看、提问、选择和确认；销售侧必须始终显示下一步和版本上下文。
- Positioning benchmark: Qwilr、Proposify、PandaDoc 与 HubSpot 均围绕创建、发送、买家互动、接受/签署和后续信号组织价值；Rubusoo 选择在复杂跨境商品、贸易条款、运费证据和版本连续性上形成差异化，而不是复制通用文档编辑器。
- Locale truth: 当前运行配置只开放 `zh-CN`。`en` 与 `es-419` 文件属于迁移资产，在各自完整业务流与营销页验收通过前，不对外宣称三语 UI 已完成，也不展示无效语言入口。

## 11. Archive Notes (when cycle is done)
- Final status: Active。
- Archive filename: 完成后移至 `docs/archive/product-convergence-plan-2026-07-18.md`。
- Key decisions to preserve: AI 只生成候选；空值优于猜测；人工确认是唯一写入闸门。
- Delivery summary: Pending。
- Completed vs deferred: Pending。
- Evidence index: Pending。
