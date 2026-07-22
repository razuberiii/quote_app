const { test } = require("@playwright/test")
const fs = require("fs")
const path = require("path")

const output = path.resolve("tmp/review_shots/motion-benchmarks-20260719")
fs.mkdirSync(output, { recursive: true })

for (const sample of [
  ["linear", "https://linear.app/"],
  ["raycast", "https://www.raycast.com/"],
  ["stripe", "https://stripe.com/"],
  ["framer", "https://www.framer.com/"]
]) {
  test(`${sample[0]} motion reference`, async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    await page.goto(sample[1], { waitUntil: "domcontentloaded", timeout: 60_000 })
    await page.waitForTimeout(1800)
    await page.screenshot({ path: path.join(output, `${sample[0]}-fold.png`) })
    for (let index = 0; index < 4; index += 1) {
      await page.mouse.wheel(0, 560)
      await page.waitForTimeout(700)
    }
    await page.screenshot({ path: path.join(output, `${sample[0]}-scroll.png`) })
  })
}
