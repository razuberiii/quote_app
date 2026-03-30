# 正式复杂报价模块化系统（Production-Oriented Staged Roadmap，2026-03-25）

> Update 2026-03-26（执行收口）
> - 报价链路已切换为“仅正式报价预设”来源：移除 demo 场景/兜底与模板 advanced 默认自动注入。
> - `QuotePreset.active` 与 `QuotePresetMaster.enabled` 已退出主流程（UI/控制器不再依赖），生效以“主映射选择/手动选择”为准。
> - 报价编辑页保留“插入标准物流费用项”手动入口，删除“插入设备主商品项”demo 入口；`fee_*` 行进一步轻量化（禁用图片）。

## 1. Summary / Context
- 核心目标：保持默认轻量 Quote 主路径不受影响，同时把中高正式度报价能力做成可长期使用的模块化系统（不是字段堆砌）。
- 本次新增重点：
  - `Formal Closing`（正式尾部模块体系）
  - `Quote -> PI` 交互路径（从 Quote 触发生成独立 PI）
- 关键边界：
  - Quote 与 PI 语义分离，不混成同一文档对象。
  - 交互入口在 Quote 页面，但 PI 生成后进入独立 PI 文档/页面。
  - 不引入重型 schema 作为前置条件，不把产品带偏成重型法务/ERP 单证平台。

## 2. Design Principles (Locked)
1. 默认轻量主路径不受影响。
2. 正式能力模块化、可选开启，不回到 advanced 字段平铺。
3. Quote 与 PI 分离：Quote 管协作与推进，PI 管确认态正式文档。
4. PI 入口长在 Quote 页面动作区，不要求用户跳离上下文重填。
5. 视觉是商业文档风格，不走法律合同系统风格。
6. 显式空值优先，不被低优先级来源回填。

## 3. Scope and Constraints
- 当前主范围：
  - `app/views/quotes/_form.html.erb`
  - `app/views/quotes/export_pdf.html.erb`
  - `app/views/quotes/_show_content.html.erb`
  - `app/views/public/quotes/show.html.erb`
  - `app/views/public/quote_shares/show.html.erb`
  - `app/models/quote.rb`
  - `app/models/quote_template.rb`
  - `app/controllers/quotes_controller.rb`
  - `app/services/*`（preset / mapper / assembler）
- 这一版仍不做：
  - 重型 configuration matrix 引擎
  - 默认 item editor 重构
  - 把 Quote/PI 合并成同一文档对象
  - Excel 正式化精修

## 4. Module Mapping Contract（字段 -> 模块）

### 4.1 固定模块顺序（PDF / internal / public 默认一致）
1. Header
2. Items
3. Totals
4. Summary Block（商务摘要）
5. Configuration Block（有值才显示）
6. Detail Pictures Block（有图才显示）
7. Logistics Summary Block
8. Container Loading Block
9. Narrative Blocks（Scope / After-Sales / Options / Exclusions / Notes）
10. Formal Closing Tail（Settlement Block -> Signature Block）
11. Footer / Signature Meta

约束：
- 空模块可隐藏，但剩余模块顺序不漂移。
- `Formal Closing Tail` 在 Narrative 之后，不再混在模糊 footer 文本里。

### 4.2 Summary Block（商务摘要）
- 来源（复用现有字段）：
  - `advanced_trade_terms.hs_code` -> HS Code
  - `advanced_trade_terms.delivery_commitment_note` -> Delivery Time
  - `advanced_trade_terms.warranty_scope_note` -> Guarantee
  - `advanced_trade_terms.support_scope_note` -> Online Support
  - `advanced_trade_terms.validity_clause_note` -> Price Valid Time
  - `advanced_trade_terms.payment_clause_note` -> Payment Term
- 角色：10 秒快读摘要。
- 规则：不与 Formal Closing 做同层重复复述。

### 4.3 Logistics Summary Block
- 来源：
  - `advanced_logistics.freight_note` -> Freight Note / Basis
  - `advanced_logistics.container_type` -> Container Type
  - `advanced_logistics.shipping_scope_note` -> Shipping Scope
- 规则：与收费 line item 分层，不混淆。

