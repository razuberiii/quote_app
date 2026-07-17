const { defineConfig } = require("@playwright/test")

module.exports = defineConfig({
  testDir: "./test/visual",
  timeout: 120_000,
  expect: { timeout: 8_000 },
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: [["list"], ["html", { outputFolder: "tmp/visual-review/html-report", open: "never" }]],
  snapshotPathTemplate: "{testDir}/../../docs/visual-review/current/{arg}{ext}",
  use: {
    baseURL: process.env.VISUAL_BASE_URL || "http://127.0.0.1:3100",
    browserName: "chromium",
    headless: true,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: { mode: "on", size: { width: 1280, height: 720 } },
    reducedMotion: "no-preference"
  },
  outputDir: "tmp/visual-review/test-results"
})
