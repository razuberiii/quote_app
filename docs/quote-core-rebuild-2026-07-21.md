# Quote Core Rebuild

## 1. Context and Goal
- Project/area: authenticated Rubusoo product, quote authoring, AI intake, document output, and customer review.
- Why now: the current Deal/CRM layer obscures the product's real value and the template editor exposes implementation details instead of producing dependable customer documents.
- Target outcome: one quote-first workflow from AI-assisted source import to immutable publication, professional PDF/XLSX, customer feedback, revision, and acceptance.
- Out of scope: sales pipeline forecasting, order fulfilment, accounting, inventory, and payment collection.
- Business value / success metric: a new user can create and send a professional first quote in under ten minutes; PDF/XLSX are one action away after publication.
- Delivery deadline (if any): current improvement cycle.

## 2. Current Problems
- Problem A: Deal, Quote, Working Draft, Version, Delivery, Files, and Final Document compete as top-level concepts.
- Problem B: AI import is split by data type and template customization is a long settings form without preview-led guidance.
- Problem C: published PDF/XLSX use a separate low-fidelity renderer and export actions are hidden behind delivery.
- Existing workaround and why it is insufficient: route aliases and CSS patches preserve capability but do not reduce the user's decision load or guarantee consistent output.

## 3. Scope and Constraints
- Scope (explicit pages/modules/files): navigation, quote list/detail/editor, inquiry review, company/catalog import, publishing, customer activity, versions, output design, PDF/XLSX, locales, legacy route redirects, visual tests.
- Business logic policy (allowed / not allowed): business model and routing changes are allowed; published snapshots and existing customer data must be preserved.
- Visual/UX policy: one shared token/component system; document renderers share brand/content rules but use output-specific layouts.
- Risk boundaries: the owner explicitly confirmed production sample data is disposable; legacy commercial state may be removed instead of carrying compatibility complexity. Published-version immutability remains the forward contract.
- Non-negotiable constraints (performance/compliance/compatibility): AI never guesses money or silently overwrites mastered data; published output is immutable and reproducible.

## 4. Execution Roadmap

### Phase 1 - Quote-first product shell
Status: `Complete`

Goals (outcome):
- Remove Deal/Inbox/CRM language and make Quotes the authenticated home.

Implementation actions (must be executable):
- [x] Add canonical quote index/detail/activity/version/output routes and legacy redirects.
- [x] Replace navigation and next-action language with quote lifecycle language.

Deliverables (must be tangible):
- Code files: routes, quote controllers/helpers/views, application navigation, locales.
- Docs updated: architecture and CSS component contract.
- Test cases added/updated: routing, quote lifecycle, legacy redirects.

Acceptance (must be verifiable):
- [x] Behavior acceptance: all seller actions are reachable without the Deal concept.
- [x] Channel/output acceptance: published PDF/XLSX/customer page are first-level actions.
- [x] Regression acceptance: existing Deal URLs redirect without losing records.

Evidence required:
- Commands/checks run: controller/system tests and route audit.
- Screenshot/PDF paths: `tmp/review_shots/quote-core-rebuild-20260721/`.
- Notes on what could not be verified: recorded during execution.

### Phase 2 - AI-managed quote data and document design
Status: `Complete`

Goals (outcome):
- Manage seller, customer, product, terms, and quote inputs through one evidence-led import pattern; replace template CRUD with brand, layout, content, and per-quote controls.

Implementation actions (must be executable):
- [x] Unify import entry points and review states while preserving human confirmation.
- [x] Introduce a constrained single document-design profile, channel languages and quote-level content editing.

Deliverables (must be tangible):
- Code files: import services/views, document-design models/services/views, migrations.
- Docs updated: AI trust boundary and design profile architecture.
- Test cases added/updated: source parsing, conflicts, profile inheritance and snapshot freezing.

Acceptance (must be verifiable):
- [x] Behavior acceptance: imported values show source evidence and never silently overwrite mastered values.
- [x] Channel/output acceptance: PDF and XLSX consume the same frozen content/brand rules.
- [x] Regression acceptance: existing templates redirect to the safe document-design profile.

Evidence required:
- Commands/checks run: model/service/controller tests.
- Screenshot/PDF paths: design studio and import review evidence folder.
- Notes on what could not be verified: recorded during execution.

### Phase 3 - Professional output and full-flow acceptance
Status: `Complete`

Goals (outcome):
- Deliver customer-ready PDF/XLSX and validate the complete new-user workflow.