### 4.4 Container Loading Block
- Stage 1：支持 lightweight 结构化行 + `container_loading_note` fallback narrative。
- 显示结构：
  - 常规列：`Variant / Version`、`Container Type`、`Capacity`、`Note`
- 新约束（补充）：
  - 客户面不出现 `optional` 这类系统语气；列头统一显示 `Note`。
  - 若 Note 全空，可隐藏该列。
- Stage 2 规划：
  - 前三列支持“受控表头预设 + 受控候选项”，不是完全自由输入表头。
  - 备注列继续自由文本。

### 4.5 Narrative Blocks
- 包含：`scope_of_supply`、after-sales/options/exclusions（可先归并）、`notes`。
- 规则：
  - 与摘要是“摘要 + 展开”关系。
  - 全空则整块隐藏（包含备注）。

### 4.6 Formal Closing Module（新增）
#### Settlement Block
- 用于正式尾部结算信息：
  - trade term / payment term / delivery time
  - remittance / bank route / beneficiary details
- 位置：Narrative 之后，Signature Block 之前。
- 边界：
  - 不与 Summary 做同层重复；Summary 快读，Settlement 正式闭合说明。

#### Signature Block
- 用于签署占位：
  - seller signature
  - seller stamp
  - buyer signature line（可选）
- 规则：
  - 不默认进入普通报价主路径。
  - 优先服务 PI profile。

## 5. Editing Contract（编辑端）
- 正式模式编辑按模块分组，不再 advanced 字段平铺。
- Stage 1 保持底层字段复用，但 UI 以模块组织。
- 模块空态规则：
  - Summary/Logistics：全空隐藏，半空仅渲染有值键。
  - Container Loading：无有效行时回退 narrative；两者都空则隐藏。
  - Notes/Narrative：全空隐藏，不留空 section。
  - Configuration：无有效行隐藏。
  - Detail Pictures：无图隐藏。
- 超长规则：
  - 摘要允许截断，但全文必须在 Narrative/对应正文有承载，禁止“只截断不保留”。

## 6. Rendering Contract（PDF / internal / public / Excel）

### 6.1 PDF（主战场）
- 目标：真实商业文件感，不像 SaaS 页面截图。
- 固定结构：遵循第 4.1 顺序。
- 强约束：
  - Header/Items/Totals/模块顺序稳定。
  - `optional` 等编辑语气不进入客户文档。
  - 空块干净隐藏。
  - 分页避免标题孤行、Totals 割裂、小模块碎裂。

### 6.2 Internal Webview
- 语义顺序跟随 PDF。
- 可视觉轻量，但不能变成字段日志墙。

### 6.3 Public Link
- 语义顺序跟随 PDF。
- 保持模块层次清晰，不做同级精排。

### 6.4 Excel（Boundary / Deferred）
- 本轮维持 simplified output。
- 仅要求：无回归、无内部术语泄露、主商品/费用项/totals/关键 supplementary 语义不丢。
- 不做正式化版式精修。

## 7. Quote Profile vs PI Profile（职责边界）

### 7.1 quotation profile
- 轻量、报价推进、协作导向。
- 可含 Summary / Logistics / Narrative / Configuration / Detail Pictures。
- 默认不展示 seller signature/stamp/buyer signature line。

### 7.2 PI profile / PI document
- 正式确认态文档。
- 支持：PI number、issue date、trade/payment/delivery、bank info、seller signature、seller stamp、buyer signature line（可选）。
- 默认不展示 negotiation/revision diff 等协作痕迹。

## 8. Quote -> PI Interaction Flow（新增）
1. 关系定义：PI 由 Quote 派生，但为独立文档记录。
2. 触发时机：accepted / won / confirmed 等建议态；同时允许手动强制触发（Create PI anyway）。
3. 入口位置：Quote 页面动作区（不要求跳到 PI 模块从头新建）。
4. 触发形态：先开轻量 panel/drawer/modal，确认 PI 专属项：
   - PI number / issue date
   - buyer/seller confirm
   - payment/trade/delivery
   - bank info
   - seller signature on/off
   - seller stamp on/off
   - buyer signature line on/off
5. 默认继承：优先继承 Quote 已有值，用户只补 PI 专属信息。
6. 生成结果：进入独立 PI 页面；Quote 显示 related PI / derived docs 关系。

