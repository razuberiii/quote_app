# CSS Cleanup Plan (2026-03)

## 1. Context and Goal
- Project/area: Rubusoo frontend styles (`app/assets/stylesheets/components.css`) with dashboard-first cleanup scope.
- Why now: Historical additive overrides caused maintainability drift; cleanup must be replacement-first instead of stacking new layers.
- Target outcome:
  - Remove same-scope obsolete/conflicting CSS in phased passes.
  - Keep canonical selector blocks only for edited scopes.
  - Establish predictable cleanup evidence per pass.
- Out of scope:
  - New feature visual redesign.
  - Broad refactor across unrelated feature families.
  - Business logic changes.

## 2. Current Problems
- Problem A: Multi-era dashboard mobile/table rules coexist, increasing cascade ambiguity.
- Problem B: Cleanup attempts tend to append overrides instead of deleting outdated rules.
- Problem C: Without strict per-pass evidence, regression risk and selector debt both grow.

## 3. Scope and Constraints
- Scope (explicit pages/modules/files):
  - Primary: `app/assets/stylesheets/components.css`
  - Target feature scopes by phase: `.dashboard-*` then `.navbar-*`/`.account-*`/`.locale-*` then `.quote-*`
  - Plan tracking doc: `docs/css-cleanup-task-2026-03.md`
- Business logic policy (allowed / not allowed):
  - Allowed: stylesheet consolidation/removal, selector merge, rule deduplication.
  - Not allowed: controller/model/business workflow changes.
- Visual/UX policy:
  - No net-new visual system.
  - Preserve current intended UI behavior; remove only redundant/conflicting historical chains.
- Risk boundaries:
  - Delete-only or merge-first for each pass whenever possible.
  - Any selector removal must be backed by in-repo usage/cascade evidence (`rg` + location notes).

## 4. Execution Roadmap

### Phase 1 - Dashboard Scope Cleanup
Status: `Code Cleanup Completed; Visual Acceptance Pending`

Goals:
- Remove obsolete/conflicting historical dashboard rules while keeping current canonical dashboard behavior.
- Eliminate duplicate mobile-table conversion chains replaced by current `dashboard-mobile-list` flow.

Acceptance:
- Dashboard edited scope has one canonical rule path per behavior.
- Removed selectors are logged with evidence.
- No dashboard functional regression in core desktop/mobile layout.

### Phase 2 - Navbar/Account/Locale Scope Cleanup
Status: `Code Cleanup Completed; Visual Acceptance Pending`

Goals:
- Consolidate nav/account/locale multi-era overrides.
- Keep one canonical dropdown/nav interaction styling path.

Acceptance:
- No parallel historical overrides for same interaction in edited scope.
- Existing nav/account behaviors preserved.

### Phase 3 - Quote Scope Cleanup
Status: `Code Cleanup Completed; Visual Acceptance Pending`

Goals:
- Remove conflicting quote-scope historical blocks in edited areas.
- Keep quote families explicit and non-overlapping.

Acceptance:
- Quote edited scope has canonical rule blocks only.
- No regression to quote creation/view critical flows.

## 5. Rules for Implementation
- Keep scope tight and phase-based.
- Reuse existing component/system patterns before creating new ones.
- Avoid parallel style/component families unless explicitly approved.
- Do not change business logic unless the phase explicitly allows it.
- Clean conflicting/obsolete same-scope rules while editing.
- Cleanup-first policy for this cycle:
  - Same-scope cleanup first (delete/merge before add).
  - One-in one-out (if a new selector is introduced in cleanup scope, remove/merge at least one old selector in that scope).
  - No patch-naming classes (`*-fix`, `*-new`, `*-v2`) without explicit approval.

## 6. Definition of Done
- Edited phase scope has canonical blocks only.
- Core UI behavior in edited scope remains stable.
- Progress log includes removal evidence and verification notes.
- Next-phase queue is explicit.

## 7. Verification Plan
- Desktop checks:
  - Dashboard main sections, cards, tables/lists, action toggles render correctly.
- Mobile checks:
  - Dashboard mobile list behavior and key card readability remain intact.
- Minimal functional checks:
  - `bundle exec rails runner "puts 'ok'"`
  - Selector evidence via `rg` before/after pass.
- What is intentionally not tested:
  - Full visual regression snapshot suite.
  - Unrelated feature family deep QA in this cycle.

## 8. File Impact Plan
- Expected files:
  - `app/assets/stylesheets/components.css`
  - `docs/css-cleanup-task-2026-03.md`
- Optional files:
  - `docs/css-components.md` (only when conventions change)
- Docs to update:
  - This plan doc progress log each pass.

