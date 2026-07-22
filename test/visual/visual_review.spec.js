const { test, expect } = require("@playwright/test")
const AxeBuilder = require("@axe-core/playwright").default
const fs = require("fs")
const path = require("path")
const { execSync } = require("child_process")

const root = path.resolve(__dirname, "../..")
const seed = JSON.parse(fs.readFileSync(path.join(root, "tmp/visual_review_seed.json"), "utf8"))
const output = path.join(root, "tmp/visual-review")
const baseline = path.join(root, "docs/visual-review/current")
const manifest = []
const quality = []
const business = []
const browserSignals = new WeakMap()

fs.mkdirSync(path.join(output, "screenshots"), { recursive: true })
if (process.env.UPDATE_VISUAL_BASELINE === "1") fs.mkdirSync(baseline, { recursive: true })

async function capture(page, name, route, scenario, viewport, options = {}) {
  await page.setViewportSize(viewport)
  // A visual baseline compares layout and art direction, not an arbitrary
  // frame in the homepage type/delete timeline. Motion has its own recorded
  // suite; freeze the marketing story through the product's real reduced-
  // motion path before navigation so consecutive screenshots are identical.
  if (name.startsWith("homepage-")) await page.emulateMedia({ reducedMotion: "reduce" })
  if (!options.keepPage) {
    await page.goto(route)
    await page.waitForLoadState("networkidle")
  }
  await page.waitForTimeout(options.motion === "reduced" ? 50 : 750)
  const file = `${name}.png`
  const target = path.join(output, "screenshots", file)
  if (options.baseline !== false) {
    await expect(page).toHaveScreenshot([file], { fullPage: true, animations: "disabled", maxDiffPixelRatio: 0.015, timeout: 20_000 })
  }
  await page.screenshot({ path: target, fullPage: true })
  const overflowDetails = await page.evaluate(() => ({
    overflow: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
    offenders: [...document.querySelectorAll("body *")].map(element => {
      const rect = element.getBoundingClientRect()
      return { tag: element.tagName, className: String(element.className).slice(0, 120), left: Math.round(rect.left), right: Math.round(rect.right), width: Math.round(rect.width) }
    }).filter(item => item.left < -1 || item.right > document.documentElement.clientWidth + 1).slice(0, 12)
  }))
  const overflow = overflowDetails.overflow
  const brokenImages = await page.locator("img").evaluateAll(images => images.filter(image => image.getAttribute("src")?.trim() && image.complete && image.naturalWidth === 0).map(image => image.src))
  const mobileTypography = viewport.width <= 412 ? await page.evaluate(() => {
    const headings = [...document.querySelectorAll("h1")].filter(element => element.getBoundingClientRect().width > 0)
    const controls = [...document.querySelectorAll("input, textarea, select, button")].filter(element => element.getBoundingClientRect().width > 0)
    return {
      largestHeadingPx: Math.max(0, ...headings.map(element => parseFloat(getComputedStyle(element).fontSize))),
      oversizedControls: controls.map(element => ({ tag: element.tagName, width: Math.round(element.getBoundingClientRect().width) }))
        .filter(element => element.width > document.documentElement.clientWidth)
    }
  }) : null
  quality.push({ name, route, ...overflowDetails, brokenImages })
  expect(overflow, `${name} has horizontal overflow: ${JSON.stringify(overflowDetails.offenders)}`).toBeFalsy()
  expect(brokenImages, `${name} has broken images`).toEqual([])
  if (mobileTypography) {
    expect(mobileTypography.largestHeadingPx, `${name} uses an oversized mobile heading`).toBeLessThanOrEqual(64)
    expect(mobileTypography.oversizedControls, `${name} has controls wider than the viewport`).toEqual([])
  }
  manifest.push({
    commit_sha: process.env.GITHUB_SHA || execSync("git rev-parse HEAD", { cwd: root }).toString().trim(),
    generated_at: new Date().toISOString(), application_version: "Rubusoo Quote Core",
    route, scenario, viewport: `${viewport.width}x${viewport.height}`, locale: "en",
    motion_mode: options.motion || "normal", screenshot_filename: file,
    playwright_test: test.info().title, data_fixture: "VisualReviewSeeder",
    expected_stage: options.stage || null, expected_next_action: options.action || null
  })
}

async function login(page) {
  await page.goto("/users/sign_in?locale=en")
  await page.locator('input[name="user[login]"]').fill(seed.email)
  await page.locator('input[name="user[password]"]').fill(seed.password)
  await page.locator('input[type="submit"]').click()
  await page.goto("/quotes?locale=en")
  await expect(page.locator(".quote-core-index")).toBeVisible()
}

