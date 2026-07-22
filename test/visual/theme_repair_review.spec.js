const { test, expect } = require("@playwright/test")
const fs = require("fs")
const path = require("path")

const output = path.resolve(process.env.THEME_REVIEW_OUTPUT || "tmp/review_shots/theme-repair-20260719")
fs.mkdirSync(output, { recursive: true })

async function shot(page, name) {
  await page.waitForLoadState("networkidle")
  await page.screenshot({ path: path.join(output, `${name}.png`), fullPage: true })
  const sizes = await page.evaluate(() => ({ width: document.documentElement.clientWidth, scroll: document.documentElement.scrollWidth }))
  expect(sizes.scroll).toBeLessThanOrEqual(sizes.width + 1)
}

async function viewportShot(page, name) {
  await page.screenshot({ path: path.join(output, `${name}.png`) })
}

async function login(page) {
  await page.goto("/users/sign_in")
  await page.locator('input[name="user[login]"]').fill("visual@rubusoo.example")
  await page.locator('input[name="user[password]"]').fill("RubusooVisual!2026")
  await page.locator('input[type="submit"]').click()
  await expect(page.getByRole("heading", { name: "待办收件箱", exact: true })).toBeVisible()
}

test("theme, inquiry and navigation repair", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto("/")
  await page.evaluate(() => localStorage.setItem("rubusoo-theme", "dark"))
  await page.reload()
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark")
  const initialPhase = await page.locator(".product-hero").getAttribute("data-story-phase")
  await page.waitForTimeout(3000)
  expect(await page.locator(".product-hero").getAttribute("data-story-phase")).not.toBe(initialPhase)
  await shot(page, "marketing-dark-390")
  await viewportShot(page, "marketing-dark-fold-390")
  await page.goto("/pricing")
  await shot(page, "pricing-dark-390")
  await viewportShot(page, "pricing-dark-fold-390")
  await page.locator(".navbar-toggle").click()
  await page.locator(".theme-switch").click()
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light")

  await login(page)
  await page.goto("/inquiries/new")
  await shot(page, "inquiry-light-390")
  await viewportShot(page, "inquiry-light-fold-390")
  await page.goto("/users/edit")
  await shot(page, "account-light-390")
  await viewportShot(page, "account-light-fold-390")

  await page.locator(".navbar-toggle").click()
  await page.locator(".account-menu-trigger").click()
  await shot(page, "account-menu-light-390")
  await page.locator(".theme-switch").click()
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark")
  await shot(page, "account-menu-dark-390")
  await page.locator(".navbar-toggle").click()
  await page.goto("/inquiries/new")
  await shot(page, "inquiry-dark-390")
  await page.goto("/company_settings/edit")
  await shot(page, "company-dark-390")
  await viewportShot(page, "company-dark-fold-390")
  await page.locator(".theme-switch").evaluate(button => button.click())
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light")
  await shot(page, "company-light-390")
  await viewportShot(page, "company-light-fold-390")
})
