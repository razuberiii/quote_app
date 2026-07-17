const { test, expect } = require("@playwright/test")
const fs = require("fs")
const path = require("path")

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
  const publish = await context.request.post("/quote_revisions", { form: { quote_id: seed.e2e_deal_id } })
  expect(publish.ok()).toBeTruthy()
  await page.goto(publish.url())
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
  await expect(page.getByRole("heading", { name: "Prepare new version" })).toBeVisible()
  await page.goto(`/quotes/${seed.e2e_deal_id}/edit`)
  await page.locator('input[name$="[quantity]"]').first().fill("3")
  await page.getByRole("button", { name: "Save quote" }).click()
  await expect(page.getByRole("button", { name: "Publish Revision 2" })).toBeVisible()
  const publishUpdate = await context.request.post("/quote_revisions", { form: { quote_id: seed.e2e_deal_id } })
  expect(publishUpdate.ok()).toBeTruthy()
  await page.goto(publishUpdate.url())
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
    page.waitForURL(/\/final_documents\/\d+$/, { timeout: 30000 }),
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