## 9. Data Source Priority（锁定）
- Settlement / bank info：
  - `quote override > template/profile defaults > company/org fallback > system fallback`
- Signature / stamp asset：
  - `quote override > template/profile preset > company/org asset fallback`
- Buyer signature line：
  - 可选，默认不强制开启。
- 显式空值：
  - 显式空值优先，禁止低优先级自动回填。

## 10. Execution Roadmap / Phase Planning

### Phase 1 - Formal Quote Production Slice（进行中）
- 目标：单场景正式可用（设备/整柜/port-to-port），可持续生产使用。
- 已包含：场景 preset、主商品/费用项插入、模块化显示基础、PDF 主链收口。
- 继续收口项：
  - 客户侧文案去系统腔（如 optional）。
  - 空备注/空模块隐藏。
  - 渠道语义一致性。

### Phase 2 - High-Value Optional Modules（进行中）
- Configuration / Detail Pictures 继续增强为通用可选模块。
- Container Loading 升级：
  - 前三列受控表头/候选项预设（非自由表头）；备注列自由输入。
- 预设化：
  - 把高频模块配置从 code/seed 逐步抽到可维护 preset 来源。
  - 轻量流程商务条款（`payment_term / trade_term / delivery_notes / terms_text / scope_of_supply`）纳入 scenario preset 来源，避免散落在模板默认字段中。
  - `scope_of_supply` 默认内容从模板预填职责中抽离，模板侧仅保留展示标签与可见性职责；模板默认内容字段进入 deprecate 路径（阶段性保留，不再作为新建 Quote 预填来源）。

### Phase 3 - PI Generation Flow & Formal Closing（新增，已启动基础实现）
- Formal Closing Tail：Settlement + Signature 模块上线。
- Quote -> PI 交互路径上线（Quote 动作区触发 + 轻量确认面板）。
- PI profile / PI export 规则落地。
- Quote 页面建立 related PI / derived documents 关系呈现。

### Phase 4 - Heavier / Lower-Frequency / Industry Extensions（原 Phase 3 顺延）
- 更重型/低频/行业化增强：
  - 重型 configuration matrix
  - 高级图集编排
  - 更深层文档策略化与行业模板体系

## 11. Field Inventory / i18n Bookkeeping
- 继续保留底层来源字段：
  - `advanced_trade_terms.*`
  - `advanced_logistics.*`
- 现有模块字段：
  - `configuration_block.rows[{label,value,position}]`
  - `detail_pictures_block.items[{image_blob_id,caption,source,position}]`
  - `container_loading_block.headers{variant,container_type,capacity,note}`
  - `container_loading_block.note_enabled:boolean`
  - `container_loading_block.rows[{variant,container_type,capacity,note,position}]`
- Formal Closing / PI 规划字段（roadmap 级，非本次实现）：
  - settlement: `trade_term`, `payment_term`, `delivery_time`, `bank_info`(route/beneficiary)
  - signature: `seller_signature_asset`, `seller_stamp_asset`, `buyer_signature_line_enabled`
  - PI: `pi_number`, `issue_date`, `source_quote_id`
- i18n 后续必补清单：
  - Formal Closing 模块标题与字段标签
  - PI panel 行为文案（Generate PI / Create PI anyway / related PI）
  - Container Loading 受控表头候选项
  - 客户面去系统腔文案（如 optional）
  - 轻量商务条款 preset 行为提示文案（场景切换、默认来源、deprecate 提示）

## 12. File Impact Plan (Planning)
- Quote 侧：
  - `app/views/quotes/_form.html.erb`
  - `app/views/quotes/export_pdf.html.erb`
  - `app/views/quotes/_show_content.html.erb`
  - `app/views/public/quotes/show.html.erb`
  - `app/views/public/quote_shares/show.html.erb`
  - `app/controllers/quotes_controller.rb`
  - `app/models/quote.rb`
  - `app/models/quote_template.rb`
- PI 侧（Phase 3 规划）：
  - `app/models/proforma_invoice.rb`（或等价对象）
  - `app/controllers/proforma_invoices_controller.rb`
  - `app/views/proforma_invoices/*`
  - Quote show action bar + relation panel
- Service 层：
  - `quote_module_mapper` / `pi_from_quote_builder` / `formal_closing_mapper`

