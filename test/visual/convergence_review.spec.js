const { test, expect } = require("@playwright/test")
const fs = require("fs")
const path = require("path")

const output = path.resolve(process.env.CONVERGENCE_REVIEW_OUTPUT || "tmp/review_shots/product-convergence-20260718")
fs.mkdirSync(output, { recursive: true })

async function capture(page, name, route, viewport) {
  await page.setViewportSize(viewport)
  await page.goto(route)
  await page.waitForLoadState("networkidle")
  await page.screenshot({ path: path.join(output, `${name}-${viewport.width}.png`), fullPage: true })
  const audit = await page.evaluate(() => ({
    width: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
    missingTranslations: document.body.innerText.match(/translation missing/gi) || [],
    visibleEnglish: [...document.querySelectorAll("h1,h2,h3,p,button,a,label,small")]
      .filter(element => element.offsetParent && /[A-Za-z]{4,}/.test(element.textContent))
      .map(element => element.textContent.trim().replace(/\s+/g, " ").slice(0, 100)).slice(0, 30)
  }))
  expect(audit.scrollWidth).toBeLessThanOrEqual(audit.width + 1)
  expect(audit.missingTranslations).toEqual([])
}

async function login(page) {
  await page.goto("/users/sign_in")
  await page.locator('input[name="user[login]"]').fill("visual@rubusoo.example")
  await page.locator('input[name="user[password]"]').fill("RubusooVisual!2026")
  await page.locator('input[type="submit"]').click()
  await expect(page.getByRole("heading", { name: "待办收件箱", exact: true })).toBeVisible()
}

test("public and authenticated convergence pages", async ({ page }) => {
  for (const viewport of [{ width: 1440, height: 900 }, { width: 390, height: 844 }]) {
    await capture(page, "home", "/", viewport)
    await capture(page, "pricing", "/pricing", viewport)
    if (viewport.width < 500) {
      await page.goto("/pricing")
      await page.locator(".navbar-toggle").click()
      await page.screenshot({ path: path.join(output, `marketing-menu-open-${viewport.width}.png`), fullPage: true })
    }
    await page.evaluate(() => localStorage.setItem("rubusoo-theme", "dark"))
    await capture(page, "home-dark", "/", viewport)
    await page.evaluate(() => localStorage.setItem("rubusoo-theme", "light"))
    const heroText = await page.locator(".hero-fixed-headline").innerText()
    const heroBox = await page.locator(".hero-fixed-headline").boundingBox()
    await page.waitForTimeout(3000)
    expect(await page.locator(".hero-fixed-headline").innerText()).toBe(heroText)
    expect(await page.locator(".hero-fixed-headline").boundingBox()).toEqual(heroBox)
    await capture(page, "sign-in", "/users/sign_in", viewport)
    await capture(page, "sign-up", "/users/sign_up", viewport)
    if (process.env.PUBLIC_ONLY === "1") continue
    await login(page)
    await capture(page, "inquiry-import", "/inquiries/new", viewport)
    await capture(page, "deals", "/deals", viewport)
    const firstDealPath = await page.locator('.deal-row__identity').first().getAttribute('href').catch(() => null)
    if (firstDealPath) await capture(page, "deal-detail", firstDealPath, viewport)
    await capture(page, "account-settings", "/users/edit", viewport)
    await capture(page, "library", "/library", viewport)
    await capture(page, "catalog-import", "/library/catalog-imports/new", viewport)
    await capture(page, "company-settings", "/company_settings/edit", viewport)
    await capture(page, "company-import", "/settings/company-imports/new", viewport)
    await capture(page, "team", "/team_members", viewport)
    if (viewport.width < 500) {
      await page.goto("/library")
      await page.locator(".navbar-toggle").click()
      await page.screenshot({ path: path.join(output, `app-menu-open-${viewport.width}.png`), fullPage: true })
      const bell = page.locator(".notification-bell-trigger")
      if (await bell.isVisible()) { await bell.click(); await page.screenshot({ path: path.join(output, `notifications-open-${viewport.width}.png`), fullPage: true }) }
      await page.locator(".notification-bell-dropdown").evaluate(element => element.removeAttribute("open"))
      await page.locator(".theme-switch").click()
      await expect(page.locator("html")).toHaveAttribute("data-theme", "dark")
      await page.screenshot({ path: path.join(output, `app-dark-${viewport.width}.png`), fullPage: true })
    }
    await page.context().clearCookies()
  }
})
