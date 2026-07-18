# 中文首次报价自助验收

本轮验收目标：不了解 Rubusoo 内部模型的中文用户，在 Library 为空且 AI 服务不可用时，仍可从英文询盘创建第一份 Working draft。

## 实际浏览器任务

测试指令只有一句：

> 请根据这封包含两件机械商品、数量、电压、目的港和 CIF 要求的英文询盘创建一份报价。

设备宽度为 390px。测试用户从「导入询盘」进入，没有预先创建 Buyer 或 Product。

## 观察与修复

| 观察 | 原因 | 产品修复 | 结果 |
| --- | --- | --- | --- |
| AI 上游不可用后，用户面对空白提取结果，不知道如何继续 | 旧降级流程只记录失败，没有产生可编辑候选 | 增加确定性解析降级，保留原文并提取 Buyer、联系人、邮箱、目的港、Incoterm、多件商品、型号、数量、电压和 Evidence | 用户无需重贴询盘，可继续确认 |
| 用户点击「创建 Deal」后仍停留在 Review，必须先猜到要保存 | HTML 的 PATCH override 覆盖了按钮上的 POST 意图 | 将「创建 Deal」定义为一次明确的保存并构建动作，先持久化当前确认，再创建 Working draft | 单次点击进入 Quote Studio |
| 空 Library 容易让用户误以为必须先维护 Catalog | 旧匹配区域强调 Catalog product | 未匹配候选默认标记为 Deal-only，并明确“不会写入 Library” | 两件商品进入报价，Product 数量保持 0 |
| Missing 项没有处理顺序 | 缺失信息只有状态，没有时机语义 | 分为“必须现在补 / 发布前补 / 建议补充 / 可以忽略”，页面只突出当前下一步 | 用户先补 Buyer/商品身份，再补价格和运费 |
| 商品导入的技术解析结果不适合审核 | 旧流程缺少来源与决策 | 商品候选展示来源 Sheet、Cell 或 PDF 页码、置信度、重复候选，并要求新建/合并/Variant/忽略后显式应用 | AI 或解析器不能静默入库 |

## 真实执行结果

1. 提交英文询盘。
2. AI 上游失败，确定性解析自动接管。
3. 提取两件商品：型号、数量和电压均保留；CIF 和目的港被识别。
4. 用户确认币种为 USD。
5. 点击一次「创建 Deal」。
6. 浏览器进入 Quote Studio，存在两个 Deal-only item。
7. Library Product 数量仍为 0。
8. Quote Studio 明确标出两项价格和运费为发布前必补，不猜价。
9. 390px 页面横向溢出为 0。

## 自动化证明

- `quote_first_inquiries_controller_test.rb`：空 Library、多商品、Deal-only、单击构建并保存当前 Review。
- `inquiry_deterministic_parser_test.rb`：多商品、型号、数量、电压、目的港和 Incoterm。
- `inquiry_guidance_test.rb`：四级缺失时机与唯一下一步。
- `product_catalog_parser_test.rb`：CSV、真实 XLSX、真实多页 PDF、来源位置、公式中和与不猜价。
- `product_import_batches_controller_test.rb`：候选不会静默入库，只有审核并应用后才创建 Product。

## 截图说明

本地真实浏览器截图位于 `tmp/self-service-audit/`，不作为公开基线。公开视觉基线仍位于 `docs/visual-review/current/`，由 Visual Review workflow 生成；其中不得包含生产数据或密钥。

## 当前边界

- 扫描 PDF 与图片导入依赖 OCR，低质量素材可能只产生低置信度候选；原文件和已确认数据会保留，用户可手工修正。
- PDF Catalog 的复杂跨页表格需要 AI 回退，但 AI 只返回 Schema 校验后的候选，不能直接创建 Product。
- 价格、运费、汇率、税费和交期不会由 AI 或确定性解析器猜测。

## 2026-07-18 Catalog 收口复验

- 标准 CSV/XLSX 可以确定性生成候选；未知 XLSX 即使已读出部分商品，仍会进入 AI 语义分析。
- 确定性候选与 AI 候选统一按 SKU 或“名称 + 型号”合并，来源证据保留并去重。
- PDF、扫描 PDF 和图片逐页或逐区块记录“已读取 / 未识别 / 失败”，不会用一个成功候选掩盖剩余范围。
- 精确 SKU 只关联可能重复商品，审核决定仍为“稍后决定”，不默认合并。
- Library 商品缺失价格以数据库 `NULL` 保存，不再用 `0` 伪装成明确价格。
- 已使用配置的真实 Provider 发起复杂三页 Catalog 验证；上游返回暂时不可用。确定性候选、原文件和逐范围失败状态均保留，但真实 Provider 端到端结果仍为 `Needs Review`，不得声称完成。
