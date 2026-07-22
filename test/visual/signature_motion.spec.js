const { test, expect } = require("@playwright/test")
const fs = require("fs")
const path = require("path")

const root = path.resolve(__dirname, "../..")
const seed = JSON.parse(fs.readFileSync(path.join(root, "tmp/visual_review_seed.json"), "utf8"))
const output = path.join(root, "tmp/visual-review/motion")
fs.mkdirSync(output, { recursive: true })

async function login(page) {
  await page.goto("/users/sign_in")
  await page.locator('input[name="user[login]"]').fill(seed.email)
  await page.locator('input[name="user[password]"]').fill(seed.password)
  await page.locator('input[type="submit"]').click()
  await expect(page.locator(".quote-core-index")).toBeVisible()
}

async function saveVideo(page, name) {
  const video = page.video()
  await page.close()
  if (video) await video.saveAs(path.join(output, `${name}.webm`))
}

test("homepage signature transformation is visible", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.goto("/")
  const headline = page.locator(".hero-fixed-headline")
  const text = await headline.innerText()
  const box = await headline.boundingBox()
  await page.waitForTimeout(3000)
  await expect(headline).toHaveText(text)
  expect(await headline.boundingBox()).toEqual(box)
  await saveVideo(page, "homepage-signature-motion")
})

test("Smart Intake evidence and Quote Studio total feedback", async ({ page }) => {
  await login(page)
  await page.goto(`/inquiries/${seed.inquiry_id}`)
  const field = page.locator(".extracted-field").first()
  if (await field.count()) await field.click()
  await page.waitForTimeout(1100)
  await page.goto(`/quotes/${seed.edge_deals.no_image}/edit`)
  const quantity = page.locator('[data-studio-motion-target="quantity"]').first()
  await quantity.fill(String(Number(await quantity.inputValue()) + 1))
  await page.waitForTimeout(1200)
  await saveVideo(page, "intake-and-studio-motion")
})

test("Delivery channel state and Buyer response feedback", async ({ page }) => {
  await login(page)
  await page.goto(`/quotes/${seed.deal_id}/deliver?version_id=${seed.version_two_id}`)
  await page.locator('.channel-option[data-value="email_link_pdf"]').click()
  await page.waitForTimeout(900)
  await page.locator('.channel-option[data-value="external"]').click()
  await page.waitForTimeout(900)
  await page.goto(`/q/${seed.buyer_token}`)
  const plan = page.locator('[data-action*="buyer-room#selectPlan"]').last()
  if (await plan.count()) await plan.click()
  await page.waitForTimeout(900)
  await page.locator('[data-action*="buyer-room#openAccept"]').click()
  await page.waitForTimeout(900)
  await saveVideo(page, "delivery-and-buyer-response-motion")
})

test.use({ reducedMotion: "reduce" })
test("reduced motion keeps the same usable states", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto("/")
  await expect(page.locator(".hero-fixed-headline")).toBeVisible()
  await page.waitForTimeout(1000)
  await saveVideo(page, "reduced-motion")
})
