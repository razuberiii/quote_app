# Chat-to-quote draft preparation plan

## 1. Context and Goal
- Project/area: Chat Sync, Smart Intake, and quote draft creation.
- Why now: Captured conversations reach an Inquiry, but sellers still copy product-library details and prices manually.
- Target outcome: Present one recommended draft preparation plus up to three explainable Catalog candidates per requested product, then carry the seller's confirmed choices into Quote Studio.
- Out of scope: Invented pricing, automatic freight calculation, arbitrary-site scraping, and sending or publishing a quote without seller review.
- Business value / success metric: A seller can turn a supported chat into an editable quote draft by reviewing exceptions instead of re-entering known Catalog data.
- Delivery deadline (if any): Current implementation cycle.

## 2. Current Problems
- Problem A: Catalog candidates are token matches and do not explain specification, currency, MOQ, or price readiness.
- Problem B: Selecting a candidate does not populate the proposed description, SKU, unit, lead time, specifications, or evidence-backed Catalog price.
- Problem C: The review UI hides non-standard extracted specifications and provides no concise draft summary.
- Existing workaround and why it is insufficient: Sellers manually copy values from the Catalog and can overlook currency or MOQ conflicts.

## 3. Scope and Constraints
- Scope (explicit pages/modules/files): Inquiry matching/preparation services, inquiry review controller/view, related Stimulus behavior, tests, and Smart Intake CSS documentation.
- Business logic policy (allowed / not allowed): Catalog values may be proposed with source labels; missing or currency-mismatched prices remain unpriced; seller confirmation is required before quote publication.
- Visual/UX policy: Reuse the open editorial `inquiry-*` family; show a recommended action first and alternatives as compact rows.
- Risk boundaries: Do not mutate the Inquiry while viewing it and do not create a Quote until the seller submits the review.
- Non-negotiable constraints (performance/compliance/compatibility): Company-scoped products only, deterministic ranking, mobile usability, evidence retained.

## 4. Execution Roadmap

### Phase 1 - Explainable draft preparation
Status: `Completed`

Goals (outcome):
- Produce deterministic, quote-ready candidate payloads from extracted requirements and Catalog facts.

Implementation actions (must be executable):
- [x] Rank candidates using identity and specification evidence.
- [x] Mark price, currency, MOQ, and missing-field risks without guessing values.

Deliverables (must be tangible):
- Code files: preparation/matching services and unit tests.
- Docs updated: this plan.
- Test cases added/updated: service candidate ranking and pricing safety.

Acceptance (must be verifiable):
- [x] Behavior acceptance: Matching-currency Catalog prices can be proposed; incompatible prices cannot.
- [x] Channel/output acceptance: Results are independent of WhatsApp versus Alibaba ingestion.
- [x] Regression acceptance: An empty Catalog still permits an unpriced draft.

Evidence required:
- Commands/checks run: focused Rails service tests.
- Screenshot/PDF paths: Phase 3.
- Notes on what could not be verified: recorded in progress log.

### Phase 2 - Human confirmation workflow
Status: `Completed`

Goals (outcome):
- Let the seller apply a recommended or alternative candidate with one action while preserving editable fields.

Implementation actions (must be executable):
- [x] Add the preparation summary and candidate controls to Inquiry review.
- [x] Populate candidate-backed fields via the existing Inquiry Stimulus controller.
- [x] Render all extracted specification keys rather than a fixed shortlist.

Deliverables (must be tangible):
- Code files: inquiry controller/view/Stimulus/CSS.
- Docs updated: `docs/css-components.md`.
- Test cases added/updated: controller/UI submission coverage.

Acceptance (must be verifiable):
- [x] Behavior acceptance: One click applies a candidate and submitted values create the expected Quote item.
- [x] Channel/output acceptance: Keyboard and touch users can operate the selection.
- [x] Regression acceptance: Manual deal-only items remain available.

Evidence required:
- Commands/checks run: controller and JavaScript tests/build.
- Screenshot/PDF paths: dedicated `tmp/review_shots/` run.
- Notes on what could not be verified: recorded in progress log.

### Phase 3 - Verification and convergence
Status: `Completed`

Goals (outcome):
- Confirm the flow at desktop and mobile widths and leave documentation aligned with implementation.

Implementation actions (must be executable):
- [x] Run focused tests and asset build/checks.
- [x] Capture desktop and mobile review evidence when the local app is available.
- [x] Consolidate same-scope CSS and document the interaction contract.

