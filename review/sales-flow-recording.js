const { chromium } = require("playwright")
const { execFileSync } = require("node:child_process")
const fs = require("node:fs")
const path = require("node:path")

const base = "https://next.rubusoo.com"
const stamp = Date.now()
const email = `sales.review.${stamp}@example.com`
const username = `sales_review_${String(stamp).slice(-8)}`
const password = "ReviewSales!2026"
const output = path.resolve(__dirname)
const findings = []

const pause = (page, ms = 1500) => page.waitForTimeout(ms)

async function explain(page, title, detail) {
  await page.evaluate(({ title, detail }) => {
    document.querySelector("#review-explainer")?.remove()
    const note = document.createElement("aside")
    note.id = "review-explainer"
    note.style.cssText = "position:fixed;z-index:2147483647;left:24px;bottom:24px;max-width:560px;padding:16px 20px;border:1px solid rgba(255,255,255,.24);border-radius:10px;background:rgba(8,11,17,.94);color:#fff;box-shadow:0 18px 60px rgba(0,0,0,.35);font:16px/1.5 system-ui,sans-serif;pointer-events:none"
    note.innerHTML = `<strong style="display:block;margin-bottom:5px;color:#79f2b2;font-size:18px">${title}</strong><span style="color:#c8cfdb">${detail}</span>`
    document.body.appendChild(note)
  }, { title, detail })
  await pause(page, 2200)
}

async function goto(page, pathname) {
  const response = await page.goto(`${base}${pathname}`, { waitUntil: "networkidle", timeout: 120000 })
  if (!response || response.status() >= 400) findings.push(`HTTP ${response?.status() || "?"}: ${pathname}`)
  await pause(page)
}

async function fillIf(page, selector, value) {
  const field = page.locator(selector).first()
  if (await field.count()) await field.fill(String(value))
}

async function selectIf(page, selector, value) {
  const field = page.locator(selector).first()
  if (await field.count()) await field.selectOption(value)
}

