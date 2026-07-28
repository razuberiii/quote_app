# Rubusoo 全功能交互验收

生成日期：2026-07-27

优先打开 [可视化验收目录](index.html)。每张截图均来自真实浏览器或真实导出文件；表格按“入口 → 页面职责 → 主要操作/结果”说明，说明页、只读页、弹窗和移动端状态均单独列出。

| # | 页面 / 状态 | 实际地址 | 入口、用途与交互 |
|---:|---|---|---|
| 01 | [公开首页](screenshots/01-home.jpg) | `/` | 入口：直接访问网站。用途：说明产品解决的问题、核心流程与试用入口。交互：查看产品演示、价格与注册入口。 |
| 02 | [价格方案](screenshots/02-pricing.jpg) | `/pricing` | 入口：首页“价格”或导航。用途：比较方案能力和试用条件。交互：选择方案并进入注册。 |
| 03 | [销售端演示](screenshots/03-seller-demo.jpg) | `/seller-demo` | 入口：首页产品演示。用途：在未登录状态理解销售从询盘到报价的完整工作方式。 |
| 04 | [客户体验演示](screenshots/04-buyer-demo.jpg) | `/buyer-demo` | 入口：首页客户页面演示。用途：展示客户如何查看、提问、修改和接受报价。 |
| 05 | [登录](screenshots/05-sign-in.jpg) | `/users/sign_in?locale=zh-CN` | 入口：顶部“登录”。用途：进入销售工作台。交互：账号密码、记住登录、注册入口。 |
| 06 | [注册](screenshots/06-sign-up.jpg) | `/users/sign_up?locale=zh-CN` | 入口：顶部“免费开始”。用途：创建新的销售工作空间。 |
| 07 | [联系页面](screenshots/07-contact.jpg) | `/zh-CN/contact` | 入口：网站页脚。用途：提交商务咨询；不是报价工作流页面。 |
| 08 | [隐私说明](screenshots/08-privacy.jpg) | `/zh-CN/privacy` | 入口：网站页脚。用途：说明数据处理和隐私边界；只读页面。 |
| 09 | [服务条款](screenshots/09-terms.jpg) | `/zh-CN/terms` | 入口：网站页脚。用途：说明产品使用条款；只读页面。 |
| 10 | [报价工作台](screenshots/10-quotes.jpg) | `/quotes` | 入口：登录后主导航“报价”。用途：查看所有交易、当前阶段和下一步动作。交互：打开交易或新建报价。 |
| 11 | [AI 导入中心](screenshots/11-ai-import-hub.jpg) | `/imports` | 入口：顶部“AI 导入”。用途：选择公司资料、商品目录或客户询盘的导入类型。 |
| 12 | [公司资料 AI 导入](screenshots/12-company-import.jpg) | `/settings/company-imports/new` | 入口：AI 导入中心或公司设置。用途：粘贴/上传资料，识别后核对并写入公司资料。 |
| 13 | [商品目录导入](screenshots/13-catalog-import.jpg) | `/library/catalog-imports/new` | 入口：AI 导入中心或商品库。用途：上传 CSV/XLSX/PDF/图片，后台识别后核对商品。 |
| 14 | [客户询盘导入](screenshots/14-smart-intake-entry.jpg) | `/inquiries/new` | 入口：新建报价或 AI 导入中心。用途：粘贴邮件/聊天或上传文件，生成可持续更新的询盘。 |
| 15 | [询盘核对与持续沟通](screenshots/15-smart-intake-review.jpg) | `/inquiries/2` | 入口：询盘导入完成或交易“沟通”。用途：保留原文、核对需求、查看缺项并追加后续客户消息。 |
| 16 | [交易概览](screenshots/16-quote-overview.jpg) | `/quotes/9` | 入口：报价列表打开一笔交易。用途：汇总客户、金额、状态和唯一下一步动作。 |
| 17 | [客户动态](screenshots/17-quote-activity.jpg) | `/quotes/9?tab=activity` | 入口：交易详情“客户动态”。用途：查看客户打开、提问、反馈和发送记录；只读事件流。 |
| 18 | [版本与导出](screenshots/18-quote-versions.jpg) | `/quotes/9?tab=versions` | 入口：交易详情“版本与导出”。用途：查看不可变版本，打开客户链接、下载 PDF/Excel 或发送。 |
| 19 | [交易文件](screenshots/19-quote-documents.jpg) | `/quotes/9?tab=documents` | 入口：交易详情“文件”。用途：集中管理客户文件、交付证据和最终文件。 |
| 20 | [报价编辑器](screenshots/20-quote-studio.jpg) | `/quotes/11/edit` | 入口：交易下一步“编辑报价”。用途：编辑商品、数量、价格、条款和客户可见内容；保存后刷新发布检查。 |
| 21 | [发布检查](screenshots/21-publish-check.jpg) | `/quotes/9/publish` | 入口：客户预览顶部“继续发布”。用途：发布前集中确认阻塞项；确认后冻结正式版本。 |
| 22 | [发送报价](screenshots/22-delivery.jpg) | `/quotes/9/deliver?version_id=5` | 入口：发布完成页或版本列表“发送”。用途：选择邮件、链接或外部渠道并记录交付。 |
| 23 | [记录客户接受](screenshots/23-acceptance.jpg) | `/quotes/9/acceptance/new?version_id=5` | 入口：交易下一步或客户确认记录。用途：记录签署人、PO 和接受证据。 |
| 24 | [版本差异](screenshots/24-version-diff.jpg) | `/quote_revisions/5` | 入口：版本列表打开某个版本。用途：比较版本内容，不展示原始 JSON。 |
| 25 | [商品库](screenshots/25-library-products.jpg) | `/library?section=products` | 入口：主导航“商品库”。用途：维护可复用商品、价格依据和使用记录。 |
| 26 | [报价预设](screenshots/26-library-presets.jpg) | `/library?section=presets` | 入口：商品库“报价预设”。用途：维护常用条款、配置和可复用报价模块。 |
| 27 | [报价输出设计](screenshots/27-document-design.jpg) | `/document_design/edit` | 入口：商品库“输出格式”或设置。用途：设置 Logo、字体、密度、字段显示和客户语言。 |
| 28 | [商品详情与价格依据](screenshots/28-product-source.jpg) | `/products/4` | 入口：商品库打开商品。用途：查看商品资料、历史报价和价格来源。 |
| 29 | [手工新建商品](screenshots/29-product-new.jpg) | `/products/new` | 入口：商品库“手工添加产品”。用途：不经过文件导入直接建立商品。 |
| 30 | [编辑商品](screenshots/30-product-edit.jpg) | `/products/4/edit` | 入口：商品详情“编辑”。用途：维护商品身份、图片、价格、规格和交期。 |
| 31 | [客户列表](screenshots/31-customers.jpg) | `/customers` | 入口：主导航“客户”。用途：按客户查看跟进状态、报价和下一步。 |
| 32 | [客户详情](screenshots/32-customer-detail.jpg) | `/customers/2` | 入口：客户列表打开客户。用途：汇总联系人、交易、活动和待办。 |
| 33 | [新建客户](screenshots/33-customer-new.jpg) | `/customers/new` | 入口：客户列表“新建客户”。用途：手工建立客户资料。 |
| 34 | [公司设置](screenshots/34-company-settings.jpg) | `/company_settings/edit` | 入口：主导航“设置”→公司。用途：维护公司身份、商务默认值、品牌与跟进邮件。 |
| 35 | [账户设置](screenshots/35-account-settings.jpg) | `/users/edit` | 入口：头像菜单“账户”。用途：维护个人身份、登录信息和安全设置。 |
| 36 | [团队设置](screenshots/36-team-settings.jpg) | `/team_members` | 入口：设置→团队。用途：查看团队成员、角色与权限。 |
| 37 | [账户菜单](screenshots/38-account-menu.jpg) | `/quotes` | 入口：顶部头像。用途：切换账户、查看通知和切换主题。交互：菜单内完成账户级操作。 |
| 38 | [移动端主菜单](screenshots/39-mobile-navigation.jpg) | `/quotes` | 入口：390px 宽度点击右上角菜单。用途：在手机上访问全部主导航、账户和主题操作。 |
| 39 | [客户公开报价链接](screenshots/37-buyer-room.jpg) | `/q/AD7H77Ksq-wUgMyUakT6H0oAEVA85ioTAx6cEuYXDhY` | 入口：版本与导出“客户页面”或复制客户链接。用途：客户查看商品、条款、总价并提问、要求修改或接受。 |
| 40 | [客户提问弹窗](screenshots/40-buyer-question.jpg) | `/q/AD7H77Ksq-wUgMyUakT6H0oAEVA85ioTAx6cEuYXDhY` | 入口：公开报价中商品、规格或整份报价的“提问”。用途：把问题连同上下文回传销售。 |
| 41 | [客户要求修改](screenshots/41-buyer-changes.jpg) | `/q/AD7H77Ksq-wUgMyUakT6H0oAEVA85ioTAx6cEuYXDhY` | 入口：公开报价右侧“要求修改”。用途：提交修改说明和附件，形成销售可核对的变更。 |
| 42 | [客户确认接受](screenshots/42-buyer-accept.jpg) | `/q/AD7H77Ksq-wUgMyUakT6H0oAEVA85ioTAx6cEuYXDhY` | 入口：公开报价右侧“接受报价”。用途：确认金额、身份和 PO 信息并锁定接受记录。 |
| 43 | [客户公开报价·移动端](screenshots/43-buyer-room-mobile.jpg) | `/q/AD7H77Ksq-wUgMyUakT6H0oAEVA85ioTAx6cEuYXDhY` | 入口：客户在手机打开公开链接。用途：验证内容阅读、底部金额和接受/修改动作不遮挡正文。 |
| 44 | [正式 PDF 报价单](screenshots/44-quote-pdf-page1.png) | `exports/quote-v2.pdf` | 入口：版本与导出 → PDF。用途：销售下载或发送给客户的固定版本文件；本图直接渲染真实导出文件第一页。 |
| 45 | [客户页面下载的 PDF](screenshots/45-buyer-pdf-page1.png) | `exports/buyer-room-quote-v2.pdf` | 入口：客户公开报价页面 → 下载 PDF。用途：客户自行留档；内容与当前正式版本一致，本图直接渲染真实下载文件。 |
| 46 | [正式 Excel 报价单](screenshots/46-quote-excel-preview.jpg) | `exports/quote-v2.xlsx` | 入口：版本与导出 → Excel。用途：向需要表格文件的客户交付；截图内容由真实 .xlsx 文件读取并呈现。 |

## 正式输出

- [正式 PDF 报价单](exports/quote-v2.pdf)
- [正式 Excel 报价单](exports/quote-v2.xlsx)
- [客户公开页下载的 PDF](exports/buyer-room-quote-v2.pdf)