async function audit(page, name) {
  const result = await new AxeBuilder({ page }).analyze()
  quality.push({ name, accessibility_violations: result.violations.map(item => ({ id: item.id, impact: item.impact, nodes: item.nodes.length })) })
  expect(result.violations.filter(item => ["critical", "serious"].includes(item.impact)), `${name} serious accessibility violations`).toEqual([])
}

test.afterAll(async () => {
  fs.writeFileSync(path.join(output, "manifest.json"), JSON.stringify(manifest, null, 2))
  fs.writeFileSync(path.join(output, "accessibility-and-quality.json"), JSON.stringify(quality, null, 2))
  fs.writeFileSync(path.join(output, "business-flow-report.json"), JSON.stringify(business, null, 2))
  if (process.env.UPDATE_VISUAL_BASELINE === "1") fs.writeFileSync(path.join(baseline, "manifest.json"), JSON.stringify(manifest, null, 2))
})

test("public product story and commercial entry points", async ({ page }) => {
  await capture(page, "homepage-desktop", "/", "marketing-product-story", { width: 1440, height: 900 })
  await capture(page, "homepage-mobile", "/", "marketing-product-story", { width: 390, height: 844 })
  await capture(page, "pricing-desktop", "/pricing", "pricing", { width: 1440, height: 900 })
  await capture(page, "pricing-mobile", "/pricing", "pricing", { width: 390, height: 844 })
  await capture(page, "seller-demo", "/seller-demo", "seller-demo", { width: 1440, height: 900 })
  await capture(page, "buyer-demo", "/buyer-demo", "buyer-demo", { width: 1440, height: 900 })
  await audit(page, "public buyer demo")
})

test("seller Quote workspace desktop", async ({ page }) => {
  await login(page)
  const quote = `/quotes/${seed.deal_id}`
  await capture(page, "seller-quotes", "/quotes", "quote-lifecycle", { width: 1440, height: 900 })
  await capture(page, "seller-quote-overview", quote, "quote-overview", { width: 1440, height: 900 })
  await capture(page, "seller-activity", `${quote}?tab=activity`, "customer-activity", { width: 1440, height: 900 })
  await capture(page, "seller-versions", `${quote}?tab=versions`, "published-outputs", { width: 1440, height: 900 })
  await capture(page, "seller-version-diff", `/quote_revisions/${seed.version_two_id}`, "version-difference", { width: 1440, height: 900 })
  await capture(page, "seller-delivery-chooser", `${quote}/deliver?version_id=${seed.version_two_id}`, "multi-channel-delivery", { width: 1440, height: 900 })
  await capture(page, "seller-record-acceptance", `${quote}/acceptance/new?version_id=${seed.version_two_id}`, "external-acceptance", { width: 1440, height: 900 })
  await capture(page, "seller-library-products", "/library?section=products", "library-products", { width: 1440, height: 900 })
  await capture(page, "seller-document-design", "/document_design/edit", "document-design", { width: 1440, height: 900 })
  await capture(page, "seller-customers", "/customers", "customers", { width: 1440, height: 900 })
  await capture(page, "seller-import-hub", "/imports", "AI-import", { width: 1440, height: 900 })
  await capture(page, "seller-settings", "/company_settings/edit", "completion-settings", { width: 1440, height: 900 })
  await capture(page, "seller-inquiry-import", "/inquiries/new", "inquiry-import", { width: 1440, height: 900 })
  await capture(page, "seller-smart-intake", `/inquiries/${seed.inquiry_id}`, "smart-intake-review", { width: 1440, height: 900 })
  await capture(page, "seller-quote-studio", `/quotes/${seed.edge_deals.no_image}/edit`, "working-draft", { width: 1440, height: 900 })
  await audit(page, "quote studio")
  business.push({ scenario: "visual-workspace", result: test.info().status, evidence: ["seller-versions.png", "seller-activity.png", "buyer-room-desktop.png"] })
})

test("seller workspace real mobile reflow", async ({ page }) => {
  await login(page)
  const quote = `/quotes/${seed.deal_id}`
  await capture(page, "seller-quotes-360", "/quotes", "mobile-quotes", { width: 360, height: 800 })
  await capture(page, "seller-quotes-390", "/quotes", "mobile-quotes", { width: 390, height: 844 })
  await capture(page, "seller-quote-mobile", quote, "mobile-quote", { width: 390, height: 844 })
  await capture(page, "seller-activity-mobile", `${quote}?tab=activity`, "mobile-activity", { width: 390, height: 844 })
  await capture(page, "seller-acceptance-mobile", `${quote}/acceptance/new?version_id=${seed.version_two_id}`, "mobile-external-acceptance", { width: 390, height: 844 })
  await capture(page, "seller-delivery-mobile", `${quote}/deliver?version_id=${seed.version_two_id}`, "mobile-delivery", { width: 412, height: 915 })
  await capture(page, "seller-smart-intake-mobile", `/inquiries/${seed.inquiry_id}`, "mobile-smart-intake", { width: 390, height: 844 })
})

