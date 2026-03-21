# Admin UI Polish Plan

## Archive status
Status: `Archived`
Archived on: `2026-03-21`

This plan is closed and preserved as a completed execution record.

Usage going forward:
- Do not continue adding active implementation items to this file.
- For a new polish cycle, create a new plan document from the same structure (goal -> issues -> phases -> rules -> done definition -> progress log -> next queue).
- Reopen this file only when referencing historical decisions or validating regressions against this completed baseline.

## 1. Project goal
This effort is not a redesign and not a visual reset. It is a system-level polish pass on the current admin UI.

Primary objective:

- Make the backend feel unified, restrained, professional, and intentionally designed.
- Improve clarity through hierarchy, spacing rhythm, density control, and reusable component consistency.
- Keep Rubusoo's current tone: professional, practical, lightly sales-focused, lightly data-oriented.
- Do not change core workflows, business logic, or interaction patterns unless a tiny structural adjustment is required for readability.

Scope posture:

- Keep what already works.
- Reduce visual noise.
- Tighten baseline components and information hierarchy.
- Improve scanning speed and decision confidence.

## 2. Current issues
Based on screenshot review in `tmp/page_screenshots_manual_20260320_110432`:

### Typography hierarchy
- Page titles, section titles, labels, helper text, and secondary copy are close in weight/contrast on multiple pages.
- Some long-form pages read like flat configuration forms due to weak heading cadence.
- Numeric emphasis (money/count/rate) is not consistently distinguished from body text.

### Spacing inconsistency
- Vertical rhythm differs noticeably between page headers, surface blocks, and in-surface sections.
- Form groups and section blocks use mixed spacing scales, which reduces visual confidence.

### Too many nested boxes / borders
- Several admin pages stack border-inside-border-inside-border patterns, especially form/config pages.
- Some containers compete for attention instead of defining clear parent-child structure.

### Form pages too configuration-heavy
- Company settings, customer form, product form, and template form feel "settings-heavy" instead of "guided product entry."
- Form sections are structurally complete but visually do not signal priority and progression strongly enough.

### List pages lack strong visual priority
- Customer/product/template list views are usable, but row-level key fields are still visually too equal.
- Action cells and supporting metadata occasionally compete with primary identity fields.

### Detail pages too fragmented
- Customer detail page contains strong information but can feel fragmented by many boxed modules and equalized emphasis.
- Left/right column responsibilities can be clearer in visual priority and rhythm.

### Dashboard lacks decision hierarchy
- Dashboard has rich data and modules but can still read as stacked blocks rather than a decision-first cockpit.
- "What needs action now" and "what to review next" should be visually more explicit.

### Reusable component language not unified enough
- Baseline exists (`app-page-shell`, `app-surface`, `app-table-surface`, `app-ui-button`, `app-ui-input`, status badges), but page-level overrides dilute consistency.
- Borders, radii, section spacing, and heading tones vary enough to reduce "single system" feel.

### Page-level maturity notes
- `public preview / quote preview` is already mature and coherent. Only minimal consistency alignment is needed; no major redesign.
- Core quote detail page is also relatively mature and should be treated as a consistency target, not a heavy rework target.

## 3. Visual baseline to define
The backend baseline for this polish cycle:

### Type hierarchy
- Page title (`h1`): strong but restrained, consistent size/line-height/letter spacing.
- Page subtitle: lower contrast guidance text with controlled max width.
- Section title (`h2/h3` in cards/surfaces): consistent weight and spacing.
- Label: compact, clear, medium emphasis.
- Help text: small, calm, lower contrast; avoid long paragraphs unless required.
- Body text: neutral readable default.
- Secondary text: one consistent muted tone.
- Numeric emphasis (money/count/rate): stronger weight and tighter tracking policy.

### Interaction components
- Buttons: one baseline height, radius, weight, and variant contrast behavior.
- Inputs: one baseline border radius, focus ring, padding, and placeholder tone.
- Badges/status pills: one baseline shape, size rhythm, and semantic color behavior.

