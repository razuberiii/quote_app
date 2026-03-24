# Formal/Complex Quote Capability Audit and Phased Plan (2026-03-24)

## 1. Context and Goal
- Project/area: Rubusoo quote domain (Quote, QuoteItem, QuoteTemplate, rendering/export/revision chain).
- Why now: Need to support formal and complex foreign-trade quotations for a minority of high-value customer scenarios, without slowing daily lightweight quoting.
- Target outcome: Deliver an advanced/opt-in architecture and phased roadmap that enables complex sections (trade/logistics/configuration/pictures) while keeping default form fast and lightweight.
- Out of scope: Immediate implementation, broad model refactor, visual redesign-only work without data/rendering linkage.

## 2. Current Problems
- Problem A: Complex quote content is only partially first-class; many sections are currently text workarounds (for example in `terms_text`, `delivery_notes`, `scope_of_supply`).
- Problem B: No explicit quote-level advanced mode gate; risk of overloading default form if features keep being added directly.
- Problem C: Multi-channel rendering is strong but split across multiple paths; future drift risk increases when adding advanced blocks.

## 3. Scope and Constraints
- Scope (explicit pages/modules/files):
  - Models: `app/models/quote.rb`, `app/models/quote_item.rb`, `app/models/quote_template.rb`
  - Controller/form: `app/controllers/quotes_controller.rb`, `app/views/quotes/_form.html.erb`
  - Internal/public views: `app/views/quotes/_show_content.html.erb`, `app/views/public/quote_shares/show.html.erb`, `app/views/public/quotes/show.html.erb`
  - Export: `app/views/quotes/export_pdf.html.erb`, `app/services/quote_exporter.rb`
  - Revision/snapshot: `app/services/quote_revision_diff_service.rb`, `app/services/quote_snapshot_builder.rb`
  - Schema: `db/schema.rb`
- Business logic policy (allowed / not allowed):
  - Allowed in planning: recommend lightweight structured additions (JSON/serialized block), opt-in controls, template defaults/inheritance.
  - Not allowed in this cycle: coding implementation.
- Visual/UX policy:
  - Default quote path remains lightweight and unchanged for most users.
  - Advanced sections should be hidden by default and appear only when enabled.
- Risk boundaries:
  - Avoid introducing mandatory fields for low-frequency sections.
  - Avoid channel mismatch (web/public/PDF/Excel inconsistency).
  - Keep revision credibility for critical fields.

## 4. Execution Roadmap

### Phase 1 - Advanced Core (Opt-in Foundation)
Status: `Completed`

Goals:
- Add quote-level advanced mode container/toggle so complex sections are not exposed by default.
- Introduce minimal structured blocks for high-value fields first:
  - trade terms (key-value style lightweight structure)
  - logistics/container loading (lightweight structured block)
- Add template-level presets/defaults for these advanced sections with quote override.
- Ensure channel strategy in Phase 1 is fixed as:
  - internal + PDF full
  - public minimal read-only
  - Excel simplified

Acceptance:
- Default quote form remains unchanged unless advanced mode is enabled.
- Advanced sections can be enabled per quote and/or pre-enabled by template.
- Internal and PDF render full advanced sections.
- Public has minimal read-only rendering for advanced sections.
- Excel includes only simplified advanced output in Phase 1.

### Phase 2 - Multi-channel Parity
Status: `Completed`

Goals:
- Align public + Excel to internal/PDF behavior for advanced sections (parity + polish).
- Consolidate section visibility behavior so template toggles and quote overrides are predictable.
- Reduce drift risk by reusing shared rendering contracts/partials/serializers where possible.

Acceptance:
- Public and Excel reach parity with internal/PDF for enabled advanced sections.
- Template visibility and defaults behave consistently across all channels.
- Release gate checklist and evidence matrix are fully executable/reviewable.

### Phase 3 - Template + Diff Completion
Status: `Completed`

Goals:
- Extend template defaults/inheritance for advanced sections (including item-level optional behavior when needed).
- Add revision/diff support for newly structured advanced fields:
  - section-level diff for large blocks
  - key-value diff for critical terms
- Improve editing ergonomics for advanced blocks without touching default lightweight flow.