Implementation actions (must be executable):
- [x] Build and inspect production PDF/XLSX fixtures and direct download responses.
- [x] Remove seller-facing Deal/template UI and run desktop/mobile light/dark audits plus the quote-core business flow.

Deliverables (must be tangible):
- Code files: renderers, output views/styles, cleanup, visual/business-flow tests.
- Docs updated: onboarding, test fixtures, output contracts, evidence index.
- Test cases added/updated: publish, download, buyer feedback, revision, acceptance, legacy routes.

Acceptance (must be verifiable):
- [x] Behavior acceptance: the canonical quote flow reaches customer activity and immutable outputs without a dead end.
- [x] Channel/output acceptance: PDF/XLSX open correctly and match frozen version data.
- [x] Regression acceptance: audited canonical routes return 200 with no overflow, theme leak or missing translation marker.

Evidence required:
- Commands/checks run: Rails suite, browser business flow, export inspection.
- Screenshot/PDF paths: `tmp/review_shots/quote-core-rebuild-20260721/`.
- Notes on what could not be verified: recorded during execution.

## 5. Rules for Implementation
- Preserve published data and provide redirects before removing legacy UI.
- Reuse and consolidate existing component families; delete same-scope conflicts.
- AI output is always a candidate with evidence until a user confirms it.
- PDF and XLSX share a semantic snapshot but have independent print-safe renderers.
- Completed phases require code, tests, and evidence rather than intent-only status.

## 6. Definition of Done
- Quotes are the only seller-facing commercial object.
- AI-assisted sources cover company, customer/requirement, and catalog data with a consistent review contract.
- Brand/layout/content rules replace user-facing template CRUD.
- Published PDF, XLSX, and customer page are immutable and directly accessible.
- New-user and customer-response flows pass in both themes and target breakpoints.

## 7. Verification Plan
- Desktop checks: 1440px light/dark full quote lifecycle.
- Mobile checks: 390px light/dark plus 360/412 overflow checks.
- Minimal functional checks: signup/login, import, review, edit, publish, PDF, XLSX, buyer view/question/change/accept, V2.
- What is intentionally not tested: external email deliverability beyond application handoff.
- Execution log format: command, result, evidence path, outstanding risk.

## 8. File Impact Plan
- Expected files: quote/inquiry/company/catalog controllers, models, services, views, routes, locales, `rubusoo.css`, tests.
- Optional files: compatibility controllers and migrations.
- Docs to update: architecture, CSS components, README/onboarding, this plan.
- Out-of-scope files that must not be touched: billing and admin behavior except navigation compatibility.

## 9. Progress Log
- `2026-07-21`: Scope approved: quote-only product, AI-managed source data, constrained document design, professional PDF/XLSX.
- `2026-07-21`: Phase 1 started; current implementation and migration risks inventoried.
- `2026-07-21`: Quotes became the authenticated home; Inbox/Deal/template navigation was removed or redirected.
- `2026-07-21`: Added Customer resource, unified AI import hub, constrained Document design and frozen seller/design snapshot data.
- `2026-07-21`: Added direct PDF/XLSX version exports; both real generators pass binary smoke tests.
- `2026-07-22`: Deployed `rubusoo:quote-core-rebuild-6`; production browser audit covered eight canonical pages at 1440/390 in light/dark.
- `2026-07-22`: Production business-flow test verified customer page, PDF and Excel directly from one immutable version.

## 10. Next Priority Queue
- Next phase/task: collect real-customer feedback on the constrained document recipes and add a recipe only when a repeated need is proven.
- Deferred items: fulfilment, accounting, payments, CRM forecasting.
- Reopen conditions: published snapshot reproducibility or production data compatibility fails.
- Owner: Codex.
- Earliest start date: 2026-07-21.
- Dependency: current schema and export tests.

## 11. Archive Notes (when cycle is done)
- Final status: complete.
- Archive filename: pending.
- Key decisions to preserve: quote-only scope; evidence-led AI; constrained design profiles; immutable outputs.
- Delivery summary: quote-only navigation, AI source hub, constrained document design, immutable customer page/PDF/XLSX and quote activity are deployed.
- Completed vs deferred: quote lifecycle and outputs complete; fulfilment, accounting, payments and CRM forecasting remain intentionally deferred.
- Evidence index: `tmp/review_shots/quote-core-rebuild-20260721/` (`audit.json`, light/dark screenshots, `customer-quote.pdf`, `customer-quote.xlsx`, `customer-quote-preview.png`).
