# Customer Workbook Template Delivery Plan

## 1. Context and Goal
- Project/area: Quote Studio, document design, published Excel export.
- Why now: Customers need to use their own workbook and fields instead of adopting built-in industry assumptions.
- Target outcome: Upload an `.xlsx`, map core and custom fields, select it on a quote, and export a populated copy while retaining workbook styling.
- Out of scope: Word/PDF template ingestion and automatic visual repair of customer files.
- Business value / success metric: A seller can reuse a customer-owned workbook without code changes.
- Delivery deadline (if any): Current improvement cycle.

## 2. Current Problems
- Problem A: Excel export only uses the built-in workbook.
- Problem B: Quote fields are predominantly fixed in code.
- Problem C: Customer workbook formatting cannot be retained.
- Existing workaround and why it is insufficient: Manually copying quote values into Excel is slow and error-prone.

## 3. Scope and Constraints
- Scope (explicit pages/modules/files): Document settings, Quote Studio, published-version Excel export.
- Business logic policy (allowed / not allowed): Customer templates supplement the basic system template; published quote data remains immutable.
- Visual/UX policy: Reuse settings and Quote Studio controls; keep mapping explicit and understandable.
- Risk boundaries: `.xlsx` only; validate type and size; neutralize formula-like user text.
- Non-negotiable constraints (performance/compliance/compatibility): Preserve the uploaded workbook package and existing styles wherever cells are mapped.

## 4. Execution Roadmap

### Phase 1 - Template and field model
Status: `Completed`

Goals (outcome):
- Store company-owned workbook templates, mappings, and custom field definitions.

Implementation actions (must be executable):
- [x] Added template and quote fields.
- [x] Added ownership, validation, and snapshot behavior.

Deliverables (must be tangible):
- Code files: migrations and models.
- Docs updated: this plan.
- Test cases added/updated: model/service coverage.

Acceptance (must be verifiable):
- [ ] Behavior acceptance: templates cannot cross company boundaries.
- [ ] Channel/output acceptance: uploaded workbook remains attached.
- [ ] Regression acceptance: quotes without a customer template retain the built-in export.

Evidence required:
- Commands/checks run: targeted Rails tests.
- Screenshot/PDF paths: `tmp/review_shots/customer_workbook_template_20260806/`.
- Notes on what could not be verified: Word and static PDF templates.

### Phase 2 - Mapping and quote workflow
Status: `Completed`

Goals (outcome):
- Let users upload and map a workbook, then fill custom values on a quote.

Implementation actions (must be executable):
- [x] Added settings upload/mapping page.
- [x] Added template selection and typed custom fields to Quote Studio.

Deliverables (must be tangible):
- Code files: controllers, routes, views.
- Docs updated: workflow notes.
- Test cases added/updated: controller tests.

Acceptance (must be verifiable):
- [ ] Behavior acceptance: mapping errors are actionable.
- [ ] Channel/output acceptance: selected template is visible in Quote Studio.
- [ ] Regression acceptance: existing quote creation/editing remains functional.

Evidence required:
- Commands/checks run: controller and visual checks.
- Screenshot/PDF paths: review folder above.
- Notes on what could not be verified: automatic mapping inference.

### Phase 3 - Workbook generation
Status: `Completed`

Goals (outcome):
- Populate mapped cells and repeated item rows in an uploaded workbook.

Implementation actions (must be executable):
- [x] Implemented package-preserving workbook writer with package limits.
- [x] Added published-version download action.
- [x] Verified the generated workbook visually and structurally; fixed a namespace loss found only by real rendering.

Deliverables (must be tangible):
- Code files: export service and controller integration.
- Docs updated: supported mapping contract.
- Test cases added/updated: workbook generation tests.

Acceptance (must be verifiable):
- [ ] Behavior acceptance: core/custom/item values populate correctly.
- [ ] Channel/output acceptance: the downloaded workbook opens and retains styles.
- [ ] Regression acceptance: built-in PDF/Excel remain available.