Acceptance:
- Revisions clearly surface meaningful changes in advanced quote content.
- Template-driven formal quote creation requires less repeated manual entry.
- Everyday quote speed is unaffected for non-advanced scenarios.
- Phase 3 exit criteria and evidence matrix are executed and reviewable.

## 5. Rules for Implementation
- Keep scope tight and phase-based.
- Reuse existing component/system patterns before creating new ones.
- Avoid parallel style/component families unless explicitly approved.
- Do not change business logic unless the phase explicitly allows it.
- Clean conflicting/obsolete same-scope rules while editing.
- Preserve default lightweight quoting as primary path; advanced remains opt-in.
- Prefer lightweight structure (JSON/serialized sections) before heavy schema expansion.
- P0 hard rule: do not redesign default item row editor.
- P0 hard rule: do not inject advanced fields into each item's main editing area.
- P0 hard rule: item-level advanced needs continue reusing existing `specifications/addons/image` capability.

## 6. Definition of Done
- Hierarchy/readability improved in target scope.
- No functional regressions in core interactions.
- Changes are traceable in progress log.
- Follow-up queue is explicit.
- Formal/complex quote support is materially improved without adding default form burden.

## 7. Verification Plan
- Desktop checks:
  - Quote form in default mode (advanced off) still supports current fast workflow.
  - Quote form in advanced mode can input and preview advanced sections.
  - Internal show/public/PDF/Excel consistency for same quote.
- Mobile checks:
  - Default quote flow remains compact and usable.
  - Advanced blocks remain readable and collapsible.
- Minimal functional checks:
  - Template preset inheritance + quote override.
  - Revision/diff output for advanced field changes.
- What is intentionally not tested:
  - Full regression suite redesign.
  - Heavy document-layout customization beyond scoped advanced sections.

## 7.1 Phase 2 Exit Criteria (Release Gate)
- Cross-channel parity:
  - Same quote must keep supplementary section presence consistent in internal/public/PDF(HTML/Prawn)/Excel.
  - Section order and section-title semantics must stay aligned.
- Customer-facing wording:
  - Public/PDF/Excel must not expose internal product terms (for example `Advanced ...`).
  - Supplementary titles and field labels must come from `supplementary_trade_terms` / `shipping_and_logistics` / `field_labels.*`.
- Excel readability:
  - Simplified output is acceptable, but headings and key/value rows must remain readable.
  - No debug-style/internal field labels in customer-visible rows.
- Legacy compatibility:
  - Old quote, old template, and old snapshot (missing advanced keys) must render/export without errors.

## 7.2 Presence Parity Matrix Template

| Sample | Internal | Public | PDF HTML | PDF Prawn | Excel | Presence parity | Title parity | Label parity | Result |
|---|---|---|---|---|---|---|---|---|---|
| A: no supplementary data | Hidden | Hidden | Hidden | Hidden | Hidden | Pass | Pass | Pass | Pass |
| B: trade only | Trade only | Trade only | Trade only | Trade only | Trade only | Pass | Pass | Pass | Pass |
| C: trade + logistics | Both shown | Both shown | Both shown | Both shown | Both shown | Pass | Pass | Pass | Pass |

Evidence notes:
- Presence/title/label parity is guarded by controller + exporter tests (`test/controllers/quotes_controller_test.rb`, `test/controllers/public_quote_shares_controller_test.rb`, `test/services/quote_exporter_test.rb`).
- Excel label/title checks use XML-level assertion (`Shipping (&amp;|&) Logistics`) to avoid escape false negatives.
- Legacy sample behavior for A-path and missing keys is covered by snapshot fallback tests.

## 7.3 Phase 2 Release Gate Checklist (Executed)

| Gate | Result | Evidence | Failure reason (if any) |
|---|---|---|---|
| Supplementary section presence parity (internal/public/PDF HTML/PDF Prawn/Excel) | Pass | `quotes_controller_test` + `quote_exporter_test` + parity matrix A/B/C | None |
| Customer-visible wording has no internal product terms (`Advanced*`) | Pass | Assertions in internal/public/pdf-html/xlsx/prawn tests | None |
| Excel simplified output is readable (section heading + K/V; no debug labels) | Pass | `quote_exporter_test` helper-line assertions + xlsx XML heading assertions | None |
| Legacy compatibility (old quote/template/snapshot) | Pass | `public_quote_shares_controller_test` legacy snapshot fallback/missing-key tests + `quote_test` visibility fallback behavior | None |