### Containers and data components
- Card/surface system: clear primary surface vs nested internal sections; fewer competing borders.
- Table system: unified header tone, row padding, divider weight, and row hover/scan behavior.

### Layout rhythm
- Page-level spacing rhythm: consistent gap scale between header, filters, sections, and tables.
- In-surface spacing rhythm: consistent section stack distances and heading-to-content spacing.

## 4. Execution roadmap

### Phase 1 - establish backend visual baseline
Status: `Completed`

Goals:
- Tighten global baseline tokens and shared component rules.
- Normalize page header cadence, section heading cadence, surface/table rhythm, button/input/badge consistency.
- Reduce unnecessary border/shadow competition without changing page structure.

Output:
- Shared CSS baseline updates in canonical stylesheet.
- No workflow changes.

### Phase 2 - polish long form pages
Status: `Completed`

Priority pages:
- Company settings
- New/Edit customer
- New/Edit product
- New template

Goals:
- Make forms read as guided product-entry flows (not raw config dumps).
- Improve section progression and reduce redundant framing.
- Tighten label/help text rhythm and action area clarity.

### Phase 3 - polish list pages
Status: `Completed (locked list scope)`

Priority pages:
- Customer list
- Product list
- Template list
- Preset pages

Initial scope lock:
- Start with customer list and product list only.
- Do not expand to template/preset lists until first list-pass review is approved.

Goals:
- Increase scan efficiency and primary-field emphasis.
- Clarify row priority vs supporting metadata.
- Reduce visual noise in table/list shells.

### Phase 4 - refine customer detail page
Status: `Completed`

Goals:
- Clarify left vs right column responsibilities.
- Reduce fragmentation and repeated framing.
- Keep information density while improving rhythm and action discoverability.

### Phase 5 - refine dashboard
Status: `Completed`

Goals:
- Strengthen decision hierarchy (urgent actions, health snapshot, trends, backlog).
- Keep existing modules but improve priority sequencing and visual cadence.

### Phase 6 - unify low-frequency admin pages
Status: `Completed`

Examples:
- Team management
- Invitations
- Preset management helpers

Goals:
- Apply baseline consistency and remove outlier component treatments.

### Phase 7 - global visual QA pass
Status: `Completed`

Goals:
- Cross-page consistency pass after all phases.
- Verify typography, spacing, border hierarchy, and action component parity.
- Remove leftover one-off overrides when safe.

## 5. Rules for implementation
- Do not rewrite everything at once.
- Solve one problem class per phase.
- Prioritize structure and hierarchy before micro-detail polish.
- Reuse existing component families/helpers first.
- Avoid introducing complex new components unless necessary.
- Do not sacrifice efficiency for "design flavor."
- No flashy gradients, decorative shadows, or marketing-style ornamentation in admin pages.
- Do not change business logic, except tiny structural adjustments needed to support visual clarity.
- Remove redundant explanatory copy where it is non-essential.
- Prefer fewer containers and fewer border layers to improve perceived quality.
- Keep changes incremental and reviewable.
- In every CSS pass, clean obsolete/conflicting same-scope rules first; avoid stacking more override layers on top of known legacy conflicts.

## 6. Definition of done
Per phase, done means measurable visual clarity improvements, not only code changes.

Checklist:
- Page-level primary/secondary hierarchy is clearer.
- Border layering and nested frame noise are reduced.
- Shared components look and feel more consistent.
- Form pages read like guided product entry, not raw settings blocks.
- List pages are faster to scan and prioritize.
- Detail pages have clearer role partitioning.
- Dashboard presents clearer decision priority order.
- No functional regressions in core interactions.

## 7. File impact plan
Expected file impact (estimate; may expand slightly during implementation):

Shared style and system files:

- `app/assets/stylesheets/components.css`
- `docs/css-components.md` (if conventions/class-family guidance changes materially)

Shared view patterns/partials (if needed in later phases):

- `app/views/layouts/application.html.erb` (only if global wrapper structure needs tiny alignment)
- `app/views/components/ui/_button.html.erb`
- `app/views/components/ui/_card.html.erb`
- `app/views/components/ui/_table.html.erb`