Evidence required:
- Commands/checks run: service/controller tests and actual workbook render.
- Screenshot/PDF paths: review folder above.
- Notes on what could not be verified: arbitrary macro-enabled or password-protected files.

### Phase 4 - Unified base-template fields
Status: `Completed`

Goals (outcome):
- Allow company-defined fields without uploading a workbook and render them consistently in every built-in customer output.

Implementation actions (must be executable):
- [x] Added typed custom-field definitions to the base document design.
- [x] Unified base-template and optional workbook fields in Quote Studio.
- [x] Frozen definitions and values into the published-version snapshot.
- [x] Rendered populated fields in Buyer Room, PDF, and built-in Excel.

Deliverables (must be tangible):
- Code files: quote template/model, design editor, snapshot builder, Buyer Room/PDF/Excel renderers.
- Docs updated: this plan and the commercial PDF CSS contract.
- Test cases added/updated: design persistence, Buyer Room rendering, Excel rendering, export regression.

Acceptance (must be verifiable):
- [x] Behavior acceptance: no uploaded file is required to create or fill a custom field.
- [x] Channel/output acceptance: one published value appears in Buyer Room, PDF, and Excel.
- [x] Regression acceptance: customer-workbook mapping and built-in exports still pass.

Evidence required:
- Commands/checks run: targeted Rails tests, Zeitwerk, diff check, actual PDF and LibreOffice rendering.
- Screenshot/PDF paths: `tmp/review_shots/customer_workbook_template_20260806/09-base-custom-fields-pdf.png` and `10-base-custom-fields-excel.png`.
- Notes on what could not be verified: Word/PDF input templates remain deferred.

## 5. Rules for Implementation
- Keep scope tight and phase-based.
- Reuse existing component/system patterns before creating new ones.
- Avoid parallel style/component families unless explicitly approved.
- Do not change business logic unless the phase explicitly allows it.
- Clean conflicting/obsolete same-scope rules while editing.
- No intent-only phase updates.

## 6. Definition of Done
- Upload, mapping, quote entry, and download work end to end.
- Existing exports continue to work.
- Tests and visual evidence are recorded.

## 7. Verification Plan
- Desktop checks: settings upload and Quote Studio selection.
- Mobile checks: forms fit at 390px.
- Minimal functional checks: upload, save, publish-version export, generated xlsx inspection.
- What is intentionally not tested: Word/PDF import.
- Execution log format: command, result, pass/fail, evidence path.

## 8. File Impact Plan
- Expected files: models, migrations, routes, controllers, Quote Studio/settings views, export service, tests.
- Optional files: locale files if shared copy is insufficient.
- Docs to update: this plan and CSS documentation only if conventions change.
- Out-of-scope files that must not be touched: buyer PDF layout.

## 9. Progress Log
- `2026-08-06`: Phase started.
- `2026-08-06`: Company-owned xlsx upload, mapping, custom fields, and immutable version binding completed.
- `2026-08-06`: Generated workbook opened in LibreOffice; original formatting and mapped quote data verified.
- `2026-08-06`: Worksheet namespace loss found during visual rendering and fixed.
- `2026-08-06`: Base-template fields unified across Quote Studio, Buyer Room, PDF, and Excel.

## 10. Next Priority Queue
- Next phase/task: Word placeholder templates.
- Deferred items: static PDF coordinate mapping and automatic layout repair.
- Reopen conditions: customer demand after Excel workflow validation.
- Owner: Product engineering.
- Earliest start date: After this cycle.
- Dependency: Excel workflow feedback.

## 11. Archive Notes (when cycle is done)
- Final status: Completed for `.xlsx` v1.
- Archive filename: `customer-workbook-template-plan-2026-08-06.md`.
- Key decisions to preserve: customer formatting is authoritative; system does not beautify uploads.
- Delivery summary: Upload, map, select, populate, publish, and download are connected end to end.
- Completed vs deferred: Excel completed; Word/PDF and automatic mapping inference deferred.
- Evidence index: `tmp/review_shots/customer_workbook_template_20260806/`.