Phase 2 closure verdict: `PASS`  
Blocked channels: `None`

## 7.4 Phase 3 Exit Criteria (Release Gate)
- Diff non-duplication:
  - Key-level and section-level changes can coexist.
  - For the same section, key-level contract fields are excluded from generic section-level summary.
- Inheritance explicit-empty precedence:
  - Quote explicit empty value blocks template default refill.
  - Duplicate/revision preserves quote snapshot semantics (no template re-injection).
- Normalized value consistency:
  - Form collapse/open, public snapshot fallback, and export presence use the same normalized value semantics.
  - `nil`, blank, whitespace-only, and normalized-empty structures do not count as present values.
- Channel contract:
  - Customer-facing wording in public/PDF/Excel stays business-semantic and avoids internal product terms.

## 7.5 Diff Behavior Table (Locked Contract)

| Field / Section | Diff mode | Customer-facing label | Notes |
|---|---|---|---|
| `advanced_trade_terms.hs_code` | key-level | HS Code | critical key |
| `advanced_trade_terms.warranty_scope_note` | key-level | Warranty | critical key |
| `advanced_trade_terms.delivery_commitment_note` | key-level | Delivery | critical key |
| `advanced_trade_terms.payment_clause_note` | key-level | Payment Terms | critical key |
| `advanced_trade_terms.support_scope_note` | section-level only | Support | avoid noise |
| `advanced_trade_terms.validity_clause_note` | section-level only | Validity | avoid noise |
| `advanced_logistics.container_type` | key-level | Container Type | critical key |
| `advanced_logistics.freight_note` | key-level | Freight | critical key |
| `advanced_logistics.shipping_scope_note` | section-level only | Shipping Scope | avoid noise |
| `advanced_logistics.container_loading_note` | section-level only | Container Loading | avoid noise |

## 7.6 Phase 3 Evidence Matrix (Executed)

| Sample | Internal | Public | PDF HTML | PDF Prawn | Excel | Diff mode result | Inheritance result | Normalized value result | Gate |
|---|---|---|---|---|---|---|---|---|---|
| S1: key-only (`hs_code`) changed | Pass | Pass | Pass | Pass | Pass | key-level only | N/A | Pass | Pass |
| S2: non-key only (`support_scope_note`) changed | Pass | Pass | Pass | Pass | Pass | section-level only | N/A | Pass | Pass |
| S3: mixed key + non-key in same section | Pass | Pass | Pass | Pass | Pass | key + section (non-duplicated) | N/A | Pass | Pass |
| S4: explicit-empty blocks template default refill | Pass | Pass | Pass | Pass | Pass | N/A | Pass | Pass | Pass |
| S5: legacy snapshot missing advanced keys | Pass | Pass | Pass | Pass | Pass | N/A | Pass | Pass | Pass |

Phase 3 closure verdict: `PASS`  
Blocked channels: `None`

## 8. File Impact Plan
- Expected files:
  - `app/models/quote.rb`
  - `app/models/quote_template.rb`
  - `app/controllers/quotes_controller.rb`
  - `app/views/quotes/_form.html.erb`
  - `app/views/quotes/_show_content.html.erb`
  - `app/views/public/quote_shares/show.html.erb`
  - `app/views/public/quotes/show.html.erb`
  - `app/views/quotes/export_pdf.html.erb`
  - `app/services/quote_exporter.rb`
  - `app/services/quote_revision_diff_service.rb`
  - `app/services/quote_snapshot_builder.rb`
  - `db/schema.rb` and migration files (only if lightweight structure cannot be safely reused from existing columns)
- Optional files:
  - Shared partials/helpers for advanced section rendering
  - Template settings UI files
- Docs to update:
  - This plan file
  - Follow-up implementation notes under `docs/` when execution starts

