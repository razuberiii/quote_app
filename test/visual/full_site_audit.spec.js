const { test, expect } = require("@playwright/test")
const fs = require("fs")
const path = require("path")

const root = path.resolve(__dirname, "../..")
const seed = JSON.parse(fs.readFileSync(path.join(root, "tmp/visual_review_seed.json"), "utf8"))
const output = path.join(root, "tmp/visual-review/full-site")
const shots = path.join(output, "screenshots")
const findings = []
fs.mkdirSync(shots, { recursive: true })
test.setTimeout(300_000)

async function login(page) {
  await page.goto("/users/sign_in")
  await page.locator('input[name="user[login]"]').fill(seed.email)
  await page.locator('input[name="user[password]"]').fill(seed.password)
  await page.locator('input[type="submit"]').click()
  await expect(page.getByRole("heading", { name: "Inbox", exact: true })).toBeVisible()
}

async function inspect(page, name, viewport) {
  await page.waitForLoadState("networkidle")
  await page.waitForTimeout(180)
  const result = await page.evaluate(() => {
    const width = document.documentElement.clientWidth
    const visible = element => {
      const rect = element.getBoundingClientRect()
      const style = getComputedStyle(element)
      return rect.width > 0 && rect.height > 0 && style.visibility !== "hidden" && style.display !== "none"
    }
    const elements = [...document.querySelectorAll("body *")].filter(visible)
    const overflow = elements.filter(element => {
      const rect = element.getBoundingClientRect()
      const scrollParent = element.parentElement?.closest(".deal-tabs,.library-tabs,.table-responsive,.studio-structure")
      return !scrollParent && (rect.left < -1 || rect.right > width + 1)
    }).slice(0, 12).map(element => ({ tag: element.tagName, class: String(element.className).slice(0, 100) }))
    const lightLeaks = document.body.classList.contains("neo-os--app") ? elements.filter(element => {
      if (element.closest(".studio-paper,.pi-document,.final-document,.document-preview,.buyer-storefront")) return false
      const rect = element.getBoundingClientRect()
      const color = getComputedStyle(element).backgroundColor.replace(/\s/g, "")
      return rect.width > Math.min(520, width * .7) && rect.height > 160 && ["rgb(255,255,255)", "rgb(248,250,252)", "rgb(249,250,251)"].includes(color)
    }).slice(0, 10).map(element => ({ tag: element.tagName, class: String(element.className).slice(0, 100) })) : []
    const clippedText = elements.filter(element => {
      if (element.matches("input,textarea,select")) return false
      const style = getComputedStyle(element)
      return element.childElementCount === 0 && element.textContent.trim().length > 12 &&
        (element.scrollWidth > element.clientWidth + 2 || element.scrollHeight > element.clientHeight + 2) &&
        ["hidden", "clip"].includes(style.overflow)
    }).slice(0, 12).map(element => ({ tag: element.tagName, class: String(element.className).slice(0, 100), text: element.textContent.trim().slice(0, 50) }))
    const brokenImages = [...document.images].filter(image => image.getAttribute("src")?.trim() && image.complete && image.naturalWidth === 0).map(image => image.src)
    return { overflow, lightLeaks, clippedText, brokenImages, pageWidth: width, scrollWidth: document.documentElement.scrollWidth }
  })
  await page.screenshot({ path: path.join(shots, `${name}-${viewport.width}.png`), fullPage: true })
  findings.push({ name, route: new URL(page.url()).pathname + new URL(page.url()).search, viewport, ...result })
  expect.soft(result.overflow, `${name} overflow`).toEqual([])
  expect.soft(result.brokenImages, `${name} broken images`).toEqual([])
}

