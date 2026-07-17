const { test, expect } = require("@playwright/test")
const fs = require("fs")
const path = require("path")
const ExcelJS = require("exceljs")

const root = path.resolve(__dirname, "../..")
const seed = JSON.parse(fs.readFileSync(path.join(root, "tmp/visual_review_seed.json"), "utf8"))
const output = path.join(root, "tmp/visual-review")

async function login(page) {
  await page.goto("/users/sign_in")
  await page.locator('input[name="user[login]"]').fill(seed.email)
  await page.locator('input[name="user[password]"]').fill(seed.password)
  await page.locator('input[type="submit"]').click()
  await expect(page.getByRole("heading", { name: "Inbox", exact: true })).toBeVisible()
}

test("scenario A executes publish, email, buyer request and immutable acceptance", async ({ page, context }) => {
  await login(page)
  await page.goto(`/quotes/${seed.e2e_deal_id}/edit`)
  await page.getByRole("link", { name: "Review & publish" }).click()
  await page.getByRole("button", { name: "Publish Revision 1" }).click()
  await expect(page.getByText(/Published Version 1/).first()).toBeVisible()

  await page.locator('.channel-option[data-value="email_link"]').click()
  await page.locator('.delivery-email-panel input[name="version_delivery[recipient]"]').fill("buyer-flow@example.com")
  await page.locator('input[name="version_delivery[subject]"]').fill("Rubusoo E2E Version 1")
  await page.locator('textarea[name="version_delivery[message_body]"]').fill("Please review the immutable Version.")
  await page.getByRole("button", { name: "Deliver Version" }).click()
  await expect(page.getByText("Version delivered successfully.")).toBeVisible()

  await page.goto(`/deals/${seed.e2e_deal_id}?tab=versions`)
  await expect(page.getByText(/Email link · Sent/i)).toBeVisible()
  await page.getByRole("link", { name: "Deliver current Version" }).count().catch(() => 0)

  await page.goto(`/deals/${seed.e2e_deal_id}/deliver`)
  const roomUrl = await page.locator(".delivery-link-row input").inputValue()
  await page.goto(roomUrl)
  await page.locator('[data-action*="buyer-room#openChanges"]').click()
  await page.locator('dialog[open] input[name="buyer_name"]').fill("Anna Flow")
  await page.locator('dialog[open] input[name="buyer_email"]').fill("anna-flow@example.com")
  await page.locator('dialog[open] textarea[name="message"]').fill("Please increase the first machine quantity to 3.")
  await page.getByRole("button", { name: "Send request" }).click()
  await expect(page).toHaveURL(/event=changes-requested/)

  await page.goto(`/deals/${seed.e2e_deal_id}`)
  await expect(page.getByText("Prepare new version", { exact: true }).first()).toBeVisible()
  await page.goto(`/quotes/${seed.e2e_deal_id}/edit`)
  await page.locator('input[name$="[quantity]"]').first().fill("3")
  await page.getByRole("button", { name: "Save quote" }).click()
  await expect(page.getByRole("button", { name: "Publish Revision 2" })).toBeVisible()
  await page.getByRole("button", { name: "Publish Revision 2" }).click()
  await expect(page.getByText(/Published Version 2/).first()).toBeVisible()
  const versionTwoRoomUrl = await page.locator(".delivery-link-row input").inputValue()

  await page.goto(roomUrl)
  await expect(page.getByText("Superseded", { exact: true })).toBeVisible()
  await expect(page.getByRole("button", { name: "Accept quote" })).toHaveCount(0)
  await page.goto(versionTwoRoomUrl)
  await page.locator('[data-action*="buyer-room#openAccept"]').click()
  await page.locator('dialog[open] input[name="name"]').fill("Anna Flow")
  await page.locator('dialog[open] input[name="email"]').fill("anna-flow@example.com")
  await page.locator('dialog[open] input[type="checkbox"]').check()
  await page.getByRole("button", { name: "Confirm acceptance" }).click()
  await expect(page).toHaveURL(/event=accepted/)
  await expect(page.getByText(/accepted/i).first()).toBeVisible()

  await page.goto(`/deals/${seed.e2e_deal_id}?tab=documents`)
  await page.locator('select[name="document_type"]').selectOption("order_confirmation")
  await Promise.all([
    page.waitForURL(/\/final_documents\/\d+$/, { timeout: 60000 }),
    page.getByRole("button", { name: "Generate file" }).click()
  ])
  await expect(page.getByRole("heading", { name: "Order Confirmation" })).toBeVisible()
  const download = await Promise.all([page.waitForEvent("download"), page.getByRole("link", { name: "Download" }).click()])
  expect((await download[0].createReadStream())).toBeTruthy()
  await page.goto(`/deals/${seed.e2e_deal_id}`)
  await page.getByRole("button", { name: "Close as won" }).click()
  await expect(page.getByText("Deal closed as won.")).toBeVisible()
  await expect(page.getByText("Closed", { exact: true }).first()).toBeVisible()

  fs.writeFileSync(path.join(output, "business-flow-executed.json"), JSON.stringify({
    scenario: "A", result: "passed", operations: ["publish_v1", "email_link", "buyer_request", "working_update", "publish_v2", "old_version_read_only", "acceptance", "order_confirmation", "close_won"],
    deal_id: seed.e2e_deal_id, executed_at: new Date().toISOString()
  }, null, 2))
})