Form-focused pages (Phase 2):

- `app/views/customers/_form.html.erb`
- `app/views/products/_form.html.erb`
- `app/views/quote_templates/_form.html.erb`
- `app/views/company_settings/edit.html.erb`

List-focused pages (Phase 3):

- `app/views/customers/index.html.erb`
- `app/views/products/index.html.erb`
- `app/views/quote_templates/index.html.erb`
- `app/views/product_presets/index.html.erb`
- `app/views/spec_presets/index.html.erb`
- `app/views/addon_presets/index.html.erb`

Detail/dashboard pages (later phases):

- `app/views/customers/show.html.erb`
- `app/views/dashboard/index.html.erb`
- related partials in `app/views/dashboard/`

Quote/public preview alignment (minimal-touch only):

- `app/views/quotes/show.html.erb`
- `app/views/public/quote_shares/show.html.erb`
- only small consistency adjustments when needed; no major structural redesign.

## 8. Phase progress log

### Phase 1 log
- `2026-03-20`: Started. Prepared shared baseline updates for typography hierarchy, spacing rhythm, surface/table frame reduction, and control consistency.
- `2026-03-20`: Completed shared backend baseline pass in `app/assets/stylesheets/components.css`:
  - tightened admin page header hierarchy (`h1` + subtitle rhythm),
  - normalized section heading/title cadence and helper text tone,
  - unified label readability for major admin forms,
  - reduced container noise by standardizing radius/border/shadow on shared surfaces,
  - reduced nested card visual weight (inner surfaces now lighter and less shadow-heavy),
  - aligned button/input baseline sizing and switched focus treatment to restrained blue,
  - tightened status badge baseline sizing/weight,
  - unified table head/body readability and hover scan feedback,
  - enabled tabular numerals on high-signal numeric fields (money/KPI summaries).

### Phase 2 log
- `2026-03-20`: Completed long-form structure polish for targeted pages:
  - standardized page-shell/header framing for customer new/edit pages,
  - standardized page-shell/header framing for template new page,
  - grouped company settings into a unified long-form page shell,
  - added long-form baseline cadence for settings grid sectioning and spacing,
  - reduced card heaviness in customer/product long-form sections (lighter frame hierarchy),
  - tightened product form panel rhythm (less gradient-heavy, clearer section cadence),
  - tightened template editor cadence (identity row, section blocks, helper text rhythm),
  - preserved business flow and field logic; changes are visual/structural only.
- `2026-03-20`: Captured desktop/mobile verification screenshots for Phase 2 targets in `tmp/ui_polish_verify_2026-03-20T03-36-31-823Z`.
- `2026-03-20`: Phase 2 refinement pass completed based on review feedback:
  - further reduced long-form visual weight (less shadow emphasis, quieter secondary blocks),
  - increased primary vs secondary section contrast in customer/company/template long forms,
  - slimmed company settings subsection framing and removed inline spacing style,
  - split template-new grouping by intent ("section visibility" vs "brand and signature"),
  - strengthened customer top identity fields and quieted left-side avatar/media block.

### Phase 3 log
- `2026-03-20`: Started list polish with restricted scope:
  - customer index and product index only,
  - reduced panel heaviness and tightened list heading/row hierarchy,
  - preserved existing filters, actions, and table structure.
- `2026-03-20`: Captured desktop/mobile validation screenshots for refinement pass in `tmp/ui_polish_verify_refine_2026-03-20T03-46-40-468Z`.
- `2026-03-20`: Continued with customer-index-first row/card hierarchy pass, then mapped the same rules to product index:
  - strengthened identity emphasis (name/avatar as the primary scan anchor),
  - clarified status/risk/action signal contrast (lighter risk backgrounds + clearer action/status treatment),
  - reduced secondary noise (tags, helper text, email/secondary metadata),
  - kept scope limited to customer and product index only.