## 9. Progress Log
- `2026-03-24`: Capability audit completed against current code; phased plan drafted.
- `2026-03-24`: No implementation code changes performed in this cycle.
- `2026-03-24`: Phase 1 implementation started (advanced quote blocks data model + form/template/render/export/diff linkage).
- `2026-03-24`: Phase 1 scope expanded to include i18n keys and template live-preview linkage for advanced blocks.
- `2026-03-24`: Follow-up polish completed for template advanced defaults UX split, mobile live-preview readability fixes, and locale linkage cleanup.
- `2026-03-24`: Phase 2 parity/polish started: supplementary section wording unified across internal/public/PDF/Excel semantics and legacy snapshot fallback retained.
- `2026-03-24`: Phase 2 release gate suite executed (`33 runs, 142 assertions, 0 failures`), presence matrix completed, Phase 2 marked completed.
- `2026-03-24`: Phase 3 kickoff implementation started: key-level/section-level non-duplicate diff contract, explicit-empty inheritance precedence, and normalized advanced block value detection for collapse/visibility fallback.
- `2026-03-24`: Phase 3 closure completed: key-level + section-level diff non-dup contract verified, explicit-empty inheritance precedence locked, normalized value semantics unified across form/public/export presence checks.

## 10. Next Priority Queue
- Next phase/task:
  - Post-Phase 3 stabilization only: monitor regression signals on revision summary readability and legacy snapshot fallback.
- Deferred items:
  - Full technical matrix schema normalization.
  - Rich gallery layout controls across all export modes.
- Reopen conditions:
  - If formal quote volume increases and workaround text sections become operational bottlenecks.
  - If channel inconsistencies are reported by customers.

## 11. Archive Notes (when cycle is done)
- Final status: `Phase 1 + Phase 2 + Phase 3 complete`
- Archive filename: `TBD after implementation cycle`
- Key decisions to preserve:
  - Advanced capability must be opt-in and low-frequency/high-value.
  - Quote-level toggle is required.
  - Template defaults should drive acceleration, but quote must retain override.
  - No new schema in Phase 2; no item-row editor redesign; `advanced_visibility` key-space remains fixed to two keys.

## Capability Audit (Hard Matrix, Code-Evidence Level)

| Capability | Status + code evidence | Current fields / current entry points | Internal support | Public support | PDF support | Excel support | Template control | Diff support | Recommended next move |
|---|---|---|---|---|---|---|---|---|---|
| 基础商品行报价 | `Direct` (`QuoteItem` core fields, `quotes/_form`, `quotes/_show_content`, `quote_exporter`) | `quote_items.description/unit_price/quantity` (+ product picker) | Full | Full (`public/quotes/show`, `public/quote_shares/show`) | Full (HTML export view + Prawn fallback) | Full | Labels/visibility via `QuoteTemplate.show_*` + label fields | Full (added/removed/modified line items) | Keep stable; do not change default item row interaction |
| item specs / addons | `Direct` (`quote_items.specifications`, `addon_charges`, snapshots + diff) | Entry via `specifications_text` / `addon_charges_text` in quote form | Full | Full | Full | Full (flattened readable rows) | `spec_label` / `addon_label` controls | Key-level diff already working | Keep as primary item-level advanced carrier in P0/P1 |
| fee / freight / service item | `Workaround` (no fee-item type model) | `quotes.tax_amount/shipping_amount/discount_amount` + manual fee rows as quote items | Full for totals | Full for totals | Full for totals | Full for totals | `show_tax/show_shipping/show_currency` | Financial diff for tax/shipping/discount/total | Keep current engine in Phase 1; no fee schema expansion |
| configuration / technical section | `Workaround` (item-level only, no quote-level first-class section) | Per-item `specifications` + `terms_text/delivery_notes` text workaround | Partial (item-level good, quote-level missing) | Partial | Partial | Partial | No dedicated `show_configuration` or defaults | Item spec diff only; no quote-level config diff | Phase 1 keep workaround; Phase 2/3 evaluate quote-level matrix only if repeat demand proven |
| logistics / container loading | `Direct (Phase 1 lightweight)` for text-structured block | `Quote.advanced_logistics` keys: `freight_note/container_type/shipping_scope_note/container_loading_note`; entry in `quotes/_form` advanced section | Full when `advanced_mode` + visibility enabled | Minimal read-only (share/public pages render block) | Full in both chains | Simplified K/V section | Template defaults in `advanced_defaults` + auto visibility via data presence; key allowlist in model | Section-level via commercial diff field `advanced_logistics` | Phase 2: public label polish parity + optional richer Excel formatting, no schema change |
| trade terms (supplementary) | `Direct (Phase 1 lightweight)` | `Quote.advanced_trade_terms` keys: `hs_code/warranty_scope_note/support_scope_note/validity_clause_note/delivery_commitment_note/payment_clause_note`; entry in quote advanced section | Full | Minimal read-only | Full in both chains; section title now customer-facing | Simplified K/V rows | Template defaults from `advanced_defaults`; quote-level visibility inferred + override map | Section-level via commercial diff field `advanced_trade_terms` | Phase 2: public/internal wording parity with PDF helper labels |
| 图片输出 | `Direct with parity caveat` | Item image upload + source selection (`item_image`, `image_source`) | Uses effective attachment path | Share snapshot path is stable; direct public page still has product fallback branch | Stable (`quote_item_image_data_uri`) | Stable with attachment path | `show_images` / `show_product_images` | Not explicit field-level diff for image swap | Phase 2 unify public direct page image resolution to effective attachment path |
| template visibility control | `Direct` for baseline sections; `Partial` for advanced visibility defaults UI | Existing `show_*` booleans complete; advanced: `enable_advanced_by_default`, `advanced_defaults`, `advanced_visibility_defaults` | Strong | Strong | Strong | Strong | Advanced defaults editable; advanced visibility defaults data exists but no explicit form controls now | Revision summary visibility toggles exist | Phase 2 decide explicit advanced visibility toggles UI vs keep “data presence implies visible” rule |
| public / PDF / Excel consistency | `Workaround/Partial parity` | Split render paths: internal/public ERB, PDF HTML ERB, Prawn fallback, Excel exporter | Good | Good but wording/label path differs | Strong after Phase 1.5 polish | Simplified intentionally | Template locale + visibility controls applied per channel | Diff tags present in share/internal/PDF HTML | Phase 2 enforce parity contract + snapshot-based QA matrix |
| revision / diff for advanced fields | `Direct (key + section-level)` | `QuoteRevisionDiffService` tracks advanced fields with mixed-mode contract | Visible in internal revision panel | Visible in share page inline updated badge | Visible in PDF HTML inline updated badge + exporter summary | Revision summary sheet keeps customer-facing labels | Template has per-channel revision summary toggles | Key-level on critical fields + section-level fallback for non-critical | Keep contract stable and avoid key-space expansion |