Deliverables (must be tangible):
- Code files: fixes discovered by verification only.
- Docs updated: this plan and CSS contract.
- Test cases added/updated: regressions discovered during verification.

Acceptance (must be verifiable):
- [x] Behavior acceptance: Prepared values survive review submission and Quote creation.
- [x] Channel/output acceptance: Desktop and mobile layouts remain readable.
- [x] Regression acceptance: Focused test set passes.

Evidence required:
- Commands/checks run: recorded in progress log.
- Screenshot/PDF paths: `tmp/review_shots/<run>/`.
- Notes on what could not be verified: recorded in progress log.

## 5. Rules for Implementation
- Keep scope tight and phase-based.
- Reuse existing component/system patterns before creating new ones.
- Avoid parallel style/component families unless explicitly approved.
- Do not change business logic unless the phase explicitly allows it.
- Clean conflicting/obsolete same-scope rules while editing.
- No intent-only phase updates: every status update must include completed actions and evidence.
- If a phase is marked `Completed`, unresolved TODOs must be moved to next phase/queue explicitly.

## 6. Definition of Done
- Hierarchy/readability improved in target scope.
- No functional regressions in core interactions.
- Changes are traceable in progress log.
- Follow-up queue is explicit.
- Each completed phase has an action checklist, file-level change list, verification evidence, and known gaps.

## 7. Verification Plan
- Desktop checks: Inquiry review at 1440px.
- Mobile checks: Inquiry review at 390px.
- Minimal functional checks: candidate ranking, price safety, review rendering, and quote creation.
- What is intentionally not tested: Live third-party Alibaba/WhatsApp DOM behavior.
- Execution log format: command, result, pass/fail, and evidence path in Progress Log.

## 8. File Impact Plan
- Expected files: Inquiry matcher/preparer, controller, review view, Stimulus controller, Rubusoo CSS, focused tests.
- Optional files: locale entries if reusable copy is unavailable.
- Docs to update: this plan and `docs/css-components.md`.
- Out-of-scope files that must not be touched: chat authentication, quote publication, PDF/Excel renderers, billing.

## 9. Progress Log
- `2026-08-05`: Phase 1 started after review of the current chat-to-Inquiry-to-Quote flow.
- `2026-08-05`: Added explainable candidate ranking, safe Catalog price proposals, currency/MOQ/specification warnings, and focused service coverage.
- `2026-08-05`: Added the human review summary, one-click candidate application/restoration, dynamic specification editing, and responsive styles.
- `2026-08-05`: Focused Rails suite passed: 26 runs, 157 assertions, 0 failures. Chat Sync Node suite passed: 3 tests.
- `2026-08-05`: Playwright verified the live mounted-code page at 1440px and 390px. Evidence: `tmp/review_shots/chat_quote_draft_20260805/`.
- `2026-08-05`: Selenium system execution was unavailable in the existing ARM image because its Selenium Manager binary was invalid; equivalent browser interaction and screenshots were completed with system Chromium and Playwright.
- `2026-08-05`: Follow-up interaction review collapsed secondary readiness/chat content, added direct anchors and a top form-associated Create draft action, and removed the field-covering sticky footer. Desktop/mobile evidence was refreshed under `tmp/review_shots/inquiry_interaction_20260805/`.

## 10. Next Priority Queue
- Next phase/task: Attachment content extraction and platform parser health reporting.
- Deferred items: Freight-provider integration, customer-specific pricing rules, and additional chat platforms.
- Reopen conditions: Live adapter failures or verified Catalog pricing requirements beyond default prices.
- Owner: Project team.
- Earliest start date: After this cycle.
- Dependency: Representative production conversations and pricing policy decisions.

## 11. Archive Notes (when cycle is done)
- Final status: Completed.
- Archive filename: To be assigned after completion.
- Key decisions to preserve: No inferred price; proposed Catalog values remain seller-confirmed inputs.
- Delivery summary: Chat-derived inquiries now expose a recommended draft and up to three editable, explainable alternatives without inventing commercial values.
- Completed vs deferred: Draft preparation and confirmation completed; attachment extraction, freight integration, and additional platforms deferred.
- Evidence index: `tmp/review_shots/chat_quote_draft_20260805/inquiry-draft-desktop.png`, `inquiry-draft-mobile.png`.