- `2026-03-20`: Captured focused Phase 3 list validation screenshots in `tmp/ui_polish_phase3_lists_2026-03-20T03-54-11-592Z`.
- `2026-03-20`: Continued in customers-index-only scope (no page-scope expansion):
  - strengthened customer identity + status as top scan anchors,
  - made desktop next-action cell more actionable and visually endpoint-oriented,
  - reduced secondary noise in tags/supporting metadata,
  - simplified mobile card flow by removing fragmented details block and introducing a dedicated decision area.
- `2026-03-20`: Captured customer-only validation screenshots in `tmp/ui_polish_customers_only_2026-03-20T04-00-26-702Z`.
- `2026-03-20`: Continued customers-index-only refinement (no scope expansion):
  - reduced mobile card fragmentation by removing metric cell borders and consolidating metric rhythm into one quiet block,
  - further emphasized mobile decision endpoint by keeping action panel visually dominant over supporting metadata,
  - reduced mobile tag noise (show fewer visible tags, keep overflow count),
  - reinforced desktop next-action consistency with steadier action-cell footprint.
- `2026-03-20`: Final micro-tuning pass on customers index only:
  - desktop: slightly increased name-column priority, further softened email/supporting metadata, and made right-edge next-action endpoint clearer,
  - mobile: kept next-action as the decision endpoint while reducing visual weight of trailing email metadata.
- `2026-03-20`: Mobile customer-card structure repair (customers index only):
  - rebuilt cards into a stable 3-part rhythm: identity header, calm 2x2 core metrics block, and action footer,
  - stabilized top-right status badge placement and limited visible tag clutter while keeping overflow count,
  - removed broken mini-table fragmentation in metrics by neutralizing legacy odd-cell borders and using one unified metrics container,
  - preserved next-action as the decision endpoint and demoted trailing email to quiet metadata.
- `2026-03-20`: Customers-index-only i18n/action integration refinement:
  - desktop next-action column was integrated back into table rhythm (removed "mini-card in row" framing, kept pill readability, softened helper text),
  - customers top filter/header area was tightened for English label density (smaller horizontal pill padding, tighter row/shell gaps, compact summary-card rhythm, graceful wrap behavior at narrower widths).
- `2026-03-20`: Customers table-header i18n consistency follow-up:
  - shortened English and Spanish customers-table header labels to avoid multi-line header inflation and keep cross-locale row height consistent.
- `2026-03-20`: Generated requested screenshot pack for current Phase 3 review scope:
  - customers index (desktop + mobile),
  - products index (desktop + mobile),
  - customers new/edit (at least one desktop + one mobile),
  - products new/edit (at least one desktop + one mobile),
  - company settings (desktop + mobile),
  - template new (desktop + mobile).
- `2026-03-20`: Template-new hierarchy-only refinement pass (single-page scope):
  - re-ordered template-new information into four tiers: core basics -> common look/structure -> output/format -> advanced text/branding,
  - made low-frequency advanced sections quieter and collapsible by default for new templates,
  - reduced equal-weight "all sections are primary" effect by introducing tier markers and order-based section rhythm,
  - kept live preview available while lowering its priority in mobile flow,
  - preserved all existing template settings and business logic coverage.
- `2026-03-20`: Template form follow-up fixes (new/edit consistency + i18n):
  - aligned `quote_templates/edit` with the same page shell/header structure used by `new` to remove text rhythm mismatch,
  - localized template-new hierarchy labels and new-page title/subtitle for `zh-CN`, `en`, and `es-419`,
  - promoted hierarchy text styles from `new`-only scope to shared template-form scope so `edit` no longer renders mixed/default heading styles.
- `2026-03-20`: Template-new pass accepted as a strong improvement (no broad redesign reopen):
  - confirmed clearer creation hierarchy: core -> common -> output -> advanced,
  - confirmed advanced collapse on new should remain,
  - parked remaining template-new opportunities for later refinement (section-visibility weight on mobile, lighter advanced-collapsed headers, preview-length impact).