## 9. Progress Log
- `2026-03-22`: Plan normalized to template structure.
- `2026-03-22`: Phase 1 Pass 1 completed (dashboard delete-only cleanup):
  - Removed obsolete dashboard mobile table-card conversion block from early `@media (max-width: 768px)` section.
  - Removed duplicate historical mobile tuning in same obsolete block for:
    - `.dashboard-kpi-row`
    - `.dashboard-kpi-card`, `.dashboard-kpi-card strong`
    - `.dashboard-kpi-head span`, `.dashboard-kpi-trend`
    - `.dashboard-panel` compact padding + overview text overrides
  - Evidence:
    - Canonical mobile selectors remain in later dashboard section (`.dashboard-mobile-list`, `.dashboard-products-table thead`).
- `2026-03-22`: Phase 1 Pass 2 completed (dashboard delete-only cleanup):
  - Removed early duplicate dashboard responsive block at `@media (max-width: 992px)` for:
    - `.dashboard-kpi-row`
    - `.dashboard-detail-grid`
  - Removed old dashboard product table width chain superseded by later canonical block:
    - `.dashboard-recent-table.dashboard-products-table th/td:nth-child(4)`
    - `.dashboard-recent-table.dashboard-products-table th/td:nth-child(5)`
  - Removed duplicate detail-grid single-column declarations under:
    - `@media (max-width: 900px)`
    - `@media (max-width: 768px)`
  - Kept canonical mobile path intact:
    - `.dashboard-mobile-list` + later dashboard `@media (max-width: 768px)` main chain
  - Evidence:
    - Later canonical dashboard responsive/table rules remain in place (`.dashboard-products-table` mobile chain, `.dashboard-mobile-list`, `.dashboard-recent-table.dashboard-products-table` tuned widths in later block).
- `2026-03-22`: Phase 1 Pass 3 completed (dashboard delete-only cleanup):
  - Removed early base `.dashboard-detail-grid` block superseded by later canonical `.dashboard-detail-grid` definition.
  - Removed early base `.dashboard-overview-list` block superseded by later canonical `.dashboard-overview-list` block.
  - Removed early `.dashboard-reminder-count-head, .dashboard-reminder-count` block superseded by later canonical width/alignment block.
  - Evidence:
    - Later canonical selectors remain in place for all removed blocks (`.dashboard-detail-grid`, `.dashboard-overview-list`, `.dashboard-reminder-count-head/.dashboard-reminder-count`).
- `2026-03-22`: Phase 1 Pass 4 completed (dashboard delete-only cleanup):
  - Removed early duplicate `height: auto` declaration from `.dashboard-panel.dashboard-overview-panel`.
  - Kept early `align-self: start` behavior unchanged.
  - Evidence:
    - Later canonical block still declares `height: auto` for `.dashboard-panel.dashboard-overview-panel` via `.dashboard-panel.dashboard-overview-panel, .dashboard-detail-grid > .dashboard-panel`.
- `2026-03-22`: Phase 1 Pass 5 completed (dashboard delete-only cleanup):
  - Removed early duplicate `height: auto` declaration from `.dashboard-detail-grid > .dashboard-panel`.
  - Evidence:
    - Later canonical block still declares `height: auto` for `.dashboard-detail-grid > .dashboard-panel` via `.dashboard-panel.dashboard-overview-panel, .dashboard-detail-grid > .dashboard-panel`.
- `2026-03-22`: Phase 1 Pass 6 completed (dashboard delete-only cleanup):
  - Removed early `.dashboard-health-band` base block (`padding/border/background/box-shadow`).
  - Evidence:
    - Later canonical late-override block keeps same baseline values and adds current constraints (`border-radius`, `margin-top`) for `.dashboard-health-band`.
- `2026-03-22`: Phase 1 Pass 7 completed (dashboard delete-only cleanup):
  - Removed early `margin-bottom: 0.1rem` from `.dashboard-health-strip`.
  - Evidence:
    - Later canonical `.dashboard-health-strip` block keeps `margin-bottom: 0`, so final cascade behavior remains unchanged.
- `2026-03-22`: Phase 1 Pass 8 completed (dashboard delete-only cleanup):
  - Removed early `margin-top: 0` from base `.dashboard-health-strip`.
  - Evidence:
    - `margin-top: 0` is default margin behavior for this grid container, and no dashboard override depends on that declaration.
- `2026-03-22`: Phase 1 Pass 9 completed (dashboard delete-only cleanup):
  - Removed duplicate `.dashboard-health-strip` block containing only:
    - `align-items: stretch`
    - `padding-top: 0`
  - Evidence:
    - Both values are default behavior for this container in current dashboard layout, so removal does not change final computed styles.
