# Rubusoo visual and business-flow review

This folder is the public, repeatable audit entry point for Rubusoo’s Deal-first product. The committed files under [`current/`](current/) are compressed baseline screenshots from deterministic test data. Every push to `main` also runs the **Visual Review** GitHub Action and uploads the full-resolution screenshots, raw browser videos, Playwright HTML report, accessibility/quality report, manifest, traces on failure and business-flow report.

## Run locally

Use a disposable test database only:

```bash
RAILS_ENV=test bundle exec rails db:prepare
RAILS_ENV=test bundle exec rails visual_review:seed
RAILS_ENV=test bundle exec rails server -p 3100
npx playwright install chromium
npx playwright test
```

`full_site_audit.spec.js` is the authenticated crawler. It visits public identity pages, every Deal tab, all Library sections, Settings/Team/Invitations, dialogs, edge states, and priority mobile widths. It writes 91 direct browser captures plus `full-site/page-inventory.md` and `full-site/visual-audit-report.json`. The workflow then builds fixed-cell desktop and mobile contact sheets; these must be inspected before updating a baseline.

To refresh the committed baseline, run Playwright with both `UPDATE_VISUAL_BASELINE=1` and `--update-snapshots`. A normal run uses `toHaveScreenshot` against the committed PNGs and fails when the pixel-difference ratio exceeds 1.5%. Review every expected/actual/diff image before committing a baseline update; CI never overwrites it.

## Audit data

`VisualReviewSeeder` creates the fictional workspace **Northstar Motion Systems**, buyer **Helix Process GmbH**, three machinery products, two immutable Published Versions, Buyer Room activity, WhatsApp delivery, a PO difference, failed delivery, missing-price Deal, no-image Deal, 50-item Deal and closed Deal. It runs only in `test` and writes identifiers to the ignored file `tmp/visual_review_seed.json`.

Demo login for the disposable visual database:

- Email: `visual@rubusoo.example`
- Password: `RubusooVisual!2026`

No production customer, uploads, credentials, API keys, logs or database backups are used.

## Evidence map

- Public: homepage, pricing and both demos.
- Seller: Inbox, Deals, Overview, Smart Intake, Quote Studio, Delivery chooser, Conversation, Versions, diff, Documents, external Acceptance, Library and Settings.
- Buyer: live Buyer Room, configuration, change request and Acceptance on desktop and real 360/390/412 widths.
- Edge cases: missing price, no image, 50 items, delivery failure, PO difference, superseded Version and closed Deal.
- Motion: `signature_motion.spec.js` records the homepage transformation, Smart Intake evidence/Studio price feedback, Delivery/Buyer response transition, and a `prefers-reduced-motion: reduce` run. The reduced-motion path retains the same content and controls.

The committed baseline is intentionally compressed. Browser videos are generated from real Playwright sessions and exist only in the GitHub Actions Artifact to avoid growing Git history.

## Download an Artifact

Open the repository’s **Actions → Visual Review → latest successful run**, then download `rubusoo-visual-review-<commit-sha>`. Open `html-report/index.html` for the navigable report. The Artifact is retained for 30 days.

## Reports

- `manifest.json`: route, scenario, viewport, motion mode, fixture, expected stage and expected Next action.
- `accessibility-and-quality.json`: axe results, horizontal overflow and broken-image checks.
- `business-flow-report.json` and `business-flow-executed.json`: rendered-state evidence and operations completed by the browser flow.
- `test-results/`: Playwright videos and failure traces.
- `motion/`: named WebM recordings of real state transitions, not page-load-only videos.
- `full-site/`: the page inventory, audit findings, all desktop/mobile captures, and both contact sheets.

Color contrast remains enabled and critical or serious axe violations fail the workflow. JavaScript console errors and failed same-origin requests are captured by Playwright’s test failure artifacts and server log.