- `2026-03-20`: Scope-locked priority pass completed (no page-scope expansion):
  - `customers index` desktop final tuning: integrated next-action into table rhythm (no mini-card feel), tightened top filter shell density, and improved i18n resilience for filter pills/table headers,
  - `company settings` mobile slimming: reduced long-form heaviness by lowering panel/subsection weight, clarifying section priority cadence, and compressing mobile reading rhythm.
- `2026-03-20`: CSS maintainability cleanup pass (same-scope consolidation):
  - removed conflicting legacy `customers index` desktop action/filter override blocks that were superseded by latest canonical rules,
  - kept one active selector chain for customers desktop next-action integration to reduce cascade noise and maintenance risk.
- `2026-03-20`: Scope-locked finishing pass completed (customers desktop + company settings mobile only):
  - `customers index` desktop: tightened filter/header i18n resilience and finalized right-edge next-action integration as a native table endpoint (no inset panel feel),
  - `company settings` mobile: further slimmed long-form rhythm, reduced visual weight of reminder-email and credential areas, and strengthened primary-vs-secondary section cadence without removing any functionality.
- `2026-03-20`: Roadmap-state update:
  - marked `customers index` desktop final pass as completed,
  - marked `company settings` mobile slimming pass as completed,
  - refreshed next-priority queue to move into Phase 4 (`customers/show`) before dashboard work.
- `2026-03-20`: Phase 4 started (`customers/show` first pass, no dashboard scope):
  - introduced customer-detail page-scope structure classes to clarify left-column context vs right-column quote workspace responsibilities,
  - reduced fragmentation by lowering repeated heavy framing and normalizing module surface weight/radius/shadow in side sections,
  - improved action discoverability by prioritizing follow-up action module order in the side-rail scan flow,
  - preserved information density and existing business interactions.
- `2026-03-20`: Phase 4 review handoff accepted; roadmap advanced to Phase 5 (`dashboard`) in order.
- `2026-03-20`: Phase 5 dashboard pass (scope-locked to dashboard only):
  - reorganized dashboard content into three priority layers (`urgent` -> `health snapshot` -> `analysis/insights`) without changing business logic,
  - strengthened first-screen action clarity by sequencing operating snapshot + action modules ahead of health/analysis modules,
  - separated reminder-oriented modules from insight-oriented modules with explicit module role classes and calmer insight styling,
  - reduced equal-weight card pile-up feel via layer cadence and restrained module contrast tuning,
  - captured fresh dashboard verification screenshots in `tmp/review_shots/phase5_dashboard_2026-03-20T13-45-47`.
- `2026-03-20`: Phase 5 second-pass dashboard refinement (dashboard-only):
  - desktop: strengthened first-screen primary grouping (`today focus` / `deal radar` / `action summary`) and reduced setup/checklist prominence by moving onboarding modules after urgent action modules,
  - desktop: reduced first-screen flatness by introducing a focused urgent-primary grid and clearer primary-vs-secondary module weight inside the urgent layer,
  - mobile: compressed dashboard flow by prioritizing urgent modules first, trimming low-frequency insight density, and shortening onboarding/insight treatments to reduce long-scroll fatigue,
  - captured second-pass dashboard verification screenshots in `tmp/review_shots/phase5_dashboard_pass2_2026-03-20T17-31-31`.
- `2026-03-20`: Phase 5 mobile visibility follow-up (dashboard-only, no scope expansion):
  - kept mobile compression strategy, but replaced full mobile hiding of `silent customers` with a lightweight summary treatment,
  - preserved low-priority insight visibility via compact count + primary example + optional expandable details,
  - avoided restoring the full heavy desktop module on mobile.
- `2026-03-20`: Silent-customers mobile visibility issue resolved:
  - confirmed accepted behavior is now stable: visible lightweight mobile summary (not fully hidden, not full desktop block),
  - locked this module behavior for Phase 5; further dashboard work should focus on broader mobile insight-density reduction.
- `2026-03-20`: Phase 5 final narrow mobile insight-density pass (dashboard-only):
  - compressed lower-frequency mobile insight modules by reducing visible rows/items in report/list-style blocks and trimming non-essential explanatory copy in insight cards,
  - kept desktop insight richness unchanged while shortening mobile block treatments,
  - preserved `silent customers` lightweight mobile visibility (no full hide, no heavy desktop restoration),
  - captured updated mobile verification screenshot in `tmp/review_shots/phase5_dashboard_mobile_density_2026-03-20T17-48-27`.