- `2026-03-22`: Phase 1 validation attempt:
  - Updated `script/capture_pages.ps1` connectivity check to use `Invoke-WebRequest -UseBasicParsing` for Windows PowerShell compatibility.
  - Screenshot run is currently blocked in this environment by Playwright browser launch permission (`spawn EPERM`), so dashboard visual acceptance remains pending manual/runtime verification.
- `2026-03-22`: Phase 2 Pass 1 completed (navbar/account/locale, delete-only cleanup):
  - Removed redundant `.locale-nav-menu .locale-nav-link { color: #334155; }` block (same value already declared in `.locale-nav-link`).
  - Removed redundant `margin-left: 0` from `@media (max-width: 980px) .app-root .locale-nav` (already declared in base locale-nav block).
  - Removed redundant `justify-content: space-between` from `@media (max-width: 980px) .app-root .locale-nav-trigger` (already declared in base trigger block).
  - Evidence:
    - Base canonical selectors remain and provide same final values (`.locale-nav-link`, `.app-root .locale-nav`, `.app-root .locale-nav-trigger`).
- `2026-03-22`: Phase 2 Pass 2 completed (navbar/account/locale, delete-only cleanup):
  - Removed redundant `margin-left: 0` from `@media (max-width: 1540px)` locale block:
    - `.app-root .locale-nav-item, .app-root .locale-nav`
  - Removed redundant standalone `@media (max-width: 1540px) .app-root .locale-nav { margin-left: 0; }`.
  - Evidence:
    - Base canonical selectors still provide the same margin baseline (`.app-root .locale-nav-item { margin-left: 0; }`, `.app-root .locale-nav { margin-left: 0; }`).
- `2026-03-22`: Phase 2 Pass 3 completed (navbar/account/locale, delete-only cleanup):
  - Removed redundant `justify-content: space-between` from `@media (max-width: 1540px) .app-root .navbar-container`.
  - Evidence:
    - Base canonical `.app-root .navbar-container` already declares `justify-content: space-between`, so final cascade behavior remains unchanged.
- `2026-03-22`: Phase 2 Pass 4 completed (navbar/account/locale, delete-only cleanup):
  - Removed redundant `justify-content: flex-start` from `@media (max-width: 1540px) .app-root .account-menu-trigger`.
  - Evidence:
    - Base canonical `.app-root .account-menu-trigger` already declares `justify-content: flex-start`, so final cascade behavior remains unchanged.
- `2026-03-22`: Phase 2 Pass 5 completed (navbar/account/locale, delete-only cleanup):
  - Removed redundant `min-width: 0` and `flex-wrap: wrap` from `@media (max-width: 768px) .app-root .navbar-brand-wrap`.
  - Evidence:
    - Base canonical `.app-root .navbar-brand-wrap` already declares `min-width: 0` and `flex-wrap: wrap`.
- `2026-03-22`: Phase 2 Pass 6 completed (navbar/account/locale, delete-only cleanup):
  - Removed redundant `@media (max-width: 480px) .app-root .navbar-menu { grid-template-columns: 1fr; }`.
  - Evidence:
    - `@media (max-width: 1540px) .app-root .navbar-menu` already sets `grid-template-columns: 1fr`, and this applies to `<=480px`.
- `2026-03-22`: Phase 2 Pass 7 completed (navbar/account/locale, delete-only cleanup):
  - Removed redundant `display: inline` from `@media (max-width: 768px) .app-root .navbar-brand-wrap h1 a`.
  - Evidence:
    - Anchor default display is inline in this scope, and no navbar/account/locale override depends on this declaration.
- `2026-03-22`: Phase 3 Pass 1 completed (quote, delete-only cleanup):
  - Removed duplicate `@media (max-width: 768px)` quote toolbar/tablet-mobile overrides already covered by later canonical mobile block:
    - `.quote-toolbar-left/.quote-toolbar-right/.quote-toolbar-right-primary { width: 100%; }`
    - `.quote-toolbar-right-primary { justify-content: flex-start; }`
    - `.quote-btn, .quote-toolbar .button_to { width: 100%; }`
    - `.quote-signal-strip { grid-template-columns: 1fr; }`
  - Removed redundant duplicate in same media scope:
    - `.quote-template-picker { width: 100%; }`
    - `.quote-template-picker select { width: 100%; }`
  - Evidence:
    - Later canonical quote mobile block keeps equivalent declarations in active cascade (`.quote-toolbar-*`, `.quote-btn/.quote-toolbar .button_to`, `.quote-signal-strip`, `.quote-template-picker` chain).