## Advanced Feature Strategy (Decision Complete)

- Quote level:
  - Keep `advanced_mode` as master gate; advanced blocks never enter default lightweight path.
  - Keep fixed visibility keys only: `show_trade_terms_advanced`, `show_logistics_block`.
- QuoteTemplate level:
  - Keep `enable_advanced_by_default` + `advanced_defaults` for template-driven prefill.
  - Quote remains final override authority.
- QuoteItem level:
  - Hard rule: no P0 item-row editor redesign.
  - Hard rule: no advanced fields injected into default item main editor.
  - Reuse `specifications/addons/image`.
- Export-only:
  - Allow presentational polish in PDF/Excel/public without adding new data fields.
- Not structuring now:
  - Quote-level configuration matrix/gallery schema deferred (high cost, lower immediate ROI).

## P0 / P1 / P2 ROI Table

| Scope item | Priority | User value | Complexity | Risk | Daily-flow burden | Template impact | Diff impact | Decision |
|---|---|---|---|---|---|---|---|---|
| Advanced opt-in gate + fixed visibility keys | P0 | High | Low | Low | None | High positive | Low | Keep and stabilize |
| Lightweight supplementary trade terms JSON | P0 | High | Low-Med | Low | None | High positive | Medium | Keep, no schema expansion |
| Lightweight shipping/logistics JSON | P0 | High | Low-Med | Low | None | High positive | Medium | Keep, no matrix modeling |
| Public + Excel wording/layout parity for advanced sections | P1 | High | Med | Med | None | Medium | Low | Completed in Phase 2 |
| Explicit advanced visibility defaults UI in template form | P1 | Med | Med | Med | None | High positive | Low | Completed in Phase 2 |
| Quote-level configuration matrix first-class model | P2 | Med-High (specific users) | High | High | Potential if exposed badly | High | High | Defer until demand signal |
| Rich container-loading table in Excel | P2 | Med | Med-High | Med | None | Medium | Low | Defer |
| Key-level advanced diff (critical keys only) | P1 | High | Med | Med | None | Low | High positive | Completed in Phase 3 |