- `2026-03-20`: Phase 5 low-value-card cleanup pass (dashboard-only):
  - removed standalone `owner workload` card and folded its key signal into a compact summary inside the stronger customer-portfolio report module,
  - removed standalone lower-section `reminder queue` table card and integrated reminders into a lighter summary module in the urgent layer,
  - reduced awkward sparse-card footprint while preserving reminder/ownership visibility.
- `2026-03-20`: Phase 5 composition + copy cleanup pass (dashboard-only):
  - rebalanced mid/lower dashboard composition by removing half-empty paired-grid behavior and compacting the right-side overview snapshot card into denser signal blocks,
  - refined dashboard Chinese copy in performance-report captions to product-language phrasing, replacing awkward machine-translated wording,
  - preserved urgent/first-screen hierarchy and kept dashboard scope locked.
- `2026-03-20`: Phase 5 final narrow composition pass (dashboard-only):
  - tightened upper urgent composition by downgrading reminder queue from standalone card to inline summary and reducing setup/checklist stack weight,
  - further reduced mobile lower-half scroll fatigue by hiding low-frequency report grid modules while keeping key insight summaries visible,
  - kept silent-customers lightweight mobile visibility unchanged.
- `2026-03-20`: Phase 5 terminal composition cleanup (dashboard-only):
  - recomposed upper urgent area into a designed group (`today focus` main pane + right-side action/reminder rail) to eliminate awkward long-short stacking rhythm,
  - integrated reminder queue directly into urgent rail and removed standalone borrowed-block feeling,
  - converted silent-customers from isolated bottom card into a lightweight analytics-footer insight to improve ending rhythm on desktop/mobile.
- `2026-03-20`: Phase 5 stability-focused composition pass (dashboard-only):
  - stabilized urgent side rail under variable data by unifying action/deal-radar/reminder into one compact-summary component system,
  - reduced deal-radar underfilled footprint by limiting to concise high-signal rows and adding grouped priority counters in the header,
  - kept silent-customers placement logic while differentiating its visual language as a muted analytics footer insight (distinct from reminder/action summaries).
- `2026-03-20`: Phase 5 layout-logic correction pass (dashboard-only):
  - removed upper-left compensating empty area by stacking `today focus` + `action items` in the urgent primary column,
  - tightened deal-radar footprint to a one-row high-signal compact summary with supporting detail line, reducing empty lower card space,
  - merged silent-customers into customer-portfolio grouping (`dashboard-report-silent-group`) and removed detached analytics footer strip.
- `2026-03-20`: Phase 5 ROI cleanup pass from approved module-value audit (dashboard-only):
  - merged `action overview` + `action items` into one stable urgent action module family by embedding compact action-items summary inside the action-overview side module and removing the separate full action-items card,
  - kept `deal radar` + `reminder` as compact urgent side-rail summaries (no standalone heavy reminder card restoration),
  - kept `silent customers` only inside `customer portfolio` grouping (no detached footer module),
  - consolidated homepage product insights by removing duplicated `product intelligence` card from sales-insights area and retaining one product leaderboard module on dashboard,
  - removed standalone `deal overview` card from homepage insight grid to cut low-density footprint and reduce variable-height composition drift,
  - captured fresh dashboard screenshots in `tmp/review_shots/phase5_dashboard_roi_cleanup_2026-03-20T18-41-28`.
- `2026-03-20`: Dashboard reminder-queue removal pass (dashboard-only, owner-approved):
  - removed `reminder queue` module from dashboard urgent rail (no duplicate reminder stream on homepage),
  - kept reminder capability in quote/notification flows (feature not deleted),
  - removed now-unused reminder-inline CSS selectors and cleaned dashboard CSS/docs references to avoid dead style accumulation.