- `2026-03-22`: Phase 3 Pass 2 completed (quote, delete-only cleanup):
  - Removed early legacy quote blocks superseded by later canonical quote web blocks:
    - `.quote-signal-strip`
    - `.quote-signal-item`
    - `.quote-meta-grid`
    - `.quote-engagement-details-grid`
    - `.quote-engagement-details-grid p`
  - Evidence:
    - Later canonical selectors for all removed blocks remain in place and are the active definitions (`.quote-signal-strip/.quote-signal-item`, `.quote-meta-grid`, `.quote-engagement-details-grid` family).
- `2026-03-22`: Phase 3 Pass 3 completed (quote, delete-only cleanup):
  - Removed early `@media (max-width: 768px) .quote-items-responsive .quote-items-table { min-width: 0; width: 100%; }`.
  - Evidence:
    - Later canonical `quote-items-responsive` mobile chain in the same media scope still controls table width/display (`.quote-items-responsive .quote-items-table, ... td { display: block !important; width: 100% !important; }` + subsequent table block).
- `2026-03-22`: Phase 3 Pass 4 completed (quote, delete-only cleanup):
  - Removed early base gaps that are fully overridden by later canonical quote-toolbar rhythm block:
    - `.quote-toolbar { gap: 0.65rem; }`
    - `.quote-toolbar-left, .quote-toolbar-right { gap: 0.7rem; }`
    - `.quote-toolbar-right-primary { gap: 0.5rem; }`
  - Removed redundant desktop media override:
    - `@media (min-width: 1024px) .quote-toolbar-right { margin-left: auto; }`
  - Evidence:
    - Later canonical quote-toolbar block still defines active spacing (`.quote-toolbar { gap: 0.75rem; }`, `.quote-toolbar-left/.quote-toolbar-right/.quote-toolbar-right-primary { gap: 0.55rem; }`).
    - Base `.quote-toolbar-right` already keeps `margin-left: auto`, so removing desktop duplicate does not change final cascade.
- `2026-03-22`: Phase 3 Pass 5 completed (quote, delete-only cleanup):
  - Removed early `.quote-toolbar-right { gap: 0.75rem; }` from base quote-toolbar block.
  - Evidence:
    - Later canonical quote-toolbar rhythm block still applies `.quote-toolbar-right { gap: 0.55rem; }` through grouped selector `.quote-toolbar-left, .quote-toolbar-right, .quote-toolbar-right-primary`.
- `2026-03-22`: Phase 3 Pass 6 completed (quote, aggressive delete-only cleanup):
  - Removed early quote-card era blocks/properties superseded by later canonical quote list/card chain:
    - Early `.quote-card-list` block (`display/grid + old gap`).
    - Early `.quote-card` block (`padding`, `border-radius`).
    - Early `.quote-queue-toolbar` block (`margin`, `border-radius`, `background`).
    - Early `.quote-card-diff` block (`margin/display/gap/color/font-size`).
    - Removed overridden properties from early `.quote-card-action-callout` block:
      - `margin-bottom`
      - `border-radius`
      - `padding`
    - Removed base `.quote-items-responsive { overflow: visible; }` (default behavior).
  - Evidence:
    - Canonical selectors remain in later chain:
      - `.quote-card` (full active visual block)
      - `.quote-card-diff` (active spacing/typography block)
      - `.quote-queue-toolbar` (active container shell block)
      - `.quote-card-list` (active list spacing block)
    - Mobile canonical table-card conversion still remains in `@media (max-width: 768px)` quote-items-responsive chain.
- `2026-03-22`: Cleanup closure decision:
  - Phase 3 code cleanup marked complete after Pass 6 (no high-confidence same-scope quote deletions left without stepping into behavior-changing refactor).
  - Overall phase cleanup status: Phase 1/2/3 code cleanup complete; all pending items are visual acceptance/closure tasks.

## 10. Next Priority Queue
- Next phase/task:
  - Phase 1 manual validation pass: dashboard desktop/mobile acceptance check (environment Playwright blocked by `spawn EPERM`).
  - Phase 2 manual visual validation pass: navbar/account/locale desktop/mobile acceptance and closure decision.
  - Phase 3 manual visual validation pass: quote desktop/mobile acceptance and closure decision.
  - Archive execution: move finalized plan to `docs/archive/css-cleanup-plan-2026-03.md` after visual acceptance sign-off.
- Deferred items:
  - None.
- Reopen conditions:
  - Any discovered regression in dashboard/navbar-account-locale/quote desktop-mobile behavior.

## 11. Archive Notes (when cycle is done)
- Final status: `Phase 1/2/3 code cleanup complete; waiting manual visual acceptance`
- Archive filename: `docs/archive/css-cleanup-plan-2026-03.md`
- Key decisions to preserve:
  - Delete/merge-first cleanup strategy.
  - Phase-based scoped cleanup with evidence log per pass.