### High-ROI One-Round Recommendation (Top 3 fixed set)
1. Public + Excel parity/polish for supplementary sections (remove channel mismatch).
2. Template advanced visibility defaults explicit control (currently data field exists but UI weak).
3. Advanced diff clarity uplift (field label cleanup + selective key-level for top 4 keys only).
## Phase Boundaries (Locked)

### Phase 1 (implemented baseline)
- Scope:
  - `advanced_mode` opt-in.
  - `advanced_trade_terms` + `advanced_logistics` lightweight structured blocks.
  - Template defaults prefill and quote override.
  - Fixed visibility keys only.
  - i18n + template live preview baseline linkage.
- Channel policy:
  - `internal + PDF full`
  - `public minimal read-only`
  - `Excel simplified`
  - `section-level diff`
- Explicit non-goals:
  - No item row editor redesign.
  - No new complex section schema.
  - No pushing advanced fields into default item area.

### Phase 2 (completed)
- Goal: parity and polish.
- Scope:
  - Public wording/label structure aligned with PDF polished language.
  - Excel supplementary sections remain simplified but more readable and consistent.
  - Template advanced visibility defaults UX completed.
  - Shared label mapping contract across internal/public/PDF/Excel.

### Phase 3 (completed)
- Goal: inheritance and diff maturity.
- Scope:
  - Template inheritance override behavior hardening.
  - Selective key-level diff for critical advanced keys.
  - Advanced editing UX cleanup without changing default lightweight path.

## Export Chain Contract (HTML PDF + Prawn + Excel)

### PDF dual-chain contract
- Chain A: HTML/WKHTML (`quotes/export_pdf.html.erb` + CSS).
- Chain B: Prawn fallback (`QuoteExporter#to_pdf`).
- Must stay consistent on:
  - section presence,
  - section order,
  - section titles,
  - field labels,
  - basic key/value readability.
- Allowed difference:
  - typography details, spacing exactness, table line weight.
- Not allowed difference:
  - section missing in one chain,
  - different field naming semantics,
  - contradictory visibility behavior.

### Excel boundary (Phase 1/2)
- Keep simplified output for supplementary sections.
- Readability-first K/V rows, no debug-like labels.
- No rich matrix layout requirement in Phase 1.
- Phase 2 may improve wrapping/column readability without schema changes.

### Acceptance artifact standard
- For each parity QA run: one quote snapshot, four outputs (internal/public/PDF-HTML/PDF-Prawn/Excel).
- Capture one screenshot/PDF snippet proving:
  - both supplementary sections present/absent consistently,
  - titles/labels aligned,
  - content readable.

## Test Plan (Execution Checklist for QA Run)

1. Template advanced defaults + quote override:
   - new quote, edit quote, duplicate revision, new revision from existing.
2. `advanced_mode` toggling:
   - save/reload cleanliness, no accidental residual values shown when disabled.
3. Channel presence consistency:
   - same quote across internal/public/PDF/Excel.
4. PDF stability:
   - header hierarchy, wrapping, no orphan heading at page bottom.
5. Excel readability:
   - simplified supplementary section readable, non-debug labels.
6. Diff clarity:
   - key-level + section-level mixed mode is clear, and no duplicate same-field signaling.
7. Compatibility:
   - legacy quote/template/no-advanced snapshot displays safely.

## Configuration / Technical Section Decision (Current Cut)

### What can be reused now
- Reuse `QuoteItem.specifications` for item-scoped technical parameters.
- Reuse `terms_text`/`delivery_notes`/`scope_of_supply` for quote-level narrative fallback.

### When quote-level first-class is required
- Shared matrix serves multiple items.
- Needs template defaults + dedicated visibility.
- Needs stable standalone section in public/PDF.
- Needs diff beyond item rows.

### Current boundary
- Phase 1/2: keep lightweight reuse model (no new quote-level technical schema).
- Phase 3+: only introduce quote-level configuration matrix if repeated business demand proves ROI.
## Required Review Scope Findings

### A. Data / Models
- `Quote` already carries advanced fields and strict allowlist normalization (`ADVANCED_*_KEYS`, `advanced_*_data`).
- `QuoteTemplate` already carries `advanced_defaults` + `advanced_visibility_defaults` + `enable_advanced_by_default`.
- `QuoteItem` already supports structured specs/addons + snapshots.
- Current gap: no quote-level first-class configuration matrix model.