test("Buyer Room current, selection and acceptance", async ({ page }) => {
  const room = `/q/${seed.buyer_token}`
  await capture(page, "buyer-room-desktop", room, "buyer-room", { width: 1440, height: 900 })
  const selectable = page.locator('[data-action*="buyer-room#selectPlan"]').first()
  if (await selectable.count()) await selectable.click()
  await capture(page, "buyer-configuration-change", room, "configuration-change", { width: 1440, height: 900 }, { keepPage: true })
  await page.locator('[data-action*="buyer-room#openChanges"]').click()
  await capture(page, "buyer-request-changes", room, "request-changes", { width: 1440, height: 900 }, { keepPage: true })
  await page.keyboard.press("Escape")
  await page.locator('[data-action*="buyer-room#openAccept"]').click()
  await capture(page, "buyer-acceptance", room, "acceptance", { width: 1440, height: 900 }, { keepPage: true })
  await page.keyboard.press("Escape")
  for (const [width, height] of [[360,800],[390,844],[412,915]]) await capture(page, `buyer-room-${width}`, room, "mobile-buyer-room", { width, height })
  await page.locator('[data-action*="buyer-room#openChanges"]').click()
  await capture(page, "buyer-request-changes-mobile", room, "mobile-request-changes", { width: 390, height: 844 }, { keepPage: true })
  await page.keyboard.press("Escape")
  await page.locator('[data-action*="buyer-room#openAccept"]').click()
  await capture(page, "buyer-acceptance-mobile", room, "mobile-acceptance", { width: 390, height: 844 }, { keepPage: true })
  await audit(page, "buyer acceptance")
})

test("edge conditions remain explicit", async ({ page }) => {
  await login(page)
  await capture(page, "edge-empty-quotes", "/quotes?q=no-such-quote-visual", "empty-quotes", { width: 1440, height: 900 })
  await capture(page, "edge-missing-price", `/quotes/${seed.edge_deals.missing_price}`, "missing-price", { width: 1440, height: 900 })
  await capture(page, "edge-no-product-image", `/quotes/${seed.edge_deals.no_image}`, "no-product-image", { width: 1440, height: 900 })
  await capture(page, "edge-long-quote-50-products", `/quotes/${seed.edge_deals.long_quote}/edit`, "50-products", { width: 1440, height: 900 })
  await capture(page, "edge-delivery-failure", `/quotes/${seed.edge_deals.delivery_failure}?tab=versions`, "delivery-failure", { width: 1440, height: 900 })
  await capture(page, "edge-po-difference", `/quotes/${seed.deal_id}?tab=activity`, "po-difference", { width: 1440, height: 900 })
  await capture(page, "edge-old-version", `/q/${seed.old_buyer_token}`, "superseded-version", { width: 1440, height: 900 })
  await capture(page, "edge-closed-quote", `/quotes/${seed.edge_deals.closed}`, "closed-quote", { width: 1440, height: 900 })
  business.push({ scenario: "edge-state-rendering", result: test.info().status,
    evidence: ["edge-po-difference.png", "edge-delivery-failure.png", "edge-closed-quote.png"] })
})

test.use({ reducedMotion: "reduce" })
test("reduced motion preserves channel actions", async ({ page }) => {
  await login(page)
  await capture(page, "reduced-motion-delivery", `/quotes/${seed.deal_id}/deliver?version_id=${seed.version_two_id}`,
    "reduced-motion", { width: 390, height: 844 }, { motion: "reduced" })
  await expect(page.locator('input[type="submit"]')).toBeEnabled()
})
test.beforeEach(async ({ page }) => {
  const signals = { consoleErrors: [], failedRequests: [] }
  browserSignals.set(page, signals)
  page.on("console", message => { if (message.type() === "error") signals.consoleErrors.push(message.text()) })
  page.on("requestfailed", request => {
    if (new URL(request.url()).origin === new URL(page.url() || "http://127.0.0.1:3100").origin) signals.failedRequests.push(`${request.method()} ${request.url()}`)
  })
})

test.afterEach(async ({ page }, testInfo) => {
  const signals = browserSignals.get(page) || { consoleErrors: [], failedRequests: [] }
  quality.push({ name: testInfo.title, ...signals })
  expect(signals.consoleErrors, "JavaScript console errors").toEqual([])
  expect(signals.failedRequests, "Failed same-origin network requests").toEqual([])
})