## 13. Acceptance & Milestones
- Phase 1 完成标准：
  - 仍是当前优先阶段（是的，当前还在 Phase 1 收口）。
  - 单场景可长期使用，不依赖开发介入改 preset。
  - 空备注不显示，客户面不出现奇怪系统词。
- Phase 2 完成标准：
  - 可选模块增强可复用；装柜前三列可通过预设选择，不是全自由。
- Phase 3 完成标准：
  - 可从 Quote 稳定生成独立 PI；Formal Closing 完整闭合成交文档语义。

## 14. Progress Log
- 2026-03-25：Roadmap 从 demo-first 重写为 production-oriented staged roadmap。
- 2026-03-25：新增模块化合同、固定渲染顺序、空态隐藏规则。
- 2026-03-25：按业务优先级重排阶段，新增 `Phase 3 - PI Generation Flow & Formal Closing`，原重型阶段顺延为 Phase 4。
- 2026-03-25：Phase 1 收口落地：客户侧 Container Loading 去除 `optional` 文案；当所有装柜备注为空时自动隐藏备注列（internal/public/share/PDF 一致）。
- 2026-03-25：Phase 1 收口继续：产品编辑页新增上传图片与已有图库统一为同一网格卡片视觉（不再两套样式），并支持上传后单张移除与主图选中态一致交互。
- 2026-03-25：Phase 2 启动（preset 来源治理）：轻量场景补齐 business terms 预设来源；`scope_of_supply` 停止从模板默认内容预填，改由 scenario preset 统一供给（模板侧默认值字段进入 deprecate 计划）。
- 2026-03-25：Phase 2 继续：Container Loading 编辑端前三列增加常用候选项（Variant/Container Type/Capacity，支持选择+手填兜底），保持备注列自由输入与现有输出结构不变。
- 2026-03-26：Phase 3 启动：新增 `Quote -> Create PI` 基础链路（生成独立派生 Quote 并记录 `source_quote_id`）、Quote 详情页 `Related Documents` 关联区块、三语 i18n 文案与回归测试。当前为无面板的直接生成版本，后续再补轻量确认面板与 Formal Closing 模块编辑器。
- 2026-03-26：为保持 Quote/PI 语义分离，详情页移除“切换为形式发票/切换为报价单”同文档换皮入口，仅保留“生成 PI（独立文档）”；并增加回归校验，确保生成时优先命中 `document_kind=proforma_invoice` 模板。
- 2026-03-26：导航命名收口：保留 `产品 > 预设`，新增 `模板` 下拉并提供 `模板 / 报价预设` 两个入口，避免与产品预设语义混淆；当前“报价预设”先挂到模板中心入口（后续在同位点承接独立报价预设管理页）。
- 2026-03-26：Phase 3 补落地：新增 `Formal Closing` 数据块（含 settlement + signature flags + PI number），并接入 Quote 编辑端、internal/public/share/PDF 渲染链。
- 2026-03-26：`Create PI` 改为轻量确认面板模式（PI number / issue date / payment/trade/delivery / bank route / beneficiary / remittance / signature flags），生成后仍保持独立 PI 文档关系。
- 2026-03-26：PI 文档编号支持优先显示 `formal_closing_block.pi_number`（为空回退 `quote_no`），并同步到 internal/public/share/PDF/Excel 的文档编号输出。
- 2026-03-26：Phase 2 落地（报价预设模块化）：新增独立 `quote_presets` 与 `quote_preset_master`（路由/导航从 `quote_templates` 解耦），按模块管理并支持主预设映射；Quote 新建自动填充 `business_terms`，advanced 启用时自动补扩展模块（仅填空不覆盖）；Quote 表单支持分模块手动套用覆盖；`container_loading_block` 扩展为可自定义表头 + `note_enabled`，并在 internal/public/share/PDF 渲染链保持一致。
- 2026-03-27：Formal Closing 签章链路切换为报价级图片来源（`quote.seller_signature_image / quote.seller_stamp_image`），支持在报价与 formal_closing 预设中上传/移除并通过预设应用到报价；渲染与导出（internal/public/share/PDF/Excel）不再依赖模板签名图片。同时新增报价预设按模块分级限额（普通 10 / VIP 50）。