test.afterAll(() => {
  fs.writeFileSync(path.join(output, "visual-audit-report.json"), JSON.stringify(findings, null, 2))
  const rows = findings.map(item => `| ${item.name} | ${item.viewport.width}×${item.viewport.height} | ${item.route} | ${item.overflow.length} | ${item.lightLeaks.length} | ${item.clippedText.length} | ${item.brokenImages.length} |`).join("\n")
  fs.writeFileSync(path.join(output, "page-inventory.md"), `# Rubusoo full-site visual audit\n\nGenerated ${new Date().toISOString()}. Screenshots are direct browser captures; a baseline must not be refreshed until this report and both contact sheets are reviewed.\n\n| Surface | Viewport | Route | Overflow | Light leaks | Clipped text | Broken images |\n|---|---:|---|---:|---:|---:|---:|\n${rows}\n`)
})

test("public, identity and recovery surfaces", async ({ page }) => {
  const routes = [
    ["home", "/"], ["pricing", "/pricing"], ["seller-demo", "/seller-demo"], ["buyer-demo", "/buyer-demo"],
    ["sign-in", "/users/sign_in"], ["sign-up", "/users/sign_up"], ["email-pending", "/pending-email-verification"],
    ["contact", "/contact"], ["resources", "/resources"], ["privacy", "/privacy"], ["terms", "/terms"], ["sample-quote", "/sample-quote"]
  ]
  for (const viewport of [{ width: 1440, height: 900 }, { width: 390, height: 844 }]) {
    await page.setViewportSize(viewport)
    for (const [name, route] of routes) { await page.goto(route); await inspect(page, name, viewport) }
  }
})

test("authenticated workspace routes, tabs and overlays", async ({ page }) => {
  await login(page)
  const deal = `/deals/${seed.deal_id}`
  const routes = [
    ["inbox", "/inbox"], ["deals", "/deals"], ["deal-overview", deal],
    ["conversation", `${deal}?tab=conversation`], ["versions", `${deal}?tab=versions`], ["documents", `${deal}?tab=documents`],
    ["version-diff", `/quote_revisions/${seed.version_two_id}`], ["delivery", `${deal}/deliver?version_id=${seed.version_two_id}`],
    ["acceptance", `${deal}/acceptance/new?version_id=${seed.version_two_id}`], ["smart-intake-import", "/inquiries/new"],
    ["smart-intake-review", `/inquiries/${seed.inquiry_id}`], ["quote-studio", `/quotes/${seed.edge_deals.no_image}/edit`],
    ["library-products", "/library?section=products"], ["library-presets", "/library?section=presets"],
    ["library-pricing", "/library?section=pricing"], ["library-content", "/library?section=content"],
    ["library-formats", "/library?section=formats"], ["library-brand", "/library?section=brand"], ["library-output", "/library?section=output"],
    ["product-source", `/products/${seed.product_id}`], ["product-new", "/products/new"], ["product-edit", `/products/${seed.product_id}/edit`],
    ["settings", "/company_settings/edit"], ["account", "/users/edit"], ["team", "/team_members"], ["invitations", "/team_invitations"],
    ["missing-price", `/deals/${seed.edge_deals.missing_price}`], ["delivery-failed", `/deals/${seed.edge_deals.delivery_failure}`],
    ["closed-deal", `/deals/${seed.edge_deals.closed}`], ["long-quote", `/quotes/${seed.edge_deals.long_quote}/edit`]
  ]
  for (const viewport of [{ width: 1440, height: 900 }, { width: 390, height: 844 }]) {
    await page.setViewportSize(viewport)
    for (const [name, route] of routes) { await page.goto(route); await inspect(page, name, viewport) }
    await page.goto("/inbox")
    const account = page.locator(".account-menu-trigger")
    if (await account.isVisible()) { await account.click(); await inspect(page, "account-menu", viewport) }
  }
})

test("priority 360 and 412 mobile states", async ({ page }) => {
  await login(page)
  for (const viewport of [{ width: 360, height: 800 }, { width: 412, height: 915 }]) {
    await page.setViewportSize(viewport)
    for (const [name, route] of [["home-priority", "/"], ["inbox-priority", "/inbox"], ["deal-priority", `/deals/${seed.deal_id}`], ["studio-priority", `/quotes/${seed.edge_deals.no_image}/edit`], ["buyer-priority", `/q/${seed.buyer_token}`]]) {
      await page.goto(route); await inspect(page, name, viewport)
    }
  }
})