async function main() {
  fs.mkdirSync(output, { recursive: true })
  execFileSync("docker", ["exec", "quoteapp-review-web", "bundle", "exec", "rails", "runner",
    `User.create!(username: ${JSON.stringify(username)}, email: ${JSON.stringify(email)}, password: ${JSON.stringify(password)}, password_confirmation: ${JSON.stringify(password)}, email_verified_at: Time.current)`])
  const browser = await chromium.launch({ headless: true })
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    recordVideo: { dir: output, size: { width: 1440, height: 900 } },
    locale: "zh-CN",
    colorScheme: "light",
    acceptDownloads: true
  })
  const page = await context.newPage()
  const video = page.video()
  page.on("console", message => {
    if (message.type() === "error") findings.push(`Console: ${message.text()}`)
  })
  page.on("response", response => {
    if (response.status() === 404) findings.push(`404: ${response.url()}`)
  })

  await goto(page, "/users/sign_in?locale=zh-CN")
  await explain(page, "01 · 登录全新销售账号", "账号已准备好，从零开始完成公司资料、商品、询盘、报价、发布与导出。")
  await page.locator('input[name="user[login]"]').fill(email)
  await pause(page, 700)
  await page.locator('input[name="user[password]"]').fill(password)
  await pause(page, 900)
  await page.locator('form[action="/users/sign_in"] input[type="submit"]').click()
  await page.waitForLoadState("networkidle")
  await pause(page, 900)

  await goto(page, "/settings/company-imports/new?locale=zh-CN")
  await explain(page, "02 · 建立公司资料", "粘贴现有公司简介，让系统整理候选字段；销售只负责核对后应用。")
  const companyProfile = `Atlas Motion Systems Ltd.\nExport sales: Sofia Chen, sofia@atlas-motion.example, +86 21 5555 0188\nAddress: 88 Automation Road, Shanghai, China\nRegistration No.: CN-91310000-REVIEW\nWe manufacture hydraulic power units and industrial motion-control equipment.\nPrimary markets: Europe, Middle East and North America.\nPayment: 30% deposit, 70% before shipment. Default currency: USD.`
  await page.locator('textarea[name="company_profile_import[source_text]"]').fill(companyProfile)
  await pause(page)
  await page.locator('form[action="/settings/company-imports"] input[type="submit"]').click()
  await page.waitForLoadState("networkidle", { timeout: 120000 })
  await pause(page, 900)
  const applyCompany = page.getByRole("button", { name: /确认并应用|应用到公司资料/ })
  if (await applyCompany.count()) {
    await explain(page, "核对识别结果", "原文与候选资料并列展示。确认无误后才写入公司资料。")
    await applyCompany.click()
    await page.waitForLoadState("networkidle")
    await pause(page)
  } else {
    findings.push("公司资料分析未进入可应用状态")
    execFileSync("docker", ["exec", "quoteapp-review-web", "bundle", "exec", "rails", "runner",
      `User.find_by!(email: ${JSON.stringify(email)}).company.update!(name: "Atlas Motion Systems Ltd.")`])
  }

  await goto(page, "/products/new?locale=zh-CN")
  await explain(page, "03 · 建立商品底稿", "录入一个可重复报价的标准商品，后续询盘可自动匹配价格、交期和规格。")
  await fillIf(page, 'input[name="product[name]"]', "HZ-240 液压动力单元")
  await fillIf(page, 'input[name="product[sku]"]', "HZ-240")
  await fillIf(page, 'input[name="product[product_category]"]', "液压动力设备")
  await fillIf(page, 'input[name="product[unit]"]', "台")
  await fillIf(page, 'input[name="product[default_price]"]', "2400")
  await selectIf(page, 'select[name="product[price_currency]"]', "USD")
  await fillIf(page, 'input[name="product[moq]"]', "1")
  await fillIf(page, 'input[name="product[lead_time]"]', "收到订金后 20 个工作日")
  await fillIf(page, 'textarea[name="product[description]"]', "5.5 kW 液压动力单元，380V / 50Hz，IP54 控制箱，不锈钢外壳，含备用密封套件。")
  await pause(page)
  await page.locator('form[action="/products"] input[type="submit"]').first().click()
  await page.waitForLoadState("networkidle")
  await pause(page, 900)

  await goto(page, "/inquiries/new?locale=zh-CN")
  await explain(page, "04 · 导入客户原始询盘", "直接粘贴客户邮件，不要求销售先整理字段；原文会保留作为证据。")
  const inquiry = `Subject: RFQ – 5 hydraulic power units for Long Beach\n\nHello Sofia,\nWe need 5 units of HZ-240 hydraulic power unit, 380V / 50Hz, IP54 control box and stainless-steel enclosure. Please include one spare seal kit per unit.\nShip CIF Long Beach, USA. Our target delivery is 20 August 2026.\nPlease quote in USD. We have approved USD 2,400 per unit from your current catalog. Freight budget confirmed by our forwarder: USD 1,800.\nBuyer: Pacific Trading Group\nContact: Maria Lopez, maria.lopez@pacific-trading.example\nPayment preference: 30% deposit, 70% before shipment.\nBest regards,\nMaria`
  await page.locator('textarea[name="inquiry[source_text]"]').fill(inquiry)
  await pause(page)
  await page.locator('form[action="/inquiries"] input[type="submit"]').click()
  await page.waitForLoadState("networkidle", { timeout: 120000 })
  await pause(page, 1800)
  await explain(page, "05 · 只核对关键结果", "补齐买家、商品、价格与运费来源。缺失信息保持可见，不让 AI 猜金额。")

  await fillIf(page, 'input[name="inquiry[extracted_data][customer]"]', "Pacific Trading Group")
  await fillIf(page, 'input[name="inquiry[extracted_data][contact_name]"]', "Maria Lopez")
  await fillIf(page, 'input[name="inquiry[extracted_data][contact_email]"]', "maria.lopez@pacific-trading.example")
  await fillIf(page, 'input[name="inquiry[extracted_data][country]"]', "United States")
  await fillIf(page, 'input[name="inquiry[extracted_data][currency]"]', "USD")
  await fillIf(page, 'input[name="inquiry[extracted_data][commercial_terms][destination]"]', "Long Beach, USA")
  await fillIf(page, 'input[name="inquiry[extracted_data][commercial_terms][incoterm]"]', "CIF Long Beach")
  await fillIf(page, 'input[name="inquiry[extracted_data][commercial_terms][delivery]"]', "2026-08-20")
  await fillIf(page, 'input[name="inquiry[extracted_data][commercial_terms][packing]"]', "出口胶合板箱")
  await fillIf(page, 'input[name="inquiry[extracted_data][commercial_terms][freight_amount]"]', "1800")
  await selectIf(page, 'select[name="inquiry[extracted_data][commercial_terms][freight_source]"]', "freight_forwarder_quote")
  await fillIf(page, 'input[name^="inquiry[extracted_data][products]"][name$="[name]"]', "HZ-240 液压动力单元")
  await fillIf(page, 'input[name^="inquiry[extracted_data][products]"][name$="[model]"]', "HZ-240")
  await fillIf(page, 'input[name^="inquiry[extracted_data][products]"][name$="[quantity]"]', "5")
  await fillIf(page, 'input[name^="inquiry[extracted_data][products]"][name$="[unit]"]', "台")
  const inquiryPrices = page.locator('input[name^="inquiry[extracted_data][products]"][name$="[unit_price]"]')
  for (let index = 0; index < await inquiryPrices.count(); index += 1) await inquiryPrices.nth(index).fill(index === 0 ? "2400" : "120")
  const inquirySources = page.locator('select[name^="inquiry[extracted_data][products]"][name$="[price_source]"]')
  for (let index = 0; index < await inquirySources.count(); index += 1) await inquirySources.nth(index).selectOption("catalog")
  await pause(page, 850)
  const buildQuote = page.getByRole("button", { name: "创建报价草稿", exact: true })
  await buildQuote.scrollIntoViewIfNeeded()
  await pause(page, 800)
  await buildQuote.click()
  await page.waitForLoadState("networkidle", { timeout: 120000 })
  await pause(page, 1800)
  await explain(page, "06 · 进入报价编辑", "询盘信息已带入报价。这里补充客户语言、付款、交付和条款。")

  await selectIf(page, 'select[name="quote[buyer_locale]"]', "en")
  const quotePrices = page.locator('input[name$="[unit_price]"]')
  for (let index = 0; index < await quotePrices.count(); index += 1) await quotePrices.nth(index).fill(index === 0 ? "2400" : "120")
  const quoteSources = page.locator('select[name$="[price_source]"]')
  for (let index = 0; index < await quoteSources.count(); index += 1) await quoteSources.nth(index).selectOption("catalog")
  await fillIf(page, 'input[name="quote[shipping_amount]"]', "1800")
  await selectIf(page, 'select[name="quote[shipping_price_source]"]', "freight_forwarder_quote")
  await fillIf(page, 'input[name="quote[payment_term]"]', "30% deposit, 70% before shipment")
  await fillIf(page, 'input[name="quote[trade_term]"]', "CIF Long Beach")
  await fillIf(page, 'textarea[name="quote[delivery_notes]"]', "Dispatch within 20 working days after deposit. Marine freight to Long Beach included.")
  await fillIf(page, 'textarea[name="quote[terms_text]"]', "Prices valid for 30 days. Warranty: 12 months from shipment.")
  await pause(page)
  await page.locator("#quote-studio-form input[type=submit]").last().click()
  await page.waitForLoadState("networkidle")
  await pause(page, 900)

  const quotePath = new URL(page.url()).pathname.replace(/\/edit$/, "")
  await goto(page, `${quotePath}/preview?locale=zh-CN`)
  await explain(page, "07 · 用客户视角预览", "客户语言设为英文。发布前先检查商品、金额、商务条款和移动端阅读结构。")
  await page.evaluate(() => window.scrollTo({ top: document.body.scrollHeight * 0.55, behavior: "smooth" }))
  await pause(page, 1200)
  await goto(page, `${quotePath}/publish?locale=zh-CN`)
  await explain(page, "08 · 确认并发布版本", "只有发布阻塞项全部通过，才能冻结不可变版本并生成客户链接与文件。")
  const publishButton = page.getByRole("button", { name: /发布|Publish/ })
  if (await publishButton.count()) {
    await publishButton.click()
    await page.waitForLoadState("networkidle")
    await pause(page, 1400)
  } else findings.push("发布页仍有阻塞项")

  const version = page.locator(".quote-version-output article").first()
  if (await version.count()) {
    await explain(page, "09 · 交付报价", "发布完成后立即提供客户页面、PDF 和 Excel，不再让销售去其他页面找导出入口。")
    const pdf = version.getByRole("link", { name: "PDF", exact: true })
    const excel = version.getByRole("link", { name: "Excel", exact: true })
    for (const [label, link] of [["PDF", pdf], ["Excel", excel]]) {
      if (!(await link.count())) { findings.push(`${label} 入口缺失`); continue }
      const response = await page.request.get(new URL(await link.getAttribute("href"), page.url()).toString())
      if (!response.ok()) findings.push(`${label} 下载失败：${response.status()}`)
    }
  } else findings.push("发布完成后未看到版本输出区")

  await page.evaluate(() => window.scrollTo({ top: 0, behavior: "smooth" }))
  await pause(page, 1200)
  await context.close()
  await browser.close()
  const source = await video.path()
  const target = path.join(output, `sales-account-full-flow-${stamp}.webm`)
  fs.renameSync(source, target)
  fs.writeFileSync(path.join(output, `sales-account-full-flow-${stamp}.json`), JSON.stringify({ email, video: path.basename(target), findings }, null, 2))
  console.log(JSON.stringify({ email, video: target, findings }, null, 2))
}

main().catch(error => {
  console.error(error)
  process.exitCode = 1
})