### B. Form Layer
- Default quote form remains separable via dedicated advanced section (`advanced_mode` toggle).
- Existing main business fields remain primary semantics (`payment_term`, `trade_term`, `valid_until`), advanced is supplementary.
- Current gap: template advanced visibility defaults are not explicitly configurable in form UI.

### C. Rendering Layer
- Internal view, public share/public direct, PDF HTML, Prawn, Excel all have advanced section branches.
- Current gap: wording/label treatment still differs in some public/internal paths vs polished PDF path.
- Drift risk remains because rendering logic is split across multiple templates/services.

### D. Template Layer
- Branding, labels, watermark, footer/signature, baseline section visibility are strong.
- Advanced defaults prefill is implemented in controller and template model.
- Current gap: no structural gap in Phase 3 closure scope; remaining work is visual polish only.

### E. Revision / Diff
- Advanced blocks now support key-level (critical keys) + section-level (non-critical remainder) contract.
- Inline updated flags appear in internal/share/PDF HTML paths.
- Current gap: broader key-level expansion is intentionally deferred to avoid noise.
## Gap Analysis (Updated, Max 8)

1. Two PDF chains can still drift without continuous parity regression checks.
2. Excel supplementary output remains intentionally simplified (readable but not rich layout).
3. Configuration/technical quote-level block is still not first-class (intentional defer).
4. Public image source resolution edge cases still need ongoing regression attention.
5. Legacy snapshot fallback remains data-driven; requires long-term guard tests.

## Implementation Plan (Phased, Practical)

### Phase 1 — Advanced Core (Baseline Complete)
- Goal:
  - Keep default flow lightweight; make formal quote content expressible.
- Scope:
  - Advanced mode + supplementary trade/logistics + template defaults + minimal public + simplified Excel.
- Impact on default flow:
  - None unless advanced mode is enabled.
- Risks:
  - Label/wording inconsistency across channels.
- Acceptance:
  - Internal + PDF full; public minimal read-only; Excel simplified.

### Phase 2 — Public + Excel Parity and Polish
- Goal:
  - Close user-facing consistency gaps.
- Scope:
  - Public section title/labels align with Phase 1.5 PDF wording.
  - Excel supplementary readability polish.
  - Expose/clarify template advanced visibility defaults behavior in UI.
  - Add parity QA snapshots as release gate.
- Impact on default flow:
  - None.
- Risks:
  - Multi-path rendering drift during updates.
- Acceptance:
  - Same quote shows same supplementary section semantics across internal/public/PDF/Excel.

### Phase 3 — Template Inheritance + Diff Completion
- Goal:
  - Improve trust and maintainability for advanced scenarios.
- Scope:
  - Key-level diff for selected advanced keys.
  - Harden defaults/inheritance and override edge cases.
  - Advanced editor UX cleanup only (no default-flow pollution).
- Impact on default flow:
  - None.
- Risks:
  - Diff verbosity/noise.
- Acceptance:
  - Critical advanced field changes are traceable and understandable.
  - Same-field duplicate diff signaling is eliminated.

## Final Recommendation

1. Distance to elegant support:
   - Core formal/complex quote capability is now production-usable with Phase 3 closure contract in place.
2. Minimal closure priorities:
   - Completed in this cycle: parity closure + selective key-level diff + explicit-empty inheritance precedence + normalized presence semantics.
3. Must-structure vs workaround:
   - Must keep structured now: supplementary trade/logistics blocks.
   - Workaround acceptable now: quote-level configuration matrix and gallery schema.
4. Must remain advanced/opt-in:
   - All formal supplementary sections and any future configuration matrix.
5. If only one high-ROI round is approved:
   - Keep current locked set stable and invest next in regression hardening + visual polish only.

## Final Summary
- Can already do well:
  - Core quote rows, item specs/addons/images, advanced opt-in gate, template-driven advanced defaults, internal+PDF full supplementary rendering.
- Can do with workaround:
  - Configuration matrix, rich container loading matrix.
- Should be added soon:
  - None required for Phase 3 closure gate; only incremental polish remains.
- Should be advanced / opt-in only:
  - Supplementary trade/logistics blocks and any future quote-level technical matrix.
- Not urgent yet:
  - Heavy schema normalization, rich Excel matrix formatting, full nested diff engine.