test("returned Excel executes download, edit, upload, review, apply and publish V2", async ({ page }) => {
  await login(page)
  const dealId = seed.e2e_excel_deal_id
  await page.goto(`/quotes/${dealId}/edit`)
  await page.getByRole("link", { name: "Review & publish" }).click()
  await page.getByRole("button", { name: "Publish Revision 1" }).click()
  await page.locator('.channel-option[data-value="excel_export"]').click()
  await page.getByRole("button", { name: "Generate file" }).click()
  await expect(page).toHaveURL(new RegExp(`/deals/${dealId}.*tab=documents`))

  const downloadPromise = page.waitForEvent("download")
  await page.getByRole("link", { name: "Download" }).first().click()
  const download = await downloadPromise
  const originalPath = path.join(output, "returned-excel-original.xlsx")
  await download.saveAs(originalPath)
  const workbook = new ExcelJS.Workbook()
  await workbook.xlsx.readFile(originalPath)
  const sheet = workbook.getWorksheet("Published quote")
  const headerRow = sheet.getRow(5)
  const quantityColumn = headerRow.values.findIndex(value => value === "Quantity")
  const priceColumn = headerRow.values.findIndex(value => value === "Unit_price")
  sheet.getRow(6).getCell(quantityColumn).value = 4
  sheet.getRow(6).getCell(priceColumn).value = 49_250
  const modifiedPath = path.join(output, "returned-excel-buyer-modified.xlsx")
  await workbook.xlsx.writeFile(modifiedPath)

  await page.goto(`/deals/${dealId}/responses/new`)
  await page.locator('select[name="deal_response[kind]"]').selectOption("returned_excel")
  await page.locator('select[name="deal_response[source]"]').selectOption("excel")
  await page.locator('input[name="deal_response[attachment]"]').setInputFiles(modifiedPath)
  await page.getByRole("button", { name: "Add to Conversation" }).click()
  await expect(page.getByText("Structured review")).toBeVisible()
  await expect(page.locator('.response-change strong').filter({ hasText: /quantity/i }).first()).toBeVisible()
  await page.screenshot({ path: path.join(output, "returned-excel-review.png"), fullPage: true })
  await page.getByRole("button", { name: "Apply selected changes to Working draft" }).click()
  await expect(page).toHaveURL(new RegExp(`/quotes/${dealId}/edit`))
  await expect(page.locator('input[name$="[quantity]"][value="4"]')).toHaveCount(1)
  await page.getByRole("button", { name: "Save quote" }).click()
  await page.getByRole("button", { name: "Publish Revision 2" }).click()
  await expect(page.getByText(/Published Version 2/).first()).toBeVisible()

  fs.writeFileSync(path.join(output, "returned-excel-flow.json"), JSON.stringify({
    scenario: "returned_excel", result: "passed", deal_id: dealId,
    assertions: ["downloaded_v1", "modified_quantity_and_price", "uploaded", "diff_visible", "applied_to_draft", "published_v2"]
  }, null, 2))
})