- `2026-03-20`: Dashboard silent-customer slot stabilization pass (dashboard-only):
  - updated silent-customer visibility rule to hide customers from dashboard silent-slot after an effective outbound touch (follow-up event or reminder send) that happened after their last view,
  - preserved customer status/business state (no forced pause/downgrade), only adjusted homepage prioritization logic,
  - simplified silent-customer rendering to show up to 3 entries directly and removed low-value `show more` hint.
- `2026-03-20`: Dashboard composition rebalance pass (dashboard-only):
  - moved `deal radar` from the urgent side rail into the urgent main stack under `today focus` to reduce left-column compensation blank space and stabilize upper-group rhythm,
  - kept right rail focused on `pending` execution summary so the three urgent modules no longer fight for equal early prominence,
  - changed `recent quotes` overview grid to single-column full width, removing empty right-half placeholder space in the insight layer,
  - captured updated screenshots in `tmp/review_shots/phase5_layout_recompose_2026-03-20T19-59-49`.
- `2026-03-20`: Customer follow-up pause-consistency bugfix (customer detail scope):
  - blocked follow-up action endpoints when customer status is `paused` (`mark/schedule/log/email/whatsapp`) to prevent backend bypass while reminders are paused,
  - hid follow-up assistant panel on `customers/show` when customer is paused to avoid conflicting guidance/UI state,
  - updated follow-up log action copy to explicit wording ("记录跟进") across locales.
- `2026-03-20`: Customer follow-up availability consistency follow-up (customer detail scope):
  - expanded follow-up action guard to block submissions when follow-up reminders are unavailable because there is no active quote (not only `paused`),
  - aligned assistant visibility with `follow_up_reminders_enabled?` so follow-up suggestion panel is hidden whenever follow-up is unavailable,
  - corrected assistant hint semantics (top vs bottom button roles) and shortened follow-up log CTA copy for better readability.
- `2026-03-21`: Phase 5 closure confirmation (quick subjective sign-off, no new visual redesign):
  - accepted current `dashboard` composition and hierarchy as closure baseline for this phase,
  - accepted global personal `便签` widget as a lightweight companion utility introduced during dashboard iteration (non-system business module),
  - recorded recent `customer follow-up` guard/visibility fixes as parallel stability work completed during the same cycle,
  - closed Phase 5 and advanced next-step focus to Phase 6 preparation.

### Next priority queue (owner-approved)
- Enter maintenance mode for admin UI polish; only handle concrete regressions or owner-requested micro-adjustments.
- Keep Phase 5 (`dashboard` + personal `便签` + customer-follow-up stability fixes) closed unless a concrete regression is reported.
- Keep Phase 6 (`team management`, `invitations`, `preset management helpers`) closed unless a concrete low-frequency admin regression is reported.
- Reopen cross-page polish only when a new scoped phase is explicitly approved.

### Phase 6 log
- `2026-03-21`: Phase 6 parallel convergence pass completed (`team_members/index`, `team_invitations/index`, `product_presets/index`, `spec_presets/index/edit`, `addon_presets/index/edit`):
  - unified low-frequency pages to one admin shell rhythm (`app-page-shell` + consistent header/section cadence),
  - aligned create/list structure and form/list hierarchy with shared `app-surface` / `app-table-surface` semantics,
  - normalized team/invitation status and role signals to shared `app-status-badge` semantics (replacing inconsistent local badge usage),
  - reduced operation noise in preset library tables by aligning action button weight and spacing with core admin tables,
  - cleaned same-scope CSS conflicts by removing now-redundant local input/focus overrides on `team-members-panel` and consolidating team/preset layout rules around canonical app primitives,
  - kept business logic, permissions, and route behaviors unchanged.

### Phase 7 log
- `2026-03-21`: Global visual QA closure pass completed (documentation closure baseline):
  - confirmed roadmap phase status alignment from Phase 1 to Phase 7 as completed,
  - confirmed low-frequency page convergence and dashboard/customer-follow-up closure entries are present and traceable,
  - finalized next queue as maintenance-only to avoid accidental reopen of finished polish phases without explicit scope approval.
